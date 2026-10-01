import httpx
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.models.account import RagChunk
from app.services import breach_checker
from app.services.ai_engine import AIUnavailable, _create_message
from app.services.rag.search import retrieve
from app.services.rag.sources import (
    CATALOG_SOURCE_TYPE,
    POLICY_SOURCE_TYPE,
    SOURCE_LABELS,
    USER_SOURCE_TYPES,
    catalog_documents,
    policy_document,
    user_documents,
)
from app.services.rag.store import embed_missing, sync_documents, upsert_document

settings = get_settings()

SYSTEM = """You are PrivacyBot, the assistant inside PrivacyShield, a personal exposure auditor.

Each question arrives with documents retrieved for it: the user's own PrivacyShield records (risk overview, accounts, breaches, dark web exposures, recommended fixes, analysed privacy policies) and entries from the Have I Been Pwned breach catalog.

Answer from those documents and cite them. When they don't cover the question, say what is missing and which PrivacyShield scan or page would produce it, rather than filling the gap from general knowledge about the user.

Lead with what the user should do, ordered by how much risk it removes, and point out chains where one account unlocks others. Keep answers short and plain. Never ask for a password."""

_catalog_synced_at = -1.0


async def _sync_catalog(db: AsyncSession) -> str | None:
    """Index HIBP's breach catalog whenever breach_checker has fetched a newer copy."""
    global _catalog_synced_at
    try:
        async with breach_checker.http_client() as client:
            catalog = await breach_checker.get_breach_catalog(client)
    except httpx.HTTPError as e:
        return f"Breach catalog unreachable ({e.__class__.__name__}); answering from indexed data."
    if breach_checker._catalog_fetched_at != _catalog_synced_at:
        await sync_documents(db, None, {CATALOG_SOURCE_TYPE}, catalog_documents(catalog))
        _catalog_synced_at = breach_checker._catalog_fetched_at
    await embed_missing(db, None)
    return None


async def ensure_indexed(user_id: int, db: AsyncSession) -> list[str]:
    warnings = []
    await sync_documents(db, user_id, USER_SOURCE_TYPES, await user_documents(user_id, db))
    await embed_missing(db, user_id)
    if warning := await _sync_catalog(db):
        warnings.append(warning)
    return warnings


async def index_policy(user_id: int, url: str, text: str, db: AsyncSession) -> None:
    if text:
        await upsert_document(db, user_id, policy_document(url, text))
        await embed_missing(db, user_id)


async def index_status(user_id: int, db: AsyncSession) -> dict:
    rows = (await db.execute(
        select(RagChunk.source_type, func.count(RagChunk.id), func.count(RagChunk.embedding))
        .where((RagChunk.user_id == user_id) | RagChunk.user_id.is_(None))
        .group_by(RagChunk.source_type)
    )).all()
    return {
        "retrieval": "hybrid" if settings.voyage_api_key else "keyword",
        "embedding_model": settings.voyage_model if settings.voyage_api_key else None,
        "generation": "claude" if settings.anthropic_api_key else None,
        "chunks": {t: {"total": total, "embedded": embedded} for t, total, embedded in rows},
    }


def _query(message: str, history: list[dict]) -> str:
    previous = [m["content"] for m in history if m.get("role") == "user" and m.get("content")]
    return f"{previous[-1]} {message}" if previous else message


async def answer(user_id: int, message: str, history: list[dict], db: AsyncSession) -> dict:
    warnings = await ensure_indexed(user_id, db)
    hits, retrieval = await retrieve(db, user_id, _query(message, history))

    sources = [
        {
            "n": i + 1,
            "title": h.chunk.title,
            "type": h.chunk.source_type,
            "label": SOURCE_LABELS.get(h.chunk.source_type, h.chunk.source_type),
            "url": h.chunk.url,
            "snippet": h.chunk.text[:280],
            "cited": False,
        }
        for i, h in enumerate(hits)
    ]
    result = {"response": None, "error": None, "sources": sources, "retrieval": {**retrieval, "warnings": warnings}}

    documents = [
        {
            "type": "document",
            "source": {"type": "text", "media_type": "text/plain", "data": h.chunk.text},
            "title": h.chunk.title,
            "context": SOURCE_LABELS.get(h.chunk.source_type, h.chunk.source_type),
            "citations": {"enabled": True},
        }
        for h in hits
    ]
    messages = [
        {"role": m["role"], "content": m["content"]}
        for m in history[-10:]
        if m.get("role") in ("user", "assistant") and m.get("content")
    ]
    messages.append({"role": "user", "content": [*documents, {"type": "text", "text": message}]})

    try:
        response = await _create_message(SYSTEM, messages)
    except AIUnavailable as e:
        result["error"] = f"{e} The most relevant records are listed below."
        return result

    parts = []
    for block in response.content:
        if block.type != "text":
            continue
        cited = sorted({c.document_index + 1 for c in (block.citations or []) if hasattr(c, "document_index")})
        for n in cited:
            if 0 < n <= len(sources):
                sources[n - 1]["cited"] = True
        parts.append(block.text + "".join(f" [{n}]" for n in cited))
    result["response"] = "".join(parts).strip()
    return result

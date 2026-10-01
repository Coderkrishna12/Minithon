import hashlib

import httpx
from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.models.account import RagChunk
from app.services.rag.chunking import chunk_text
from app.services.rag.sources import SourceDoc

settings = get_settings()

VOYAGE_URL = "https://api.voyageai.com/v1/embeddings"
EMBED_BATCH = 64


def _scope(user_id: int | None):
    return RagChunk.user_id.is_(None) if user_id is None else RagChunk.user_id == user_id


def _hash(doc: SourceDoc) -> str:
    return hashlib.sha256(f"{doc.title}\n{doc.text}\n{doc.url or ''}".encode()).hexdigest()


async def sync_documents(db: AsyncSession, user_id: int | None, source_types: set[str], docs: list[SourceDoc]) -> int:
    """Make the stored chunks for these source types match `docs`. Unchanged sources are left alone."""
    rows = (await db.execute(
        select(RagChunk.source_type, RagChunk.source_id, RagChunk.source_hash)
        .where(_scope(user_id), RagChunk.source_type.in_(source_types))
    )).all()
    stored = {(t, i): h for t, i, h in rows}
    wanted = {(d.source_type, d.source_id): d for d in docs}

    stale = [key for key, h in stored.items() if key not in wanted or _hash(wanted[key]) != h]
    for source_type, source_id in stale:
        await db.execute(delete(RagChunk).where(
            _scope(user_id), RagChunk.source_type == source_type, RagChunk.source_id == source_id
        ))

    changed = 0
    for key, doc in wanted.items():
        if key in stored and key not in stale:
            continue
        digest = _hash(doc)
        for n, piece in enumerate(chunk_text(doc.text)):
            db.add(RagChunk(
                user_id=user_id, source_type=doc.source_type, source_id=doc.source_id, source_hash=digest,
                chunk_no=n, title=doc.title, text=piece, url=doc.url,
            ))
        changed += 1
    await db.commit()
    return changed


async def upsert_document(db: AsyncSession, user_id: int | None, doc: SourceDoc) -> None:
    """Replace one source's chunks without touching other sources of the same type."""
    await db.execute(delete(RagChunk).where(
        _scope(user_id), RagChunk.source_type == doc.source_type, RagChunk.source_id == doc.source_id
    ))
    digest = _hash(doc)
    for n, piece in enumerate(chunk_text(doc.text)):
        db.add(RagChunk(
            user_id=user_id, source_type=doc.source_type, source_id=doc.source_id, source_hash=digest,
            chunk_no=n, title=doc.title, text=piece, url=doc.url,
        ))
    await db.commit()


async def embed_texts(texts: list[str], input_type: str) -> list[list[float]] | None:
    """Voyage embeddings, or None when no key is configured or the API is unreachable."""
    if not settings.voyage_api_key or not texts:
        return None
    vectors: list[list[float]] = []
    async with httpx.AsyncClient(timeout=30) as client:
        for start in range(0, len(texts), EMBED_BATCH):
            try:
                resp = await client.post(
                    VOYAGE_URL,
                    headers={"Authorization": f"Bearer {settings.voyage_api_key}"},
                    json={"input": texts[start:start + EMBED_BATCH], "model": settings.voyage_model, "input_type": input_type},
                )
                resp.raise_for_status()
            except httpx.HTTPError:
                return None
            data = sorted(resp.json()["data"], key=lambda d: d["index"])
            vectors.extend(d["embedding"] for d in data)
    return vectors


async def embed_missing(db: AsyncSession, user_id: int | None) -> int:
    """Embed chunks that have no vector for the configured model yet."""
    if not settings.voyage_api_key:
        return 0
    chunks = (await db.execute(
        select(RagChunk).where(_scope(user_id), (RagChunk.embedding.is_(None)) | (RagChunk.embedding_model != settings.voyage_model))
    )).scalars().all()
    if not chunks:
        return 0
    vectors = await embed_texts([f"{c.title}\n{c.text}" for c in chunks], "document")
    if vectors is None:
        return 0
    for chunk, vector in zip(chunks, vectors):
        chunk.embedding = vector
        chunk.embedding_model = settings.voyage_model
    await db.commit()
    return len(chunks)

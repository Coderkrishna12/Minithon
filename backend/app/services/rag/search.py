import math
import re
from collections import Counter
from dataclasses import dataclass

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.models.account import RagChunk
from app.services.rag.store import embed_texts

settings = get_settings()

TOKEN = re.compile(r"[a-z0-9]+")
STOPWORDS = {
    "a", "an", "and", "are", "as", "at", "be", "by", "can", "do", "does", "for", "from", "has", "have", "how", "i",
    "if", "in", "is", "it", "its", "me", "my", "of", "on", "or", "should", "so", "that", "the", "their", "this", "to",
    "was", "what", "when", "which", "who", "why", "will", "with", "you", "your",
}
RRF_K = 60
USER_BOOST = 1.5
MAX_PER_SOURCE = 2


@dataclass
class Hit:
    chunk: RagChunk
    score: float


def stem(token: str) -> str:
    """Light suffix stripping so "passwords", "leaked" and "leaking" match "password" and "leak"."""
    for suffix in ("ing", "ed"):
        if token.endswith(suffix) and len(token) - len(suffix) >= 3:
            return token[: -len(suffix)]
    if token.endswith("es") and token[:-2].endswith(("ch", "sh", "x", "z")):
        return token[:-2]
    if token.endswith("s") and not token.endswith("ss") and len(token) > 3:
        return token[:-1]
    return token


def tokenize(text: str) -> list[str]:
    return [stem(t) for t in TOKEN.findall(text.lower()) if t not in STOPWORDS]


def bm25_scores(query: list[str], docs: list[list[str]], k1: float = 1.5, b: float = 0.75) -> list[float]:
    if not docs or not query:
        return [0.0] * len(docs)
    avg_len = sum(len(d) for d in docs) / len(docs) or 1.0
    df = Counter(t for d in docs for t in set(d))
    n = len(docs)
    scores = []
    for d in docs:
        tf = Counter(d)
        score = 0.0
        for term in set(query):
            if term not in tf:
                continue
            idf = math.log(1 + (n - df[term] + 0.5) / (df[term] + 0.5))
            score += idf * tf[term] * (k1 + 1) / (tf[term] + k1 * (1 - b + b * len(d) / avg_len))
        scores.append(score)
    return scores


def cosine(a: list[float], b: list[float]) -> float:
    dot = sum(x * y for x, y in zip(a, b))
    na = math.sqrt(sum(x * x for x in a))
    nb = math.sqrt(sum(y * y for y in b))
    return dot / (na * nb) if na and nb else 0.0


async def retrieve(db: AsyncSession, user_id: int, query: str, k: int = 8) -> tuple[list[Hit], dict]:
    """Hybrid search over the user's own records and the shared breach catalog, fused with reciprocal rank fusion."""
    chunks = list((await db.execute(
        select(RagChunk).where((RagChunk.user_id == user_id) | RagChunk.user_id.is_(None))
    )).scalars().all())
    if not chunks:
        return [], {"mode": "empty", "searched": 0}

    lexical = bm25_scores(tokenize(query), [tokenize(f"{c.title} {c.text}") for c in chunks])
    lexical = [s * (USER_BOOST if c.user_id is not None else 1.0) for s, c in zip(lexical, chunks)]
    rankings = [[i for i in sorted(range(len(chunks)), key=lambda i: -lexical[i]) if lexical[i] > 0]]
    mode = "keyword"

    query_vector = None
    if settings.voyage_api_key and any(c.embedding_model == settings.voyage_model for c in chunks):
        vectors = await embed_texts([query], "query")
        query_vector = vectors[0] if vectors else None
    if query_vector is not None:
        dense = {
            i: cosine(query_vector, c.embedding) * (USER_BOOST if c.user_id is not None else 1.0)
            for i, c in enumerate(chunks)
            if c.embedding and c.embedding_model == settings.voyage_model
        }
        rankings.append(sorted(dense, key=lambda i: -dense[i])[: k * 5])
        mode = "hybrid"

    fused: dict[int, float] = {}
    for ranking in rankings:
        for rank, i in enumerate(ranking):
            fused[i] = fused.get(i, 0.0) + 1 / (RRF_K + rank + 1)

    hits: list[Hit] = []
    per_source: Counter = Counter()
    for i in sorted(fused, key=lambda i: -fused[i]):
        c = chunks[i]
        key = (c.user_id, c.source_type, c.source_id)
        if per_source[key] >= MAX_PER_SOURCE:
            continue
        per_source[key] += 1
        hits.append(Hit(c, fused[i]))
        if len(hits) == k:
            break
    return hits, {"mode": mode, "searched": len(chunks)}

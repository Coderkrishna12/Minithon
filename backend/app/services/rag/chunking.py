import re

CHUNK_CHARS = 900
OVERLAP_CHARS = 150


def _tail(text: str, size: int) -> str:
    """Last `size` characters, starting at a word boundary."""
    if len(text) <= size:
        return text
    cut = text[-size:]
    space = cut.find(" ")
    return cut[space + 1:] if space != -1 else cut


def chunk_text(text: str, size: int = CHUNK_CHARS, overlap: int = OVERLAP_CHARS) -> list[str]:
    """Sentence-aware chunks of about `size` characters, each repeating the previous chunk's tail."""
    text = re.sub(r"\s+", " ", text).strip()
    if not text:
        return []
    if len(text) <= size:
        return [text]

    pieces: list[str] = []
    for sentence in re.split(r"(?<=[.!?])\s+", text):
        while len(sentence) > size:
            pieces.append(sentence[:size])
            sentence = sentence[size:]
        if sentence:
            pieces.append(sentence)

    chunks: list[str] = []
    current = ""
    for piece in pieces:
        if current and len(current) + 1 + len(piece) > size:
            chunks.append(current)
            current = f"{_tail(current, overlap)} {piece}".strip()
        else:
            current = f"{current} {piece}".strip()
    if current:
        chunks.append(current)
    return chunks

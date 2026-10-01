import hashlib
from types import SimpleNamespace

from tests.test_real_data import CATALOG, add, handler_for, xon_analytics


def test_chunking_overlaps_and_respects_size():
    from app.services.rag.chunking import chunk_text

    text = " ".join(f"Sentence number {i} talks about passwords and breaches." for i in range(60))
    chunks = chunk_text(text, size=300, overlap=60)
    assert len(chunks) > 5
    assert all(len(c) <= 360 for c in chunks)
    assert chunks[1].split(" ")[0] in chunks[0]


def test_bm25_ranks_the_matching_document_first():
    from app.services.rag.search import bm25_scores, tokenize

    docs = [tokenize(t) for t in ("Spotify music account", "Adobe breach leaked password hints", "Gmail inbox recovery")]
    scores = bm25_scores(tokenize("what leaked in the adobe breach?"), docs)
    assert scores.index(max(scores)) == 1


def test_tokenizer_matches_word_forms():
    from app.services.rag.search import tokenize

    assert tokenize("Which passwords leaked?") == tokenize("password leak")
    assert tokenize("breaches services") == tokenize("breach service")


def _seed(client, headers, email, mock_http):
    mock_http["handler"] = handler_for(xon_analytics([]))
    add(client, headers, service_name="Gmail", service_url="gmail.com", email_used=email, category="email")
    add(client, headers, service_name="Adobe", service_url="adobe.com", email_used=email, password_group="A")
    add(client, headers, service_name="Dropbox", service_url="dropbox.com", email_used=email, password_group="A")
    client.post("/api/breaches/scan-all", headers=headers)


def test_without_claude_key_returns_retrieved_records_and_says_why(client, auth, mock_http):
    headers, email = auth
    _seed(client, headers, email, mock_http)

    body = client.post("/api/ai/chat", headers=headers, json={"message": "What leaked in the Adobe breach?"}).json()

    assert body["response"] is None
    assert "ANTHROPIC_API_KEY" in body["error"]
    titles = [s["title"] for s in body["sources"]]
    assert "Adobe breach" in titles
    assert any(t.startswith("Breach: Adobe") for t in titles)
    assert body["retrieval"]["mode"] == "keyword"


def test_answer_cites_retrieved_documents(client, auth, mock_http, monkeypatch):
    headers, email = auth
    _seed(client, headers, email, mock_http)

    import app.services.rag.pipeline as pipeline
    seen = {}

    async def fake_create(system, messages, effort="low", output_format=None):
        seen["messages"] = messages
        docs = [b for b in messages[-1]["content"] if b["type"] == "document"]
        reuse = next(i for i, d in enumerate(docs) if d["title"] == "Your risk overview")
        return SimpleNamespace(content=[
            SimpleNamespace(type="text", text="Change the password you reuse on Adobe and Dropbox.",
                            citations=[SimpleNamespace(document_index=reuse, cited_text="Password reused")]),
            SimpleNamespace(type="text", text=" Then turn on 2FA for Gmail.", citations=None),
        ])

    monkeypatch.setattr(pipeline, "_create_message", fake_create)
    body = client.post("/api/ai/chat", headers=headers, json={"message": "What is my biggest risk?"}).json()

    overview = next(s for s in body["sources"] if s["title"] == "Your risk overview")
    assert body["response"].startswith(f"Change the password you reuse on Adobe and Dropbox. [{overview['n']}]")
    assert overview["cited"] is True
    assert "Password reused across: Adobe, Dropbox" in seen["messages"][-1]["content"][overview["n"] - 1]["source"]["data"]
    assert seen["messages"][-1]["content"][-1] == {"type": "text", "text": "What is my biggest risk?"}


def test_hybrid_retrieval_uses_embeddings_when_voyage_is_configured(client, auth, mock_http, monkeypatch):
    headers, email = auth
    _seed(client, headers, email, mock_http)

    import app.services.rag.search as search
    import app.services.rag.store as store

    def vec(text):
        v = [0.0] * 64
        for word in text.lower().split():
            v[int(hashlib.md5(word.strip(".,?").encode()).hexdigest(), 16) % 64] += 1
        return v

    async def fake_embed(texts, input_type):
        return [vec(t) for t in texts]

    monkeypatch.setattr(store.settings, "voyage_api_key", "test-key")
    monkeypatch.setattr(store, "embed_texts", fake_embed)
    monkeypatch.setattr(search, "embed_texts", fake_embed)

    client.post("/api/ai/rag/reindex", headers=headers)
    status = client.get("/api/ai/rag/status", headers=headers).json()
    assert status["retrieval"] == "hybrid"
    assert all(v["embedded"] == v["total"] for v in status["chunks"].values())

    body = client.post("/api/ai/chat", headers=headers, json={"message": "LinkedIn breach"}).json()
    assert body["retrieval"]["mode"] == "hybrid"
    assert body["sources"][0]["title"] == "LinkedIn breach"


def test_analysed_privacy_policies_become_searchable(client, auth, mock_http, monkeypatch):
    headers, _ = auth
    mock_http["handler"] = handler_for(xon_analytics([]))

    import app.api.ai_chat as ai_chat

    async def fake_fetch(url):
        return "We collect your faceprint and voiceprint for biometric identification and keep them indefinitely."

    monkeypatch.setattr(ai_chat, "fetch_policy_text", fake_fetch)
    client.post("/api/ai/analyze-policy", headers=headers, json={"url": "https://example.com/privacy"})

    body = client.post("/api/ai/chat", headers=headers, json={"message": "Does any policy collect biometric data?"}).json()
    assert body["sources"][0]["type"] == "policy"
    assert body["sources"][0]["url"] == "https://example.com/privacy"


def test_user_records_never_leak_across_users(client, auth, mock_http):
    headers, email = auth
    _seed(client, headers, email, mock_http)

    import secrets
    other = f"other{secrets.token_hex(3)}@example.com"
    credential = secrets.token_urlsafe(12)
    client.post("/api/auth/register", json={"email": other, "username": other.split("@")[0], "password": credential})
    token = client.post("/api/auth/login", json={"email": other, "password": credential}).json()["access_token"]

    body = client.post("/api/ai/chat", headers={"Authorization": f"Bearer {token}"}, json={"message": "Adobe Dropbox Gmail account"}).json()
    assert {s["type"] for s in body["sources"]} <= {"hibp_breach"}

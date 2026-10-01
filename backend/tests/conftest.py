import os
import secrets
import sys
from pathlib import Path

import httpx
import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))


@pytest.fixture
def client(tmp_path, monkeypatch):
    os.environ["DATABASE_URL"] = f"sqlite+aiosqlite:///{tmp_path}/test.db"
    os.environ["HIBP_API_KEY"] = ""
    os.environ["MONITOR_INTERVAL_MINUTES"] = "0"
    for name in list(sys.modules):
        if name == "app" or name.startswith("app."):
            del sys.modules[name]

    from fastapi.testclient import TestClient
    from app.main import app
    from app.core.config import get_settings

    # Empty env vars are ignored, so a real key in backend/.env would leak into tests.
    monkeypatch.setattr(get_settings(), "gemini_api_key", "")

    with TestClient(app) as c:
        yield c


@pytest.fixture
def mock_http(monkeypatch):
    """Route every outbound call from the breach/exposure services to a handler the test sets."""
    state = {"handler": lambda request: httpx.Response(404)}

    def factory():
        return httpx.AsyncClient(transport=httpx.MockTransport(lambda r: state["handler"](r)))

    import app.services.breach_checker as bc
    import app.api.darkweb as dw
    import app.api.smart_import as si

    bc._catalog.clear()
    bc._catalog_fetched_at = 0.0
    for module in (bc, dw, si):
        monkeypatch.setattr(module, "http_client", factory)
    return state


@pytest.fixture
def auth(client):
    email = f"user{secrets.token_hex(4)}@example.com"
    credential = secrets.token_urlsafe(16)
    client.post("/api/auth/register", json={"email": email, "username": email.split("@")[0], "password": credential})
    token = client.post("/api/auth/login", json={"email": email, "password": credential}).json()["access_token"]
    return {"Authorization": f"Bearer {token}"}, email

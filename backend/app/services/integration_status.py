"""In-process health metadata for external integration adapters."""
from datetime import datetime, timezone
from threading import Lock

_lock = Lock()
_state: dict[str, dict] = {}


def record_call(name: str, *, healthy: bool, latency_ms: float | None = None, detail: str | None = None):
    now = datetime.now(timezone.utc).isoformat()
    with _lock:
        previous = _state.get(name, {})
        _state[name] = {
            "health": "healthy" if healthy else "down",
            "latency_ms": round(latency_ms, 1) if latency_ms is not None else None,
            "last_successful_call": now if healthy else previous.get("last_successful_call"),
            "last_checked": now,
            "detail": detail if not healthy else None,
        }


def get_state(name: str) -> dict:
    with _lock:
        return dict(_state.get(name, {}))

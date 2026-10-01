from fastapi import APIRouter

from app.core.config import get_settings
from app.services.integration_status import get_state

router = APIRouter(tags=["status"])


@router.get("/status")
async def integration_status():
    """Return honest mode/configuration and the last observed provider health."""
    settings = get_settings()
    configured = {
        # Public breach catalogue is reachable without a key; keyed email lookups still depend on XON/key.
        "hibp": True,
        "xon": True,  # The current XON public endpoint does not require an API key.
        # Credentials alone cannot make an unfinished OAuth flow operational.
        "gmail": False,
        "claude": bool(settings.anthropic_api_key),
        "blockchain": bool(settings.polygon_private_key),
    }
    modes = {
        "hibp": settings.hibp_mode,
        "xon": settings.xon_mode,
        "gmail": "unavailable_not_implemented",
        "claude": "live" if configured["claude"] else "unconfigured",
        "blockchain": "testnet" if configured["blockchain"] else "local_hash_chain",
    }
    result = {}
    for name in configured:
        observed = get_state(name)
        mode = modes[name]
        if mode == "mock":
            health = "mock"
        elif not configured[name] and name not in ("xon",):
            health = "unconfigured" if name not in ("blockchain",) else "local_only"
        else:
            health = observed.get("health", "not_checked")
        result[name] = {
            "mode": mode,
            "configured": configured[name],
            "health": health,
            "last_successful_call": observed.get("last_successful_call"),
            "last_checked": observed.get("last_checked"),
            "latency_ms": observed.get("latency_ms"),
            "detail": observed.get("detail"),
        }
    return {"api_version": "1", "integrations": result}

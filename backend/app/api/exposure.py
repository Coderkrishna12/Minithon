import time
from collections import defaultdict, deque

import httpx
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from app.core.security import get_current_user
from app.models.user import User
from app.services.exposure import exposure_profile

router = APIRouter(prefix="/exposure", tags=["exposure"])

# Lookups hit third-party APIs; keep a person from hammering them.
_RATE = 20
_recent: dict[int, deque] = defaultdict(deque)


class ScanRequest(BaseModel):
    email: str
    consent: bool = False


@router.post("/scan")
async def scan_email(data: ScanRequest, user: User = Depends(get_current_user)):
    """Live 'what a hacker already knows' profile for an email address. Nothing is stored."""
    if not data.consent:
        raise HTTPException(status_code=400, detail="Confirm you have permission to look up this email address.")
    window = _recent[user.id]
    now = time.monotonic()
    while window and now - window[0] > 3600:
        window.popleft()
    if len(window) >= _RATE:
        raise HTTPException(status_code=429, detail="Too many lookups this hour. Try again later.")
    window.append(now)
    try:
        return await exposure_profile(data.email)
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))
    except httpx.HTTPError:
        raise HTTPException(status_code=502, detail="The breach databases didn't answer. Check the connection and try again.")

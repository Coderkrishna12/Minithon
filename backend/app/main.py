from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api import (
    auth, accounts, dashboard, graph, blockchain, breaches, ai_chat,
    notifications, features, search, timeline, family, did, dao,
    darkweb, reminders, reports, smart_import, websocket,
)
from app.db.session import init_db


@asynccontextmanager
async def lifespan(app: FastAPI):
    await init_db()
    yield


app = FastAPI(
    title="PrivacyShield API",
    description="Digital Footprint & Privacy Risk Auditor — AI + Blockchain",
    version="2.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000", "http://10.0.2.2:8000", "*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router, prefix="/api")
app.include_router(accounts.router, prefix="/api")
app.include_router(dashboard.router, prefix="/api")
app.include_router(graph.router, prefix="/api")
app.include_router(blockchain.router, prefix="/api")
app.include_router(breaches.router, prefix="/api")
app.include_router(ai_chat.router, prefix="/api")
app.include_router(notifications.router, prefix="/api")
app.include_router(features.router, prefix="/api")
app.include_router(search.router, prefix="/api")
app.include_router(timeline.router, prefix="/api")
app.include_router(family.router, prefix="/api")
app.include_router(did.router, prefix="/api")
app.include_router(dao.router, prefix="/api")
app.include_router(darkweb.router, prefix="/api")
app.include_router(reminders.router, prefix="/api")
app.include_router(reports.router, prefix="/api")
app.include_router(smart_import.router, prefix="/api")
app.include_router(websocket.router, prefix="/api")


@app.get("/api/health")
async def health():
    return {"status": "ok", "service": "PrivacyShield API", "version": "2.0.0"}

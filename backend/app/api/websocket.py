from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from datetime import datetime, timezone
import asyncio
import json

router = APIRouter(tags=["websocket"])


class ConnectionManager:
    def __init__(self):
        self.active_connections: dict[int, list[WebSocket]] = {}

    async def connect(self, websocket: WebSocket, user_id: int):
        await websocket.accept()
        if user_id not in self.active_connections:
            self.active_connections[user_id] = []
        self.active_connections[user_id].append(websocket)

    def disconnect(self, websocket: WebSocket, user_id: int):
        if user_id in self.active_connections:
            self.active_connections[user_id] = [
                ws for ws in self.active_connections[user_id] if ws != websocket
            ]
            if not self.active_connections[user_id]:
                del self.active_connections[user_id]

    async def send_to_user(self, user_id: int, message: dict):
        if user_id in self.active_connections:
            for ws in self.active_connections[user_id]:
                try:
                    await ws.send_json(message)
                except Exception:
                    pass

    async def broadcast(self, message: dict):
        for user_id in list(self.active_connections.keys()):
            await self.send_to_user(user_id, message)


manager = ConnectionManager()


@router.websocket("/ws/breach-monitor/{user_id}")
async def breach_monitor_ws(websocket: WebSocket, user_id: int):
    await manager.connect(websocket, user_id)
    try:
        await websocket.send_json({
            "type": "connected",
            "message": "Real-time breach monitoring active",
            "timestamp": datetime.now(timezone.utc).isoformat(),
        })

        while True:
            try:
                data = await asyncio.wait_for(websocket.receive_text(), timeout=30)
                msg = json.loads(data)

                if msg.get("type") == "ping":
                    await websocket.send_json({
                        "type": "pong",
                        "timestamp": datetime.now(timezone.utc).isoformat(),
                    })
                elif msg.get("type") == "subscribe":
                    await websocket.send_json({
                        "type": "subscribed",
                        "channels": msg.get("channels", ["breaches"]),
                        "timestamp": datetime.now(timezone.utc).isoformat(),
                    })
            except asyncio.TimeoutError:
                await websocket.send_json({
                    "type": "heartbeat",
                    "timestamp": datetime.now(timezone.utc).isoformat(),
                    "monitoring": True,
                })
    except WebSocketDisconnect:
        manager.disconnect(websocket, user_id)


async def notify_breach(user_id: int, breach_data: dict):
    await manager.send_to_user(user_id, {
        "type": "breach_alert",
        "data": breach_data,
        "timestamp": datetime.now(timezone.utc).isoformat(),
    })


async def notify_score_change(user_id: int, old_score: int, new_score: int):
    await manager.send_to_user(user_id, {
        "type": "score_update",
        "old_score": old_score,
        "new_score": new_score,
        "timestamp": datetime.now(timezone.utc).isoformat(),
    })

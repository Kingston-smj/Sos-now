import asyncio
from collections import defaultdict

from fastapi import WebSocket


class Hub:
    """Open app connections, keyed by user, so a new incident can be pushed live."""

    def __init__(self) -> None:
        self._rooms: dict[int, set[WebSocket]] = defaultdict(set)
        self._lock = asyncio.Lock()

    async def connect(self, user_id: int, websocket: WebSocket) -> None:
        await websocket.accept()
        async with self._lock:
            self._rooms[user_id].add(websocket)

    def disconnect(self, user_id: int, websocket: WebSocket) -> None:
        self._rooms[user_id].discard(websocket)
        if not self._rooms[user_id]:
            self._rooms.pop(user_id, None)

    async def broadcast(self, message: dict, exclude_user_id: int | None = None) -> None:
        async with self._lock:
            targets = [
                (user_id, socket)
                for user_id, sockets in self._rooms.items()
                if user_id != exclude_user_id
                for socket in sockets
            ]
        dead: list[tuple[int, WebSocket]] = []
        for user_id, socket in targets:
            try:
                await socket.send_json(message)
            except Exception:
                dead.append((user_id, socket))
        for user_id, socket in dead:
            self.disconnect(user_id, socket)

"""
FastAPI Server providing:
1. /ws/telemetry: Live WebSocket streaming of cursor coordinates, keystrokes, and state.
2. /stream/video: Multipart MJPEG virtual desktop live feed.
3. /api/task: REST lifecycle management endpoints (submit, pause, resume, logs).
"""

from __future__ import annotations

import asyncio
from typing import Any, Dict, List, Set
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, StreamingResponse
from pydantic import BaseModel

from src.agent.action_engine import ActionEngine
from src.sandbox.browser import BrowserController


class TaskRequest(BaseModel):
    task: str
    max_steps: int = 10


def create_app(browser: BrowserController, engine: ActionEngine) -> FastAPI:
    app = FastAPI(title="Hark AI Computer-Use Agent", version="1.0.0")

    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    active_websockets: Set[WebSocket] = set()
    execution_logs: List[Dict[str, Any]] = []

    def telemetry_callback(payload: Dict[str, Any]) -> None:
        execution_logs.append(payload)
        asyncio.create_task(broadcast_telemetry(payload))

    engine.set_callback(telemetry_callback)

    async def broadcast_telemetry(data: Dict[str, Any]) -> None:
        disconnected = set()
        for ws in active_websockets:
            try:
                await ws.send_json(data)
            except Exception:
                disconnected.add(ws)
        active_websockets.difference_update(disconnected)

    @app.websocket("/ws/telemetry")
    async def websocket_telemetry(websocket: WebSocket) -> None:
        await websocket.accept()
        active_websockets.add(websocket)
        try:
            while True:
                cursor_event = {
                    "event": "cursor_position",
                    "data": {
                        "x": browser.cursor_x,
                        "y": browser.cursor_y,
                        "is_mouse_down": browser.is_mouse_down,
                    },
                }
                await websocket.send_json(cursor_event)
                await asyncio.sleep(0.05)
        except WebSocketDisconnect:
            active_websockets.discard(websocket)
        except Exception:
            active_websockets.discard(websocket)

    async def video_frame_generator():
        while True:
            try:
                frame_bytes = await browser.capture_screen(with_cursor=True)
                yield (
                    b"--frame\r\n"
                    b"Content-Type: image/jpeg\r\n\r\n" + frame_bytes + b"\r\n"
                )
            except Exception:
                await asyncio.sleep(0.1)
            await asyncio.sleep(0.05)

    @app.get("/stream/video")
    async def stream_video():
        return StreamingResponse(
            video_frame_generator(),
            media_type="multipart/x-mixed-replace; boundary=frame",
        )

    @app.post("/api/task")
    async def start_task(req: TaskRequest):
        if engine.is_running:
            return JSONResponse(status_code=400, content={"error": "Agent is already running a task."})

        asyncio.create_task(engine.run_task(req.task, max_steps=req.max_steps))
        return {"status": "started", "task": req.task}

    @app.post("/api/task/pause")
    async def pause_task():
        engine.is_paused = True
        return {"status": "paused"}

    @app.post("/api/task/resume")
    async def resume_task():
        engine.is_paused = False
        return {"status": "resumed"}

    @app.get("/api/task/status")
    async def get_status():
        return {
            "is_running": engine.is_running,
            "is_paused": engine.is_paused,
            "cursor": {"x": browser.cursor_x, "y": browser.cursor_y},
            "steps_completed": len(engine.history),
        }

    @app.get("/api/task/logs")
    async def get_logs():
        return {"logs": execution_logs[-100:]}

    return app

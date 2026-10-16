"""
FastAPI Server providing:
1. /ws/telemetry: Live WebSocket streaming of cursor coordinates, keystrokes, and state.
2. /stream/video: Multipart MJPEG virtual desktop live feed.
3. /api/task: REST lifecycle management endpoints (submit, pause, resume, abort, status, logs).
4. /api/sdui/compile: Server-Driven UI contract compiler endpoint.
"""

from __future__ import annotations

import asyncio
from contextlib import asynccontextmanager
from typing import Any, Dict, List, Optional, Set
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, StreamingResponse
from pydantic import BaseModel

from src.agent.action_engine import ActionEngine
from src.agent.sdui_engine import SDUICompiler
from src.agent.speculative_planner import MacroPlan
from src.sandbox.browser import BrowserController


class TaskRequest(BaseModel):
    task: str
    max_steps: int = 10
    require_approval: Optional[bool] = None


class SDUICompileRequest(BaseModel):
    prompt: str


class ModelSelectRequest(BaseModel):
    provider: str
    model_name: Optional[str] = None
    api_key: Optional[str] = None
    base_url: Optional[str] = None


class OperatorInputRequest(BaseModel):
    action: str = "click"
    norm_x: Optional[float] = None
    norm_y: Optional[float] = None
    text: Optional[str] = None
    delta_y: Optional[float] = None


class MemoryPreferenceRequest(BaseModel):
    key: str
    value: Any


class VaultSecretRequest(BaseModel):
    handle: str
    secret_value: str


def create_app(
    browser: Optional[BrowserController] = None,
    engine: Optional[ActionEngine] = None,
) -> FastAPI:
    browser_instance = browser or BrowserController(width=1280, height=800, headless=True)
    engine_instance = engine or ActionEngine(browser=browser_instance)

    @asynccontextmanager
    async def lifespan(_app: FastAPI):
        await browser_instance.start()
        try:
            yield
        finally:
            await browser_instance.close()

    app = FastAPI(
        title="Hark AI Computer-Use Agent",
        version="2.0.0",
        lifespan=lifespan,
    )

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
        try:
            loop = asyncio.get_running_loop()
            loop.create_task(broadcast_telemetry(payload))
        except RuntimeError:
            pass

    engine_instance.set_callback(telemetry_callback)

    async def broadcast_telemetry(data: Dict[str, Any]) -> None:
        disconnected = set()
        for ws in list(active_websockets):
            try:
                await ws.send_json(data)
            except Exception:
                disconnected.add(ws)
        active_websockets.difference_update(disconnected)

    @app.get("/health")
    async def health_check():
        return {"status": "ok", "service": "hark-agent", "version": "2.0.0"}

    @app.websocket("/ws/telemetry")
    async def websocket_telemetry(websocket: WebSocket) -> None:
        await websocket.accept()
        active_websockets.add(websocket)
        try:
            while True:
                nx, ny = browser_instance.norm_cursor
                cursor_event = {
                    "event": "cursor_position",
                    "data": {
                        "x": browser_instance.cursor_x,
                        "y": browser_instance.cursor_y,
                        "norm_x": nx,
                        "norm_y": ny,
                        "is_mouse_down": browser_instance.is_mouse_down,
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
                frame_bytes = await browser_instance.capture_screen(with_cursor=True)
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
        if engine_instance.is_running:
            engine_instance.abort()
            await asyncio.sleep(0.1)

        sdui_widget = SDUICompiler.compile_for_prompt(req.task)
        asyncio.create_task(
            engine_instance.run_task(
                req.task,
                max_steps=req.max_steps,
                require_approval=req.require_approval,
            )
        )
        return {
            "status": "started",
            "task": req.task,
            "sdui_widget": sdui_widget,
        }

    @app.post("/api/task/pause")
    async def pause_task():
        engine_instance.is_paused = True
        return {"status": "paused"}

    @app.post("/api/task/resume")
    async def resume_task():
        engine_instance.is_paused = False
        return {"status": "resumed"}

    @app.post("/api/task/approve")
    async def approve_task():
        return engine_instance.approve_pending()

    @app.post("/api/task/abort")
    async def abort_task():
        engine_instance.abort()
        return {"status": "aborted"}

    @app.post("/api/sandbox/input")
    async def sandbox_operator_input(req: OperatorInputRequest):
        result = await browser_instance.operator_input(
            action=req.action,
            norm_x=req.norm_x,
            norm_y=req.norm_y,
            text=req.text,
            delta_y=req.delta_y,
        )
        engine_instance.emit(
            "operator_input",
            {
                "action": req.action,
                "norm_x": result["cursor"]["norm_x"],
                "norm_y": result["cursor"]["norm_y"],
            },
        )
        return result

    @app.post("/api/task/macro")
    async def execute_macro(plan: MacroPlan):
        result = await engine_instance.execute_macro_plan(plan)
        return result

    @app.post("/api/sdui/compile")
    async def compile_sdui(req: SDUICompileRequest):
        return SDUICompiler.compile_for_prompt(req.prompt)

    @app.get("/api/models")
    async def list_models():
        return engine_instance.get_model_catalog()

    @app.post("/api/models/select")
    async def select_model(req: ModelSelectRequest):
        active = engine_instance.configure_model(
            provider=req.provider,
            model_name=req.model_name,
            api_key=req.api_key,
            base_url=req.base_url,
        )
        return {"status": "updated", "active": active}

    @app.get("/api/memory")
    async def get_memory():
        return engine_instance.memory.get_summary(
            vault_handles=engine_instance.vault.list_handles()
        )

    @app.post("/api/memory")
    async def update_memory(req: MemoryPreferenceRequest):
        prefs = engine_instance.memory.remember(req.key, req.value)
        return {"status": "saved", "preferences": prefs}

    @app.get("/api/vault/handles")
    async def list_vault_handles():
        return {"handles": engine_instance.vault.list_handles()}

    @app.post("/api/vault/secret")
    async def set_vault_secret(req: VaultSecretRequest):
        token = engine_instance.vault.set_secret(req.handle, req.secret_value)
        return {"status": "sealed", "handle": token}

    @app.get("/api/task/status")
    async def get_status():
        nx, ny = browser_instance.norm_cursor
        return {
            "is_running": engine_instance.is_running,
            "is_paused": engine_instance.is_paused,
            "pending_approval": engine_instance.pending_approval,
            "current_task": engine_instance.current_task,
            "model": engine_instance.get_active_model_info(),
            "cursor": {
                "x": browser_instance.cursor_x,
                "y": browser_instance.cursor_y,
                "norm_x": nx,
                "norm_y": ny,
            },
            "steps_completed": len(engine_instance.history),
        }

    @app.get("/api/task/logs")
    async def get_logs():
        return {"logs": execution_logs[-100:]}

    return app


app = create_app()

if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=8000, log_level="info")

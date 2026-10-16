from __future__ import annotations

import asyncio
import pytest
from fastapi.testclient import TestClient

from src.agent.action_engine import ActionEngine
from src.agent.sdui_engine import SDUICompiler
from src.agent.speculative_planner import MacroPlan
from src.sandbox.browser import BrowserController
from src.stream.server import create_app


@pytest.mark.asyncio
async def test_browser_controller_and_tagged_screen():
    browser = BrowserController(width=1280, height=800, headless=True)
    try:
        await browser.start()
        frame = await browser.capture_screen(with_cursor=True)
        assert len(frame) > 1000
        assert frame[:2] == b"\xff\xd8"  # JPEG magic bytes

        tagged_bytes, marks = await browser.capture_tagged_screen()
        assert len(tagged_bytes) > 1000
        assert len(marks) >= 3
        nx, ny = browser.norm_cursor
        assert 0.0 <= nx <= 1.0
        assert 0.0 <= ny <= 1.0
    finally:
        await browser.close()


@pytest.mark.asyncio
async def test_action_engine_task_and_sdui():
    browser = BrowserController(width=1280, height=800, headless=True)
    events = []
    engine = ActionEngine(browser=browser, on_step_callback=lambda ev: events.append(ev))
    try:
        res = await engine.run_task("Pay electric bill", max_steps=5)
        assert res["status"] == "success"
        assert "sdui_widget" in res
        assert res["sdui_widget"]["type"] == "action_button"
        event_names = [e["event"] for e in events]
        assert "task_started" in event_names
        assert "remote_widget" in event_names
        assert "action_start" in event_names
        assert "task_finished" in event_names

        action_starts = [e["data"] for e in events if e["event"] == "action_start"]
        assert all(0.0 <= a["norm_x"] <= 1.0 and 0.0 <= a["norm_y"] <= 1.0 for a in action_starts)
    finally:
        await browser.close()


def test_fastapi_endpoints_and_websocket():
    browser = BrowserController(width=1280, height=800, headless=True)
    engine = ActionEngine(browser=browser)
    app = create_app(browser, engine)

    with TestClient(app) as client:
        health = client.get("/health")
        assert health.status_code == 200
        assert health.json()["status"] == "ok"

        status_resp = client.get("/api/task/status")
        assert status_resp.status_code == 200
        status_data = status_resp.json()
        assert "norm_x" in status_data["cursor"]
        assert "norm_y" in status_data["cursor"]

        sdui_resp = client.post("/api/sdui/compile", json={"prompt": "Check my flight"})
        assert sdui_resp.status_code == 200
        assert sdui_resp.json()["id"] == "widget_flight_checkin"

        macro_resp = client.post(
            "/api/task/macro",
            json={
                "plan_name": "quick_search",
                "steps": [{"type": "click", "x": 300, "y": 110}, {"type": "wait", "ms": 20}],
                "expected_outcome": "focused",
            },
        )
        assert macro_resp.status_code == 200
        assert macro_resp.json()["status"] == "success"

        models_resp = client.get("/api/models")
        assert models_resp.status_code == 200
        models_data = models_resp.json()
        assert "gemini" in models_data["providers"]
        assert "anthropic" in models_data["providers"]
        assert "ollama" in models_data["providers"]

        select_resp = client.post(
            "/api/models/select",
            json={"provider": "ollama", "model_name": "qwen2.5vl:7b"},
        )
        assert select_resp.status_code == 200
        assert select_resp.json()["active"]["provider"] == "ollama"
        assert select_resp.json()["active"]["model_name"] == "qwen2.5vl:7b"

        # Test operator input endpoint
        input_resp = client.post(
            "/api/sandbox/input",
            json={"action": "click", "norm_x": 0.42, "norm_y": 0.58},
        )
        assert input_resp.status_code == 200
        assert input_resp.json()["status"] == "executed"
        assert abs(input_resp.json()["cursor"]["norm_x"] - 0.42) < 0.05
        assert abs(input_resp.json()["cursor"]["norm_y"] - 0.58) < 0.05

        # Test memory endpoints
        mem_post = client.post("/api/memory", json={"key": "preferred_seat", "value": "14A"})
        assert mem_post.status_code == 200
        assert mem_post.json()["status"] == "saved"

        mem_get = client.get("/api/memory")
        assert mem_get.status_code == 200
        assert mem_get.json()["preferences"]["preferred_seat"] == "14A"

        # Test zero-knowledge vault endpoints
        vault_post = client.post(
            "/api/vault/secret",
            json={"handle": "delta_login", "secret_value": "SkyMilesSecret99!"},
        )
        assert vault_post.status_code == 200
        assert vault_post.json()["status"] == "sealed"
        assert vault_post.json()["handle"] == "$VAULT:delta_login"

        vault_get = client.get("/api/vault/handles")
        assert vault_get.status_code == 200
        assert "$VAULT:delta_login" in vault_get.json()["handles"]

        # Test approval endpoint
        approve_resp = client.post("/api/task/approve")
        assert approve_resp.status_code == 200

        task_resp = client.post("/api/task", json={"task": "Order pizza", "max_steps": 4})
        assert task_resp.status_code == 200
        assert task_resp.json()["status"] == "started"
        assert task_resp.json()["sdui_widget"]["id"] == "widget_doordash_cart"

        pause_resp = client.post("/api/task/pause")
        assert pause_resp.status_code == 200
        assert pause_resp.json()["status"] == "paused"

        resume_resp = client.post("/api/task/resume")
        assert resume_resp.status_code == 200
        assert resume_resp.json()["status"] == "resumed"

        abort_resp = client.post("/api/task/abort")
        assert abort_resp.status_code == 200
        assert abort_resp.json()["status"] == "aborted"

        parsed_action = ActionEngine._parse_action_json(
            '```json\n{"thought": "Click button", "action": "click", "mark_id": 2}\n```'
        )
        assert parsed_action.action == "click"
        assert parsed_action.mark_id == 2

        with client.websocket_connect("/ws/telemetry") as ws:
            packet = ws.receive_json()
            assert packet["event"] == "cursor_position"
            assert 0.0 <= packet["data"]["norm_x"] <= 1.0
            assert 0.0 <= packet["data"]["norm_y"] <= 1.0


@pytest.mark.asyncio
async def test_zero_knowledge_vault_and_approval_gate():
    browser = BrowserController(width=1280, height=800, headless=True)
    events = []
    engine = ActionEngine(browser=browser, on_step_callback=lambda ev: events.append(ev))
    try:
        # 1. Setup Zero-Knowledge Vault Token
        token = engine.vault.set_secret("pge_pass", "SuperSecretPassword123")
        assert token == "$VAULT:pge_pass"
        assert "$VAULT:pge_pass" in engine.vault.list_handles()

        # 2. Test token resolution at keystroke boundary
        resolved = engine.vault.resolve_token("$VAULT:pge_pass")
        assert resolved == "SuperSecretPassword123"

        # 3. Test token masking
        masked = engine.vault.mask_text("User entered password SuperSecretPassword123 into portal.")
        assert "SuperSecretPassword123" not in masked
        assert "[VAULT:pge_pass]" in masked

        # 4. Test approval gate mechanism
        engine.require_operator_approval = True
        approval_task = asyncio.create_task(
            engine.run_task("Checkout cart with $84.20", max_steps=2, require_approval=True)
        )

        # Allow task to start and hit approval check
        await asyncio.sleep(0.5)
        if engine.pending_approval:
            app_result = engine.approve_pending()
            assert app_result["status"] == "resumed"

        res = await approval_task
        assert res["status"] in ("success", "completed_max_steps")

        # Verify that memory episodes were recorded
        summary = engine.memory.get_summary(vault_handles=engine.vault.list_handles())
        assert summary["total_episodes"] >= 1
        assert "$VAULT:pge_pass" in summary["vault_handles"]
    finally:
        await browser.close()


"""
Action-Prediction Model Engine.
Coordinates multi-modal vision prompts, Set-of-Marks visual element grounding,
action generation, and fallback simulation for Hark computer-use workflows.
"""

from __future__ import annotations

import base64
import json
import os
from typing import Any, Callable, Dict, List, Optional
import httpx
from pydantic import BaseModel, Field

from src.agent.memory_vault import AgentMemory, ZeroKnowledgeVault
from src.agent.sdui_engine import SDUICompiler
from src.agent.speculative_planner import MacroPlan, SpeculativePlanner
from src.sandbox.browser import BrowserController, InteractiveMark
from src.sandbox.dual_stream import DualStreamGrounding


class AgentAction(BaseModel):
    action: str = Field(description="Action name: click, type, scroll, wait, finish, navigate, macro")
    mark_id: Optional[int] = Field(default=None, description="Set-of-Marks ID of the targeted element")
    x: Optional[float] = Field(default=None, description="Direct X coordinate if not targeting mark")
    y: Optional[float] = Field(default=None, description="Direct Y coordinate if not targeting mark")
    text: Optional[str] = Field(default=None, description="Text string to type")
    press_enter: Optional[bool] = Field(default=False, description="Press enter after typing")
    delta_x: Optional[float] = Field(default=0.0, description="Horizontal scroll delta")
    delta_y: Optional[float] = Field(default=0.0, description="Vertical scroll delta")
    seconds: Optional[float] = Field(default=1.0, description="Wait duration")
    url: Optional[str] = Field(default=None, description="Navigation target URL")
    thought: Optional[str] = Field(default="", description="Chain-of-thought rationale")
    result: Optional[str] = Field(default=None, description="Final output answer if finish")
    macro_steps: Optional[List[Dict[str, Any]]] = Field(
        default=None,
        description="Speculative macro batch of atomic steps to execute in a single turn",
    )
    requires_approval: bool = Field(
        default=False,
        description="True when action executes a financial, checkout, or high-stakes commitment",
    )


SUPPORTED_MODEL_PROFILES: Dict[str, Dict[str, Any]] = {
    "gemini": {
        "default_model": "gemini-2.5-pro",
        "models": ["gemini-2.5-pro", "gemini-2.5-flash", "gemini-2.0-flash"],
        "env_key": "GEMINI_API_KEY",
        "base_url": "https://generativelanguage.googleapis.com/v1beta",
        "description": "Google Gemini native multimodal vision & UI grounding",
    },
    "anthropic": {
        "default_model": "claude-sonnet-4-20250514",
        "models": ["claude-sonnet-4-20250514", "claude-3-7-sonnet-latest", "claude-3-5-sonnet-latest"],
        "env_key": "ANTHROPIC_API_KEY",
        "base_url": "https://api.anthropic.com/v1",
        "description": "Anthropic Claude Computer Use & Set-of-Marks reasoning",
    },
    "openai": {
        "default_model": "gpt-4o",
        "models": ["gpt-4o", "gpt-4o-mini", "computer-use-preview"],
        "env_key": "OPENAI_API_KEY",
        "base_url": "https://api.openai.com/v1",
        "description": "OpenAI GPT-4o & CUA multimodal vision reasoning",
    },
    "grok": {
        "default_model": "grok-2-vision-latest",
        "models": ["grok-2-vision-latest", "grok-4"],
        "env_key": "XAI_API_KEY",
        "base_url": "https://api.x.ai/v1",
        "description": "xAI Grok Vision & high-context agentic reasoning",
    },
    "nous": {
        "default_model": "Hermes-4-70B",
        "models": ["Hermes-4-70B", "Hermes-3-Llama-3.1-70B"],
        "env_key": "NOUS_API_KEY",
        "base_url": "https://inference-api.nousresearch.com/v1",
        "description": "Nous Research Hermes structured JSON & tool-use engine",
    },
    "openrouter": {
        "default_model": "qwen/qwen-2.5-vl-72b-instruct",
        "models": [
            "qwen/qwen-2.5-vl-72b-instruct",
            "bytedance/ui-tars-72b",
            "anthropic/claude-3.7-sonnet",
            "google/gemini-2.5-pro",
        ],
        "env_key": "OPENROUTER_API_KEY",
        "base_url": "https://openrouter.ai/api/v1",
        "description": "Unified OpenRouter gateway for Qwen-VL, UI-TARS, Claude, and Gemini",
    },
    "ollama": {
        "default_model": "qwen2.5vl:7b",
        "models": ["qwen2.5vl:7b", "qwen2.5vl:72b", "ui-tars:7b", "dots-vlm1:latest", "llava:13b"],
        "env_key": "OLLAMA_HOST",
        "base_url": "http://127.0.0.1:11434/v1",
        "description": "Local zero-cost open-weight VLM execution via Ollama / vLLM",
    },
    "simulator": {
        "default_model": "hark-action-sim-v2",
        "models": ["hark-action-sim-v2"],
        "env_key": "",
        "base_url": "local://sandbox",
        "description": "Deterministic low-latency Set-of-Marks action simulator",
    },
}


class ActionEngine:
    """Orchestrates action-prediction loop between visual browser state and LLM."""

    SYSTEM_PROMPT = (
        "You are Hark, an autonomous computer-use vision agent. "
        "You receive a desktop screenshot tagged with Set-of-Marks (numbered badges). "
        "Predict the single next action to complete the user's task.\n"
        "Respond strictly in valid JSON matching this schema:\n"
        "{\n"
        '  "thought": "Reasoning for the step",\n'
        '  "action": "click" | "type" | "scroll" | "wait" | "navigate" | "finish",\n'
        '  "mark_id": <int or null>,\n'
        '  "text": <string or null>,\n'
        '  "press_enter": <bool>,\n'
        '  "delta_y": <float or null>,\n'
        '  "url": <string or null>,\n'
        '  "result": <string or null>\n'
        "}"
    )

    def __init__(
        self,
        browser: BrowserController,
        api_key: Optional[str] = None,
        model_name: Optional[str] = None,
        provider: Optional[str] = None,
        base_url: Optional[str] = None,
        on_step_callback: Optional[Callable[[Dict[str, Any]], None]] = None,
        memory: Optional[AgentMemory] = None,
    ):
        self.browser = browser
        self.on_step_callback = on_step_callback
        self.sdui_compiler = SDUICompiler()
        self.speculative_planner = SpeculativePlanner(browser)
        self.memory = memory or AgentMemory()
        self.vault: ZeroKnowledgeVault = browser.vault
        self.is_paused = False
        self.is_running = False
        self.require_operator_approval = False
        self.pending_approval = False
        self.current_task: Optional[str] = None
        self.history: List[Dict[str, Any]] = []

        self.provider: str = "simulator"
        self.model_name: str = "hark-action-sim-v2"
        self.api_key: Optional[str] = None
        self.base_url: str = "local://sandbox"
        self.configure_model(
            provider=provider or os.getenv("HARK_PROVIDER"),
            model_name=model_name or os.getenv("HARK_MODEL"),
            api_key=api_key,
            base_url=base_url or os.getenv("HARK_BASE_URL"),
        )

    def configure_model(
        self,
        provider: Optional[str] = None,
        model_name: Optional[str] = None,
        api_key: Optional[str] = None,
        base_url: Optional[str] = None,
    ) -> Dict[str, Any]:
        """Resolves provider, model name, API key, and endpoint for multimodal grounding."""
        resolved_provider = (provider or "").strip().lower()

        if not resolved_provider or resolved_provider == "auto":
            if api_key or os.getenv("GEMINI_API_KEY") or os.getenv("GOOGLE_API_KEY"):
                if not api_key and (os.getenv("GEMINI_API_KEY") or os.getenv("GOOGLE_API_KEY")):
                    resolved_provider = "gemini"
            if not resolved_provider or resolved_provider == "auto":
                if os.getenv("ANTHROPIC_API_KEY"):
                    resolved_provider = "anthropic"
                elif os.getenv("OPENAI_API_KEY"):
                    resolved_provider = "openai"
                elif os.getenv("XAI_API_KEY"):
                    resolved_provider = "grok"
                elif os.getenv("OPENROUTER_API_KEY"):
                    resolved_provider = "openrouter"
                elif os.getenv("NOUS_API_KEY"):
                    resolved_provider = "nous"
                elif os.getenv("OLLAMA_HOST"):
                    resolved_provider = "ollama"
                elif api_key:
                    resolved_provider = "openai"
                else:
                    resolved_provider = "simulator"

        if resolved_provider not in SUPPORTED_MODEL_PROFILES:
            resolved_provider = "openai"

        profile = SUPPORTED_MODEL_PROFILES[resolved_provider]
        self.provider = resolved_provider
        self.model_name = model_name or profile["default_model"]
        self.base_url = (base_url or profile["base_url"]).rstrip("/")

        if api_key:
            self.api_key = api_key
        elif resolved_provider == "gemini":
            self.api_key = os.getenv("GEMINI_API_KEY") or os.getenv("GOOGLE_API_KEY")
        elif resolved_provider == "ollama":
            self.api_key = "ollama"
            if os.getenv("OLLAMA_HOST") and not base_url:
                host = os.getenv("OLLAMA_HOST", "http://127.0.0.1:11434").rstrip("/")
                self.base_url = f"{host}/v1" if not host.endswith("/v1") else host
        elif profile["env_key"]:
            self.api_key = os.getenv(profile["env_key"])
        else:
            self.api_key = None

        return self.get_active_model_info()

    def get_active_model_info(self) -> Dict[str, Any]:
        return {
            "provider": self.provider,
            "model_name": self.model_name,
            "base_url": self.base_url,
            "has_api_key": bool(self.api_key),
            "effective_mode": (
                "live_llm"
                if (self.provider != "simulator" and bool(self.api_key))
                else "fallback_simulator"
            ),
        }

    def get_model_catalog(self) -> Dict[str, Any]:
        return {
            "active": self.get_active_model_info(),
            "providers": SUPPORTED_MODEL_PROFILES,
        }

    def set_callback(self, callback: Callable[[Dict[str, Any]], None]) -> None:
        self.on_step_callback = callback

    def emit(self, event_type: str, data: Dict[str, Any]) -> None:
        if self.on_step_callback:
            self.on_step_callback({"event": event_type, "data": data})

    def approve_pending(self) -> Dict[str, Any]:
        """Approves a pending high-stakes action gated by operator/biometric auth."""
        self.pending_approval = False
        self.is_paused = False
        self.emit("approval_granted", {"task": self.current_task})
        return {"status": "approved", "task": self.current_task}

    def abort(self) -> None:
        """Aborts any currently running or paused task."""
        self.is_running = False
        self.is_paused = False
        self.pending_approval = False
        self.emit("task_aborted", {"task": self.current_task})

    @staticmethod
    def _parse_action_json(raw_text: str) -> AgentAction:
        cleaned = raw_text.strip()
        if cleaned.startswith("```"):
            lines = cleaned.splitlines()
            if lines and lines[0].startswith("```"):
                lines = lines[1:]
            if lines and lines[-1].strip().startswith("```"):
                lines = lines[:-1]
            cleaned = "\n".join(lines).strip()
        start = cleaned.find("{")
        end = cleaned.rfind("}")
        if start != -1 and end != -1 and end > start:
            cleaned = cleaned[start : end + 1]
        parsed = json.loads(cleaned)
        return AgentAction(**parsed)

    async def predict_next_action(
        self, task: str, tagged_image_bytes: bytes, marks: List[InteractiveMark]
    ) -> AgentAction:
        """Queries configured Vision LLM provider or uses deterministic simulation fallback."""
        if self.provider == "simulator" or not self.api_key:
            return await self._simulate_action(task, marks)

        b64_image = base64.b64encode(tagged_image_bytes).decode("utf-8")
        elements_summary = "\n".join(
            [
                f"ID [{m.mark_id}] <{m.tag_name} role='{m.role}' sel='{m.selector}'> '{m.text}' at ({m.x}, {m.y})"
                for m in marks[:40]
            ]
        )
        memory_context = self.memory.get_context_prompt(self.vault.list_handles())
        prompt_text = (
            f"Task: {task}\n"
            f"{memory_context}\n"
            f"Interactive Elements (Dual-Stream SoM + AXTree):\n{elements_summary}"
        )

        try:
            async with httpx.AsyncClient(timeout=30.0) as client:
                if self.provider == "gemini":
                    url = f"{self.base_url}/models/{self.model_name}:generateContent?key={self.api_key}"
                    resp = await client.post(
                        url,
                        headers={"Content-Type": "application/json"},
                        json={
                            "systemInstruction": {"parts": [{"text": self.SYSTEM_PROMPT}]},
                            "contents": [
                                {
                                    "role": "user",
                                    "parts": [
                                        {"text": prompt_text},
                                        {
                                            "inline_data": {
                                                "mime_type": "image/jpeg",
                                                "data": b64_image,
                                            }
                                        },
                                    ],
                                }
                            ],
                            "generationConfig": {"responseMimeType": "application/json"},
                        },
                    )
                    resp.raise_for_status()
                    data = resp.json()
                    content = data["candidates"][0]["content"]["parts"][0]["text"]
                    return self._parse_action_json(content)

                if self.provider == "anthropic":
                    resp = await client.post(
                        f"{self.base_url}/messages",
                        headers={
                            "x-api-key": self.api_key,
                            "anthropic-version": "2023-06-01",
                            "Content-Type": "application/json",
                        },
                        json={
                            "model": self.model_name,
                            "max_tokens": 1024,
                            "system": self.SYSTEM_PROMPT,
                            "messages": [
                                {
                                    "role": "user",
                                    "content": [
                                        {
                                            "type": "image",
                                            "source": {
                                                "type": "base64",
                                                "media_type": "image/jpeg",
                                                "data": b64_image,
                                            },
                                        },
                                        {"type": "text", "text": prompt_text},
                                    ],
                                }
                            ],
                        },
                    )
                    resp.raise_for_status()
                    data = resp.json()
                    content = data["content"][0]["text"]
                    return self._parse_action_json(content)

                # OpenAI-compatible providers: openai, grok, openrouter, nous, ollama
                user_content: Any = [
                    {"type": "text", "text": prompt_text},
                    {
                        "type": "image_url",
                        "image_url": {"url": f"data:image/jpeg;base64,{b64_image}"},
                    },
                ]
                payload: Dict[str, Any] = {
                    "model": self.model_name,
                    "messages": [
                        {"role": "system", "content": self.SYSTEM_PROMPT},
                        {"role": "user", "content": user_content},
                    ],
                }
                if self.provider in ("openai", "ollama"):
                    payload["response_format"] = {"type": "json_object"}

                resp = await client.post(
                    f"{self.base_url}/chat/completions",
                    headers={
                        "Authorization": f"Bearer {self.api_key}",
                        "Content-Type": "application/json",
                    },
                    json=payload,
                )
                resp.raise_for_status()
                data = resp.json()
                content = data["choices"][0]["message"]["content"]
                return self._parse_action_json(content)
        except Exception as e:
            self.emit(
                "error",
                {
                    "message": f"Vision LLM ({self.provider}/{self.model_name}) failed: {e}. Falling back to simulation."
                },
            )
            return await self._simulate_action(task, marks)

    async def _simulate_action(self, task: str, marks: List[InteractiveMark]) -> AgentAction:
        """Deterministic fallback simulator with Speculative Macro Batching and $VAULT injection."""
        step_count = len(self.history)
        lower_task = task.lower()
        if step_count == 0:
            search_input = next(
                (m for m in marks if "search" in m.text.lower() or m.tag_name in ("input", "textarea")),
                None,
            )
            if search_input:
                typed_payload = task
                if any(k in lower_task for k in ("bill", "pge", "electric", "pay")) and "$VAULT:" not in task:
                    typed_payload = f"{task} [Token: $VAULT:chase_ach_token]"
                cx, cy = search_input.center
                return AgentAction(
                    thought=f"Identified input #{search_input.mark_id} ({search_input.selector}). Executing speculative focus + type macro.",
                    action="type",
                    mark_id=search_input.mark_id,
                    text=typed_payload,
                    press_enter=True,
                    macro_steps=[
                        {"type": "click", "x": cx, "y": cy},
                        {"type": "type", "text": typed_payload, "press_enter": True},
                    ],
                )
            return AgentAction(
                thought="Navigating to target web resource",
                action="navigate",
                url="https://news.ycombinator.com",
            )
        elif step_count == 1:
            clickables = [m for m in marks if m.tag_name in ("a", "button")]
            preferred = None
            is_high_stakes = False
            if any(k in lower_task for k in ("bill", "pge", "electric", "pay")):
                preferred = next((m for m in clickables if "pay" in m.text.lower()), None)
                is_high_stakes = True
            elif any(k in lower_task for k in ("flight", "delta", "check")):
                preferred = next((m for m in clickables if "check" in m.text.lower()), None)
            elif any(k in lower_task for k in ("pizza", "order", "food")):
                preferred = next((m for m in clickables if "order" in m.text.lower()), None)
                is_high_stakes = True

            clickable = preferred or next(iter(clickables), None)
            if clickable:
                return AgentAction(
                    thought=f"Clicking element #{clickable.mark_id} ('{clickable.text}') via Dual-Stream Grounding ({clickable.selector})",
                    action="click",
                    mark_id=clickable.mark_id,
                    requires_approval=is_high_stakes,
                )
            return AgentAction(thought="Scrolling down page", action="scroll", delta_y=300)
        elif step_count == 2:
            return AgentAction(thought="Verifying transaction confirmation on viewport", action="scroll", delta_y=200)
        else:
            return AgentAction(
                thought="Task goal satisfied from page observation.",
                action="finish",
                result=f"Completed task '{self.vault.mask_text(task)}' successfully.",
            )

    async def execute_action(self, action: AgentAction, step_index: int = 0) -> None:
        """Translates high-level AgentAction into browser actions with Dual-Stream fallback & Speculative Batching."""
        target_x, target_y = action.x, action.y
        dom_selector = ""
        if action.mark_id and action.mark_id in self.browser.last_marks:
            mark = self.browser.last_marks[action.mark_id]
            target_x, target_y = mark.center
            dom_selector = mark.selector or f"{mark.tag_name}[mark='{mark.mark_id}']"

        if target_x is None:
            target_x = self.browser.cursor_x
        if target_y is None:
            target_y = self.browser.cursor_y

        norm_x = round(max(0.0, min(1.0, target_x / float(self.browser.width))), 4)
        norm_y = round(max(0.0, min(1.0, target_y / float(self.browser.height))), 4)

        payload = action.model_dump()
        if payload.get("text"):
            payload["text"] = self.vault.mask_text(str(payload["text"]))
        if payload.get("macro_steps"):
            masked_steps = []
            for st in payload["macro_steps"]:
                st_copy = dict(st)
                if st_copy.get("text"):
                    st_copy["text"] = self.vault.mask_text(str(st_copy["text"]))
                masked_steps.append(st_copy)
            payload["macro_steps"] = masked_steps

        payload.update(
            {
                "x": target_x,
                "y": target_y,
                "norm_x": norm_x,
                "norm_y": norm_y,
                "active_step": step_index,
                "dom_selector": dom_selector,
            }
        )

        # High-Stakes Biometric / Operator Approval Gate
        if action.requires_approval and self.require_operator_approval:
            self.pending_approval = True
            self.emit(
                "approval_required",
                {
                    "task": self.current_task,
                    "step": step_index,
                    "thought": action.thought,
                    "dom_selector": dom_selector,
                },
            )
            while self.pending_approval and self.is_running:
                import asyncio
                await asyncio.sleep(0.2)
            if not self.is_running:
                return

        self.emit("action_start", payload)

        if action.macro_steps:
            plan = MacroPlan(
                plan_name=f"speculative_step_{step_index}",
                steps=action.macro_steps,
                expected_outcome=action.thought or "macro_completed",
            )
            await self.speculative_planner.execute_macro_batch(plan)

        elif action.action == "navigate" and action.url:
            await self.browser.navigate(action.url)

        elif action.action == "click":
            page = await self.browser.ensure_page()
            if page is not None and dom_selector:
                await DualStreamGrounding.click_with_fallback(
                    page=page,
                    norm_x=norm_x * 1000.0,
                    norm_y=norm_y * 1000.0,
                    fallback_selector=dom_selector,
                    screen_width=self.browser.width,
                    screen_height=self.browser.height,
                )
            await self.browser.human_click(target_x, target_y)

        elif action.action == "type":
            if action.mark_id and action.mark_id in self.browser.last_marks:
                await self.browser.human_click(target_x, target_y)

            if action.text:
                await self.browser.human_type(action.text, press_enter=bool(action.press_enter))

        elif action.action == "scroll":
            await self.browser.scroll(action.delta_x or 0.0, action.delta_y or 300.0)

        elif action.action == "wait":
            import asyncio
            await asyncio.sleep(action.seconds or 1.0)

        self.emit(
            "action_end",
            {
                "action": action.action,
                "active_step": step_index,
                "x": self.browser.cursor_x,
                "y": self.browser.cursor_y,
                "norm_x": self.browser.norm_cursor[0],
                "norm_y": self.browser.norm_cursor[1],
            },
        )

    async def execute_macro_plan(self, plan: MacroPlan) -> Dict[str, Any]:
        """Executes a speculative macro-action batch."""
        self.emit("macro_plan_started", plan.model_dump())
        ok = await self.speculative_planner.execute_macro_batch(plan)
        self.emit("macro_plan_finished", {"plan_name": plan.plan_name, "success": ok})
        return {"status": "success" if ok else "failed", "plan_name": plan.plan_name}

    async def run_task(
        self,
        task: str,
        max_steps: int = 10,
        require_approval: Optional[bool] = None,
    ) -> Dict[str, Any]:
        """Main agent perception-action loop."""
        self.is_running = True
        self.is_paused = False
        self.pending_approval = False
        if require_approval is not None:
            self.require_operator_approval = require_approval
        self.current_task = task
        self.history = []

        sdui_widget = self.sdui_compiler.compile_for_prompt(task)
        self.emit("task_started", {"task": task, "sdui_widget": sdui_widget})
        self.emit("remote_widget", sdui_widget)

        try:
            for step in range(max_steps):
                while self.is_paused and self.is_running:
                    import asyncio
                    await asyncio.sleep(0.3)

                if not self.is_running:
                    self.memory.record_episode(task, "aborted", None, len(self.history))
                    return {"status": "aborted", "steps": self.history}

                tagged_bytes, marks = await self.browser.capture_tagged_screen()
                action = await self.predict_next_action(task, tagged_bytes, marks)
                logged_action = action.model_dump()
                if logged_action.get("text"):
                    logged_action["text"] = self.vault.mask_text(str(logged_action["text"]))
                if logged_action.get("macro_steps"):
                    logged_action["macro_steps"] = [
                        {
                            **st,
                            "text": self.vault.mask_text(str(st["text"]))
                            if st.get("text")
                            else st.get("text"),
                        }
                        for st in logged_action["macro_steps"]
                    ]
                self.history.append({"step": step, "action": logged_action})

                if action.action == "finish":
                    self.memory.record_episode(task, "success", action.result, len(self.history))
                    self.emit(
                        "task_finished",
                        {
                            "task": task,
                            "result": action.result,
                            "steps_completed": len(self.history),
                        },
                    )
                    return {
                        "status": "success",
                        "result": action.result,
                        "sdui_widget": sdui_widget,
                        "steps": self.history,
                    }

                await self.execute_action(action, step_index=step)

            result_msg = f"Completed {max_steps} steps for '{self.vault.mask_text(task)}'."
            self.memory.record_episode(task, "completed_max_steps", result_msg, len(self.history))
            self.emit(
                "task_finished",
                {
                    "task": task,
                    "result": result_msg,
                    "steps_completed": len(self.history),
                },
            )
            return {
                "status": "completed_max_steps",
                "sdui_widget": sdui_widget,
                "steps": self.history,
            }
        finally:
            self.is_running = False
            self.pending_approval = False

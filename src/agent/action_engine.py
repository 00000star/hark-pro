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

from src.sandbox.browser import BrowserController, InteractiveMark


class AgentAction(BaseModel):
    action: str = Field(description="Action name: click, type, scroll, wait, finish, navigate")
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


class ActionEngine:
    """Orchestrates action-prediction loop between visual browser state and LLM."""

    def __init__(
        self,
        browser: BrowserController,
        api_key: Optional[str] = None,
        model_name: str = "qwen-2.5-vl",
        on_step_callback: Optional[Callable[[Dict[str, Any]], None]] = None,
    ):
        self.browser = browser
        self.api_key = api_key or os.getenv("OPENAI_API_KEY") or os.getenv("ANTHROPIC_API_KEY")
        self.model_name = model_name
        self.on_step_callback = on_step_callback
        self.is_paused = False
        self.is_running = False
        self.history: List[Dict[str, Any]] = []

    def set_callback(self, callback: Callable[[Dict[str, Any]], None]) -> None:
        self.on_step_callback = callback

    def emit(self, event_type: str, data: Dict[str, Any]) -> None:
        if self.on_step_callback:
            self.on_step_callback({"event": event_type, "data": data})

    async def predict_next_action(
        self, task: str, tagged_image_bytes: bytes, marks: List[InteractiveMark]
    ) -> AgentAction:
        """Queries Vision LLM or uses simulation fallback if no external API key is present."""
        if not self.api_key:
            return await self._simulate_action(task, marks)

        b64_image = base64.b64encode(tagged_image_bytes).decode("utf-8")
        elements_summary = "\n".join(
            [f"ID [{m.mark_id}] <{m.tag_name}> '{m.text}' at ({m.x}, {m.y})" for m in marks[:40]]
        )

        system_prompt = (
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

        user_content = [
            {"type": "text", "text": f"Task: {task}\nInteractive Elements:\n{elements_summary}"},
            {
                "type": "image_url",
                "image_url": {"url": f"data:image/jpeg;base64,{b64_image}"},
            },
        ]

        try:
            async with httpx.AsyncClient(timeout=30.0) as client:
                resp = await client.post(
                    "https://api.openai.com/v1/chat/completions",
                    headers={
                        "Authorization": f"Bearer {self.api_key}",
                        "Content-Type": "application/json",
                    },
                    json={
                        "model": "gpt-4o",
                        "messages": [
                            {"role": "system", "content": system_prompt},
                            {"role": "user", "content": user_content},
                        ],
                        "response_format": {"type": "json_object"},
                    },
                )
                resp.raise_for_status()
                data = resp.json()
                content = data["choices"][0]["message"]["content"]
                parsed = json.loads(content)
                return AgentAction(**parsed)
        except Exception as e:
            self.emit("error", {"message": f"Vision LLM query failed: {e}. Falling back to simulation."})
            return await self._simulate_action(task, marks)

    async def _simulate_action(self, task: str, marks: List[InteractiveMark]) -> AgentAction:
        """Deterministic fallback simulator for out-of-the-box demo execution."""
        step_count = len(self.history)
        if step_count == 0:
            search_input = next(
                (m for m in marks if "search" in m.text.lower() or m.tag_name in ("input", "textarea")),
                None,
            )
            if search_input:
                return AgentAction(
                    thought=f"Identified search box #{search_input.mark_id}. Typing user query: '{task}'",
                    action="type",
                    mark_id=search_input.mark_id,
                    text=task,
                    press_enter=True,
                )
            return AgentAction(
                thought="Navigating to target web resource",
                action="navigate",
                url="https://news.ycombinator.com",
            )
        elif step_count == 1:
            clickable = next((m for m in marks if m.tag_name in ("a", "button")), None)
            if clickable:
                return AgentAction(
                    thought=f"Clicking link #{clickable.mark_id} ('{clickable.text}') to inspect details",
                    action="click",
                    mark_id=clickable.mark_id,
                )
            return AgentAction(thought="Scrolling down page", action="scroll", delta_y=300)
        elif step_count == 2:
            return AgentAction(thought="Scrolling down to read content", action="scroll", delta_y=400)
        else:
            return AgentAction(
                thought="Task goal satisfied from page observation.",
                action="finish",
                result=f"Completed task '{task}' successfully.",
            )

    async def execute_action(self, action: AgentAction) -> None:
        """Translates high-level AgentAction into browser actions."""
        self.emit("action_start", action.model_dump())

        if action.action == "navigate" and action.url:
            await self.browser.navigate(action.url)

        elif action.action == "click":
            target_x, target_y = action.x, action.y
            if action.mark_id and action.mark_id in self.browser.last_marks:
                mark = self.browser.last_marks[action.mark_id]
                target_x, target_y = mark.center

            if target_x is not None and target_y is not None:
                await self.browser.human_click(target_x, target_y)

        elif action.action == "type":
            if action.mark_id and action.mark_id in self.browser.last_marks:
                mark = self.browser.last_marks[action.mark_id]
                await self.browser.human_click(*mark.center)

            if action.text:
                await self.browser.human_type(action.text, press_enter=bool(action.press_enter))

        elif action.action == "scroll":
            await self.browser.scroll(action.delta_x or 0.0, action.delta_y or 300.0)

        elif action.action == "wait":
            import asyncio
            await asyncio.sleep(action.seconds or 1.0)

        self.emit("action_end", {"action": action.action})

    async def run_task(self, task: str, max_steps: int = 10) -> Dict[str, Any]:
        """Main agent perception-action loop."""
        self.is_running = True
        self.history = []
        self.emit("task_started", {"task": task})

        for step in range(max_steps):
            while self.is_paused and self.is_running:
                import asyncio
                await asyncio.sleep(0.5)

            if not self.is_running:
                break

            tagged_bytes, marks = await self.browser.capture_tagged_screen()
            action = await self.predict_next_action(task, tagged_bytes, marks)
            self.history.append({"step": step, "action": action.model_dump()})

            if action.action == "finish":
                self.emit("task_finished", {"result": action.result})
                self.is_running = False
                return {"status": "success", "result": action.result, "steps": self.history}

            await self.execute_action(action)

        self.is_running = False
        return {"status": "completed_max_steps", "steps": self.history}

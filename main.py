"""
CLI & Server Entrypoint for Hark (Handoff) AI Computer-Use Agent.
"""

from __future__ import annotations

import argparse
import asyncio
import uvicorn

from src.agent.action_engine import ActionEngine
from src.sandbox.browser import BrowserController
from src.stream.server import create_app


def parse_args():
    parser = argparse.ArgumentParser(description="Hark Computer-Use AI Agent")
    parser.add_argument("--host", type=str, default="0.0.0.0", help="Host interface to bind")
    parser.add_argument("--port", type=int, default=8000, help="Port to listen on")
    parser.add_argument("--headless", action="store_true", default=True, help="Run browser headless")
    parser.add_argument("--task", type=str, default=None, help="Directly execute a single task")
    parser.add_argument(
        "--provider",
        type=str,
        default=None,
        help="Vision LLM provider: auto, gemini, anthropic, openai, grok, nous, openrouter, ollama, simulator",
    )
    parser.add_argument("--model", type=str, default=None, help="Model name override (e.g., gemini-2.5-pro, qwen2.5vl:7b)")
    parser.add_argument("--base-url", type=str, default=None, help="Custom OpenAI-compatible base URL")
    return parser.parse_args()


async def run_single_cli_task(
    task_str: str,
    provider: str | None = None,
    model_name: str | None = None,
    base_url: str | None = None,
):
    browser = BrowserController(width=1280, height=800, headless=True)
    engine = ActionEngine(
        browser=browser,
        provider=provider,
        model_name=model_name,
        base_url=base_url,
    )
    try:
        await browser.start()
        info = engine.get_active_model_info()
        print(f"[*] Executing task: '{task_str}' (provider={info['provider']}, model={info['model_name']})")
        result = await engine.run_task(task_str)
        print(f"[✓] Task Result: {result}")
    finally:
        await browser.close()


def main():
    args = parse_args()

    if args.task:
        asyncio.run(
            run_single_cli_task(
                args.task,
                provider=args.provider,
                model_name=args.model,
                base_url=args.base_url,
            )
        )
        return

    browser = BrowserController(width=1280, height=800, headless=args.headless)
    engine = ActionEngine(
        browser=browser,
        provider=args.provider,
        model_name=args.model,
        base_url=args.base_url,
    )
    app = create_app(browser, engine)

    info = engine.get_active_model_info()
    print(
        f"[*] Launching Hark Agent on http://{args.host}:{args.port} "
        f"[provider={info['provider']}, model={info['model_name']}]"
    )
    uvicorn.run(app, host=args.host, port=args.port, log_level="info")


if __name__ == "__main__":
    main()

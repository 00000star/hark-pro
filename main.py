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
    return parser.parse_args()


async def run_single_cli_task(task_str: str):
    browser = BrowserController(width=1280, height=800, headless=True)
    engine = ActionEngine(browser=browser)
    try:
        await browser.start()
        print(f"[*] Executing task: '{task_str}'")
        result = await engine.run_task(task_str)
        print(f"[✓] Task Result: {result}")
    finally:
        await browser.close()


def main():
    args = parse_args()

    if args.task:
        asyncio.run(run_single_cli_task(args.task))
        return

    browser = BrowserController(width=1280, height=800, headless=args.headless)
    engine = ActionEngine(browser=browser)
    app = create_app(browser, engine)

    @app.on_event("startup")
    async def startup_event():
        await browser.start()

    @app.on_event("shutdown")
    async def shutdown_event():
        await browser.close()

    print(f"[*] Launching Hark Agent on http://{args.host}:{args.port}")
    uvicorn.run(app, host=args.host, port=args.port, log_level="info")


if __name__ == "__main__":
    main()

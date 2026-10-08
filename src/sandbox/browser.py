"""
Virtual Computer Browser Controller.
Manages Playwright instances, Set-of-Marks (SoM) visual badge tagging,
human-like mouse and keyboard movements, and screenshot rendering.
"""

from __future__ import annotations

import asyncio
import io
import math
import random
from dataclasses import dataclass
from typing import Any, Dict, List, Optional, Tuple

from PIL import Image, ImageDraw, ImageFont

try:
    from playwright.async_api import Browser, BrowserContext, Page, async_playwright
except ImportError:
    Browser = Any
    BrowserContext = Any
    Page = Any
    async_playwright = None


@dataclass
class InteractiveMark:
    mark_id: int
    tag_name: str
    text: str
    x: float
    y: float
    width: float
    height: float

    @property
    def center(self) -> Tuple[float, float]:
        return (self.x + self.width / 2.0, self.y + self.height / 2.0)


class BrowserController:
    """Controls virtual browser environment, viewport telemetry, and visual tagging."""

    def __init__(self, width: int = 1280, height: int = 800, headless: bool = True):
        self.width = width
        self.height = height
        self.headless = headless
        self._playwright = None
        self._browser: Optional[Browser] = None
        self._context: Optional[BrowserContext] = None
        self._page: Optional[Page] = None
        self.cursor_x: float = width / 2.0
        self.cursor_y: float = height / 2.0
        self.is_mouse_down: bool = False
        self.last_marks: Dict[int, InteractiveMark] = {}
        self.lock = asyncio.Lock()

    async def start(self) -> None:
        """Launches Playwright Chromium session with configured viewport."""
        if self._browser is not None:
            return

        if async_playwright is None:
            print("[WARN] Playwright not installed. Running in mock browser mode.")
            return

        self._playwright = await async_playwright().start()
        self._browser = await self._playwright.chromium.launch(
            headless=self.headless,
            args=[
                "--no-sandbox",
                "--disable-setuid-sandbox",
                "--disable-dev-shm-usage",
                "--disable-blink-features=AutomationControlled",
                f"--window-size={self.width},{self.height}",
            ],
        )
        self._context = await self._browser.new_context(
            viewport={"width": self.width, "height": self.height},
            user_agent=(
                "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 "
                "(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36 HarkAgent/1.0"
            ),
        )
        self._page = await self._context.new_page()
        await self._page.goto("https://www.google.com", wait_until="domcontentloaded")

    async def close(self) -> None:
        """Closes browser session cleanly."""
        if self._context:
            await self._context.close()
        if self._browser:
            await self._browser.close()
        if self._playwright:
            await self._playwright.stop()
        self._page = None
        self._context = None
        self._browser = None
        self._playwright = None

    async def ensure_page(self) -> Optional[Page]:
        if self._page is None and async_playwright is not None:
            await self.start()
        return self._page

    async def navigate(self, url: str) -> None:
        page = await self.ensure_page()
        if page is None:
            return
        if not (url.startswith("http://") or url.startswith("https://")):
            url = f"https://{url}"
        await page.goto(url, wait_until="networkidle", timeout=30000)

    async def smooth_move_mouse(self, target_x: float, target_y: float, steps: int = 15) -> None:
        """Moves cursor to target with Bezier curve easing to simulate human hand."""
        page = await self.ensure_page()
        start_x, start_y = self.cursor_x, self.cursor_y
        ctrl_x = (start_x + target_x) / 2.0 + random.uniform(-40, 40)
        ctrl_y = (start_y + target_y) / 2.0 + random.uniform(-40, 40)

        for step in range(1, steps + 1):
            t = step / steps
            cur_x = (1 - t) ** 2 * start_x + 2 * (1 - t) * t * ctrl_x + t**2 * target_x
            cur_y = (1 - t) ** 2 * start_y + 2 * (1 - t) * t * ctrl_y + t**2 * target_y
            self.cursor_x = cur_x
            self.cursor_y = cur_y
            if page:
                await page.mouse.move(cur_x, cur_y)
            await asyncio.sleep(random.uniform(0.005, 0.015))

        self.cursor_x = target_x
        self.cursor_y = target_y
        if page:
            await page.mouse.move(target_x, target_y)

    async def human_click(self, x: float, y: float, click_count: int = 1) -> None:
        """Simulates human click with movement, press delay, and release."""
        page = await self.ensure_page()
        await self.smooth_move_mouse(x, y)
        for _ in range(click_count):
            self.is_mouse_down = True
            if page:
                await page.mouse.down()
            await asyncio.sleep(random.uniform(0.04, 0.09))
            self.is_mouse_down = False
            if page:
                await page.mouse.up()
            await asyncio.sleep(random.uniform(0.05, 0.12))

    async def human_type(self, text: str, press_enter: bool = False) -> None:
        """Types text with natural human keystroke jitter."""
        page = await self.ensure_page()
        if not page:
            return
        for char in text:
            await page.keyboard.type(char)
            await asyncio.sleep(random.uniform(0.03, 0.11))
        if press_enter:
            await asyncio.sleep(random.uniform(0.1, 0.25))
            await page.keyboard.press("Enter")

    async def scroll(self, delta_x: float, delta_y: float) -> None:
        """Smoothly scrolls page viewport."""
        page = await self.ensure_page()
        if page:
            await page.mouse.wheel(delta_x, delta_y)
        await asyncio.sleep(0.3)

    async def extract_interactive_elements(self) -> List[InteractiveMark]:
        """Extracts visible interactive elements from DOM for Set-of-Marks visual prompting."""
        page = await self.ensure_page()
        if not page:
            # Fallback mock marks
            mock_marks = [
                InteractiveMark(1, "input", "Search Google", 300, 250, 400, 40),
                InteractiveMark(2, "button", "Google Search", 350, 310, 120, 36),
                InteractiveMark(3, "a", "Gmail", 980, 20, 50, 20),
            ]
            self.last_marks = {m.mark_id: m for m in mock_marks}
            return mock_marks

        js_code = """
        () => {
            const elements = Array.from(document.querySelectorAll(
                'a, button, input, textarea, select, [role="button"], [role="link"], [role="tab"], [onclick], [tabindex]'
            ));
            const results = [];
            let counter = 1;

            for (const el of elements) {
                const rect = el.getBoundingClientRect();
                const style = window.getComputedStyle(el);
                if (
                    rect.width > 8 &&
                    rect.height > 8 &&
                    rect.top < window.innerHeight &&
                    rect.bottom > 0 &&
                    rect.left < window.innerWidth &&
                    rect.right > 0 &&
                    style.visibility !== 'hidden' &&
                    style.display !== 'none' &&
                    style.opacity !== '0'
                ) {
                    const text = (el.innerText || el.getAttribute('aria-label') || el.getAttribute('placeholder') || el.value || '').trim().slice(0, 50);
                    results.push({
                        mark_id: counter++,
                        tag_name: el.tagName.toLowerCase(),
                        text: text,
                        x: Math.round(rect.x),
                        y: Math.round(rect.y),
                        width: Math.round(rect.width),
                        height: Math.round(rect.height)
                    });
                }
            }
            return results.slice(0, 60);
        }
        """
        raw_marks = await page.evaluate(js_code)
        marks: Dict[int, InteractiveMark] = {}
        for item in raw_marks:
            mark = InteractiveMark(
                mark_id=item["mark_id"],
                tag_name=item["tag_name"],
                text=item["text"],
                x=float(item["x"]),
                y=float(item["y"]),
                width=float(item["width"]),
                height=float(item["height"]),
            )
            marks[mark.mark_id] = mark

        self.last_marks = marks
        return list(marks.values())

    async def capture_screen(self, with_cursor: bool = True) -> bytes:
        """Captures raw viewport screenshot as JPEG bytes with simulated cursor overlay."""
        page = await self.ensure_page()
        if page:
            raw_png = await page.screenshot(type="png")
            image = Image.open(io.BytesIO(raw_png)).convert("RGB")
        else:
            # Fallback blank canvas
            image = Image.new("RGB", (self.width, self.height), color=(24, 24, 27))
            draw = ImageDraw.Draw(image)
            draw.text((self.width // 2 - 100, self.height // 2), "Hark Virtual Computer", fill=(200, 200, 200))

        if with_cursor:
            draw = ImageDraw.Draw(image)
            cx, cy = int(self.cursor_x), int(self.cursor_y)
            cursor_points = [
                (cx, cy),
                (cx, cy + 16),
                (cx + 4, cy + 12),
                (cx + 9, cy + 20),
                (cx + 12, cy + 18),
                (cx + 7, cy + 10),
                (cx + 14, cy + 10),
            ]
            draw.polygon(cursor_points, fill="#FF0055", outline="#FFFFFF")

        output = io.BytesIO()
        image.save(output, format="JPEG", quality=80)
        return output.getvalue()

    async def capture_tagged_screen(self) -> Tuple[bytes, List[InteractiveMark]]:
        marks = await self.extract_interactive_elements()
        raw_bytes = await self.capture_screen(with_cursor=True)
        image = Image.open(io.BytesIO(raw_bytes)).convert("RGB")
        draw = ImageDraw.Draw(image)

        for mark in marks:
            box_x0 = mark.x
            box_y0 = mark.y
            box_x1 = mark.x + mark.width
            box_y1 = mark.y + mark.height

            draw.rectangle([box_x0, box_y0, box_x1, box_y1], outline="#00E5FF", width=2)
            badge_text = str(mark.mark_id)
            badge_w, badge_h = len(badge_text) * 8 + 8, 16
            bx0 = box_x0
            by0 = max(0, box_y0 - badge_h)
            draw.rectangle([bx0, by0, bx0 + badge_w, by0 + badge_h], fill="#000000")
            draw.text((bx0 + 4, by0 + 2), badge_text, fill="#FFFFFF")

        output = io.BytesIO()
        image.save(output, format="JPEG", quality=85)
        return output.getvalue(), marks

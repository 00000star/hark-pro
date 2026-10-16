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

from src.agent.memory_vault import ZeroKnowledgeVault
from src.sandbox.dual_stream import DualStreamGrounding

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
    role: str = ""
    selector: str = ""

    @property
    def center(self) -> Tuple[float, float]:
        return (self.x + self.width / 2.0, self.y + self.height / 2.0)


class BrowserController:
    """Controls virtual browser environment, viewport telemetry, and visual tagging."""

    DEFAULT_SANDBOX_HTML = """<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8"/>
<title>Hark Virtual Computer Sandbox</title>
<style>
  body { margin: 0; font-family: system-ui, -apple-system, sans-serif; background: #0d0f17; color: #fff; }
  .header { background: #161822; padding: 14px 24px; display: flex; align-items: center; justify-content: space-between; border-bottom: 1px solid #262938; }
  .brand { font-weight: 800; color: #00e5ff; letter-spacing: 0.8px; }
  .container { max-width: 900px; margin: 36px auto; padding: 0 24px; }
  .search-box { display: flex; gap: 12px; margin-bottom: 28px; }
  input[type="text"] { flex: 1; padding: 12px 16px; border-radius: 10px; border: 1px solid #2e3244; background: #141724; color: #fff; font-size: 15px; }
  button { padding: 12px 22px; border-radius: 10px; border: none; background: #0a84ff; color: #fff; font-weight: 700; cursor: pointer; }
  .cards { display: grid; grid-template-columns: repeat(3, 1fr); gap: 16px; }
  .card { background: #161926; border: 1px solid #262a3d; border-radius: 14px; padding: 18px; }
  .card h3 { margin: 0 0 8px 0; font-size: 16px; color: #00e5ff; }
  .card p { margin: 0 0 14px 0; font-size: 13px; color: #9ba1b8; }
  .card a { color: #30d158; text-decoration: none; font-weight: 600; font-size: 13px; }
</style>
</head>
<body>
  <div class="header">
    <div class="brand">HARK SECURE SANDBOX • OS 3.0</div>
    <div id="status">Ready</div>
  </div>
  <div class="container">
    <div class="search-box">
      <input id="search-input" type="text" placeholder="Search or enter workflow command..." aria-label="Search input"/>
      <button id="search-btn" onclick="document.getElementById('status').innerText='Searching: '+document.getElementById('search-input').value">Execute Action</button>
    </div>
    <div class="cards">
      <div class="card">
        <h3>PG&amp;E Utility Portal</h3>
        <p>Statement #88219 • Balance Due: $84.20</p>
        <a href="#pay-bill" role="button" onclick="document.getElementById('status').innerText='Bill Paid: $84.20'">Pay $84.20 ACH</a>
      </div>
      <div class="card">
        <h3>Delta Air Lines</h3>
        <p>Flight DL 412 • SFO to JFK • Seat 14A</p>
        <a href="#checkin" role="button" onclick="document.getElementById('status').innerText='Checked In: DL 412'">Confirm Check-In</a>
      </div>
      <div class="card">
        <h3>Tony's Pizza Napoletana</h3>
        <p>16" Margherita • DashPass $0 Delivery</p>
        <a href="#order" role="button" onclick="document.getElementById('status').innerText='Order Placed: $32.50'">Place Order $32.50</a>
      </div>
    </div>
  </div>
</body>
</html>"""

    def __init__(
        self,
        width: int = 1280,
        height: int = 800,
        headless: bool = True,
        vault: Optional[ZeroKnowledgeVault] = None,
    ):
        self.width = width
        self.height = height
        self.headless = headless
        self.vault = vault or ZeroKnowledgeVault()
        self._playwright = None
        self._browser: Optional[Browser] = None
        self._context: Optional[BrowserContext] = None
        self._page: Optional[Page] = None
        self._start_attempted: bool = False
        self.cursor_x: float = width / 2.0
        self.cursor_y: float = height / 2.0
        self.is_mouse_down: bool = False
        self.current_url: str = "https://sandbox.hark.ai/workspace"
        self.last_typed_text: str = ""
        self.last_action_label: str = "Standby"
        self.scroll_y: float = 0.0
        self.last_marks: Dict[int, InteractiveMark] = {}
        self.semantic_targets: List[Dict[str, Any]] = []
        self.lock = asyncio.Lock()

    @property
    def norm_cursor(self) -> Tuple[float, float]:
        """Normalized cursor coordinates in [0.0, 1.0]."""
        nx = max(0.0, min(1.0, self.cursor_x / float(self.width)))
        ny = max(0.0, min(1.0, self.cursor_y / float(self.height)))
        return (round(nx, 4), round(ny, 4))

    async def start(self) -> None:
        """Launches Playwright Chromium session with configured viewport or falls back cleanly."""
        if self._browser is not None or self._start_attempted:
            return

        self._start_attempted = True
        if async_playwright is None:
            print("[WARN] Playwright not installed. Running in built-in visual sandbox mode.")
            return

        try:
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
            await self._page.set_content(self.DEFAULT_SANDBOX_HTML, wait_until="domcontentloaded")
        except Exception as exc:
            first_line = str(exc).splitlines()[0] if str(exc) else "unavailable"
            print(f"[INFO] Chromium binary not active ({first_line}). Using built-in Hark visual sandbox renderer.")
            await self.close()
            self._start_attempted = True

    async def close(self) -> None:
        """Closes browser session cleanly."""
        try:
            if self._context:
                await self._context.close()
        except Exception:
            pass
        try:
            if self._browser:
                await self._browser.close()
        except Exception:
            pass
        try:
            if self._playwright:
                await self._playwright.stop()
        except Exception:
            pass
        self._page = None
        self._context = None
        self._browser = None
        self._playwright = None

    async def ensure_page(self) -> Optional[Page]:
        if self._page is None and not self._start_attempted and async_playwright is not None:
            await self.start()
        return self._page

    async def navigate(self, url: str) -> None:
        if not (url.startswith("http://") or url.startswith("https://")):
            url = f"https://{url}"
        self.current_url = url
        self.last_action_label = f"Navigate -> {url}"
        page = await self.ensure_page()
        if page is None:
            return
        try:
            await page.goto(url, wait_until="domcontentloaded", timeout=10000)
        except Exception:
            # Keep sandbox responsive if external network URL is unreachable
            await page.set_content(self.DEFAULT_SANDBOX_HTML, wait_until="domcontentloaded")

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
            self.cursor_x = max(0.0, min(float(self.width), cur_x))
            self.cursor_y = max(0.0, min(float(self.height), cur_y))
            if page:
                try:
                    await page.mouse.move(self.cursor_x, self.cursor_y)
                except Exception:
                    pass
            await asyncio.sleep(random.uniform(0.005, 0.015))

        self.cursor_x = max(0.0, min(float(self.width), target_x))
        self.cursor_y = max(0.0, min(float(self.height), target_y))
        if page:
            try:
                await page.mouse.move(self.cursor_x, self.cursor_y)
            except Exception:
                pass

    async def human_click(self, x: float, y: float, click_count: int = 1) -> None:
        """Simulates human click with movement, press delay, and release."""
        page = await self.ensure_page()
        await self.smooth_move_mouse(x, y)
        self.last_action_label = f"Click ({int(self.cursor_x)}, {int(self.cursor_y)})"
        for _ in range(click_count):
            self.is_mouse_down = True
            if page:
                try:
                    await page.mouse.down()
                except Exception:
                    pass
            await asyncio.sleep(random.uniform(0.04, 0.09))
            self.is_mouse_down = False
            if page:
                try:
                    await page.mouse.up()
                except Exception:
                    pass
            await asyncio.sleep(random.uniform(0.05, 0.12))

    async def human_type(self, text: str, press_enter: bool = False) -> None:
        """
        Types text with natural human keystroke jitter.
        Resolves $VAULT:<handle> secrets strictly at the keystroke boundary while keeping UI/logs masked.
        """
        masked_display = self.vault.mask_text(text)
        resolved_secret_text = self.vault.resolve(text)
        self.last_typed_text = masked_display
        self.last_action_label = f"Type '{masked_display[:28]}'"
        page = await self.ensure_page()
        if not page:
            await asyncio.sleep(min(0.4, len(resolved_secret_text) * 0.02))
            return
        try:
            for char in resolved_secret_text:
                await page.keyboard.type(char)
                await asyncio.sleep(random.uniform(0.02, 0.06))
            if press_enter:
                await asyncio.sleep(random.uniform(0.05, 0.15))
                await page.keyboard.press("Enter")
        except Exception:
            pass

    async def scroll(self, delta_x: float, delta_y: float) -> None:
        """Smoothly scrolls page viewport."""
        self.scroll_y = max(0.0, self.scroll_y + delta_y)
        self.last_action_label = f"Scroll dy={int(delta_y)}"
        page = await self.ensure_page()
        if page:
            try:
                await page.mouse.wheel(delta_x, delta_y)
            except Exception:
                pass
        await asyncio.sleep(0.2)

    async def operator_input(
        self,
        action: str,
        norm_x: Optional[float] = None,
        norm_y: Optional[float] = None,
        text: Optional[str] = None,
        delta_y: Optional[float] = None,
    ) -> Dict[str, Any]:
        """Executes direct operator takeover input from mobile client."""
        px = (
            max(0.0, min(float(self.width), float(norm_x) * self.width))
            if norm_x is not None
            else self.cursor_x
        )
        py = (
            max(0.0, min(float(self.height), float(norm_y) * self.height))
            if norm_y is not None
            else self.cursor_y
        )
        act = action.lower().strip()
        if act == "click":
            await self.human_click(px, py)
        elif act == "move":
            await self.smooth_move_mouse(px, py, steps=6)
        elif act == "type" and text:
            if norm_x is not None and norm_y is not None:
                await self.human_click(px, py)
            await self.human_type(text, press_enter=True)
        elif act == "scroll":
            await self.scroll(0.0, delta_y if delta_y is not None else 250.0)

        nx, ny = self.norm_cursor
        return {
            "status": "executed",
            "action": act,
            "cursor": {"x": self.cursor_x, "y": self.cursor_y, "norm_x": nx, "norm_y": ny},
        }

    async def extract_interactive_elements(self) -> List[InteractiveMark]:
        """
        Extracts visible interactive elements from DOM for Set-of-Marks visual prompting,
        fused with Chromium Accessibility Tree (DualStreamGrounding).
        """
        page = await self.ensure_page()
        if not page:
            mock_marks = [
                InteractiveMark(
                    1,
                    "input",
                    self.last_typed_text or "Search or enter workflow command...",
                    190,
                    96,
                    680,
                    44,
                    role="textbox",
                    selector="#search-input",
                ),
                InteractiveMark(
                    2,
                    "button",
                    "Execute Action",
                    884,
                    96,
                    200,
                    44,
                    role="button",
                    selector="#search-btn",
                ),
                InteractiveMark(
                    3,
                    "a",
                    "Pay $84.20 ACH",
                    210,
                    260,
                    240,
                    36,
                    role="button",
                    selector="a[href='#pay-bill']",
                ),
                InteractiveMark(
                    4,
                    "a",
                    "Confirm Check-In",
                    520,
                    260,
                    240,
                    36,
                    role="button",
                    selector="a[href='#checkin']",
                ),
                InteractiveMark(
                    5,
                    "a",
                    "Place Order $32.50",
                    830,
                    260,
                    240,
                    36,
                    role="button",
                    selector="a[href='#order']",
                ),
            ]
            self.last_marks = {m.mark_id: m for m in mock_marks}
            self.semantic_targets = [
                {"role": m.role, "name": m.text, "selector": m.selector} for m in mock_marks
            ]
            return mock_marks

        self.semantic_targets = await DualStreamGrounding.extract_semantic_targets(page)

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
                    const role = el.getAttribute('role') || el.tagName.toLowerCase();
                    const idAttr = el.getAttribute('id');
                    const hrefAttr = el.getAttribute('href');
                    const selector = idAttr ? `#${idAttr}` : (hrefAttr ? `${el.tagName.toLowerCase()}[href="${hrefAttr}"]` : el.tagName.toLowerCase());
                    results.push({
                        mark_id: counter++,
                        tag_name: el.tagName.toLowerCase(),
                        text: text,
                        x: Math.round(rect.x),
                        y: Math.round(rect.y),
                        width: Math.round(rect.width),
                        height: Math.round(rect.height),
                        role: role,
                        selector: selector
                    });
                }
            }
            return results.slice(0, 60);
        }
        """
        try:
            raw_marks = await page.evaluate(js_code)
        except Exception:
            raw_marks = []

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
                role=item.get("role", ""),
                selector=item.get("selector", ""),
            )
            marks[mark.mark_id] = mark

        self.last_marks = marks
        return list(marks.values())

    def _render_fallback_canvas(self) -> Image.Image:
        """Renders a high-contrast virtual desktop frame when running without Chromium."""
        image = Image.new("RGB", (self.width, self.height), color=(13, 15, 23))
        draw = ImageDraw.Draw(image)

        # Top Chrome Header
        draw.rectangle([0, 0, self.width, 52], fill=(22, 24, 34))
        draw.text((24, 18), "HARK SECURE SANDBOX • OS 3.0", fill=(0, 229, 255))
        draw.text((self.width - 360, 18), f"Action: {self.last_action_label}", fill=(48, 209, 88))

        # Search input & Execute button
        draw.rectangle([190, 96, 870, 140], fill=(20, 23, 36), outline=(46, 50, 68), width=2)
        search_txt = self.last_typed_text or "Search or enter workflow command..."
        draw.text((206, 110), search_txt[:65], fill=(230, 235, 245))
        draw.rectangle([884, 96, 1084, 140], fill=(10, 132, 255))
        draw.text((934, 110), "Execute Action", fill=(255, 255, 255))

        # Cards
        cards = [
            (190, "PG&E Utility Portal", "Statement #88219 • Due: $84.20", "Pay $84.20 ACH"),
            (500, "Delta Air Lines", "Flight DL 412 • SFO -> JFK (14A)", "Confirm Check-In"),
            (810, "Tony's Pizza Napoletana", "16\" Margherita • $0 Delivery", "Place Order $32.50"),
        ]
        for x0, title, subtitle, cta in cards:
            draw.rectangle([x0, 180, x0 + 280, 310], fill=(22, 25, 38), outline=(38, 42, 61), width=2)
            draw.text((x0 + 18, 200), title, fill=(0, 229, 255))
            draw.text((x0 + 18, 228), subtitle, fill=(155, 161, 184))
            draw.rectangle([x0 + 18, 260, x0 + 258, 294], fill=(28, 38, 56), outline=(48, 209, 88), width=1)
            draw.text((x0 + 32, 270), cta, fill=(48, 209, 88))

        # URL / Telemetry status bar at bottom
        draw.rectangle([0, self.height - 36, self.width, self.height], fill=(18, 20, 30))
        draw.text(
            (24, self.height - 24),
            f"URL: {self.current_url}   |   Cursor: ({int(self.cursor_x)}, {int(self.cursor_y)})",
            fill=(140, 150, 175),
        )
        return image

    async def capture_screen(self, with_cursor: bool = True) -> bytes:
        """Captures raw viewport screenshot as JPEG bytes with simulated cursor overlay."""
        page = await self.ensure_page()
        image: Optional[Image.Image] = None
        if page:
            try:
                raw_png = await page.screenshot(type="png")
                image = Image.open(io.BytesIO(raw_png)).convert("RGB")
            except Exception:
                image = None

        if image is None:
            image = self._render_fallback_canvas()

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
            if self.is_mouse_down:
                draw.ellipse([cx - 14, cy - 14, cx + 14, cy + 14], outline="#00E5FF", width=2)

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

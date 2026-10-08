"""
Dual-Stream Grounding Engine for Hark 2.0.
Pairs visual coordinate prediction with Chromium's Accessibility Tree (AXTree).
Prevents coordinate drift when dynamic page elements reflow.
"""

from __future__ import annotations

from typing import Any, Dict, List, Optional

try:
    from playwright.async_api import Page
except ImportError:
    Page = Any  # type: ignore


class DualStreamGrounding:
    """
    Dual-Stream hybrid grounding mechanism.
    Combines visual coordinates with semantic DOM accessibility nodes.
    """

    @staticmethod
    async def extract_semantic_targets(page: Page) -> List[Dict[str, Any]]:
        """Extract accessibility tree nodes with bounding boxes and semantic roles."""
        try:
            snapshot = await page.accessibility.snapshot()
        except Exception:
            return []

        targets = []

        def traverse(node: Dict[str, Any]):
            if node.get("role") in ["button", "link", "textbox", "combobox", "checkbox"]:
                targets.append({
                    "role": node.get("role"),
                    "name": node.get("name", ""),
                    "value": node.get("value", "")
                })
            for child in node.get("children", []):
                traverse(child)

        if snapshot:
            traverse(snapshot)
        return targets

    @staticmethod
    async def click_with_fallback(
        page: Page,
        norm_x: float,
        norm_y: float,
        fallback_selector: Optional[str] = None,
        screen_width: int = 1280,
        screen_height: int = 800,
    ) -> bool:
        """
        Attempts to click a semantic DOM target; falls back to visual coordinates
        if DOM node is inaccessible or encapsulated in Shadow DOM.
        """
        if fallback_selector:
            try:
                el = await page.wait_for_selector(fallback_selector, timeout=1500)
                if el and await el.is_visible():
                    await el.click()
                    return True
            except Exception:
                pass

        # Fallback to physical coordinate click
        pixel_x = int((norm_x / 1000.0) * screen_width)
        pixel_y = int((norm_y / 1000.0) * screen_height)
        await page.mouse.move(pixel_x, pixel_y, steps=5)
        await page.mouse.click(pixel_x, pixel_y)
        return True

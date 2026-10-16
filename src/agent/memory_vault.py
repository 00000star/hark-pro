"""
Persistent Agent Memory (SOUL.md + Episodic Store) and Zero-Knowledge Vault Handle Resolver.
Combines OpenClaw/Hermes persistent memory with Hark Pro's zero-knowledge credential injection.
"""

from __future__ import annotations

import json
import os
import re
import time
from pathlib import Path
from typing import Any, Dict, List, Optional


class ZeroKnowledgeVault:
    """
    Stores sensitive credentials behind opaque $VAULT:<handle> tokens.
    The LLM only ever sees handle names (e.g., $VAULT:chase_ach_token).
    Actual secret values are resolved strictly inside BrowserController.human_type().
    """

    VAULT_PATTERN = re.compile(r"\$VAULT:([a-zA-Z0-9_\-]+)")

    def __init__(self) -> None:
        self._secrets: Dict[str, str] = {
            "chase_ach_token": "ACH-9928-4410-CHASE",
            "delta_skymiles_pin": "DL-88412-SKY",
            "doordash_virtual_card": "4242-8899-0011-3250",
            "pge_account_pin": "PGE-7741-UTIL",
        }

    def set_secret(self, handle: str, secret_value: str) -> str:
        clean_handle = handle.strip().lstrip("$").replace("VAULT:", "")
        self._secrets[clean_handle] = secret_value
        return f"$VAULT:{clean_handle}"

    def list_handles(self) -> List[str]:
        """Returns opaque handle references safe to expose to prompts and UI."""
        return [f"$VAULT:{k}" for k in sorted(self._secrets.keys())]

    def contains_vault_handle(self, text: str) -> bool:
        return bool(self.VAULT_PATTERN.search(text or ""))

    def mask_text(self, text: str) -> str:
        """Replaces any $VAULT:<handle> or resolved secret with a masked badge for UI/logs."""
        if not text:
            return ""
        masked = self.VAULT_PATTERN.sub(r"[VAULT:\1]", text)
        for key, secret in self._secrets.items():
            if secret and secret in masked:
                masked = masked.replace(secret, f"[VAULT:{key}]")
        return masked

    def resolve(self, text: str) -> str:
        """Resolves $VAULT:<handle> tokens into raw secret values at the browser keystroke boundary."""
        if not text:
            return ""

        def _replacer(match: re.Match[str]) -> str:
            key = match.group(1)
            return self._secrets.get(key, match.group(0))

        return self.VAULT_PATTERN.sub(_replacer, text)

    def resolve_token(self, text: str) -> str:
        """Alias for resolve()."""
        return self.resolve(text)


class AgentMemory:
    """
    Loads SOUL.md directives and maintains persistent user preferences & episodic task history.
    """

    def __init__(self, root_dir: Optional[Path] = None, storage_filename: str = ".hark_memory.json") -> None:
        self.root_dir = root_dir or Path(__file__).resolve().parents[2]
        self.soul_path = self.root_dir / "SOUL.md"
        self.storage_path = self.root_dir / storage_filename
        self.preferences: Dict[str, Any] = {
            "preferred_seat": "14A (Window, Main Cabin Extra)",
            "default_payment_handle": "$VAULT:chase_ach_token",
            "location": "San Francisco, CA (SFO)",
        }
        self.episodes: List[Dict[str, Any]] = []
        self._load()

    def _load(self) -> None:
        if self.storage_path.exists():
            try:
                data = json.loads(self.storage_path.read_text(encoding="utf-8"))
                if isinstance(data.get("preferences"), dict):
                    self.preferences.update(data["preferences"])
                if isinstance(data.get("episodes"), list):
                    self.episodes = data["episodes"][-50:]
            except Exception:
                pass

    def _save(self) -> None:
        try:
            payload = {
                "preferences": self.preferences,
                "episodes": self.episodes[-50:],
            }
            self.storage_path.write_text(json.dumps(payload, indent=2), encoding="utf-8")
        except Exception:
            pass

    def read_soul(self) -> str:
        if self.soul_path.exists():
            try:
                return self.soul_path.read_text(encoding="utf-8").strip()
            except Exception:
                pass
        return "You are Hark Pro, an autonomous computer-use vision agent."

    def remember(self, key: str, value: Any) -> Dict[str, Any]:
        self.preferences[key] = value
        self._save()
        return self.preferences

    def record_episode(self, task: str, status: str, result: Optional[str], steps_count: int) -> None:
        self.episodes.append(
            {
                "timestamp": int(time.time()),
                "task": task,
                "status": status,
                "result": result,
                "steps_count": steps_count,
            }
        )
        self.episodes = self.episodes[-50:]
        self._save()

    def get_context_prompt(self, vault_handles: Optional[List[str]] = None) -> str:
        prefs_str = ", ".join(f"{k}={v}" for k, v in self.preferences.items())
        recent = self.episodes[-3:]
        recent_str = (
            "; ".join(f"{ep['task']} ({ep['status']})" for ep in recent)
            if recent
            else "None"
        )
        handles_str = ", ".join(vault_handles or []) or "None"
        return (
            f"User Preferences: {prefs_str}\n"
            f"Available Zero-Knowledge Vault Handles: {handles_str}\n"
            f"Recent Episodic History: {recent_str}"
        )

    def get_summary(self, vault_handles: Optional[List[str]] = None) -> Dict[str, Any]:
        return {
            "soul_excerpt": self.read_soul()[:400],
            "preferences": self.preferences,
            "vault_handles": vault_handles or [],
            "episodes_count": len(self.episodes),
            "total_episodes": len(self.episodes),
            "recent_episodes": self.episodes[-10:],
        }

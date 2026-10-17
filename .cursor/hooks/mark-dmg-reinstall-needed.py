#!/usr/bin/env python3
"""Mark a local DMG reinstall when app source files change."""
from __future__ import annotations

import json
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
STATE_DIR = ROOT / ".cursor" / "state"
DIRTY_FILE = STATE_DIR / "dmg-reinstall-needed"

RELEVANT_SUFFIXES = (
    "/Package.swift",
    "/VERSION",
    "/.swift-version",
    "/scripts/build_macos_app.sh",
)
RELEVANT_PARTS = ("/Sources/",)


def is_relevant(path: str) -> bool:
    normalized = path.replace("\\", "/")
    if any(part in normalized for part in RELEVANT_PARTS):
        return True
    return any(normalized.endswith(suffix) for suffix in RELEVANT_SUFFIXES)


def main() -> int:
    try:
        payload = json.load(sys.stdin)
    except Exception:
        print("{}")
        return 0

    path = str(payload.get("file_path") or "")
    if path and is_relevant(path):
        STATE_DIR.mkdir(parents=True, exist_ok=True)
        DIRTY_FILE.write_text(datetime.now(timezone.utc).isoformat() + "\n", encoding="utf-8")

    print("{}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

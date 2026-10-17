#!/usr/bin/env python3
"""Ask the agent to reinstall the local DMG after app source changes."""
from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DIRTY_FILE = ROOT / ".cursor" / "state" / "dmg-reinstall-needed"

FOLLOWUP = (
    "QuotaBar 源码已改完，但还没有重新安装本地 DMG。"
    "请立刻运行 `scripts/reinstall_local_dmg.sh`："
    "它会重新编译、打包 DMG、用该 DMG 覆盖安装 `/Applications/QuotaBar.app` 并重启应用。"
    "禁止修改或删除任何用户级数据，包括 "
    "`~/Library/Application Support/QuotaBar`、Keychain、偏好设置、"
    "`~/.quotabar.json` 和 `~/.quotabar-credentials.json`。"
    "安装完成后不要再改代码，直接汇报结果。"
)


def emit(payload: dict) -> None:
    json.dump(payload, sys.stdout, ensure_ascii=False)
    sys.stdout.write("\n")


def main() -> int:
    try:
        payload = json.load(sys.stdin)
    except Exception:
        emit({})
        return 0

    status = payload.get("status")
    loop_count = int(payload.get("loop_count") or 0)
    if status != "completed" or loop_count >= 1 or not DIRTY_FILE.is_file():
        emit({})
        return 0

    emit({"followup_message": FOLLOWUP})
    return 0


if __name__ == "__main__":
    sys.exit(main())

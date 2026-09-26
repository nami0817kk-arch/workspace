# -*- coding: utf-8 -*-
"""その日に予約済みの公開時刻を並べる（2026-09-25）。

    python tools/slots.py            # 今日
    python tools/slots.py 2026-09-26

**枠を提案する前に、必ずこれを見る。**9/25 に「16:00 から」と提案したら
「18時40分までは設定済みだよ」と返された。控え（research/posted.json）に
予約時刻を書いていなかったので、埋まっている枠が手元で分からなかった。
`posted.record(publish_at=…)` が書くようになったのは 9/25 の夕方からで、
それより前の投稿は出ない（YouTube Studio で見る）。
"""
from __future__ import annotations

import json
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

JST = timezone(timedelta(hours=9))
LEDGER = Path(__file__).resolve().parents[1] / "research" / "posted.json"


def slots(day: str, path: Path = LEDGER) -> list[tuple[str, str]]:
    rows = json.loads(path.read_text(encoding="utf-8")) if path.exists() else []
    out = []
    for r in rows:
        at = str(r.get("publish_at") or "")
        if not at:
            continue
        local = datetime.fromisoformat(at.replace("Z", "+00:00")).astimezone(JST)
        if local.strftime("%Y-%m-%d") == day:
            out.append((local.strftime("%H:%M"), str(r.get("build") or "")))
    return sorted(out)


def main() -> int:
    day = sys.argv[1] if len(sys.argv) > 1 else datetime.now(JST).strftime("%Y-%m-%d")
    rows = slots(day)
    if not rows:
        print(f"{day}: 控えに予約時刻がありません（9/25 夕方より前の投稿は Studio で見る）")
        return 0
    for t, b in rows:
        print(f"{t}  {b}")
    print(f"{len(rows)} 本。次に空くのは {rows[-1][0]} のあと")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

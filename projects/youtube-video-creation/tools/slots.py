# -*- coding: utf-8 -*-
"""その日に予約済みの公開時刻を並べる（2026-09-25）。

    python tools/slots.py            # 今日
    python tools/slots.py 2026-09-26

**枠を提案する前に、必ずこれを見る。**9/25 に「16:00 から」と提案したら
「18時40分までは設定済みだよ」と返された。控え（research/posted.json）に
予約時刻を書いていなかったので、埋まっている枠が手元で分からなかった。
`posted.record(publish_at=…)` が書くようになったのは 9/25 の夕方からで、
それより前の投稿は出ない（YouTube Studio で見る）。

**その日のショートの本数も数える**（2026-10-10 に足した）。10/9 にショートを
**5本しか出さなかった**日があり（決めた形は10本）、登録者の伸びが
+12〜20人/日 → +4.5人/日 に落ちた。**ショートはこのチャンネルの再生の92.8%**で、
配られる口が半分なら登録も半分以下になる。しかもその日は**ニュースのショートが0本**で、
登録が付く型（日本人選手本人の発言。1万再生あたり6.8人）が1本も無かった。
**数が足りない日を黙って作らない。**
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
    return report_shorts(rows)


SHORTS_PER_DAY = 10     # 1日に配られる上限（2026-09-16 に124本で確認）。下回る日を作らない
NEWS_SHORTS_MIN = 2     # ニュースのショート（2026-10-08 決定「シリーズ8・ニュース2」）


def report_shorts(rows: list[tuple[str, str]]) -> int:
    """その日のショートの本数と、ニュースのショートが入っているかを言う。

    見分けは出力先の名前。`_short` で終わればショート。
    ニュースかシリーズかは**名前では分からない**ので、ここでは数だけ出して
    「ニュースが入っているか」は人に聞く（取材メモの `series:` を見るには
    台本まで辿る必要があり、投稿の控えには残っていない）。
    """
    shorts = [b for _, b in rows if b.endswith("_short")]
    print(f"  うちショート {len(shorts)} 本（1日の上限 {SHORTS_PER_DAY} 本）")
    if len(shorts) < SHORTS_PER_DAY:
        print(f"  × ショートが {SHORTS_PER_DAY - len(shorts)} 本足りません。"
              f"**ショートは再生の92.8%**で、減らすと登録者の伸びが直に落ちる"
              f"（10/9 に5本の日を作って +12〜20人/日 → +4.5人/日）")
        print(f"  × **ニュースのショートが {NEWS_SHORTS_MIN} 本入っているか目で見る。**"
              f"登録が付くのは日本人選手本人の発言のショート（1万再生あたり6.8人）")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

"""何をいつ投稿したかを控える。**同じ動画を二度上げないため。**

2026-09-07 に、本編8本を15分おきに上げる処理がまだ走っている最中に、
「サムネイルが付いていない」と思って**2本目の投稿処理を起こした。**
先の処理の出力を最後まで読んでいなかった。結果、japan / kubo / spurs /
inter が二重に公開され、その4本分で投稿本数の上限を使い切り、
ショート6本がその日のうちに出せなくなった。

人の注意では防げない。**投稿する側が「これはもう上げた」と知っている**
必要がある。だからここに控える。

もうひとつ、**投稿できる本数は「1日100本」ではない。**同じ日に実測して、
直近24時間で34本目に `uploadLimitExceeded` が返った。日付で戻る枠ではなく
**転がる24時間の窓**なので、24時間前の投稿が抜けた分だけ空く。
控えがあれば、上限に当たる前に知らせられる。
"""

from __future__ import annotations

import json
from datetime import datetime, timedelta, timezone
from pathlib import Path

LEDGER = Path("research/posted.json")

# 実測値。2026-09-07 に34本目で uploadLimitExceeded（開設3日目のチャンネル）。
# チャンネルが育つと増えるらしいので、外したら測り直して入れ直す。
WINDOW_HOURS = 24
WINDOW_MAX = 34


def key(build_dir: Path | str) -> str:
    """出力先の名前を控えの見出しにする（例: 20260907_japan_short）。"""
    return Path(build_dir).resolve().name


def _load(path: Path) -> list[dict]:
    if not path.exists():
        return []
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return []
    return data if isinstance(data, list) else []


def find(build_dir: Path | str, path: Path = LEDGER) -> dict | None:
    """この出力先をすでに投稿していれば、そのときの控えを返す。"""
    name = key(build_dir)
    for row in reversed(_load(path)):
        if row.get("build") == name:
            return row
    return None


def record(build_dir: Path | str, video_id: str, path: Path = LEDGER,
           now: datetime | None = None) -> dict:
    now = now or datetime.now(timezone.utc)
    row = {"build": key(build_dir), "video_id": video_id,
           "at": now.astimezone(timezone.utc).isoformat(timespec="seconds")}
    rows = _load(path)
    rows.append(row)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(rows, ensure_ascii=False, indent=2) + "\n",
                    encoding="utf-8")
    return row


def _times(path: Path) -> list[datetime]:
    out = []
    for row in _load(path):
        try:
            out.append(datetime.fromisoformat(row["at"]))
        except (KeyError, ValueError):
            continue
    return sorted(out)


def in_window(path: Path = LEDGER, now: datetime | None = None) -> int:
    """直近24時間に投稿した本数。**控えた分だけ**なので目安。"""
    now = now or datetime.now(timezone.utc)
    edge = now - timedelta(hours=WINDOW_HOURS)
    return len([t for t in _times(path) if t > edge])


def left(path: Path = LEDGER, now: datetime | None = None) -> int:
    return max(0, WINDOW_MAX - in_window(path, now))


def frees_at(path: Path = LEDGER, now: datetime | None = None) -> datetime | None:
    """次に1枠空く時刻。空きがあるなら None。"""
    now = now or datetime.now(timezone.utc)
    edge = now - timedelta(hours=WINDOW_HOURS)
    live = [t for t in _times(path) if t > edge]
    if len(live) < WINDOW_MAX:
        return None
    return live[len(live) - WINDOW_MAX] + timedelta(hours=WINDOW_HOURS)

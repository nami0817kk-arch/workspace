"""APIの枠を自分で数える。

**APIは残量を教えてくれない。**Google Cloud のコンソールを開けば実際の
使用量は見えるが、投稿の途中で毎回開くわけにはいかない。

2026-09-06 に、枠が残っているのに「使い切った」と思い込んで投稿を止めた。
16時50分の時点でリセット済みだと正しく判断していたのに、11本上げたあと
**確かめずに「使い切った」と繰り返していた。**数えていれば起きなかった。

数えるのはこちらが叩いたぶんだけ。手でStudioから上げたぶんは入らないので、
**目安であって正確な残量ではない。**それでも「まだ余っている / もう危ない」
の判断には足りる。
"""

from __future__ import annotations

import json
from datetime import datetime, timedelta, timezone
from pathlib import Path

# **公表値ではなく実測値を使う。**2026-09-06 に18本投稿して
# Queries per day は 4,815 だった（コンソールで確認）。1本あたり約270。
# 「1本1,600、1日6本が上限」と記録していたが、**6倍ちがっていた。**
# 実測でしか分からないので、ずれてきたらコンソールを見て入れ直す。
COST_PER_UPLOAD = 270      # 動画1本ぶん（サムネイルの設定・やり直しも含む実績）
COSTS = {
    "videos.insert": COST_PER_UPLOAD,
    "videos.update": 50,
    "videos.list": 1,
    "thumbnails.set": 0,   # 上の COST_PER_UPLOAD に含めて数えている
    "commentThreads.insert": 50,   # 最初のコメント（2026-09-08）。公式の表の値
    "search.list": 100,
}
# 1日に使えるリクエストの合計
DAILY = 10000
# **投稿数そのものにも上限がある**（Video Uploads per day）。
# 記録していなかったが、コンソールに出ている。ふつうは Queries が先に尽きる
DAILY_UPLOADS = 100
LEDGER = Path("research/quota.json")
# 枠は太平洋時間の深夜0時に戻る。夏時間は UTC-7、冬は UTC-8
PACIFIC_SUMMER = timezone(timedelta(hours=-7))


def _today(now: datetime | None = None) -> str:
    """いまが太平洋時間で何日か。**枠はこの日付で切り替わる。**"""
    at = (now or datetime.now(timezone.utc)).astimezone(PACIFIC_SUMMER)
    return at.strftime("%Y-%m-%d")


def _load(path: Path) -> dict:
    if not path.exists():
        return {}
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {}


def record(call: str, path: Path = LEDGER, now: datetime | None = None) -> int:
    """叩いたぶんを足して、その日の合計を返す。"""
    cost = COSTS.get(call)
    if cost is None:
        raise KeyError(f"費用の分からない呼び出しです: {call}")
    day = _today(now)
    book = _load(path)
    today = dict(book.get(day) or {})
    today[call] = int(today.get(call, 0)) + 1
    book[day] = today
    # 昨日までは残しておく。**いつ何本上げたかを後から見返せる**
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(book, ensure_ascii=False, indent=2), encoding="utf-8")
    return used(path, now)


def used(path: Path = LEDGER, now: datetime | None = None) -> int:
    today = _load(path).get(_today(now)) or {}
    return sum(COSTS.get(name, 0) * int(count) for name, count in today.items())


def left(path: Path = LEDGER, now: datetime | None = None) -> int:
    return max(0, DAILY - used(path, now))


def uploads_today(path: Path = LEDGER, now: datetime | None = None) -> int:
    today = _load(path).get(_today(now)) or {}
    return int(today.get("videos.insert", 0))


def uploads_left(path: Path = LEDGER, now: datetime | None = None) -> int:
    """あと何本上げられるか。**2つの上限のうち、先に尽きるほうで決まる。**"""
    by_cost = left(path, now) // COST_PER_UPLOAD
    by_count = DAILY_UPLOADS - uploads_today(path, now)
    return max(0, min(by_cost, by_count))


def resets_at(now: datetime | None = None) -> datetime:
    """次に枠が戻る時刻（そのまま日本時間で表示できる）。"""
    at = (now or datetime.now(timezone.utc)).astimezone(PACIFIC_SUMMER)
    return (at + timedelta(days=1)).replace(hour=0, minute=0, second=0, microsecond=0)


def report(path: Path = LEDGER, now: datetime | None = None) -> list[str]:
    today = _load(path).get(_today(now)) or {}
    jst = timezone(timedelta(hours=9))
    lines = [f"■ APIの枠　{used(path, now)} / {DAILY} 使用"]
    for name, count in sorted(today.items()):
        lines.append(f"  {name:<16} {count:>3}回 × {COSTS.get(name, 0)} = "
                     f"{COSTS.get(name, 0) * count}")
    lines.append(f"  投稿 {uploads_today(path, now)} / {DAILY_UPLOADS} 本")
    lines.append(f"  残り {left(path, now)}　→ **あと{uploads_left(path, now)}本**")
    lines.append(f"  次のリセット: 日本時間 "
                 f"{resets_at(now).astimezone(jst).strftime('%m-%d %H:%M')}")
    if not today:
        lines.append("  ※ 記録がありません。手で上げたぶんは数えられません")
    return lines

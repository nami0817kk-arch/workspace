"""何をいつ投稿したかを控える。**同じ動画を二度上げないため。**

2026-09-07 に、本編8本を15分おきに上げる処理がまだ走っている最中に、
「サムネイルが付いていない」と思って**2本目の投稿処理を起こした。**
先の処理の出力を最後まで読んでいなかった。結果、japan / kubo / spurs /
inter が二重に公開され、その4本分で投稿本数の上限を使い切り、
ショート6本がその日のうちに出せなくなった。

人の注意では防げない。**投稿する側が「これはもう上げた」と知っている**
必要がある。だからここに控える。

もうひとつ、**投稿できる本数は「1日100本」ではない。**コンソールの
「Video Uploads per day」が 49/100 でも `uploadLimitExceeded` が返る。
**弾いているのはコンソールに出ていないチャンネル側の上限**で、残量を
見る手段が無い。だから「何本まで」ではなく「いつ戻るか」で扱う。

2026-09-07 に、10:36 に弾かれてから 12:41 に試しても弾かれたまま。
**転がる24時間の窓ではない**（それなら2時間で数本ぶん空いていた）。
枠は Queries と同じく太平洋時間の深夜0時＝日本時間16時に戻るとみて
数え直す。数えるのはこちらが上げた本数で、上限そのものは分からない。
"""

from __future__ import annotations

import json
from datetime import datetime, timedelta, timezone
from pathlib import Path

LEDGER = Path("research/posted.json")

# **上限の本数は分からない。**2026-09-07 に34本目で弾かれたが、
# それが上限だという確証はない（コンソールの Video Uploads per day は
# 49/100 で余っていた）。ここでは「いつ戻るか」だけを確かなものとして扱う。
PACIFIC_SUMMER = timezone(timedelta(hours=-7))
# 目安。これを超えたら弾かれても驚かない、という程度の数
SOFT_MAX = 34

# **投稿は時間で散らす**（2026-09-07 の実測）。参考にしている
# 2chサッカーの噂話（登録10.3万）は直近24時間に 8/18/20/21/22/23 時間前と
# **1時間に1本ずつ**出していた。こちらは13時間前に4本、14〜15時間前に4本と
# **一度に固めて**出していた。まとめて出すと、同じ枠を自分の動画同士で
# 奪い合い、登録者の新着も一度で埋まる。
SPREAD_MINUTES = 45


def since_last(path: Path = LEDGER, now: datetime | None = None) -> float | None:
    """前に投稿してから何分たったか。控えが無ければ None。"""
    times = _times(path)
    if not times:
        return None
    now = now or datetime.now(timezone.utc)
    return (now - max(times)).total_seconds() / 60.0


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


def day_start(now: datetime | None = None) -> datetime:
    """枠が戻った時刻。太平洋時間の深夜0時＝日本時間の16時。"""
    at = (now or datetime.now(timezone.utc)).astimezone(PACIFIC_SUMMER)
    return at.replace(hour=0, minute=0, second=0, microsecond=0)


def today(path: Path = LEDGER, now: datetime | None = None) -> int:
    """枠が戻ってから上げた本数。**上限そのものは分からない。**"""
    edge = day_start(now)
    return len([t for t in _times(path) if t >= edge])


def frees_at(path: Path = LEDGER, now: datetime | None = None) -> datetime:
    """次に枠が戻る時刻。**本数に関係なく、必ず次の16時（JST）。**"""
    return day_start(now) + timedelta(days=1)

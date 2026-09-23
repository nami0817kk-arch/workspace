"""アーカイブ全体を横断して数える。

1日ぶんの表は他所にもあるが、「何日ランクインしたか」はこのサイトが
毎日ためているからこそ出せる。読み物として成立する唯一の持ち札なので、
ここは数えた事実だけを書く（見通し・推奨は書かない）。
"""
from __future__ import annotations

from collections import defaultdict


def _tally(days: list[dict], key: str) -> dict[str, dict]:
    """銘柄コードごとに、登場した日と最大騰落率を集める。"""
    acc: dict[str, dict] = defaultdict(
        lambda: {"code": "", "name": "", "dates": [], "best_pct": None}
    )
    # days は新しい順。集計は古い順に見たほうが「最新の名称」を残しやすい。
    for day in reversed(days):
        for row in day.get(key, []):
            e = acc[row["code"]]
            e["code"] = row["code"]
            e["name"] = row["name"]  # 社名変更があれば新しいほうが残る
            e["dates"].append(day["rec_date"])
            pct = row["change_pct"]
            if e["best_pct"] is None or abs(pct) > abs(e["best_pct"]):
                e["best_pct"] = pct
    return acc


def frequent(days: list[dict], key: str = "gainers", top_n: int = 20) -> list[dict]:
    """ランクイン回数の多い順。2回以上のものだけ返す。

    1回だけの銘柄は全体の大半で、並べても「その日たまたま上がった」以上の
    ことを言わない。数えた意味があるのは複数回のものだけ。
    """
    entries = [e for e in _tally(days, key).values() if len(e["dates"]) >= 2]
    for e in entries:
        e["count"] = len(e["dates"])
        e["latest"] = max(e["dates"])
        e["streak"] = _longest_run(e["dates"], _all_dates(days))
    entries.sort(key=lambda e: (-e["count"], -abs(e["best_pct"] or 0), e["code"]))
    return entries[:top_n]


def _all_dates(days: list[dict]) -> list[str]:
    """掲載のある日付を古い順に。連続判定はこの並びの上で数える。"""
    return sorted(d["rec_date"] for d in days)


def _longest_run(dates: list[str], all_dates: list[str]) -> int:
    """連続してランクインした最大日数。

    「連続」はカレンダーの連日ではなく**掲載日の並び**で数える。
    取得を取り逃した日や休場日を挟んでも、間に他の掲載日が無ければ連続とみなす。
    """
    index = {d: i for i, d in enumerate(all_dates)}
    positions = sorted(index[d] for d in dates if d in index)
    best = run = 1
    for prev, cur in zip(positions, positions[1:]):
        run = run + 1 if cur == prev + 1 else 1
        best = max(best, run)
    return best

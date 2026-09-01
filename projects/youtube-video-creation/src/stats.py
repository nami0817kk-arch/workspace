"""何を出してきたかを振り返る。

covered.yaml はこれまで重複を止めるためだけに使っていた。同じものを
数えれば「どこに偏っているか」が見える。移籍ばかり、プレミアばかりに
なっていないか。1日3本のうち何本出せているか。
"""

from __future__ import annotations

from collections import Counter
from dataclasses import dataclass, field
from datetime import date, datetime, timedelta

from . import coverage


@dataclass
class Summary:
    days: int
    total: int = 0
    per_day: dict[date, int] = field(default_factory=dict)
    slots: Counter = field(default_factory=Counter)
    themes: list[tuple[str, int]] = field(default_factory=list)

    @property
    def average(self) -> float:
        return self.total / self.days if self.days else 0.0

    @property
    def empty_days(self) -> int:
        return sum(1 for count in self.per_day.values() if count == 0)


def summarise(entries: list[coverage.Entry], days: int = 14, now: datetime | None = None) -> Summary:
    """直近のぶんを数える。空の日も1日として数える（出せなかった日も実績）。"""
    now = now or datetime.now()
    edge = now - timedelta(days=days)
    recent = [entry for entry in entries if entry.at >= edge]

    summary = Summary(days=days, total=len(recent))
    for offset in range(days):
        summary.per_day[(now - timedelta(days=offset)).date()] = 0
    for entry in recent:
        day = entry.at.date()
        if day in summary.per_day:
            summary.per_day[day] += 1
        summary.slots[entry.slot] += 1

    summary.themes = Counter(entry.key for entry in recent).most_common(5)
    return summary


def bars(summary: Summary, target: int) -> list[str]:
    """日ごとの本数を、目標に対する棒で見せる。"""
    rows = []
    for day in sorted(summary.per_day, reverse=True):
        count = summary.per_day[day]
        filled = "■" * count + "□" * max(0, target - count)
        rows.append(f"  {day:%m/%d}　{filled}　{count}本")
    return rows


def advice(summary: Summary, target: int) -> list[str]:
    """偏りに気づくための一言。"""
    notes: list[str] = []
    if summary.total == 0:
        return ["まだ記録がありません。draft を通すと記録されます"]

    if summary.average < target * 0.6:
        notes.append(
            f"1日あたり{summary.average:.1f}本です（目標{target}本）。"
            "本数を追うか、目標のほうを下げるか決めてください"
        )
    if summary.empty_days >= 3:
        notes.append(f"1本も出していない日が{summary.empty_days}日あります")

    if summary.slots:
        most, count = summary.slots.most_common(1)[0]
        if count > summary.total * 0.6:
            notes.append(f"『{most}』の枠に{count}本、偏っています")

    repeats = [(key, count) for key, count in summary.themes if count >= 3]
    for key, count in repeats:
        notes.append(f"『{key}』を{count}回扱っています。飽きられていないか見てください")
    return notes


def gaps(
    entries: list[coverage.Entry],
    leagues: dict,
    kinds: tuple[str, ...] = ("transfer", "match"),
    now: datetime | None = None,
) -> tuple[list[tuple[str, str, int]], list[tuple[str, int]]]:
    """何日ぶん扱っていないかを、リーグと種別ごとに返す。

    covered.yaml は繰り返しを止めるためのもの。裏返すと「追えていない領域」が
    見える。ずっと扱っていないリーグは、視聴者から見れば扱っていないのと同じ。
    """
    now = now or datetime.now()
    latest: dict[str, datetime] = {}
    latest_kind: dict[str, datetime] = {}
    for entry in entries:
        if entry.league:
            latest[entry.league] = max(latest.get(entry.league, entry.at), entry.at)
        if entry.kind:
            latest_kind[entry.kind] = max(latest_kind.get(entry.kind, entry.at), entry.at)

    league_rows = [
        (key, str((leagues.get(key) or {}).get("name") or key), _days(latest.get(key), now))
        for key in leagues
    ]
    kind_rows = [(kind, _days(latest_kind.get(kind), now)) for kind in kinds]

    # 「一度も扱っていない」がいちばん急ぐので先頭に置く
    league_rows.sort(key=lambda row: _urgency(row[2]), reverse=True)
    kind_rows.sort(key=lambda row: _urgency(row[1]), reverse=True)
    return league_rows, kind_rows


def _urgency(days: int) -> float:
    return float("inf") if days < 0 else days


def _days(when: datetime | None, now: datetime) -> int:
    """扱っていなければ -1（「一度も」の印）。"""
    return -1 if when is None else (now - when).days

"""どの検索が候補につながったかを記録する。

スキャンのクエリは15本ある。毎日全部回すが、何も返さないものが混ざっていても
気づけない。実際にEA Sportsの評価しか返さないクエリを1つ抱えていた。

候補を作ったときに「どの検索から来たか」を控えておけば、効かない検索が見える。
"""

from __future__ import annotations

from collections import Counter
from dataclasses import dataclass
from datetime import date, datetime, timedelta
from pathlib import Path

import yaml

from .config import _resolve

LEDGER = "research/queries.yaml"


@dataclass
class Run:
    """スキャンを1回回した記録。"""

    label: str          # 検索の名前（設定の label）
    at: datetime
    hits: int = 0       # 候補になった件数

    def to_dict(self) -> dict:
        return {"label": self.label, "at": self.at.isoformat(timespec="minutes"), "hits": self.hits}


def load(path: str | Path = LEDGER) -> list[Run]:
    target = _resolve(path)
    if not target.exists():
        return []
    raw = yaml.safe_load(target.read_text(encoding="utf-8")) or {}
    runs: list[Run] = []
    for row in raw.get("runs") or []:
        try:
            runs.append(
                Run(
                    label=str(row.get("label", "")),
                    at=datetime.fromisoformat(str(row.get("at"))),
                    hits=int(row.get("hits", 0)),
                )
            )
        except (TypeError, ValueError):
            continue
    return runs


def save(runs: list[Run], path: str | Path = LEDGER) -> Path:
    target = _resolve(path)
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(
        "# どの検索が候補につながったかの記録\n"
        + yaml.safe_dump(
            {"runs": [run.to_dict() for run in runs]}, allow_unicode=True, sort_keys=False
        ),
        encoding="utf-8",
    )
    return target


def record(counts: dict[str, int], now: datetime | None = None, path: str | Path = LEDGER) -> Path:
    """今回のスキャンの結果を足す。0件だった検索も記録する（それが知りたい）。"""
    now = now or datetime.now()
    runs = load(path)
    runs += [Run(label=label, at=now, hits=hits) for label, hits in counts.items()]
    return save(runs, path)


def tally(runs: list[Run], days: int = 30, now: datetime | None = None) -> list[tuple[str, int, int]]:
    """(検索の名前, 回した回数, 候補になった数)。候補の少ない順に並べる。"""
    now = now or datetime.now()
    edge = now - timedelta(days=days)
    recent = [run for run in runs if run.at >= edge]

    times: Counter = Counter()
    hits: Counter = Counter()
    for run in recent:
        times[run.label] += 1
        hits[run.label] += run.hits

    rows = [(label, times[label], hits[label]) for label in times]
    rows.sort(key=lambda row: (row[2], -row[1]))
    return rows


def dead(rows: list[tuple[str, int, int]], least_runs: int = 5) -> list[str]:
    """何度も回して1件も返していない検索。"""
    return [label for label, times, hits in rows if times >= least_runs and hits == 0]

"""伸びしろを検出するルールの入口。

2種類ある。

1. **ベースライン診断** -- どのプロジェクトでも満たしていたい水準との差分。
   器は `ruleset.py`、中身は `checks/` 配下（reliability / automation / docs）。
2. **横展開** -- あるPJTで既にやっている良い習慣を、まだのPJTへ持っていく。
   `practices.py`。

外から使うのは `run_all` だけでよい。
"""

from __future__ import annotations

from typing import Iterable

from . import checks  # noqa: F401  import した時点でルールが登録される
from .models import Finding, Snapshot
from .practices import PRACTICES, Practice, run_crosspollination
from .ruleset import baseline_rule_ids, rule, run_baseline

__all__ = [
    "PRACTICES",
    "Practice",
    "registered_rule_ids",
    "rule",
    "run_all",
    "run_baseline",
    "run_crosspollination",
]


def run_all(snapshots: Iterable[Snapshot]) -> list[Finding]:
    """ベースライン診断と横展開をまとめて走らせる。"""
    snaps = list(snapshots)
    return run_baseline(snaps) + run_crosspollination(snaps)


def registered_rule_ids() -> list[str]:
    return baseline_rule_ids() + [f"xpol.{p.id}" for p in PRACTICES]

"""ベースライン診断の登録と実行。

ルールの中身は `checks/` にあり、このモジュールは器だけを持つ。
分けているのは循環 import を避けるため（checks は `rule` を import し、
`rules` は checks を import する）。
"""

from __future__ import annotations

from typing import Callable, Iterable

from .models import Finding, Snapshot

RuleFn = Callable[[Snapshot], Finding | None]

# (ルールID, 対象とするプロジェクト種別, 判定関数)
_RULES: list[tuple[str, tuple[str, ...], RuleFn]] = []


def rule(rule_id: str, kinds: tuple[str, ...] = ()) -> Callable[[RuleFn], RuleFn]:
    """ルールを登録する。``kinds`` を指定すると対象種別を絞れる。

    ルールIDは台帳の指紋の材料になっている。**変えると過去の判断
    （解決済み・却下済み）との対応が切れる**ので、文面は自由に直してよいが
    IDは据え置く。
    """

    def deco(fn: RuleFn) -> RuleFn:
        _RULES.append((rule_id, kinds, fn))
        return fn

    return deco


def _f(snap: Snapshot, rule_id: str, **kw) -> Finding:
    """ルール本体から Finding を組み立てる小道具。"""
    return Finding(rule_id=rule_id, ref_key=snap.ref.key, **kw)


def run_baseline(snapshots: Iterable[Snapshot]) -> list[Finding]:
    """登録済みのルールを全プロジェクトに当てる。"""
    findings: list[Finding] = []
    for snap in snapshots:
        if snap.unavailable or not snap.ref.active:
            continue
        for rule_id, kinds, fn in _RULES:
            if kinds and snap.kind not in kinds:
                continue
            found = fn(snap)
            if found is not None:
                findings.append(found)
    return findings


def baseline_rule_ids() -> list[str]:
    return [rid for rid, _, _ in _RULES]

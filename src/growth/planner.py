"""検出結果 → 「今週やる分」への絞り込み。

このシステムで一番大事なのは、たくさん指摘することではなく
「今これをやればいい」が3つくらいに絞られていること。
全部並べられると結局どれも手をつけないので、意図的に上限をかける。
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any, Iterable

from .ledger import DISMISSED, OPEN, SNOOZED, Ledger
from .models import SEVERITY_WEIGHT, Finding, Proposal, Snapshot
from .survey import maturity_score

DEFAULTS = {
    "max_proposals_per_project": 3,
    "max_proposals_total": 12,
    "nag_decay_after": 3,
}


@dataclass
class Plan:
    """1回のランの結果一式。"""

    proposals: list[Proposal] = field(default_factory=list)
    deferred: list[Proposal] = field(default_factory=list)
    decisions: list[Proposal] = field(default_factory=list)
    snoozed: list[Proposal] = field(default_factory=list)
    resolved: list[dict[str, Any]] = field(default_factory=list)
    regressed: list[dict[str, Any]] = field(default_factory=list)
    scores: dict[str, int] = field(default_factory=dict)
    score_delta: dict[str, int] = field(default_factory=dict)
    snapshots: list[Snapshot] = field(default_factory=list)

    @property
    def new_proposals(self) -> list[Proposal]:
        return [p for p in self.proposals if p.is_new]

    @property
    def average_score(self) -> int:
        if not self.scores:
            return 0
        return int(round(sum(self.scores.values()) / len(self.scores)))

    def to_dict(self) -> dict[str, Any]:
        return {
            "proposals": [p.to_dict() for p in self.proposals],
            "decisions": [p.to_dict() for p in self.decisions],
            "snoozed": [p.to_dict() for p in self.snoozed],
            "deferred_count": len(self.deferred),
            "resolved": self.resolved,
            "regressed": self.regressed,
            "scores": self.scores,
            "score_delta": self.score_delta,
            "average_score": self.average_score,
            "projects": [s.to_dict() for s in self.snapshots],
        }


def merge_topics(findings: Iterable[Finding]) -> list[Finding]:
    """同じプロジェクトの同じ論点は1件にまとめる。

    ベースライン診断（「テストが無い」）と横展開（「よそはテストを書いている」）は
    同じことを指しているので、片方に寄せたうえでお手本の情報だけ引き継ぐ。
    """
    by_topic: dict[tuple[str, str], Finding] = {}
    standalone: list[Finding] = []

    for finding in findings:
        if not finding.topic:
            standalone.append(finding)
            continue
        key = (finding.ref_key, finding.topic)
        current = by_topic.get(key)
        if current is None:
            by_topic[key] = finding
            continue
        keep, drop = _pick_survivor(current, finding)
        if drop.exemplar and not keep.exemplar:
            keep.exemplar = drop.exemplar
            keep.action = f"{keep.action}\n参考: {drop.exemplar} が既に同じことをやっているので、そこから写すのが早い。"
            keep.evidence = list(dict.fromkeys([*keep.evidence, *drop.evidence]))
        by_topic[key] = keep

    return [*by_topic.values(), *standalone]


def _pick_survivor(a: Finding, b: Finding) -> tuple[Finding, Finding]:
    """重い方 / 具体的な方を残す。ベースライン診断を優先する。"""
    def rank(f: Finding) -> tuple[float, int, str]:
        return (
            SEVERITY_WEIGHT.get(f.severity, 0),
            0 if f.category == "crosspollination" else 1,
            f.rule_id,
        )

    return (a, b) if rank(a) >= rank(b) else (b, a)


def score_priority(
    finding: Finding, ledger: Ledger, weight: float, nag_decay_after: int
) -> float:
    """優先度。深刻度 × プロジェクト重み × ルールの信頼度 × しつこさ減衰。"""
    base = SEVERITY_WEIGHT.get(finding.severity, 10.0)
    confidence = ledger.rule_confidence(finding.rule_id)
    seen = ledger.seen_count(finding.fingerprint)
    if seen > nag_decay_after:
        # 何度も言って動いていないものは、他を押しのけないよう静かにする
        nag = 0.6 ** (seen - nag_decay_after)
    else:
        nag = 1.0
    return base * weight * confidence * nag


def build_plan(
    snapshots: list[Snapshot],
    findings: list[Finding],
    ledger: Ledger,
    config: dict[str, Any] | None = None,
) -> Plan:
    cfg = {**DEFAULTS, **(config or {})}
    merged = merge_topics(findings)
    report = ledger.reconcile(merged)

    weights = {s.ref.key: s.ref.weight for s in snapshots}
    scores = {s.ref.key: maturity_score(s) for s in snapshots if not s.unavailable}
    previous = ledger.previous_scores() or ledger.latest_scores()

    candidates: list[Proposal] = []
    for finding in merged:
        entry = ledger.entry(finding.fingerprint)
        if entry.get("status") == DISMISSED:
            continue  # 却下されたものは二度と出さない
        candidates.append(
            Proposal(
                finding=finding,
                priority=score_priority(
                    finding, ledger, weights.get(finding.ref_key, 1.0), cfg["nag_decay_after"]
                ),
                status=entry.get("status", OPEN),
                first_seen=entry.get("first_seen", ""),
                last_seen=entry.get("last_seen", ""),
                seen_count=int(entry.get("seen_count", 1)),
                issue_url=entry.get("issue_url"),
                note=entry.get("note"),
            )
        )

    candidates.sort(key=lambda p: (-p.priority, p.finding.ref_key, p.finding.rule_id))
    # 持ち主にしか決められないものは、作業リストの枠を使わない。
    # 同じ列に混ぜると、着手できない項目が上位を占めて全体が読まれなくなる。
    # 「見たうえで今はやらない」と記録したものは、理由つきで別枠に置く。
    # 消してしまうと判断の記録が残らず、作業枠に混ぜると毎回上位を占める。
    snoozed = [p for p in candidates if p.status == SNOOZED]
    rest = [p for p in candidates if p.status != SNOOZED]
    decisions = [p for p in rest if p.finding.decision]
    actionable = [p for p in rest if not p.finding.decision]
    selected, deferred = _apply_caps(actionable, cfg)

    ledger.record_history(scores, open_count=len(candidates))

    return Plan(
        proposals=selected,
        deferred=deferred,
        decisions=decisions,
        snoozed=snoozed,
        resolved=[_entry_summary(ledger, fp) for fp in report["resolved"]],
        regressed=[_entry_summary(ledger, fp) for fp in report["regressed"]],
        scores=scores,
        score_delta={k: v - previous.get(k, v) for k, v in scores.items()},
        snapshots=snapshots,
    )


def _apply_caps(
    candidates: list[Proposal], cfg: dict[str, Any]
) -> tuple[list[Proposal], list[Proposal]]:
    per_project = int(cfg["max_proposals_per_project"])
    total = int(cfg["max_proposals_total"])
    used: dict[str, int] = {}
    selected: list[Proposal] = []
    deferred: list[Proposal] = []

    for proposal in candidates:
        key = proposal.finding.ref_key
        # critical は上限を無視して必ず出す。漏らすと意味がない種類なので。
        forced = proposal.finding.severity == "critical"
        if not forced and (used.get(key, 0) >= per_project or len(selected) >= total):
            deferred.append(proposal)
            continue
        used[key] = used.get(key, 0) + 1
        selected.append(proposal)

    return selected, deferred


def _entry_summary(ledger: Ledger, fingerprint: str) -> dict[str, Any]:
    entry = ledger.entry(fingerprint)
    return {
        "fingerprint": fingerprint,
        "project": entry.get("project", "?"),
        "title": entry.get("title", "?"),
        "rule_id": entry.get("rule_id", "?"),
    }

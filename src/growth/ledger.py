"""台帳（growth/ledger.json）。このシステムの「記憶」にあたる部分。

これがあることで、成長ループは毎回ゼロから同じことを言うのではなく、

* 一度出した提案を二度出さない
* 却下された提案は以後黙る（学習）
* 指摘が消えたら「解決した」と記録して、成長を数字で残す
* 何度言っても着手されないものは静かにする（しつこくしない）

という振る舞いになる。
"""

from __future__ import annotations

import json
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable

from .models import Finding

LEDGER_VERSION = 1
OPEN = "open"
RESOLVED = "resolved"
DISMISSED = "dismissed"
SNOOZED = "snoozed"

# 今後もう提案しないステータス
MUTED_STATUSES = {DISMISSED}
# 「見たうえで今はやらない」。消さずに残すが、作業リストの枠は使わない。
DEFERRED_STATUSES = {SNOOZED}


def _now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def _today() -> str:
    return datetime.now(timezone.utc).date().isoformat()


@dataclass
class Ledger:
    path: Path
    version: int = LEDGER_VERSION
    proposals: dict[str, dict[str, Any]] = field(default_factory=dict)
    history: list[dict[str, Any]] = field(default_factory=list)
    rule_stats: dict[str, dict[str, int]] = field(default_factory=dict)
    # 起票済みのサマリ Issue（日付 -> URL）。
    # GitHub の一覧 API は直後の作成を返さないことがあるため、
    # 重複起票を防ぐ主たる根拠はこちら側に置く。
    summary_issues: dict[str, str] = field(default_factory=dict)

    # -- 入出力 ----------------------------------------------------------

    @classmethod
    def load(cls, path: Path) -> "Ledger":
        if not path.exists():
            return cls(path=path)
        data = json.loads(path.read_text(encoding="utf-8"))
        return cls(
            path=path,
            version=data.get("version", LEDGER_VERSION),
            proposals=data.get("proposals", {}),
            history=data.get("history", []),
            rule_stats=data.get("rule_stats", {}),
            summary_issues=data.get("summary_issues", {}),
        )

    def save(self) -> None:
        self.path.parent.mkdir(parents=True, exist_ok=True)
        payload = {
            "version": self.version,
            "updated_at": _now(),
            "proposals": self.proposals,
            "history": self.history,
            "rule_stats": self.rule_stats,
            "summary_issues": self.summary_issues,
        }
        self.path.write_text(
            json.dumps(payload, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
            encoding="utf-8",
        )

    # -- 記録 ------------------------------------------------------------

    def _stat(self, rule_id: str) -> dict[str, int]:
        return self.rule_stats.setdefault(
            rule_id, {"emitted": 0, "resolved": 0, "dismissed": 0}
        )

    def reconcile(self, findings: Iterable[Finding]) -> dict[str, list[str]]:
        """今回の検出結果と台帳を突き合わせて状態を更新する。

        返り値は ``{"new": [...], "resolved": [...], "regressed": [...]}``。
        1回のランにつき1度だけ呼ぶ。
        """
        findings = list(findings)
        current = {f.fingerprint: f for f in findings}
        report: dict[str, list[str]] = {"new": [], "resolved": [], "regressed": []}
        now = _now()
        today = _today()

        for fp, finding in current.items():
            entry = self.proposals.get(fp)
            if entry is None:
                self.proposals[fp] = {
                    "rule_id": finding.rule_id,
                    "project": finding.ref_key,
                    "title": finding.title,
                    "topic": finding.topic,
                    "exemplar": finding.exemplar,
                    "status": OPEN,
                    "first_seen": now,
                    "last_seen": now,
                    "last_seen_date": today,
                    "seen_count": 1,
                    "issue_url": None,
                }
                self._stat(finding.rule_id)["emitted"] += 1
                report["new"].append(fp)
                continue

            # 「何回言ったか」は日単位で数える。1日に複数回走らせただけで
            # しつこさ減衰がかかると、手元で確認するたびに提案が沈んでいく。
            if entry.get("last_seen_date") != today:
                entry["seen_count"] = int(entry.get("seen_count", 0)) + 1
            entry["last_seen_date"] = today
            entry["last_seen"] = now
            entry["title"] = finding.title
            entry["topic"] = finding.topic
            if entry.get("status") == RESOLVED:
                # 一度直ったものがまた出てきた = 退行。黙って戻さず記録する。
                entry["status"] = OPEN
                entry["regressed_at"] = now
                report["regressed"].append(fp)

        for fp, entry in self.proposals.items():
            if fp in current:
                continue
            if entry.get("status") in (OPEN, SNOOZED):
                entry["status"] = RESOLVED
                entry["resolved_at"] = now
                self._stat(entry.get("rule_id", "?"))["resolved"] += 1
                report["resolved"].append(fp)

        return report

    def mark(self, fingerprint: str, status: str, note: str | None = None) -> bool:
        """人が明示的に状態を変える（却下 / 対応済み など）。"""
        entry = self.proposals.get(fingerprint)
        if entry is None:
            return False
        previous = entry.get("status")
        entry["status"] = status
        entry["status_changed_at"] = _now()
        if note:
            entry["note"] = note
        if status == DISMISSED and previous != DISMISSED:
            self._stat(entry.get("rule_id", "?"))["dismissed"] += 1
        return True

    def attach_issue(self, fingerprint: str, url: str) -> None:
        entry = self.proposals.get(fingerprint)
        if entry is not None:
            entry["issue_url"] = url

    def record_history(self, scores: dict[str, int], open_count: int) -> None:
        """成熟度スコアの推移を残す。同じ日に2回走ったら上書きする。"""
        row = {
            "date": _today(),
            "scores": dict(sorted(scores.items())),
            "average": int(round(sum(scores.values()) / len(scores))) if scores else 0,
            "open": open_count,
            "resolved_total": sum(
                1 for e in self.proposals.values() if e.get("status") == RESOLVED
            ),
        }
        self.history = [h for h in self.history if h.get("date") != row["date"]]
        self.history.append(row)
        self.history.sort(key=lambda h: h["date"])
        # 直近1年ぶんだけ保持する
        self.history = self.history[-370:]

    # -- 参照 ------------------------------------------------------------

    def summary_issue_for(self, date: str) -> str | None:
        return self.summary_issues.get(date)

    def record_summary_issue(self, date: str, url: str) -> None:
        self.summary_issues[date] = url

    def is_muted(self, fingerprint: str) -> bool:
        entry = self.proposals.get(fingerprint)
        return bool(entry) and entry.get("status") in MUTED_STATUSES

    def entry(self, fingerprint: str) -> dict[str, Any]:
        return self.proposals.get(fingerprint, {})

    def seen_count(self, fingerprint: str) -> int:
        return int(self.proposals.get(fingerprint, {}).get("seen_count", 0))

    def rule_confidence(self, rule_id: str) -> float:
        """却下されがちなルールは自信を下げる = 出しゃばらなくなる。"""
        stat = self.rule_stats.get(rule_id)
        if not stat:
            return 1.0
        dismissed = stat.get("dismissed", 0)
        accepted = stat.get("resolved", 0)
        if dismissed == 0:
            return 1.0
        return max(0.15, 1.0 - dismissed / (dismissed + accepted + 1))

    def open_fingerprints(self) -> list[str]:
        return [fp for fp, e in self.proposals.items() if e.get("status") == OPEN]

    def snoozed_fingerprints(self) -> list[str]:
        return [fp for fp, e in self.proposals.items() if e.get("status") == SNOOZED]

    def latest_scores(self) -> dict[str, int]:
        return dict(self.history[-1]["scores"]) if self.history else {}

    def previous_scores(self) -> dict[str, int]:
        return dict(self.history[-2]["scores"]) if len(self.history) >= 2 else {}

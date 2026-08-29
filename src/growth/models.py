"""成長ループの中核データモデル。

外部依存なし（標準ライブラリのみ）。CI でも手元でも同じ挙動になるようにしている。
"""

from __future__ import annotations

import hashlib
from dataclasses import dataclass, field
from typing import Any

# --------------------------------------------------------------------------
# 深刻度と優先度
# --------------------------------------------------------------------------

SEVERITY_WEIGHT: dict[str, float] = {
    "critical": 100.0,
    "high": 60.0,
    "medium": 30.0,
    "low": 12.0,
}

SEVERITY_LABEL_JA: dict[str, str] = {
    "critical": "緊急",
    "high": "高",
    "medium": "中",
    "low": "低",
}

CATEGORY_LABEL_JA: dict[str, str] = {
    "security": "セキュリティ",
    "reliability": "動作の確からしさ",
    "automation": "自動化",
    "docs": "ドキュメント",
    "quality": "コード品質",
    "crosspollination": "他PJTからの横展開",
}


@dataclass(frozen=True)
class ProjectRef:
    """成長ループの管理対象となるプロジェクト1件。

    モノレポ（claude-code-dev）の場合は ``path`` にサブディレクトリを入れて、
    1リポジトリから複数の ProjectRef を作る。
    """

    key: str
    repo: str
    path: str = "."
    title: str = ""
    kind: str = "auto"
    tags: tuple[str, ...] = ()
    active: bool = True
    weight: float = 1.0
    # モノレポの親エントリで、子プロジェクトとして別途見るサブパス。
    # 親の観測からは除外して、子の中身が親の成績に混ざらないようにする。
    exclude: tuple[str, ...] = ()

    @property
    def slug(self) -> str:
        """人間にもマシンにも一意な識別子。"""
        if self.path in (".", "", None):
            return self.repo
        return f"{self.repo}/{self.path.strip('/')}"

    @property
    def display(self) -> str:
        return self.title or self.key

    @property
    def is_monorepo_child(self) -> bool:
        return self.path not in (".", "", None)


@dataclass
class Snapshot:
    """ある時点でのプロジェクトの観測結果。"""

    ref: ProjectRef
    collected_at: str
    kind: str
    files: list[str] = field(default_factory=list)
    signals: dict[str, Any] = field(default_factory=dict)
    unavailable: bool = False

    def has(self, name: str) -> bool:
        return bool(self.signals.get(name))

    def get(self, name: str, default: Any = None) -> Any:
        return self.signals.get(name, default)

    def to_dict(self) -> dict[str, Any]:
        return {
            "key": self.ref.key,
            "slug": self.ref.slug,
            "kind": self.kind,
            "collected_at": self.collected_at,
            "file_count": len(self.files),
            "unavailable": self.unavailable,
            "signals": self.signals,
        }


@dataclass
class Finding:
    """「ここが伸びしろ」1件。ルールが生成する。"""

    rule_id: str
    ref_key: str
    title: str
    why: str
    action: str
    severity: str = "medium"
    category: str = "quality"
    evidence: list[str] = field(default_factory=list)
    exemplar: str | None = None
    # 同じ論点をベースライン診断と横展開の両方から指摘したときに
    # まとめるためのキー（"tests" / "ci" など）。
    topic: str = ""
    # 持ち主にしか決められないもの（ライセンス選定、着手するか否か）。
    # 誰がやっても同じ「作業」と混ぜると、片付かない項目がいつまでも
    # 残り続けて、リストそのものが読まれなくなる。
    decision: bool = False

    @property
    def fingerprint(self) -> str:
        """同じ指摘を二度出さないための安定キー。

        タイトルや文面、お手本プロジェクトが変わっても指紋が変わらないよう、
        ルールIDと対象プロジェクトだけから作る。文面を推敲するたびに
        「新しい提案」として再通知されるのを防ぐため。
        """
        raw = f"{self.rule_id}|{self.ref_key}"
        return hashlib.sha1(raw.encode("utf-8")).hexdigest()[:12]


@dataclass
class Proposal:
    """台帳の状態を反映して優先度づけまで済んだ提案。"""

    finding: Finding
    priority: float
    status: str = "open"
    first_seen: str = ""
    last_seen: str = ""
    seen_count: int = 0
    issue_url: str | None = None
    note: str | None = None

    @property
    def fingerprint(self) -> str:
        return self.finding.fingerprint

    @property
    def is_new(self) -> bool:
        return self.seen_count <= 1

    def to_dict(self) -> dict[str, Any]:
        f = self.finding
        return {
            "fingerprint": self.fingerprint,
            "rule_id": f.rule_id,
            "project": f.ref_key,
            "title": f.title,
            "why": f.why,
            "action": f.action,
            "severity": f.severity,
            "category": f.category,
            "evidence": list(f.evidence),
            "exemplar": f.exemplar,
            "topic": f.topic,
            "decision": f.decision,
            "priority": round(self.priority, 2),
            "status": self.status,
            "first_seen": self.first_seen,
            "last_seen": self.last_seen,
            "seen_count": self.seen_count,
            "issue_url": self.issue_url,
            "note": self.note,
        }

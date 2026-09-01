"""横展開（cross-pollination）の定義。

あるPJTで既にうまくいっている習慣を、まだやっていないPJTへ持っていく。
ここが「依頼されなくても伝わる」部分の中心なので、ベースライン診断とは
別ファイルにしてある。

原則: **お手本が1つも無い習慣については何も言わない。**
「よそでできているのだからここでもできるはず」という根拠がある指摘だけを出す。
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Iterable

from .models import Finding, Snapshot


@dataclass(frozen=True)
class Practice:
    """あるPJTで既に実践している「良い習慣」の定義。"""

    id: str
    label: str
    signal: str
    topic: str
    applies_to: tuple[str, ...]
    why: str
    action: str
    severity: str = "medium"
    # この習慣がそもそも意味を持つ条件。満たさないプロジェクトは対象外にする。
    # 例: 依存を1つも持たないPJTに「バージョンを固定しろ」と言っても仕方がない。
    requires_signal: str | None = None


PRACTICES: tuple[Practice, ...] = (
    Practice(
        id="claude-md",
        label="CLAUDE.md で AI に前提を渡す",
        signal="has_claude_md",
        topic="claude-md",
        applies_to=("python", "node", "flutter", "other", "scaffold", "monorepo"),
        why="CLAUDE.md があると、毎回の依頼で環境や規約を説明し直さなくて済む。"
            "依頼のたびに前提を書く手間がそのまま消える。",
        action="お手本の CLAUDE.md を写し、このプロジェクト固有の"
               "「目的 / 構成 / 動かし方 / 気をつけること」に書き換える。",
        severity="medium",
    ),
    Practice(
        id="env-example",
        label=".env.example で必要な設定を明示する",
        signal="has_env_example",
        topic="env",
        applies_to=("python", "node"),
        why="設定漏れで動かない、という一番つまらない詰まり方を防げる。",
        action="お手本の .env.example に倣って、このプロジェクトで使う環境変数のキー名を並べる。",
        severity="low",
    ),
    Practice(
        id="ci-workflow",
        label="GitHub Actions で自動実行する",
        signal="has_ci",
        topic="ci",
        applies_to=("python", "node", "flutter"),
        why="手元で動かす前提だと、動かさなくなった時点で止まる。",
        action="お手本のワークフローを写して、このプロジェクト用のジョブに書き換える。",
        severity="medium",
    ),
    Practice(
        id="readme-runbook",
        label="README に実行コマンドを載せる",
        signal="readme_has_runbook",
        topic="readme",
        applies_to=("python", "node", "flutter"),
        why="同じ形式で書いてあると、どのPJTでも同じ手順で立ち上げられる。",
        action="お手本の README の「ローカルでの動作確認」節と同じ構成で書く。",
        severity="low",
    ),
    Practice(
        id="automated-tests",
        label="自動テストを置く",
        signal="has_tests",
        topic="tests",
        applies_to=("python", "node", "flutter"),
        why="1つのPJTでテストの型が決まれば、他PJTはそれを写すだけで済む。",
        action="お手本のテストの書き方（配置・命名・実行方法）をそのまま持ち込む。",
        severity="medium",
    ),
    Practice(
        id="pinned-deps",
        label="依存バージョンを固定する",
        signal="_pinned",
        topic="deps",
        applies_to=("python",),
        # requirements.txt を持たない（＝固定すべき依存が無い）PJTは対象外
        requires_signal="has_requirements",
        why="固定しているPJTがあるなら、他も揃えたほうが事故の起き方が読める。",
        action="お手本と同じく requirements.txt を `==` で固定する。",
        severity="low",
    ),
)


def _practice_holds(snap: Snapshot, practice: Practice) -> bool:
    if practice.signal == "_pinned":
        ratio = snap.get("pinned_ratio")
        return ratio is not None and ratio >= 0.8
    return snap.has(practice.signal)


def run_crosspollination(snapshots: Iterable[Snapshot]) -> list[Finding]:
    """既にどこかで実践している習慣を、まだのプロジェクトへ伝える。

    お手本が1つも無い習慣については何も言わない。
    「よそでできているのだからここでもできるはず」という根拠がある指摘だけを出す。
    """
    snaps = [s for s in snapshots if not s.unavailable and s.ref.active]
    findings: list[Finding] = []

    for practice in PRACTICES:
        holders = [s for s in snaps if _practice_holds(s, practice)]
        if not holders:
            continue
        # お手本は「その習慣を持っていて、かつ最も成熟しているもの」を選ぶ
        exemplar = max(holders, key=lambda s: (s.get("code_lines", 0), s.ref.key))
        for snap in snaps:
            if snap.kind not in practice.applies_to:
                continue
            if practice.requires_signal and not snap.has(practice.requires_signal):
                continue  # その習慣がそもそも意味を持たないPJT
            if _practice_holds(snap, practice):
                continue
            if snap.ref.key == exemplar.ref.key:
                continue
            findings.append(
                Finding(
                    rule_id=f"xpol.{practice.id}",
                    ref_key=snap.ref.key,
                    title=f"{practice.label}（{exemplar.ref.display} で既に実践中）",
                    why=practice.why,
                    action=practice.action,
                    severity=practice.severity,
                    category="crosspollination",
                    topic=practice.topic,
                    exemplar=exemplar.ref.key,
                    evidence=[f"お手本: {exemplar.ref.slug}"],
                )
            )
    return findings

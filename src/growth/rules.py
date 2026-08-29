"""伸びしろを検出するルール群。

2種類ある:

1. ベースライン診断 -- 「どのプロジェクトでも満たしていたい水準」との差分。
2. 横展開（cross-pollination） -- あるPJTで既にやっている良い習慣を、
   まだやっていないPJTへ持っていく。依頼されなくても勝手に伝播させるための仕組み。
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Callable, Iterable

from .models import Finding, Snapshot

# --------------------------------------------------------------------------
# ベースライン診断
# --------------------------------------------------------------------------

RuleFn = Callable[[Snapshot], Finding | None]
_RULES: list[tuple[str, tuple[str, ...], RuleFn]] = []


def rule(rule_id: str, kinds: tuple[str, ...] = ()) -> Callable[[RuleFn], RuleFn]:
    """ルールを登録する。``kinds`` を指定すると対象種別を絞れる。"""

    def deco(fn: RuleFn) -> RuleFn:
        _RULES.append((rule_id, kinds, fn))
        return fn

    return deco


def _f(snap: Snapshot, rule_id: str, **kw) -> Finding:
    return Finding(rule_id=rule_id, ref_key=snap.ref.key, **kw)


# --- セキュリティ ---------------------------------------------------------

@rule("secret.tracked-env-file")
def _tracked_env(snap: Snapshot) -> Finding | None:
    tracked = snap.get("tracked_env_file") or []
    if not tracked:
        return None
    return _f(
        snap, "secret.tracked-env-file",
        title=".env がリポジトリに入ってしまっている",
        why="API キーなどの実値が Git 履歴に残る。公開リポジトリなら即漏洩、"
            "非公開でも履歴からは消えないため早いほど傷が浅い。",
        action="該当ファイルを `git rm --cached` で追跡から外し、`.gitignore` に `.env` を追加する。"
               "併せて中身のキーをローテーションし、`.env.example` にキー名だけを残す。",
        severity="critical", category="security", topic="secrets",
        evidence=tracked,
    )


@rule("secret.hardcoded")
def _hardcoded_secret(snap: Snapshot) -> Finding | None:
    files = snap.get("hardcoded_secret_files") or []
    if not files:
        return None
    return _f(
        snap, "secret.hardcoded",
        title="コード中にキーらしき文字列が直書きされている疑い",
        why="そのままコミットされると鍵が漏れる。誤検知の可能性もあるので中身の確認が要る。",
        action="該当箇所を確認し、本物のキーなら環境変数（`os.environ`）に逃がしてローテーションする。"
               "ダミー値やテストデータなら、誤検知として無視してよい。",
        severity="critical", category="security", topic="secrets",
        evidence=files,
    )


@rule("secret.gitignore-env", kinds=("python", "node", "flutter"))
def _gitignore_env(snap: Snapshot) -> Finding | None:
    if not snap.has("uses_env_vars") or snap.has("gitignore_covers_env"):
        return None
    return _f(
        snap, "secret.gitignore-env",
        title="環境変数を使っているのに .gitignore が .env を除外していない",
        why="ローカルで `.env` を作った瞬間に、うっかりコミットする事故が起きる。",
        action="`.gitignore` に `.env` を追加する。1行で終わる割に事故の期待値が大きい。",
        severity="high", category="security", topic="secrets",
    )


# --- 動作の確からしさ -----------------------------------------------------

@rule("test.missing", kinds=("python", "node", "flutter"))
def _tests_missing(snap: Snapshot) -> Finding | None:
    if snap.has("has_tests") or snap.get("code_file_count", 0) < 2:
        return None
    return _f(
        snap, "test.missing",
        title="自動テストが1本もない",
        why=f"コードが {snap.get('code_file_count', 0)} ファイル / 約 {snap.get('code_lines', 0)} 行ある。"
            "この規模だと手で全部確かめるのは無理で、壊れたことに気づくのが本番になる。",
        action="まず一番壊れて困る関数1つに対してテストを1本書く。網羅は狙わない。"
               "`tests/test_<対象>.py` を作り、正常系1件・異常系1件から始める。",
        severity="high", category="reliability", topic="tests",
    )


@rule("test.empty-dir")
def _empty_test_dir(snap: Snapshot) -> Finding | None:
    if not snap.has("has_empty_test_dir") or snap.has("has_tests"):
        return None
    return _f(
        snap, "test.empty-dir",
        title="tests/ が空のまま置かれている",
        why="雛形だけ作って中身が入っていない状態。あるように見えて何も守っていない。",
        action="最初の1本を書くか、当面書かないなら tests/ を消して README に方針を書く。"
               "「あとで」を残しておくと、テストが無いことに気づけなくなる。",
        severity="low", category="reliability", topic="tests",
    )


@rule("ci.no-test-run")
def _ci_no_tests(snap: Snapshot) -> Finding | None:
    if not (snap.has("has_ci") and snap.has("has_tests")) or snap.has("ci_runs_tests"):
        return None
    return _f(
        snap, "ci.no-test-run",
        title="テストはあるが CI で実行されていない",
        why="手元で流し忘れたら意味がなくなる。せっかく書いたテストが放置される典型パターン。",
        action="既存のワークフローに `pytest`（Flutter なら `flutter test`）のステップを足す。",
        severity="high", category="automation", topic="ci",
        evidence=snap.get("ci_workflows") or [],
    )


@rule("ci.missing", kinds=("python", "node", "flutter"))
def _ci_missing(snap: Snapshot) -> Finding | None:
    if snap.has("has_ci") or snap.get("code_file_count", 0) < 2:
        return None
    return _f(
        snap, "ci.missing",
        title="CI が無く、push しても誰も検証していない",
        why="壊れたコードが master に入っても気づけない。",
        action="`.github/workflows/ci.yml` を追加し、push と pull_request で"
               "依存インストール + テスト（または最低限 import チェック）を走らせる。",
        severity="medium", category="automation", topic="ci",
    )


@rule("ci.silent-failure")
def _silent_failure(snap: Snapshot) -> Finding | None:
    if not snap.has("has_scheduled_workflow") or not snap.has("has_ci"):
        return None
    if snap.has("has_failure_alert"):
        return None  # 失敗時に鳴らす仕掛けが既にある
    return _f(
        snap, "ci.silent-failure",
        title="定期実行ジョブが黙って失敗する状態になっている",
        why="スケジュール実行は、失敗しても手元で気づく機会がない。"
            "データ更新が止まっていることに何日も後で気づく、という壊れ方をする。",
        action="ワークフロー末尾に `if: failure()` の通知ステップを足す（Issue 起票 / メール / Webhook のいずれか）。"
               "GitHub は定期ジョブ失敗を通知しない設定のこともあるので、明示的に鳴らす。",
        severity="high", category="automation", topic="alerting",
        evidence=snap.get("ci_workflows") or [],
    )


@rule("ci.unpinned-actions")
def _unpinned_actions(snap: Snapshot) -> Finding | None:
    refs = snap.get("unpinned_action_refs") or []
    if not refs:
        return None
    return _f(
        snap, "ci.unpinned-actions",
        title="GitHub Actions を @main / @master で参照している",
        why="上流の変更でいきなり CI が壊れる。自分は何も変えていないのに落ちる。",
        action="`uses:` をタグ（例 `@v4`）かコミット SHA に固定する。",
        severity="medium", category="automation", topic="ci-hygiene",
        evidence=refs,
    )


# --- 依存関係 -------------------------------------------------------------

@rule("deps.undeclared", kinds=("python",))
def _deps_undeclared(snap: Snapshot) -> Finding | None:
    if snap.has("declares_dependencies") or snap.get("python_file_count", 0) < 2:
        return None
    return _f(
        snap, "deps.undeclared",
        title="依存パッケージがどこにも書かれていない",
        why="別マシンや CI で動かすときに、何を入れればいいか誰も分からない。",
        action="`requirements.txt`（または `pyproject.toml`）を作り、import しているサードパーティを列挙する。",
        severity="high", category="reliability", topic="deps",
    )


@rule("deps.unpinned", kinds=("python",))
def _deps_unpinned(snap: Snapshot) -> Finding | None:
    ratio = snap.get("pinned_ratio")
    if ratio is None or ratio >= 0.5:
        return None
    return _f(
        snap, "deps.unpinned",
        title="依存バージョンが固定されていない",
        why="`>=` だけだと、上流の新バージョンが出た日に、コードを何も変えていないのに壊れる。"
            "定期実行しているプロジェクトほど痛い。",
        action="動いている今の環境で `pip freeze` を取り、`requirements.txt` を `==` で固定する。"
               "更新は Dependabot に任せて、上がったときに気づけるようにする。",
        severity="medium", category="reliability", topic="deps",
        evidence=[f"固定率 {int((ratio or 0) * 100)}% / 依存 {snap.get('dependency_count', 0)} 件"],
    )


@rule("deps.no-dependabot")
def _no_dependabot(snap: Snapshot) -> Finding | None:
    if snap.has("has_dependabot") or not snap.has("declares_dependencies"):
        return None
    return _f(
        snap, "deps.no-dependabot",
        title="依存更新の自動チェックが無い",
        why="脆弱性や非互換に気づくきっかけが無い。手動で見に行くのは続かない。",
        action="`.github/dependabot.yml` を追加し、pip / github-actions を weekly で監視させる。",
        severity="low", category="automation", topic="deps-update",
    )


@rule("env.no-example")
def _no_env_example(snap: Snapshot) -> Finding | None:
    if not snap.has("uses_env_vars") or snap.has("has_env_example"):
        return None
    return _f(
        snap, "env.no-example",
        title="必要な環境変数の一覧が無い",
        why="時間が経つと自分でも「何を設定すれば動くのか」が分からなくなる。",
        action="`.env.example` にキー名だけ（値は空）を並べる。README からそれを参照する。",
        severity="medium", category="docs", topic="env",
    )


# --- ドキュメント ---------------------------------------------------------

@rule("docs.readme-missing")
def _readme_missing(snap: Snapshot) -> Finding | None:
    if snap.has("has_readme"):
        return None
    return _f(
        snap, "docs.readme-missing",
        title="README が無い",
        why="何のプロジェクトで、どう動かすのかが分からない。数ヶ月後の自分が一番困る。",
        action="README.md に「目的」「動かし方」「構成」の3節を書く。長さは要らない。",
        severity="high", category="docs", topic="readme",
    )


@rule("docs.readme-no-runbook")
def _readme_no_runbook(snap: Snapshot) -> Finding | None:
    if not snap.has("has_readme") or snap.has("readme_has_runbook"):
        return None
    if snap.get("code_file_count", 0) == 0:
        return None
    return _f(
        snap, "docs.readme-no-runbook",
        title="README に「動かし方」のコマンドが書かれていない",
        why="セットアップ手順を毎回思い出すことになる。手が止まる原因のうち一番安く潰せる部分。",
        action="README にコードブロックで、環境構築 → 実行 のコマンドをそのまま貼れる形で書く。",
        severity="medium", category="docs", topic="readme",
    )


@rule("scaffold.dormant", kinds=("scaffold",))
def _dormant(snap: Snapshot) -> Finding | None:
    return _f(
        snap, "scaffold.dormant",
        title="雛形だけ作られて中身が無い",
        why="空のプロジェクトが並んでいると、どれが生きているのか分からなくなり、"
            "点検のノイズにもなる。",
        action="次の一手を1つだけ決めて README に書く（例:「最初に作る機能はこれ」）。"
               "当面やらないなら README にその旨を書くか、リポジトリをアーカイブする。",
        severity="low", category="quality", topic="dormant",
    )


@rule("quality.oversized-file")
def _oversized(snap: Snapshot) -> Finding | None:
    files = snap.get("oversized_files") or []
    if not files:
        return None
    return _f(
        snap, "quality.oversized-file",
        title="1ファイルが大きくなりすぎている",
        why="変更のたびに全体を読み直すことになり、手を入れる心理的コストが上がる。",
        action="責務ごとにモジュールを分ける。まず「他から呼ばれていない塊」を別ファイルに出すのが安全。",
        severity="low", category="quality", topic="structure",
        evidence=files,
    )


def run_baseline(snapshots: Iterable[Snapshot]) -> list[Finding]:
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


# --------------------------------------------------------------------------
# 横展開（cross-pollination）
# --------------------------------------------------------------------------

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


def run_all(snapshots: Iterable[Snapshot]) -> list[Finding]:
    snaps = list(snapshots)
    return run_baseline(snaps) + run_crosspollination(snaps)


def registered_rule_ids() -> list[str]:
    return [rid for rid, _, _ in _RULES] + [f"xpol.{p.id}" for p in PRACTICES]

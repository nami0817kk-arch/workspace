"""ベースライン診断のルール群。

「どのプロジェクトでも満たしていたい水準」との差分を出す。

もう一方の柱である横展開（あるPJTで既にやっている良い習慣を、まだやっていない
PJTへ持っていく仕組み）は `practices.py` にある。両方まとめて走らせるのは `run_all`。
"""

from __future__ import annotations

from typing import Callable, Iterable

from .models import Finding, Snapshot
from .practices import PRACTICES, Practice, run_crosspollination

__all__ = [
    "PRACTICES",
    "Practice",
    "registered_rule_ids",
    "rule",
    "run_all",
    "run_baseline",
    "run_crosspollination",
]

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


def run_all(snapshots: Iterable[Snapshot]) -> list[Finding]:
    """ベースライン診断と横展開をまとめて走らせる。"""
    snaps = list(snapshots)
    return run_baseline(snaps) + run_crosspollination(snaps)


def registered_rule_ids() -> list[str]:
    return [rid for rid, _, _ in _RULES] + [f"xpol.{p.id}" for p in PRACTICES]

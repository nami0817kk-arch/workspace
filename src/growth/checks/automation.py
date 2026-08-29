"""自動化まわりの診断。

CI の有無と作り、定期実行の安全弁、依存の宣言と更新。
人が見ていない時間に動くものが、黙って壊れないようにするための観点。
"""

from __future__ import annotations

from ..models import Finding, Snapshot
from ..ruleset import _f, rule


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

@rule("ci.no-timeout")
def _no_timeout(snap: Snapshot) -> Finding | None:
    workflows = snap.get("workflows_without_timeout") or []
    if not workflows:
        return None
    return _f(
        snap, "ci.no-timeout",
        title="ワークフローに実行時間の上限が無い",
        why="ネットワーク待ちなどでジョブがハングすると、GitHub の既定では"
            "6時間走り続けて Actions の実行時間を食い潰す。しかも失敗として"
            "扱われるのは6時間後になる。",
        action="各 job に `timeout-minutes:` を入れる（テストなら10分、"
               "取得や公開を伴うものでも30分あれば足りる）。",
        severity="medium", category="automation", topic="ci-hygiene",
        evidence=workflows,
    )

@rule("ci.broad-permissions")
def _broad_permissions(snap: Snapshot) -> Finding | None:
    workflows = snap.get("workflows_without_permissions") or []
    if not workflows:
        return None
    return _f(
        snap, "ci.broad-permissions",
        title="ワークフローがトークンの権限を絞っていない",
        why="`permissions:` を書かないと、リポジトリ既定の広い権限のまま動く。"
            "サードパーティの action を1つ入れただけで、それが書き込み権を持つ。",
        action="各ワークフローに必要な権限だけを明示する。"
               "読むだけなら `permissions:\n  contents: read`。",
        severity="medium", category="security", topic="ci-permissions",
        evidence=workflows,
    )

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

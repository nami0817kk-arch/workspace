"""ドキュメントと体裁の診断。

数ヶ月後の自分が読んで動かせるか、公開物として辻褄が合っているか。
"""

from __future__ import annotations

from ..models import Finding, Snapshot
from ..ruleset import _f, rule


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

@rule("docs.bom")
def _bom(snap: Snapshot) -> Finding | None:
    files = snap.get("bom_files") or []
    if not files:
        return None
    return _f(
        snap, "docs.bom",
        title="ファイル先頭に UTF-8 BOM が入っている",
        why="Windows のエディタで保存すると混入する。Linux 側のツールが"
            "先頭3バイトを本文として読み、見出しが崩れたり差分が汚れたりする。",
        action="BOM 無しの UTF-8 で保存し直す。",
        severity="low", category="docs", topic="encoding",
        evidence=files,
    )

@rule("docs.broken-link")
def _broken_link(snap: Snapshot) -> Finding | None:
    links = snap.get("broken_links") or []
    if not links:
        return None
    return _f(
        snap, "docs.broken-link",
        title="ドキュメント内のリンク先が存在しない",
        why="リンクをたどった先が無いと、書いてある内容自体が信用されなくなる。",
        action="リンク先を直すか、まだ無いものへのリンクなら文章から外す。",
        severity="low", category="docs", topic="links",
        evidence=links[:8],
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
        severity="low", category="quality", topic="dormant", decision=True,
    )

@rule("legal.no-license")
def _no_license(snap: Snapshot) -> Finding | None:
    if snap.ref.is_monorepo_child:
        return None  # ライセンスはリポジトリ単位。子PJTごとには置かない。
    if "public" not in snap.ref.tags or snap.has("has_license"):
        return None
    return _f(
        snap, "legal.no-license",
        title="公開リポジトリにライセンスが無い",
        why="ライセンスが無いコードは、既定では誰も使えない（全権利留保）。"
            "公開している意図と実際の扱いが食い違う。",
        action="意図に合う LICENSE ファイルを置く。"
               "自由に使ってよいなら MIT、そうでないなら README に条件を明記する。",
        severity="medium", category="docs", topic="license", decision=True,
    )


@rule("docs.stale-reference")
def _stale_reference(snap: Snapshot) -> Finding | None:
    refs = snap.get("stale_references") or []
    if not refs:
        return None
    return _f(
        snap, "docs.stale-reference",
        title="ドキュメントが存在しないファイルを載せている",
        why="実装をやめた・移した機能の記述が残っていると、"
            "そこだけでなくドキュメント全体が信用されなくなる。",
        action="記述を消すか、実際のパスに直す。"
               "これから作る予定のものなら「未実装」と分かるように書く。",
        severity="low", category="docs", topic="doc-accuracy",
        evidence=refs[:8],
    )

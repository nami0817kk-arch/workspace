"""各プロジェクトの現状を観測して Snapshot にする。

ネットワークには触らない。ローカルにクローン済みのディレクトリだけを読む。
そのぶんテストしやすく、CI でも手元でも同じ結果になる。
"""

from __future__ import annotations

from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from .models import ProjectRef, Snapshot
from .signals import (
    CODE_EXTS,
    SKIP_DIRS,
    collect_signals,
)


def _now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def walk_files(root: Path, exclude: tuple[str, ...] = ()) -> list[str]:
    """SKIP_DIRS と ``exclude`` を除いた相対パス一覧（posix 表記）。"""
    out: list[str] = []
    if not root.is_dir():
        return out
    prefixes = tuple(f"{e.strip('/')}/" for e in exclude if e not in (".", "", None))
    for path in root.rglob("*"):
        if not path.is_file():
            continue
        rel = path.relative_to(root).as_posix()
        if set(path.relative_to(root).parts) & SKIP_DIRS:
            continue
        if prefixes and rel.startswith(prefixes):
            continue
        out.append(rel)
    return sorted(out)


def repo_root_for(workspace: Path, ref: ProjectRef) -> Path:
    return workspace / ref.repo.split("/")[-1]


def collect(workspace: Path, ref: ProjectRef) -> Snapshot:
    """1プロジェクト分の観測。

    サブプロジェクトの場合、CI や dependabot などリポジトリ全体にしか
    存在しえないものは親リポジトリ側を見る。
    """
    repo_root = repo_root_for(workspace, ref)
    proj_root = repo_root if ref.path in (".", "", None) else repo_root / ref.path

    if not proj_root.is_dir():
        return Snapshot(ref=ref, collected_at=_now(), kind="unknown", unavailable=True)

    files = walk_files(proj_root, ref.exclude)
    repo_files = files if proj_root == repo_root else walk_files(repo_root)

    signals = collect_signals(proj_root, files, repo_root, repo_files, ref)

    kind = ref.kind if ref.kind not in ("auto", "") else infer_kind(files, signals)
    signals["kind"] = kind
    signals["file_count"] = len(files)
    return Snapshot(ref=ref, collected_at=_now(), kind=kind, files=files, signals=signals)


def infer_kind(files: list[str], signals: dict[str, Any]) -> str:
    """プロジェクトの種類を推定する。ルールの適用範囲を絞るのに使う。"""
    names = {f.split("/")[-1] for f in files}
    if "pubspec.yaml" in names:
        return "flutter"
    if "package.json" in names:
        return "node"
    if signals.get("code_file_count", 0) == 0:
        return "scaffold"
    if signals.get("python_file_count", 0) > 0:
        return "python"
    return "other"


# --------------------------------------------------------------------------
# 成熟度スコア
# --------------------------------------------------------------------------

# 「これがあると健全」という観点の重み。合計 100 になるよう正規化して使う。
MATURITY_WEIGHTS: dict[str, float] = {
    "has_readme": 10,
    "readme_has_runbook": 10,
    "has_tests": 20,
    "has_ci": 12,
    "ci_runs_tests": 13,
    "has_gitignore": 5,
    "gitignore_covers_env": 5,
    "declares_dependencies": 8,
    "has_claude_md": 7,
    "no_secret_risk": 10,
}


# モノレポの入れ物リポジトリには、テストや依存宣言を求めても意味がない。
# 実装は子プロジェクト側にあるので、入れ物としての観点だけで採点する。
MONOREPO_CRITERIA = (
    "has_readme", "readme_has_runbook", "has_gitignore",
    "gitignore_covers_env", "has_claude_md", "no_secret_risk",
)


def _criteria_for(kind: str) -> dict[str, float]:
    if kind == "monorepo":
        return {k: v for k, v in MATURITY_WEIGHTS.items() if k in MONOREPO_CRITERIA}
    return MATURITY_WEIGHTS


def maturity_score(snapshot: Snapshot) -> int:
    """0-100 の成熟度。時系列で見ると「育っているか」が分かる。"""
    if snapshot.unavailable:
        return 0
    if snapshot.kind == "scaffold":
        # 空の雛形に満点近い点がつくと成長が見えなくなるので、
        # 中身のない状態は明示的に低く出す。
        return 15 if snapshot.has("has_readme") else 0

    criteria = _criteria_for(snapshot.kind)
    got = 0.0
    for name, weight in criteria.items():
        if name == "no_secret_risk":
            ok = not snapshot.get("tracked_env_file") and not snapshot.get("hardcoded_secret_files")
        else:
            ok = snapshot.has(name)
        if ok:
            got += weight
    total = sum(criteria.values())
    return int(round(got / total * 100)) if total else 0

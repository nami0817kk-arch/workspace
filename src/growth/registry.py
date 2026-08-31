"""管理対象プロジェクトの台帳（growth/projects.toml）の読み込み。

TOML は Python 3.11 標準の tomllib で読むので追加依存はない。
モノレポは ``subprojects`` にグロブを書いておくと、実際のディレクトリを
見て子プロジェクトへ自動展開される。手で1つずつ登録しなくてよい。
"""

from __future__ import annotations

import dataclasses
import tomllib
from pathlib import Path

from .models import ProjectRef

DEFAULT_REGISTRY = Path("growth/projects.toml")

# サブプロジェクト展開時に無視するディレクトリ名
_IGNORED_DIRS = {
    ".git", ".github", ".venv", "venv", "node_modules", "__pycache__",
    ".dart_tool", "build", "dist", "output", ".idea", ".vscode",
}


def load_registry(path: Path) -> tuple[list[ProjectRef], dict]:
    """projects.toml を読み、ProjectRef の一覧と設定を返す。"""
    data = tomllib.loads(path.read_text(encoding="utf-8"))
    config = data.get("config", {})
    refs: list[ProjectRef] = []
    for entry in data.get("project", []):
        refs.append(_ref_from_entry(entry))
    return refs, config


def _ref_from_entry(entry: dict) -> ProjectRef:
    repo = entry["repo"]
    path = entry.get("path", ".")
    key = entry.get("key") or _default_key(repo, path)
    return ProjectRef(
        key=key,
        repo=repo,
        path=path,
        title=entry.get("title", ""),
        kind=entry.get("kind", "auto"),
        tags=tuple(entry.get("tags", [])),
        active=bool(entry.get("active", True)),
        weight=float(entry.get("weight", 1.0)),
    )


def _default_key(repo: str, path: str) -> str:
    name = repo.split("/")[-1]
    if path in (".", "", None):
        return name
    return f"{name}/{path.strip('/')}"


def expand_subprojects(
    refs: list[ProjectRef], workspace: Path, registry_path: Path
) -> list[ProjectRef]:
    """``subprojects`` グロブを実ディレクトリに展開する。

    親エントリ自体も残す（リポジトリ全体にかかるルールがあるため）。
    """
    data = tomllib.loads(registry_path.read_text(encoding="utf-8"))
    patterns: dict[str, list[str]] = {}
    for entry in data.get("project", []):
        globs = entry.get("subprojects")
        if globs:
            key = entry.get("key") or _default_key(entry["repo"], entry.get("path", "."))
            patterns[key] = list(globs)

    expanded: list[ProjectRef] = []
    for ref in refs:
        children: list[ProjectRef] = []
        for pattern in patterns.get(ref.key, []):
            children.extend(_expand_one(ref, workspace, pattern))
        if children:
            # 親は「入れ物としてのリポジトリ」として見る。子の中身を数えると
            # 親がいつも優等生に見えてしまい、横展開のお手本選びが狂う。
            ref = dataclasses.replace(
                ref,
                exclude=tuple(c.path for c in children),
                kind="monorepo" if ref.kind == "auto" else ref.kind,
            )
        expanded.append(ref)
        expanded.extend(children)
    return _dedupe(expanded)


def _expand_one(parent: ProjectRef, workspace: Path, pattern: str) -> list[ProjectRef]:
    root = workspace / parent.repo.split("/")[-1]
    if not root.is_dir():
        return []
    out: list[ProjectRef] = []
    for child in sorted(root.glob(pattern)):
        if not child.is_dir() or child.name in _IGNORED_DIRS:
            continue
        rel = child.relative_to(root).as_posix()
        out.append(
            ProjectRef(
                key=f"{parent.repo.split('/')[-1]}/{rel}",
                repo=parent.repo,
                path=rel,
                title=child.name,
                kind="auto",
                tags=parent.tags + ("subproject",),
                active=parent.active,
                weight=parent.weight,
            )
        )
    return out


def _dedupe(refs: list[ProjectRef]) -> list[ProjectRef]:
    seen: set[str] = set()
    out: list[ProjectRef] = []
    for ref in refs:
        if ref.key in seen:
            continue
        seen.add(ref.key)
        out.append(ref)
    return out


def repo_names(refs: list[ProjectRef]) -> list[str]:
    """クローンが必要なリポジトリ名（owner/name）の重複なし一覧。"""
    seen: set[str] = set()
    out: list[str] = []
    for ref in refs:
        if ref.repo not in seen:
            seen.add(ref.repo)
            out.append(ref.repo)
    return out

"""各プロジェクトの現状を観測して Snapshot にする。

ネットワークには触らない。ローカルにクローン済みのディレクトリだけを読む。
そのぶんテストしやすく、CI でも手元でも同じ結果になる。
"""

from __future__ import annotations

import re
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from .models import ProjectRef, Snapshot

SKIP_DIRS = {
    ".git", ".venv", "venv", "node_modules", "__pycache__", ".dart_tool",
    "build", "dist", "output", ".pytest_cache", ".mypy_cache", ".idea",
    ".vscode", ".gradle", "Pods",
}

CODE_EXTS = {".py", ".dart", ".js", ".ts", ".tsx", ".jsx", ".go", ".rs", ".kt", ".java"}
TEST_NAME_RE = re.compile(r"(^test_.*\.py$|.*_test\.py$|.*_test\.dart$|.*\.test\.[jt]sx?$)")
TEST_RUNNER_RE = re.compile(r"\b(pytest|unittest|flutter test|npm test|vitest|jest|go test)\b")
ENV_USE_RE = re.compile(r"os\.environ|os\.getenv|getenv\(|load_dotenv|dotenv|process\.env")
SECRET_LITERAL_RE = re.compile(
    r"""(?ix)
    (api[_-]?key|secret|token|password|passwd)
    \s*[:=]\s*
    ['"][A-Za-z0-9_\-/+]{16,}['"]
    """
)
OVERSIZED_LINES = 400
MAX_READ_BYTES = 400_000


def _now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def _read_text(path: Path) -> str:
    try:
        raw = path.read_bytes()[:MAX_READ_BYTES]
    except OSError:
        return ""
    return raw.decode("utf-8", errors="replace")


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

    signals: dict[str, Any] = {}
    signals.update(_docs_signals(proj_root, files))
    signals.update(_test_signals(proj_root, files))
    signals.update(_dependency_signals(proj_root, files))
    signals.update(_secret_signals(proj_root, files))
    signals.update(_code_signals(proj_root, files))
    signals.update(_repo_signals(repo_root, repo_files, ref))

    kind = ref.kind if ref.kind not in ("auto", "") else infer_kind(files, signals)
    signals["kind"] = kind
    signals["file_count"] = len(files)
    return Snapshot(ref=ref, collected_at=_now(), kind=kind, files=files, signals=signals)


# --------------------------------------------------------------------------
# 個別シグナル
# --------------------------------------------------------------------------

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


def _docs_signals(root: Path, files: list[str]) -> dict[str, Any]:
    readme = next((f for f in files if f.lower() in ("readme.md", "readme.rst", "readme.txt")), None)
    body = _read_text(root / readme) if readme else ""
    has_fence = "```" in body
    setup_words = ("インストール", "セットアップ", "使い方", "実行", "install", "setup", "usage", "run")
    return {
        "has_readme": readme is not None,
        "readme_bytes": len(body.encode("utf-8")),
        "readme_has_runbook": has_fence and any(w in body.lower() or w in body for w in setup_words),
        "has_claude_md": any(f.upper() == "CLAUDE.MD" for f in files),
        "has_license": any(f.split("/")[-1].upper().startswith("LICENSE") for f in files),
        "doc_file_count": sum(1 for f in files if f.endswith(".md")),
    }


def _test_signals(root: Path, files: list[str]) -> dict[str, Any]:
    test_files = [f for f in files if TEST_NAME_RE.match(f.split("/")[-1])]
    has_test_dir = any(f.startswith(("tests/", "test/")) for f in files)
    return {
        "test_file_count": len(test_files),
        "has_tests": len(test_files) > 0,
        "has_empty_test_dir": has_test_dir and len(test_files) == 0,
    }


def _dependency_signals(root: Path, files: list[str]) -> dict[str, Any]:
    names = {f.split("/")[-1] for f in files if "/" not in f}
    out: dict[str, Any] = {
        "has_requirements": "requirements.txt" in names,
        "has_pyproject": "pyproject.toml" in names,
        "has_lockfile": bool(
            names & {"poetry.lock", "requirements.lock", "pubspec.lock", "package-lock.json", "uv.lock"}
        ),
        "pinned_ratio": None,
        "declares_dependencies": bool(
            names & {"requirements.txt", "pyproject.toml", "pubspec.yaml", "package.json"}
        ),
    }
    if out["has_requirements"]:
        lines = [
            ln.strip()
            for ln in _read_text(root / "requirements.txt").splitlines()
            if ln.strip() and not ln.strip().startswith("#")
        ]
        if lines:
            pinned = sum(1 for ln in lines if "==" in ln)
            out["pinned_ratio"] = round(pinned / len(lines), 3)
            out["dependency_count"] = len(lines)
    return out


def _secret_signals(root: Path, files: list[str]) -> dict[str, Any]:
    gitignore = _read_text(root / ".gitignore") if ".gitignore" in files else ""
    uses_env = False
    hardcoded: list[str] = []
    for f in files:
        if not f.endswith(tuple(CODE_EXTS)):
            continue
        text = _read_text(root / f)
        if ENV_USE_RE.search(text):
            uses_env = True
        # テストコードにはダミーの鍵がよく出てくる。そこで鳴らすと
        # 毎回同じ誤検知が出て、本物の指摘まで信用されなくなる。
        if not _is_test_file(f) and SECRET_LITERAL_RE.search(text):
            hardcoded.append(f)
    return {
        "has_gitignore": ".gitignore" in files,
        "gitignore_covers_env": ".env" in gitignore,
        "has_env_example": any(f.split("/")[-1] in (".env.example", ".env.sample") for f in files),
        "uses_env_vars": uses_env,
        "tracked_env_file": [f for f in files if f.split("/")[-1] == ".env"],
        "hardcoded_secret_files": hardcoded,
    }


def _is_test_file(rel: str) -> bool:
    parts = rel.split("/")
    name = parts[-1]
    return (
        bool(TEST_NAME_RE.match(name))
        or name in ("conftest.py", "helpers.py")
        or parts[0] in ("tests", "test")
    )


def _code_signals(root: Path, files: list[str]) -> dict[str, Any]:
    code = [f for f in files if f.endswith(tuple(CODE_EXTS))]
    oversized: list[str] = []
    total_lines = 0
    for f in code:
        n = _read_text(root / f).count("\n") + 1
        total_lines += n
        if n > OVERSIZED_LINES:
            oversized.append(f"{f} ({n}行)")
    return {
        "code_file_count": len(code),
        "python_file_count": sum(1 for f in code if f.endswith(".py")),
        "code_lines": total_lines,
        "oversized_files": sorted(oversized),
    }


def _repo_signals(repo_root: Path, repo_files: list[str], ref: ProjectRef) -> dict[str, Any]:
    """リポジトリ全体にしか存在しないもの（CI 等）を見る。"""
    workflows = [f for f in repo_files if f.startswith(".github/workflows/") and f.endswith((".yml", ".yaml"))]
    texts = {w: _read_text(repo_root / w) for w in workflows}
    joined = "\n".join(texts.values())

    covering = workflows
    if ref.is_monorepo_child:
        # サブPJTを扱っているワークフローだけを「このPJTのCI」とみなす
        covering = [w for w, t in texts.items() if ref.path.strip("/") in t]

    covering_text = "\n".join(texts[w] for w in covering)

    return {
        "repo_workflow_count": len(workflows),
        "has_ci": len(covering) > 0,
        "ci_workflows": covering,
        "ci_runs_tests": any(TEST_RUNNER_RE.search(texts[w]) for w in covering),
        "has_scheduled_workflow": "schedule:" in covering_text or "cron:" in covering_text,
        "has_failure_alert": bool(re.search(r"failure\(\)|if:\s*failure", covering_text)),
        "workflow_uses_secrets": "secrets." in covering_text,
        "unpinned_action_refs": sorted(
            set(re.findall(r"uses:\s*([\w.\-/]+@(?:master|main))", covering_text))
        ),
        "has_dependabot": any(
            f in (".github/dependabot.yml", ".github/dependabot.yaml") for f in repo_files
        ),
        "has_issue_template": any(f.startswith(".github/ISSUE_TEMPLATE") for f in repo_files),
    }


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

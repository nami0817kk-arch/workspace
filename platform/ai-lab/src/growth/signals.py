"""観測したファイル群から個別のシグナルを取り出す関数群。

ここに並んでいる `_*_signals` が、ルールの判断材料そのものになる。
新しいルールに新しい材料が要るなら、まずこのファイルに足す。
どれもファイルを読むだけで、ネットワークには出ない。
"""

from __future__ import annotations

import ast
import re
from pathlib import Path
from typing import Any

from .models import ProjectRef

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
LONG_FUNCTION_LINES = 100
MAX_READ_BYTES = 400_000

def _read_text(path: Path) -> str:
    try:
        raw = path.read_bytes()[:MAX_READ_BYTES]
    except OSError:
        return ""
    return raw.decode("utf-8", errors="replace")

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
    long_functions: list[str] = []
    total_lines = 0
    for f in code:
        text = _read_text(root / f)
        n = text.count("\n") + 1
        total_lines += n
        # テストファイルはケースが増えれば当然伸びる。長さ自体は欠陥ではないので
        # 数えない。ここで鳴らすと「テストを書くと怒られる」ことになる。
        if n > OVERSIZED_LINES and not _is_test_file(f):
            oversized.append(f"{f} ({n}行)")
        if f.endswith(".py") and not _is_test_file(f):
            long_functions.extend(_long_functions(f, text))
    return {
        "code_file_count": len(code),
        "python_file_count": sum(1 for f in code if f.endswith(".py")),
        "code_lines": total_lines,
        "oversized_files": sorted(oversized),
        "long_functions": sorted(long_functions),
    }


def _long_functions(rel: str, text: str) -> list[str]:
    """長すぎる関数を構文木で拾う。

    ファイルの行数より、こちらのほうが手を入れる場所を名指しできる。
    """
    try:
        tree = ast.parse(text)
    except SyntaxError:
        return []
    out = []
    for node in ast.walk(tree):
        if not isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
            continue
        length = (node.end_lineno or node.lineno) - node.lineno
        if length > LONG_FUNCTION_LINES:
            out.append(f"{rel}:{node.lineno} {node.name}() {length}行")
    return out


# 例外を受けたあと何も残さずに処理を進める文
_SILENT_STMTS = (ast.Pass, ast.Continue, ast.Break)

# 「何が起きても」捕まえる書き方。ここで握りつぶすと原因が完全に消える。
_BROAD_EXCEPTIONS = {"Exception", "BaseException"}


def _is_broad_handler(node: ast.ExceptHandler) -> bool:
    """捕まえる例外が広すぎるか。

    `except (IndexError, ValueError): continue` のように種類を絞ったものは、
    「この行は飛ばす」という意図の表明として妥当なので対象にしない。
    絞らずに握りつぶしているものだけを拾う。
    """
    if node.type is None:
        return True
    targets = node.type.elts if isinstance(node.type, ast.Tuple) else [node.type]
    return any(isinstance(t, ast.Name) and t.id in _BROAD_EXCEPTIONS for t in targets)


def _robustness_signals(root: Path, files: list[str]) -> dict[str, Any]:
    """握りつぶされた例外を AST で拾う。

    `except ...: pass` は、失敗しても呼び出し側が何も知らないまま先へ進む。
    正規表現では複数行の本体を見誤るので構文木で判定する。
    """
    swallowed: list[str] = []
    bare: list[str] = []
    for rel in files:
        if not rel.endswith(".py") or _is_test_file(rel):
            continue
        try:
            tree = ast.parse(_read_text(root / rel))
        except SyntaxError:
            continue
        for node in ast.walk(tree):
            if not isinstance(node, ast.ExceptHandler):
                continue
            if node.type is None:
                bare.append(f"{rel}:{node.lineno}")
            # `pass` だけでなく `continue` / `break` だけの本体も、
            # 失敗を黙って飛ばしている点では同じ。
            if _is_broad_handler(node) and all(
                isinstance(stmt, _SILENT_STMTS) for stmt in node.body
            ):
                swallowed.append(f"{rel}:{node.lineno}")
    return {
        "swallowed_exceptions": sorted(swallowed),
        "bare_excepts": sorted(bare),
    }


_TEXT_EXTS = (".py", ".md", ".txt", ".toml", ".yml", ".yaml", ".json", ".csv")


def _encoding_signals(root: Path, files: list[str]) -> dict[str, Any]:
    """UTF-8 BOM 付きのテキストファイルを拾う。

    Windows のエディタで保存すると混入しやすく、Linux 側のツールが
    先頭3バイトを本文として読んでしまう。
    """
    bom: list[str] = []
    for rel in files:
        if not rel.endswith(_TEXT_EXTS):
            continue
        try:
            head = (root / rel).open("rb").read(3)
        except OSError:
            continue
        if head == b"\xef\xbb\xbf":
            bom.append(rel)
    return {"bom_files": sorted(bom)}


_MD_LINK_RE = re.compile(r"\[[^\]]*\]\(([^)\s]+)\)")

# ドキュメント中の `src/foo/bar.py` のようなパス参照。
# 区切りを含むものだけを見る。`rules.py` のような裸のファイル名は
# 文中の言及であることが多く、拾うと誤検知だらけになる。
_MD_PATH_RE = re.compile(
    r"`([A-Za-z0-9_.-]+(?:/[A-Za-z0-9_.-]+)+\.(?:py|dart|toml|txt|yml|yaml|json|md|csv))`"
)


def _link_signals(root: Path, files: list[str], repo_root: Path) -> dict[str, Any]:
    """Markdown 内の相対リンクのうち、実在しない先を拾う。"""
    broken: list[str] = []
    for rel in files:
        if not rel.endswith(".md"):
            continue
        base = (root / rel).parent
        for target in _MD_LINK_RE.findall(_read_text(root / rel)):
            if target.startswith(("http://", "https://", "#", "mailto:")):
                continue
            path = target.split("#", 1)[0]
            if not path:
                continue
            if not any((r / path).exists() for r in (base, root, repo_root)):
                broken.append(f"{rel} -> {target}")
    return {"broken_links": sorted(set(broken))}


def _reference_signals(root: Path, files: list[str], repo_root: Path) -> dict[str, Any]:
    """ドキュメントが「ある」と書いているのに実在しないパスを拾う。

    実装をやめた・移した機能が README に残り続けると、
    書いてある内容全体が信用されなくなる。
    """
    stale: list[str] = []
    for rel in files:
        if not rel.endswith(".md"):
            continue
        base = (root / rel).parent
        for target in _MD_PATH_RE.findall(_read_text(root / rel)):
            # サブPJTのドキュメントから `.github/workflows/...` のような
            # リポジトリ直下のパスを指すことがあるので、そちらも見る。
            if any((r / target).exists() for r in (root, base, repo_root)):
                continue
            stale.append(f"{rel} -> {target}")
    return {"stale_references": sorted(set(stale))}


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
        "workflows_without_timeout": [
            w for w in covering if "timeout-minutes" not in texts[w]
        ],
        "workflows_without_permissions": [
            w for w in covering if not re.search(r"^permissions:", texts[w], re.M)
        ],
        "has_dependabot": any(
            f in (".github/dependabot.yml", ".github/dependabot.yaml") for f in repo_files
        ),
        "has_issue_template": any(f.startswith(".github/ISSUE_TEMPLATE") for f in repo_files),
    }


def collect_signals(
    proj_root: Path, files: list[str], repo_root: Path, repo_files: list[str], ref: ProjectRef
) -> dict[str, Any]:
    """観測の全シグナルを1つの辞書にまとめる。

    ルールを足すときにここへ1行加えるだけで済むよう、
    個別の抽出関数の呼び出しはここに集約している。
    """
    out: dict[str, Any] = {}
    out.update(_docs_signals(proj_root, files))
    out.update(_test_signals(proj_root, files))
    out.update(_dependency_signals(proj_root, files))
    out.update(_secret_signals(proj_root, files))
    out.update(_code_signals(proj_root, files))
    out.update(_robustness_signals(proj_root, files))
    out.update(_encoding_signals(proj_root, files))
    out.update(_link_signals(proj_root, files, repo_root))
    out.update(_reference_signals(proj_root, files, repo_root))
    out.update(_repo_signals(repo_root, repo_files, ref))
    return out

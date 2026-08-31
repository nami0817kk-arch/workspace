"""テスト用の擬似プロジェクトを組み立てるヘルパ。"""

from __future__ import annotations

from pathlib import Path

from growth.models import ProjectRef


def make_repo(workspace: Path, name: str, files: dict[str, str]) -> Path:
    """``files`` の相対パス→中身 でリポジトリを作る。"""
    root = workspace / name
    for rel, content in files.items():
        target = root / rel
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(content, encoding="utf-8")
    root.mkdir(parents=True, exist_ok=True)
    return root


def ref(name: str, path: str = ".", **kw) -> ProjectRef:
    return ProjectRef(key=kw.pop("key", name), repo=f"owner/{name}", path=path, **kw)


PY_APP = "import os\n\nAPI = os.environ['TOKEN']\n\n\ndef run():\n    return API\n"
PY_APP2 = "def helper(x):\n    return x + 1\n"

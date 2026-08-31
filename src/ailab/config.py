"""設定と .env の読み込み。"""

from __future__ import annotations

import os
from pathlib import Path


def project_root() -> Path:
    """リポジトリのルート（src/ の親）を返す。"""
    return Path(__file__).resolve().parents[2]


def load_dotenv(path: Path | None = None, override: bool = False) -> dict[str, str]:
    """.env を読み込んで os.environ に反映する（依存ライブラリなしの簡易版）。

    KEY=VALUE 形式のみを扱い、# 始まりの行と空行は無視する。
    値の前後のクォートは取り除く。
    """
    env_path = path or (project_root() / ".env")
    loaded: dict[str, str] = {}
    if not env_path.is_file():
        return loaded

    for raw in env_path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, value = line.partition("=")
        key = key.strip()
        value = value.strip().strip('"').strip("'")
        if not key:
            continue
        loaded[key] = value
        if override or key not in os.environ:
            os.environ[key] = value
    return loaded


def get_env(name: str, default: str | None = None) -> str | None:
    """環境変数を取得する（未設定・空文字なら default）。"""
    value = os.environ.get(name)
    if value is None or not value.strip():
        return default
    return value.strip()


def output_dir(sub: str = "") -> Path:
    """出力先ディレクトリ（既定は output/、AILAB_OUTPUT_DIR で変更可）。"""
    base = Path(get_env("AILAB_OUTPUT_DIR") or (project_root() / "output"))
    path = base / sub if sub else base
    path.mkdir(parents=True, exist_ok=True)
    return path

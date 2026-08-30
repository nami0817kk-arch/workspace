"""テスト共通設定。"""

import sys
from pathlib import Path

import pytest

SRC = Path(__file__).resolve().parents[1] / "src"
if str(SRC) not in sys.path:
    sys.path.insert(0, str(SRC))


@pytest.fixture(autouse=True)
def block_network(monkeypatch):
    """テストから実際の外部通信が出ないようにする。

    FakeSession は requests.Session ではないので、差し替え済みのテストには影響しない。
    """
    import requests

    def refuse(self, method, url, *args, **kwargs):
        raise AssertionError(f"テストから外部通信しようとしました: {method} {url}")

    monkeypatch.setattr(requests.sessions.Session, "request", refuse)


@pytest.fixture(autouse=True)
def isolated_environment(tmp_path, monkeypatch):
    """テストが実ユーザーのキャッシュや .env を触らないようにする。"""
    monkeypatch.setenv("AILAB_CACHE_DIR", str(tmp_path / "cache"))
    monkeypatch.setenv("AILAB_CACHE_TTL", "0")  # 既定ではキャッシュ無効
    monkeypatch.setenv("AILAB_OUTPUT_DIR", str(tmp_path / "output"))
    for name in (
        "OPENAI_API_KEY",
        "GEMINI_API_KEY",
        "GOOGLE_API_KEY",
        "STABILITY_API_KEY",
        "PIXABAY_API_KEY",
        "GITHUB_TOKEN",
        "GH_TOKEN",
        "AILAB_GITHUB_REPO",
    ):
        monkeypatch.delenv(name, raising=False)

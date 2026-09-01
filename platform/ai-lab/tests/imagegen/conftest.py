"""テスト共通設定。"""

import sys
from pathlib import Path

import pytest

SRC = Path(__file__).resolve().parents[1] / "src"
if str(SRC) not in sys.path:
    sys.path.insert(0, str(SRC))


@pytest.fixture(autouse=True)
def fresh_rate_limiters():
    """レート制限はコネクタ名で共有されるので、テストごとに捨てる。"""
    from imagegen.core.connector import reset_limiters

    reset_limiters()
    yield
    reset_limiters()


@pytest.fixture(autouse=True)
def no_sleeping(monkeypatch):
    """テストで実際に待たない（再試行の待ちやレート制限の回復待ち）。"""
    import time

    monkeypatch.setattr(time, "sleep", lambda _seconds: None)


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
def no_dotenv(monkeypatch):
    """開発機の .env をテストに持ち込まない。

    CLI と MCP は起動時に .env を読む。実際のキーが入っている環境では、
    conftest がキーを消しても読み直されてしまい、doctor が本当に通信してしまう。
    """
    monkeypatch.setattr("imagegen.cli.load_dotenv", lambda *args, **kwargs: {})
    monkeypatch.setattr("imagegen.mcp_server.load_dotenv", lambda *args, **kwargs: {})


@pytest.fixture(autouse=True)
def isolated_environment(tmp_path, monkeypatch):
    """テストが実ユーザーのキャッシュや .env を触らないようにする。"""
    monkeypatch.setenv("IMAGEGEN_CACHE_DIR", str(tmp_path / "cache"))
    monkeypatch.setenv("IMAGEGEN_CACHE_TTL", "0")  # 既定ではキャッシュ無効
    monkeypatch.setenv("IMAGEGEN_OUTPUT_DIR", str(tmp_path / "output"))
    for name in (
        "OPENAI_API_KEY",
        "GEMINI_API_KEY",
        "GOOGLE_API_KEY",
        "STABILITY_API_KEY",
        "PIXABAY_API_KEY",
        "GITHUB_TOKEN",
        "EDINET_API_KEY",
        "ESTAT_APP_ID",
        "ELEVENLABS_API_KEY",
        "ELEVENLABS_VOICE_ID",
        "VOICEVOX_URL",
        "VOICEVOX_SPEAKER",
        "IMAGEGEN_BEEP_CPS",
        "GH_TOKEN",
        "IMAGEGEN_GITHUB_REPO",
    ):
        monkeypatch.delenv(name, raising=False)

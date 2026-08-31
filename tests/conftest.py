import pytest
from fastapi.testclient import TestClient

from app.clients.gemini import GenerationResult
from app.config import Settings
from app.dependencies import get_cache, get_client
from app.main import create_app
from app.services.cache import NullCache


class FakeGeminiClient:
    """上流を叩かないスタブ。呼ばれた引数を記録する。"""

    def __init__(self) -> None:
        self.calls: list[dict] = []
        self.result = GenerationResult(
            text="こんにちは",
            model="gemini-3.5-flash",
            usage={"prompt_tokens": 3, "output_tokens": 2, "total_tokens": 5},
        )
        self.chunks = ["こん", "にち", "は"]
        self.error: Exception | None = None
        self.error_after_chunks: Exception | None = None

    async def generate(self, prompt, **kwargs):
        self.calls.append({"prompt": prompt, **kwargs})
        if self.error:
            raise self.error
        return self.result

    async def generate_stream(self, prompt, **kwargs):
        self.calls.append({"prompt": prompt, "stream": True, **kwargs})
        if self.error:
            raise self.error
        for chunk in self.chunks:
            yield chunk
        if self.error_after_chunks:
            raise self.error_after_chunks

    async def list_models(self):
        if self.error:
            raise self.error
        return [
            {
                "name": "models/gemini-3.5-flash",
                "display_name": "Gemini 3.5 Flash",
                "description": None,
                "input_token_limit": 1_048_576,
                "output_token_limit": 65_536,
            }
        ]


@pytest.fixture
def fake_client() -> FakeGeminiClient:
    return FakeGeminiClient()


@pytest.fixture
def make_client_for(fake_client):
    """設定を差し替えたテスト用アプリを作るファクトリ。"""

    def _make(**settings_kwargs):
        settings = Settings(gemini_api_key="test-key", _env_file=None, **settings_kwargs)
        app = create_app(settings)
        app.dependency_overrides[get_client] = lambda: fake_client
        return app

    return _make


@pytest.fixture
def client(make_client_for):
    app = make_client_for(cache_ttl=0)
    app.dependency_overrides[get_cache] = lambda: NullCache()
    with TestClient(app) as c:
        yield c

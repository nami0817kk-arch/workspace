import pytest
from fastapi.testclient import TestClient

from app.clients.gemini import GenerationResult
from app.config import Settings
from app.dependencies import get_cache, get_client
from app.main import create_app
from app.services.cache import TTLCache


class FakeGeminiClient:
    """上流を叩かないスタブ。呼ばれた引数を記録する。"""

    def __init__(self) -> None:
        self.calls: list[dict] = []
        self.result = GenerationResult(
            text="こんにちは",
            model="gemini-3.7-flash",
            usage={"prompt_tokens": 3, "output_tokens": 2, "total_tokens": 5},
        )
        self.error: Exception | None = None

    async def generate(self, prompt, **kwargs):
        self.calls.append({"prompt": prompt, **kwargs})
        if self.error:
            raise self.error
        return self.result

    async def list_models(self):
        if self.error:
            raise self.error
        return [
            {
                "name": "models/gemini-3.7-flash",
                "display_name": "Gemini 3.7 Flash",
                "description": None,
                "input_token_limit": 1_048_576,
                "output_token_limit": 65_536,
            }
        ]


@pytest.fixture
def fake_client() -> FakeGeminiClient:
    return FakeGeminiClient()


@pytest.fixture
def cache() -> TTLCache:
    return TTLCache(ttl_seconds=0)


@pytest.fixture
def client(fake_client, cache):
    settings = Settings(gemini_api_key="test-key", cache_ttl=0, _env_file=None)
    app = create_app(settings)
    app.dependency_overrides[get_client] = lambda: fake_client
    app.dependency_overrides[get_cache] = lambda: cache
    with TestClient(app) as c:
        yield c

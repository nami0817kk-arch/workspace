import pytest
from fastapi.testclient import TestClient

from app.config import Settings
from app.dependencies import get_cache, get_client
from app.main import create_app
from app.services.cache import TTLCache


@pytest.fixture
def secured_client(fake_client):
    settings = Settings(
        gemini_api_key="test-key",
        api_keys="secret-one, secret-two",
        cache_ttl=0,
        _env_file=None,
    )
    app = create_app(settings)
    app.dependency_overrides[get_client] = lambda: fake_client
    app.dependency_overrides[get_cache] = lambda: TTLCache(0)
    with TestClient(app) as c:
        yield c


def test_missing_key_is_rejected(secured_client):
    res = secured_client.post("/v1/generate", json={"prompt": "x"})
    assert res.status_code == 401


def test_wrong_key_is_rejected(secured_client):
    res = secured_client.post(
        "/v1/generate", json={"prompt": "x"}, headers={"X-API-Key": "nope"}
    )
    assert res.status_code == 401


def test_valid_key_is_accepted(secured_client):
    res = secured_client.post(
        "/v1/generate", json={"prompt": "x"}, headers={"X-API-Key": "secret-one"}
    )
    assert res.status_code == 200


def test_second_configured_key_also_works(secured_client):
    res = secured_client.get("/v1/models", headers={"X-API-Key": "secret-two"})
    assert res.status_code == 200


def test_health_stays_public(secured_client):
    assert secured_client.get("/health").status_code == 200


def test_auth_disabled_when_no_keys_configured(client):
    # conftest の client は API_KEYS 未設定
    assert client.post("/v1/generate", json={"prompt": "x"}).status_code == 200

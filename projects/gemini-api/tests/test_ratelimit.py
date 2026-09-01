import pytest
from fastapi.testclient import TestClient

from app.services.ratelimit import RateLimiter


@pytest.fixture
def limited_client(make_client_for):
    app = make_client_for(rate_limit_per_minute=2, cache_ttl=0)
    with TestClient(app) as c:
        yield c


def test_requests_under_limit_pass(limited_client):
    for _ in range(2):
        assert limited_client.post("/v1/generate", json={"prompt": "x"}).status_code == 200


def test_request_over_limit_gets_429_with_retry_after(limited_client):
    for _ in range(2):
        limited_client.post("/v1/generate", json={"prompt": "x"})

    res = limited_client.post("/v1/generate", json={"prompt": "x"})
    assert res.status_code == 429
    assert int(res.headers["Retry-After"]) > 0


def test_health_is_not_rate_limited(limited_client):
    for _ in range(5):
        assert limited_client.get("/health").status_code == 200


def test_disabled_by_default(client):
    for _ in range(6):
        assert client.post("/v1/generate", json={"prompt": "x"}).status_code == 200


def test_limiter_counts_per_identity():
    limiter = RateLimiter(limit_per_minute=1)
    assert limiter.check("key:a") is None
    assert limiter.check("key:a") is not None  # a は超過
    assert limiter.check("key:b") is None  # b は別枠


def test_limiter_disabled_when_zero():
    limiter = RateLimiter(limit_per_minute=0)
    assert limiter.enabled is False
    for _ in range(100):
        assert limiter.check("key:a") is None


def test_window_resets():
    limiter = RateLimiter(limit_per_minute=1, window_seconds=1)
    assert limiter.check("key:a") is None
    assert limiter.check("key:a") is not None

    import time

    time.sleep(1.05)
    assert limiter.check("key:a") is None

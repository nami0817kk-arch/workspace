import pytest
import requests
from fakes import FakeResponse, FakeSession

from ailab.core import cache, http
from ailab.core.errors import AuthError, ConnectorError, NetworkError, NotFoundError, RateLimitError


def test_request_returns_successful_response():
    sess = FakeSession([FakeResponse(json_data={"ok": True})])
    assert http.request("GET", "https://example.com", sess=sess).json() == {"ok": True}


def test_request_retries_server_error_then_succeeds(monkeypatch):
    monkeypatch.setattr(http.time, "sleep", lambda _seconds: None)
    sess = FakeSession([FakeResponse(status_code=500), FakeResponse(json_data={"ok": True})])
    assert http.request("GET", "https://example.com", sess=sess).ok
    assert len(sess.calls) == 2


def test_request_does_not_retry_client_error():
    sess = FakeSession([FakeResponse(status_code=400, json_data={"message": "bad"})])
    with pytest.raises(ConnectorError, match="bad"):
        http.request("GET", "https://example.com", sess=sess)
    assert len(sess.calls) == 1


@pytest.mark.parametrize(
    ("status", "expected"),
    [(401, AuthError), (403, AuthError), (404, NotFoundError), (429, RateLimitError)],
)
def test_status_codes_map_to_specific_errors(status, expected, monkeypatch):
    monkeypatch.setattr(http.time, "sleep", lambda _seconds: None)
    sess = FakeSession([FakeResponse(status_code=status) for _ in range(3)])
    with pytest.raises(expected):
        http.request("GET", "https://example.com", sess=sess, label="テストAPI")


def test_retry_after_header_is_used(monkeypatch):
    slept = []
    monkeypatch.setattr(http.time, "sleep", slept.append)
    sess = FakeSession(
        [FakeResponse(status_code=429, headers={"Retry-After": "2"}), FakeResponse(json_data={})]
    )
    http.request("GET", "https://example.com", sess=sess)
    assert slept == [2.0]


def test_connection_failure_becomes_network_error(monkeypatch):
    monkeypatch.setattr(http.time, "sleep", lambda _seconds: None)

    class Broken(FakeSession):
        def request(self, method, url, **kwargs):
            raise requests.ConnectionError("切断")

    with pytest.raises(NetworkError, match="接続できませんでした"):
        http.request("GET", "https://example.com", sess=Broken(), label="テストAPI")


def test_rate_limiter_allows_burst_then_raises():
    limiter = http.RateLimiter(2, 3600, label="テストAPI")
    assert limiter.wait() == 0.0
    assert limiter.wait() == 0.0
    with pytest.raises(RateLimitError, match="使い切りました"):
        limiter.wait()


def test_rate_limiter_waits_when_recovery_is_short():
    limiter = http.RateLimiter(1, 0.01, label="テストAPI")
    limiter.wait()
    assert limiter.wait() > 0


def test_get_json_uses_cache_on_second_call(monkeypatch):
    monkeypatch.setenv("AILAB_CACHE_TTL", "600")
    sess = FakeSession([FakeResponse(json_data={"hit": 1})])
    params = {"q": "cat"}

    first = http.get_json("https://example.com/api", params=params, cache_ttl=600, sess=sess)
    second = http.get_json("https://example.com/api", params=params, cache_ttl=600, sess=sess)

    assert first == second == {"hit": 1}
    assert len(sess.calls) == 1  # 2回目は通信しない


def test_get_json_skips_cache_when_ttl_is_zero():
    sess = FakeSession([FakeResponse(json_data={"n": 1}), FakeResponse(json_data={"n": 2})])
    http.get_json("https://example.com/api", cache_ttl=0, sess=sess)
    http.get_json("https://example.com/api", cache_ttl=0, sess=sess)
    assert len(sess.calls) == 2


def test_expired_cache_is_ignored(monkeypatch):
    key = cache.make_key("https://example.com", {"q": 1})
    cache.store(key, {"old": True}, ttl=600)
    monkeypatch.setattr(cache.time, "time", lambda: 2 * 10**9)  # 遠い未来へ進める
    assert cache.load(key, ttl=600) is None


def test_broken_cache_file_is_ignored():
    key = cache.make_key("https://example.com", None)
    (cache.cache_dir() / f"{key}.json").write_text("{壊れている", encoding="utf-8")
    assert cache.load(key, ttl=600) is None


def test_clear_removes_cache_files():
    cache.store(cache.make_key("a", None), {"a": 1}, ttl=600)
    cache.store(cache.make_key("b", None), {"b": 1}, ttl=600)
    assert cache.clear() == 2

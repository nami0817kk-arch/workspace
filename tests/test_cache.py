import time

from app.services.cache import TTLCache


def test_disabled_cache_never_stores():
    cache = TTLCache(ttl_seconds=0)
    key = TTLCache.make_key(prompt="a")
    cache.set(key, "value")
    assert cache.get(key) is None


def test_value_expires():
    cache = TTLCache(ttl_seconds=1)
    key = TTLCache.make_key(prompt="a")
    cache.set(key, "value")
    assert cache.get(key) == "value"
    time.sleep(1.1)
    assert cache.get(key) is None


def test_key_depends_on_all_parts():
    a = TTLCache.make_key(prompt="a", model="x")
    b = TTLCache.make_key(prompt="a", model="y")
    assert a != b

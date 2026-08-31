import asyncio

from app.services.cache import MemoryCache, NullCache, build_cache, make_key


def run(coro):
    return asyncio.run(coro)


def test_null_cache_never_stores():
    cache = NullCache()
    key = make_key(prompt="a")
    run(cache.set(key, {"text": "value"}))
    assert run(cache.get(key)) is None
    assert cache.enabled is False


def test_memory_cache_roundtrip():
    cache = MemoryCache(ttl_seconds=60)
    key = make_key(prompt="a")
    run(cache.set(key, {"text": "value"}))
    assert run(cache.get(key)) == {"text": "value"}


def test_memory_cache_expires():
    cache = MemoryCache(ttl_seconds=1)
    key = make_key(prompt="a")
    run(cache.set(key, {"text": "value"}))
    assert run(cache.get(key)) is not None
    import time

    time.sleep(1.1)
    assert run(cache.get(key)) is None


def test_memory_cache_evicts_when_full():
    cache = MemoryCache(ttl_seconds=60, max_entries=4)
    for i in range(10):
        run(cache.set(make_key(prompt=str(i)), {"text": str(i)}))
    assert len(cache._store) <= 4


def test_key_depends_on_all_parts():
    assert make_key(prompt="a", model="x") != make_key(prompt="a", model="y")


def test_build_cache_selects_backend():
    assert isinstance(build_cache(0), NullCache)
    assert isinstance(build_cache(60), MemoryCache)

"""生成結果のキャッシュ。

インターフェースは非同期に統一してあり、バックエンドは2種類:

- `MemoryCache` … プロセス内。既定。再起動で消え、ワーカー間で共有されない
- `RedisCache`  … `REDIS_URL` を設定したとき。複数ワーカー / 複数プロセスで共有できる

保存するのは JSON 化できる dict のみ（バックエンド間で表現を揃えるため）。
"""

from __future__ import annotations

import hashlib
import json
import logging
import time
from typing import Any, Protocol

logger = logging.getLogger(__name__)


def make_key(**parts: Any) -> str:
    payload = json.dumps(parts, sort_keys=True, ensure_ascii=False, default=str)
    return "gemini-api:" + hashlib.sha256(payload.encode("utf-8")).hexdigest()


class CacheBackend(Protocol):
    enabled: bool

    async def get(self, key: str) -> dict | None: ...

    async def set(self, key: str, value: dict) -> None: ...

    async def close(self) -> None: ...


class NullCache:
    """キャッシュ無効時。常にミスする。"""

    enabled = False

    async def get(self, key: str) -> dict | None:
        return None

    async def set(self, key: str, value: dict) -> None:
        return None

    async def close(self) -> None:
        return None


class MemoryCache:
    enabled = True

    def __init__(self, ttl_seconds: int, max_entries: int = 512) -> None:
        self._ttl = ttl_seconds
        self._max_entries = max_entries
        self._store: dict[str, tuple[float, dict]] = {}

    async def get(self, key: str) -> dict | None:
        entry = self._store.get(key)
        if entry is None:
            return None
        expires_at, value = entry
        if expires_at < time.monotonic():
            self._store.pop(key, None)
            return None
        return value

    async def set(self, key: str, value: dict) -> None:
        if len(self._store) >= self._max_entries:
            self._purge()
        self._store[key] = (time.monotonic() + self._ttl, value)

    async def close(self) -> None:
        self._store.clear()

    def _purge(self) -> None:
        now = time.monotonic()
        for k in [k for k, (exp, _) in self._store.items() if exp < now]:
            self._store.pop(k, None)
        if len(self._store) >= self._max_entries:
            # まだ溢れるなら期限が近いものから捨てる
            oldest = sorted(self._store.items(), key=lambda kv: kv[1][0])
            for k, _ in oldest[: max(1, self._max_entries // 4)]:
                self._store.pop(k, None)


class RedisCache:
    """Redis バックエンド。`pip install redis` が必要。"""

    enabled = True

    def __init__(self, url: str, ttl_seconds: int) -> None:
        try:
            from redis.asyncio import from_url
        except ImportError as exc:  # pragma: no cover - 依存が無い環境向け
            raise RuntimeError(
                "REDIS_URL が設定されていますが redis パッケージがありません。"
                "`pip install redis` を実行してください。"
            ) from exc

        self._ttl = ttl_seconds
        self._redis = from_url(url, encoding="utf-8", decode_responses=True)

    async def get(self, key: str) -> dict | None:
        try:
            raw = await self._redis.get(key)
        except Exception as exc:
            # キャッシュはあくまで最適化なので、落ちてもリクエストは通す
            logger.warning("redis get failed (%s); ミス扱いで続行します", exc)
            return None
        if raw is None:
            return None
        try:
            return json.loads(raw)
        except json.JSONDecodeError:
            logger.warning("redis に壊れた値がありました: %s", key)
            return None

    async def set(self, key: str, value: dict) -> None:
        try:
            await self._redis.set(key, json.dumps(value, ensure_ascii=False), ex=self._ttl)
        except Exception as exc:
            logger.warning("redis set failed (%s); キャッシュせず続行します", exc)

    async def close(self) -> None:
        try:
            await self._redis.aclose()
        except Exception:  # pragma: no cover
            pass


def build_cache(ttl_seconds: int, redis_url: str = "") -> CacheBackend:
    if ttl_seconds <= 0:
        return NullCache()
    if redis_url:
        logger.info("cache backend: redis (ttl=%ss)", ttl_seconds)
        return RedisCache(redis_url, ttl_seconds)
    logger.info("cache backend: memory (ttl=%ss)", ttl_seconds)
    return MemoryCache(ttl_seconds)

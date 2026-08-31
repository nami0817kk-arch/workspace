"""プロセス内 TTL キャッシュ。

同じプロンプトを短時間に繰り返し叩いたときの上流コールと課金を減らすためだけのもの。
プロセスを跨いで共有はしない（必要になったら Redis に差し替える）。
"""

from __future__ import annotations

import hashlib
import json
import time
from typing import Any


class TTLCache:
    def __init__(self, ttl_seconds: int, max_entries: int = 512) -> None:
        self._ttl = ttl_seconds
        self._max_entries = max_entries
        self._store: dict[str, tuple[float, Any]] = {}

    @property
    def enabled(self) -> bool:
        return self._ttl > 0

    @staticmethod
    def make_key(**parts: Any) -> str:
        payload = json.dumps(parts, sort_keys=True, ensure_ascii=False, default=str)
        return hashlib.sha256(payload.encode("utf-8")).hexdigest()

    def get(self, key: str) -> Any | None:
        if not self.enabled:
            return None
        entry = self._store.get(key)
        if entry is None:
            return None
        expires_at, value = entry
        if expires_at < time.monotonic():
            self._store.pop(key, None)
            return None
        return value

    def set(self, key: str, value: Any) -> None:
        if not self.enabled:
            return
        if len(self._store) >= self._max_entries:
            self._purge()
        self._store[key] = (time.monotonic() + self._ttl, value)

    def _purge(self) -> None:
        now = time.monotonic()
        expired = [k for k, (exp, _) in self._store.items() if exp < now]
        for k in expired:
            self._store.pop(k, None)
        if len(self._store) >= self._max_entries:
            # まだ溢れるなら期限が近いものから捨てる
            for k, _ in sorted(self._store.items(), key=lambda kv: kv[1][0])[: self._max_entries // 4]:
                self._store.pop(k, None)

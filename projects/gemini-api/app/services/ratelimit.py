"""固定ウィンドウのレート制限。

プロセス内カウンタなので、ワーカーを増やすとワーカー数だけ緩くなる。
上流の課金を守るための保険であって、厳密な制御が要るなら Redis 側に持たせる。
"""

from __future__ import annotations

import time


class RateLimiter:
    def __init__(self, limit_per_minute: int, window_seconds: int = 60) -> None:
        self._limit = limit_per_minute
        self._window = window_seconds
        self._hits: dict[str, tuple[float, int]] = {}

    @property
    def enabled(self) -> bool:
        return self._limit > 0

    def check(self, identity: str) -> int | None:
        """許可なら None、超過なら Retry-After に入れる残り秒数を返す。"""
        if not self.enabled:
            return None

        now = time.monotonic()
        window_start, count = self._hits.get(identity, (now, 0))

        if now - window_start >= self._window:
            self._hits[identity] = (now, 1)
            self._sweep(now)
            return None

        if count >= self._limit:
            return max(1, int(self._window - (now - window_start)))

        self._hits[identity] = (window_start, count + 1)
        return None

    def _sweep(self, now: float) -> None:
        if len(self._hits) < 1024:
            return
        for key in [k for k, (start, _) in self._hits.items() if now - start >= self._window]:
            self._hits.pop(key, None)

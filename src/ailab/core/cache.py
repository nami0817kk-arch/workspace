"""検索結果の簡易ディスクキャッシュ。

無料枠のAPIを同じ検索で何度も叩かないためのもの。JSONレスポンスだけを対象にする。
"""

from __future__ import annotations

import hashlib
import json
import os
import time
from pathlib import Path
from typing import Any

#: 既定のキャッシュ保持時間（秒）
DEFAULT_TTL = 900


def cache_dir() -> Path:
    """キャッシュ置き場（AILAB_CACHE_DIR で変更可）。"""
    base = os.environ.get("AILAB_CACHE_DIR") or (Path.home() / ".cache" / "ailab")
    path = Path(base)
    path.mkdir(parents=True, exist_ok=True)
    return path


def default_ttl() -> int:
    """既定のTTL（AILAB_CACHE_TTL で変更可。0 でキャッシュ無効）。"""
    raw = os.environ.get("AILAB_CACHE_TTL")
    if raw is None or not raw.strip():
        return DEFAULT_TTL
    try:
        return max(0, int(raw))
    except ValueError:
        return DEFAULT_TTL


def make_key(url: str, params: dict | None = None) -> str:
    """URL とクエリからキャッシュキーを作る。"""
    payload = json.dumps([url, sorted((params or {}).items(), key=lambda kv: str(kv[0]))], default=str)
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()[:32]


def load(key: str, ttl: int) -> Any | None:
    """有効なキャッシュがあれば返す。無ければ None。"""
    if ttl <= 0:
        return None
    path = cache_dir() / f"{key}.json"
    if not path.is_file():
        return None
    try:
        record = json.loads(path.read_text(encoding="utf-8"))
        if time.time() - float(record["ts"]) > ttl:
            return None
        return record["body"]
    except (ValueError, KeyError, OSError):
        return None


def store(key: str, body: Any, ttl: int) -> None:
    """キャッシュへ保存する（失敗しても無視する）。"""
    if ttl <= 0:
        return
    try:
        (cache_dir() / f"{key}.json").write_text(
            json.dumps({"ts": time.time(), "body": body}, ensure_ascii=False), encoding="utf-8"
        )
    except OSError:  # pragma: no cover - ディスク不調時は諦める
        pass


def clear() -> int:
    """キャッシュを全消しして削除件数を返す。"""
    removed = 0
    for path in cache_dir().glob("*.json"):
        try:
            path.unlink()
            removed += 1
        except OSError:  # pragma: no cover
            pass
    return removed

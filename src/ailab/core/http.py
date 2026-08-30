"""HTTP 共通処理：User-Agent、再試行、レート制限、エラーの言い換え。"""

from __future__ import annotations

import threading
import time
from typing import Any
from urllib.parse import urlsplit

import requests

from .. import USER_AGENT
from . import cache as cache_module
from .errors import AuthError, ConnectorError, NetworkError, NotFoundError, RateLimitError
from .redact import redact

#: 再試行する状態コード
RETRY_STATUS = (429, 500, 502, 503, 504)
DEFAULT_RETRIES = 3


def session(extra_headers: dict[str, str] | None = None) -> requests.Session:
    """User-Agent 付きの requests.Session を返す。"""
    sess = requests.Session()
    sess.headers.update({"User-Agent": USER_AGENT})
    if extra_headers:
        sess.headers.update(extra_headers)
    return sess


def error_detail(response) -> str:
    """API のエラーレスポンスから読みやすいメッセージを組み立てる。"""
    text = ""
    try:
        payload: Any = response.json()
    except ValueError:
        text = (getattr(response, "text", "") or "").strip()
    else:
        if isinstance(payload, dict):
            for key in ("error", "message", "detail", "errors"):
                if key in payload:
                    value = payload[key]
                    text = value.get("message", str(value)) if isinstance(value, dict) else str(value)
                    break
        if not text:
            text = str(payload)
    text = redact(text)[:500]  # クエリ文字列に載ったAPIキーを表示しない
    return f"HTTP {response.status_code}: {text}" if text else f"HTTP {response.status_code}"


def retry_after_seconds(response) -> float | None:
    """Retry-After ヘッダを秒数として読む。"""
    raw = (response.headers or {}).get("Retry-After")
    if not raw:
        return None
    try:
        return float(raw)
    except (TypeError, ValueError):
        return None


def raise_for_response(response, *, label: str) -> None:
    """エラーレスポンスを ailab の例外へ言い換える。"""
    status = response.status_code
    detail = error_detail(response)
    if status in (401, 403):
        raise AuthError(f"{label}: 認証・権限のエラーです（キーや権限を確認）。{detail}")
    if status == 404:
        raise NotFoundError(f"{label}: 見つかりませんでした。{detail}")
    if status == 429:
        raise RateLimitError(
            f"{label}: レート制限にかかりました。時間をおいて再実行してください。{detail}",
            retry_after=retry_after_seconds(response),
        )
    raise ConnectorError(f"{label}: {detail}")


class RateLimiter:
    """トークンバケットで無料枠を守る（プロセス内のみ）。

    枠の分だけは待たずに連続で叩ける。使い切ったときだけ回復を待つ。
    """

    #: これ以上待つなら、黙って止まるより例外で知らせる（秒）
    MAX_WAIT = 10.0

    def __init__(
        self,
        requests_per_period: int,
        period_seconds: float,
        label: str = "外部API",
        max_wait: float | None = None,
    ):
        self.rate = max(1, requests_per_period) / max(1e-6, period_seconds)
        self.capacity = float(max(1, requests_per_period))
        self.label = label
        self.max_wait = self.MAX_WAIT if max_wait is None else max_wait
        self._tokens = self.capacity
        self._last = time.monotonic()
        self._lock = threading.Lock()

    def wait(self) -> float:
        """必要なら待機し、待った秒数を返す。

        並列実行から同時に呼ばれるので、枠の計算はロックの中で行う。
        待つ側がロックを持ったままだと他が進めないため、待機はロックの外で行う。
        """
        with self._lock:
            now = time.monotonic()
            self._tokens = min(self.capacity, self._tokens + (now - self._last) * self.rate)
            self._last = now

            if self._tokens >= 1.0:
                self._tokens -= 1.0
                return 0.0

            need = (1.0 - self._tokens) / self.rate
            if need > self.max_wait:
                raise RateLimitError(
                    f"{self.label}: 無料枠を使い切りました。約{int(need)}秒あけて再実行してください。",
                    retry_after=need,
                )
            # 待つ分をここで確保しておく（他のスレッドが同じ枠を二重取りしないように）
            self._tokens -= 1.0

        time.sleep(need)
        return need


def request(
    method: str,
    url: str,
    *,
    sess: requests.Session | None = None,
    label: str = "外部API",
    retries: int = DEFAULT_RETRIES,
    limiter: RateLimiter | None = None,
    backoff: float = 1.0,
    **kwargs,
):
    """再試行つきでリクエストする。成功レスポンスだけを返す。

    429/5xx は指数バックオフで最大 retries 回まで再試行し、
    それでも駄目なら ailab の例外へ言い換える。
    """
    last_response = None
    for attempt in range(max(1, retries)):
        if limiter:
            limiter.wait()
        try:
            response = (sess or session()).request(method, url, **kwargs)
        except requests.RequestException as exc:
            if attempt == retries - 1:
                host = urlsplit(url).netloc or url
                raise NetworkError(
                    redact(f"{label}: {host} へ接続できませんでした（{type(exc).__name__}）")
                ) from exc
            time.sleep(backoff * (2**attempt))
            continue

        if response.ok:
            return response

        last_response = response
        if response.status_code not in RETRY_STATUS or attempt == retries - 1:
            break
        wait = retry_after_seconds(response) or backoff * (2**attempt)
        time.sleep(min(wait, 30.0))

    raise_for_response(last_response, label=label)


def get_json(
    url: str,
    *,
    params: dict | None = None,
    cache_ttl: int = 0,
    **kwargs,
) -> Any:
    """GET して JSON を返す。cache_ttl が正なら結果をディスクにキャッシュする。"""
    key = cache_module.make_key(url, params)
    cached = cache_module.load(key, cache_ttl)
    if cached is not None:
        return cached

    response = request("GET", url, params=params, **kwargs)
    body = response.json()
    cache_module.store(key, body, cache_ttl)
    return body

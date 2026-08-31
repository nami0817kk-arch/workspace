"""ゲートウェイ自身の認証とレート制限。

`API_KEYS` が空のときは認証なし（ローカル用）。値が入っていれば
`X-API-Key` ヘッダが一致しないと 401 にする。
上流に出す GEMINI_API_KEY とは別のキーであることに注意。
"""

from __future__ import annotations

import hashlib
import secrets

from fastapi import HTTPException, Request, Security, status
from fastapi.security import APIKeyHeader

api_key_header = APIKeyHeader(name="X-API-Key", auto_error=False)


async def require_api_key(
    request: Request,
    provided: str | None = Security(api_key_header),
) -> None:
    allowed = request.app.state.settings.api_key_list
    if not allowed:
        return  # 認証無効

    if provided is None or not any(
        secrets.compare_digest(provided, candidate) for candidate in allowed
    ):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="X-API-Key ヘッダが未指定または不正です",
        )


def _identity(request: Request, api_key: str | None) -> str:
    """レート制限の単位。キーがあればキーごと、無ければ接続元 IP ごと。"""
    if api_key:
        return "key:" + hashlib.blake2s(api_key.encode("utf-8"), digest_size=8).hexdigest()
    client = request.client
    return "ip:" + (client.host if client else "unknown")


async def enforce_rate_limit(
    request: Request,
    provided: str | None = Security(api_key_header),
) -> None:
    limiter = request.app.state.rate_limiter
    if not limiter.enabled:
        return

    retry_after = limiter.check(_identity(request, provided))
    if retry_after is not None:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="リクエストが多すぎます。しばらく待って再試行してください",
            headers={"Retry-After": str(retry_after)},
        )

"""ゲートウェイ自身の認証。

`API_KEYS` が空のときは認証なし（ローカル用）。値が入っていれば
`X-API-Key` ヘッダが一致しないと 401 にする。
上流に出す GEMINI_API_KEY とは別のキーであることに注意。
"""

from __future__ import annotations

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

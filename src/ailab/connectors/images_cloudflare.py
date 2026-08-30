"""Cloudflare Workers AI（無料枠が大きい画像生成）。

無料枠は1日あたりの上限が大きく、常用に耐える。アカウントIDとAPIトークンの
2つが必要。モデルによって応答形式が違う（base64 / OpenAI互換 / 生バイト列）ので
いずれも受け付ける。
"""

from __future__ import annotations

import base64

from ..core.connector import AuthSpec, CheckResult, Connector, RateLimit
from ..core.errors import AuthError, ConnectorError
from ..core.registry import register
from ..core.types import GeneratedImage
from ..utils import parse_size

API_BASE = "https://api.cloudflare.com/client/v4/accounts"


@register
class CloudflareImages(Connector):
    name = "cloudflare"
    category = "images"
    summary = "Cloudflare Workers AI の画像生成（無料枠が大きい）"
    #: 有料APIの後、キー不要の pollinations より前
    priority = 35
    auth = AuthSpec(
        env=("CLOUDFLARE_ACCOUNT_ID", "CLOUDFLARE_API_TOKEN"),
        signup_url="https://dash.cloudflare.com/profile/api-tokens",
        note="アカウントIDとAPIトークンの両方が必要（Workers AI の権限を付ける）",
    )
    terms_url = "https://www.cloudflare.com/website-terms/"
    rate_limit = RateLimit(requests=300, per_seconds=60)
    default_model = "@cf/black-forest-labs/flux-1-schnell"

    def account_id(self) -> str | None:
        from ..config import get_env

        return get_env("CLOUDFLARE_ACCOUNT_ID")

    def token(self) -> str | None:
        from ..config import get_env

        return get_env("CLOUDFLARE_API_TOKEN")

    def default_headers(self) -> dict[str, str]:
        token = self.token()
        return {"Authorization": f"Bearer {token}"} if token else {}

    def check(self) -> CheckResult:
        if not self.is_available():
            return CheckResult(self.name, ok=False, detail=self.unavailable_reason(), skipped=True)
        body = self.get_json(
            f"{API_BASE}/{self.account_id()}/ai/models/search",
            params={"search": "flux", "per_page": 1},
            use_cache=False,
            timeout=30,
        )
        found = len(body.get("result") or [])
        return CheckResult(self.name, ok=True, detail=f"トークン有効（モデル検索 {found} 件）")

    def generate(
        self,
        prompt: str,
        *,
        size: str = "1024x1024",
        n: int = 1,
        model: str | None = None,
        timeout: int = 180,
        steps: int | None = None,
    ) -> list[GeneratedImage]:
        if not self.is_available():
            raise AuthError(self.unavailable_reason())

        model = self.resolve_model(model)
        payload: dict = {"prompt": prompt}
        if steps is not None:
            payload["steps"] = steps
        if "flux" not in model:  # flux 系はサイズ指定を受け取らない
            try:
                width, height = parse_size(size)
            except ValueError:
                width = height = 0
            if width and height:
                payload.update({"width": width, "height": height})

        url = f"{API_BASE}/{self.account_id()}/ai/run/{model}"
        images: list[GeneratedImage] = []
        for _ in range(max(1, n)):  # 1リクエスト1枚
            response = self.request("POST", url, json=payload, timeout=timeout)
            data, mime = _extract_image(response)
            images.append(
                GeneratedImage(
                    data=data, mime=mime, provider=self.name, model=model, prompt=prompt
                )
            )
        return images


def _extract_image(response) -> tuple[bytes, str]:
    """モデルごとに違う応答形式から画像バイト列を取り出す。"""
    content_type = response.headers.get("Content-Type", "").split(";")[0].strip()
    if content_type.startswith("image/"):
        return response.content, content_type

    try:
        body = response.json()
    except ValueError as exc:
        raise ConnectorError("cloudflare: 応答を解釈できませんでした") from exc

    result = body.get("result") or {}
    encoded = result.get("image") if isinstance(result, dict) else None
    if not encoded:
        items = (result.get("data") if isinstance(result, dict) else None) or body.get("data") or []
        if items and isinstance(items[0], dict):
            encoded = items[0].get("b64_json")
    if not encoded:
        errors = body.get("errors") or body.get("messages") or body
        raise ConnectorError(f"cloudflare: 画像が返りませんでした（{str(errors)[:200]}）")

    return base64.b64decode(encoded), "image/jpeg"

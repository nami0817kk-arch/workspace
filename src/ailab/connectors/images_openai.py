"""OpenAI Images API (gpt-image-1 / dall-e-3)。"""

from __future__ import annotations

import base64

from ..core.connector import AuthSpec, CheckResult, Connector, RateLimit
from ..core.errors import AuthError, ConnectorError
from ..core.registry import register
from ..core.types import GeneratedImage

API_URL = "https://api.openai.com/v1/images/generations"
MODELS_URL = "https://api.openai.com/v1/models"


@register
class OpenAIImages(Connector):
    name = "openai"
    category = "images"
    summary = "OpenAI の画像生成 (gpt-image-1 / dall-e-3)"
    auth = AuthSpec(env=("OPENAI_API_KEY",), signup_url="https://platform.openai.com/api-keys")
    terms_url = "https://openai.com/policies/usage-policies/"
    rate_limit = RateLimit(requests=20, per_seconds=60)
    default_model = "gpt-image-1"
    priority = 10

    def default_headers(self) -> dict[str, str]:
        key = self.api_key()
        return {"Authorization": f"Bearer {key}"} if key else {}

    def check(self) -> CheckResult:
        if not self.is_available():
            return CheckResult(self.name, ok=False, detail=self.unavailable_reason(), skipped=True)
        self.get_json(MODELS_URL, use_cache=False, timeout=30)
        return CheckResult(self.name, ok=True, detail="APIキー有効")

    def generate(
        self,
        prompt: str,
        *,
        size: str = "1024x1024",
        n: int = 1,
        model: str | None = None,
        timeout: int = 180,
    ) -> list[GeneratedImage]:
        if not self.is_available():
            raise AuthError(self.unavailable_reason())

        model = model or self.default_model
        payload: dict = {"model": model, "prompt": prompt, "n": n, "size": size}
        if model.startswith("dall-e"):
            payload["response_format"] = "b64_json"

        response = self.request("POST", API_URL, json=payload, timeout=timeout)

        images: list[GeneratedImage] = []
        for item in response.json().get("data", []):
            if item.get("b64_json"):
                data = base64.b64decode(item["b64_json"])
            elif item.get("url"):
                data = self.request("GET", item["url"], timeout=timeout).content
            else:
                continue
            images.append(
                GeneratedImage(
                    data=data,
                    mime="image/png",
                    provider=self.name,
                    model=model,
                    prompt=prompt,
                    meta={"revised_prompt": item.get("revised_prompt", "")},
                )
            )

        if not images:
            raise ConnectorError("openai: 画像が返りませんでした")
        return images

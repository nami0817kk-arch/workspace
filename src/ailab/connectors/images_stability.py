"""Stability AI (Stable Image) の画像生成。"""

from __future__ import annotations

from ..core.connector import AuthSpec, CheckResult, Connector, RateLimit
from ..core.errors import AuthError
from ..core.registry import register
from ..core.types import GeneratedImage
from ..utils import ASPECT_RATIOS, closest_aspect_ratio  # noqa: F401  (旧来の import 先を維持)

BASE_URL = "https://api.stability.ai/v2beta/stable-image/generate"
ACCOUNT_URL = "https://api.stability.ai/v1/user/account"


@register
class StabilityImages(Connector):
    name = "stability"
    category = "images"
    summary = "Stability AI の画像生成 (core / ultra / sd3)"
    auth = AuthSpec(
        env=("STABILITY_API_KEY",), signup_url="https://platform.stability.ai/account/keys"
    )
    terms_url = "https://stability.ai/terms-of-service"
    rate_limit = RateLimit(requests=150, per_seconds=10)
    default_model = "core"
    priority = 30

    def default_headers(self) -> dict[str, str]:
        key = self.api_key()
        return {"Authorization": f"Bearer {key}"} if key else {}

    def check(self) -> CheckResult:
        if not self.is_available():
            return CheckResult(self.name, ok=False, detail=self.unavailable_reason(), skipped=True)
        body = self.get_json(ACCOUNT_URL, use_cache=False, timeout=30)
        return CheckResult(self.name, ok=True, detail=f"アカウント {body.get('email', '')}")

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
        images: list[GeneratedImage] = []
        for _ in range(max(1, n)):  # Stability は1リクエスト1枚
            response = self.request(
                "POST",
                f"{BASE_URL}/{model}",
                headers={"Accept": "image/*"},
                files={"none": ""},
                data={
                    "prompt": prompt,
                    "output_format": "png",
                    "aspect_ratio": closest_aspect_ratio(size),
                },
                timeout=timeout,
            )
            images.append(
                GeneratedImage(
                    data=response.content,
                    mime=response.headers.get("Content-Type", "image/png").split(";")[0],
                    provider=self.name,
                    model=model,
                    prompt=prompt,
                )
            )
        return images

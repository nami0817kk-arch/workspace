"""Stability AI (Stable Image) の画像生成。"""

from __future__ import annotations

from ..core.connector import AuthSpec, CheckResult, Connector, RateLimit
from ..core.errors import AuthError
from ..core.registry import register
from ..core.types import GeneratedImage
from ..utils import parse_size

BASE_URL = "https://api.stability.ai/v2beta/stable-image/generate"
ACCOUNT_URL = "https://api.stability.ai/v1/user/account"

#: Stability は自由なピクセル指定ではなくアスペクト比を受け取る
ASPECT_RATIOS = ["1:1", "16:9", "9:16", "3:2", "2:3", "4:5", "5:4", "21:9", "9:21"]


def closest_aspect_ratio(size: str) -> str:
    """'1024x1536' のようなサイズを、もっとも近いアスペクト比表記に変換する。"""
    try:
        width, height = parse_size(size)
    except ValueError:
        return "1:1"
    target = width / height
    return min(
        ASPECT_RATIOS,
        key=lambda ratio: abs(target - (int(ratio.split(":")[0]) / int(ratio.split(":")[1]))),
    )


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

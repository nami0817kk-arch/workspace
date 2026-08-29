"""Stability AI (Stable Image) による画像生成。"""

from __future__ import annotations

from ..http import error_detail, session
from ..utils import parse_size
from .base import GeneratedImage, ImageProvider, ProviderError

BASE_URL = "https://api.stability.ai/v2beta/stable-image/generate"

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


class StabilityProvider(ImageProvider):
    name = "stability"
    default_model = "core"  # core / ultra / sd3
    api_key_env = "STABILITY_API_KEY"

    def generate(
        self,
        prompt: str,
        *,
        size: str = "1024x1024",
        n: int = 1,
        model: str | None = None,
        timeout: int = 180,
    ) -> list[GeneratedImage]:
        key = self.api_key()
        if not key:
            raise ProviderError(self.unavailable_reason())

        model = model or self.default_model
        sess = session({"Authorization": f"Bearer {key}", "Accept": "image/*"})
        url = f"{BASE_URL}/{model}"

        images: list[GeneratedImage] = []
        for _ in range(max(1, n)):  # Stability は1リクエスト1枚
            response = sess.post(
                url,
                files={"none": ""},
                data={
                    "prompt": prompt,
                    "output_format": "png",
                    "aspect_ratio": closest_aspect_ratio(size),
                },
                timeout=timeout,
            )
            if not response.ok:
                raise ProviderError(f"Stability 画像生成に失敗しました ({error_detail(response)})")
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

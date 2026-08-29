"""OpenAI Images API (gpt-image-1 / dall-e-3) による画像生成。"""

from __future__ import annotations

import base64

from ..http import error_detail, session
from .base import GeneratedImage, ImageProvider, ProviderError

API_URL = "https://api.openai.com/v1/images/generations"


class OpenAIProvider(ImageProvider):
    name = "openai"
    default_model = "gpt-image-1"
    api_key_env = "OPENAI_API_KEY"

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
        payload: dict = {"model": model, "prompt": prompt, "n": n, "size": size}
        if model.startswith("dall-e"):
            payload["response_format"] = "b64_json"

        sess = session({"Authorization": f"Bearer {key}"})
        response = sess.post(API_URL, json=payload, timeout=timeout)
        if not response.ok:
            raise ProviderError(f"OpenAI 画像生成に失敗しました ({error_detail(response)})")

        images: list[GeneratedImage] = []
        for item in response.json().get("data", []):
            if item.get("b64_json"):
                data = base64.b64decode(item["b64_json"])
            elif item.get("url"):
                fetched = sess.get(item["url"], timeout=timeout)
                if not fetched.ok:
                    raise ProviderError(f"画像のダウンロードに失敗しました ({error_detail(fetched)})")
                data = fetched.content
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
            raise ProviderError("OpenAI から画像が返りませんでした")
        return images

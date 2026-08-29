"""Google Gemini / Imagen による画像生成。"""

from __future__ import annotations

import base64

from ..http import error_detail, session
from .base import GeneratedImage, ImageProvider, ProviderError

BASE_URL = "https://generativelanguage.googleapis.com/v1beta/models"


class GeminiProvider(ImageProvider):
    name = "gemini"
    default_model = "gemini-2.5-flash-image"
    api_key_env = "GEMINI_API_KEY"

    def api_key(self):  # GOOGLE_API_KEY もフォールバックとして許可する
        from ..config import get_env

        return get_env("GEMINI_API_KEY") or get_env("GOOGLE_API_KEY")

    def unavailable_reason(self) -> str:
        if self.is_available():
            return ""
        return "環境変数 GEMINI_API_KEY (または GOOGLE_API_KEY) が未設定です"

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
        sess = session({"x-goog-api-key": key})

        if model.startswith("imagen"):
            url = f"{BASE_URL}/{model}:predict"
            payload = {
                "instances": [{"prompt": prompt}],
                "parameters": {"sampleCount": n},
            }
        else:
            url = f"{BASE_URL}/{model}:generateContent"
            payload = {
                "contents": [{"parts": [{"text": prompt}]}],
                "generationConfig": {"responseModalities": ["IMAGE"]},
            }

        response = sess.post(url, json=payload, timeout=timeout)
        if not response.ok:
            raise ProviderError(f"Gemini 画像生成に失敗しました ({error_detail(response)})")

        body = response.json()
        images = [
            GeneratedImage(
                data=base64.b64decode(data),
                mime=mime,
                provider=self.name,
                model=model,
                prompt=prompt,
            )
            for mime, data in _iter_inline_images(body)
        ]
        if not images:
            raise ProviderError(
                "Gemini から画像が返りませんでした（モデル名が画像生成対応か確認してください）"
            )
        return images[:n] if model.startswith("imagen") else images


def _iter_inline_images(body: dict):
    """レスポンスから (mimeType, base64データ) を取り出す。"""
    for prediction in body.get("predictions", []) or []:
        data = prediction.get("bytesBase64Encoded")
        if data:
            yield prediction.get("mimeType", "image/png"), data

    for candidate in body.get("candidates", []) or []:
        for part in candidate.get("content", {}).get("parts", []) or []:
            inline = part.get("inlineData") or part.get("inline_data")
            if inline and inline.get("data"):
                yield inline.get("mimeType") or inline.get("mime_type") or "image/png", inline["data"]

"""Google Gemini / Imagen の画像生成。"""

from __future__ import annotations

import base64

from ..core.connector import AuthSpec, CheckResult, Connector, RateLimit
from ..core.errors import AuthError, ConnectorError
from ..core.registry import register
from ..core.types import GeneratedImage

BASE_URL = "https://generativelanguage.googleapis.com/v1beta/models"


@register
class GeminiImages(Connector):
    name = "gemini"
    category = "images"
    summary = "Gemini / Imagen の画像生成"
    auth = AuthSpec(
        env=("GEMINI_API_KEY", "GOOGLE_API_KEY"),
        any_of=True,
        signup_url="https://aistudio.google.com/apikey",
    )
    terms_url = "https://ai.google.dev/gemini-api/terms"
    rate_limit = RateLimit(requests=15, per_seconds=60)
    default_model = "gemini-2.5-flash-image"
    priority = 20

    def default_headers(self) -> dict[str, str]:
        key = self.api_key()
        return {"x-goog-api-key": key} if key else {}

    def check(self) -> CheckResult:
        if not self.is_available():
            return CheckResult(self.name, ok=False, detail=self.unavailable_reason(), skipped=True)
        body = self.get_json(BASE_URL, use_cache=False, timeout=30)
        return CheckResult(
            self.name, ok=True, detail=f"利用可能モデル {len(body.get('models', []))} 件"
        )

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

        model = self.resolve_model(model)
        if model.startswith("imagen"):
            url = f"{BASE_URL}/{model}:predict"
            payload = {"instances": [{"prompt": prompt}], "parameters": {"sampleCount": n}}
        else:
            url = f"{BASE_URL}/{model}:generateContent"
            payload = {
                "contents": [{"parts": [{"text": prompt}]}],
                "generationConfig": {"responseModalities": ["IMAGE"]},
            }

        body = self.request("POST", url, json=payload, timeout=timeout).json()
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
            raise ConnectorError(
                "gemini: 画像が返りませんでした（モデル名が画像生成対応か確認してください）"
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

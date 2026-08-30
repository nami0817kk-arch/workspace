"""Hugging Face Inference API（無料枠のある生成API）。"""

from __future__ import annotations

from ..config import get_env
from ..core.connector import AuthSpec, CheckResult, Connector, RateLimit
from ..core.errors import AuthError, ConnectorError
from ..core.registry import register
from ..core.types import GeneratedImage
from ..utils import parse_size

DEFAULT_BASE_URL = "https://api-inference.huggingface.co"
WHOAMI_URL = "https://huggingface.co/api/whoami-v2"


def base_url() -> str:
    """推論エンドポイント（HF_INFERENCE_URL で差し替え可）。

    Hugging Face は提供形態が変わることがあるため、URL を設定で逃がしている。
    """
    return (get_env("HF_INFERENCE_URL") or DEFAULT_BASE_URL).rstrip("/")


@register
class HuggingFaceImages(Connector):
    name = "huggingface"
    category = "images"
    summary = "Hugging Face の推論APIで生成"
    priority = 27
    auth = AuthSpec(
        env=("HF_TOKEN", "HUGGINGFACE_API_KEY"),
        any_of=True,
        signup_url="https://huggingface.co/settings/tokens",
    )
    terms_url = "https://huggingface.co/terms-of-service"
    rate_limit = RateLimit(requests=60, per_seconds=3600)
    default_model = "black-forest-labs/FLUX.1-schnell"

    def default_headers(self) -> dict[str, str]:
        key = self.api_key()
        return {"Authorization": f"Bearer {key}"} if key else {}

    def check(self) -> CheckResult:
        if not self.is_available():
            return CheckResult(self.name, ok=False, detail=self.unavailable_reason(), skipped=True)
        body = self.get_json(WHOAMI_URL, use_cache=False, timeout=30)
        return CheckResult(self.name, ok=True, detail=f"{body.get('name', '')} として認証")

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
        parameters: dict = {}
        try:
            width, height = parse_size(size)
        except ValueError:
            width = height = 0
        if width and height:
            parameters.update({"width": width, "height": height})

        payload: dict = {"inputs": prompt}
        if parameters:
            payload["parameters"] = parameters

        images: list[GeneratedImage] = []
        for _ in range(max(1, n)):  # 1リクエスト1枚
            response = self.request(
                "POST",
                f"{base_url()}/models/{model}",
                json=payload,
                headers={"Accept": "image/png"},
                timeout=timeout,
            )
            content_type = response.headers.get("Content-Type", "image/png").split(";")[0].strip()
            if content_type.startswith("application/json"):
                # モデル読み込み中などは 200 でも JSON が返ることがある
                raise ConnectorError(f"huggingface: 画像が返りませんでした（{response.text[:200]}）")
            images.append(
                GeneratedImage(
                    data=response.content,
                    mime=content_type,
                    provider=self.name,
                    model=model,
                    prompt=prompt,
                )
            )
        return images

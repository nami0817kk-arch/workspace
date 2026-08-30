"""Replicate（Flux / SDXL など多数のモデルをホストする生成API）。"""

from __future__ import annotations

import time

from ..core.connector import AuthSpec, CheckResult, Connector, RateLimit
from ..core.errors import AuthError, ConnectorError
from ..core.registry import register
from ..core.types import GeneratedImage
from ..utils import closest_aspect_ratio

API_BASE = "https://api.replicate.com/v1"
#: 完了待ちの上限（秒）と間隔
POLL_TIMEOUT = 180
POLL_INTERVAL = 2.0
TERMINAL_STATUSES = {"succeeded", "failed", "canceled"}


@register
class ReplicateImages(Connector):
    name = "replicate"
    category = "images"
    summary = "Replicate 上のモデルで生成 (Flux / SDXL など)"
    priority = 25
    auth = AuthSpec(
        env=("REPLICATE_API_TOKEN",), signup_url="https://replicate.com/account/api-tokens"
    )
    terms_url = "https://replicate.com/terms"
    rate_limit = RateLimit(requests=600, per_seconds=60)
    default_model = "black-forest-labs/flux-schnell"

    def default_headers(self) -> dict[str, str]:
        key = self.api_key()
        return {"Authorization": f"Bearer {key}"} if key else {}

    def check(self) -> CheckResult:
        if not self.is_available():
            return CheckResult(self.name, ok=False, detail=self.unavailable_reason(), skipped=True)
        body = self.get_json(f"{API_BASE}/account", use_cache=False, timeout=30)
        return CheckResult(self.name, ok=True, detail=f"{body.get('username', '')} として認証")

    def generate(
        self,
        prompt: str,
        *,
        size: str = "1024x1024",
        n: int = 1,
        model: str | None = None,
        timeout: int = POLL_TIMEOUT,
    ) -> list[GeneratedImage]:
        if not self.is_available():
            raise AuthError(self.unavailable_reason())

        model = self.resolve_model(model)
        payload = {
            "input": {
                "prompt": prompt,
                "num_outputs": max(1, n),
                "aspect_ratio": closest_aspect_ratio(size),
            }
        }
        # owner/name:version 形式はバージョン指定、owner/name 形式は公式モデル用の口を使う
        if ":" in model:
            name, _, version = model.partition(":")
            payload["version"] = version
            url = f"{API_BASE}/predictions"
        else:
            url = f"{API_BASE}/models/{model}/predictions"

        prediction = self.request(
            "POST", url, json=payload, headers={"Prefer": "wait"}, timeout=60
        ).json()
        prediction = self._wait_for_result(prediction, timeout=timeout)

        outputs = prediction.get("output") or []
        if isinstance(outputs, str):
            outputs = [outputs]
        if not outputs:
            raise ConnectorError(f"replicate: 画像が返りませんでした（status={prediction.get('status')}）")

        return [
            GeneratedImage(
                data=self.request("GET", url_, timeout=60).content,
                mime="image/webp" if url_.endswith(".webp") else "image/png",
                provider=self.name,
                model=model,
                prompt=prompt,
                meta={"prediction_id": prediction.get("id", "")},
            )
            for url_ in outputs[: max(1, n)]
        ]

    def _wait_for_result(self, prediction: dict, *, timeout: int) -> dict:
        """完了するまで状態を問い合わせる（Prefer: wait で既に終わっていれば何もしない）。"""
        deadline = time.monotonic() + timeout
        while prediction.get("status") not in TERMINAL_STATUSES:
            if time.monotonic() > deadline:
                raise ConnectorError(f"replicate: {timeout}秒待っても完了しませんでした")
            time.sleep(POLL_INTERVAL)
            poll_url = (prediction.get("urls") or {}).get("get")
            if not poll_url:
                raise ConnectorError("replicate: 進捗を確認するURLが返りませんでした")
            prediction = self.get_json(poll_url, use_cache=False, timeout=30)

        if prediction.get("status") != "succeeded":
            detail = prediction.get("error") or prediction.get("status")
            raise ConnectorError(f"replicate: 生成に失敗しました（{detail}）")
        return prediction

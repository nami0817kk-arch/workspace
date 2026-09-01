"""Pollinations.AI（APIキー不要で使える画像生成）。

無料・オープンソース(MIT)の公開サービス。キーが1つも無い環境でも
「本物の生成AI画像」が作れる唯一のコネクタなので、auto では local の直前に選ばれる。

制約:
- 匿名利用は概ね15秒に1回。連続生成では自動で待つ。
- 透かしを外す nologo はアカウント登録が必要。
- 既定で private=true を送り、生成物が公開フィードに載らないようにしている。
"""

from __future__ import annotations

from urllib.parse import quote

from ..core.connector import AuthSpec, CheckResult, Connector, RateLimit
from ..core.errors import ConnectorError
from ..core.registry import register
from ..core.types import GeneratedImage
from ..utils import parse_size

BASE_URL = "https://image.pollinations.ai/prompt"


@register
class PollinationsImages(Connector):
    name = "pollinations"
    category = "images"
    summary = "APIキー不要で使える画像生成（無料・15秒に1回程度）"
    #: 有料APIの後、プレースホルダの local より前
    priority = 40
    auth = AuthSpec(
        env=("POLLINATIONS_TOKEN",),
        optional=True,
        signup_url="https://auth.pollinations.ai/",
        note="無くても使える。登録すると待ち時間が短くなり nologo が使える",
    )
    terms_url = "https://github.com/pollinations/pollinations"
    #: 匿名は15秒に1回。連続生成のために少し長めに待つ
    rate_limit = RateLimit(requests=1, per_seconds=15, max_wait_seconds=40)
    default_model = "sana"

    def default_headers(self) -> dict[str, str]:
        key = self.api_key()
        return {"Authorization": f"Bearer {key}"} if key else {}

    def check(self) -> CheckResult:
        response = self.request(
            "GET", f"{BASE_URL}/{quote('ping')}", params={"width": 64, "height": 64}, timeout=60
        )
        keyed = "トークンあり" if self.api_key() else "トークンなし（15秒に1回程度）"
        return CheckResult(self.name, ok=True, detail=f"生成できました・{keyed}（{len(response.content):,}バイト）")

    def generate(
        self,
        prompt: str,
        *,
        size: str = "1024x1024",
        n: int = 1,
        model: str | None = None,
        timeout: int = 180,
        seed: int | None = None,
        enhance: bool = False,
        private: bool = True,
    ) -> list[GeneratedImage]:
        model = self.resolve_model(model)
        width, height = parse_size(size)

        images: list[GeneratedImage] = []
        for index in range(max(1, n)):
            params: dict = {
                "model": model,
                "width": width,
                "height": height,
                # 生成物が公開フィードに流れないようにする
                "private": "true" if private else "false",
            }
            if enhance:
                params["enhance"] = "true"
            if seed is not None:
                params["seed"] = seed + index
            if self.api_key():
                params["nologo"] = "true"  # 透かし除去は登録ユーザーのみ

            response = self.request(
                "GET", f"{BASE_URL}/{quote(prompt, safe='')}", params=params, timeout=timeout
            )
            content_type = response.headers.get("Content-Type", "image/jpeg").split(";")[0].strip()
            if not content_type.startswith("image/"):
                raise ConnectorError(
                    f"pollinations: 画像が返りませんでした（{response.text[:200]}）"
                )
            images.append(
                GeneratedImage(
                    data=response.content,
                    mime=content_type,
                    provider=self.name,
                    model=model,
                    prompt=prompt,
                    meta={"seed": params.get("seed", "")},
                )
            )
        return images

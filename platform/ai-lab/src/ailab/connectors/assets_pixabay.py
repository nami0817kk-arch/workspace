"""Pixabay（イラスト・ベクター素材）。無料の APIキーが必要。"""

from __future__ import annotations

from ..core.connector import AuthSpec, CheckResult, Connector, RateLimit
from ..core.errors import AuthError
from ..core.registry import register
from ..core.types import Asset

API_URL = "https://pixabay.com/api/"


@register
class PixabayAssets(Connector):
    name = "pixabay"
    category = "assets"
    summary = "イラスト・ベクター素材（無料キー）"
    auth = AuthSpec(env=("PIXABAY_API_KEY",), signup_url="https://pixabay.com/api/docs/")
    terms_url = "https://pixabay.com/service/terms/"
    license_note = "Pixabay Content License（商用可・クレジット不要。人物や商標には要注意）"
    rate_limit = RateLimit(requests=100, per_seconds=60)
    priority = 20

    def check(self) -> CheckResult:
        if not self.is_available():
            return CheckResult(self.name, ok=False, detail=self.unavailable_reason(), skipped=True)
        body = self.get_json(
            API_URL,
            params={"key": self.api_key(), "q": "test", "per_page": 3},
            use_cache=False,
            timeout=30,
        )
        return CheckResult(self.name, ok=True, detail=f"検索可能（{body.get('total', 0)}件ヒット）")

    def search_assets(
        self,
        query: str,
        *,
        limit: int = 10,
        image_type: str = "illustration",
        lang: str = "ja",
        timeout: int = 30,
    ) -> list[Asset]:
        if not self.is_available():
            raise AuthError(self.unavailable_reason())

        body = self.get_json(
            API_URL,
            params={
                "key": self.api_key(),
                "q": query,
                "image_type": image_type,  # illustration / vector / photo / all
                "per_page": max(3, min(limit, 200)),
                "safesearch": "true",
                "lang": lang,
            },
            timeout=timeout,
        )
        return [_to_asset(hit) for hit in body.get("hits", [])[:limit]]


def _to_asset(hit: dict) -> Asset:
    return Asset(
        source="pixabay",
        title=(hit.get("tags") or "").split(",")[0].strip() or "pixabay image",
        image_url=hit.get("largeImageURL") or hit.get("webformatURL") or "",
        page_url=hit.get("pageURL") or "",
        thumbnail_url=hit.get("previewURL") or "",
        license="Pixabay Content License",
        license_url="https://pixabay.com/service/license-summary/",
        creator=hit.get("user") or "",
        creator_url=f"https://pixabay.com/users/{hit.get('user', '')}-{hit.get('user_id', '')}/",
        width=int(hit.get("imageWidth") or 0),
        height=int(hit.get("imageHeight") or 0),
        source_id=str(hit.get("id") or ""),
        tags=[tag.strip() for tag in (hit.get("tags") or "").split(",") if tag.strip()],
    )

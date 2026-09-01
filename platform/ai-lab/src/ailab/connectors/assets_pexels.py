"""Pexels（写真素材）。無料の APIキーが必要。"""

from __future__ import annotations

from ..core.connector import AuthSpec, CheckResult, Connector, RateLimit
from ..core.errors import AuthError
from ..core.registry import register
from ..core.types import Asset

SEARCH_URL = "https://api.pexels.com/v1/search"


@register
class PexelsAssets(Connector):
    name = "pexels"
    category = "assets"
    summary = "写真素材（無料キー）"
    priority = 50
    auth = AuthSpec(env=("PEXELS_API_KEY",), signup_url="https://www.pexels.com/api/")
    terms_url = "https://www.pexels.com/terms-of-service/"
    license_note = "Pexels License（商用可・クレジット不要だが表示は歓迎）"
    rate_limit = RateLimit(requests=200, per_seconds=3600)

    def default_headers(self) -> dict[str, str]:
        key = self.api_key()
        return {"Authorization": key} if key else {}

    def check(self) -> CheckResult:
        if not self.is_available():
            return CheckResult(self.name, ok=False, detail=self.unavailable_reason(), skipped=True)
        body = self.get_json(
            SEARCH_URL, params={"query": "test", "per_page": 1}, use_cache=False, timeout=30
        )
        return CheckResult(self.name, ok=True, detail=f"検索可能（{body.get('total_results', 0)}件ヒット）")

    def search_assets(self, query: str, *, limit: int = 10, timeout: int = 30) -> list[Asset]:
        if not self.is_available():
            raise AuthError(self.unavailable_reason())

        body = self.get_json(
            SEARCH_URL,
            params={"query": query, "per_page": max(1, min(limit, 80))},
            timeout=timeout,
        )
        return [_to_asset(photo) for photo in (body.get("photos") or [])][:limit]


def _to_asset(photo: dict) -> Asset:
    src = photo.get("src") or {}
    return Asset(
        source="pexels",
        title=photo.get("alt") or "Pexels photo",
        image_url=src.get("large") or src.get("original") or "",
        page_url=photo.get("url") or "",
        thumbnail_url=src.get("tiny") or src.get("small") or "",
        license="Pexels License",
        license_url="https://www.pexels.com/license/",
        creator=photo.get("photographer") or "",
        creator_url=photo.get("photographer_url") or "",
        width=int(photo.get("width") or 0),
        height=int(photo.get("height") or 0),
        source_id=str(photo.get("id") or ""),
    )

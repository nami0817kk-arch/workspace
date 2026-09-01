"""Unsplash（写真素材）。無料の Access Key が必要。"""

from __future__ import annotations

from ..core.connector import AuthSpec, CheckResult, Connector, RateLimit
from ..core.errors import AuthError, ConnectorError
from ..core.registry import register
from ..core.types import Asset

SEARCH_URL = "https://api.unsplash.com/search/photos"


@register
class UnsplashAssets(Connector):
    name = "unsplash"
    category = "assets"
    summary = "高品質な写真素材（無料キー）"
    priority = 40
    auth = AuthSpec(
        env=("UNSPLASH_ACCESS_KEY",),
        signup_url="https://unsplash.com/oauth/applications",
        note="Access Key（Secret Key ではない）",
    )
    terms_url = "https://unsplash.com/api-terms"
    license_note = "Unsplash License（商用可・クレジット必須ではないが表示が強く推奨）"
    #: Demo アプリの上限は 50 req/h
    rate_limit = RateLimit(requests=50, per_seconds=3600)

    def default_headers(self) -> dict[str, str]:
        key = self.api_key()
        return {"Authorization": f"Client-ID {key}"} if key else {}

    def check(self) -> CheckResult:
        if not self.is_available():
            return CheckResult(self.name, ok=False, detail=self.unavailable_reason(), skipped=True)
        body = self.get_json(
            SEARCH_URL, params={"query": "test", "per_page": 1}, use_cache=False, timeout=30
        )
        return CheckResult(self.name, ok=True, detail=f"検索可能（{body.get('total', 0)}件ヒット）")

    def search_assets(self, query: str, *, limit: int = 10, timeout: int = 30) -> list[Asset]:
        if not self.is_available():
            raise AuthError(self.unavailable_reason())

        body = self.get_json(
            SEARCH_URL,
            params={"query": query, "per_page": max(1, min(limit, 30))},
            timeout=timeout,
        )
        return [_to_asset(result) for result in (body.get("results") or [])][:limit]

    def notify_download(self, asset: Asset) -> None:
        """ダウンロードを Unsplash へ通知する（APIガイドラインで要求されている）。"""
        location = (asset.meta or {}).get("download_location")
        if not location or not self.is_available():
            return
        try:
            self.request("GET", location, timeout=30)
        except ConnectorError:  # 通知の失敗で素材取得自体を壊さない
            pass


def _to_asset(result: dict) -> Asset:
    urls = result.get("urls") or {}
    links = result.get("links") or {}
    user = result.get("user") or {}
    return Asset(
        source="unsplash",
        title=result.get("description") or result.get("alt_description") or "Unsplash photo",
        image_url=urls.get("regular") or urls.get("full") or urls.get("raw") or "",
        page_url=links.get("html") or "",
        thumbnail_url=urls.get("thumb") or urls.get("small") or "",
        license="Unsplash License",
        license_url="https://unsplash.com/license",
        creator=user.get("name") or user.get("username") or "",
        creator_url=(user.get("links") or {}).get("html") or "",
        width=int(result.get("width") or 0),
        height=int(result.get("height") or 0),
        source_id=str(result.get("id") or ""),
        tags=[tag.get("title", "") for tag in (result.get("tags") or []) if isinstance(tag, dict)],
        meta={"download_location": links.get("download_location", "")},
    )

"""Openverse（WordPress 運営の CC 素材横断検索）。APIキー不要。"""

from __future__ import annotations

from ..core.connector import AuthSpec, CheckResult, Connector, RateLimit
from ..core.registry import register
from ..core.types import Asset

API_URL = "https://api.openverse.org/v1/images/"


@register
class OpenverseAssets(Connector):
    name = "openverse"
    category = "assets"
    summary = "CC素材の横断検索（キー不要）"
    auth = AuthSpec()
    terms_url = "https://openverse.org/terms"
    license_note = "CC0 / CC BY など（作品ごとに異なる。license 欄を必ず確認）"
    rate_limit = RateLimit(requests=100, per_seconds=3600)
    priority = 10

    def check(self) -> CheckResult:
        body = self.get_json(API_URL, params={"q": "test", "page_size": 1}, use_cache=False, timeout=30)
        return CheckResult(self.name, ok=True, detail=f"検索可能（{body.get('result_count', 0)}件ヒット）")

    def search_assets(
        self,
        query: str,
        *,
        limit: int = 10,
        commercial_only: bool = True,
        category: str | None = "illustration",
        timeout: int = 30,
    ) -> list[Asset]:
        params: dict = {"q": query, "page_size": max(1, min(limit, 50))}
        if commercial_only:
            # 商用利用可・改変可のライセンスに絞る
            params["license_type"] = "commercial,modification"
        if category:
            params["category"] = category

        body = self.get_json(API_URL, params=params, timeout=timeout)
        return [_to_asset(result) for result in body.get("results", [])][:limit]


def _to_asset(result: dict) -> Asset:
    license_name = result.get("license", "")
    version = result.get("license_version", "")
    return Asset(
        source="openverse",
        title=result.get("title") or "",
        image_url=result.get("url") or "",
        page_url=result.get("foreign_landing_url") or "",
        thumbnail_url=result.get("thumbnail") or "",
        license=" ".join(part for part in (license_name.upper(), version) if part) or "unknown",
        license_url=result.get("license_url") or "",
        creator=result.get("creator") or "",
        creator_url=result.get("creator_url") or "",
        width=int(result.get("width") or 0),
        height=int(result.get("height") or 0),
        source_id=str(result.get("id") or ""),
        tags=[tag.get("name", "") for tag in (result.get("tags") or []) if isinstance(tag, dict)],
    )

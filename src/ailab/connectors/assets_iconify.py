"""Iconify（20万点以上の SVG アイコンを横断検索）。APIキー不要。"""

from __future__ import annotations

from ..core.connector import AuthSpec, CheckResult, Connector, RateLimit
from ..core.registry import register
from ..core.types import Asset

SEARCH_URL = "https://api.iconify.design/search"
SVG_URL = "https://api.iconify.design/{prefix}/{name}.svg"
PAGE_URL = "https://icon-sets.iconify.design/{prefix}/{name}/"
#: API 側の下限。これより小さい limit は受け付けられない
MIN_LIMIT = 32


@register
class IconifyAssets(Connector):
    name = "iconify"
    category = "assets"
    summary = "SVGアイコンの横断検索（キー不要）"
    priority = 5  # キー不要で速いので素材検索の先頭に置く
    auth = AuthSpec()
    terms_url = "https://iconify.design/docs/usage/"
    license_note = "アイコンセットごとに異なる（MIT / Apache / CC BY など。license 欄を確認）"
    rate_limit = RateLimit(requests=200, per_seconds=60)

    def check(self) -> CheckResult:
        body = self.get_json(
            SEARCH_URL, params={"query": "home", "limit": MIN_LIMIT}, use_cache=False, timeout=30
        )
        return CheckResult(self.name, ok=True, detail=f"検索可能（{len(body.get('icons', []))}件）")

    def search_assets(self, query: str, *, limit: int = 10, timeout: int = 30) -> list[Asset]:
        body = self.get_json(
            SEARCH_URL,
            params={"query": query, "limit": max(MIN_LIMIT, min(limit, 999))},
            timeout=timeout,
        )
        collections = body.get("collections") or {}
        return [_to_asset(icon, collections) for icon in (body.get("icons") or [])][:limit]


def _to_asset(icon: str, collections: dict) -> Asset:
    """'mdi:cat' 形式のアイコンIDを Asset へ変換する。"""
    prefix, _, name = icon.partition(":")
    info = collections.get(prefix) or {}
    license_info = info.get("license") or {}
    author = info.get("author") or {}
    return Asset(
        source="iconify",
        title=f"{name.replace('-', ' ')} ({info.get('name', prefix)})",
        image_url=SVG_URL.format(prefix=prefix, name=name),
        page_url=PAGE_URL.format(prefix=prefix, name=name),
        thumbnail_url=SVG_URL.format(prefix=prefix, name=name),
        license=license_info.get("title") or license_info.get("spdx") or "unknown",
        license_url=license_info.get("url") or "",
        creator=author.get("name") or "",
        creator_url=author.get("url") or "",
        source_id=icon,
        tags=[prefix],
    )

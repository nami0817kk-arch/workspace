"""Wikimedia Commons（パブリックドメイン・CC 素材）。APIキー不要。"""

from __future__ import annotations

import re

from ..core.connector import AuthSpec, CheckResult, Connector, RateLimit
from ..core.registry import register
from ..core.types import Asset

API_URL = "https://commons.wikimedia.org/w/api.php"
TAG_RE = re.compile(r"<[^>]+>")


@register
class WikimediaAssets(Connector):
    name = "wikimedia"
    category = "assets"
    summary = "Wikimedia Commons の画像（キー不要）"
    auth = AuthSpec()
    terms_url = "https://commons.wikimedia.org/wiki/Commons:Licensing"
    license_note = "パブリックドメイン / CC BY-SA など（作品ごとに異なる）"
    rate_limit = RateLimit(requests=200, per_seconds=60)
    priority = 30

    def check(self) -> CheckResult:
        self.get_json(
            API_URL, params={"action": "query", "format": "json", "meta": "siteinfo"},
            use_cache=False, timeout=30,
        )
        return CheckResult(self.name, ok=True, detail="検索可能")

    def search_assets(self, query: str, *, limit: int = 10, timeout: int = 30) -> list[Asset]:
        body = self.get_json(
            API_URL,
            params={
                "action": "query",
                "format": "json",
                "generator": "search",
                "gsrsearch": f"{query} filetype:bitmap|drawing",
                "gsrnamespace": "6",  # File:
                "gsrlimit": max(1, min(limit, 50)),
                "prop": "imageinfo",
                "iiprop": "url|size|extmetadata",
                "iiurlwidth": "480",
            },
            timeout=timeout,
        )
        pages = (body.get("query") or {}).get("pages") or {}
        return [_to_asset(page) for page in pages.values() if page.get("imageinfo")][:limit]


def _clean(value: str) -> str:
    return TAG_RE.sub("", value or "").strip()


def _to_asset(page: dict) -> Asset:
    info = page["imageinfo"][0]
    meta = info.get("extmetadata") or {}

    def field(name: str) -> str:
        return _clean((meta.get(name) or {}).get("value", ""))

    return Asset(
        source="wikimedia",
        title=(page.get("title") or "").removeprefix("File:"),
        image_url=info.get("url") or "",
        page_url=info.get("descriptionurl") or "",
        thumbnail_url=info.get("thumburl") or "",
        license=field("LicenseShortName") or "unknown",
        license_url=field("LicenseUrl"),
        creator=field("Artist"),
        width=int(info.get("width") or 0),
        height=int(info.get("height") or 0),
        source_id=str(page.get("pageid") or ""),
    )

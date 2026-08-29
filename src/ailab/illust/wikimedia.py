"""Wikimedia Commons（パブリックドメイン・CC 素材）。APIキー不要。"""

from __future__ import annotations

import re

from ..http import error_detail, session
from .base import IllustItem, IllustSource, SourceError

API_URL = "https://commons.wikimedia.org/w/api.php"
TAG_RE = re.compile(r"<[^>]+>")


class WikimediaSource(IllustSource):
    name = "wikimedia"
    api_key_env = None
    license_note = "パブリックドメイン / CC BY-SA など（作品ごとに異なる）"

    def search(self, query: str, *, limit: int = 10, timeout: int = 30) -> list[IllustItem]:
        params = {
            "action": "query",
            "format": "json",
            "generator": "search",
            "gsrsearch": f"{query} filetype:bitmap|drawing",
            "gsrnamespace": "6",  # File:
            "gsrlimit": max(1, min(limit, 50)),
            "prop": "imageinfo",
            "iiprop": "url|size|extmetadata",
            "iiurlwidth": "480",
        }
        response = session().get(API_URL, params=params, timeout=timeout)
        if not response.ok:
            raise SourceError(f"Wikimedia Commons の検索に失敗しました ({error_detail(response)})")

        pages = (response.json().get("query") or {}).get("pages") or {}
        items = [_to_item(page) for page in pages.values() if page.get("imageinfo")]
        return items[:limit]


def _clean(value: str) -> str:
    return TAG_RE.sub("", value or "").strip()


def _to_item(page: dict) -> IllustItem:
    info = page["imageinfo"][0]
    meta = info.get("extmetadata") or {}

    def field(name: str) -> str:
        return _clean((meta.get(name) or {}).get("value", ""))

    return IllustItem(
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

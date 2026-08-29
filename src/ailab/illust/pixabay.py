"""Pixabay（イラスト・ベクター素材）。無料の APIキーが必要。"""

from __future__ import annotations

from ..http import error_detail, session
from .base import IllustItem, IllustSource, SourceError

API_URL = "https://pixabay.com/api/"


class PixabaySource(IllustSource):
    name = "pixabay"
    api_key_env = "PIXABAY_API_KEY"
    license_note = "Pixabay Content License（商用可・クレジット不要。人物や商標には要注意）"

    def search(
        self,
        query: str,
        *,
        limit: int = 10,
        timeout: int = 30,
        image_type: str = "illustration",
        lang: str = "ja",
    ) -> list[IllustItem]:
        key = self.api_key()
        if not key:
            raise SourceError(self.unavailable_reason())

        params = {
            "key": key,
            "q": query,
            "image_type": image_type,  # illustration / vector / photo / all
            "per_page": max(3, min(limit, 200)),
            "safesearch": "true",
            "lang": lang,
        }
        response = session().get(API_URL, params=params, timeout=timeout)
        if not response.ok:
            raise SourceError(f"Pixabay の検索に失敗しました ({error_detail(response)})")

        hits = response.json().get("hits", [])
        return [_to_item(hit) for hit in hits[:limit]]


def _to_item(hit: dict) -> IllustItem:
    return IllustItem(
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

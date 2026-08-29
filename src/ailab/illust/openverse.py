"""Openverse（WordPress 運営の CC 素材横断検索）。APIキー不要。"""

from __future__ import annotations

from ..http import error_detail, session
from .base import IllustItem, IllustSource, SourceError

API_URL = "https://api.openverse.org/v1/images/"


class OpenverseSource(IllustSource):
    name = "openverse"
    api_key_env = None
    license_note = "CC0 / CC BY など（作品ごとに異なる。license 欄を必ず確認）"

    def search(
        self,
        query: str,
        *,
        limit: int = 10,
        timeout: int = 30,
        commercial_only: bool = True,
        category: str | None = "illustration",
    ) -> list[IllustItem]:
        params: dict = {"q": query, "page_size": max(1, min(limit, 50))}
        if commercial_only:
            # 商用利用可・改変可のライセンスに絞る
            params["license_type"] = "commercial,modification"
        if category:
            params["category"] = category

        response = session().get(API_URL, params=params, timeout=timeout)
        if not response.ok:
            raise SourceError(f"Openverse の検索に失敗しました ({error_detail(response)})")

        items = [_to_item(result) for result in response.json().get("results", [])]
        return items[:limit]


def _to_item(result: dict) -> IllustItem:
    license_name = result.get("license", "")
    version = result.get("license_version", "")
    return IllustItem(
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

"""Qiita の記事検索。トークンは任意（あればレート上限が上がる）。"""

from __future__ import annotations

from ..core.connector import AuthSpec, CheckResult, Connector, RateLimit
from ..core.registry import register
from ..core.types import FeedItem

API_URL = "https://qiita.com/api/v2/items"


@register
class QiitaFeed(Connector):
    name = "qiita"
    category = "feed"
    summary = "Qiita の記事検索（トークンは任意）"
    priority = 20
    auth = AuthSpec(
        env=("QIITA_TOKEN",),
        optional=True,
        signup_url="https://qiita.com/settings/applications",
        note="無くても使える。設定するとレート上限が上がる",
    )
    terms_url = "https://qiita.com/terms"
    rate_limit = RateLimit(requests=60, per_seconds=3600)

    def default_headers(self) -> dict[str, str]:
        key = self.api_key()
        return {"Authorization": f"Bearer {key}"} if key else {}

    def check(self) -> CheckResult:
        body = self.get_json(API_URL, params={"per_page": 1}, use_cache=False, timeout=30)
        keyed = "トークンあり" if self.api_key() else "トークンなし（枠は狭い）"
        return CheckResult(self.name, ok=True, detail=f"検索可能・{keyed}（{len(body)}件取得）")

    def fetch_items(self, query: str, *, limit: int = 10, timeout: int = 30) -> list[FeedItem]:
        body = self.get_json(
            API_URL,
            params={"query": query, "per_page": max(1, min(limit, 100))},
            timeout=timeout,
        )
        return [_to_item(item) for item in body][:limit]


def _to_item(item: dict) -> FeedItem:
    return FeedItem(
        source="qiita",
        title=item.get("title") or "(無題)",
        url=item.get("url") or "",
        published=item.get("created_at") or "",
        summary=(item.get("body") or "").strip()[:300],
        author=(item.get("user") or {}).get("id", ""),
        tags=[tag.get("name", "") for tag in (item.get("tags") or []) if isinstance(tag, dict)],
        meta={"likes": item.get("likes_count", 0), "stocks": item.get("stocks_count", 0)},
    )

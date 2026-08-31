"""Wikipedia の記事検索。APIキー不要。

Wikimedia Commons（画像）とは別のサイトなので、コネクタも分けている。
こちらは記事の見出しと導入文を返す。
"""

from __future__ import annotations

import re

from ..config import get_env
from ..core.connector import AuthSpec, CheckResult, Connector, RateLimit
from ..core.registry import register
from ..core.types import FeedItem

#: 言語コードを頭に付けて `en:Messi` のようにも書ける
LANG_PREFIX = re.compile(r"^([a-z]{2,3})\s*:\s*(.*)$")
DEFAULT_LANG = "ja"
#: 導入文はそのままだと長いので切る
SUMMARY_LIMIT = 400


def api_url(lang: str) -> str:
    return f"https://{lang}.wikipedia.org/w/api.php"


def default_lang() -> str:
    """既定の言語（AILAB_WIKIPEDIA_LANG で変更可）。"""
    return (get_env("AILAB_WIKIPEDIA_LANG") or DEFAULT_LANG).strip().lower()


def split_lang(query: str) -> tuple[str, str]:
    """'en:Messi' を ('en', 'Messi') に分ける。前置きが無ければ既定の言語。"""
    matched = LANG_PREFIX.match(query.strip())
    if matched:
        return matched.group(1), matched.group(2).strip()
    return default_lang(), query.strip()


@register
class WikipediaFeed(Connector):
    name = "wikipedia"
    category = "feed"
    summary = "Wikipedia の記事検索（キー不要。en: で言語指定）"
    priority = 15
    auth = AuthSpec()
    terms_url = "https://foundation.wikimedia.org/wiki/Policy:Terms_of_Use"
    license_note = "本文は CC BY-SA（引用・再利用には出典表示と継承が必要）"
    rate_limit = RateLimit(requests=200, per_seconds=60)

    def check(self) -> CheckResult:
        lang = default_lang()
        self.get_json(
            api_url(lang),
            params={"action": "query", "format": "json", "meta": "siteinfo"},
            use_cache=False,
            timeout=30,
        )
        return CheckResult(self.name, ok=True, detail=f"検索可能（既定の言語: {lang}）")

    def fetch_items(self, query: str, *, limit: int = 5, timeout: int = 30) -> list[FeedItem]:
        lang, terms = split_lang(query)
        if not terms:
            from ..core.errors import ConfigError

            raise ConfigError("検索するキーワードを指定してください")

        body = self.get_json(
            api_url(lang),
            params={
                "action": "query",
                "format": "json",
                "generator": "search",
                "gsrsearch": terms,
                "gsrlimit": max(1, min(limit, 50)),
                "prop": "extracts|info",
                "inprop": "url",
                "exintro": 1,      # 導入部だけ
                "explaintext": 1,  # HTMLではなく本文
                "exlimit": "max",  # 複数ページ分をまとめて取る
            },
            timeout=timeout,
        )
        pages = (body.get("query") or {}).get("pages") or {}
        items = [_to_item(page, lang) for page in pages.values()]
        # 検索順（index）を保つ。API は辞書で返すため順序が失われる
        items.sort(key=lambda item: item.meta.get("order", 0))
        return items[:limit]


def _to_item(page: dict, lang: str) -> FeedItem:
    extract = " ".join((page.get("extract") or "").split())
    return FeedItem(
        source="wikipedia",
        title=page.get("title") or "(無題)",
        url=page.get("fullurl") or "",
        published=page.get("touched") or "",
        summary=extract[:SUMMARY_LIMIT],
        tags=[lang],
        meta={"pageid": page.get("pageid", ""), "lang": lang, "order": page.get("index", 0)},
    )

"""RSS / Atom フィードの取得。APIキー不要。

query にはフィードのURLを渡す（キーワード検索ではない）。
"""

from __future__ import annotations

import re
from xml.etree import ElementTree

from ..core.connector import AuthSpec, CheckResult, Connector, RateLimit
from ..core.errors import ConfigError, ConnectorError
from ..core.registry import register
from ..core.types import FeedItem

ATOM_NS = "{http://www.w3.org/2005/Atom}"
DC_NS = "{http://purl.org/dc/elements/1.1/}"
TAG_RE = re.compile(r"<[^>]+>")


@register
class RssFeed(Connector):
    name = "rss"
    category = "feed"
    summary = "RSS / Atom フィードの取得（キー不要。query はフィードURL）"
    priority = 10
    auth = AuthSpec()
    rate_limit = RateLimit(requests=60, per_seconds=60)

    def check(self) -> CheckResult:
        # 対象URLが無いと確認できないので、疎通確認は行わない
        return CheckResult(
            self.name, ok=True, detail="フィードURLを指定して使う（疎通確認なし）", skipped=True
        )

    def fetch_items(self, query: str, *, limit: int = 10, timeout: int = 30) -> list[FeedItem]:
        url = query.strip()
        if not url.startswith(("http://", "https://")):
            raise ConfigError(f"フィードのURLを指定してください: {query!r}")

        response = self.request("GET", url, timeout=timeout)
        return parse_feed(response.text, url)[:limit]


def parse_feed(xml_text: str, source_url: str = "") -> list[FeedItem]:
    """RSS 2.0 と Atom のどちらでも記事一覧に変換する。"""
    try:
        root = ElementTree.fromstring(xml_text.strip())
    except ElementTree.ParseError as exc:
        raise ConnectorError(f"rss: フィードを解析できませんでした（{exc}）") from exc

    items = [_from_rss(node, source_url) for node in root.iter("item")]
    items += [_from_atom(node, source_url) for node in root.iter(f"{ATOM_NS}entry")]
    return items


def _text(node, *paths: str) -> str:
    for path in paths:
        found = node.find(path)
        if found is not None and (found.text or "").strip():
            return found.text.strip()
    return ""


def _clean(value: str, limit: int = 300) -> str:
    return TAG_RE.sub("", value or "").strip()[:limit]


def _from_rss(node, source_url: str) -> FeedItem:
    return FeedItem(
        source="rss",
        title=_text(node, "title") or "(無題)",
        url=_text(node, "link", "guid"),
        published=_text(node, "pubDate", f"{DC_NS}date"),
        summary=_clean(_text(node, "description")),
        author=_text(node, "author", f"{DC_NS}creator"),
        tags=[c.text.strip() for c in node.findall("category") if (c.text or "").strip()],
        meta={"feed": source_url},
    )


def _from_atom(node, source_url: str) -> FeedItem:
    link = ""
    for candidate in node.findall(f"{ATOM_NS}link"):
        href = candidate.get("href", "")
        if href and candidate.get("rel", "alternate") == "alternate":
            link = href
            break
    return FeedItem(
        source="rss",
        title=_text(node, f"{ATOM_NS}title") or "(無題)",
        url=link,
        published=_text(node, f"{ATOM_NS}published", f"{ATOM_NS}updated"),
        summary=_clean(_text(node, f"{ATOM_NS}summary", f"{ATOM_NS}content")),
        author=_text(node, f"{ATOM_NS}author/{ATOM_NS}name"),
        tags=[c.get("term", "") for c in node.findall(f"{ATOM_NS}category") if c.get("term")],
        meta={"feed": source_url},
    )

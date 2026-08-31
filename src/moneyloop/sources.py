"""RSS/Atomの取得とパース。標準ライブラリのみで完結させている。

外部フィードは壊れていることが日常なので、1本の失敗で号が落ちないよう
例外はソース単位で握り、収集できた分だけ返す。
"""

from __future__ import annotations

import re
import urllib.error
import urllib.request
from datetime import datetime, timedelta, timezone
from email.utils import parsedate_to_datetime
from xml.etree import ElementTree

from .models import Item, Niche, Source

USER_AGENT = "moneyloop/0.1 (+https://github.com/nami0817kk-arch/ai-lab)"
_TAG = re.compile(r"<[^>]+>")
_WS = re.compile(r"\s+")


def fetch(url: str, timeout: float = 20.0) -> str:
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, timeout=timeout) as res:
        raw = res.read()
    return raw.decode("utf-8", errors="replace")


def strip_html(text: str, limit: int = 600) -> str:
    plain = _WS.sub(" ", _TAG.sub(" ", text or "")).strip()
    return plain[:limit]


def parse_datetime(value: str | None) -> datetime | None:
    """RFC822(RSS)とISO8601(Atom)の両方を受け付ける。失敗したらNone。"""
    if not value:
        return None
    value = value.strip()
    for parser in (parsedate_to_datetime, datetime.fromisoformat):
        try:
            dt = parser(value.replace("Z", "+00:00") if parser is datetime.fromisoformat else value)
            return dt if dt.tzinfo else dt.replace(tzinfo=timezone.utc)
        except (TypeError, ValueError):
            continue
    return None


def _text(node, *names: str) -> str:
    """名前空間の有無にかかわらず子要素のテキストを引く。"""
    for child in node:
        tag = child.tag.rsplit("}", 1)[-1]
        if tag in names:
            if tag == "link" and not (child.text or "").strip():
                return (child.attrib.get("href") or "").strip()
            return (child.text or "").strip()
    return ""


def parse_feed(xml_text: str, niche: str, source_name: str, limit: int = 20) -> list[Item]:
    """RSS 2.0 / Atom を Item のリストに変換する。"""
    try:
        root = ElementTree.fromstring(xml_text.strip())
    except ElementTree.ParseError:
        return []

    entries = [n for n in root.iter() if n.tag.rsplit("}", 1)[-1] in ("item", "entry")]
    now = datetime.now(timezone.utc)
    items: list[Item] = []
    for node in entries[:limit]:
        title = strip_html(_text(node, "title"), 300)
        url = _text(node, "link", "id")
        if not title or not url.startswith("http"):
            continue
        items.append(
            Item(
                niche=niche,
                source=source_name,
                title=title,
                url=url,
                summary=strip_html(_text(node, "description", "summary", "content")),
                published_at=parse_datetime(_text(node, "pubDate", "published", "updated", "date")),
                fetched_at=now,
            )
        )
    return items


def collect(
    niche: Niche,
    *,
    max_items_per_source: int = 20,
    lookback_hours: int = 48,
    fetcher=fetch,
) -> tuple[list[Item], list[str]]:
    """ニッチの全ソースから記事を集める。戻り値は (記事, エラーメッセージ)。"""
    cutoff = datetime.now(timezone.utc) - timedelta(hours=lookback_hours)
    items: list[Item] = []
    errors: list[str] = []
    for src in niche.sources:
        try:
            xml_text = fetcher(src.url)
        except (urllib.error.URLError, OSError, ValueError) as exc:
            errors.append(f"{src.name}: 取得失敗 ({exc})")
            continue
        for item in parse_feed(xml_text, niche.code, src.name, max_items_per_source):
            # 日付不明の記事は落とさず残す（フィード側の欠損が多いため）。
            if item.published_at is None or item.published_at >= cutoff:
                items.append(item)
    return items, errors


def source_from_url(url: str, name: str | None = None) -> Source:
    return Source(name=name or url.split("//")[-1].split("/")[0], url=url)

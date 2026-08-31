"""RSSフィードから最新の見出しを取る。

検索経由には構造的な限界がある。索引が数時間〜2日遅れ、日付で引くと
一覧ページが返り、要約は捏造する。RSSはサイトが自分で出している一覧なので、
見出し・URL・正確な時刻が数分遅れで取れる。

注意: 開発コンテナからは外に出られない（プロキシが403を返す）。
これは運用するPCで動かすためのもの。fetch --check で各フィードの生死を
確かめてから使う。
"""

from __future__ import annotations

import re
import urllib.error
import urllib.request
import xml.etree.ElementTree as ET
from dataclasses import dataclass
from datetime import datetime, timezone
from email.utils import parsedate_to_datetime

TIMEOUT = 15
# ボットとして名乗る。偽装はしない
USER_AGENT = "soccer-news-pipeline/1.0 (+rss reader)"

ATOM = "{http://www.w3.org/2005/Atom}"


class FeedError(Exception):
    pass


@dataclass
class Item:
    title: str
    url: str
    published: datetime | None = None

    def hours_ago(self, now: datetime | None = None) -> float | None:
        if self.published is None:
            return None
        now = now or datetime.now(timezone.utc)
        if now.tzinfo is None:
            now = now.replace(tzinfo=timezone.utc)
        return (now - self.published).total_seconds() / 3600

    def line(self) -> str:
        """collect にそのまま流せる形（見出し<タブ>URL<タブ>経過時間）。

        フィードには正確な時刻がある。URLから日付が読めないサイト（Sky など）でも
        鮮度を捨てずに済むよう、3列目に経過時間を付ける。
        """
        age = self.hours_ago()
        if age is None:
            return f"{self.title}\t{self.url}"
        return f"{self.title}\t{self.url}\t{max(0.0, age):.1f}h"


def fetch(url: str, timeout: int = TIMEOUT) -> list[Item]:
    """フィードを1本取って、新しい順に返す。"""
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            body = response.read()
    except (urllib.error.URLError, OSError, TimeoutError) as error:
        raise FeedError(f"取得できません: {error}") from error
    return parse(body.decode("utf-8", errors="replace"))


def parse(text: str) -> list[Item]:
    """RSS 2.0 と Atom の両方を読む。壊れた項目は飛ばす。"""
    try:
        root = ET.fromstring(text.strip())
    except ET.ParseError as error:
        raise FeedError(f"フィードとして読めません: {error}") from error

    items: list[Item] = []
    # RSS 2.0: <rss><channel><item>
    for node in root.iter("item"):
        entry = _rss_item(node)
        if entry:
            items.append(entry)
    # Atom: <feed><entry>
    for node in root.iter(f"{ATOM}entry"):
        entry = _atom_entry(node)
        if entry:
            items.append(entry)

    items.sort(
        key=lambda i: i.published or datetime.min.replace(tzinfo=timezone.utc), reverse=True
    )
    return items


def _rss_item(node) -> Item | None:
    title = _clean(node.findtext("title") or "")
    url = (node.findtext("link") or "").strip()
    if not (title and url.startswith("http")):
        return None
    published = None
    stamp = node.findtext("pubDate") or node.findtext(
        "{http://purl.org/dc/elements/1.1/}date"
    )
    if stamp:
        published = _when(stamp)
    return Item(title=title, url=url, published=published)


def _atom_entry(node) -> Item | None:
    title = _clean(node.findtext(f"{ATOM}title") or "")
    url = ""
    for link in node.findall(f"{ATOM}link"):
        if link.get("rel") in (None, "alternate"):
            url = (link.get("href") or "").strip()
            break
    if not (title and url.startswith("http")):
        return None
    stamp = node.findtext(f"{ATOM}published") or node.findtext(f"{ATOM}updated")
    return Item(title=title, url=url, published=_when(stamp) if stamp else None)


def _when(stamp: str) -> datetime | None:
    """RFC822（RSS）と ISO8601（Atom/dc:date）の両方を読む。読めなければ None。"""
    stamp = stamp.strip()
    try:
        found = parsedate_to_datetime(stamp)
        if found.tzinfo is None:
            found = found.replace(tzinfo=timezone.utc)
        return found
    except (TypeError, ValueError):
        pass
    try:
        found = datetime.fromisoformat(stamp.replace("Z", "+00:00"))
        if found.tzinfo is None:
            found = found.replace(tzinfo=timezone.utc)
        return found
    except ValueError:
        return None


TAG = re.compile(r"<[^>]+>")


def _clean(text: str) -> str:
    """CDATAやタグの混入を落とす。見出しはプレーンテキストにする。"""
    return TAG.sub("", text).strip()


def recent(items: list[Item], hours: float, now: datetime | None = None) -> list[Item]:
    """この時間内のものだけ。時刻の無い項目は残す（判断できないものは落とさない）。"""
    kept = []
    for item in items:
        age = item.hours_ago(now)
        if age is None or age <= hours:
            kept.append(item)
    return kept

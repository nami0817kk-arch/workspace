"""RSSフィードから最新の見出しを取る。

検索経由には構造的な限界がある。索引が数時間〜2日遅れ、日付で引くと
一覧ページが返り、要約は捏造する。RSSはサイトが自分で出している一覧なので、
見出し・URL・正確な時刻が数分遅れで取れる。

注意: 開発コンテナからは外に出られない（プロキシが403を返す）。
これは運用するPCで動かすためのもの。fetch --check で各フィードの生死を
確かめてから使う。
"""

from __future__ import annotations

import html as html_lib
import re
import urllib.error
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
from dataclasses import dataclass
from datetime import datetime, timezone
from email.utils import parsedate_to_datetime

TIMEOUT = 15
# ボットとして名乗る。偽装はしない
USER_AGENT = "soccer-news-pipeline/1.0 (+rss reader)"

ATOM = "{http://www.w3.org/2005/Atom}"
# ページが宣言しているフィードを拾うため
LINK_TAG = re.compile(r"<link\b[^>]*>", re.I)


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


# これより古い見出ししか無いフィードは、生きていても止まっている
STALE_HOURS = 72


def is_stale(hours: float | None, limit: float = STALE_HOURS) -> bool:
    """フィードが止まっているか。

    「取れる」と「使える」は別。AS の as.com/rss/futbol/portada.xml は
    68件返すが最新が4年前だった（実測）。件数だけ見ていると気づけない。
    Premier League のフィードでも同じことが起きて、手で見つけている。
    """
    return hours is not None and hours > limit


def age_text(hours: float | None) -> str:
    """フィードの新しさの言い方。

    フィード側の時計が進んでいることがある（Sky は実測で40分ほど先の時刻を
    付けてきた）。そのまま引き算すると「最新 -0.7時間前」になって読めない。
    サイト側の時計の話なので、こちらで直せる種類のものではない。
    黙って0に丸めると気づけないので、進んでいることが見えるようにする。
    """
    if hours is None:
        return "時刻なし"
    if hours < 0:
        return f"最新の時刻が{-hours * 60:.0f}分先（フィード側の時計が進んでいる）"
    return f"最新 {hours:.1f}時間前"


def _get(url: str, timeout: int = TIMEOUT) -> str:
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            return response.read().decode("utf-8", errors="replace")
    except (urllib.error.URLError, OSError, TimeoutError) as error:
        raise FeedError(f"取得できません: {error}") from error


def fetch(url: str, timeout: int = TIMEOUT) -> list[Item]:
    """フィードを1本取って、新しい順に返す。"""
    return parse(_get(url, timeout))


def discover(page_url: str, timeout: int = TIMEOUT) -> list[tuple[str, str]]:
    """ページが自分で宣言しているフィードを取り出す。(名前, URL) の並び。

    フィードのURLを当て推量で探すと外す。Sky は全スポーツ版とサッカー版が
    連番のIDで並んでいて、番号からは中身が読めない（実測で外した）。
    ページ自身に聞けば、そのページ用のフィードが名前つきで返る。
    """
    html = _get(page_url, timeout)
    found: list[tuple[str, str]] = []
    for tag in LINK_TAG.findall(html):
        lowered = tag.lower()
        if "application/rss+xml" not in lowered and "application/atom+xml" not in lowered:
            continue
        href = _attr(tag, "href")
        if not href:
            continue
        url = urllib.parse.urljoin(page_url, _unescape(href))
        if url in {u for _, u in found}:
            continue
        found.append((_unescape(_attr(tag, "title")) or "（名前なし）", url))
    return found


def _attr(tag: str, name: str) -> str:
    match = re.search(rf'{name}\s*=\s*"([^"]*)"', tag, re.I) or re.search(
        rf"{name}\s*=\s*'([^']*)'", tag, re.I
    )
    return match.group(1).strip() if match else ""


def _unescape(text: str) -> str:
    return html_lib.unescape(text)


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


# RFC822 が知らない時間帯の名前。書いてあるのに読めないと、
# 「時間帯なし」→ UTC とみなされて、夏時間のぶんだけ新しい方へずれる。
# Sky は BST と書いてくる。UTC扱いすると全部の見出しが1時間新しくなり、
# `fetch --check` に「最新の時刻が46分先」と出ていた（実測）。
#
# IST は「アイルランド(+0100)」と「インド(+0530)」で割れるので入れない。
# 当てられないものを当てたことにしない。
NAMED_ZONES = {
    "BST": "+0100",     # 英国夏時間。Sky
    "CET": "+0100",
    "CEST": "+0200",    # 中欧夏時間。kicker / Gazzetta の系統
    "WET": "+0000",
    "WEST": "+0100",
    "EET": "+0200",
    "EEST": "+0300",
    "JST": "+0900",
}

ZONE_TAIL = re.compile("(" + "|".join(NAMED_ZONES) + ")[ ]*$")


def _numeric_zone(stamp: str) -> str:
    """末尾の時間帯の名前を、数字の時差に置き換える。"""
    return ZONE_TAIL.sub(lambda m: NAMED_ZONES[m.group(1).upper()], stamp)


def _when(stamp: str) -> datetime | None:
    """RFC822（RSS）と ISO8601（Atom/dc:date）の両方を読む。読めなければ None。"""
    stamp = stamp.strip()
    try:
        found = parsedate_to_datetime(_numeric_zone(stamp))
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

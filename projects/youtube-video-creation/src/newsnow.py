"""NewsNow の見出し一覧から候補を取る（英語圏の集約サイト）。

FOOTBALL TOPIC の英語版にあたるものを探して、いちばん近かったのがここ
（2026-09-05 に実測。docs/news-sources.md に比較を残してある）。

**人気の点数は持っていない。**FOOTBALL TOPIC の Points に当たるものが無いので、
「いま読まれているか」の軸には使えない。ここが埋めるのは**幅と、リーグの自動判定**。

一覧に載っているもの:
  - 見出し
  - 媒体名（data-pub と、読める名前の両方）
  - UNIX時刻（**経過時間がそのまま出る**）
  - クラブとリーグのタグ（`/h/Sport/Football/Premier+League/Liverpool`）
    → league を機械で埋められる。毎回手で埋めていた欄

リンクは中継URL（c.newsnow.co.uk）で、素の GET では飛ばない。中継ページの
中に実URLが書いてあるので、そこから取り出す。**1件につき1回よけいに叩く**ので、
取る件数は絞る。
"""

from __future__ import annotations

import html as html_mod
import re
import time
from dataclasses import dataclass
from datetime import datetime

import requests

URL = "https://www.newsnow.co.uk/h/Sport/Football"
UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) youtube-video-creation/1.0"
TIMEOUT = 25
PAUSE = 0.4      # 中継ページを続けて叩くときの間

# リーグのタグ → こちらのリーグ名。載っていないものは空のまま（判断を残す）
LEAGUE_BY_TAG = {
    "Premier+League": "england",
    "La+Liga": "spain",
    "Serie+A": "italy",
    "Bundesliga": "germany",
    "Ligue+1": "france",
    "Eredivisie": "netherlands",
    "J+League": "japan",
}

# 見出しの箱。class は "hl "・"hl hl_inv"・"hl" のどれもある
BLOCK = re.compile(r'<div class="hl(?:\s[^"]*)?"[^>]*>(?P<body>.*?)</span></div>', re.S)
LINK = re.compile(r'<a class="hll" href="(?P<url>[^"]+)"[^>]*>(?P<title>[^<]+)</a>')
PUB = re.compile(r'data-pub="(?P<key>[^"]*)"[^>]*>(?P<name>[^<]*?)<')
TIME = re.compile(r'data-time="(?P<epoch>[0-9]+)"')
TAG = re.compile(r'<a class="fav" href="/h/Sport/Football/(?P<path>[^"]+)"')
OUTBOUND = re.compile(r'href="(https?://(?!c\.newsnow|www\.newsnow|www\.dec\.org\.uk)[^"]+)"')


class NewsNowError(Exception):
    pass


@dataclass
class Item:
    title: str
    url: str                 # 中継URL。resolve すると実URLに変わる
    publisher: str = ""
    posted: "datetime | None" = None
    league: str = ""
    clubs: tuple = ()

    def hours_ago(self, now: "datetime | None" = None) -> float:
        if self.posted is None:
            return -1.0
        return max(0.0, ((now or datetime.now()) - self.posted).total_seconds() / 3600)


def fetch(limit: int = 40, session=None) -> list[Item]:
    """見出し一覧を読む。リンクはまだ中継URLのまま。"""
    client = session or requests
    try:
        response = client.get(URL, headers={"User-Agent": UA}, timeout=TIMEOUT)
        response.raise_for_status()
    except requests.RequestException as error:
        raise NewsNowError(f"開けません: {error}") from error
    return parse(response.text, limit)


def parse(html: str, limit: int = 40) -> list[Item]:
    items: list[Item] = []
    seen: set[str] = set()
    for block in BLOCK.finditer(html):
        body = block.group("body")
        link = LINK.search(body)
        if not link:
            continue
        url = link.group("url").strip()
        if url in seen:
            continue
        seen.add(url)

        paths = [p for p in TAG.findall(body)]
        league = ""
        clubs = []
        for path in paths:
            head, _, tail = path.partition("/")
            league = league or LEAGUE_BY_TAG.get(head, "")
            if tail:
                clubs.append(tail.replace("+", " "))
        pub = PUB.search(body)
        stamp = TIME.search(body)
        items.append(Item(
            title=html_mod.unescape(re.sub(r"\s+", " ", link.group("title"))).strip(),
            url=url,
            publisher=(html_mod.unescape(pub.group("name")).strip() if pub else ""),
            posted=(datetime.fromtimestamp(int(stamp.group("epoch"))) if stamp else None),
            league=league,
            clubs=tuple(clubs),
        ))
        if len(items) >= limit:
            break
    return items


def resolve(items: list[Item], session=None, pause: float = PAUSE) -> list[Item]:
    """中継URLを実URLに置き換える。**1件につき1回叩く**ので、件数を絞って呼ぶ。

    取れなかったものは落とす。中継URLのまま候補にすると、確度の上限を
    決める仕組み（domain_tiers）が「網に無いサイト」としか見られない。
    """
    client = session or requests
    out: list[Item] = []
    for item in items:
        time.sleep(pause)
        try:
            page = client.get(
                item.url, headers={"User-Agent": UA, "Referer": URL}, timeout=TIMEOUT
            )
            page.raise_for_status()
        except requests.RequestException:
            continue
        found = OUTBOUND.search(page.text)
        if not found:
            continue
        item.url = found.group(1)
        out.append(item)
    return out


def recent(hours: float = 24.0, limit: int = 40, now=None, session=None) -> list[Item]:
    """直近ぶんだけ、新しい順に。実URLまで解決して返す。"""
    rows = [i for i in fetch(limit, session) if i.posted is not None]
    fresh = [i for i in rows if i.hours_ago(now) <= hours]
    fresh.sort(key=lambda i: i.hours_ago(now))
    return resolve(fresh, session)


def lines(rows: list[Item]) -> str:
    """`gather --paste` にそのまま渡せる「見出し<TAB>URL」の並び。"""
    return chr(10).join(f"{i.title}{chr(9)}{i.url}" for i in rows)


def meta(rows: list[Item], now=None) -> dict[str, dict]:
    """URL → 経過時間とリーグ。gather が hits に貼り直すのに使う。"""
    return {
        i.url: {"hours_ago": i.hours_ago(now), "league": i.league, "rank": 0}
        for i in rows
    }

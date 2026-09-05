"""まとめを横断する集約サイト（FOOTBALL TOPIC）から、話題の一覧を取る。

**フィードだけでは1日ぶんの材料が足りない。**実測（2026-09-04）で、9本の枠に
対して条件を満たす候補が5本しか無かった。ここは60件のまとめへのリンクを
1ページで並べているので、材料の幅がひと息に広がる。

`?sort=click_cnt` はクリック数順。**いま何が読まれているか**が分かるので、
題材選びの手がかりになる（新着順だと、まだ誰も読んでいないものが上に来る）。

取れるのは見出しとリンク先だけ。確度は rumour 群（未確認どまり）で、
リンク先は匿名掲示板のまとめ。単独では根拠にしない。反応を引くときは
`reactions` でリンク先を辿って**数えてから**使う。
"""

from __future__ import annotations

import re

import requests

URL = "https://www.footballtopic.com/matome/"
UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) youtube-video-creation/1.0"
TIMEOUT = 30
SORTS = {"話題": "click_cnt", "新着": "date"}

# <h2 class="postTitle"><img ...><a href="URL" onclick="..." target="_blank">見出し</a>
ROW = re.compile(
    r'<h2[^>]*class="postTitle"[^>]*>.*?<a[^>]+href="(?P<url>[^"]+)"[^>]*>(?P<title>[^<]+)</a>',
    re.S,
)


class TopicError(Exception):
    pass


def fetch(sort: str = "話題", limit: int = 60, session=None) -> list[tuple[str, str]]:
    """(見出し, リンク先) の一覧。話題順が既定。"""
    key = SORTS.get(sort, sort)
    client = session or requests
    try:
        response = client.get(
            URL, params={"sort": key}, headers={"User-Agent": UA}, timeout=TIMEOUT
        )
        response.raise_for_status()
    except requests.RequestException as error:
        raise TopicError(f"開けません: {error}") from error
    # このページは UTF-8 だが Content-Type に charset が無く、requests が
    # 取り違えて文字化けする（実測 2026-09-04）。明示して読む
    response.encoding = "utf-8"
    return parse(response.text, limit)


def parse(html: str, limit: int = 60) -> list[tuple[str, str]]:
    rows: list[tuple[str, str]] = []
    seen: set[str] = set()
    for match in ROW.finditer(html):
        url = match.group("url").strip()
        title = re.sub(r"\s+", " ", match.group("title")).strip()
        if not title or not url.startswith("http") or url in seen:
            continue
        seen.add(url)
        rows.append((title, url))
        if len(rows) >= limit:
            break
    return rows


def lines(sort: str = "話題", limit: int = 60, session=None) -> str:
    """`gather --paste` にそのまま渡せる「見出し<TAB>URL」の並び。"""
    return chr(10).join(f"{title}{chr(9)}{url}" for title, url in fetch(sort, limit, session))


def ranks(sort: str = "話題", limit: int = 60, session=None) -> dict[str, int]:
    """リンク先URL → 掲載順（1が最上位）。

    話題順のページは**クリック数の多い順**に並んでいる。並び順そのものが
    「いま何が読まれているか」で、こちらのフィードでは代わりが作れない。
    """
    return {url: index for index, (_, url) in enumerate(fetch(sort, limit, session), start=1)}

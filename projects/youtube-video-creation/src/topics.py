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
from dataclasses import dataclass
from datetime import datetime

import requests

URL = "https://www.footballtopic.com/matome/"
UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) youtube-video-creation/1.0"
TIMEOUT = 30
SORTS = {"話題": "click_cnt", "新着": "date"}

# 1件ぶんの並び。見出しのあとに「媒体名 on 2026.09.03/06:00　105 Points」が続く。
# **日時と Points まで載っている。**当日分に絞れるし、人気を実数で読める。
# 1件ぶんの並び。見出しのあとに
#   <p class="postInfo">媒体名&nbsp;on&nbsp;2026.09.03/06:00　<span>105&nbsp;Points</span></p>
# が続く。**日時と Points まで載っている。**当日分に絞れるし、人気を実数で読める。
#
# postInfo はまるごと取ってから中身を読む。1つの正規表現に省略可能な組を
# 混ぜると、遅延一致がそこを空で通してしまい Points が常に 0 になった
# （2026-09-05 実測）。
ROW = re.compile(
    r'<h2[^>]*class="postTitle"[^>]*>.*?<a[^>]+href="(?P<url>[^"]+)"[^>]*>(?P<title>[^<]+)</a>'
    r'.*?<p[^>]*class="postInfo"[^>]*>(?P<info>.*?)</p>',
    re.S,
)
POSTED = re.compile(r"(\d{4})\.(\d{2})\.(\d{2})/(\d{2}):(\d{2})")
POINTS = re.compile(r"(\d+)(?:&nbsp;|\s)*Points", re.I)


@dataclass
class Topic:
    """集約サイトに並んでいた1件。"""

    title: str
    url: str
    site: str = ""
    posted: "datetime | None" = None
    points: int = 0
    rank: int = 0        # 絞り込んだあとの順位。1が一番人気

    def hours_ago(self, now: "datetime | None" = None) -> float:
        if self.posted is None:
            return -1.0
        base = now or datetime.now()
        return max(0.0, (base - self.posted).total_seconds() / 3600)


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


def parse(html: str, limit: int = 60) -> list[Topic]:
    rows: list[Topic] = []
    seen: set[str] = set()
    for match in ROW.finditer(html):
        url = match.group("url").strip()
        title = re.sub(r"\s+", " ", match.group("title")).strip()
        if not title or not url.startswith("http") or url in seen:
            continue
        seen.add(url)
        info = match.group("info") or ""
        points = POINTS.search(info)
        rows.append(Topic(
            title=title,
            url=url,
            site=re.split(r"&nbsp;|\son\s", info)[0].strip(),
            posted=_moment(info),
            points=int(points.group(1)) if points else 0,
        ))
        if len(rows) >= limit:
            break
    return rows


def _moment(text: str | None) -> "datetime | None":
    """「2026.09.03/06:00」を読む。読めなければ None。"""
    found = POSTED.search(text or "")
    if not found:
        return None
    try:
        return datetime(*(int(g) for g in found.groups()))
    except ValueError:
        return None


def recent(hours: float = 24.0, limit: int = 60, now=None, session=None) -> list[Topic]:
    """**直近ぶんだけを、人気の多い順に。**順位を振り直して返す。

    集約サイトの並びは全期間のクリック数順なので、何日も前の記事が上に来る。
    枠に入れるのは当日の話なので、日時で絞ってから数え直す。
    Points が載っていない行は 0 として最後に回す。
    """
    rows = [t for t in fetch("話題", limit, session) if t.posted is not None]
    fresh = [t for t in rows if t.hours_ago(now) <= hours]
    fresh.sort(key=lambda t: (-t.points, t.hours_ago(now)))
    for index, topic in enumerate(fresh, start=1):
        topic.rank = index
    return fresh


def lines(rows: list[Topic]) -> str:
    """`gather --paste` にそのまま渡せる「見出し<TAB>URL」の並び。"""
    return chr(10).join(f"{t.title}{chr(9)}{t.url}" for t in rows)


def meta(rows: list[Topic], now=None) -> dict[str, dict]:
    """URL → 順位と経過時間。gather が hits に貼り直すのに使う。

    **経過時間もここで分かる。**集約サイト経由の候補は時刻が読めず、
    「新しさ」の点が付かなかった（2026-09-05 実測）。日時が載っているので使う。
    """
    return {
        t.url: {"rank": t.rank, "points": t.points, "hours_ago": t.hours_ago(now)}
        for t in rows
    }


def ranks(sort: str = "話題", limit: int = 60, session=None) -> dict[str, int]:
    """リンク先URL → 掲載順（1が最上位）。

    話題順のページは**クリック数の多い順**に並んでいる。並び順そのものが
    「いま何が読まれているか」で、こちらのフィードでは代わりが作れない。
    """
    return {t.url: index for index, t in enumerate(fetch(sort, limit, session), start=1)}

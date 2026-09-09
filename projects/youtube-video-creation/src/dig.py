"""題材から材料までを一本につなぐ（2026-09-09）。

ユーザー「掘るの仕組みが弱いと思わない？」——弱かった。深掘り検索21本は
**検索語を印刷するだけ**で1本も自動で回っておらず、私が手で叩いて目に留まった
ものだけを読んでいた。`material` も「私が既に取材メモに書いた出典」しか読まない。
だから取材の深さがその時の集中力に依存し、昨夜の6本は他人の声0件・数字3〜11行と
ばらついた。

**検索から本文までを繋ぐ。**使えるものを実測（2026-09-09）で選んだ。

| 経路 | 実URL | 使いどころ |
|---|---|---|
| 媒体の検索フィード（`?s=<語>&feed=rss2`） | **あり** | 本文を読む記事を見つける |
| Google ニュース検索RSS | 無し（google.com へのリンク） | **どれだけの媒体が扱ったか**を測る |
| DuckDuckGo / Bing | 202・抽出不可 | 使わない |

Google ニュースは実URLを隠すので本文は読めないが、「日本語99件・英語100件」の
ように**話の大きさ**と媒体名・見出し・日付が取れる。題材選びの裏取りに使う。
"""

from __future__ import annotations

import re
import urllib.parse
import xml.etree.ElementTree as ET
from dataclasses import dataclass, field
from urllib.parse import urlparse

import requests

UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) youtube-video-creation/1.0"
TIMEOUT = 20

# 題材語で引ける検索フィード。**2026-09-09 に1つずつ叩いて、実URLが返ることを確認した。**
# qoly / football-zone / gekisaka / soccerdigest / number は同じ形が通らなかった
SEARCH_FEEDS = (
    "https://www.footballchannel.jp/?s={q}&feed=rss2",
    "https://web.ultra-soccer.jp/?s={q}&feed=rss2",
    "https://soccer-king.jp/?s={q}&feed=rss2",
    "https://www.theworldmagazine.jp/?s={q}&feed=rss2",
    "https://www.footballista.jp/?s={q}&feed=rss2",
)
NEWS_JA = "https://news.google.com/rss/search?q={q}&hl=ja&gl=JP&ceid=JP:ja"
NEWS_EN = "https://news.google.com/rss/search?q={q}&hl=en-GB&gl=GB&ceid=GB:en"
MAX_ARTICLES = 8       # 本文を読む記事の数。読むほど遅くなるので上限を置く


@dataclass
class Hit:
    title: str
    url: str
    outlet: str
    published: str = ""


@dataclass
class Coverage:
    """どれだけの媒体が扱ったか。実URLは取れないので、数と名前だけ。"""

    total: int = 0
    outlets: list[tuple[str, int]] = field(default_factory=list)
    headlines: list[tuple[str, str]] = field(default_factory=list)   # (媒体, 見出し)


@dataclass
class Entry:
    title: str = ""
    link: str = ""
    source: str = ""      # Google ニュースだけが持つ「どの媒体か」
    published: str = ""


def _feed(url: str, session=None) -> list[Entry]:
    """RSS 2.0 を読む。**新しい依存を足さない**（2026-09-09）。

    最初 feedparser で書いたが、あれはローカルに偶然入っていただけで
    requirements に無く、CI が ModuleNotFoundError で落ちた。
    src/feeds.py と同じく標準ライブラリで読む。Google ニュースも媒体の
    検索フィードも RSS 2.0 なので、これで足りる。
    """
    client = session or requests
    try:
        resp = client.get(url, headers={"User-Agent": UA}, timeout=TIMEOUT)
        root = ET.fromstring(resp.text.strip())
    except Exception:  # noqa: BLE001 - 1本落ちても他の経路は続ける
        return []
    entries: list[Entry] = []
    for node in root.iter("item"):
        def text(tag: str) -> str:
            found = node.find(tag)
            return (found.text or "").strip() if found is not None else ""

        entries.append(Entry(title=text("title"), link=text("link"),
                             source=text("source"), published=text("pubDate")))
    return entries


def search(topic: str, hosts: set[str], session=None, must: str = "") -> list[Hit]:
    """媒体の検索フィードから、題材の記事を実URL付きで集める。

    許可サイト以外は捨てる。見出しに題材の語が1つも無いものも捨てる
    （`?s=` が効かず新着をそのまま返す媒体がある）。

    ``must`` を渡すと、**その語のどれかが見出しに無い記事も捨てる**（2026-09-09）。
    人名だけで引くと、その選手の別の日の話が並ぶ。実際にハーランドで
    コベントリー戦と主将の話、アーセナルでSD人事が返ってきて、今日の話が
    1本も入らなかった。枠の見出しの言葉を渡して絞る。
    """
    from .material import is_allowed

    words = [w for w in re.split(r"[\s　]+", topic) if w]
    narrow = [w for w in re.split(r"[\s　]+", must) if w]
    found: list[Hit] = []
    seen: set[str] = set()
    for pattern in SEARCH_FEEDS:
        url = pattern.format(q=urllib.parse.quote(topic))
        for entry in _feed(url, session):
            link, title = entry.link, entry.title
            if not link or link in seen or not is_allowed(link, hosts):
                continue
            if words and not any(w in title for w in words):
                continue
            if narrow and not any(w in title for w in narrow):
                continue
            seen.add(link)
            found.append(Hit(title=title, url=link.split("?")[0],
                             outlet=urlparse(link).netloc,
                             published=entry.published))
    return found


def coverage(topic: str, english: str = "", session=None) -> Coverage:
    """Google ニュース検索RSS で、その話をどれだけの媒体が扱ったかを測る。"""
    from collections import Counter

    got = Coverage()
    names: Counter = Counter()
    for template, query in ((NEWS_JA, topic), (NEWS_EN, english or topic)):
        if not query:
            continue
        for entry in _feed(template.format(q=urllib.parse.quote(query)), session):
            got.total += 1
            if entry.source:
                names[entry.source] += 1
            if len(got.headlines) < 12:
                got.headlines.append((entry.source, entry.title))
    got.outlets = names.most_common(12)
    return got


def render(topic: str, got: Coverage, hits: list[Hit], material_text: str,
           reactions_text: str = "") -> str:
    """材料の1枚。上から「話の大きさ」「読めた記事」「反応」。"""
    lines = [f"# 材料: {topic}", ""]
    lines += [f"## 話の大きさ（Google ニュース）", f"- 記事 {got.total}件 / 媒体 {len(got.outlets)}",
              "- 扱った媒体: " + "、".join(f"{n}（{c}）" for n, c in got.outlets[:10]), ""]
    if got.headlines:
        lines.append("### 見出し（本文は読めない。題材と切り口の参考）")
        lines += [f"- [{outlet}] {title}" for outlet, title in got.headlines]
        lines.append("")
    lines.append(f"## 本文を読んだ記事（{len(hits)}本）")
    lines += [f"- {h.outlet} {h.title}　{h.url}" for h in hits]
    lines += ["", material_text]
    if reactions_text:
        lines += ["## 反応", reactions_text]
    return chr(10).join(lines)


def run(topic: str, hosts: set[str], english: str = "", session=None,
        limit: int = MAX_ARTICLES, must: str = "") -> tuple[Coverage, list[Hit], str]:
    """検索 → 本文 → 材料。反応は呼ぶ側で足す（時間がかかるので別建て）。"""
    from . import material as material_mod

    got = coverage(topic, english, session)
    hits = search(topic, hosts, session, must)[:limit]
    items = material_mod.gather([h.url for h in hits], hosts, session)
    return got, hits, material_mod.render(items)

# -*- coding: utf-8 -*-
"""「世の中の気になる」を集める。3つの源から拾う。

1. ニュース  … いま起きていること（RSS）
2. サジェスト … 人が実際に打ち込んでいる疑問（Google の検索補完）
3. はてブ    … いま議論になっていること

どれも無料・鍵なしで取れるものだけを使う。
"""
from __future__ import annotations

import json
import re
import urllib.error
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
from dataclasses import dataclass, field

UA = {"User-Agent": "Mozilla/5.0 (danmen-gather)"}

NEWS_FEEDS: dict[str, str] = {
    "主要":     "https://news.yahoo.co.jp/rss/topics/top-picks.xml",
    "国内":     "https://news.yahoo.co.jp/rss/topics/domestic.xml",
    "国際":     "https://news.yahoo.co.jp/rss/topics/world.xml",
    "経済":     "https://news.yahoo.co.jp/rss/topics/business.xml",
    "科学":     "https://news.yahoo.co.jp/rss/topics/science.xml",
    "IT":       "https://news.yahoo.co.jp/rss/topics/it.xml",
    "暮らし":   "https://news.yahoo.co.jp/rss/topics/life.xml",
    "NHK主要":  "https://www.nhk.or.jp/rss/news/cat0.xml",
    "NHK経済":  "https://www.nhk.or.jp/rss/news/cat5.xml",
    "NHK科学":  "https://www.nhk.or.jp/rss/news/cat3.xml",
    "NHK国際":  "https://www.nhk.or.jp/rss/news/cat6.xml",
    "ITmedia":  "https://rss.itmedia.co.jp/rss/2.0/news_bursts.xml",
    "東洋経済": "https://toyokeizai.net/list/feed/rss",
    "ダイヤモンド": "https://diamond.jp/list/feed/rss/dol",
    "トレンド": "https://trends.google.co.jp/trending/rss?geo=JP",
}

HATENA_FEEDS: dict[str, str] = {
    "はてブ総合": "https://b.hatena.ne.jp/hotentry.rss",
    "はてブ経済": "https://b.hatena.ne.jp/hotentry/economics.rss",
    "はてブ社会": "https://b.hatena.ne.jp/hotentry/social.rss",
    "はてブ技術": "https://b.hatena.ne.jp/hotentry/it.rss",
}

# 毎日かならず引く種。世の中の定番の疑問を取りこぼさないため
SEED_QUERIES = [
    "なぜ 日本 だけ", "なぜ 日本 は", "どうして 値上げ", "なぜ 税金",
    "なぜ 減った", "なぜ 増えた", "なぜ 高い", "なぜ 安い",
]


@dataclass
class Item:
    """拾ったひとつ。"""
    source: str
    text: str
    link: str = ""
    kind: str = "news"          # news / suggest / hatena
    seed: str = ""              # サジェストのとき、どの語から出たか
    hits: list[str] = field(default_factory=list)
    score: int = 0


def _get(url: str, timeout: int = 20) -> bytes:
    return urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=timeout).read()


def _rss(url: str) -> list[tuple[str, str]]:
    root = ET.fromstring(_get(url))
    out = []
    for item in root.iter():
        tag = item.tag.split("}")[-1]
        if tag not in ("item", "entry"):
            continue
        title = link = ""
        for child in item:
            t = child.tag.split("}")[-1]
            if t == "title":
                title = (child.text or "").strip()
            elif t == "link":
                link = (child.text or child.get("href") or "").strip()
        if title:
            out.append((title, link))
    return out


def news() -> list[Item]:
    out: list[Item] = []
    for name, url in NEWS_FEEDS.items():
        try:
            for title, link in _rss(url):
                out.append(Item(source=name, text=title, link=link, kind="news"))
        except Exception:
            continue
    return out


def hatena() -> list[Item]:
    out: list[Item] = []
    for name, url in HATENA_FEEDS.items():
        try:
            for title, link in _rss(url):
                out.append(Item(source=name, text=title, link=link, kind="hatena"))
        except Exception:
            continue
    return out


def suggest(seed: str, youtube: bool = False) -> list[str]:
    """検索補完。人が実際に打っている疑問が取れる。

    youtube=True にすると YouTube 側の補完になる。Google とは結果が違い、
    「動画で見たい疑問」が出る（例：ガソリン → Google は「価格」「近く」、
    YouTube は「ガソリン税」「減税」「廃止」）。
    """
    ds = "&ds=yt" if youtube else ""
    url = ("https://suggestqueries.google.com/complete/search"
           f"?client=firefox&hl=ja{ds}&q={urllib.parse.quote(seed)}")
    try:
        data = json.loads(_get(url, timeout=12).decode("utf-8"))
        return [s for s in data[1] if isinstance(s, str)]
    except Exception:
        return []


# ニュースの見出しから、サジェストに投げる語を拾う
STOP = set("ため こと もの よう これ それ 日本 発表 検討 可能性 見通し 方針 社長 首相 大臣".split())
WORD = re.compile(r"[一-龥ァ-ヶー]{3,8}")


def keywords_from(items: list[Item], limit: int = 12) -> list[str]:
    counts: dict[str, int] = {}
    for it in items:
        for w in WORD.findall(it.text):
            if w in STOP:
                continue
            counts[w] = counts.get(w, 0) + 1
    return [w for w, _ in sorted(counts.items(), key=lambda kv: -kv[1])[:limit]]


def suggests(seeds: list[str], youtube: bool = False) -> list[Item]:
    out: list[Item] = []
    seen: set[str] = set()
    label = "YouTube検索" if youtube else "サジェスト"
    kind = "yt_suggest" if youtube else "suggest"
    for seed in seeds:
        for s in suggest(seed, youtube=youtube):
            if s in seen or s == seed:
                continue
            seen.add(s)
            out.append(Item(source=label, text=s, kind=kind, seed=seed))
    return out


def demand(word: str) -> dict[str, list[str]]:
    """ひとつの言葉について、Google と YouTube の両方で何が検索されているか見る。
    題材を決める前に、動画としての需要があるか確かめるのに使う。"""
    return {"Google": suggest(word), "YouTube": suggest(word, youtube=True)}


TRENDS_RSS = "https://trends.google.co.jp/trending/rss?geo=JP"
_TRENDS_CACHE: list[tuple[str, int]] | None = None


def trends(limit: int = 40) -> list[tuple[str, int]]:
    """Google の**急上昇ワード**と、その検索数の目安。(語, 件数) の並び。

    2026-10-09 に足した。それまで「新しさ」は**由来だけ**で決めていて
    （ニュース由来なら3点）、実際にいま検索されているかを見ていなかった。

    旧 URL（/trends/trendingsearches/daily/rss）は 404。今は /trending/rss。
    """
    global _TRENDS_CACHE
    if _TRENDS_CACHE is not None:
        return _TRENDS_CACHE[:limit]
    import re as _re
    out: list[tuple[str, int]] = []
    try:
        raw = _get(TRENDS_RSS).decode("utf-8", "replace")
        pat = r"<title>(.*?)</title>.*?approx_traffic>([0-9,]+)\+?<"
        for m in _re.finditer(pat, raw, _re.S):
            word = _re.sub(r"<[^>]+>", "", m.group(1)).strip()
            if word and word != "Daily Search Trends":
                out.append((word, int(m.group(2).replace(",", ""))))
    except Exception:
        out = []
    _TRENDS_CACHE = out
    return out[:limit]


def trend_hit(text: str, limit: int = 40) -> int:
    """その題材が、いま急上昇している語を含むか。含めば検索数の目安を返す。

    **急上昇ワードの側を分けて照合する。** 丸ごとの一致を見ると、
    「ホワイトソックス 監督」が「ホワイトソックスの試合」に当たらない（2026-10-09）。
    """
    best = 0
    for word, n in trends(limit):
        parts = [w for w in word.split() if len(w) >= 2]
        if (word and word in text) or any(p in text for p in parts):
            best = max(best, n)
    return best


def gather_all() -> list[Item]:
    ns = news()
    hs = hatena()
    words = keywords_from(ns, limit=10)
    seeds = SEED_QUERIES + [f"なぜ {w}" for w in words]
    ss = suggests(seeds)
    # YouTube 側は「なぜ」を付けず、言葉そのもので引く。
    # 動画で何が見られているかは、言い回しが検索と違うため。
    ys = suggests(words + ["なぜ", "なぜ 日本"], youtube=True)
    return ns + hs + ss + ys

# -*- coding: utf-8 -*-
"""ニュースと検索トレンドから「なぜが立つ」題材の候補を拾う。

使い方:
    python scripts/gather.py                      # 画面に出すだけ
    python scripts/gather.py --out research/candidates/20261006.json

拾った見出しに ○× を付けるのはユーザー。ここは番号を振って並べるところまで。
"""
from __future__ import annotations

import argparse
import json
import sys
import urllib.error
import urllib.request
import xml.etree.ElementTree as ET
from datetime import datetime

FEEDS: dict[str, str] = {
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

# 「なぜが立つ」の芽。重みは、理由が説明されないまま流れやすい順
SIGNALS: dict[str, tuple[int, list[str]]] = {
    "異質":   (3, ["日本だけ", "世界初", "唯一", "異例", "初めて", "世界一", "日本以外"]),
    "増減":   (2, ["過去最多", "過去最少", "過去最高", "過去最低", "急増", "急減", "最多", "最少",
                   "相次ぐ", "激減", "半減", "倍増"]),
    "消える": (2, ["倒産", "廃業", "撤退", "打ち切り", "閉店", "終了", "撤去", "廃止", "休止"]),
    "値動き": (2, ["値上げ", "値下げ", "高騰", "急騰", "暴落", "下落", "最高値", "最安値", "赤字"]),
    "制度":   (2, ["改正", "新制度", "義務化", "規制", "控除", "減税", "増税", "給付", "補助金",
                   "解禁", "認可", "基準"]),
    "問い":   (1, ["なぜ", "背景", "理由", "わけ", "からくり", "仕組み"]),
}

# 扱わないもの（CLAUDE.md の「扱わないもの」に対応）
NG_WORDS = [
    "死去", "逝去", "訃報", "容疑者", "逮捕", "殺害", "殺人", "暴行", "強盗", "虐待",
    "不倫", "熱愛", "離婚", "破局", "結婚", "妊娠", "出産", "引退会見",
    "被害者", "遺体", "心肺停止", "炎上", "謝罪会見",
    "死亡", "重体", "重傷", "搬送", "安否", "行方不明", "遭難",
    # 医療・健康の助言になりうるもの
    "熱中症", "感染", "ワクチン", "がん", "認知症", "うつ病", "ダイエット",
]


def fetch(url: str, timeout: int = 20) -> list[tuple[str, str]]:
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 (danmen-gather)"})
    with urllib.request.urlopen(req, timeout=timeout) as res:
        root = ET.fromstring(res.read())
    out: list[tuple[str, str]] = []
    for item in root.iter("item"):
        title = (item.findtext("title") or "").strip()
        link = (item.findtext("link") or "").strip()
        if title:
            out.append((title, link))
    return out


def judge(title: str) -> tuple[int, list[str]]:
    """点と、当たった芽を返す。扱わないものは -1。"""
    if any(ng in title for ng in NG_WORDS):
        return -1, []
    points = 0
    hits: list[str] = []
    for kind, (weight, words) in SIGNALS.items():
        for word in words:
            if word in title:
                points += weight
                hits.append(f"{kind}:{word}")
                break
    return points, hits


def gather() -> list[dict]:
    seen: set[str] = set()
    rows: list[dict] = []
    for cat, url in FEEDS.items():
        try:
            items = fetch(url)
        except (urllib.error.URLError, ET.ParseError, TimeoutError) as err:
            print(f"  （{cat} は取れず: {type(err).__name__}）", file=sys.stderr)
            continue
        for title, link in items:
            if title in seen:
                continue
            seen.add(title)
            points, hits = judge(title)
            if points > 0:
                rows.append({"cat": cat, "title": title, "score": points,
                             "hits": hits, "link": link})
    rows.sort(key=lambda r: (-r["score"], r["cat"]))
    print(f"■ 読んだ見出し {len(seen)} 件", file=sys.stderr)
    return rows


def main() -> int:
    parser = argparse.ArgumentParser(description="「なぜが立つ」題材の候補を拾う")
    parser.add_argument("--out", help="控えを書く先（JSON）")
    parser.add_argument("--limit", type=int, default=20, help="画面に出す数（既定: 20）")
    args = parser.parse_args()

    rows = gather()
    print(f"\n■ {datetime.now():%Y-%m-%d %H:%M}　候補 {len(rows)} 件\n")
    for i, row in enumerate(rows[:args.limit], 1):
        print(f"{i:>2}. [{row['cat']}] {row['title']}")
        print(f"     芽: {' / '.join(row['hits'])}")
    if args.out:
        with open(args.out, "w", encoding="utf-8") as fp:
            json.dump(rows, fp, ensure_ascii=False, indent=2)
        print(f"\n控え: {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

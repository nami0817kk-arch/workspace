"""数字を取る口（2026-09-08）。選手・クラブのページの表を、そのまま文字に起こす。

ユーザー「中身のボリュームで負けている」。stats の群（11サイト）はあるのに使う
道具が無く、今日のプレミア移籍はブラウザで手で写した。
実測（同日）: transfermarkt.jp は素の GET で 200・表32個。fbref / sofascore /
worldfootball は 403、understat は表無し。**まず transfermarkt.jp を読む。**

表は要約せず、行ごとにセルを「｜」で並べて材料に置く。数字の解釈は台本を書く側。
（src/stats.py は「これまで何を出したか」の振り返りで、別物）
"""

from __future__ import annotations

import html
import re
from dataclasses import dataclass, field
from urllib.parse import urlparse

import requests

UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) youtube-video-creation/1.0"
TIMEOUT = 25
MAX_TABLES = 30
MAX_ROWS = 40
MAX_CELL = 60          # これより長いセルはフォームや注記。数字の表には無い
READABLE = ("transfermarkt.jp", "transfermarkt.com", "transfermarkt.de",
            "transfermarkt.co.uk", "fotmob.com")


class NumbersError(RuntimeError):
    pass


@dataclass
class Table:
    caption: str
    rows: list[list[str]] = field(default_factory=list)


_TAG = re.compile(r"<[^>]+>")
_TABLE = re.compile(r"<table[^>]*>(.*?)</table>", re.S | re.I)
_ROW = re.compile(r"<tr[^>]*>(.*?)</tr>", re.S | re.I)
_CELL = re.compile(r"<t[hd][^>]*>(.*?)</t[hd]>", re.S | re.I)
_CAP = re.compile(r"<caption[^>]*>(.*?)</caption>|<h2[^>]*>(.*?)</h2>", re.S | re.I)


def _clean(fragment: str) -> str:
    text = html.unescape(_TAG.sub(" ", fragment))
    return re.sub(r"\s+", " ", text).strip()


def readable(url: str) -> bool:
    host = urlparse(url).netloc.lower()
    return any(host == h or host.endswith("." + h) for h in READABLE)


def fetch(url: str, session=None) -> str:
    if not readable(url):
        raise NumbersError(f"このサイトは素の取得で読めません（読めるのは {', '.join(READABLE)}）: {url}")
    client = session or requests
    resp = client.get(url, headers={"User-Agent": UA}, timeout=TIMEOUT)
    resp.raise_for_status()
    if resp.encoding in (None, "ISO-8859-1"):
        resp.encoding = resp.apparent_encoding
    return resp.text


def parse(page: str) -> list[Table]:
    """ページの表を全部、行と列の文字に起こす。空の表と1行の表は落とす。"""
    tables: list[Table] = []
    for found in _TABLE.finditer(page):
        body = found.group(1)
        rows: list[list[str]] = []
        for row in _ROW.findall(body):
            cells = [_clean(c) for c in _CELL.findall(row)]
            cells = [c for c in cells if c]
            # 絞り込みのフォーム（国籍の一覧など）は1セルが数百字になる。数字の表の
            # セルは短い。長いセルを含む行は表ではない（2026-09-08 transfermarkt で実測）
            if cells and all(len(c) <= MAX_CELL for c in cells):
                rows.append(cells[:12])
        if len(rows) < 2:
            continue
        # 表の見出しは直前の caption / h2 から。無ければ1行目
        before = page[max(0, found.start() - 1500):found.start()]
        caps = [_clean(a or b) for a, b in _CAP.findall(before)]
        caption = caps[-1] if caps else " ".join(rows[0])[:60]
        tables.append(Table(caption=caption[:80], rows=rows[:MAX_ROWS]))
        if len(tables) >= MAX_TABLES:
            break
    return tables


def render(url: str, tables: list[Table]) -> str:
    lines = [f"## 数字（表）: {urlparse(url).netloc}", f"- {url}", ""]
    if not tables:
        lines.append("（表が取れませんでした）")
    for table in tables:
        lines.append(f"### {table.caption}")
        for row in table.rows:
            lines.append("- " + "｜".join(row))
        lines.append("")
    return chr(10).join(lines)

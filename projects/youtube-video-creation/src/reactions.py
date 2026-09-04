"""まとめサイトのスレッドから、書き込みを取り出して数える。

**「多い」と言うには数える。**CLAUDE.md の「数を数えた言い方をしない」は、
数えていなかったから置いた決まりで、数えれば言える（2026-09-04 に方針変更）。

引用するのは数件にとどめる。スレ全体を写すのは引用ではないし、画面にも載らない。
どの発言も出どころ（スレのURLとレス番号）が分かる形でしか使わない。
"""

from __future__ import annotations

import re
from dataclasses import dataclass

import requests

UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) youtube-video-creation/1.0"
TIMEOUT = 30

# レスの頭。「172: 名無しさん＠恐縮です 2026/09/03(木) 13:12:02.99 ID:Vm65lWHc0」
HEAD = re.compile(
    r"^(?P<no>{d}{{1,4}}):{s}*(?P<name>[^{n}]{{0,40}}?){s}*"
    r"(?P<date>{d}{{4}}/{d}{{2}}/{d}{{2}}[^{n}]*?ID:[{w}/+.-]+)$".format(
        d=chr(92) + "d", s=chr(92) + "s", n=chr(92) + "n", w=chr(92) + "w"
    )
)
NOISE = ("adsbygoogle", "http", "以下は「", "このまとめのまとめ", "スポンサーリンク")


@dataclass
class Post:
    no: int
    text: str

    @property
    def short(self) -> str:
        return self.text if len(self.text) <= 40 else self.text[:39] + "…"


class ReactionError(Exception):
    pass


def fetch(url: str, session=None) -> list[Post]:
    """スレのまとめページから書き込みを取り出す。"""
    client = session or requests
    try:
        response = client.get(url, headers={"User-Agent": UA}, timeout=TIMEOUT)
        response.raise_for_status()
    except requests.RequestException as error:
        raise ReactionError(f"開けません: {error}") from error
    return parse(response.text)


def parse(html: str) -> list[Post]:
    """HTML から書き込みだけを取り出す。整形はここに閉じ込める。"""
    text = re.sub(r"<(script|style)[^>]*>.*?</$1>".replace("$1", chr(92) + "1"), " ", html, flags=re.S | re.I)
    text = re.sub(r"<br[^>]*>", chr(10), text, flags=re.I)
    text = re.sub(r"<[^>]+>", chr(10), text)
    text = (text.replace("&gt;", ">").replace("&lt;", "<")
                .replace("&amp;", "&").replace("&nbsp;", " ").replace("&quot;", '"'))

    lines = [line.strip() for line in text.split(chr(10))]
    posts: list[Post] = []
    number: int | None = None
    buffer: list[str] = []

    def flush() -> None:
        if number is None:
            return
        body = " ".join(buffer).strip()
        body = re.sub(r">>{d}+".format(d=chr(92) + "d"), "", body).strip()
        body = re.sub(r"{s}+".format(s=chr(92) + "s"), " ", body)
        if _usable(body):
            posts.append(Post(no=number, text=body))

    index = 0
    while index < len(lines):
        line = lines[index]
        head = _head_at(lines, index)
        if head is not None:
            flush()
            number, buffer = head[0], []
            index = head[1]
            continue
        if number is not None and line:
            buffer.append(line)
        index += 1
    flush()

    seen: set[str] = set()
    unique: list[Post] = []
    for post in posts:
        if post.text in seen:
            continue
        seen.add(post.text)
        unique.append(post)
    return unique


def _head_at(lines: list[str], index: int) -> tuple[int, int] | None:
    """行が「番号 / 名前 / 日時+ID」の3行組なら、レス番号と次の位置を返す。"""
    line = lines[index]
    match = re.fullmatch(r"({d}{{1,4}}):".format(d=chr(92) + "d"), line)
    if not match:
        return None
    tail = lines[index + 1 : index + 4]
    if not any("ID:" in item for item in tail):
        return None
    for offset, item in enumerate(tail):
        if "ID:" in item:
            return int(match.group(1)), index + 2 + offset
    return None


def _usable(body: str) -> bool:
    if not 4 <= len(body) <= 120:
        return False
    return not any(word in body for word in NOISE)


def tally(posts: list[Post], words: dict[str, tuple[str, ...]]) -> dict[str, int]:
    """言葉ごとに何件あったかを数える。**言い切るための根拠にする。**"""
    counts = {label: 0 for label in words}
    for post in posts:
        for label, keys in words.items():
            if any(key in post.text for key in keys):
                counts[label] += 1
    return counts

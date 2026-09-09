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


# 題材名でスレを探せるまとめサイト（2026-09-08）。livedoor 系は /search?q= が
# 素の HTML で返る（4サイトとも実測で 200・記事リンク 11〜31 件）。
# 今日の新6本のうち4本で反応が0件だったのは、スレのURLを人が見つけた回しか
# 反応が入らない仕組みだったから
SEARCH_SITES = ("sakarabo.blog.jp", "sakasaka10.blog.jp",
                "footballnet.2chblog.jp", "samuraigoal.doorblog.jp")
_ARCHIVE = r'https?://{host}/archives/\d+\.html'


def find(query: str, session=None, per_site: int = 3) -> list[tuple[str, str]]:
    """題材名でまとめサイトを検索し、(記事URL, 題名) を新しい順に近い並びで返す。

    見出しに題材の語が入っているものを優先する。検索結果ページはサイトごとに
    作りが違うので、記事URLと同じ <a> の中の文字を題名として取る。
    """
    client = session or requests
    found: list[tuple[str, str]] = []
    words = [w for w in re.split(r"[\s　]+", query) if w]
    for host in SEARCH_SITES:
        try:
            resp = client.get(f"https://{host}/search?q={requests.utils.quote(query)}",
                              headers={"User-Agent": UA}, timeout=TIMEOUT)
            page = resp.text
        except Exception:  # noqa: BLE001 - 1サイト落ちても他を続ける
            continue
        pattern = re.compile(r'<a[^>]+href="(' + _ARCHIVE.format(host=re.escape(host))
                             + r')"[^>]*>([^<]{6,120})</a>')
        seen: set[str] = set()
        scored: list[tuple[int, int, str, str]] = []
        for url, title in pattern.findall(page):
            title = title.strip()
            if url in seen:
                continue
            seen.add(url)
            matched = sum(1 for w in words if w in title)
            if matched == 0:
                continue
            # 記事番号は新しいほど大きい。語が多く当たる順、同点なら新しい順
            number = int(re.search(r"/archives/(\d+)", url).group(1))
            scored.append((matched, number, url, title))
        scored.sort(key=lambda x: (x[0], x[1]), reverse=True)
        found += [(url, title) for _, _, url, title in scored[:per_site]]
    # **語が全部当たる記事があれば、それだけにする。**「プレミア 順位」で
    # 「プレミア」だけ当たる遠藤航のスレを選んでいた（2026-09-09 実測）
    full = [(u, t) for u, t in found if all(w in t for w in words)]
    return full if full else found


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

    # 空行は落としてから走査する。残したままだと「番号」と「ID:」の間に
    # 空行が入るサイトで見出しを取り逃がす（football-2ch で実測 2026-09-04）
    lines = [line.strip() for line in text.split(chr(10)) if line.strip()]
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
    """レスの頭なら、レス番号と本文が始まる位置を返す。

    まとめサイトによって書き方が違う（2026-09-04 実測）。

        footballnet   「172:」「名無しさん＠恐縮です」「2026/… ID:xxx」
        football-2ch  「1」「名前：」「ゴアマガラ ★」「：2026/… ID:xxx」

    共通しているのは**番号の行があり、数行以内に ID: の行が来る**こと。
    番号のうしろのコロンは、あってもなくてもよい扱いにする。
    """
    match = re.fullmatch(r"({d}{{1,4}}):?".format(d=chr(92) + "d"), lines[index])
    if not match:
        return None
    tail = lines[index + 1 : index + 5]
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


# 読み上げに回す1件の長さ（2026-09-07）。参考3チャンネルの実測は1件3.1秒で、
# 日本語の読み上げは約5.5字/秒なので 17字前後。切りのいいところまで許して30字。
# 2026-09-07 に30字から締めた。**実測は1件3.1秒＝約16字**で、30字（5.5秒）は
# 「2chまとめのテンポ」から外れる。落としすぎないよう20字にする
SAY_MAX = 20
# 参考チャンネルは「いいやつ」「ラヤいいな」のような4〜5字も読んでいた（実測）。
# 拾い損ねの1〜2字だけを落とす
SAY_MIN = 4


def say_lines(posts: list[Post], want: int = 12, limit: int = SAY_MAX) -> list[Post]:
    """**読み上げる**ぶんの反応を選ぶ。カードに載せる引用とは別。

    伸びているチャンネルは1件2〜4秒でぶつ切りに読み上げていた（実測19.2件）。
    長い書き込みは切らずに**落とす**。途中で切ると意味が変わり、
    「…」で終わる引用を推測で補わないという決まりにも反する。
    """
    picked: list[Post] = []
    for post in posts:
        body = post.text.strip()
        # 一文だけ取り出せるなら、そこまでを1件にする（長い連投を捨てないため）
        for mark in ("。", "!", "！", "?", "？"):
            head, sep, _ = body.partition(mark)
            if sep and SAY_MIN <= len(head) <= limit:
                body = head
                break
        if not SAY_MIN <= len(body) <= limit:
            continue
        picked.append(Post(no=post.no, text=body.rstrip("。")))
        if len(picked) >= want:
            break
    return picked

"""検索結果を候補ファイルの下書きにする。

これまでは検索結果を見ながら候補ファイルを手で書いていた。URLを写し間違えるし、
拾ったつもりで抜けることもある。タイトルとURLを貼れば行を組み立てる。

**見出しに書いてあることしか入れない。** 要約は使わない（要約は見出しに無い内容を
混ぜてくる。docs/news-sources.md 参照）。
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field

# 「タイトル<空白/タブ>URL」か、URLだけの行を拾う
URL = re.compile(r"https?://\S+")


@dataclass
class Hit:
    """検索結果の1件。"""

    title: str
    url: str
    site: str = ""
    posted_on: str = ""      # URLから日付が読めたとき
    number: int = 0          # 記事ID


def parse(text: str) -> list[Hit]:
    """貼り付けた検索結果を1件ずつに分ける。

    受け付ける形:
        見出し<タブか2つ以上の空白>https://...
        見出し
        https://...
        https://...        （URLだけ。見出しは後で書く）
    """
    hits: list[Hit] = []
    pending = ""

    for raw in text.splitlines():
        line = raw.strip().lstrip("-*・ ").strip()
        if not line:
            continue

        found = URL.search(line)
        if not found:
            pending = line
            continue

        # 全角の括弧や読点がURLの末尾にくっついてくる
        url = found.group(0).rstrip(').,、。）」』】>＞')
        title = line[: found.start()].strip(" \t-—|:：（(「『【<＜") or pending
        hits.append(Hit(title=title.strip(), url=url))
        pending = ""

    return hits


def enrich(hits: list[Hit], read) -> list[Hit]:
    """URLからサイト・日付・記事IDを埋める。read は freshness.read。"""
    for hit in hits:
        ref = read(hit.url)
        hit.site = ref.site
        hit.number = ref.number
        hit.posted_on = ref.posted_on.isoformat() if ref.posted_on else ""
    return hits


def slug(text: str, limit: int = 28) -> str:
    """見出しやURLから候補の id を作る。短く、英数字だけにする。

    数字だけの語は飛ばす。記事IDがそのまま id になっても意味がないため。
    """
    words = [w for w in re.findall(r"[A-Za-z0-9]+", text.lower()) if not w.isdigit()]
    if not words:
        return ""
    return "_".join(words[:3])[:limit].strip("_")


def group(hits: list[Hit], threshold: float = 0.45) -> list[list[Hit]]:
    """同じ話を報じた記事をまとめる。

    5媒体が同じ移籍を報じると、候補が5件に増えてしまう。動画は1本なので、
    まとめて1件にする。まとまったぶんは出典が増えるので、確度の裏付けになる。

    判定は見出しの語の重なり。人名とクラブ名が共通していれば同じ話とみなす。
    英語と日本語の記事は語が重ならないので、まとまらない（それでよい。
    どちらを使うかは書き手が決める）。
    """
    groups: list[list[Hit]] = []
    for hit in hits:
        words = _words(hit)
        for bunch in groups:
            if _overlap(words, _words(bunch[0])) >= threshold:
                bunch.append(hit)
                break
        else:
            groups.append([hit])
    return groups


def _words(hit: Hit) -> set[str]:
    """見出しとURLから、話題を表す語だけを取り出す。"""
    text = f"{hit.title} {hit.url.rsplit('/', 2)[-1].replace('-', ' ')}"
    found = {
        w.lower()
        for w in re.findall(r"[A-Za-z]{3,}", text)
        if w.lower() not in NOISE and w.lower() not in GENERIC
    }
    # 日本語は語に切れないので、カタカナと漢字の並びをそのまま拾う
    found |= {w for w in re.findall(r"[ァ-ヴー]{3,}|[一-龠]{2,}", text)}
    return found


def _overlap(left: set[str], right: set[str]) -> float:
    """共通の語の割合。少ないほうを分母にする（見出しの長さの差を吸収）。"""
    if not left or not right:
        return 0.0
    return len(left & right) / min(len(left), len(right))


def to_yaml(hits: list[Hit], date_label: str, merge: bool = True) -> str:
    """候補ファイルの下書き。判断が要るところは空にして残す。

    merge=True なら同じ話をまとめて1件にし、出典を並べる。
    """
    bunches = group(hits) if merge else [[hit] for hit in hits]

    lines = [
        f"# 候補テーマ（{date_label}）",
        "# collect が作った下書き。見出しに書いてあることだけが入っている。",
        "# tier / topic / league は判断が要るので、目で見て埋めること。",
        f'date: "{date_label}"',
        "candidates:",
    ]
    for index, bunch in enumerate(bunches, start=1):
        head = bunch[0]
        key = _from_url(head.url) or slug(head.title) or f"c{index}"
        english = next((english_words(hit.url) for hit in bunch if english_words(hit.url)), "")

        lines += [
            f"  - id: {key}",
            f"    title: {_title_line(head.title)}",
            '    topic: ""          # 話題のまとまり。同じ topic は1日1枠まで',
            '    league: ""         # england/spain/germany/italy/france/netherlands/japan',
            "    kind: transfer",
            _tier_line(head.title),
            f"    en: {_quote(english)}" + ("            # URLから作った。合っているか見る"
                                            if english else "            # 英語サイトを引く語"),
            f"    url: {head.url}",
        ]
        if head.posted_on:
            lines.append(f"    # 公開日: {head.posted_on}（URLから読めた）")
        if len(bunch) > 1:
            lines.append(f"    # 同じ話を {len(bunch)}媒体が報じている")

        lines.append("    sources:")
        for hit in bunch:
            lines.append(f"      - {hit.url}")
        for hit in bunch[1:]:
            lines.append(f"      # ↑ {hit.title[:60]}")
        lines.append("")
    return "\n".join(lines) + "\n"


def _tier_line(title: str) -> str:
    guess = guess_tier(title)
    if guess:
        return f"    tier: {guess}           # 見出しの言い回しからの当たり。見て直す"
    return "    tier: 報道           # 見出しから判断できず。確定/報道/未確認 に直す"


def english_words(url: str, limit: int = 4) -> str:
    """記事URLから英語の検索語を作る。

    記事URLのスラッグには選手名とクラブ名が入っている。
    transfer / news / latest のような、どの記事にも入る語は落とす。
    残りが2語に満たなければ当てにならないので空を返す（手で書くほうが早い）。
    """
    parts = [p for p in url.split("?")[0].rstrip("/").split("/") if p]
    words: list[str] = []
    for part in reversed(parts[-3:]):
        for word in re.findall(r"[A-Za-z]+", part.replace("-", " ").replace("_", " ")):
            lower = word.lower()
            if len(lower) < 3 or lower in NOISE or lower in GENERIC or lower in words:
                continue
            words.append(lower)
        if len(words) >= limit:
            break

    if len(words) < 2:
        return ""
    return " ".join(word.capitalize() for word in words[:limit])


# 見出しの言い回しから確度の当たりをつける。上から順に見て、最初に当たったもの。
# あくまで当たりで、決めるのは書き手。公式サイトの記事は別途 official 群で判断する
TIER_HINTS: list[tuple[str, tuple[str, ...]]] = [
    ("未確認", (
        "rumour", "rumor", "linked with", "eyeing", "monitoring", "interested in",
        "could", "may ", "reportedly", "paper talk", "gossip",
        "の噂", "浮上", "関心", "候補に", "とみられる", "か？", "可能性",
    )),
    ("確定", (
        "official", "confirmed", "completes", "complete signing", "have signed",
        "signs for", "announce", "statement", "unveiled",
        "公式発表", "正式発表", "発表", "決定", "完全移籍が", "合意に達し",
    )),
    ("報道", (
        "understand", "sources", "agreed", "set to", "close to", "in talks",
        "と報じ", "報道", "伝えられ", "明かした", "語った", "との情報",
    )),
]


# 語ではなく形で分かるもの
TIER_SHAPES: list[tuple[str, re.Pattern]] = [
    # スコアが入っていれば試合結果。点数は事実
    ("確定", re.compile(r"\b\d{1,2}\s*[-–:]\s*\d{1,2}\b")),
    # 疑問形は分析・観測記事。事実の報道ではない
    ("未確認", re.compile(r"[?？]\s*$|^(?:does|is|will|can|should|why|who|what)\b", re.I)),
]


def guess_tier(title: str) -> str:
    """見出しから確度の当たりをつける。分からなければ空。

    「公式発表」と「〜と報じられている」と「〜か？」では確度がまるで違う。
    見出しに出ている言い回しは、その記事がどの段階かをよく表している。
    ただし当たりでしかないので、書き手が見て直す前提にする。
    """
    text = (title or "").strip()
    lowered = text.lower()

    for tier, words in TIER_HINTS:
        if any(word.lower() in lowered for word in words):
            return tier
    for tier, shape in TIER_SHAPES:
        if shape.search(text):
            return tier
    return ""


def _title_line(title: str) -> str:
    """見出しが拾えなかった行は、書くべき場所として空で残す。"""
    return _quote(title) if title else '""          # 見出しを書く'


# 英語キーワードにすると邪魔になる語。記事URLにほぼ必ず入る
NOISE = {
    "transfer", "news", "latest", "update", "updates", "report", "reports",
    "exclusive", "official", "deal", "move", "signs", "sign", "signing",
    "the", "and", "for", "with", "his", "her", "from", "who", "what", "why",
    "premier", "league", "football", "soccer", "match", "story", "article",
    "as", "is", "to", "of", "on", "in", "at", "he", "she", "it", "a", "an",
}

# URLに必ず入る、中身を表さない区切り。id にしても意味がない
GENERIC = {
    "report", "news", "article", "articles", "story", "index", "en", "jp", "post",
    "detail", "topteamtopics", "noticias", "soccer", "football", "match", "video",
}


def _from_url(url: str) -> str:
    """URLの人が読める部分から id を作る。

    数字だけの区切りと、report / news のような中身を表さない語は飛ばす。
    """
    parts = [p for p in url.split("?")[0].rstrip("/").split("/") if p]
    for part in reversed(parts[-3:]):
        key = slug(part.replace("-", " ").replace(".html", ""))
        if key and key not in GENERIC:
            return key
    return ""


def _quote(text: str) -> str:
    """YAML に入れて壊れない形にする。"""
    body = text.replace('"', "'").strip()
    return f'"{body}"' if body else '""'

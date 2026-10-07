"""台本の文体の点検（10-08 ユーザー指示）。読み上げの声で目立つ「AIらしさ」を数えて知らせる（止めない）。

伸びている歴史の長尺18本の調べ（research/benchmark_long.md）で、嫌われるもののいちばん上が
「AIらしい不自然な日本語」だった。合成音声は同じ語尾・同じ言い回しが続くと、文字で読むよりずっと目立つ。

数えるもの：
- 同じ語尾の連続：剣崎の文末（〜です。〜ました。〜ます。…）が同じ形で続く
- 同じ言い回しの繰り返し：1本の中で同じ言い回しが何度も出る（「と言われています」）
- 硬い・書き言葉の語：話し言葉で浮く語（「〜である」「〜における」「すなわち」）
- つむぎの返しの頭：「え、」「へえ、」で始まる返しが1節に何度も
- 長すぎる文：読点の多い文は、耳で追えない

しきい値は 10-08 に既存の6本（cixi・kira・akechi・nobunaga・sakoku・napoleon）に掛けて決めた。
"""
from __future__ import annotations

import re
from collections import Counter

from .voice import display_text

HOST = "語り"
LISTENER = "聞き"

ENDING_RUN = 4           # 剣崎の同じ語尾がこの数だけ続いたら知らせる（文単位。つむぎの短い返しを挟んでも数え続け、節で数え直す）
PHRASE_LEN = 8           # この字数以上の言い回しを数える
PHRASE_TIMES = 4         # 1本の中でこの回数以上出たら知らせる
PHRASE_SHOW = 5          # 知らせる言い回しの数の上限（多い順）
HEAD_TIMES = 3           # つむぎの返しが「え、」「へえ、」で始まるのが1節にこの回数以上
COMMAS_MAX = 5           # 1文の読点がこの数以上なら長い（4つだと6本で4〜15か所出て多すぎた。10-08）
COMMAS_LONG = 4          # 読点がこの数で、
LONG_CHARS = 60          # この字数以上の文も長いと数える

# 文末の形。長いものから当てる（「でした」を「た」と数えない）
ENDINGS = ("でしょうか", "でしょう", "ですよね", "ですね", "ですか", "でした", "ました", "ません", "です", "ます")
_END_RE = re.compile("(" + "|".join(ENDINGS) + r")$")
# 話し言葉で浮く語（書き言葉・論文の言い方）。読みが同じでも、話し言葉の言い換えがあるもの
STIFF = (
    # 「まであった」「手であり」の「で」は数えない（10-08、吉良の回の「言い回しまであった」）
    ("である", r"(?<![まて])である(?![かう])"), ("であった", r"(?<![まて])であった"), ("であり", r"(?<![まて])であり(?!ま)"),
    ("における", r"における"), ("において", r"において"), ("とされる", r"とされる"), ("とされた", r"とされた"),
    ("とされて", r"とされて"), ("に関して", r"に関して"), ("に関する", r"に関する"), ("すなわち", r"すなわち"),
    ("なお、", r"(?:^|[。、])なお、"), ("および", r"および|及び"), ("ならびに", r"ならびに|並びに"),
    ("かつ", r"(?:^|、)かつ(?!て)"),
    ("〜ものの", r"ものの(?=、)"), ("〜にて", r"(?<![よ])にて(?=[、。]|$)"), ("〜につき", r"につき(?=[、。])"),
    ("〜のみ", r"(?<![の])のみ(?=[、。でがをはにと]|$)"), ("〜ゆえ", r"(?<!ゆ)ゆえ(?:に)?(?=[、。])"),
    ("〜であろう", r"であろう"), ("〜せねば", r"せねば"), ("〜し得る", r"し得る|しうる"),
)
_STIFF = [(name, re.compile(p)) for name, p in STIFF]
_HEAD = re.compile(r"^(?:え|えっ|ええ|えー|へえ|へー|へぇ|ええっ)(?:[、！？!?…ー]|$)")
_QUOTE = re.compile(r"「[^」]*」|『[^』]*』|（[^）]*）")


def _plain(text: str) -> str:
    return display_text(text).strip()


def sentences(text: str) -> list[str]:
    """文に分ける（「」の中の句点では切らない）。"""
    t = _plain(text)
    out, cur, depth = [], "", 0
    for ch in t:
        cur += ch
        if ch in "「『":
            depth += 1
        elif ch in "」』":
            depth = max(0, depth - 1)
        elif ch in "。！？!?" and depth == 0:
            out.append(cur)
            cur = ""
    if cur.strip():
        out.append(cur)
    # 「！」「？」の連なり（「えっ！？」）は前の文にまとめる
    merged: list[str] = []
    for s in out:
        if merged and re.fullmatch(r"[。！？!?」』…]+", s):
            merged[-1] += s
        else:
            merged.append(s)
    return [s for s in merged if s.strip()]


def ending_of(sentence: str) -> str | None:
    s = re.sub(r"[。！？!?…」』）\s]+$", "", sentence)
    m = _END_RE.search(s)
    return m.group(1) if m else None


def ending_runs(script) -> list[str]:
    """剣崎の文末が同じ形で ENDING_RUN 回以上続いたところ。

    台本は1〜3文ずつつむぎと交互なので、剣崎の文だけを順に並べて数える（間につむぎ・人物の行があっても、
    剣崎の声は同じ語尾で戻ってくる）。節が替わると数え直す。10-08 に既存6本で、行の中だけで数えると0件、
    剣崎の文を通して数えると1本0〜3か所だった。
    """
    warns = []
    run, prev, start, sec = 0, None, None, None
    def flush():
        if run >= ENDING_RUN:
            warns.append(f"{start}行目から剣崎の文末「〜{prev}。」が{run}文続きます（言い切り・問い・体言止めを混ぜる）")
    for l in script.lines:
        if l.section != sec:
            flush()
            run, prev, sec = 0, None, l.section
        if l.speaker != HOST:
            continue
        for s in sentences(l.text):
            e = ending_of(s)
            if e is not None and e == prev:
                run += 1
            else:
                flush()
                run, prev, start = (1, e, l.index + 1) if e else (0, None, None)
    flush()
    return warns


def _phrase_text(l) -> str:
    """言い回しを数える文。人物の言葉の引用と「」の中（史料の文句）は外す。"""
    return _QUOTE.sub("／", _plain(l.text))


def repeated_phrases(script, names=()) -> list[str]:
    """同じ PHRASE_LEN 字以上の言い回しが PHRASE_TIMES 回以上。名前（人物・地名）だけのものは数えない。"""
    texts = [_phrase_text(l) for l in script.lines if l.speaker in (HOST, LISTENER)]
    for n in sorted((n for n in names if len(n) >= 2), key=len, reverse=True):   # 名前は言い回しに数えない（「アントワネットが」）
        texts = [t.replace(n, "／") for t in texts]
    count: Counter = Counter()
    for t in texts:
        seen = set()
        for chunk in re.split(r"[／。！？!?]", t):
            for i in range(len(chunk) - PHRASE_LEN + 1):
                g = chunk[i:i + PHRASE_LEN]
                if g not in seen:
                    seen.add(g)
                    count[g] += 1
    hits = {g: n for g, n in count.items() if n >= PHRASE_TIMES and not _is_name(g, names)
            and not re.fullmatch(r"[^ぁ-ん]*", g)}          # 仮名の無いもの（固有名・年号の並び）は外す
    # つながる8字の並びは1つの言い回しにまとめる（「と言われていま」「言われています」→「と言われています」）
    phrases = _merge(hits, texts)
    phrases = [(p, n) for p, n in phrases if not _fixed(p)]
    phrases.sort(key=lambda x: (-x[1], -len(x[0])))
    return [f"同じ言い回し「{p}」が{n}回（{PHRASE_TIMES}回以上は耳に残る。言い換えるか削る）" for p, n in phrases[:PHRASE_SHOW]]


FIXED = ("今日の地層は、ここまでです", "また一緒に、掘りましょう")   # 決まった締めの言葉は数えない


def _fixed(p: str) -> bool:
    return any(p in f or f in p for f in FIXED)


def _is_name(g: str, names) -> bool:
    return any(g in n or n in g for n in names if len(n) >= 3)


def _merge(hits: dict, texts: list[str]) -> list[tuple[str, int]]:
    out: list[tuple[str, int]] = []
    used = set()
    for g in sorted(hits, key=lambda x: -hits[x]):
        if g in used:
            continue
        # 左右に伸ばせるだけ伸ばす（回数が同じ並びだけ）
        p = g
        grown = True
        while grown:
            grown = False
            for h in hits:
                if h in used or h == p or hits[h] != hits[g]:
                    continue
                if p.endswith(h[:-1]) and not p.endswith(h):
                    p, grown = p + h[-1], True
                elif p.startswith(h[1:]) and not p.startswith(h):
                    p, grown = h[0] + p, True
        n = sum(1 for t in texts if p in t)
        if n >= PHRASE_TIMES:
            out.append((p, n))
        for h in hits:
            if h in p:
                used.add(h)
    return out


def stiff_words(script) -> list[str]:
    """話し言葉で浮く書き言葉の語。人物の言葉の行と「」の中（史料の引用）は数えない。"""
    found: dict[str, list[int]] = {}
    for l in script.lines:
        if l.speaker not in (HOST, LISTENER):
            continue
        t = _QUOTE.sub("／", _plain(l.text))
        for name, rx in _STIFF:
            if rx.search(t):
                found.setdefault(name, []).append(l.index + 1)
    return [f"書き言葉の「{name}」{len(rows)}か所 {rows[:8]}（話し言葉に言い換える）" for name, rows in found.items()]


def listener_heads(script) -> list[str]:
    """つむぎの返しが「え、」「へえ、」で始まるのが1節に HEAD_TIMES 回以上。"""
    warns = []
    for sec in script.sections:
        rows = [l.index + 1 for l in script.lines
                if l.section == sec.index and l.speaker == LISTENER and _HEAD.match(_plain(l.text))]
        if len(rows) >= HEAD_TIMES:
            warns.append(f"{sec.index + 1}節：つむぎの返しが「え」「へえ」で{len(rows)}回始まります {rows}（頭を変えるか、頭を落とす）")
    return warns


def long_sentences(script) -> list[str]:
    """読点が COMMAS_MAX 個以上か、COMMAS_LONG 個で LONG_CHARS 字以上の文（耳で追えない）。"""
    rows = []
    for l in script.lines:
        if l.speaker not in (HOST, LISTENER):
            continue
        if any(is_long(s) for s in sentences(l.text)):
            rows.append(l.index + 1)
    if not rows:
        return []
    return [f"読点の多い長い文が{len(rows)}か所 {rows[:10]}{'…' if len(rows) > 10 else ''}"
            f"（読点{COMMAS_MAX}つ以上か、{COMMAS_LONG}つで{LONG_CHARS}字以上。2文に分ける）"]


def is_long(sentence: str) -> bool:
    bare = _QUOTE.sub("", sentence)
    n = bare.count("、")
    return n >= COMMAS_MAX or (n >= COMMAS_LONG and len(sentence) >= LONG_CHARS)


def notes(script, names=()) -> list[str]:
    """文体の点検の結果（知らせるだけ）。頭に「文体：」を付けて返す。"""
    out = ending_runs(script) + repeated_phrases(script, names) + stiff_words(script) + listener_heads(script) \
        + long_sentences(script)
    return ["文体：" + w for w in out]

"""字幕の切り分け・折り返し・強調の色分け。本編・ショート・SRT で同じ切り方を使う。"""
from __future__ import annotations

import re

NO_HEAD = "、。，．・！？!?」』）)ーっゃゅょッャュョ…》"   # 行の頭に来てはいけない文字
SUB_CHARS = 40          # 字幕1枚に入れる字数の目安（2行ぶん）
MIN_CHUNK = 6           # これより短いかたまりは前に寄せる（「。」だけの字幕を出さない）
GOOD_BREAK = "、。！？」がのをにはでとも"   # 2行に割るとき、この字の後ろで切ると読みやすい

_EMPH = re.compile(r"《(.+?)》")


def _split_sentences(text: str) -> list[str]:
    """。！？で切る。ただし「」の中では切らない。"""
    out, cur, depth = [], "", 0
    for ch in text:
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
    return out


def chunks(text: str, limit: int = SUB_CHARS) -> list[str]:
    """字幕を1枚 limit 字までのかたまりに分ける（《》はそのまま残す。字数には数えない）。"""
    plain_len = lambda s: len(_EMPH.sub(r"\1", s))
    pieces: list[str] = []
    for sent in _split_sentences(text):
        if plain_len(sent) <= limit:
            pieces.append(sent)
            continue
        cur = ""
        for part in re.split(r"(?<=、)", sent):
            if cur and plain_len(cur) + plain_len(part) > limit:
                pieces.append(cur)
                cur = part
            else:
                cur += part
        if cur:
            pieces.append(cur)
    merged: list[str] = []
    for p in pieces:
        if merged and (plain_len(p) < MIN_CHUNK or plain_len(merged[-1]) + plain_len(p) <= limit):
            merged[-1] += p
        else:
            merged.append(p)
    return merged or [text]


def plain(text: str) -> str:
    return _EMPH.sub(r"\1", text)


def emphasis_mask(text: str) -> tuple[str, list[bool]]:
    """《》を外した文字列と、1文字ずつの「強調かどうか」。"""
    out, mask, pos = [], [], 0
    for m in _EMPH.finditer(text):
        before = text[pos:m.start()]
        out.append(before)
        mask += [False] * len(before)
        out.append(m.group(1))
        mask += [True] * len(m.group(1))
        pos = m.end()
    out.append(text[pos:])
    mask += [False] * len(text[pos:])
    return "".join(out), mask


def wrap(text: str, font, width: int) -> list[str]:
    """幅で折り返す。「／」は必ず改行。句読点や閉じかっこは行の頭に置かず、前の行に残す。"""
    out: list[str] = []
    for para in text.split("／"):
        cur = ""
        for ch in para:
            if font.getlength(cur + ch) > width and cur and ch not in NO_HEAD:
                out.append(cur)
                cur = ch
            else:
                cur += ch
        if cur:
            out.append(cur)
    return out


def wrap_balanced(text: str, font, width: int) -> list[str]:
    """2行になるときは、なるべく同じ長さで、読みやすい切れ目（読点や助詞の後ろ）で割る。"""
    rows = wrap(text, font, width)
    if len(rows) != 2 or "／" in text:
        return rows
    best, best_score = rows, None
    mid = len(text) / 2
    for i in range(1, len(text)):
        a, b = text[:i], text[i:]
        if b[0] in NO_HEAD or font.getlength(a) > width or font.getlength(b) > width:
            continue
        score = abs(i - mid) - (6 if text[i - 1] in GOOD_BREAK else 0)
        if best_score is None or score < best_score:
            best, best_score = [a, b], score
    return best

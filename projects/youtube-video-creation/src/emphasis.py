"""テロップの中で、どこが大事かを画面に言わせる（2026-09-15）。

**きっかけ。**ユーザーから「動画編集もレベルアップさせていく必要があるかなー」。
`render._draw_telop` を読み直したら、**強調する仕組みが1つも無かった。**

    開幕からの未勝利が4試合になりました

「4試合」も「未勝利」も「が」も、画面の上では同じ白・同じ大きさで並ぶ。
**どこが大事かを画面が何も言っていない。**

**動きでは解かない。**`telop_in` と `scene_fade` は 2026-09-14 に
ユーザー指摘（「出た瞬間に止まって見えた」「前後のテロップが重なって
二重に見えた」「一瞬暗転する」）で 0 にしてある。あれは一度やって、
見え方が悪くて切ったもの。**ここは字の話なので、ちらつきは起きない。**

**書き方。**台本のテロップに `**` で囲むだけ。

    telop: 開幕からの未勝利が**4試合**になりました

**大きさは変えない。**変えると折り返しの計算が狂い、行の高さも揃わなくなる。
色と下線だけで差をつける。折り返しは囲みを外した文字列で計算するので、
`**` を足しても行の割れ方は1文字も変わらない。
"""

from __future__ import annotations

import re

# `**…**` で囲む。**改行をまたがない**（テロップは2〜3行に折り返されるので、
# またぐ書き方を許すと下線をどこに引くか決められない）
MARK = re.compile(r"\*\*([^*\n]+?)\*\*")


def split(text: str) -> tuple[str, list[tuple[int, int]]]:
    """`**` を外した文字列と、強調する範囲を返す。

    範囲は**外したあとの文字列に対する** (始まり, 終わり) で、
    終わりは含まない。囲みが1つも無ければ、範囲は空のまま返る。

        >>> split("未勝利が**4試合**になりました")
        ('未勝利が4試合になりました', [(4, 7)])
    """
    if not text or "**" not in text:
        return text or "", []

    plain: list[str] = []
    spans: list[tuple[int, int]] = []
    at = 0
    length = 0
    for hit in MARK.finditer(text):
        before = text[at:hit.start()]
        plain.append(before)
        length += len(before)
        inner = hit.group(1)
        spans.append((length, length + len(inner)))
        plain.append(inner)
        length += len(inner)
        at = hit.end()
    plain.append(text[at:])
    return "".join(plain), spans


def strip(text: str) -> str:
    """囲みを外した文字列だけ。

    **画面以外へ渡すときは必ずこれを通す。**字幕・概要欄・サムネイル・
    読み上げに `**` が漏れると、読み上げなら「アスタリスク」と発音され、
    字幕なら聞こえた音と食い違う。
    """
    return split(text)[0]


def marked(text: str) -> bool:
    """囲みが1つでもあるか。"""
    return bool(text) and bool(MARK.search(text))


def spans_in(line: str, offset: int, spans: list[tuple[int, int]]) -> list[tuple[int, int]]:
    """折り返した1行ぶんに掛かる範囲を、その行の中の位置に直す。

    `offset` はその行が、囲みを外した全文の何文字目から始まるか。
    行をまたぐ範囲は、行ごとに切って返す（`**` は改行をまたげないが、
    **折り返しは文字数で入るので、囲みの途中で行が変わることはある**）。
    """
    out: list[tuple[int, int]] = []
    end_of_line = offset + len(line)
    for start, end in spans:
        lo, hi = max(start, offset), min(end, end_of_line)
        if lo < hi:
            out.append((lo - offset, hi - offset))
    return out

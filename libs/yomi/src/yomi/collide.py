"""③ 読み替え辞書の巻き込み。

辞書のキーが、もっと長い語の一部として当たり（「露: つゆ」が「披露」に）、置き換えの前後でその語の読み（fugashi）が
変わるものを知らせる。キーの頭が語の途中のときだけ見る（キーの終わりが語の途中なのは「都を落と」のような活用の切り方で、
わざとそうしている）。
"""
from __future__ import annotations

from dataclasses import dataclass

from .kana import norm, unvoice
from .morph import SYMBOL, available, tokens
from .replace import replacements


@dataclass
class Collision:
    key: str              # 辞書のキー
    word: str             # キーが一部として当たった、もっと長い語
    before: str           # その語の読み（置き換える前）
    after: str            # 置き換えたあとの読み
    label: str = ""


def _read(text: str) -> str:
    return norm("".join(t.reading or t.surface for t in tokens(text) if t.pos[0] not in SYMBOL), long=True)


def collisions(readings: dict[str, str], texts, strip=None) -> list[Collision]:
    """texts は (見出し, 文)。strip は文から読まない印を外す関数（《》など。省けばそのまま）。"""
    out: list[Collision] = []
    if not available():
        return out
    for label, text in texts:
        plain = strip(text) if strip else text
        reps = replacements(plain, readings)
        if not reps:
            continue
        toks = tokens(plain)
        for key, s, e in reps:
            over = [t for t in toks if t.start < e and t.end > s]
            if not over:
                continue
            ws, we = min(t.start for t in over), max(t.end for t in over)
            if ws == s:
                continue
            word = plain[ws:we]
            before = _read(word)
            after = _read(plain[ws:s] + readings[key] + plain[e:we])
            if before != after and unvoice(before) != unvoice(after):
                out.append(Collision(key, word, before, after, label))
    return out


def collision_lines(cols: list[Collision]) -> list[str]:
    """知らせの文（キーと長い語ごとに1件。当たった所を並べる）。"""
    groups: dict[tuple[str, str, str, str], list[str]] = {}
    for c in cols:
        groups.setdefault((c.key, c.word, c.before, c.after), []).append(c.label)
    out = []
    for (k, w, b, a), labels in groups.items():
        more = f"ほか{len(labels) - 4}か所" if len(labels) > 4 else ""
        out.append(f"読み替え辞書の「{k}」が「{w}」の中にも当たり、読みが変わります（{b}→{a}。"
                   f"{'・'.join(labels[:4])}{more}）。「{w}」を長い語として足す")
    return out

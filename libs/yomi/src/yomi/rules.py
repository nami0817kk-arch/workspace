"""② 読みが割れる語と、文脈で読みが決まる型。

一覧（lex.ambiguous）の語が1語として出た所を拾う。読み替え辞書で置き換えた所は、置き換えたあとの文にもう字が無いので数えない。
型（lex.rules）に当たった所は止める。ただしエンジンのカナがあり、型の正しい読み（want）で読めていれば止めない
（過去の回に流して、正しく読めている所を止めないことを確かめるため）。エンジンが無ければ確かめられないので止める。
"""
from __future__ import annotations

from dataclasses import dataclass

from .diff import segments
from .kana import norm
from .lexicon import Lexicon, default
from .morph import SYMBOL, Tok, tokens


def _match(t: Tok | None, cond: dict) -> bool:
    if t is None:
        return False
    if "any" in cond:
        return any(_match(t, c) for c in cond["any"])
    if "surface" in cond and t.surface not in [str(s) for s in cond["surface"]]:
        return False
    if "end" in cond and t.surface[-1:] not in str(cond["end"]):
        return False
    for k, idx in (("pos1", 0), ("pos2", 1), ("pos3", 2)):
        if k in cond:
            want = cond[k] if isinstance(cond[k], list) else [cond[k]]
            if t.pos[idx] not in want:
                return False
    return True


def _when(toks: list[Tok], i: int, spec) -> bool:
    if spec is None:
        return True
    for alt in (spec if isinstance(spec, list) else [spec]):
        if all(_match(toks[i + int(off)] if 0 <= i + int(off) < len(toks) else None, cond)
               for off, cond in alt.items()):
            return True
    return False


def rule_of(toks: list[Tok], i: int, lex: Lexicon | None = None) -> tuple[str, tuple[str, ...]] | None:
    """i 番目の語が型に当たるか。(型の名前, 正しい読みの候補)。"""
    lex = lex or default()
    t = toks[i]
    for r in lex.rules:
        if t.surface not in [str(s) for s in r.get("surface", [])]:
            continue
        if not _when(toks, i, r.get("when")):
            continue
        if r.get("unless") is not None and _when(toks, i, r["unless"]):
            continue
        return str(r["name"]), tuple(str(w) for w in r["want"])
    return None


@dataclass
class Hit:
    label: str            # 行の見出し（「12行目」など。呼ぶ側が決める）
    word: str             # 当たった語のまわり（置き換えたあとの文）
    char: str             # 割れる語
    rule: str | None      # 型の名前（None は一覧に出すだけ）
    want: tuple[str, ...]
    got: str | None       # エンジンの読み（カナが無ければ None）

    @property
    def ok(self) -> bool:
        """型に当たったが、エンジンが正しく読めている。"""
        return self.rule is not None and self.got is not None and norm(self.got, long=True) in {
            norm(w, long=True) for w in self.want}


def ambiguous_hits(label: str, text: str, kana: str | None, lex: Lexicon | None = None) -> list[Hit]:
    """置き換えたあとの文で、読みが割れる語を1語として使った所。"""
    lex = lex or default()
    toks = tokens(text)
    if not any(t.surface in lex.ambiguous for t in toks):
        return []
    seg: dict[int, str] = {}
    if kana is not None:
        toks, seg = segments(text, kana, lex)
    out = []
    for i, t in enumerate(toks):
        if t.surface not in lex.ambiguous:
            continue
        r = rule_of(toks, i, lex)
        lo = toks[i - 1].start if i > 0 and toks[i - 1].pos[0] not in SYMBOL else t.start
        hi = toks[i + 1].end if i + 1 < len(toks) and toks[i + 1].pos[0] not in SYMBOL else t.end
        out.append(Hit(label, text[lo:hi], t.surface, r[0] if r else None, r[1] if r else lex.ambiguous[t.surface],
                       seg.get(i) if kana is not None else None))
    return out

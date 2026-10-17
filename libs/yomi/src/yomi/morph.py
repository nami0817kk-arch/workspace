"""fugashi（UniDic）で文を語に切り、語ごとの読みを取る。入っていなければ available() が False。"""
from __future__ import annotations

from dataclasses import dataclass
from functools import lru_cache


@dataclass(frozen=True)
class Tok:
    surface: str
    start: int                 # 文の中の位置
    end: int
    reading: str | None        # 発音のカナ（UniDic の pron）。数字・記号・未知語は None
    pos: tuple[str, str, str]  # 品詞（大・中・小）
    kana: str | None = None    # 書きのカナ（UniDic の kana。「言う」は pron ユー・kana イウ、助詞「は」は ワ・ハ）


@lru_cache(maxsize=1)
def _tagger():
    try:
        import fugashi
        return fugashi.Tagger()
    except Exception:          # 入っていない・辞書が無い
        return None


def available() -> bool:
    return _tagger() is not None


def _clean(v):
    return None if v in (None, "*", "") else v


def tokens(text: str) -> list[Tok]:
    tagger = _tagger()
    if tagger is None:
        return []
    out, pos = [], 0
    for w in tagger(text):
        s = w.surface
        k = text.find(s, pos)
        if k < 0:
            k = pos
        f = w.feature
        out.append(Tok(s, k, k + len(s), _clean(getattr(f, "pron", None)),
                       (f.pos1 or "", f.pos2 or "", f.pos3 or ""), _clean(getattr(f, "kana", None))))
        pos = k + len(s)
    return out


SYMBOL = ("補助記号", "空白")

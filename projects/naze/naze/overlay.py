"""画面に重ねる字幕・見出し・地点の札・隅の表記(PIL)。

字幕の書き方: 改行は \\n、強調は【】、同じ行の中でページを分けるときは |(字数で時間を配分)。
"""
from __future__ import annotations

import re
from typing import List, Optional, Tuple

from PIL import Image, ImageDraw, ImageFont

from .config import FONT, W

WHITE = (255, 255, 255)
YEL = (255, 214, 64)
OCHRE = (236, 190, 100)
BLUE = (90, 180, 220)
RED = (240, 90, 80)
GREEN = (110, 220, 140)
NAVY = (8, 16, 36)
DIM = (220, 225, 235)

_fc = {}


def font(sz: int, path: str = FONT) -> ImageFont.FreeTypeFont:
    k = (path, sz)
    if k not in _fc:
        _fc[k] = ImageFont.truetype(path, sz)
    return _fc[k]


def parse(row: str) -> List[Tuple[str, bool]]:
    return [(p, i % 2 == 1) for i, p in enumerate(re.split(r"[【】]", row)) if p]


def _row_w(segs, f) -> float:
    return sum(f.getlength(t) for t, _ in segs)


def rows(dr: ImageDraw.ImageDraw, text: str, cy: float, size: int, maxw: int = 980, color=WHITE, hl=YEL, stroke: int = 8, cx: float = W / 2) -> None:
    """複数行を中央揃えで描く(はみ出すなら字を小さくする)。"""
    rs = [parse(r) for r in text.split("\n")]
    sz = size
    while max(_row_w(r, font(sz)) for r in rs) > maxw and sz > 20:
        sz -= 2
    f = font(sz)
    lh = int(sz * 1.3)
    y = cy - lh * len(rs) // 2
    for r in rs:
        x = cx - _row_w(r, f) / 2
        for t, h in r:
            dr.text((x, y), t, font=f, fill=hl if h else color, stroke_width=stroke, stroke_fill=NAVY)
            x += f.getlength(t)
        y += lh


def page_of(sub: str, t: float, start: float, end: float) -> str:
    pages = sub.split("|")
    if len(pages) == 1:
        return pages[0]
    n = [len(re.sub(r"[【】\n]", "", p)) for p in pages]
    frac = (t - start) / max(1e-6, end - start)
    acc = 0.0
    for p, k in zip(pages, n):
        acc += k / sum(n)
        if frac < acc:
            return p
    return pages[-1]


def current(lines: List[dict], t: float) -> Optional[dict]:
    """時刻 t に字幕を出す行(次の行が始まるまで前の行のまま)。"""
    cur = None
    for l in lines:
        if l["start"] <= t:
            cur = l
    return cur


def label(img: Image.Image, x: float, y: float, text: str, col, alpha: float, below: bool = False, size: int = 50) -> None:
    """地点の札(点 + 線 + 角丸の箱)。"""
    if alpha <= 0:
        return
    f = font(size)
    tw = f.getlength(text)
    cx = min(max(x, tw / 2 + 40), W - tw / 2 - 40)
    bh = size + 24
    if below:
        by0, by1, ly = y + 70, y + 70 + bh, y + 70
    else:
        by1, by0, ly = y - 70, y - 70 - bh, y - 70
    ov = Image.new("RGBA", img.size, (0, 0, 0, 0))
    od = ImageDraw.Draw(ov)
    a = int(255 * alpha)
    od.line([(x, y), (x, ly)], fill=(255, 255, 255, a), width=4)
    od.ellipse([x - 11, y - 11, x + 11, y + 11], fill=tuple(col) + (a,), outline=(255, 255, 255, a), width=4)
    od.rounded_rectangle([cx - tw / 2 - 22, by0, cx + tw / 2 + 22, by1], 16, fill=NAVY + (int(215 * alpha),), outline=tuple(col) + (a,), width=4)
    od.text((cx - tw / 2, by0 + 8), text, font=f, fill=tuple(col) + (a,))
    img.alpha_composite(ov)


def corner(dr: ImageDraw.ImageDraw, left: str = "", right: str = "", size: int = 30) -> None:
    f = font(size)
    if left:
        dr.text((36, 40), left, font=f, fill=DIM, stroke_width=4, stroke_fill=NAVY)
    if right:
        dr.text((W - 36 - f.getlength(right), 40), right, font=f, fill=DIM, stroke_width=4, stroke_fill=NAVY)


def band(img: Image.Image, y0: int, y1: int, alpha: float = 0.75) -> None:
    ov = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(ov).rectangle([0, y0, W, y1], fill=NAVY + (int(255 * alpha),))
    img.alpha_composite(ov)

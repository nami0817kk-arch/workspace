"""画面に重ねる字幕・見出し・地点の札・隅の表記(PIL)。

字幕の書き方: 改行は \\n、強調は【】、同じ行の中でページを分けるときは |(字数で時間を配分)。
"""
from __future__ import annotations

import re
from typing import List, Optional, Tuple

from PIL import Image, ImageDraw, ImageFont

from .config import FONT, LAYOUT, W

WHITE = (255, 255, 255)
YEL = (255, 214, 64)
OCHRE = (236, 190, 100)
BLUE = (90, 180, 220)
RED = (240, 90, 80)
GREEN = (110, 220, 140)
NAVY = (8, 16, 36)
DIM = (220, 225, 235)

_fc = {}
# 点検用: そのコマで描いた字の箱 [(種類, (x0, y0, x1, y1), 文字)]。frame_fn がコマの頭で空にする
BOXES: list = []


def font(sz: int, path: str = FONT) -> ImageFont.FreeTypeFont:
    k = (path, sz)
    if k not in _fc:
        _fc[k] = ImageFont.truetype(path, sz)
    return _fc[k]


def parse(row: str) -> List[Tuple[str, bool]]:
    return [(p, i % 2 == 1) for i, p in enumerate(re.split(r"[【】]", row)) if p]


def _row_w(segs, f) -> float:
    return sum(f.getlength(t) for t, _ in segs)


def rows(dr: ImageDraw.ImageDraw, text: str, cy: float, size: int, maxw: int = LAYOUT["maxw"], color=WHITE, hl=YEL, stroke: int = 8, cx: float = W / 2) -> None:
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
        BOXES.append(("text", (x - stroke, y - stroke, x + _row_w(r, f) + stroke, y + lh), "".join(t for t, _ in r), sz / size))
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
    if alpha > 0.5:
        BOXES.append(("label", (cx - tw / 2 - 22, min(by0, y), cx + tw / 2 + 22, max(by1, y)), text, 1.0))
    img.alpha_composite(ov)


def corner(dr: ImageDraw.ImageDraw, left: str = "", right: str = "", size: int = 30) -> None:
    f = font(size)
    if left:
        BOXES.append(("corner", (36, 40, 36 + f.getlength(left), 40 + size * 1.3), left, 1.0))
        dr.text((36, 40), left, font=f, fill=DIM, stroke_width=4, stroke_fill=NAVY)
    if right:
        BOXES.append(("corner", (W - 36 - f.getlength(right), 40, W - 36, 40 + size * 1.3), right, 1.0))
        dr.text((W - 36 - f.getlength(right), 40), right, font=f, fill=DIM, stroke_width=4, stroke_fill=NAVY)


def band(img: Image.Image, y0: int, y1: int, alpha: float = 0.75) -> None:
    ov = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(ov).rectangle([0, y0, W, y1], fill=NAVY + (int(255 * alpha),))
    img.alpha_composite(ov)


CTA_TEXT = "チャンネル登録と高評価、よろしくお願いします。"
THUMB = "\U0001F44D"
SYM_FONT = "C:/Windows/Fonts/seguisym.ttf"


def cta(img: Image.Image, t: float, band_y, size: int = 64) -> None:
    """結びのお願い: 帯の上に「チャンネル登録」と高評価のボタン。t はお願いの行が始まってからの秒。
    0.25 秒で現れ、1.2 秒で登録が「登録済み」に、1.6 秒で高評価の手が黄色になる。"""
    a = min(1.0, t / 0.25)
    y0, y1 = band_y
    band(img, y0, y1, 0.8 * a)
    dr = ImageDraw.Draw(img)
    cy = (y0 + y1) / 2
    rows(dr, "チャンネル登録と【高評価】\nよろしくお願いします", cy - (y1 - y0) * 0.2, size, stroke=8)
    f = font(int(size * 0.8))
    by = cy + (y1 - y0) * 0.2
    bh = int(size * 1.35)
    done = t > 1.2
    sub_t = "登録済み" if done else "チャンネル登録"
    sw = f.getlength(sub_t) + size * 1.0
    gap = size * 0.6
    tw = sw + gap + bh * 1.6
    x = W / 2 - tw / 2
    pop = 1.0 + 0.08 * max(0.0, 1 - abs(t - 1.2) / 0.15)
    ov = Image.new("RGBA", img.size, (0, 0, 0, 0))
    od = ImageDraw.Draw(ov)
    A = int(255 * a)
    w2 = sw * pop
    od.rounded_rectangle([x + sw / 2 - w2 / 2, by - bh / 2, x + sw / 2 + w2 / 2, by + bh / 2], bh // 2,
                         fill=((90, 90, 96) if done else (220, 30, 36)) + (A,))
    od.text((x + sw / 2 - f.getlength(sub_t) / 2, by - f.size * 0.62), sub_t, font=f, fill=(255, 255, 255, A))
    tx = x + sw + gap
    liked = t > 1.6
    od.rounded_rectangle([tx, by - bh / 2, tx + bh * 1.6, by + bh / 2], bh // 2, fill=(30, 36, 56, A), outline=(255, 255, 255, A), width=3)
    g = ImageFont.truetype(SYM_FONT, int(bh * 1.05))
    bb = g.getbbox(THUMB)
    od.text((tx + bh * 0.8 - (bb[0] + bb[2]) / 2, by - (bb[1] + bb[3]) / 2), THUMB, font=g, fill=(YEL if liked else WHITE) + (A,))
    img.alpha_composite(ov)
    BOXES.append(("cta", (x, by - bh / 2, x + tw, by + bh / 2), "登録と高評価", 1.0))

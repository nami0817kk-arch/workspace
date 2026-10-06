# -*- coding: utf-8 -*-
"""画面の細かい部品。数字の組版・マーカー・引き出し線・吹き出し・切り口。

細部が効く。単色の四角と素の文字だけだと、どれだけ並べても作り込んで見えない。
"""
from __future__ import annotations

import re

from PIL import Image, ImageDraw, ImageFilter, ImageFont

FONT_PATH = "C:/Windows/Fonts/NotoSansJP-VF.ttf"
GOLD = "#E7B93F"
INK = "#141C26"

UNIT = re.compile(r"(\d+(?:\.\d+)?)|([^\d]+)")


def F(size: int, weight: int = 900) -> ImageFont.FreeTypeFont:
    f = ImageFont.truetype(FONT_PATH, size)
    try:
        f.set_variation_by_axes([weight])
    except Exception:
        pass
    return f


def number(d: ImageDraw.ImageDraw, text: str, x: int, y: int, size: int,
           fill="#141C26", unit_ratio: float = 0.62) -> float:
    """「53円80銭」を、数字は大きく、単位は小さく組む。戻り値は右端の x。

    数字と単位を同じ大きさで打つと素人の組版に見える。単位を小さくして
    下に揃えるだけで、ぐっと締まる。
    """
    big = F(size)
    small = F(int(size * unit_ratio), 800)
    base = y + size * 0.78            # 数字の下端に単位を揃える
    for m in UNIT.finditer(text):
        num, unit = m.group(1), m.group(2)
        if num:
            d.text((x, y), num, font=big, fill=fill)
            x += d.textlength(num, font=big)
        else:
            uy = base - int(size * unit_ratio) * 0.78
            d.text((x, uy), unit, font=small, fill=fill)
            x += d.textlength(unit, font=small)
    return x


def marker(d: ImageDraw.ImageDraw, text: str, x: int, y: int, font,
           color=(231, 185, 63, 150), pad: int = 6) -> None:
    """蛍光ペンの帯。文字の下半分にだけ引く（本物のマーカーのように）。"""
    w = d.textlength(text, font=font)
    h = font.size
    d.rectangle([x - pad, y + h * 0.52, x + w + pad, y + h * 1.02], fill=color[:3])


def leader(d: ImageDraw.ImageDraw, frm: tuple[int, int], to: tuple[int, int],
           text: str, size: int = 26, color=GOLD) -> None:
    """引き出し線。図の一点から、横に伸ばして札を置く。"""
    x0, y0 = frm
    x1, y1 = to
    d.ellipse([x0 - 7, y0 - 7, x0 + 7, y0 + 7], fill=color)
    d.line([(x0, y0), (x1 - 30, y0)], fill=color, width=3)
    d.line([(x1 - 30, y0), (x1 - 30, y1)], fill=color, width=3)
    d.line([(x1 - 30, y1), (x1, y1)], fill=color, width=3)
    f = F(size, 800)
    w = d.textlength(text, font=f)
    d.rounded_rectangle([x1 + 6, y1 - size * 0.9, x1 + w + 30, y1 + size * 0.9],
                        radius=8, fill=color)
    d.text((x1 + 18, y1 - size * 0.62), text, font=f, fill="#141C26")


def balloon(im: Image.Image, text: str, x: int, y: int, size: int = 32,
            fill=(255, 255, 255, 245), tail: str = "right") -> Image.Image:
    """吹き出し。立ち絵の横に置く。tail は尻尾の向き。"""
    d = ImageDraw.Draw(im)
    f = F(size, 800)
    lines = text.split("\n")
    w = int(max(d.textlength(ln, font=f) for ln in lines)) + 60
    h = len(lines) * int(size * 1.5) + 36
    layer = Image.new("RGBA", (w + 40, h + 40), (0, 0, 0, 0))
    ld = ImageDraw.Draw(layer)
    ld.rounded_rectangle([20, 20, w + 20, h + 20], radius=18, fill=(0, 0, 0, 120))
    layer = layer.filter(ImageFilter.GaussianBlur(10))
    im.alpha_composite(layer, (x - 20, y - 14))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([x, y, x + w, y + h], radius=18, fill=fill)
    if tail == "right":
        d.polygon([(x + w, y + h * 0.45), (x + w + 28, y + h * 0.58), (x + w, y + h * 0.72)],
                  fill=fill)
    else:
        d.polygon([(x, y + h * 0.45), (x - 28, y + h * 0.58), (x, y + h * 0.72)], fill=fill)
    ty = y + 18
    for ln in lines:
        d.text((x + 30, ty), ln, font=f, fill=INK)
        ty += int(size * 1.5)
    return im


def cut_edge(im: Image.Image, side: str = "left", color=GOLD, width: int = 6) -> Image.Image:
    """画面の端に斜めの切り口を引く。このチャンネルの意匠（＝断面）。"""
    d = ImageDraw.Draw(im)
    W, H = im.size
    if side == "left":
        d.line([(0, H * 0.18), (W * 0.055, H * 0.52), (0, H * 0.86)], fill=color, width=width)
    else:
        d.line([(W, H * 0.18), (W * 0.945, H * 0.52), (W, H * 0.86)], fill=color, width=width)
    return im


def progress(im: Image.Image, done: float, color=GOLD, height: int = 8) -> Image.Image:
    """画面の下端に、どこまで来たかの細い線。"""
    d = ImageDraw.Draw(im)
    W, H = im.size
    d.rectangle([0, H - height, W, H], fill=(255, 255, 255, 40))
    d.rectangle([0, H - height, int(W * max(0.0, min(done, 1.0))), H], fill=color)
    return im

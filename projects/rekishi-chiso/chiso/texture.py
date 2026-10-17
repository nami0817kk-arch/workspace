"""紙の質感（texture）。図の板・メモの札・真ん中の額の台紙に、うっすら紙の目を乗せる。2026-10-07。

別チャンネル「世の中の断面図」の texture.paper を下敷きにした。あちらの finish は RGBA を RGB に落とし、
板の影の外が黒い枠になる。ここでは色（RGB）だけを変え、透明（alpha）はそのまま残す。

紙の目は画面1枚ぶんを最初に1回だけ作って控え（毎コマ作らない）、板の形の中にだけ足し引きする。
config.yaml の `texture: true`、または台本の一番上の `texture: true` で入る（既定は切る。前の回の見た目を変えない）。
"""
from __future__ import annotations

import random

from PIL import Image, ImageChops, ImageDraw, ImageFilter

STRENGTH = 9          # 明るさを足し引きする最大の幅（0〜255 の段階で）。言われないと気づかない程度
_CACHE: dict = {}


def grain(size: tuple[int, int]) -> tuple[Image.Image, Image.Image]:
    """紙の目（明るくする分, 暗くする分）。細かい粒と横に流れる繊維。決まった種で作るので毎回同じ。"""
    key = size
    if key not in _CACHE:
        w, h = size
        rnd = random.Random(20261007)
        fine = Image.frombytes("L", (w // 2, h // 2), rnd.randbytes((w // 2) * (h // 2)))
        fine = fine.resize((w, h), Image.BILINEAR).filter(ImageFilter.GaussianBlur(0.8))
        fw, fh = max(1, w // 24), max(1, h // 2)                  # 横長に引き伸ばすと、紙の繊維の筋になる
        fiber = Image.frombytes("L", (fw, fh), rnd.randbytes(fw * fh)).resize((w, h), Image.BICUBIC)
        g = ImageChops.add(fine, fiber, scale=2.0)                # 2つの平均（真ん中は 128 前後）
        g = g.point(lambda v: max(0, min(255, int(128 + (v - 128) * 1.6))))
        lighter = g.point(lambda v: int(max(0, v - 128) * STRENGTH / 127))
        darker = g.point(lambda v: int(max(0, 128 - v) * STRENGTH / 128))
        _CACHE[key] = (Image.merge("RGB", (lighter,) * 3), Image.merge("RGB", (darker,) * 3))
    return _CACHE[key]


def apply(img: Image.Image, box, radius: int = 0) -> None:
    """img（RGBA）の box の中（角丸 radius）に紙の目を乗せる。alpha は変えない。"""
    x0, y0, x1, y1 = (int(round(v)) for v in box)
    x0, y0 = max(0, x0), max(0, y0)
    x1, y1 = min(img.width, x1), min(img.height, y1)
    if x1 <= x0 or y1 <= y0:
        return
    up, down = grain(img.size)
    region = img.crop((x0, y0, x1, y1))
    alpha = region.getchannel("A")
    rgb = region.convert("RGB")
    rgb = ImageChops.subtract(ImageChops.add(rgb, up.crop((x0, y0, x1, y1))), down.crop((x0, y0, x1, y1)))
    out = rgb.convert("RGBA")
    out.putalpha(alpha)
    mask = Image.new("L", out.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, out.width - 1, out.height - 1], radius=radius, fill=255)
    region.paste(out, (0, 0), mask)
    img.paste(region, (x0, y0))


def plate(key, size: tuple[int, int], box, radius: int, draw_fn) -> Image.Image:
    """板（影＋塗り）を透明な層に描いて紙の目を乗せたもの。同じ板（key）は1回だけ作って控える。"""
    key = ("plate", key, size, tuple(box), radius)
    if key not in _CACHE:
        layer = Image.new("RGBA", size, (0, 0, 0, 0))
        draw_fn(layer)
        apply(layer, box, radius)
        _CACHE[key] = layer
    return _CACHE[key]

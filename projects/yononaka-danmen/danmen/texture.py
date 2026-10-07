# -*- coding: utf-8 -*-
"""画面の質感。のっぺりした塗りを、印刷物や放送の画に寄せる。

図も画面も、PIL でべた塗りしたままだと「きれいだが安い」見え方になる。
薄い紙の目、わずかな粒子、四隅の落ち、ほんの少しの暖色。
どれも単体では気づかれないが、全部を薄く重ねると出来上がりが変わる。

    paper     … 紙の目。板（白地の図）に
    grain     … 粒子。全画面（実写の上）に
    vignette  … 四隅をわずかに落とす
    warm      … ほんの少し暖色に寄せる
    finish    … 上の4つを既定の強さでまとめて掛ける

どれも強さは 0〜1 で、既定は「言われないと気づかない」程度にしてある。
"""
from __future__ import annotations

import math
import random

from PIL import Image, ImageChops, ImageDraw, ImageEnhance, ImageFilter

_CACHE: dict[tuple, Image.Image] = {}


def paper(im: Image.Image, strength: float = 0.5) -> Image.Image:
    """紙の目。細かい濃淡を乗算で重ねる。白い板に効く。"""
    if strength <= 0:
        return im
    key = ("paper", im.size)
    tex = _CACHE.get(key)
    if tex is None:
        w, h = im.size
        rnd = random.Random(20261007)
        small = Image.new("L", (max(w // 3, 1), max(h // 3, 1)))
        small.putdata([rnd.randint(214, 255) for _ in range(small.width * small.height)])
        tex = small.resize(im.size, Image.BILINEAR).filter(ImageFilter.GaussianBlur(1.1))
        # 横に薄い筋を入れる（紙の繊維の向き）
        d = ImageDraw.Draw(tex)
        for y in range(0, h, 11):
            d.line([(0, y), (w, y)], fill=251, width=1)
        _CACHE[key] = tex
    lo = int(255 - 30 * max(0.0, min(strength, 1.0)))
    flat = tex.point(lambda v: int(lo + (v - 214) * (255 - lo) / 41))
    return ImageChops.multiply(im.convert("RGB"), Image.merge("RGB", (flat, flat, flat)))


def grain(im: Image.Image, strength: float = 0.5) -> Image.Image:
    """粒子。暗い実写の上に乗せると、塗りに見えていた面が映像に寄る。"""
    if strength <= 0:
        return im
    key = ("grain", im.size)
    tex = _CACHE.get(key)
    if tex is None:
        rnd = random.Random(815)
        w, h = im.size
        small = Image.new("L", (max(w // 2, 1), max(h // 2, 1)))
        small.putdata([rnd.randint(104, 150) for _ in range(small.width * small.height)])
        tex = small.resize(im.size, Image.BILINEAR)
        _CACHE[key] = tex
    k = max(0.0, min(strength, 1.0))
    soft = tex.point(lambda v: int(128 + (v - 128) * k))
    base = im.convert("RGB")
    noise = Image.merge("RGB", (soft, soft, soft))
    # ソフトライトの代わりに、オーバーレイに近い合成を軽く掛ける
    return Image.blend(base, ImageChops.overlay(base, noise), 0.5)


def vignette(im: Image.Image, strength: float = 0.5) -> Image.Image:
    """四隅をわずかに落とす。真ん中に目が行く。"""
    if strength <= 0:
        return im
    key = ("vig", im.size)
    mask = _CACHE.get(key)
    if mask is None:
        w, h = im.size
        mask = Image.new("L", (w, h), 255)
        d = ImageDraw.Draw(mask)
        cx, cy = w / 2, h / 2
        rmax = math.hypot(cx, cy)
        steps = 48
        for i in range(steps):
            t = 1 - i / steps                       # 外ほど小さい
            r = rmax * (0.55 + 0.45 * t)
            v = int(255 - 86 * (1 - t) ** 1.6)
            d.ellipse([cx - r * 1.08, cy - r, cx + r * 1.08, cy + r], fill=v)
        mask = mask.filter(ImageFilter.GaussianBlur(w / 28))
        _CACHE[key] = mask
    k = max(0.0, min(strength, 1.0))
    soft = mask.point(lambda v: int(255 - (255 - v) * k))
    base = im.convert("RGB")
    dark = ImageEnhance.Brightness(base).enhance(0.55)
    return Image.composite(base, dark, soft)


def warm(im: Image.Image, strength: float = 0.5) -> Image.Image:
    """ほんの少し暖色に寄せる。青が勝った画が、紙と放送の色に近づく。"""
    if strength <= 0:
        return im
    k = max(0.0, min(strength, 1.0))
    r, g, b = im.convert("RGB").split()
    r = r.point(lambda v: min(255, int(v + 7 * k)))
    b = b.point(lambda v: max(0, int(v - 6 * k)))
    return Image.merge("RGB", (r, g, b))


def finish(im: Image.Image, kind: str = "panel") -> Image.Image:
    """まとめて掛ける。kind は panel（白地の図）か screen（全画面）。

    どちらも「言われないと気づかない」強さにしてある。強くすると汚れて見える。
    """
    if kind == "panel":
        im = paper(im, 0.40)
        im = warm(im, 0.22)
        return im
    if kind == "screen":
        im = grain(im, 0.32)
        im = vignette(im, 0.30)
        im = warm(im, 0.30)
        return im
    raise SystemExit("知らない種類です: {}（使えるのは panel / screen）".format(kind))

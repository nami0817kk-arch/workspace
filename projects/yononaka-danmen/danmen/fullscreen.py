# -*- coding: utf-8 -*-
"""画面いっぱいのグラフ。白い板を使わず、背景に直接置く。

ニュース番組はこの形も多く使う。板に載せるより強く、画面と一体になる。
立ち絵（右下）と字幕（下）の場所は空けてある。

    ranking … 横棒。国や項目を並べる
    change  … 縦棒。時間で変わったものと、変化率
    number  … 数字ひとつ。画面の主役
"""
from __future__ import annotations

import re
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

from danmen import screens, typo

W, H = 1920, 1080
FONT_PATH = "C:/Windows/Fonts/NotoSansJP-VF.ttf"
GOLD = "#E7B93F"
INK_LIGHT = "#C8D3E4"
GREEN_D, GREEN_L = (10, 110, 94), (32, 196, 164)
AMBER_D, AMBER_L = (168, 102, 8), (244, 170, 34)
GRAY_D, GRAY_L = (72, 82, 96), (124, 136, 152)
UNIT = re.compile(r"(\d+(?:[,.]\d+)*)|([^\d]+)")

# 立ち絵と字幕のために空ける場所
SAFE_BOTTOM = 300
SAFE_RIGHT = 420


def F(size: int, weight: int = 900) -> ImageFont.FreeTypeFont:
    # 読めない大きさは作らない。1920 の画面での 28px が、スマホで 5.7pt の下限
    size = max(int(size), typo.MIN_PX)
    f = ImageFont.truetype(FONT_PATH, size)
    try:
        f.set_variation_by_axes([weight])
    except Exception:
        pass
    return f


def _num(d: ImageDraw.ImageDraw, text: str, x: float, y: float, size: int,
         fill="white", stroke: int = 0, stroke_fill=(6, 10, 18)) -> float:
    """数字は大きく、単位は小さく。縁取りも付けられる。"""
    big, small = F(size), F(int(size * 0.58), 800)
    if not re.search(r"\d", text):
        f = F(int(size * 0.76), 800)
        d.text((x, y + size * 0.12), text, font=f, fill=fill,
               stroke_width=stroke, stroke_fill=stroke_fill)
        return x + d.textlength(text, font=f)
    base = y + size * 0.80
    for m in UNIT.finditer(text):
        num, unit = m.group(1), m.group(2)
        if num:
            d.text((x, y), num, font=big, fill=fill, stroke_width=stroke, stroke_fill=stroke_fill)
            x += d.textlength(num, font=big)
        else:
            uy = base - int(size * 0.58) * 0.80
            d.text((x, uy), unit, font=small, fill=fill,
                   stroke_width=max(stroke - 2, 0), stroke_fill=stroke_fill)
            x += d.textlength(unit, font=small)
    return x


def _bg(fig: dict) -> Image.Image:
    im = screens.backdrop(fig.get("photo"), dark=fig.get("dark", 0.26), blur=4).convert("RGBA")
    veil = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(veil)
    for y in range(0, 230):
        d.line([(0, y), (W, y)], fill=(5, 9, 16, int(220 * (1 - y / 230))))
    for y in range(H - 330, H):
        d.line([(0, y), (W, y)], fill=(5, 9, 16, int(235 * ((y - (H - 330)) / 330))))
    return Image.alpha_composite(im, veil)


def _title(im: Image.Image, text: str, sub: str = "") -> int:
    """左上の題。色帯ではなく、金の縦線＋白抜きで置く。戻り値は本文を始める y。"""
    d = ImageDraw.Draw(im)
    d.rectangle([64, 96, 76, 176], fill=GOLD)
    d.text((100, 96), text, font=F(52), fill="white",
           stroke_width=6, stroke_fill=(6, 10, 18))
    if sub:
        d.text((102, 162), sub, font=F(26, 700), fill=INK_LIGHT)
    return 250


def _glow_bar(size, dark, light, radius=8) -> Image.Image:
    w, h = max(size[0], 2), max(size[1], 2)
    g = Image.new("RGB", (w, h))
    gd = ImageDraw.Draw(g)
    for x in range(w):
        t = x / max(w - 1, 1)
        gd.line([(x, 0), (x, h)], fill=tuple(int(a + (b - a) * (0.2 + 0.8 * t))
                                             for a, b in zip(dark, light)))
    gloss = Image.new("L", (w, h), 0)
    ImageDraw.Draw(gloss).rectangle([0, 0, w, int(h * 0.42)], fill=70)
    g = Image.composite(Image.new("RGB", (w, h), (255, 255, 255)), g,
                        gloss.filter(ImageFilter.GaussianBlur(max(h * 0.1, 1))))
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, w - 1, h - 1], radius=radius, fill=255)
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    out.paste(g, (0, 0), mask)
    return out


def _paste_bar(im: Image.Image, bar: Image.Image, x: int, y: int, glow=True) -> None:
    if glow:
        halo = Image.new("RGBA", (bar.width + 60, bar.height + 60), (0, 0, 0, 0))
        halo.paste((255, 255, 255, 70), (30, 30), bar.split()[3])
        im.alpha_composite(halo.filter(ImageFilter.GaussianBlur(18)), (x - 30, y - 30))
    sh = Image.new("RGBA", (bar.width + 40, bar.height + 40), (0, 0, 0, 0))
    sh.paste((0, 0, 0, 170), (14, 18), bar.split()[3])
    im.alpha_composite(sh.filter(ImageFilter.GaussianBlur(10)), (x - 14, y - 10))
    im.alpha_composite(bar, (x, y))


def _credit(im: Image.Image, text: str) -> None:
    if text:
        d = ImageDraw.Draw(im)
        f = F(21, 600)
        d.text((W - d.textlength(text, font=f) - 56, H - 46), text, font=f, fill="#9FB0C9")


def ranking(fig: dict) -> Image.Image:
    im = _bg(fig)
    top = _title(im, fig.get("title", ""), fig.get("sub", ""))
    items = fig["items"]
    focus = str(fig.get("focus", items[0]["label"]))
    mx = max(float(i["value"]) for i in items) or 1
    label_w = 260
    bar_max = W - SAFE_RIGHT - label_w - 330
    y = top
    step = min(110, (H - SAFE_BOTTOM - top) // max(len(items), 1))
    for it in items:
        is_focus = str(it["label"]) == focus
        dark, light = (GREEN_D, GREEN_L) if is_focus else (GRAY_D, GRAY_L)
        d = ImageDraw.Draw(im)
        d.text((64, y + 14), str(it["label"]), font=F(34, 900 if is_focus else 700),
               fill="white" if is_focus else INK_LIGHT, stroke_width=5, stroke_fill=(6, 10, 18))
        bw = int(bar_max * float(it["value"]) / mx)
        _paste_bar(im, _glow_bar((max(bw, 8), 56), dark, light), 64 + label_w, y + 10,
                   glow=is_focus)
        d = ImageDraw.Draw(im)
        _num(d, str(it.get("note", it["value"])), 64 + label_w + max(bw, 8) + 26, y + 6,
             48, fill="white" if is_focus else INK_LIGHT, stroke=7)
        y += step
    _credit(im, fig.get("credit", ""))
    return im.convert("RGB")


def change(fig: dict) -> Image.Image:
    im = _bg(fig)
    top = _title(im, fig.get("title", ""), fig.get("sub", ""))
    items = fig["items"]
    n = len(items)
    rate_w = 360
    cw = (W - SAFE_RIGHT - 128 - rate_w - (n - 1) * 70) // max(n, 1)
    mx = max(float(v["value"]) for v in items) or 1
    x = 64
    bar_area = H - SAFE_BOTTOM - top - 150
    for i, it in enumerate(items):
        last = i == n - 1
        dark, light = (AMBER_D, AMBER_L) if last else (GRAY_D, GRAY_L)
        d = ImageDraw.Draw(im)
        d.text((x, top), str(it["label"]), font=F(30, 800), fill=INK_LIGHT,
               stroke_width=5, stroke_fill=(6, 10, 18))
        bh = int(bar_area * float(it["value"]) / mx)
        _paste_bar(im, _glow_bar((cw, bh), dark, light), x, top + 50 + (bar_area - bh), glow=last)
        d = ImageDraw.Draw(im)
        _num(d, str(it.get("note", it["value"])), x, top + 62 + bar_area, 56,
             fill="white" if last else INK_LIGHT, stroke=8)
        x += cw + 70
    if n >= 2:
        first = float(items[0]["value"])
        rate = (float(items[-1]["value"]) - first) / first * 100 if first else 0
        up = rate >= 0
        col = "#F0564A" if up else "#5BA8F5"
        txt = "{}{:.0f}%".format("▲" if up else "▼", abs(rate))
        d = ImageDraw.Draw(im)
        f = F(78)
        tw = d.textlength(txt, font=f)
        bx = W - SAFE_RIGHT - tw - 40
        d.text((bx, top + 130), txt, font=f, fill=col, stroke_width=10, stroke_fill=(6, 10, 18))
        lab, lf = "この間の変化", F(28, 700)
        d.text((bx, top + 84), lab, font=lf, fill=INK_LIGHT, stroke_width=5, stroke_fill=(6, 10, 18))
    _credit(im, fig.get("credit", ""))
    return im.convert("RGB")


def number(fig: dict) -> Image.Image:
    """数字ひとつを画面の主役にする。"""
    im = _bg(fig)
    top = _title(im, fig.get("title", ""), fig.get("sub", ""))
    d = ImageDraw.Draw(im)
    value = str(fig.get("value", ""))
    size = int(fig.get("size", 230))
    probe = ImageDraw.Draw(Image.new("RGB", (1, 1)))
    tw = 0
    for m in UNIT.finditer(value):
        num, unit = m.group(1), m.group(2)
        tw += probe.textlength(num or unit, font=F(size) if num else F(int(size * 0.58), 800))
    x = (W - SAFE_RIGHT - tw) / 2
    y = top + 60
    _num(d, value, x, y, size, fill=GOLD, stroke=14)
    lead = str(fig.get("lead", ""))
    if lead:
        f = F(44, 800)
        d.text(((W - SAFE_RIGHT - d.textlength(lead, font=f)) / 2, y + size + 40), lead,
               font=f, fill="white", stroke_width=8, stroke_fill=(6, 10, 18))
    _credit(im, fig.get("credit", ""))
    return im.convert("RGB")


KINDS = {"ranking": ranking, "change": change, "number": number}


def draw(fig: dict, out: Path) -> Path:
    kind = fig.get("kind")
    if kind not in KINDS:
        raise SystemExit("知らない種類です: {}（使えるのは {}）".format(kind, " / ".join(KINDS)))
    im = KINDS[kind](fig)
    out.parent.mkdir(parents=True, exist_ok=True)
    im.save(out)
    return out

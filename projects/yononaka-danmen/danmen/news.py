# -*- coding: utf-8 -*-
"""ニュース番組の水準でグラフと表を描く。

これまでの `figures.py` は「資料」の作りだった。こちらは「テロップ」の作り。
違いは7つ。

1. 板の上に**色の帯**を敷き、そこに題を白抜きで置く（資料は細い罫線）
2. 棒は**グラデーション＋上のつや＋落ち影**。平らに塗らない
3. 数字は**極太・特大**、単位だけ小さく（テレビのテロップの組版）
4. **増減は ▲▼** で示し、色を分ける
5. 強調する項目だけ色。**残りは無彩色に落とす**
6. 目盛りは出さない。代わりに**値を棒の先に直接置く**
7. 右下に**小さく出典**。常に入れる
"""
from __future__ import annotations

import re
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

FONT_PATH = "C:/Windows/Fonts/NotoSansJP-VF.ttf"

# 色（dataviz の検証を通した3色を基に、テロップ向けに濃淡を足した）
BLUE_D, BLUE_L = (28, 54, 122), (74, 110, 214)
GREEN_D, GREEN_L = (8, 92, 78), (24, 164, 138)
AMBER_D, AMBER_L = (150, 92, 8), (226, 152, 24)
RED_D, RED_L = (140, 32, 28), (216, 68, 56)
GRAY_D, GRAY_L = (104, 110, 120), (158, 164, 174)

PAIRS = [(GREEN_D, GREEN_L), (AMBER_D, AMBER_L), (BLUE_D, BLUE_L)]
INK = "#121922"
INK_SUB = "#5F6A77"
PANEL = (252, 252, 250)
GOLD = "#E7B93F"


def F(size: int, weight: int = 900) -> ImageFont.FreeTypeFont:
    f = ImageFont.truetype(FONT_PATH, size)
    try:
        f.set_variation_by_axes([weight])
    except Exception:
        pass
    return f


UNIT = re.compile(r"(\d+(?:[,.]\d+)*)|([^\d]+)")


def put_number(d: ImageDraw.ImageDraw, text: str, x: float, y: float, size: int,
               fill=INK, unit_ratio: float = 0.58, shadow: bool = False) -> float:
    """数字は大きく、単位は小さく。テレビのテロップの組み方。

    数字がひとつも無い値（「道路だけ」など）は、ふつうの文字として描く。
    """
    big, small = F(size), F(int(size * unit_ratio), 800)
    if not re.search(r"\d", text):
        f = F(int(size * 0.76), 800)
        if shadow:
            d.text((x + 2, y + 2), text, font=f, fill=(0, 0, 0, 90))
        d.text((x, y + size * 0.12), text, font=f, fill=fill)
        return x + d.textlength(text, font=f)
    base = y + size * 0.80
    for m in UNIT.finditer(text):
        num, unit = m.group(1), m.group(2)
        if num:
            if shadow:
                d.text((x + 3, y + 3), num, font=big, fill=(0, 0, 0, 90))
            d.text((x, y), num, font=big, fill=fill)
            x += d.textlength(num, font=big)
        else:
            uy = base - int(size * unit_ratio) * 0.80
            if shadow:
                d.text((x + 2, uy + 2), unit, font=small, fill=(0, 0, 0, 90))
            d.text((x, uy), unit, font=small, fill=fill)
            x += d.textlength(unit, font=small)
    return x


def _panel(w: int, h: int, title: str, band=(20, 34, 64)) -> tuple:
    """上に色帯を持つ板。ニュースのフリップはこの形。"""
    im = Image.new("RGBA", (w + 56, h + 56), (0, 0, 0, 0))
    sh = Image.new("RGBA", im.size, (0, 0, 0, 0))
    ImageDraw.Draw(sh).rounded_rectangle([34, 40, w + 34, h + 40], radius=14, fill=(0, 0, 0, 165))
    im.alpha_composite(sh.filter(ImageFilter.GaussianBlur(16)))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([28, 28, w + 28, h + 28], radius=14, fill=PANEL)
    band_h = 86
    d.rounded_rectangle([28, 28, w + 28, 28 + band_h], radius=14, fill=band)
    d.rectangle([28, 28 + band_h - 16, w + 28, 28 + band_h], fill=band)
    d.rectangle([28, 28 + band_h - 5, w + 28, 28 + band_h], fill=GOLD)
    if title:
        d.text((58, 28 + 20), title, font=F(40), fill="white")
    return im, d, 28 + band_h + 26


def _bar(size: tuple[int, int], dark, light, radius: int = 6) -> Image.Image:
    """グラデーション＋上のつやを持つ棒。"""
    w, h = max(size[0], 2), max(size[1], 2)
    g = Image.new("RGB", (w, h))
    gd = ImageDraw.Draw(g)
    for x in range(w):
        t = x / max(w - 1, 1)
        gd.line([(x, 0), (x, h)], fill=tuple(int(a + (b - a) * (0.25 + 0.75 * t))
                                             for a, b in zip(dark, light)))
    gloss = Image.new("L", (w, h), 0)
    ImageDraw.Draw(gloss).rectangle([0, 0, w, int(h * 0.44)], fill=74)
    g = Image.composite(Image.new("RGB", (w, h), (255, 255, 255)), g,
                        gloss.filter(ImageFilter.GaussianBlur(max(h * 0.1, 1))))
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, w - 1, h - 1], radius=radius, fill=255)
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    out.paste(g, (0, 0), mask)
    return out


def _credit(d: ImageDraw.ImageDraw, text: str, w: int, h: int) -> None:
    if text:
        f = F(20, 600)
        d.text((w + 28 - d.textlength(text, font=f) - 24, h + 28 - 34), text, font=f, fill=INK_SUB)


def ranking(fig: dict) -> Image.Image:
    """横棒のランキング。注目する1本だけ色、ほかは灰。ニュースの定番。"""
    items = fig["items"]
    focus = str(fig.get("focus", items[0]["label"]))
    w, h = 1120, 150 + len(items) * 104
    im, d, top = _panel(w, h, fig.get("title", ""), band=fig.get("band", (20, 34, 64)))
    mx = max(float(i["value"]) for i in items) or 1
    y = top
    label_w = 230
    bar_max = w - label_w - 330
    for it in items:
        is_focus = str(it["label"]) == focus
        dark, light = PAIRS[0] if is_focus else (GRAY_D, GRAY_L)
        d.text((58, y + 18), str(it["label"]), font=F(32, 900 if is_focus else 700),
               fill=INK if is_focus else INK_SUB)
        bw = int(bar_max * float(it["value"]) / mx)
        bar = _bar((max(bw, 6), 64), dark, light)
        sh = Image.new("RGBA", (bar.width + 20, bar.height + 20), (0, 0, 0, 0))
        sh.paste((0, 0, 0, 110), (8, 10), bar.split()[3])
        im.alpha_composite(sh.filter(ImageFilter.GaussianBlur(7)), (58 + label_w - 8, y + 2))
        im.alpha_composite(bar, (58 + label_w, y + 8))
        d = ImageDraw.Draw(im)
        put_number(d, str(it.get("note", it["value"])), 58 + label_w + max(bw, 6) + 22, y + 10,
                   46, fill=INK if is_focus else INK_SUB)
        y += 104
    _credit(d, fig.get("credit", ""), w, h)
    return im


def change(fig: dict) -> Image.Image:
    """前と後ろを比べ、増減を ▲▼ で出す。ニュースで最も見る形。"""
    items = fig["items"]
    w, h = 1120, 460
    im, d, top = _panel(w, h, fig.get("title", ""), band=fig.get("band", (20, 34, 64)))
    n = len(items)
    rate_w = 250                       # 右に変化率を置く場所
    cw = (w - 120 - rate_w - (n - 1) * 60) // max(n, 1)
    x = 58
    first = float(items[0]["value"])
    for i, it in enumerate(items):
        val = float(it["value"])
        last = i == n - 1
        dark, light = (AMBER_D, AMBER_L) if last else (GRAY_D, GRAY_L)
        d.text((x, top), str(it["label"]), font=F(28, 800), fill=INK_SUB)
        bar_h = int(170 * (val / max(float(v["value"]) for v in items)))
        bar = _bar((cw, bar_h), dark, light)
        im.alpha_composite(bar, (x, top + 46 + (170 - bar_h)))
        d = ImageDraw.Draw(im)
        put_number(d, str(it.get("note", it["value"])), x, top + 232, 54,
                   fill=INK if last else INK_SUB)
        x += cw + 60
    if n >= 2:
        rate = (float(items[-1]["value"]) - first) / first * 100 if first else 0
        up = rate >= 0
        col = (200, 48, 40) if up else (24, 110, 200)
        mark = "▲" if up else "▼"
        txt = "{}{:.0f}%".format(mark, abs(rate))
        f = F(62)
        tw = d.textlength(txt, font=f)
        d.text((w - tw - 30, top + 70), txt, font=f, fill=col)
        lab, lf = "この間の変化", F(24, 700)
        d.text((w - d.textlength(lab, font=lf) - 30, top + 30), lab, font=lf, fill=INK_SUB)
    _credit(d, fig.get("credit", ""), w, h)
    return im


def board(fig: dict) -> Image.Image:
    """表。1行目を強調し、縞を敷く。ニュースのフリップの表。"""
    cols = fig.get("cols", [])
    items = fig["items"]
    w, h = 1180, 196 + len(items) * 84
    im, d, top = _panel(w, h, fig.get("title", ""), band=fig.get("band", (20, 34, 64)))
    label_w = 420
    cw = (w - label_w - 60) // max(len(cols), 1)
    for i, c in enumerate(cols):
        f = F(28, 800)
        cx = 58 + label_w + i * cw
        d.text((cx + (cw - d.textlength(str(c), font=f)) / 2, top - 6), str(c), font=f, fill=INK_SUB)
    top += 40
    d.line([(58, top), (w - 2), ], fill="#D9DDE3", width=2) if False else None
    d.line([(58, top), (w - 2, top)], fill="#D9DDE3", width=2)
    y = top + 10
    for n, it in enumerate(items):
        if n % 2 == 1:
            d.rectangle([44, y - 4, w + 12, y + 68], fill="#F2F4F7")
        d.text((58, y + 12), str(it["label"]), font=F(31, 800), fill=INK)
        for i, v in enumerate(it.get("values", [])):
            cx = 58 + label_w + i * cw
            strong = bool(it.get("strong")) and i == len(it.get("values", [])) - 1
            size = 38 if strong else 32
            tw = 0
            probe = ImageDraw.Draw(Image.new("RGB", (1, 1)))
            for m in UNIT.finditer(str(v)):
                num, unit = m.group(1), m.group(2)
                tw += probe.textlength(num or unit,
                                       font=F(size) if num else F(int(size * 0.58), 800))
            put_number(d, str(v), cx + (cw - tw) / 2, y + (6 if strong else 10), size,
                       fill=(196, 122, 10) if strong else INK)
        y += 84
    _credit(d, fig.get("credit", ""), w, h)
    return im


def big_number(fig: dict) -> Image.Image:
    """数字ひとつ。ニュースの「きょうの数字」。"""
    w, h = 940, 380
    im, d, top = _panel(w, h, fig.get("title", ""), band=fig.get("band", (20, 34, 64)))
    value = str(fig.get("value", ""))
    probe = ImageDraw.Draw(Image.new("RGB", (1, 1)))
    size = 132
    tw = 0
    for m in UNIT.finditer(value):
        num, unit = m.group(1), m.group(2)
        tw += probe.textlength(num or unit, font=F(size) if num else F(int(size * 0.58), 800))
    put_number(d, value, (w - tw) / 2 + 28, top + 10, size, fill=(196, 122, 10), shadow=True)
    sub = str(fig.get("sub", ""))
    if sub:
        f = F(34, 800)
        d.text(((w - d.textlength(sub, font=f)) / 2 + 28, top + 182), sub, font=f, fill=INK)
    _credit(d, fig.get("credit", ""), w, h)
    return im


KINDS = {"ranking": ranking, "change": change, "board": board, "big_number": big_number}


def draw(fig: dict, out: Path) -> Path:
    kind = fig.get("kind")
    if kind not in KINDS:
        raise SystemExit("知らない種類です: {}（使えるのは {}）".format(kind, " / ".join(KINDS)))
    im = KINDS[kind](fig)
    out.parent.mkdir(parents=True, exist_ok=True)
    im.save(out)
    return out

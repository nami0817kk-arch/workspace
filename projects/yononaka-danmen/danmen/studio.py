# -*- coding: utf-8 -*-
"""テレビのスタジオ解説の画面。日本のニュース番組で最も見る形。

    flip … 白い大きなフリップに、黒帯の見出しと札を並べる。右に出演者のワイプ

参考にした形（日テレ NEWS の解説画面）の作り。
  ・画面の左7割が白いフリップ。影を落として浮かせる
  ・フリップの上に**黒い帯の見出し**（白抜き・太い縁取り）
  ・中身は**薄い黄の枠**で囲い、その中に札を置く
  ・札は2種類。**灰色地に赤文字**（項目名）と**赤地に白文字**（中身）。どちらも黒い枠つき
  ・右に**ワイプ**（ピンクの枠に人物）。名前の札を下に敷く
  ・右上に**番組の帯**（時刻のしるしと、2段の見出し）

数字の組版や書体は news.py と揃えてある。
"""
from __future__ import annotations

import re
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

FONT_PATH = "C:/Windows/Fonts/NotoSansJP-VF.ttf"
W, H = 1920, 1080
PINK = (228, 60, 110)
PINK_D = (176, 28, 74)
RED = (214, 32, 34)
RED_D = (150, 16, 18)
CREAM = (244, 231, 188)
INK = (18, 18, 22)
BASE = Path(r"C:/Users/なみ/dev/output/yononaka-danmen/assets")


def F(size: int, weight: int = 900) -> ImageFont.FreeTypeFont:
    f = ImageFont.truetype(FONT_PATH, size)
    try:
        f.set_variation_by_axes([weight])
    except Exception:
        pass
    return f


def _studio_bg() -> Image.Image:
    """スタジオの壁。薄い灰色に、ゆるい斜めの面を重ねる。"""
    im = Image.new("RGB", (W, H), (236, 237, 239))
    d = ImageDraw.Draw(im)
    for i, (poly, col) in enumerate([
        ([(0, 0), (520, 0), (240, H), (0, H)], (228, 229, 232)),
        ([(520, 0), (1150, 0), (980, H), (240, H)], (242, 243, 245)),
        ([(1150, 0), (W, 0), (W, H), (980, H)], (232, 233, 236)),
    ]):
        d.polygon(poly, fill=col)
    for x in range(-200, W, 190):
        d.line([(x, 0), (x + 320, H)], fill=(226, 227, 231), width=3)
    return im


def _tag(d: ImageDraw.ImageDraw, text: str, x: int, y: int, size: int = 44,
         kind: str = "red") -> tuple[int, int]:
    """札。kind は red（赤地に白）／gray（灰色地に赤文字）／plain（白地に黒）。"""
    f = F(size)
    tw = d.textlength(text, font=f)
    pad = 20
    w, h = int(tw + pad * 2), int(size * 1.55)
    if kind == "red":
        bg, fg = RED, (255, 255, 255)
    elif kind == "gray":
        bg, fg = (176, 178, 182), RED
    else:
        bg, fg = (255, 255, 255), INK
    d.rectangle([x + 6, y + 7, x + w + 6, y + h + 7], fill=(60, 60, 66))     # 影
    d.rectangle([x, y, x + w, y + h], fill=bg, outline=INK, width=5)
    d.text((x + pad, y + (h - size * 1.18) / 2), text, font=f, fill=fg,
           stroke_width=3 if kind == "gray" else 0, stroke_fill=INK)
    return w, h


def flip(spec: dict) -> Image.Image:
    """スタジオ解説の画面を1枚作る。"""
    im = _studio_bg()
    d = ImageDraw.Draw(im)

    # 右上：番組の帯
    band = spec.get("band", {})
    if band:
        bx, by = W - 720, 36
        d.ellipse([bx - 70, by - 6, bx + 30, by + 94], fill=(255, 255, 255), outline=PINK, width=5)
        t1 = str(band.get("corner", ""))
        f1 = F(40)
        d.text((bx - 70 + (100 - d.textlength(t1, font=f1)) / 2, by + 10), t1, font=f1, fill=PINK)
        d.rectangle([bx + 46, by, W - 40, by + 58], fill=PINK)
        d.text((bx + 72, by + 6), str(band.get("head", "")), font=F(42), fill="white")
        d.rectangle([bx + 46, by + 62, W - 40, by + 112], fill=(248, 150, 178))
        d.text((bx + 72, by + 70), str(band.get("sub", "")), font=F(32), fill="white")

    # 左：白いフリップ
    fx, fy = 120, 180
    fw, fh = 1320, 800
    sh = Image.new("RGBA", (fw + 60, fh + 60), (0, 0, 0, 0))
    ImageDraw.Draw(sh).rectangle([30, 34, fw + 30, fh + 34], fill=(0, 0, 0, 120))
    im.paste(Image.new("RGB", sh.size, (0, 0, 0)), (fx - 30, fy - 26),
             sh.filter(ImageFilter.GaussianBlur(14)).split()[3])
    d = ImageDraw.Draw(im)
    d.rectangle([fx, fy, fx + fw, fy + fh], fill=(255, 255, 255))

    # 見出し（黒帯・白抜き）
    title = str(spec.get("title", ""))
    if title:
        tf = F(60)
        tw = d.textlength(title, font=tf)
        tx = fx + (fw - tw) / 2
        ty = fy + 36
        d.rectangle([tx - 34, ty - 12, tx + tw + 34, ty + 76], fill=INK)
        d.text((tx, ty), title, font=tf, fill="white")

    # 中身：薄い黄の枠
    rows = spec.get("rows", [])
    row_h = 0
    for row in rows:
        row_h += max(int(float(c.get("size", 44)) * 1.55) for c in row) + 26
    bx0, by0 = fx + 36, fy + 150
    bx1 = fx + fw - 36
    by1 = min(by0 + row_h + 50, fy + fh - 150)
    d.rectangle([bx0, by0, bx1, by1], fill=CREAM)
    y = by0 + 26
    for row in rows:
        x = bx0 + 26
        tallest = 0
        for cell in row:
            text = str(cell.get("text", ""))
            kind = cell.get("kind", "plain")
            size = int(cell.get("size", 44))
            if kind == "text":
                f = F(size)
                d.text((x, y + 8), text, font=f, fill=INK)
                x += d.textlength(text, font=f) + 24
                tallest = max(tallest, int(size * 1.5))
            else:
                w, h = _tag(d, text, x, y, size, kind)
                x += w + 24
                tallest = max(tallest, h)
        y += tallest + 26

    note = str(spec.get("note", ""))
    if note:
        d.text((bx0, by1 + 22), note, font=F(28, 700), fill=(90, 90, 96))
    credit = str(spec.get("credit", ""))
    if credit:
        f = F(22, 600)
        d.text((fx + fw - d.textlength(credit, font=f) - 20, fy + fh - 40), credit,
               font=f, fill=(120, 120, 126))

    # 右：ワイプ
    for i, p in enumerate(spec.get("wipes", [])[:2]):
        wx, wy = W - 440, 180 + i * 440
        ww, wh = 360, 300
        d.rectangle([wx - 8, wy - 8, wx + ww + 8, wy + wh + 8], fill=PINK)
        img = p.get("photo")
        if img and Path(str(img)).exists():
            pic = Image.open(str(img)).convert("RGBA")
            pic = pic.crop((0, 0, pic.width, int(pic.height * 0.34)))
            s = wh / pic.height
            pic = pic.resize((int(pic.width * s), wh))
            tile = Image.new("RGB", (ww, wh), (226, 232, 240))
            tile.paste(pic.convert("RGB"), ((ww - pic.width) // 2, 0), pic)
            im.paste(tile, (wx, wy))
        else:
            d.rectangle([wx, wy, wx + ww, wy + wh], fill=(226, 232, 240))
        d = ImageDraw.Draw(im)
        name = str(p.get("name", ""))
        if name:
            d.rectangle([wx - 8, wy + wh + 10, wx + ww + 8, wy + wh + 70], fill=PINK)
            nf = F(38)
            d.text((wx + (ww - d.textlength(name, font=nf)) / 2, wy + wh + 16), name,
                   font=nf, fill="white")
        role = str(p.get("role", ""))
        if role:
            rf = F(24, 700)
            d.text((wx + (ww - d.textlength(role, font=rf)) / 2, wy + wh + 78), role,
                   font=rf, fill=(70, 70, 76))
    return im


KINDS = {"flip": flip}


def draw(spec: dict, out: Path) -> Path:
    kind = spec.get("kind", "flip")
    if kind not in KINDS:
        raise SystemExit("知らない種類です: {}".format(kind))
    im = KINDS[kind](spec)
    out.parent.mkdir(parents=True, exist_ok=True)
    im.save(out)
    return out

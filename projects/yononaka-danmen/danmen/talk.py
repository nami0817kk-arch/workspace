# -*- coding: utf-8 -*-
"""掛け合いの画面。2人が出てくる形、3つ。

    talk     … 2人が左右に立ち、吹き出しで1往復
    aside    … すでにある画面の右下に立ち絵と一言を重ねる（後掛け）
    reaction … 聞き手が大きく驚く。節の頭で数字を出すときに

立ち絵は `cast.py` から読む。顔の大きさと立ち位置は、どの画面でも揃えてある。
"""
from __future__ import annotations

import re
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

from danmen import cast, screens, typo

W, H = 1920, 1080
FONT_PATH = "C:/Windows/Fonts/NotoSansJP-VF.ttf"
NAVY = (18, 32, 62)
GOLD = "#E7B93F"
GOLD_RGB = (231, 185, 63)
INK = (18, 20, 26)
AMBER = (164, 102, 8)        # 文字用。塗りより濃い（白地で 4.6:1）
UNIT = re.compile(r"(\d+(?:[,.]\d+)*)|([^\d]+)")


def F(size: int, weight: int = 900) -> ImageFont.FreeTypeFont:
    # 読めない大きさは作らない。1920 の画面での 28px が、スマホで 5.7pt の下限
    size = max(int(size), typo.MIN_PX)
    f = ImageFont.truetype(FONT_PATH, size)
    try:
        f.set_variation_by_axes([weight])
    except Exception:
        pass
    return f


def _wrap(d, text: str, font, width: float) -> list[str]:
    lines, cur = [], ""
    for ch in text:
        if ch == "\n":
            lines.append(cur); cur = ""; continue
        cur += ch
        if d.textlength(cur, font=font) > width:
            lines.append(cur); cur = ""
    if cur:
        lines.append(cur)
    return lines


def _bubble_size(text: str, max_w: int, size: int) -> tuple[int, int, list[str]]:
    """吹き出しの大きさを、描く前に測る。置き場所を決めるのに要る。"""
    d = ImageDraw.Draw(Image.new("RGB", (1, 1)))
    f = F(size, 800)
    lines = _wrap(d, text, f, max_w - 72)[:4]
    bw = int(max(d.textlength(ln, font=f) for ln in lines)) + 72
    bh = len(lines) * int(size * 1.46) + 44
    return bw, bh, lines


def _bubble(im: Image.Image, text: str, x: int, y: int, max_w: int, size: int = 40,
            tail: str = "left", fill=(252, 252, 250, 248)) -> tuple[int, int]:
    """吹き出し。tail は尻尾の出る向き（しゃべっている人の側）。"""
    bw, bh, lines = _bubble_size(text, max_w, size)
    d = ImageDraw.Draw(im)
    f = F(size, 800)
    sh = Image.new("RGBA", (bw + 60, bh + 60), (0, 0, 0, 0))
    ImageDraw.Draw(sh).rounded_rectangle([26, 32, bw + 26, bh + 32], radius=22,
                                         fill=(0, 0, 0, 150))
    im.alpha_composite(sh.filter(ImageFilter.GaussianBlur(14)), (x - 26, y - 24))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([x, y, x + bw, y + bh], radius=22, fill=fill)
    if tail == "left":
        d.polygon([(x, y + bh * 0.42), (x - 34, y + bh * 0.56), (x, y + bh * 0.70)], fill=fill)
    elif tail == "down":
        mx = x + bw * 0.62
        d.polygon([(mx - 26, y + bh), (mx + 26, y + bh), (mx + 4, y + bh + 34)], fill=fill)
    else:
        d.polygon([(x + bw, y + bh * 0.42), (x + bw + 34, y + bh * 0.56),
                   (x + bw, y + bh * 0.70)], fill=fill)
    ty = y + 22
    for ln in lines:
        d.text((x + 36, ty), ln, font=f, fill=INK)
        ty += int(size * 1.46)
    return bw, bh


def talk(spec: dict) -> Image.Image:
    """2人が左右に立ち、吹き出しで1往復。節のつなぎ目や、問いを立てるときに。

    spec: {photo, title, left:{who,mood,say}, right:{who,mood,say}}
    """
    im = screens.backdrop(spec.get("photo"), dark=float(spec.get("dark", 0.40)),
                          blur=8).convert("RGBA")
    d = ImageDraw.Draw(im)
    title = str(spec.get("title", ""))
    if title:
        d.rectangle([64, 60, 76, 150], fill=GOLD)
        d.text((100, 56), title, font=F(52), fill="white",
               stroke_width=6, stroke_fill=(6, 10, 18))

    left = spec.get("left", {"who": "katari"})
    right = spec.get("right", {"who": "kikite"})
    # 立ち絵は腰から上。2人とも同じ高さにして、背の違いを作らない
    lw = cast.put(im, str(left.get("who", "katari")), str(left.get("mood", "")),
                  h=740, part="half", left=40, bottom=H - 10)
    rw = cast.put(im, str(right.get("who", "kikite")), str(right.get("mood", "")),
                  h=740, part="half", right=40, bottom=H - 10)
    # 吹き出し。左の人は右へ、右の人は左へ出す
    if str(left.get("say", "")):
        _bubble(im, str(left["say"]), lw + 90, 230, 920, size=40, tail="left")
    if str(right.get("say", "")):
        s = str(right["say"])
        bw, _, _ = _bubble_size(s, 920, 38)
        _bubble(im, s, W - rw - 90 - bw, 560, 920, size=38, tail="right")
    credit = str(spec.get("credit", ""))
    if credit:
        cf = F(typo.NOTE, 600)
        d = ImageDraw.Draw(im)
        d.text((W - d.textlength(credit, font=cf) - 60, H - 48), credit, font=cf,
               fill="#9FB0C9")
    return im.convert("RGB")


def aside(im: Image.Image, spec: dict) -> Image.Image:
    """すでにある画面の右下に、立ち絵と一言を重ねる。後掛けで使う。

    図を見せている最中に、聞き手が「え、半分が税金ですか」と割り込む形。
    """
    out = im.convert("RGBA")
    who = str(spec.get("who", "kikite"))
    mood = str(spec.get("mood", "odoroki"))
    h = int(spec.get("height", 480))
    side = str(spec.get("side", "right"))
    kw = {"right": 40} if side == "right" else {"left": 40}
    wpx = cast.put(out, who, mood, h=h, part="bust", bottom=out.size[1] - 6, **kw)
    say = str(spec.get("say", ""))
    if say:
        size = int(spec.get("size", 36))
        # 吹き出しは**立ち絵の真上**に出す。横に出すと図の上に乗ってしまう
        max_w = int(spec.get("max_width", 620))
        bw, bh, _ = _bubble_size(say, max_w, size)
        W_, H_ = out.size
        cx = (W_ - 40 - wpx / 2) if side == "right" else (40 + wpx / 2)
        bx = int(min(max(cx - bw * 0.62, 20), W_ - bw - 20))
        by = max(30, H_ - h - bh - 24)
        _bubble(out, say, bx, by, max_w, size=size, tail="down")
    return out.convert("RGB")


def reaction(spec: dict) -> Image.Image:
    """聞き手が大きく驚く。数字を出した直後に1枚だけ挟む。

    毎回使うと安くなるので、1本に2回まで。
    """
    im = screens.backdrop(spec.get("photo"), dark=float(spec.get("dark", 0.38)),
                          blur=10).convert("RGBA")
    # 放射状の線（驚きの集中線）。薄く、数を抑える
    import math
    rays = Image.new("RGBA", im.size, (0, 0, 0, 0))
    rd = ImageDraw.Draw(rays)
    cx, cy = W * 0.40, H * 0.46
    for i in range(44):
        a = i / 44 * math.tau + 0.12
        rd.line([(cx + math.cos(a) * 320, cy + math.sin(a) * 320),
                 (cx + math.cos(a) * 1600, cy + math.sin(a) * 1600)],
                fill=(255, 255, 255, 26), width=9)
    im.alpha_composite(rays.filter(ImageFilter.GaussianBlur(3)))

    cast.put(im, str(spec.get("who", "kikite")), str(spec.get("mood", "odoroki")),
             h=900, part="half", right=60, bottom=H + 10)
    d = ImageDraw.Draw(im)
    lead = str(spec.get("lead", ""))
    if lead:
        d.text((110, 220), lead, font=F(48), fill="#DCE4F0",
               stroke_width=6, stroke_fill=(6, 10, 18))
    val = str(spec.get("value", ""))
    if val:
        size = 230
        probe = ImageDraw.Draw(Image.new("RGB", (1, 1)))

        def _w(sz: int) -> float:
            t = 0.0
            for m in UNIT.finditer(val):
                t += probe.textlength(m.group(0),
                                      font=F(sz) if m.group(1) else F(int(sz * 0.50), 800))
            return t

        while _w(size) > 1020 and size > 70:
            size -= 10
        x, base = 110, 310 + size * 0.80
        for m in UNIT.finditer(val):
            num, unit = m.group(1), m.group(2)
            if num:
                d.text((x, 310), num, font=F(size), fill=GOLD_RGB,
                       stroke_width=12, stroke_fill=(6, 10, 18))
                x += d.textlength(num, font=F(size))
            else:
                uf = F(int(size * 0.50), 800)
                d.text((x, base - int(size * 0.50) * 0.80), unit, font=uf, fill="white",
                       stroke_width=9, stroke_fill=(6, 10, 18))
                x += d.textlength(unit, font=uf)
    say = str(spec.get("say", ""))
    if say:
        _bubble(im, say, 110, 330 + 250, 820, size=44, tail="right")
    credit = str(spec.get("credit", ""))
    if credit:
        # 右下は立ち絵がいるので、出典は左下に出す
        d.text((110, H - 56), credit, font=F(typo.NOTE, 600), fill="#9FB0C9")
    return im.convert("RGB")


KINDS = {"talk": talk, "reaction": reaction}


def draw(spec: dict, out: Path) -> Path:
    kind = spec.get("kind")
    if kind not in KINDS:
        raise SystemExit("知らない種類です: {}（使えるのは {}／aside は後掛け）".format(
            kind, " / ".join(KINDS)))
    im = KINDS[kind](spec)
    out.parent.mkdir(parents=True, exist_ok=True)
    im.save(out)
    return out

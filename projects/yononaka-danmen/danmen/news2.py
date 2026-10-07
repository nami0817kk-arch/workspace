# -*- coding: utf-8 -*-
"""ニュース番組の「画面の作法」をさらに4つ。

    breaking … 速報の帯。画面の下に赤い札と見出し
    lshape   … L字。下と右に枠を作り、真ん中に映像を残す
    voices   … 街の声。聞いた人の属性つきで声を並べる
    split    … 分割画面。左に実写、右に図や数字

どれも 1920x1080 の画面として返す。背景は実写（暗く落とす）か濃紺。
"""
from __future__ import annotations

import re
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageFont

from danmen import screens, typo

W, H = 1920, 1080
FONT_PATH = "C:/Windows/Fonts/NotoSansJP-VF.ttf"
RED = (206, 32, 36)
RED_D = (150, 16, 18)
NAVY = (18, 32, 62)
GOLD = "#E7B93F"
INK = (18, 20, 26)
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


def _bg(spec: dict, dark: float = 0.5, blur: int = 2) -> Image.Image:
    return screens.backdrop(spec.get("photo"), dark=dark, blur=blur).convert("RGBA")


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


def breaking(spec: dict) -> Image.Image:
    """速報の帯。画面の下に赤い札と見出し。実写の上に重ねる。"""
    im = _bg(spec, dark=float(spec.get("dark", 0.62)), blur=1)
    d = ImageDraw.Draw(im)
    y = H - 300
    # 下の帯（2段）
    d.rectangle([0, y, W, y + 128], fill=NAVY + (242,))
    d.rectangle([0, y + 128, W, y + 196], fill=(242, 244, 248, 240))
    # 左の赤い札
    tag = str(spec.get("tag", "速報"))
    tf = F(54)
    tw = d.textlength(tag, font=tf)
    d.rectangle([0, y, tw + 80, y + 128], fill=RED)
    d.text((40, y + 32), tag, font=tf, fill="white")
    head = str(spec.get("head", ""))
    d.text((tw + 120, y + 28), head, font=F(60), fill="white")
    sub = str(spec.get("sub", ""))
    if sub:
        d.text((tw + 124, y + 142), sub, font=F(38), fill=INK)
    # 右上の局名ふう（チャンネルの名）
    name = str(spec.get("channel", "世の中の断面図"))
    nf = F(30, 800)
    d.rectangle([W - d.textlength(name, font=nf) - 64, 36,
                 W - 32, 92], fill=(0, 0, 0, 150))
    d.text((W - d.textlength(name, font=nf) - 48, 46), name, font=nf, fill="white")
    when = str(spec.get("when", ""))
    if when:
        wf = F(typo.NOTE, 700)
        d.text((W - d.textlength(when, font=wf) - 48, 100), when, font=wf, fill="#C8D3E4")
    return im.convert("RGB")


def lshape(spec: dict) -> Image.Image:
    """L字。右と下に枠を作り、真ん中を映像のために空ける。

    地震や選挙のときに見る形。情報を出しながら映像も見せたいときに使う。
    """
    im = _bg(spec, dark=float(spec.get("dark", 0.78)), blur=0)
    d = ImageDraw.Draw(im)
    side_w, bottom_h = 520, 260
    d.rectangle([W - side_w, 0, W, H], fill=NAVY + (245,))
    d.rectangle([0, H - bottom_h, W - side_w, H], fill=NAVY + (245,))
    d.rectangle([W - side_w, 0, W - side_w + 6, H], fill=GOLD)
    d.rectangle([0, H - bottom_h, W - side_w, H - bottom_h + 6], fill=GOLD)

    # 右の枠：項目を並べる
    d.text((W - side_w + 36, 40), str(spec.get("side_title", "いま分かっていること")),
           font=F(34), fill=GOLD)
    y = 110
    for it in spec.get("items", [])[:7]:
        d.ellipse([W - side_w + 36, y + 12, W - side_w + 52, y + 28], fill="white")
        for ln in _wrap(d, str(it), F(30, 800), side_w - 110)[:2]:
            d.text((W - side_w + 70, y), ln, font=F(30, 800), fill="white")
            y += 42
        y += 22

    # 下の枠：見出しと添え
    head = str(spec.get("head", ""))
    d.text((48, H - bottom_h + 40), head, font=F(58), fill="white")
    sub = str(spec.get("sub", ""))
    if sub:
        d.text((50, H - bottom_h + 130), sub, font=F(34, 700), fill="#C8D3E4")
    credit = str(spec.get("credit", ""))
    if credit:
        cf = F(typo.NOTE, 600)
        d.text((48, H - 44), credit, font=cf, fill="#8FA3C4")
    return im.convert("RGB")


def voices(spec: dict) -> Image.Image:
    """街の声。属性つきで並べる。顔は出さない（実在の人を出さないため）。"""
    im = _bg(spec, dark=0.3, blur=4)
    d = ImageDraw.Draw(im)
    d.rectangle([64, 60, 76, 150], fill=GOLD)
    d.text((100, 56), str(spec.get("title", "街の声")), font=F(52), fill="white",
           stroke_width=6, stroke_fill=(6, 10, 18))
    note = str(spec.get("note", ""))
    if note:
        d.text((102, 120), note, font=F(typo.NOTE, 700), fill="#C8D3E4")

    items = spec.get("items", [])[:4]
    y = 210
    for it in items:
        text = str(it.get("text", ""))
        who = str(it.get("who", ""))
        f = F(38, 800)
        lines = _wrap(d, text, f, W - 420)[:3]
        bh = 60 + len(lines) * 54
        card = Image.new("RGBA", (W - 220, bh), (0, 0, 0, 0))
        ImageDraw.Draw(card).rounded_rectangle([0, 0, W - 260, bh], radius=16,
                                               fill=(252, 252, 250, 246))
        sh = Image.new("RGBA", (W - 200, bh + 24), (0, 0, 0, 0))
        ImageDraw.Draw(sh).rounded_rectangle([14, 16, W - 246, bh + 16], radius=16,
                                             fill=(0, 0, 0, 150))
        im.alpha_composite(sh.filter(ImageFilter.GaussianBlur(10)), (100, y - 8))
        im.alpha_composite(card, (110, y))
        d = ImageDraw.Draw(im)
        d.rectangle([110, y, 122, y + bh], fill=GOLD)
        ty = y + 22
        for ln in lines:
            d.text((154, ty), "「" + ln + "」" if ln is lines[0] and len(lines) == 1 else ln,
                   font=f, fill=INK)
            ty += 54
        if who:
            wf = F(typo.NOTE, 700)
            d.text((W - 260 - d.textlength(who, font=wf) - 20, y + bh - 44), who,
                   font=wf, fill=(110, 118, 128))
        y += bh + 28
    credit = str(spec.get("credit", ""))
    if credit:
        cf = F(typo.NOTE, 600)
        d.text((W - d.textlength(credit, font=cf) - 60, H - 48), credit, font=cf, fill="#9FB0C9")
    return im.convert("RGB")


def split(spec: dict) -> Image.Image:
    """分割画面。左に実写、右に数字や短い言葉。"""
    im = Image.new("RGBA", (W, H), (12, 20, 34, 255))
    left_w = int(W * 0.56)
    photo = spec.get("photo")
    if photo and Path(str(photo)).exists():
        pic = Image.open(str(photo)).convert("RGB")
        s = max(left_w / pic.width, H / pic.height)
        pic = pic.resize((int(pic.width * s), int(pic.height * s)))
        pic = pic.crop((0, 0, left_w, H))
        pic = ImageEnhance.Brightness(pic).enhance(0.86)
        im.paste(pic, (0, 0))
    d = ImageDraw.Draw(im)
    # 境目の金の線と、右の濃紺
    d.rectangle([left_w, 0, W, H], fill=(16, 26, 44, 255))
    d.rectangle([left_w - 6, 0, left_w, H], fill=GOLD)
    # 左下に説明
    cap = str(spec.get("caption", ""))
    if cap:
        cf = F(30, 800)
        d.rectangle([0, H - 110, left_w - 6, H], fill=(6, 10, 18, 210))
        d.text((40, H - 86), cap, font=cf, fill="white")
    # 右：見出しと数字
    x = left_w + 60
    d.rectangle([x, 90, x + 12, 170], fill=GOLD)
    d.text((x + 34, 86), str(spec.get("title", "")), font=F(44), fill="white")
    y = 230
    for it in spec.get("items", [])[:4]:
        lab, val = str(it.get("label", "")), str(it.get("value", ""))
        d.text((x, y), lab, font=F(28, 800), fill="#9FB0C9")
        size = 76
        probe = ImageDraw.Draw(Image.new("RGB", (1, 1)))
        tw = 0
        for m in UNIT.finditer(val):
            tw += probe.textlength(m.group(0),
                                   font=F(size) if m.group(1) else F(int(size * 0.58), 800))
        while tw > W - x - 80 and size > 34:
            size -= 4
            tw = 0
            for m in UNIT.finditer(val):
                tw += probe.textlength(m.group(0),
                                       font=F(size) if m.group(1) else F(int(size * 0.58), 800))
        xx = x
        base = y + 44 + size * 0.80
        for m in UNIT.finditer(val):
            num, unit = m.group(1), m.group(2)
            if num:
                d.text((xx, y + 44), num, font=F(size), fill="white")
                xx += d.textlength(num, font=F(size))
            else:
                sf = F(int(size * 0.58), 800)
                d.text((xx, base - int(size * 0.58) * 0.80), unit, font=sf, fill="white")
                xx += d.textlength(unit, font=sf)
        note = str(it.get("note", ""))
        if note:
            d.text((x, y + 44 + size + 6), note, font=F(typo.NOTE, 700), fill="#9FB0C9")
        y += size + 110
    credit = str(spec.get("credit", ""))
    if credit:
        cf = F(typo.NOTE, 600)
        d.text((x, H - 54), credit, font=cf, fill="#8FA3C4")
    return im.convert("RGB")


KINDS = {"breaking": breaking, "lshape": lshape, "voices": voices, "split": split}


def draw(spec: dict, out: Path) -> Path:
    kind = spec.get("kind")
    if kind not in KINDS:
        raise SystemExit("知らない種類です: {}（使えるのは {}）".format(kind, " / ".join(KINDS)))
    im = KINDS[kind](spec)
    out.parent.mkdir(parents=True, exist_ok=True)
    im.save(out)
    return out

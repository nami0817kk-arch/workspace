# -*- coding: utf-8 -*-
"""ニュース番組の「画面の作法」、さらに4つ。

    poll     … 世論調査の結果。横棒と大きな％
    recap    … ここまでのおさらい。節の切れ目に挟む
    live     … 中継風。実写の上に「現地」の札と地名・日時
    versus   … 左右の全画面比べ。日本と世界を並べる

どれも 1920x1080 の画面として返す。news2.py と同じ作り。
"""
from __future__ import annotations

import re
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageFont

from danmen import screens, typo

W, H = 1920, 1080
FONT_PATH = "C:/Windows/Fonts/NotoSansJP-VF.ttf"
RED = (206, 32, 36)
NAVY = (18, 32, 62)
GOLD = "#E7B93F"
GOLD_RGB = (231, 185, 63)
INK = (18, 20, 26)
AMBER = (164, 102, 8)        # 文字用。塗りより濃い（白地で 4.6:1）
TEAL = (22, 158, 134)
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


def _head(im: Image.Image, title: str, note: str = "") -> ImageDraw.ImageDraw:
    """左上の見出し。金の縦線＋白抜き。どの様式でも共通。"""
    d = ImageDraw.Draw(im)
    d.rectangle([64, 60, 76, 150], fill=GOLD)
    d.text((100, 56), title, font=F(52), fill="white",
           stroke_width=6, stroke_fill=(6, 10, 18))
    if note:
        d.text((102, 120), note, font=F(typo.NOTE, 700), fill="#C8D3E4")
    return d


def _foot(d: ImageDraw.ImageDraw, credit: str) -> None:
    if credit:
        cf = F(typo.NOTE, 600)
        d.text((W - d.textlength(credit, font=cf) - 60, H - 48), credit, font=cf, fill="#9FB0C9")


def poll(spec: dict) -> Image.Image:
    """世論調査の結果。横棒と大きな％。調査の素性（誰が・いつ・何人）を必ず添える。"""
    im = _bg(spec, dark=0.30, blur=6)
    d = _head(im, str(spec.get("title", "世論調査")), str(spec.get("note", "")))
    items = spec.get("items", [])[:5]
    total = sum(float(i["value"]) for i in items) or 1
    x0 = 160
    bw = 1180
    step = 150
    y = int((H - len(items) * step) / 2) + 40
    # 棒の下地は半透明なので、別の層に描いてから重ねる
    base = Image.new("RGBA", im.size, (0, 0, 0, 0))
    bd = ImageDraw.Draw(base)
    for n in range(len(items)):
        by = y + n * step + 58
        bd.rounded_rectangle([x0, by, x0 + bw, by + 46], radius=8, fill=(255, 255, 255, 56))
    im.alpha_composite(base)
    d = ImageDraw.Draw(im)
    for n, it in enumerate(items):
        pct = float(it["value"]) / total * 100
        focus = bool(it.get("focus"))
        col = AMBER if focus else (TEAL if n == 0 else (108, 124, 150))
        d.text((x0, y), str(it.get("label", "")), font=F(40, 900 if focus else 800),
               fill="white" if focus else "#DCE4F0")
        by = y + 58
        fw = max(int(bw * pct / 100), 12)
        d.rounded_rectangle([x0, by, x0 + fw, by + 46], radius=8, fill=col)
        # ％は棒の右に、数字だけ大きく
        s = "{:.0f}".format(pct)
        nf, uf = F(64), F(32, 800)
        px = x0 + bw + 40
        d.text((px, by - 18), s, font=nf, fill="white")
        d.text((px + d.textlength(s, font=nf) + 4, by + 8), "%", font=uf, fill="#C8D3E4")
        y += step
    _foot(d, str(spec.get("credit", "")))
    return im.convert("RGB")


def recap(spec: dict) -> Image.Image:
    """ここまでのおさらい。節の切れ目に挟んで、視聴者を置いていかない。"""
    im = _bg(spec, dark=0.26, blur=8)
    d = ImageDraw.Draw(im)
    # 中央に紙の板
    bx0, by0, bx1, by1 = 230, 180, W - 230, H - 180
    sh = Image.new("RGBA", (bx1 - bx0 + 80, by1 - by0 + 80), (0, 0, 0, 0))
    ImageDraw.Draw(sh).rounded_rectangle([40, 44, bx1 - bx0 + 40, by1 - by0 + 44],
                                         radius=20, fill=(0, 0, 0, 170))
    im.alpha_composite(sh.filter(ImageFilter.GaussianBlur(16)), (bx0 - 40, by0 - 40))
    d.rounded_rectangle([bx0, by0, bx1, by1], radius=20, fill=(252, 251, 247, 252))
    d.rectangle([bx0, by0, bx1, by0 + 96], fill=NAVY)
    d.rounded_rectangle([bx0, by0, bx1, by0 + 40], radius=20, fill=NAVY)
    d.rectangle([bx0, by0 + 96, bx1, by0 + 102], fill=GOLD)
    title = str(spec.get("title", "ここまでのおさらい"))
    d.text((bx0 + 44, by0 + 18), title, font=F(52), fill="white")
    items = spec.get("items", [])[:4]
    y = by0 + 160
    for n, it in enumerate(items, 1):
        d.ellipse([bx0 + 56, y + 4, bx0 + 112, y + 60], fill=AMBER)
        nf = F(34)
        d.text((bx0 + 56 + (56 - d.textlength(str(n), font=nf)) / 2, y + 12), str(n),
               font=nf, fill="white")
        f = F(40, 900)
        for ln in _wrap(d, str(it.get("text", it) if isinstance(it, dict) else it), f,
                        bx1 - bx0 - 220)[:2]:
            d.text((bx0 + 140, y + 4), ln, font=f, fill=INK)
            y += 52
        note = str(it.get("note", "")) if isinstance(it, dict) else ""
        if note:
            d.text((bx0 + 140, y + 4), note, font=F(typo.NOTE, 600), fill=(110, 118, 128))
            y += 42
        y += 46
    nxt = str(spec.get("next", ""))
    if nxt:
        d.rectangle([bx0 + 56, by1 - 110, bx1 - 56, by1 - 106], fill="#DDE1E8")
        d.text((bx0 + 56, by1 - 88), "このあと　" + nxt, font=F(32, 800), fill=(90, 98, 110))
    return im.convert("RGB")


def live(spec: dict) -> Image.Image:
    """中継風。実写の上に「現地」の札と地名・日時。撮った場所と日を必ず書く。"""
    im = _bg(spec, dark=0.72, blur=0)
    d = ImageDraw.Draw(im)
    # 左上：赤い丸と「現地」
    tag = str(spec.get("tag", "現地"))
    tf = F(40)
    tw = d.textlength(tag, font=tf)
    d.rectangle([64, 60, 64 + tw + 110, 60 + 70], fill=RED)
    d.ellipse([84, 80, 114, 110], fill="white")
    d.text((128, 66), tag, font=tf, fill="white")
    # 左下：地名と日時の2段
    place = str(spec.get("place", ""))
    when = str(spec.get("when", ""))
    y = H - 300
    if place:
        pf = F(66)
        pw = d.textlength(place, font=pf)
        d.rectangle([0, y, pw + 140, y + 100], fill=NAVY + (242,))
        d.rectangle([0, y, 14, y + 100], fill=GOLD)
        d.text((56, y + 12), place, font=pf, fill="white")
    if when:
        wf = F(32, 800)
        ww = d.textlength(when, font=wf)
        d.rectangle([0, y + 104, ww + 110, y + 164], fill=(242, 244, 248, 236))
        d.text((56, y + 114), when, font=wf, fill=INK)
    cap = str(spec.get("caption", ""))
    if cap:
        cf = F(34, 800)
        d.rectangle([0, H - 110, W, H], fill=(6, 10, 18, 200))
        d.text((56, H - 86), cap, font=cf, fill="white")
    credit = str(spec.get("credit", ""))
    if credit:
        cf = F(typo.NOTE, 600)
        d.text((W - d.textlength(credit, font=cf) - 56, H - 44), credit, font=cf, fill="#9FB0C9")
    return im.convert("RGB")


def versus(spec: dict) -> Image.Image:
    """左右の全画面比べ。日本と世界、昔といま。真ん中に金の線と「VS」の代わりの札。"""
    im = Image.new("RGBA", (W, H), (12, 20, 34, 255))
    half = W // 2
    for side, key in ((0, "left"), (1, "right")):
        s = spec.get(key, {})
        photo = s.get("photo")
        tile = Image.new("RGB", (half, H), (18, 30, 52) if side == 0 else (24, 24, 30))
        if photo and Path(str(photo)).exists():
            pic = Image.open(str(photo)).convert("RGB")
            sc = max(half / pic.width, H / pic.height)
            pic = pic.resize((int(pic.width * sc), int(pic.height * sc)))
            ox = (pic.width - half) // 2
            pic = pic.crop((ox, 0, ox + half, H))
            # 元の明るさがまちまちなので、同じ暗さに揃えてから敷く
            g = pic.convert("L").resize((32, 18))
            avg = sum(g.getdata()) / (32 * 18)
            tile = ImageEnhance.Brightness(pic).enhance(min(0.34, 44.0 / max(avg, 1.0)))
        im.paste(tile, (side * half, 0))
    d = ImageDraw.Draw(im)
    d.rectangle([half - 5, 0, half + 5, H], fill=GOLD)
    # 上の見出し
    title = str(spec.get("title", ""))
    if title:
        tf = F(54)
        tw = d.textlength(title, font=tf)
        d.rectangle([(W - tw) / 2 - 40, 50, (W + tw) / 2 + 40, 142], fill=NAVY + (240,))
        d.text(((W - tw) / 2, 62), title, font=tf, fill="white")
    for side, key in ((0, "left"), (1, "right")):
        s = spec.get(key, {})
        cx = half // 2 + side * half
        name = str(s.get("name", ""))
        nf = F(64)
        d.text((cx - d.textlength(name, font=nf) / 2, 230), name, font=nf, fill="white",
               stroke_width=6, stroke_fill=(6, 10, 18))
        val = str(s.get("value", ""))
        if val:
            size = 150
            probe = ImageDraw.Draw(Image.new("RGB", (1, 1)))

            def _w(sz: int) -> float:
                t = 0.0
                for m in UNIT.finditer(val):
                    t += probe.textlength(m.group(0),
                                          font=F(sz) if m.group(1) else F(int(sz * 0.52), 800))
                return t

            while _w(size) > half - 120 and size > 50:
                size -= 6
            xx = cx - _w(size) / 2
            base = 380 + size * 0.80
            col = GOLD_RGB if s.get("focus") else (255, 255, 255)
            for m in UNIT.finditer(val):
                num, unit = m.group(1), m.group(2)
                if num:
                    d.text((xx, 380), num, font=F(size), fill=col,
                           stroke_width=7, stroke_fill=(6, 10, 18))
                    xx += d.textlength(num, font=F(size))
                else:
                    uf = F(int(size * 0.52), 800)
                    d.text((xx, base - int(size * 0.52) * 0.80), unit, font=uf, fill=col,
                           stroke_width=5, stroke_fill=(6, 10, 18))
                    xx += d.textlength(unit, font=uf)
        note = str(s.get("note", ""))
        if note:
            f = F(34, 800)
            yy = 600
            for ln in _wrap(d, note, f, half - 160)[:3]:
                d.text((cx - d.textlength(ln, font=f) / 2, yy), ln, font=f, fill="#DCE4F0",
                       stroke_width=4, stroke_fill=(6, 10, 18))
                yy += 50
    _foot(d, str(spec.get("credit", "")))
    return im.convert("RGB")


KINDS = {"poll": poll, "recap": recap, "live": live, "versus": versus}


def draw(spec: dict, out: Path) -> Path:
    kind = spec.get("kind")
    if kind not in KINDS:
        raise SystemExit("知らない種類です: {}（使えるのは {}）".format(kind, " / ".join(KINDS)))
    im = KINDS[kind](spec)
    out.parent.mkdir(parents=True, exist_ok=True)
    im.save(out)
    return out

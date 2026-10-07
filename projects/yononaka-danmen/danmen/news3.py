# -*- coding: utf-8 -*-
"""ニュース番組の画面、さらに5つ。

    qa         … 問いと答え。Q と A の札で見せる
    points     … きょうのポイント。3つにまとめる（締めで使う）
    glossary   … 用語の解説を画面いっぱいに
    before     … 写真の左右比べ（前と後）
    statement  … 公式の発言の引用。誰が、いつ、どこで言ったかを添える

実在の人の顔は出さない。発言は公式に発表されたものを、出典つきで引くだけにする。
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageFont

from danmen import screens, typo

W, H = 1920, 1080
FONT_PATH = "C:/Windows/Fonts/NotoSansJP-VF.ttf"
GOLD = "#E7B93F"
GOLD_RGB = (231, 185, 63)
NAVY = (18, 32, 62)
GREEN = (16, 140, 118)
RED = (196, 48, 42)
INK = (18, 20, 26)


def F(size: int, weight: int = 900) -> ImageFont.FreeTypeFont:
    # 読めない大きさは作らない。1920 の画面での 28px が、スマホで 5.7pt の下限
    size = max(int(size), typo.MIN_PX)
    f = ImageFont.truetype(FONT_PATH, size)
    try:
        f.set_variation_by_axes([weight])
    except Exception:
        pass
    return f


def _bg(spec: dict, dark: float = 0.28, blur: int = 4) -> Image.Image:
    im = screens.backdrop(spec.get("photo"), dark=dark, blur=blur).convert("RGBA")
    veil = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(veil)
    for y in range(0, 220):
        d.line([(0, y), (W, y)], fill=(5, 9, 16, int(215 * (1 - y / 220))))
    for y in range(H - 260, H):
        d.line([(0, y), (W, y)], fill=(5, 9, 16, int(225 * ((y - (H - 260)) / 260))))
    return Image.alpha_composite(im, veil)


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


def _head(im: Image.Image, text: str, sub: str = "") -> int:
    d = ImageDraw.Draw(im)
    d.rectangle([64, 72, 76, 152], fill=GOLD)
    d.text((100, 68), text, font=F(50), fill="white", stroke_width=6, stroke_fill=(6, 10, 18))
    if sub:
        d.text((102, 132), sub, font=F(26, 700), fill="#C8D3E4")
    return 210


def qa(spec: dict) -> Image.Image:
    """問いと答え。札で見せる。このチャンネルの型にいちばん近い。"""
    im = _bg(spec)
    top = _head(im, str(spec.get("title", "よくある疑問")), str(spec.get("sub", "")))
    d = ImageDraw.Draw(im)
    y = top
    for it in spec.get("items", [])[:3]:
        q, a = str(it.get("q", "")), str(it.get("a", ""))
        qf, af = F(40), F(34, 800)
        qlines = _wrap(d, q, qf, W - 420)[:2]
        alines = _wrap(d, a, af, W - 420)[:3]
        bh = 60 + len(qlines) * 56 + 20 + len(alines) * 48
        card = Image.new("RGBA", (W - 180, bh), (0, 0, 0, 0))
        ImageDraw.Draw(card).rounded_rectangle([0, 0, W - 220, bh], radius=16,
                                               fill=(252, 252, 250, 248))
        sh = Image.new("RGBA", (W - 160, bh + 26), (0, 0, 0, 0))
        ImageDraw.Draw(sh).rounded_rectangle([14, 16, W - 206, bh + 16], radius=16,
                                             fill=(0, 0, 0, 150))
        im.alpha_composite(sh.filter(ImageFilter.GaussianBlur(10)), (90, y - 8))
        im.alpha_composite(card, (100, y))
        d = ImageDraw.Draw(im)
        # Q の札
        d.rounded_rectangle([130, y + 22, 130 + 56, y + 78], radius=10, fill=NAVY)
        d.text((130 + 28 - d.textlength("Q", font=F(36)) / 2, y + 30), "Q", font=F(36), fill="white")
        ty = y + 24
        for ln in qlines:
            d.text((214, ty), ln, font=qf, fill=INK)
            ty += 56
        ty += 14
        d.rounded_rectangle([130, ty + 4, 130 + 56, ty + 60], radius=10, fill=GOLD_RGB)
        d.text((130 + 28 - d.textlength("A", font=F(36)) / 2, ty + 12), "A", font=F(36), fill=INK)
        for ln in alines:
            d.text((214, ty + 6), ln, font=af, fill=(70, 78, 88))
            ty += 48
        y += bh + 28
    credit = str(spec.get("credit", ""))
    if credit:
        cf = F(22, 600)
        d.text((W - d.textlength(credit, font=cf) - 60, H - 48), credit, font=cf, fill="#9FB0C9")
    return im.convert("RGB")


def points(spec: dict) -> Image.Image:
    """きょうのポイント。3つにまとめる。締めで使う。"""
    im = _bg(spec, dark=0.22, blur=6)
    top = _head(im, str(spec.get("title", "きょうのポイント")), str(spec.get("sub", "")))
    d = ImageDraw.Draw(im)
    items = spec.get("items", [])[:3]
    y = top + 20
    for n, it in enumerate(items, 1):
        label = str(it.get("label", ""))
        note = str(it.get("note", ""))
        card = Image.new("RGBA", (W - 200, 170), (0, 0, 0, 0))
        ImageDraw.Draw(card).rounded_rectangle([0, 0, W - 240, 170], radius=16,
                                               fill=(14, 22, 38, 235))
        im.alpha_composite(card, (100, y))
        d = ImageDraw.Draw(im)
        d.rounded_rectangle([100, y, 112, y + 170], fill=GOLD)
        d.ellipse([150, y + 48, 150 + 74, y + 122], fill=GOLD_RGB)
        num = str(n)
        d.text((150 + 37 - d.textlength(num, font=F(44)) / 2, y + 60), num, font=F(44), fill=INK)
        for ln in _wrap(d, label, F(42), W - 480)[:2]:
            d.text((260, y + 36), ln, font=F(42), fill="white")
        if note:
            d.text((262, y + 102), note, font=F(26, 700), fill="#9FB0C9")
        y += 196
    return im.convert("RGB")


def glossary(spec: dict) -> Image.Image:
    """用語の解説を画面いっぱいに。難しい言葉が出たら、ここで止めて説明する。"""
    im = _bg(spec, dark=0.2, blur=7)
    d = ImageDraw.Draw(im)
    word = str(spec.get("word", ""))
    read = str(spec.get("read", ""))
    body = str(spec.get("body", ""))
    cx, cy, cw, chh = 150, 240, W - 300, 520
    card = Image.new("RGBA", (cw + 60, chh + 60), (0, 0, 0, 0))
    ImageDraw.Draw(card).rounded_rectangle([30, 30, cw + 30, chh + 30], radius=20,
                                           fill=(252, 251, 247, 250))
    sh = card.filter(ImageFilter.GaussianBlur(18))
    im.alpha_composite(Image.new("RGBA", card.size, (0, 0, 0, 0)))
    im.paste(Image.new("RGB", card.size, (0, 0, 0)), (cx - 30, cy - 18),
             sh.split()[3].point(lambda v: int(v * 0.6)))
    im.alpha_composite(card, (cx - 30, cy - 30))
    d = ImageDraw.Draw(im)
    d.rectangle([cx, cy, cx + 16, cy + chh], fill=GOLD)
    d.text((cx + 54, cy + 30), "ことばの意味", font=F(26, 800), fill="#B08A20")
    d.text((cx + 54, cy + 76), word, font=F(76), fill=INK)
    if read:
        d.text((cx + 58, cy + 172), read, font=F(28, 700), fill=(120, 128, 138))
    y = cy + 230
    for ln in _wrap(d, body, F(36, 700), cw - 120)[:6]:
        d.text((cx + 54, y), ln, font=F(36, 700), fill=(40, 46, 56))
        y += 54
    credit = str(spec.get("credit", ""))
    if credit:
        cf = F(22, 600)
        d.text((cx + cw - d.textlength(credit, font=cf) - 40, cy + chh - 44), credit,
               font=cf, fill=(130, 136, 146))
    return im.convert("RGB")


def before(spec: dict) -> Image.Image:
    """写真の左右比べ。前と後、日本とよその国、などを並べる。"""
    im = Image.new("RGBA", (W, H), (10, 16, 28, 255))
    d = ImageDraw.Draw(im)
    pics = spec.get("items", [])[:2]
    half = W // 2
    for i, it in enumerate(pics):
        x0 = i * half
        p = it.get("photo")
        if p and Path(str(p)).exists():
            pic = Image.open(str(p)).convert("RGB")
            s = max(half / pic.width, H / pic.height)
            pic = pic.resize((int(pic.width * s), int(pic.height * s)))
            pic = pic.crop((0, 0, half, H))
            pic = ImageEnhance.Brightness(pic).enhance(0.72)
            im.paste(pic, (x0, 0))
        d = ImageDraw.Draw(im)
        # 下に説明の帯
        d.rectangle([x0, H - 250, x0 + half, H], fill=(8, 14, 24, 225))
        d.rectangle([x0 + 50, H - 226, x0 + 62, H - 150], fill=GOLD)
        d.text((x0 + 86, H - 232), str(it.get("label", "")), font=F(46), fill="white")
        val = str(it.get("value", ""))
        if val:
            d.text((x0 + 86, H - 158), val, font=F(60), fill=GOLD)
        note = str(it.get("note", ""))
        if note:
            d.text((x0 + 88, H - 80), note, font=F(26, 700), fill="#9FB0C9")
    d.rectangle([half - 4, 0, half + 4, H], fill=GOLD)
    title = str(spec.get("title", ""))
    if title:
        tf = F(54)
        tw = d.textlength(title, font=tf)
        d.rectangle([(W - tw) / 2 - 40, 60, (W + tw) / 2 + 40, 150], fill=(8, 14, 24, 235))
        d.text(((W - tw) / 2, 68), title, font=tf, fill="white")
    credit = str(spec.get("credit", ""))
    if credit:
        cf = F(22, 600)
        d.text((W - d.textlength(credit, font=cf) - 40, 170), credit, font=cf, fill="#9FB0C9")
    return im.convert("RGB")


def statement(spec: dict) -> Image.Image:
    """公式の発言を引く。誰が、いつ、どこで言ったかを必ず添える。顔は出さない。"""
    im = _bg(spec, dark=0.24, blur=5)
    d = ImageDraw.Draw(im)
    text = str(spec.get("text", ""))
    who = str(spec.get("who", ""))
    role = str(spec.get("role", ""))
    when = str(spec.get("when", ""))
    f = F(46, 800)
    lines = _wrap(d, text, f, W - 440)[:4]
    bh = 250 + len(lines) * 68      # 発言者と肩書の分も入れる
    y0 = (H - bh) // 2 - 40
    card = Image.new("RGBA", (W - 260, bh), (0, 0, 0, 0))
    ImageDraw.Draw(card).rounded_rectangle([0, 0, W - 300, bh], radius=18,
                                           fill=(252, 251, 247, 250))
    im.alpha_composite(card, (130, y0))
    d = ImageDraw.Draw(im)
    d.rectangle([130, y0, 146, y0 + bh], fill=NAVY)
    d.text((190, y0 + 28), "“", font=F(90), fill=(200, 205, 212))
    y = y0 + 84
    for ln in lines:
        d.text((190, y), ln, font=f, fill=INK)
        y += 68
    # 誰の発言か
    if who:
        d.rectangle([190, y + 16, 190 + 10, y + 70], fill=GOLD)
        d.text((216, y + 12), who, font=F(36), fill=INK)
        if role:
            d.text((218, y + 60), role, font=F(24, 700), fill=(120, 128, 138))
    if when:
        wf = F(24, 700)
        d.text((W - 300 - d.textlength(when, font=wf) + 130 - 40, y + 16), when,
               font=wf, fill=(120, 128, 138))
    credit = str(spec.get("credit", ""))
    if credit:
        cf = F(22, 600)
        d.text((W - d.textlength(credit, font=cf) - 60, H - 48), credit, font=cf, fill="#9FB0C9")
    return im.convert("RGB")


KINDS = {"qa": qa, "points": points, "glossary": glossary, "before": before,
         "statement": statement}


def draw(spec: dict, out: Path) -> Path:
    kind = spec.get("kind")
    if kind not in KINDS:
        raise SystemExit("知らない種類です: {}（使えるのは {}）".format(kind, " / ".join(KINDS)))
    im = KINDS[kind](spec)
    out.parent.mkdir(parents=True, exist_ok=True)
    im.save(out)
    return out

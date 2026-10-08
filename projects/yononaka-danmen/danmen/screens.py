# -*- coding: utf-8 -*-
"""図ではない「画面」を作る。

    title     … 冒頭のタイトル（最初の5秒。離脱の大半はここ）
    chapter   … 節の中扉（30分を9つに区切る）
    outro     … 締め（次回の問いと、登録の誘い）
    thumbnail … サムネイル（クリックされなければ中身は関係ない）
    quote     … 原文の引用（条文・報告書の一節）
    term      … 用語の札（画面の隅に出す小さな説明）

背景の実写は assets/photos と assets/videos から。暗く落として使う。
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageFont

from danmen import typo

W, H = 1920, 1080
GOLD = "#E7B93F"
CYAN = "#5BD6F5"
GREEN = "#19B894"
NAVY = (20, 34, 64)
BASE = pathlib_base = Path(r"C:/Users/なみ/dev/output/yononaka-danmen/assets")
FONT_PATH = "C:/Windows/Fonts/NotoSansJP-VF.ttf"


def F(size: int, weight: int = 900) -> ImageFont.FreeTypeFont:
    # 読めない大きさは作らない。1920 の画面での 28px が、スマホで 5.7pt の下限
    size = max(int(size), typo.MIN_PX)
    f = ImageFont.truetype(FONT_PATH, size)
    try:
        f.set_variation_by_axes([weight])
    except Exception:
        pass
    return f


def backdrop(photo: Path | None, dark: float = 0.33, blur: int = 3) -> Image.Image:
    """背景。実写があれば暗く落として使い、無ければ濃紺のグラデ。"""
    if photo and Path(photo).exists():
        im = Image.open(photo).convert("RGB").resize((W, H))
        im = ImageEnhance.Brightness(im).enhance(dark)
        im = ImageEnhance.Color(im).enhance(0.72)
        return im.filter(ImageFilter.GaussianBlur(blur))
    im = Image.new("RGB", (W, H), (14, 22, 38))
    d = ImageDraw.Draw(im)
    for y in range(H):
        t = y / H
        d.line([(0, y), (W, y)], fill=(int(14 + 14 * t), int(22 + 18 * t), int(38 + 28 * t)))
    return im


def _veil(im: Image.Image, top: int = 250, bottom: int = 340) -> Image.Image:
    veil = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(veil)
    for y in range(0, top):
        d.line([(0, y), (W, y)], fill=(5, 9, 16, int(225 * (1 - y / top))))
    for y in range(H - bottom, H):
        d.line([(0, y), (W, y)], fill=(5, 9, 16, int(238 * ((y - (H - bottom)) / bottom))))
    return Image.alpha_composite(im.convert("RGBA"), veil).convert("RGB")


def _logo(im: Image.Image, x: int, y: int, box: int = 86) -> None:
    p = BASE / "brand" / "logo.png"
    if p.exists():
        lg = Image.open(p).convert("RGBA")
        lg.thumbnail((box, box))
        im.paste(lg, (x, y), lg)


def _outlined(d, text: str, x: int, y: int, font, fill, stroke=14, stroke_fill=(6, 10, 18)) -> None:
    d.text((x, y), text, font=font, fill=fill, stroke_width=stroke, stroke_fill=stroke_fill)


def title(spec: dict) -> Image.Image:
    """冒頭。問いを画面いっぱいに出す。"""
    im = _veil(backdrop(spec.get("photo"), dark=0.30), top=200, bottom=240)
    d = ImageDraw.Draw(im)
    _logo(im, 54, 44)
    d = ImageDraw.Draw(im)
    d.text((158, 48), "日本のなぜ", font=F(30, 800), fill="#D6E0F0")
    d.text((158, 86), "ニュースを数字で切る", font=F(typo.NOTE, 500), fill="#8FA3C4")

    lines = spec.get("lines", [])
    sizes = [96] * len(lines)
    total = sum(s + 30 for s in sizes)
    y = (H - total) // 2
    for ln, size in zip(lines, sizes):
        parts = ln if isinstance(ln, list) else [(ln, "white")]
        x = 110
        place = []
        for t, c in parts:
            f = F(size)
            place.append((t, c, f, x))
            x += d.textlength(t, font=f)
        for t, c, f, px in place:
            _outlined(d, t, px, y, f, (6, 10, 18), stroke=16)
        for t, c, f, px in place:
            if c != "white":
                d.text((px, y), t, font=f, fill=(6, 10, 18), stroke_width=5, stroke_fill=GOLD)
        for t, c, f, px in place:
            d.text((px, y), t, font=f, fill=c)
        y += size + 30
    sub = spec.get("sub", "")
    if sub:
        d.text((114, y + 10), sub, font=F(32, 700), fill="#C6D2E4")
    return im


def chapter(spec: dict) -> Image.Image:
    """節の中扉。何節目で、何を見るのかを大きく出す。"""
    im = _veil(backdrop(spec.get("photo"), dark=0.22, blur=6), top=160, bottom=200)
    d = ImageDraw.Draw(im)
    no = str(spec.get("no", ""))
    name = str(spec.get("name", ""))
    lead = str(spec.get("lead", ""))
    d.rounded_rectangle([W // 2 - 420, H // 2 - 170, W // 2 + 420, H // 2 + 170],
                        radius=20, fill=(10, 16, 28), outline=GOLD, width=3)
    f = F(150)
    d.text((W // 2 - d.textlength(no, font=f) / 2, H // 2 - 150), no, font=f, fill=GREEN)
    f2 = F(58)
    d.text((W // 2 - d.textlength(name, font=f2) / 2, H // 2 + 20), name, font=f2, fill="white")
    if lead:
        f3 = F(28, 600)
        d.text((W // 2 - d.textlength(lead, font=f3) / 2, H // 2 + 104), lead,
               font=f3, fill="#9FB0C9")
    return im


def quote(spec: dict) -> Image.Image:
    """原文の引用。条文や報告書の一節を、出典つきで見せる。"""
    im = _veil(backdrop(spec.get("photo"), dark=0.26), top=200, bottom=260)
    d = ImageDraw.Draw(im)
    body = str(spec.get("text", ""))
    src = str(spec.get("source", ""))
    pad = 70
    box_w = W - pad * 2
    f = F(44, 700)
    lines, cur = [], ""
    for ch in body:
        cur += ch
        if d.textlength(cur, font=f) > box_w - 160 or ch == "\n":
            lines.append(cur.rstrip("\n"))
            cur = ""
    if cur:
        lines.append(cur)
    h = 150 + len(lines) * 68
    y0 = (H - h) // 2
    d.rounded_rectangle([pad, y0, W - pad, y0 + h], radius=18, fill=(252, 251, 247))
    d.rectangle([pad, y0, pad + 14, y0 + h], fill=GOLD)
    d.text((pad + 50, y0 + 26), "原文", font=F(typo.NOTE, 800), fill="#B08A20")
    y = y0 + 76
    for ln in lines:
        d.text((pad + 50, y), ln, font=f, fill="#141C26")
        y += 68
    if src:
        d.text((pad + 50, y0 + h - 48), src, font=F(typo.NOTE, 600), fill="#6B7684")
    return im


def term(im: Image.Image, word: str, mean: str) -> Image.Image:
    """用語の札。右上に小さく出す（画面に重ねる）。"""
    d = ImageDraw.Draw(im)
    f1, f2 = F(28, 900), F(typo.NOTE, 600)
    w = max(d.textlength(word, font=f1), d.textlength(mean, font=f2)) + 60
    x, y = W - w - 50, 130
    d.rounded_rectangle([x, y, x + w, y + 104], radius=10, fill=(252, 251, 247))
    d.rectangle([x, y, x + 10, y + 104], fill=CYAN)
    d.text((x + 28, y + 16), word, font=f1, fill="#141C26")
    d.text((x + 28, y + 58), mean, font=f2, fill="#6B7684")
    return im


def outro(spec: dict) -> Image.Image:
    """締め。次回の問いと、登録の誘い。右側は YouTube の終了画面のために空ける。"""
    im = _veil(backdrop(spec.get("photo"), dark=0.26, blur=5), top=180, bottom=220)
    d = ImageDraw.Draw(im)
    _logo(im, 110, 150, box=120)
    d = ImageDraw.Draw(im)
    d.text((110, 300), "次回", font=F(32, 800), fill=GOLD)
    nxt = str(spec.get("next", ""))
    f = F(56)
    x, y = 110, 350
    for ln in [nxt[i:i + 16] for i in range(0, len(nxt), 16)][:3]:
        d.text((x, y), ln, font=f, fill="white")
        y += 76
    d.text((110, y + 30), "チャンネル登録で、次の断面も見られます",
           font=F(28, 700), fill="#C6D2E4")
    return im


def thumbnail(spec: dict) -> Image.Image:
    """サムネイル。小さくても読めるよう、文字は画面の3分の1を占める。"""
    im = backdrop(spec.get("photo"), dark=0.40, blur=1)
    veil = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    vd = ImageDraw.Draw(veil)
    for y in range(H):
        vd.line([(0, y), (W, y)], fill=(5, 9, 16, int(150 * (y / H))))
    im = Image.alpha_composite(im.convert("RGBA"), veil).convert("RGB")
    d = ImageDraw.Draw(im)
    big = spec.get("big", [])
    y = 150
    for ln in big:
        parts = ln if isinstance(ln, list) else [(ln, "white")]
        x = 80
        place = []
        for t, c in parts:
            f = F(132)
            place.append((t, c, f, x))
            x += d.textlength(t, font=f)
        for t, c, f, px in place:
            d.text((px, y), t, font=f, fill=(6, 10, 18), stroke_width=22, stroke_fill=(6, 10, 18))
        for t, c, f, px in place:
            if c != "white":
                d.text((px, y), t, font=f, fill=(6, 10, 18), stroke_width=8, stroke_fill=GOLD)
        for t, c, f, px in place:
            d.text((px, y), t, font=f, fill=c)
        y += 160
    note = str(spec.get("note", ""))
    if note:
        d.rounded_rectangle([80, y + 20, 80 + d.textlength(note, font=F(44, 800)) + 60, y + 110],
                            radius=10, fill=GOLD)
        d.text((110, y + 38), note, font=F(44, 800), fill="#141C26")
    ch = BASE / "characters" / "katari.png"
    if ch.exists():
        c = Image.open(ch).convert("RGBA")
        c = c.crop((0, 0, c.width, int(c.height * 0.30)))
        s = 520 / c.height
        c = c.resize((int(c.width * s), 520))
        im.paste(c, (W - c.width - 40, H - 520), c)
    return im


KINDS = {"title": title, "chapter": chapter, "quote": quote, "outro": outro,
         "thumbnail": thumbnail}


def draw(kind: str, spec: dict, out: Path) -> Path:
    if kind not in KINDS:
        raise SystemExit("画面の種類「{}」は知りません。使えるのは {}".format(kind, " / ".join(KINDS)))
    im = KINDS[kind](spec)
    out.parent.mkdir(parents=True, exist_ok=True)
    im.save(out)
    return out


def agenda(spec: dict) -> Image.Image:
    """冒頭の目次。30分で何を見るのかを最初に示す。

    「あと何があるか」が見えると、途中で切られにくい。
    """
    im = _veil(backdrop(spec.get("photo"), dark=0.24, blur=5), top=180, bottom=200)
    d = ImageDraw.Draw(im)
    _logo(im, 64, 44, box=72)
    d = ImageDraw.Draw(im)
    d.text((152, 50), "日本のなぜ", font=F(typo.NOTE, 800), fill="#D6E0F0")
    d.text((64, 150), str(spec.get("title", "今日みる断面")), font=F(50), fill="white")
    d.line([(64, 230), (W - 64, 230)], fill=GOLD, width=3)

    items = spec.get("items", [])[:6]
    y = 280
    for i, it in enumerate(items, 1):
        col = GREEN if i == 1 else (70, 96, 150)
        d.rounded_rectangle([64, y, 134, y + 70], radius=10, fill=col)
        num = "{:02d}".format(i)
        d.text((64 + 35 - d.textlength(num, font=F(34)) / 2, y + 16), num, font=F(34), fill="white")
        d.text((162, y + 8), str(it), font=F(38), fill="white")
        y += 96
    d.text((64, y + 20), "出典はすべて画面に出します", font=F(typo.NOTE, 700), fill="#9FB0C9")
    return im


KINDS["agenda"] = agenda

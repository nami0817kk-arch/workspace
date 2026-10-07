"""つむぎの「寄り」：聞き手を腰から上で大きく出し、集中線と大きな数字を出す（その行のあいだだけ）。

    - 聞き: 少なっ！ 天下人なのに？
      reaction: {number: "100人", lead: "信長の供は", say: "少なっ！ 天下人なのに？"}

2026-10-07、別チャンネル「世の中の断面図」の talk.reaction から移した。数字の山場で1枚だけ挟むと、
いつもの下の隅の小さい2人と画の大きさが変わるので「新しいもの」になる。毎回使うと安くなるので
**1本に2回まで**（check が知らせる）。このあいだ、下の小さい2人・メモ・肖像・年表・図は隠す。
立ち絵は config の cast の聞き手（ヘルメット付き）の「驚き」の顔（faces が無ければ1枚の立ち絵）。

    number  大きく出す数字（数字は金で大きく、単位は白で半分の大きさ）。必ず書く
    lead    数字の上の小さな見出し（任意）
    say     数字の下の吹き出し（任意。字幕と同じ文なら省いてよい）
    who     誰を大きく出すか（既定は 聞き）
"""
from __future__ import annotations

import json
import math

from PIL import Image, ImageDraw, ImageFilter

from .figures import fit_number, number_width, put_number

GOLD = (214, 178, 110)
NUM_GOLD = (236, 196, 96)
INK = (244, 236, 220)
WAIST = 0.47          # 立ち絵の上から何割を見せるか（腰から上。ヘルメットの上端から数える）
SHOW_H = 940          # 見せる部分の高さ（px、1080 の画面で）
RIGHT = 70            # 右の余白
from .check import REACTION_MAX as MAX_PER_EPISODE  # noqa: E402  1本に何回まで（目安は check.py の頭）


def spec_of(raw) -> dict:
    return json.loads(raw) if isinstance(raw, str) else dict(raw)


def _ease(t: float) -> float:
    return 0.5 - 0.5 * math.cos(math.pi * max(0.0, min(1.0, t)))


def backdrop(painter, img: Image.Image, raw, t: float = 1.0) -> Image.Image:
    """背景を暗く落とし、集中線・見出し・大きな数字を描く（立ち絵より下の層）。t で数字が弾んで出る。"""
    spec = spec_of(raw)
    W, H = img.size
    img = img.copy()
    img.alpha_composite(Image.new("RGBA", img.size, (10, 8, 6, 170)))
    rays = Image.new("RGBA", img.size, (0, 0, 0, 0))
    rd = ImageDraw.Draw(rays)
    cx, cy = W * 0.70, H * 0.42                          # 立ち絵の顔のあたりから外へ
    a = int(34 * min(1.0, 0.3 + t))
    for i in range(48):
        ang = i / 48 * math.tau + 0.07
        r0 = 300 + (i % 3) * 40
        rd.line([(cx + math.cos(ang) * r0, cy + math.sin(ang) * r0),
                 (cx + math.cos(ang) * 1700, cy + math.sin(ang) * 1700)], fill=(255, 236, 200, a), width=10)
    img.alpha_composite(rays.filter(ImageFilter.GaussianBlur(3)))
    dr = ImageDraw.Draw(img, "RGBA")
    x = 120
    lead = spec.get("lead", "")
    if lead:
        dr.text((x, 350), lead, font=painter.font("serif", 56, bold=True), fill=INK, anchor="ls",
                stroke_width=5, stroke_fill=(12, 10, 8))
    num = spec.get("number", "")
    if num:
        e = _ease(min(1.0, t / 0.35))                    # 最初の3分の1で、少し行き過ぎて戻る
        pop = 0.7 + 0.42 * math.sin(math.pi / 2 * e) - 0.12 * e if t < 1 else 1.0
        full = fit_number(painter, num, 250, 1020, floor=90)
        size = max(40, int(full * pop) // 4 * 4)
        base = 380 + full * 0.92
        w = number_width(painter, num, size)
        x0 = x + (number_width(painter, num, full) - w) / 2
        layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
        put_number(painter, ImageDraw.Draw(layer, "RGBA"), x0, base - (full - size) * 0.4, num, size, NUM_GOLD,
                   stroke=12, stroke_fill=(12, 10, 8), unit_fill=(255, 255, 255))
        if t < 1:
            layer.putalpha(layer.split()[3].point(lambda v: int(v * min(1.0, e * 1.6))))
        img.alpha_composite(layer)
    return img


def figure(painter, who: str, tone: str = "驚き", mouth: bool = False, blink: bool = False) -> Image.Image:
    """腰から上の大きな立ち絵。cast の faces に「驚き」の顔があればそれ、無ければ1枚の立ち絵。"""
    key = ("react", who, tone, mouth, blink, painter.H)
    if key not in painter._images:
        cast = painter.config["cast"][who]
        src = None
        if cast.get("faces"):
            from .faces import face_key
            path = painter.assets / cast["faces"] / f"{face_key(tone, mouth, blink)}.png"
            if path.exists():
                src = Image.open(path).convert("RGBA")
        if src is None:
            src = painter.image(cast["image"])
        src = src.crop(src.getbbox())
        show = int(SHOW_H * painter.H / 1080)
        full = int(show / WAIST)
        im = src.resize((max(1, int(src.width * full / src.height)), full), Image.LANCZOS)
        painter._images[key] = im.crop((0, 0, im.width, show))
    return painter._images[key]


def put_figure(painter, img: Image.Image, raw, talking: bool, mouth: bool, blink: bool, hop: float) -> None:
    """立ち絵を右に大きく置き、縁を少し光らせ、吹き出し（say）を左に出す。"""
    spec = spec_of(raw)
    who = spec.get("who") or "聞き"
    ch = figure(painter, who, "驚き", mouth and talking, blink)
    W, H = img.size
    lift = int(18 * math.sin(math.pi * hop)) if talking else 0
    x, y = W - ch.width - RIGHT, H - ch.height + 10 - lift
    glow = Image.new("RGBA", img.size, (0, 0, 0, 0))                # 縁の光（暗い背景から浮かせる）
    a = ch.split()[3].point(lambda v: 140 if v > 40 else 0)
    glow.paste(Image.new("RGBA", ch.size, (255, 232, 180, 255)), (x, y), a)
    img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(14)))
    img.alpha_composite(ch, (x, y))
    say = spec.get("say", "")
    if say:
        bubble(painter, img, say, 120, 690)


def bubble(painter, img: Image.Image, text: str, x: int, y: int) -> None:
    """白い吹き出し。尾は右（立ち絵のほう）へ短く。"""
    from .subs import wrap_balanced
    f = painter.font("gothic", 46)
    rows = wrap_balanced(text, f, 760)[:2]
    w = int(max(f.getlength(r) for r in rows)) + 64
    h = 58 * len(rows) + 40
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    d.rounded_rectangle([x + 6, y + 8, x + w + 6, y + h + 8], radius=26, fill=(0, 0, 0, 130))
    layer = layer.filter(ImageFilter.GaussianBlur(6))
    d = ImageDraw.Draw(layer)
    tip = (x + w + 56, y + h * 0.5)
    d.polygon([(x + w - 4, y + h * 0.3), (x + w - 4, y + h * 0.7), tip], fill=(255, 252, 244, 255))
    d.rounded_rectangle([x, y, x + w, y + h], radius=26, fill=(255, 252, 244, 255), outline=(60, 44, 28, 255), width=4)
    d.polygon([(x + w - 6, y + h * 0.3 + 4), (x + w - 6, y + h * 0.7 - 4), (x + w + 4, y + h * 0.5)],
              fill=(255, 252, 244, 255))
    for k, r in enumerate(rows):
        d.text((x + 32, y + 20 + 58 * k), r, font=f, fill=(30, 22, 14))
    img.alpha_composite(layer)

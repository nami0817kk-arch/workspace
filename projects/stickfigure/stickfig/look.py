"""アニメの「見た目」を作る: 色つきの流線背景・特大の斬撃の弧・顔(目)・色の閃き。

参考(2026-10-19 に6本を見た)は、寄りの画・彩度の高い光・主役のような特大の効果で作られていた。
当方は引きの全身・灰色の洞窟・効果は控えめだった。ここはその差を埋める合成側の処理。
"""
from __future__ import annotations

import math
import random
from typing import Dict, Tuple

from PIL import Image, ImageDraw, ImageFilter

from . import camera, fk

W, H = camera.W, camera.H

# 色(上, 下, 流線)。カットごとに回す
PALETTES = [
    ((255, 120, 30), (150, 20, 20), (255, 235, 170)),     # 橙〜赤
    ((40, 200, 255), (20, 40, 150), (230, 250, 255)),     # 水色〜青
    ((220, 60, 255), (70, 10, 120), (255, 220, 255)),     # 紫
    ((255, 230, 60), (200, 90, 10), (255, 255, 220)),     # 黄
]


def streak_bg(f: int, hue: int, angle: float = -0.35) -> Image.Image:
    """色のグラデーション+斜めの流線(カットごとに入れ替わる)の背景。"""
    top, bot, line = PALETTES[hue % len(PALETTES)]
    base = Image.new("RGB", (W, H))
    d = ImageDraw.Draw(base)
    for y in range(0, H, 4):
        t = y / H
        d.rectangle([0, y, W, y + 4], fill=tuple(int(top[i] * (1 - t) + bot[i] * t) for i in range(3)))
    ov = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    od = ImageDraw.Draw(ov)
    rnd = random.Random(f // 2 * 7 + hue)
    ux, uy = math.cos(angle), math.sin(angle)
    for _ in range(46):
        cx, cy = rnd.uniform(-100, W + 100), rnd.uniform(-100, H + 100)
        ln = rnd.uniform(260, 900)
        w = rnd.choice((2, 3, 5, 8, 14))
        al = int(rnd.uniform(60, 200))
        od.line([cx, cy, cx + ux * ln, cy + uy * ln], fill=(*line, al), width=w)
    dark = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    dd = ImageDraw.Draw(dark)
    for _ in range(22):                      # 暗い筋(コントラスト)
        cx, cy = rnd.uniform(-100, W + 100), rnd.uniform(-100, H + 100)
        ln = rnd.uniform(200, 700)
        dd.line([cx, cy, cx + ux * ln, cy + uy * ln], fill=(10, 0, 20, 150), width=rnd.choice((6, 12, 22)))
    out = base.convert("RGBA")
    out.alpha_composite(dark)
    out.alpha_composite(ov)
    return out


def slash_arc(cx: float, cy: float, age: int, nb: int, flip: int = 1, col=(170, 245, 255)) -> Image.Image:
    """特大の斬撃の弧(三日月)。age が進むと、振り抜く向きに回りながら薄れる。"""
    ov = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    t = min(1.0, age / nb)
    R = 430 + 90 * t
    a0 = math.radians(-100 + 80 * t) * flip
    a1 = math.radians(40 + 80 * t) * flip
    n = 40
    outer, inner = [], []
    for i in range(n + 1):
        u = i / n
        a = a0 + (a1 - a0) * u
        th = math.sin(math.pi * u) * (70 * (1 - 0.6 * t))        # 中央ほど太い
        outer.append((cx + math.cos(a) * (R + th * 0.4), cy + math.sin(a) * (R + th * 0.4) * 0.55))
        inner.append((cx + math.cos(a) * (R - th), cy + math.sin(a) * (R - th) * 0.55))
    poly = outer + inner[::-1]
    al = int(255 * (1 - t) ** 0.6)
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(glow).polygon(poly, fill=(*col, int(al * 0.9)))
    glow = glow.filter(ImageFilter.GaussianBlur(26))
    ov.alpha_composite(glow)
    ov.alpha_composite(glow)
    ImageDraw.Draw(ov).polygon(poly, fill=(255, 255, 255, al))
    return ov


def shock_ring(cx: float, cy: float, age: int, nb: int, col=(255, 200, 80)) -> Image.Image:
    ov = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    t = min(1.0, age / nb)
    r = 60 + 420 * t
    d = ImageDraw.Draw(ov)
    al = int(255 * (1 - t))
    d.ellipse([cx - r, cy - r * 0.55, cx + r, cy + r * 0.55], outline=(*col, al), width=int(26 * (1 - t) + 4))
    return ov.filter(ImageFilter.GaussianBlur(2))


def eyes(plan: dict, f: int, img: Image.Image) -> None:
    """顔(目)を、頭の位置に描く。face: fight=つり目で睨む / pain=ぎゅっと閉じる / ko=× / win=にっこり。"""
    d = ImageDraw.Draw(img)
    cam = plan["frames"][f]["cam"]
    for who, a in plan["actors"].items():
        p = plan["frames"][f]["actors"][who]
        s = 1 if a.get("facing", 1) >= 0 else -1
        sk = fk.skeleton(p, s, p["root_x"], a.get("scale", 1.0))
        hx, hz = sk["head"]
        r = sk["head_r"]
        face = p.get("face", "fight")
        pts = []
        for ex, ey in ((0.06, -0.20), (0.15, -0.16)):
            X, Z = camera.project(cam, hx + s * r * ex / 0.215 * 1.0, -r * 0.93 * (abs(ey) / 0.20), hz + r * 0.12)[:2]
            pts.append((X, Z))
        k = camera.px_per_unit(cam) * r / 0.215 * 0.026
        for i, (X, Z) in enumerate(pts):
            ang = -0.45 * s if i == 0 else -0.3 * s
            if face == "fight":
                d.ellipse([X - 4.2 * k, Z - 3.4 * k, X + 4.2 * k, Z + 3.4 * k], fill=(255, 255, 255))
                d.ellipse([X - 1.9 * k + s * 1.0 * k, Z - 1.9 * k, X + 1.9 * k + s * 1.0 * k, Z + 1.9 * k], fill=(10, 10, 10))
                d.line([X - 5.5 * k, Z - 4.6 * k + (3.2 * k if s * (-1 if i == 0 else 1) > 0 else 0), X + 5.5 * k, Z - 4.6 * k + (0 if s * (-1 if i == 0 else 1) > 0 else 3.2 * k)],
                       fill=(10, 10, 10), width=max(2, int(1.8 * k)))
            elif face == "pain":
                d.line([X - 4 * k, Z - 2.5 * k, X + 3 * k, Z], fill=(10, 10, 10), width=max(2, int(1.8 * k)))
                d.line([X - 4 * k, Z + 2.5 * k, X + 3 * k, Z], fill=(10, 10, 10), width=max(2, int(1.8 * k)))
            elif face == "ko":
                d.line([X - 3.5 * k, Z - 3.5 * k, X + 3.5 * k, Z + 3.5 * k], fill=(10, 10, 10), width=max(2, int(1.8 * k)))
                d.line([X - 3.5 * k, Z + 3.5 * k, X + 3.5 * k, Z - 3.5 * k], fill=(10, 10, 10), width=max(2, int(1.8 * k)))
            else:
                d.arc([X - 4 * k, Z - 3 * k, X + 4 * k, Z + 3 * k], 200, 340, fill=(10, 10, 10), width=max(2, int(1.8 * k)))


def charge_aura(plan: dict, f: int, who: str, age01: float, col=(120, 230, 255)) -> Tuple[Image.Image, float]:
    """必殺技の溜め: 人物のまわりに光の柱と上昇する粒、広がる輪。age01=0→1(溜めの進み)。返り値は(重ねる画像, 背景を暗くする量)。"""
    cam = plan["frames"][f]["cam"]
    a = plan["actors"][who]
    p = plan["frames"][f]["actors"][who]
    s = 1 if a.get("facing", 1) >= 0 else -1
    sk = fk.skeleton(p, s, p["root_x"], a.get("scale", 1.0))
    hx, hz = sk["hip"]
    cx, cy = camera.project(cam, hx, 0.0, hz + 0.1)[:2]
    u = camera.px_per_unit(cam)
    rnd = random.Random(f)
    ov = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(ov)
    pulse = 0.75 + 0.25 * math.sin(f * 1.7)
    for i in range(34):                                   # 上へ立つ光の筋
        x = cx + rnd.uniform(-0.55, 0.55) * u
        h = rnd.uniform(0.8, 2.6) * u * (0.4 + age01)
        y0 = cy + rnd.uniform(0.0, 0.9) * u
        w = rnd.choice((2, 3, 5, 8))
        d.line([x, y0, x + rnd.uniform(-10, 10), y0 - h], fill=(*col, int(rnd.uniform(90, 220) * pulse)), width=w)
    for i in range(26):                                   # 上昇する粒
        x = cx + rnd.uniform(-0.9, 0.9) * u
        y = cy - ((rnd.random() + f * 0.05 * rnd.uniform(0.6, 1.4)) % 1.0) * 2.4 * u + 0.5 * u
        r = rnd.uniform(2, 6)
        d.ellipse([x - r, y - r, x + r, y + r], fill=(255, 255, 255, 230))
    glow = ov.filter(ImageFilter.GaussianBlur(10))
    out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    halo = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    r0 = (0.9 + 0.5 * age01) * u * pulse
    ImageDraw.Draw(halo).ellipse([cx - r0, cy - r0 * 1.6, cx + r0, cy + r0 * 0.9], fill=(*col, int(60 + 60 * age01)))
    out.alpha_composite(halo.filter(ImageFilter.GaussianBlur(40)))
    out.alpha_composite(glow)
    out.alpha_composite(ov)
    for k in range(2):                                    # 足もとから広がる輪
        t = (age01 * 1.6 + k * 0.5) % 1.0
        rr = (0.4 + 1.8 * t) * u
        ImageDraw.Draw(out).ellipse([cx - rr, cy + 0.85 * u - rr * 0.3, cx + rr, cy + 0.85 * u + rr * 0.3], outline=(*col, int(230 * (1 - t))), width=4)
    return out, 0.55 * min(1.0, age01 * 3)


def sweep_arc(pts: list, age: int, nb: int, col=(170, 245, 255)) -> Image.Image:
    """剣先が実際に通った道(画面上の点列)に沿う、特大の斬撃の弧。中ほどが太く、端は細い。"""
    ov = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    if len(pts) < 3:
        return ov
    t = min(1.0, age / nb)
    n = len(pts)
    left, right = [], []
    for i, (x, y) in enumerate(pts):
        x0, y0 = pts[max(0, i - 1)]
        x1, y1 = pts[min(n - 1, i + 1)]
        dx, dy = x1 - x0, y1 - y0
        ln = math.hypot(dx, dy) or 1.0
        nx, ny = -dy / ln, dx / ln
        w = math.sin(math.pi * (i + 0.5) / n) * (46 * (1 - 0.7 * t)) + 2
        left.append((x + nx * w, y + ny * w))
        right.append((x - nx * w * 0.35, y - ny * w * 0.35))
    poly = left + right[::-1]
    al = int(255 * (1 - t) ** 0.6)
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(glow).polygon(poly, fill=(*col, int(al * 0.9)))
    glow = glow.filter(ImageFilter.GaussianBlur(18))
    ov.alpha_composite(glow)
    ImageDraw.Draw(ov).polygon(poly, fill=(255, 255, 255, al))
    return ov


def sparks(cx: float, cy: float, age: int, u: float, seed: int, col=(255, 230, 120), n: int = 16, spread: float = 1.0) -> Image.Image:
    """火花: 命中点から飛び散る短い筋。放物線で落ち、尾を引いて消える。u は 1 単位の画素数(距離の基準)。"""
    ov = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    if age < 0:
        return ov
    d = ImageDraw.Draw(ov)
    rnd = random.Random(seed)
    tt = age / 30.0
    for i in range(n):
        ang = rnd.uniform(-math.pi, math.pi)
        sp = rnd.uniform(0.9, 2.6) * u * spread
        vx, vy = math.cos(ang) * sp, math.sin(ang) * sp * 0.7 - 0.6 * u
        life = rnd.uniform(0.26, 0.46)
        if tt > life:
            continue
        x = cx + vx * tt
        y = cy + vy * tt + 0.5 * 9.0 * u * tt * tt
        px, py = cx + vx * max(0.0, tt - 0.05), cy + vy * max(0.0, tt - 0.05) + 0.5 * 9.0 * u * max(0.0, tt - 0.05) ** 2
        al = int(255 * (1 - tt / life))
        d.line([(px, py), (x, y)], fill=(*col, al), width=max(2, int(0.028 * u * (1 - tt / life)) + 1))
    glow = ov.filter(ImageFilter.GaussianBlur(3))
    out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    out.alpha_composite(glow)
    out.alpha_composite(ov)
    return out

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


# 2D の舞台の色(上の帯=空/天井, 奥の壁, 床, 床の線, 柱, 右の壁)。名前は blender_player.THEMES と同じ
FLAT_THEMES = {
    "cave": dict(sky=(38, 38, 48), wall=(70, 68, 78), floor=(96, 88, 78), line=(78, 70, 62), prop=(58, 46, 36), side=(84, 82, 86)),
    "dojo": dict(sky=(236, 226, 200), wall=(222, 206, 172), floor=(176, 124, 74), line=(150, 104, 60), prop=(96, 58, 34), side=(214, 196, 160)),
    "field": dict(sky=(150, 200, 245), wall=(178, 214, 240), floor=(104, 150, 76), line=(92, 134, 66), prop=(84, 60, 36), side=(140, 142, 148)),
    "night": dict(sky=(14, 14, 34), wall=(30, 30, 60), floor=(40, 42, 66), line=(30, 32, 54), prop=(66, 66, 96), side=(54, 54, 84)),
    "sunset": dict(sky=(246, 150, 92), wall=(226, 120, 86), floor=(132, 90, 82), line=(112, 74, 68), prop=(96, 74, 74), side=(118, 92, 94)),
}


def flat_bg(plan: dict, f: int) -> Image.Image:
    """平らな2Dの背景: 上の帯・奥の壁・床の帯・床の横線・柱(単色の長方形)・右の壁。遠近の床の目地は描かない。
    位置はカメラの投影で決める(人物と同じ座標系で、パン・寄りに合わせて動く)が、形は正面向きの平らな図形。"""
    cam = plan["frames"][f]["cam"]
    th = FLAT_THEMES.get(plan.get("stage", {}).get("theme", "cave"), FLAT_THEMES["cave"])
    img = Image.new("RGB", (W, H), th["sky"])
    d = ImageDraw.Draw(img)
    tx = cam.get("tx", cam.get("x", 0.0))
    y_floor = camera.project(cam, tx, 0.0, 0.0)[1]              # 人物の足もとの線(y=0 の面の地面)
    y_back = camera.project(cam, tx, 9.0, 0.0)[1]               # 奥の壁の根元
    y_top = camera.project(cam, tx, 9.0, 6.0)[1]                # 奥の壁の上端
    y_h = min(y_back, y_floor - 4)
    d.rectangle([0, y_top, W, y_h], fill=th["wall"])
    d.rectangle([0, y_h, W, H], fill=th["floor"])
    u = camera.px_per_unit(cam)
    for k in range(1, 4):                                       # 床の横線(平行。奥ほど詰まる)
        yy = y_h + (y_floor - y_h) * (k / 4.0) ** 1.6
        d.line([(0, yy), (W, yy)], fill=th["line"], width=2)
    x_left, _ = camera.project(cam, tx - 12, 0.0, 0.0)[:2]
    for n, px in enumerate(range(-18, 48, 3)):                  # 柱: 正面向きの長方形(幅は一定、奥行きで小さくしない)
        X = camera.project(cam, px, 3.5, 0.0)[0]
        if -60 < X < W + 60:
            wpx = max(6, int(0.18 * u))
            d.rectangle([X - wpx / 2, y_top + (y_h - y_top) * 0.15, X + wpx / 2, y_h], fill=th["prop"])
    _flat_props(d, cam, plan.get("stage", {}).get("theme", "cave"), th, tx, y_top, y_h, u)
    wall_x = plan.get("stage", {}).get("wall_x")
    if wall_x is not None:
        X = camera.project(cam, wall_x, 0.0, 0.0)[0]
        if X < W:
            d.rectangle([X, 0, W, y_floor + 4], fill=th["side"])
            d.line([(X, 0), (X, y_floor + 4)], fill=th["line"], width=3)
            for k in range(1, 9):                               # 壁の横線
                yy = y_floor - k * 0.6 * u
                if yy > 0:
                    d.line([(X, yy), (W, yy)], fill=th["line"], width=1)
    return img.convert("RGBA")


def _mix(a, b, k):
    return tuple(int(a[i] * (1 - k) + b[i] * k) for i in range(3))


def _flat_props(d: ImageDraw.ImageDraw, cam: dict, theme: str, th: dict, tx: float, y_top: float, y_h: float, u: float) -> None:
    """舞台ごとの、平らな飾り(2D の切り絵)。奥の壁(y=9 の面)に貼る: 遠景なのでパンに対してゆっくり動く。"""
    def bx(x):                                           # 奥の壁の面での画面 x
        return camera.project(cam, x, 9.0, 0.0)[0]
    span = y_h - y_top
    if theme == "field":                                 # 丘と木
        hill = _mix(th["wall"], th["floor"], 0.55)
        for k, (cx, w_, hgt) in enumerate(((-14, 16, 0.45), (-2, 20, 0.6), (12, 18, 0.5), (26, 16, 0.42), (40, 20, 0.55))):
            X0, X1 = bx(cx - w_ / 2), bx(cx + w_ / 2)
            d.ellipse([X0, y_h - span * hgt, X1, y_h + span * hgt], fill=hill)
        tree = _mix(th["prop"], (40, 90, 40), 0.6)
        for cx in range(-20, 50, 5):
            X = bx(cx + 1.3)
            r = span * 0.11
            d.rectangle([X - r * 0.12, y_h - r * 1.2, X + r * 0.12, y_h], fill=th["prop"])
            d.ellipse([X - r, y_h - r * 2.3, X + r, y_h - r * 0.6], fill=tree)
    elif theme == "night":                               # 月と星
        X = bx(tx + 6.0)
        r = span * 0.16
        d.ellipse([X - r, y_top + span * 0.12, X + r, y_top + span * 0.12 + 2 * r], fill=(240, 236, 210))
        d.ellipse([X - r * 0.55, y_top + span * 0.06, X + r * 1.1, y_top + span * 0.06 + 2 * r * 0.95], fill=th["sky"])
        rnd = random.Random(5)
        for _ in range(60):
            sx, sy = rnd.uniform(-30, 60), rnd.uniform(0.02, 0.6)
            X = bx(sx)
            if -5 < X < W + 5:
                rr = rnd.choice((1, 1, 2))
                d.ellipse([X - rr, y_top + span * sy - rr, X + rr, y_top + span * sy + rr], fill=(230, 230, 240))
    elif theme == "sunset":                              # 夕日と遠い山
        X = bx(tx - 4.0)
        r = span * 0.22
        d.ellipse([X - r, y_h - r * 1.1, X + r, y_h + r * 0.9], fill=(255, 214, 120))
        mount = _mix(th["wall"], (60, 30, 50), 0.5)
        pts = []
        for k, cx in enumerate(range(-30, 60, 6)):
            pts.append((bx(cx), y_h - span * (0.25 + 0.2 * ((k * 7) % 5) / 4.0)))
        d.polygon([(bx(-40), y_h + 2)] + pts + [(bx(70), y_h + 2)], fill=mount)
    elif theme == "dojo":                                # 障子の格子
        for cx in range(-24, 54, 4):
            X0, X1 = bx(cx), bx(cx + 3.2)
            d.rectangle([X0, y_top + span * 0.12, X1, y_h - span * 0.08], outline=th["line"], width=3)
            for k in range(1, 4):
                yy = y_top + span * 0.12 + (span * 0.8) * k / 4
                d.line([(X0, yy), (X1, yy)], fill=th["line"], width=1)
            xm = (X0 + X1) / 2
            d.line([(xm, y_top + span * 0.12), (xm, y_h - span * 0.08)], fill=th["line"], width=1)
    else:                                                # 洞窟: つらら岩
        rock = _mix(th["wall"], (0, 0, 0), 0.35)
        for k, cx in enumerate(range(-24, 54, 3)):
            X = bx(cx)
            hw = span * 0.05
            hh = span * (0.18 + 0.14 * ((k * 5) % 4) / 3.0)
            d.polygon([(X - hw, y_top - 2), (X + hw, y_top - 2), (X, y_top + hh)], fill=rock)

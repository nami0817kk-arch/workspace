"""ラピュタを風船で浮かせる回(計算の回)の画面。行の scene=dict(kind=…) を描く(無い行は前の行を引き継ぐ)。
場面が変わると 0.5 秒で溶け合わせる。作品の映像・絵は使わない。島は自作の簡単な図(雲・城の段・巨大な木・下の岩)。AI 絵は作らない。
数字の出どころは research.md と sim/*.py。台本は scripts.md。
kind: island / formula / bars / table / big / fill / domes / balloon / cube / people / row / airbox / alt / gasbar / rise / snack / two /
      weather / nasa / domevs / ship / spheres / column / under / timeline / hot / share / mix4 / bag / aircol / area / cluster / low /
      cushion / final / counter / three / lattice
"""
from __future__ import annotations

import math
import random

from PIL import Image, ImageDraw, ImageFilter

from naze import mapscene, overlay as O
from naze.config import H, W

LAND = W > H
S = min(W, H) / 1080
COLS = dict(dim=O.DIM, white=O.WHITE, yel=O.YEL, red=O.RED, green=O.GREEN)
BG0, BG1 = (10, 18, 40), (16, 30, 62)
SKY0, SKY1 = (22, 48, 92), (88, 132, 182)

AMBER = (240, 170, 70)
GREY = (170, 178, 192)
GRN = (110, 220, 140)
BLU = (90, 170, 235)
RED_ = (240, 90, 80)
ORG = (240, 150, 40)
TEAL = (80, 210, 190)
STONE = (198, 188, 168)
ROCK = (104, 96, 92)
LEAF = (52, 122, 72)
BALL = (236, 96, 120)


def _ease(u):
    u = max(0.0, min(1.0, u))
    return u * u * (3 - 2 * u)


def grad(img, top=BG0, bot=BG1, box=None):
    x0, y0, x1, y1 = box or (0, 0, W, H)
    d = ImageDraw.Draw(img)
    n = int(y1 - y0)
    for i in range(0, n, 2):
        u = i / max(1, n)
        d.rectangle([x0, y0 + i, x1, y0 + i + 2], fill=tuple(int(top[j] + (bot[j] - top[j]) * u) for j in range(3)))


def text(d, xy, s, size, col=O.WHITE, anchor="la", stroke=5):
    d.text(xy, s, font=O.font(int(size * S)), fill=col, anchor=anchor, stroke_width=stroke, stroke_fill=O.NAVY)


def fitsize(s, size, maxw):
    sz = size
    while O.font(int(sz * S)).getlength(s) > maxw and sz > 22:
        sz -= 2
    return sz


def vtext(d, xy, s, size, col=O.WHITE, anchor="mm", maxw=None, stroke=4):
    if maxw:
        size = fitsize(s, size, maxw)
    text(d, xy, s, size, col, anchor, stroke)


def label(d, xy, s, size=40, col=O.WHITE, anchor="mm", maxw=None):
    """白い字の小さな札(箱つき)。重なりの点検に載せる。"""
    if maxw:
        size = fitsize(s, size, maxw)
    f = O.font(int(size * S))
    bb = d.textbbox(xy, s, font=f, anchor=anchor)
    pad = 12 * S
    box = (bb[0] - pad, bb[1] - pad * 0.7, bb[2] + pad, bb[3] + pad * 0.7)
    d.rounded_rectangle(box, int(10 * S), fill=O.NAVY + (230,), outline=col, width=max(2, int(3 * S)))
    d.text(xy, s, font=f, fill=col, anchor=anchor)
    O.BOXES.append(("label", box, s, 1.0))
    return box


def head(d, box, s, col=O.YEL, size=44):
    x0, y0, x1, y1 = box
    label(d, ((x0 + x1) / 2, y0 + 50 * S), s, size, col, maxw=(x1 - x0) - 80 * S)


def tagbox(d, box, s):
    """置いた値の札(「仮置き」など)。図の右下の隅。"""
    x0, y0, x1, y1 = box
    label(d, (x1 - 30 * S, y1 - 34 * S), s, 30, O.DIM, "rm", maxw=(x1 - x0) - 80 * S)


def mix(c, bg, a):
    return tuple(int(c[i] * a + bg[i] * (1 - a)) for i in range(3))


def arrow(d, p0, p1, col, w=6, hd=22):
    x0, y0 = p0
    x1, y1 = p1
    d.line([p0, p1], fill=col, width=max(2, int(w * S)))
    a = math.atan2(y1 - y0, x1 - x0)
    h = hd * S
    d.polygon([(x1, y1), (x1 - h * math.cos(a - 0.45), y1 - h * math.sin(a - 0.45)), (x1 - h * math.cos(a + 0.45), y1 - h * math.sin(a + 0.45))], fill=col)


def dashed(d, p0, p1, col, w=3, dash=14):
    x0, y0 = p0
    x1, y1 = p1
    L = math.hypot(x1 - x0, y1 - y0)
    n = max(1, int(L / (dash * S)))
    for i in range(0, n, 2):
        a, b = i / n, min(1.0, (i + 1) / n)
        d.line([(x0 + (x1 - x0) * a, y0 + (y1 - y0) * a), (x0 + (x1 - x0) * b, y0 + (y1 - y0) * b)], fill=col, width=max(2, int(w * S)))


def hbr(d, xa, xb, y, s, col=O.YEL, size=40, up=True):
    """横の寸法線(両端に縦の線)と札の字。"""
    d.line([(xa, y), (xb, y)], fill=col, width=max(2, int(4 * S)))
    for xx in (xa, xb):
        d.line([(xx, y - 14 * S), (xx, y + 14 * S)], fill=col, width=max(2, int(4 * S)))
    text(d, ((xa + xb) / 2, y - 16 * S if up else y + 16 * S), s, size, col, "md" if up else "ma", 5)


def vbr(d, x, ya, yb, s, col=O.YEL, size=36, side="r"):
    d.line([(x, ya), (x, yb)], fill=col, width=max(2, int(4 * S)))
    for yy in (ya, yb):
        d.line([(x - 12 * S, yy), (x + 12 * S, yy)], fill=col, width=max(2, int(4 * S)))
    if side == "r":
        text(d, (x + 18 * S, (ya + yb) / 2), s, size, col, "lm", 5)
    else:
        text(d, (x - 18 * S, (ya + yb) / 2), s, size, col, "rm", 5)


# ---- 島の図(自作。城の段・巨大な木・下の岩) -------------------------------------------------------
_SPR = {}
_MW = 700          # 下絵の「城のいちばん下の段の幅」(画素)。下絵は 1400×1400、境目(段の下・岩の上)が真ん中


def _island_master():
    if "m" in _SPR:
        return _SPR["m"]
    w = _MW
    im = Image.new("RGBA", (1400, 1400), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    cx, cy = 700, 700
    rnd = random.Random(7)
    # 下の岩: ごつごつした逆さの山(先は少し右へ)
    pts = [(cx - 0.56 * w, cy)]
    n = 14
    for i in range(1, n):
        u = i / n
        x = cx - 0.56 * w + 1.12 * w * u
        depth = 0.85 * w * math.sin(math.pi * u) ** 0.85
        pts.append((x, cy + 0.04 * w + depth * (0.75 + 0.25 * rnd.random())))
    pts.append((cx + 0.56 * w, cy))
    d.polygon(pts, fill=ROCK)
    # 面の明暗(左を明るく)
    for i in range(1, n - 1, 2):
        a, b = pts[i], pts[i + 1]
        d.polygon([(a[0], cy + 6), (b[0], cy + 6), b, a], fill=(122, 112, 104) if a[0] < cx else (88, 82, 80))
    for i in range(7):
        x = cx - 0.4 * w + i * 0.13 * w
        d.line([(x, cy + 20), (x + 0.03 * w, cy + 0.3 * w * (0.6 + 0.4 * rnd.random()))], fill=(78, 72, 70), width=5)
    # 根(岩の上を這う)
    for sx in (-0.47, -0.3, 0.32, 0.48):
        x = cx + sx * w
        d.line([(x, cy - 4), (x + 0.02 * w, cy + 0.12 * w), (x - 0.01 * w, cy + 0.22 * w)], fill=(110, 82, 58), width=9)
    # 城の段(下から 3 段と塔)
    tiers = [(0.50, 0.00, 0.14), (0.36, 0.14, 0.28), (0.22, 0.28, 0.40), (0.08, 0.40, 0.50)]
    for k, (hw, ya, yb) in enumerate(tiers):
        x0, x1 = cx - hw * w, cx + hw * w
        y0, y1 = cy - yb * w, cy - ya * w
        d.rectangle([x0, y0, x1, y1], fill=STONE, outline=(150, 140, 122), width=4)
        d.rectangle([x0, y0, x1, y0 + 0.018 * w], fill=(92, 150, 84))           # 段の上の草
        nwin = max(2, int(hw * 26))
        for j in range(nwin):
            xx = x0 + (x1 - x0) * (j + 0.5) / nwin
            ww = 0.012 * w
            d.rounded_rectangle([xx - ww, y0 + 0.04 * w, xx + ww, y1 - 0.025 * w], int(ww), fill=(70, 66, 74))
    # 巨大な木: 幹と、城を抱える枝葉
    d.rectangle([cx - 0.035 * w, cy - 0.66 * w, cx + 0.035 * w, cy - 0.40 * w], fill=(112, 82, 56))
    for sx in (-1, 1):
        d.line([(cx, cy - 0.58 * w), (cx + sx * 0.22 * w, cy - 0.50 * w), (cx + sx * 0.36 * w, cy - 0.34 * w)], fill=(112, 82, 56), width=16)
        d.line([(cx + sx * 0.36 * w, cy - 0.34 * w), (cx + sx * 0.42 * w, cy - 0.16 * w), (cx + sx * 0.47 * w, cy - 0.02 * w)], fill=(112, 82, 56), width=10)
    blobs = [(0, -0.66, 0.17), (-0.17, -0.60, 0.14), (0.17, -0.60, 0.14), (-0.30, -0.47, 0.12), (0.30, -0.47, 0.12),
             (-0.40, -0.33, 0.09), (0.40, -0.33, 0.09), (-0.08, -0.74, 0.11), (0.09, -0.75, 0.10)]
    for bx, by, r in blobs:
        d.ellipse([cx + (bx - r) * w, cy + (by - r) * w, cx + (bx + r) * w, cy + (by + r) * w], fill=LEAF)
    for bx, by, r in blobs:
        r2 = r * 0.55
        d.ellipse([cx + (bx - r2 - 0.03) * w, cy + (by - r2 - 0.04) * w, cx + (bx + r2 - 0.03) * w, cy + (by + r2 - 0.04) * w], fill=(78, 150, 92))
    _SPR["m"] = im
    return im


def _island_lit(frac):
    key = ("lit", round(frac, 4))
    if key in _SPR:
        return _SPR[key]
    import numpy as np
    m = _island_master()
    a = np.asarray(m.split()[3], dtype=np.float32) / 255
    rows = a.sum(axis=1)
    cum = np.cumsum(rows) / rows.sum()
    yc = int(np.searchsorted(cum, frac))
    base = m.copy()
    dark = Image.new("RGBA", m.size, (40, 46, 64, 255))
    base = Image.composite(dark, Image.new("RGBA", m.size, (0, 0, 0, 0)), m.split()[3])
    lit = Image.new("RGBA", m.size, (255, 214, 64, 255))
    mask = m.split()[3].copy()
    ImageDraw.Draw(mask).rectangle([0, yc, 1400, 1400], fill=0)
    base.paste(lit, (0, 0), mask)
    _SPR[key] = (base, yc)
    return base, yc


def island(img, cx, cy, w, alpha=1.0, lit=None):
    """島を置く。cx, cy = 城のいちばん下の段の真ん中の下端(岩の上)。w = その段の幅(画素)。"""
    sc = w / _MW
    if lit:
        spr, _ = _island_lit(lit)
    else:
        spr = _island_master()
    size = max(8, int(1400 * sc))
    key = (id(spr), size)
    if key not in _SPR:
        _SPR[key] = spr.resize((size, size), Image.LANCZOS)
    s2 = _SPR[key]
    if alpha < 0.999:
        s2 = s2.copy()
        s2.putalpha(s2.split()[3].point(lambda v: int(v * alpha)))
    img.paste(s2, (int(cx - size / 2), int(cy - size / 2)), s2)


def isl_top(cy, w):
    return cy - 0.80 * w


def isl_bot(cy, w):
    return cy + 0.85 * w


# ---- 雲 ---------------------------------------------------------------------------------------

def _cloud(seed, wpx):
    key = ("cl", seed, int(wpx))
    if key in _SPR:
        return _SPR[key]
    rnd = random.Random(seed)
    hh = int(wpx * 0.42)
    mg = int(wpx * 0.12)
    im = Image.new("RGBA", (int(wpx) + 2 * mg, hh + 2 * mg), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    for i in range(9):
        r = wpx * (0.09 + 0.08 * rnd.random())
        x = mg + wpx * (0.22 + 0.56 * rnd.random())
        y = mg + hh * (0.55 + 0.12 * rnd.random())
        d.ellipse([x - r * 1.3, y - r, x + r * 1.3, y + r * 0.6], fill=(245, 248, 255, 200))
    im = im.filter(ImageFilter.GaussianBlur(wpx * 0.025))
    _SPR[key] = im
    return im


def clouds(img, box, t, layer=0, n=5, speed=14, alpha=1.0, ymin=0.15, ymax=0.9, size=0.45, seed=0):
    x0, y0, x1, y1 = box
    ww = x1 - x0
    rnd = random.Random(seed * 31 + layer)
    for i in range(n):
        cw = ww * size * (0.6 + 0.6 * rnd.random())
        sp = _cloud(seed * 10 + i + layer * 100, cw)
        if alpha < 0.999:
            sp = sp.copy()
            sp.putalpha(sp.split()[3].point(lambda v: int(v * alpha)))
        span = ww + cw
        x = x0 - cw + ((rnd.random() * span + t * speed * S * (1 + 0.3 * layer)) % span)
        y = y0 + (y1 - y0) * (ymin + (ymax - ymin) * rnd.random()) - sp.height / 2
        img.paste(sp, (int(x), int(y)), sp)


def sky(img, box):
    grad(img, SKY0, SKY1, box)


# ---- 島の場面 ------------------------------------------------------------------------------------

def sc_island(img, box, t, k, P):
    x0, y0, x1, y1 = box
    mode = P.get("mode", "plain")
    if mode == "cloud":
        sky(img, box)
    else:
        grad(img, box=box)
    d = ImageDraw.Draw(img)
    bw, bh = x1 - x0, y1 - y0
    # 島の大きさと置き場所
    hasbag = P.get("bag")
    wid = min(bw * 0.36, bh / 2.0 * (0.62 if hasbag else 1.0)) if LAND else min(bw * 0.56, bh / 2.1 * (0.7 if hasbag else 1.0))
    if P.get("measure") or P.get("parts"):
        wid *= 0.92
    cx = x0 + bw * (0.5 if not (P.get("measure") or P.get("parts")) or not LAND else 0.36)
    cy = y0 + bh * (0.50 if not hasbag else 0.70)
    if not LAND and P.get("tags") and not hasbag:
        cy = y0 + bh * (0.50 + 0.04 * len(P["tags"]))
    if not LAND and (P.get("measure") or P.get("parts")):
        cy = y0 + bh * 0.40
    z0, z1 = P.get("zoom", (1.0, 1.04))
    z = z0 + (z1 - z0) * _ease(k)
    fx, fy = cx, cy
    if P.get("focus") == "top":
        fy = cy - 0.45 * wid
        z = 1.0 + 0.35 * _ease(k * 1.4)
    elif P.get("focus") == "rock":
        fy = cy + 0.35 * wid
        z = 1.0 + 0.35 * _ease(k * 1.4)
    wz = wid * z
    icx = fx + (cx - fx) * z
    icy = fy + (cy - fy) * z
    if P.get("drift"):
        icy += 14 * S * math.sin(t * 0.8)
        icx += 30 * S * math.sin(t * 0.25)
    if mode == "cloud":
        clouds(img, box, t, 0, n=5, speed=10, alpha=0.75, ymin=0.15, ymax=0.85, size=0.40)
    if hasbag == "sphere":
        R = min(bw * 0.38, (icy - y0 - 0.8 * wz - 40 * S) / 2.1)
        bcy = icy - 0.8 * wz - 60 * S - R
        for sx in (-0.4, -0.2, 0, 0.2, 0.4):
            d.line([(icx + sx * wz, icy - 0.5 * wz), (icx + sx * R * 1.4, bcy + R * 0.85)], fill=(220, 220, 230), width=max(2, int(2 * S)))
        d.ellipse([icx - R, bcy - R, icx + R, bcy + R], fill=(150, 196, 236), outline=O.WHITE, width=max(2, int(4 * S)))
        text(d, (icx, bcy), "1つの袋", 54, O.NAVY, "mm", 0)
        text(d, (icx + R + 20 * S, bcy - 30 * S), "横に広げて", 40, O.WHITE, "lm", 4) if LAND else None
    if hasbag == "nasa":
        R = min(bw * 0.24, (icy - y0 - 0.8 * wz - 100 * S) / 1.6)
        mouth = icy - 0.8 * wz - 40 * S
        top = mouth - 1.6 * R
        nasa_shape(d, icx, mouth, top, R, (150, 196, 236))
        for sx in (-0.3, 0, 0.3):
            d.line([(icx + sx * wz, icy - 0.6 * wz), (icx, mouth)], fill=(220, 220, 230), width=max(2, int(2 * S)))
        bl = P.get("baglabel", [])
        tx = icx + R + 30 * S
        for i, s in enumerate(bl):
            if LAND:
                text(d, (tx, top + 80 * S + i * 70 * S), s, 50, O.YEL if i == 0 else O.WHITE, "lm", 5)
            else:
                vtext(d, ((x0 + x1) / 2, y0 + 120 * S + i * 64 * S), s, 50, O.YEL if i == 0 else O.WHITE, "mm", maxw=bw - 60 * S)
        if P.get("weight"):
            label(d, (icx + wz * 0.75, icy + 0.3 * wz), "軽い島 " + P["weight"], 38, O.WHITE, "lm")
    island(img, icx, icy, wz, lit=P.get("lit"))
    d = ImageDraw.Draw(img)
    if mode == "cloud":
        clouds(img, box, t, 1, n=3, speed=18, alpha=0.55, ymin=0.55, ymax=1.0, size=0.5, seed=3)
        d = ImageDraw.Draw(img)
    if P.get("dim"):
        ov = Image.new("RGBA", img.size, (0, 0, 0, 0))
        ImageDraw.Draw(ov).rectangle(box, fill=(6, 12, 30, 150))
        img.alpha_composite(ov)
        d = ImageDraw.Draw(img)
    if P.get("name"):
        a = _ease(k * 3)
        if a > 0:
            text(d, ((x0 + x1) / 2, y0 + 70 * S), P["name"], 96 if LAND else 84, mix(O.YEL, (30, 40, 70), a), "mm", 8)
    # 札
    tags = P.get("tags", [])
    for i, s in enumerate(tags):
        if LAND:
            label(d, (icx + 0.62 * wz + 30 * S, icy - 0.4 * wz + i * 0.75 * wz), s, 44, O.YEL, "lm")
        else:
            label(d, ((x0 + x1) / 2, y0 + 80 * S + i * 90 * S), s, 44, O.YEL)
    m = P.get("measure", 0)
    if m:
        ya = icy + 22 * S
        xa, xb = icx - wz * 0.5, icx + wz * 0.5
        d.line([(xa, icy - 0.14 * wz), (xa, ya + 20 * S)], fill=O.YEL, width=max(2, int(3 * S)))
        d.line([(xb, icy - 0.14 * wz), (xb, ya + 20 * S)], fill=O.YEL, width=max(2, int(3 * S)))
        uu = _ease(k * 2) if m == 1 else 1.0
        xm = xa + (xb - xa) * uu
        d.line([(xa, ya), (xm, ya)], fill=O.YEL, width=max(3, int(6 * S)))
        text(d, (icx, ya + 62 * S), "城のいちばん下の段の幅", 34, O.YEL, "mm", 4)
        if m >= 2:
            text(d, (icx, ya + 128 * S), "1.6〜1.8km", 76, O.YEL, "mm", 7)
        if m == 3:
            u = (t * 0.12) % 1.0
            px = xa + (xb - xa) * u
            py = icy - 0.14 * wz - 10 * S
            d.ellipse([px - 9 * S, py - 30 * S, px + 9 * S, py - 12 * S], fill=O.WHITE)
            d.line([(px, py - 12 * S), (px, py + 8 * S)], fill=O.WHITE, width=max(2, int(5 * S)))
            ph = math.sin(t * 9) * 8 * S
            d.line([(px, py + 8 * S), (px - ph, py + 26 * S)], fill=O.WHITE, width=max(2, int(4 * S)))
            d.line([(px, py + 8 * S), (px + ph, py + 26 * S)], fill=O.WHITE, width=max(2, int(4 * S)))
        names = [("柳田理科雄", "1.6km", "パズーの身長1.4mとして"), ("岡田斗司夫", "1.76km", "凧の操縦席の幅1mとして（崩れたあとの段）"), ("QuizKnock", "1.8km", "")]
        if LAND:
            tx = x0 + bw * 0.64
            for i, (nm, v, why) in enumerate(names):
                yy = y0 + bh * (0.24 + 0.22 * i)
                a = 1.0 if m >= 2 else _ease(k * 3 - i * 0.6)
                if a <= 0:
                    continue
                label(d, (tx, yy), nm + ("　" + v if m >= 2 else ""), 46, O.WHITE, "lm")
                if m >= 2 and why:
                    text(d, (tx + 14 * S, yy + 52 * S), why, 30, O.DIM, "lm", 3)
            if m >= 2:
                text(d, (tx, y0 + bh * 0.88), "3人とも作中の画面から測った値", 32, O.DIM, "lm", 3)
        else:
            for i, (nm, v, why) in enumerate(names):
                yy = y0 + bh * (0.80 + 0.075 * i)
                a = 1.0 if m >= 2 else _ease(k * 3 - i * 0.6)
                if a <= 0:
                    continue
                label(d, ((x0 + x1) / 2, yy), nm + ("　" + v if m >= 2 else ""), 42, O.WHITE)
    p = P.get("parts", 0)
    if p:
        if LAND:
            tx = x0 + bw * 0.64
            label(d, (tx, icy - 0.30 * wz), "上：城と町（円柱、中に部屋）", 42, O.WHITE, "lm")
            label(d, (tx, icy + 0.30 * wz), "下：岩のかたまり", 42, O.WHITE, "lm")
            d.line([(icx + 0.52 * wz, icy - 0.2 * wz), (tx - 20 * S, icy - 0.30 * wz)], fill=O.DIM, width=max(2, int(2 * S)))
            d.line([(icx + 0.40 * wz, icy + 0.30 * wz), (tx - 20 * S, icy + 0.30 * wz)], fill=O.DIM, width=max(2, int(2 * S)))
            if p >= 2:
                vtext(d, (tx, icy + 0.30 * wz + 80 * S), "花崗岩　1立方メートルで約2.65t", 46, O.YEL, "lm", maxw=x1 - tx - 30 * S)
        else:
            yb = y0 + bh * 0.80
            label(d, ((x0 + x1) / 2, yb), "上：城と町　下：岩のかたまり", 42, O.WHITE)
            if p >= 2:
                text(d, ((x0 + x1) / 2, yb + 90 * S), "花崗岩　1立方メートルで約2.65t", 46, O.YEL, "mm", 5)
    if P.get("lit"):
        if LAND:
            label(d, (icx + 0.62 * wz + 30 * S, icy - 0.4 * wz + 90 * S), "光った所がヘリウムで浮く分", 34, O.WHITE, "lm")
        else:
            label(d, ((x0 + x1) / 2, y1 - 60 * S), "光った所がヘリウムで浮く分", 34, O.WHITE)


def nasa_shape(d, cx, mouth, top, R, col, outline=O.WHITE):
    """NASA の科学気球のような、上がふくらんだ形(下の口はすぼまる)。mouth=口の y、top=てっぺんの y、R=最大の半径。"""
    hgt = mouth - top
    pts = []
    n = 40
    for i in range(n + 1):
        u = i / n                       # 0=てっぺん 1=口
        y = top + hgt * u
        if u < 0.45:
            r = R * math.sqrt(max(0.0, 1 - ((0.45 - u) / 0.45) ** 2))
        else:
            r = R * (1 - (u - 0.45) / 0.55) ** 1.25
        pts.append((cx + r, y))
    pts2 = [(2 * cx - x, y) for x, y in pts[::-1]]
    d.polygon(pts + pts2, fill=col, outline=outline)
    for j in range(-3, 4):
        xs = [(cx + (x - cx) * j / 3.6, y) for x, y in pts]
        d.line(xs, fill=mix(O.WHITE, col, 0.35), width=max(1, int(2 * S)))


# ---- 札・棒・表・大きな数 ------------------------------------------------------------------------

def sc_formula(img, box, t, k, P):
    grad(img, box=box)
    x0, y0, x1, y1 = box
    d = ImageDraw.Draw(img)
    cx = (x0 + x1) / 2
    rows = P["rows"]
    gap = (y1 - y0 - (60 * S if P.get("tag") else 0)) / (len(rows) + 1)
    for i, (s, size, col) in enumerate(rows):
        a = _ease(k * (len(rows) + 0.5) * 1.8 - i)
        if a <= 0:
            continue
        cc = COLS[col]
        c = tuple(int(v * a + 20 * (1 - a)) for v in cc)
        sz = size
        if P.get("mark") and i == 0:
            sz = int(size * (1.0 + 0.4 * (1 - _ease(k * 4))))
        f = O.font(int(sz * S))
        while f.getlength(s) > (x1 - x0) - (80 if LAND else 120) * S and sz > 30:
            sz -= 4
            f = O.font(int(sz * S))
        yy = y0 + gap * (i + 1) + 6 * S * math.sin(t * 1.3 + i)
        if P.get("mark") and i == 0:
            bigmark(d, cx, yy, sz * S * 0.42, s, c)
            continue
        text(d, (cx, yy), s, sz, c, "mm", 6)


def bigmark(d, cx, cy, r, sym, col):
    """太い ×・○。"""
    w = max(6, int(r * 0.28))
    if sym == "×":
        d.line([(cx - r, cy - r), (cx + r, cy + r)], fill=O.NAVY, width=w + 10)
        d.line([(cx - r, cy + r), (cx + r, cy - r)], fill=O.NAVY, width=w + 10)
        d.line([(cx - r, cy - r), (cx + r, cy + r)], fill=col, width=w)
        d.line([(cx - r, cy + r), (cx + r, cy - r)], fill=col, width=w)
    else:
        d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=O.NAVY, width=w + 10)
        d.ellipse([cx - r + 5, cy - r + 5, cx + r - 5, cy + r - 5], outline=col, width=w)


def bars(d, box, rows, vmax, k=1.0, marks=(), grow=None, done=False):
    """rows = [(名前, 値, 数字の札, 色)]。marks = [(値, 札, 色)] は縦の目印。grow は伸びる行(ほかは最初から出ている)。"""
    x0, y0, x1, y1 = box
    na = not LAND
    ya = y0 + ((170 if na else 120) + (60 if marks else 0)) * S
    n = len(rows)
    rh = min((200 if na else 150) * S, (y1 - 40 * S - ya) / n)
    ya = ya + ((y1 - 40 * S - ya) - rh * n) * 0.4
    gx0 = x0 + 50 * S if na else x0 + (x1 - x0) * 0.33
    gx1 = x1 - 60 * S
    px = lambda v: gx0 + (gx1 - gx0) * min(v, vmax) / vmax
    bh = rh * (0.32 if na else 0.46)
    f = O.font(int(38 * S))
    for i, (name, v, txt, col) in enumerate(rows):
        if done or (grow is not None and i not in grow):
            a = 1.0
        else:
            j = i if grow is None else grow.index(i)
            a = _ease(k * 3.0 - 0.35 * j)
        cy = ya + rh * (i + 0.5) + (14 * S if na else 0)
        nsz = 38
        maxn = (x1 - x0 - 100 * S) if na else (gx0 - x0 - 40 * S)
        while O.font(int(nsz * S)).getlength(name) > maxn and nsz > 22:
            nsz -= 2
        if na:
            text(d, (gx0, cy - bh / 2 - 12 * S), name, nsz, O.WHITE, "ld", 4)
        else:
            text(d, (gx0 - 20 * S, cy), name, nsz, O.WHITE, "rm", 4)
        if a <= 0:
            continue
        end = px(v)
        e = gx0 + max(8 * S, (end - gx0)) * a
        d.rectangle([gx0, cy - bh / 2, e, cy + bh / 2], fill=col)
        if v > vmax and a > 0.95:
            for j in range(3):
                xx = e - 30 * S + j * 12 * S
                d.line([(xx, cy - bh / 2), (xx + 10 * S, cy + bh / 2)], fill=BG1, width=max(2, int(4 * S)))
        tw = f.getlength(txt)
        if a > 0.6:
            if e + 14 * S + tw > x1 - 20 * S:
                text(d, (e - 16 * S, cy), txt, 38, O.NAVY, "rm", 0)
            else:
                text(d, (e + 14 * S, cy), txt, 38, O.WHITE, "lm", 4)
    for j, (v, s, col) in enumerate(marks):
        xm = px(v)
        d.line([(xm, ya - 8 * S), (xm, ya + rh * n)], fill=col, width=max(2, int(5 * S)))
        sz = fitsize(s, 34, (x1 - x0) - 60 * S)
        tw = O.font(int(sz * S)).getlength(s)
        yy = ya - 16 * S - j * 46 * S
        if xm - tw - 10 * S < x0 + 10 * S:
            text(d, (xm + 12 * S, yy), s, sz, col, "ld", 4)
        else:
            text(d, (xm - 12 * S, yy), s, sz, col, "rd", 4)


def sc_bars(img, box, t, k, P):
    grad(img, box=box)
    x0, y0, x1, y1 = box
    d = ImageDraw.Draw(img)
    note = P.get("note")
    mk = P.get("mark")
    bb = [x0, y0, x1, y1 - (100 * S if note else 0) - (60 * S if P.get("tag") else 0)]
    if mk:
        if LAND:
            bb[2] = x1 - 380 * S
        else:
            bb[3] -= 260 * S
    bars(d, bb, P["rows"], P["vmax"], k, P.get("marks", ()), P.get("grow"), P.get("done"))
    if P.get("head"):
        head(d, box, P["head"])
    if note:
        label(d, ((x0 + x1) / 2, bb[3] + 44 * S), note, 42, P.get("ncol", O.RED), maxw=(x1 - x0) - 80 * S)
    if mk:
        a = _ease(k * 2.5 - 1.0)
        if a > 0:
            sz = int(260 * S * (1 + 0.4 * (1 - _ease(k * 2.5 - 1.0))))
            cx, cy = ((x1 - 190 * S), (y0 + y1) / 2) if LAND else ((x0 + x1) / 2, bb[3] + 130 * S)
            bigmark(d, cx, cy, sz * 0.36, mk, O.RED if mk == "×" else O.GREEN)


def sc_table(img, box, t, k, P):
    """rows = [(名前, 重さ/中身, 印, 説明)]。"""
    grad(img, box=box)
    x0, y0, x1, y1 = box
    d = ImageDraw.Draw(img)
    rows = P["rows"]
    n = len(rows)
    top = y0 + 150 * S
    rh = min((130 if LAND else 150) * S, (y1 - top - 40 * S) / max(n, 1))
    w = x1 - x0
    if LAND:
        cx_tag, cx_name, cx_mark, cx_det = x0 + 60 * S, x0 + w * 0.27, x0 + w * 0.58, x0 + w * 0.64
    else:
        cx_tag, cx_name, cx_mark, cx_det = x0 + 40 * S, x0 + w * 0.40, x0 + w * 0.80, None
    mark_col = {"×": O.RED, "○": O.GREEN, "△": O.YEL}
    for i, (tag, name, mk, det) in enumerate(rows):
        a = _ease(k * n * 1.3 - i)
        if a <= 0:
            continue
        cy = top + rh * (i + 0.5)
        d.rounded_rectangle([x0 + 20 * S, cy - rh * 0.44, x1 - 20 * S, cy + rh * 0.44], int(12 * S), fill=mix((30, 44, 78), BG1, a), outline=mix(O.DIM, BG1, 0.4 * a), width=max(2, int(2 * S)))
        vtext(d, (cx_tag, cy), tag, 42, O.YEL, "lm", maxw=(cx_name - cx_tag - 20 * S))
        vtext(d, (cx_name, cy), name, 40, O.WHITE, "lm", maxw=cx_mark - cx_name - 50 * S)
        bigmark(d, cx_mark, cy, rh * 0.26, mk, mark_col[mk]) if mk in "×○" else text(d, (cx_mark, cy), mk, 70, mark_col[mk], "mm", 5)
        if cx_det:
            vtext(d, (cx_det, cy), det, 38, O.WHITE, "lm", maxw=x1 - cx_det - 40 * S)
    head(d, box, P.get("head", ""))


def sc_big(img, box, t, k, P):
    grad(img, box=box)
    x0, y0, x1, y1 = box
    d = ImageDraw.Draw(img)
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    sc = 1.0 + 0.5 * (1 - _ease(k * 3)) if P.get("count") else 1.0
    vtext(d, (cx, cy - 40 * S), P["big"], 170 * sc, O.YEL, "mm", maxw=(x1 - x0) - 60 * S, stroke=9)
    vtext(d, (cx, cy + 110 * S), P["sub"], 48, O.WHITE, "mm", maxw=(x1 - x0) - 60 * S)
    # 小さな風船の粒がゆっくり昇る(画面を止めない)
    rnd = random.Random(5)
    for i in range(26):
        bx = x0 + (x1 - x0) * rnd.random()
        by = y1 - ((t * 30 * S * (0.5 + rnd.random()) + rnd.random() * (y1 - y0)) % (y1 - y0))
        r = (8 + 6 * rnd.random()) * S
        d.ellipse([bx - r, by - r * 1.2, bx + r, by + r * 1.2], fill=mix(BALL, BG1, 0.35))


# ---- 1章・2章の図 ---------------------------------------------------------------------------------

def sc_fill(img, box, t, k, P):
    grad(img, box=box)
    x0, y0, x1, y1 = box
    d = ImageDraw.Draw(img)
    bw = x1 - x0
    side = min(bw * 0.30, (y1 - y0) * 0.50) if LAND else min(bw * 0.40, (y1 - y0) * 0.30)
    if LAND:
        cs = [(x0 + bw * 0.28, (y0 + y1) / 2 + 10 * S), (x0 + bw * 0.72, (y0 + y1) / 2 + 10 * S)]
    else:
        cs = [((x0 + x1) / 2, y0 + (y1 - y0) * 0.33), ((x0 + x1) / 2, y0 + (y1 - y0) * 0.74)]
    u = _ease(k * 2)
    for j, (cx, cy) in enumerate(cs):
        bx0, by0 = cx - side / 2, cy - side / 2
        if j == 0:
            d.rectangle([bx0, by0, bx0 + side, by0 + side], fill=(150, 140, 124), outline=O.WHITE, width=max(2, int(3 * S)))
            nn = 4
            c = side / nn
            for a in range(nn):
                for b in range(nn):
                    if (a + b) % 3 != 1:
                        pad = c * 0.16
                        rr = mix((30, 34, 50), (150, 140, 124), u)
                        d.rectangle([bx0 + a * c + pad, by0 + b * c + pad, bx0 + (a + 1) * c - pad, by0 + (b + 1) * c - pad], fill=rr)
            ttl, sub, col = "部屋だらけ", "軽い", BLU
        else:
            d.rectangle([bx0, by0, bx0 + side, by0 + side], fill=ROCK, outline=O.WHITE, width=max(2, int(3 * S)))
            rnd = random.Random(3)
            for _ in range(40):
                px, py = bx0 + side * rnd.random(), by0 + side * rnd.random()
                rr = side * 0.03
                d.ellipse([px - rr, py - rr, px + rr, py + rr], fill=(130, 120, 112))
            ttl, sub, col = "岩がぎっしり", "重い", RED_
        if LAND:
            text(d, (cx, by0 - 40 * S), ttl, 50, O.WHITE, "mm", 5)
            text(d, (cx, by0 + side + 60 * S), sub, 70, col, "mm", 6)
        else:
            text(d, (cx - side / 2 - 30 * S, cy - 30 * S), ttl, 40, O.WHITE, "rm", 4) if False else None
            text(d, (cx, by0 - 36 * S), ttl + "　→　" + sub, 48, col, "mm", 5)
    head(d, box, "重さを左右するのは、中の詰まり具合")


def _dome(d, cx, base, wd, col, outline=None):
    h = wd * 0.32
    d.chord([cx - wd / 2, base - h * 2, cx + wd / 2, base], 180, 360, fill=col, outline=outline)


def sc_domes(img, box, t, k, P):
    grad(img, box=box)
    x0, y0, x1, y1 = box
    d = ImageDraw.Draw(img)
    n = P["n"]
    top = y0 + 120 * S
    bot = y1 - (90 if LAND else 220) * S
    cols = 30 if LAND else 18
    rows = math.ceil(n / cols)
    cell = min((x1 - x0 - 80 * S) / cols, (bot - top) / rows)
    gx0 = (x0 + x1) / 2 - cell * cols / 2
    shown = int(n * _ease(k * 1.6))
    for i in range(n):
        r, c = divmod(i, cols)
        cx = gx0 + cell * (c + 0.5)
        base = top + cell * (r + 0.8)
        _dome(d, cx, base, cell * 0.86, (210, 214, 226) if i < shown else (40, 52, 84))
    cnt = f"{shown}杯" if shown < n else "約530杯"
    if LAND:
        text(d, ((x0 + x1) / 2, y1 - 40 * S), f"岩で満たした東京ドーム　{cnt}　＝　17億t", 50, O.YEL, "mm", 5)
    else:
        text(d, ((x0 + x1) / 2, y1 - 160 * S), f"岩で満たした東京ドーム", 46, O.WHITE, "mm", 5)
        text(d, ((x0 + x1) / 2, y1 - 80 * S), f"{cnt}　＝　17億t", 60, O.YEL, "mm", 6)
    head(d, box, "東京ドーム1杯を岩で満たすと　約329万t")


def balloon_at(d, cx, cy, r, col=BALL, string=True, sway=0.0, nseg=12):
    d.ellipse([cx - r, cy - r * 1.18, cx + r, cy + r * 1.0], fill=col, outline=mix(O.WHITE, col, 0.4), width=max(1, int(2 * S)))
    d.ellipse([cx - r * 0.55, cy - r * 0.85, cx - r * 0.2, cy - r * 0.4], fill=mix(O.WHITE, col, 0.6))
    d.polygon([(cx, cy + r), (cx - r * 0.12, cy + r * 1.15), (cx + r * 0.12, cy + r * 1.15)], fill=col)
    if string:
        pts = [(cx + math.sin(i * 0.5 + sway) * r * 0.12, cy + r * 1.15 + i * r * 0.25) for i in range(nseg)]
        d.line(pts, fill=(220, 220, 230), width=max(1, int(2 * S)))


def sc_balloon(img, box, t, k, P):
    grad(img, box=box)
    x0, y0, x1, y1 = box
    d = ImageDraw.Draw(img)
    st = P.get("stage", 0)
    f = P.get("formula")
    bw, bh = x1 - x0, y1 - y0
    if LAND:
        cx = x0 + bw * (0.24 if f else 0.42)
        cy = y0 + bh * 0.36
    else:
        cx = (x0 + x1) / 2
        cy = y0 + bh * (0.26 if f else 0.36)
    r = (110 if LAND else 120) * S
    cy += 12 * S * math.sin(t * 1.4)
    if st == 2:
        # 結び: 風船と、上に大きな座布団の影
        ov = Image.new("RGBA", img.size, (0, 0, 0, 0))
        od = ImageDraw.Draw(ov)
        cw = bw * 0.82
        od.rounded_rectangle([(x0 + x1) / 2 - cw / 2, y0 + 70 * S, (x0 + x1) / 2 + cw / 2, y0 + 70 * S + cw * 0.12], int(cw * 0.05), fill=(150, 196, 236, 90), outline=(220, 235, 255, 140), width=max(2, int(3 * S)))
        img.alpha_composite(ov)
        d = ImageDraw.Draw(img)
        cy = y0 + bh * 0.52 + 10 * S * math.sin(t * 1.4)
        cx = (x0 + x1) / 2
    balloon_at(d, cx, cy, r, sway=t * 1.5, nseg=7)
    sb = cy + r * 1.15 + r * 0.25 * 6
    if st == 0:
        if LAND:
            text(d, (cx + r + 60 * S, cy - 20 * S), "お祭りのヘリウムの風船", 56, O.WHITE, "lm", 5)
            text(d, (cx + r + 60 * S, cy + 60 * S), "直径28cm", 44, O.DIM, "lm", 4)
        else:
            text(d, (cx, sb + 60 * S), "お祭りのヘリウムの風船", 50, O.WHITE, "mm", 5)
            text(d, (cx, sb + 120 * S), "直径28cm", 40, O.DIM, "mm", 4)
    if st == 1:
        # ひもの先に 1円玉 10 枚
        cr = 22 * S
        for i in range(10):
            yy = sb + 10 * S + i * 13 * S
            d.ellipse([cx - cr, yy - cr * 0.35, cx + cr, yy + cr * 0.35], fill=(205, 208, 214), outline=(120, 124, 132))
        label(d, (cx + r + 30 * S, cy - 20 * S), "10g", 64, O.YEL, "lm")
        text(d, (cx + 40 * S, sb + 80 * S), "1円玉10枚ぶん", 44, O.WHITE, "lm", 5)
        if f:
            rows = [("浮く力 ＝ 押しのけた空気の重さ − ガスの重さ", 40, O.YEL), ("海面の1立方メートルで", 34, O.DIM),
                    ("ヘリウム　1.2250 − 0.1693 ＝ 1.0557kg", 40, O.WHITE), ("水素　1.1397kg", 40, O.WHITE)]
            if LAND:
                fx0, fy0 = x0 + bw * 0.46, y0 + bh * 0.22
                d.rounded_rectangle([fx0 - 30 * S, fy0 - 40 * S, x1 - 40 * S, fy0 + 330 * S], int(18 * S), fill=(14, 26, 54), outline=O.DIM, width=max(2, int(2 * S)))
                for i, (s, sz, col) in enumerate(rows):
                    vtext(d, (fx0, fy0 + 30 * S + i * 80 * S), s, sz, col, "lm", maxw=x1 - fx0 - 80 * S)
            else:
                fy0 = y0 + bh * 0.68
                for i, (s, sz, col) in enumerate(rows):
                    vtext(d, ((x0 + x1) / 2, fy0 + i * 72 * S), s, sz, col, "mm", maxw=bw - 80 * S)
    if st == 2:
        text(d, ((x0 + x1) / 2, y0 + 70 * S + bw * 0.06), "直径32kmの座布団", 46, O.WHITE, "mm", 5)
        text(d, (cx + r + 40 * S, cy), "お祭りの風船", 46, O.WHITE, "lm", 5)


def sc_cube(img, box, t, k, P):
    grad(img, box=box)
    x0, y0, x1, y1 = box
    d = ImageDraw.Draw(img)
    bw, bh = x1 - x0, y1 - y0
    side = min(bh * 0.55, bw * 0.30) if LAND else min(bw * 0.6, bh * 0.38)
    cx = x0 + bw * (0.30 if LAND else 0.5)
    cy = y0 + bh * (0.52 if LAND else 0.36)
    u = _ease(k * 1.6)
    nn = 10
    c = side / nn
    shown = int(nn * nn * u)
    for i in range(nn * nn):
        a, b = divmod(i, nn)
        xx, yy = cx - side / 2 + b * c, cy + side / 2 - (a + 1) * c
        col = BALL if i < shown else (40, 52, 84)
        d.rectangle([xx + 1, yy + 1, xx + c - 1, yy + c - 1], fill=col)
    d.rectangle([cx - side / 2, cy - side / 2, cx + side / 2, cy + side / 2], outline=O.WHITE, width=max(2, int(3 * S)))
    if LAND:
        tx = x0 + bw * 0.52
        text(d, (tx, cy - 110 * S), "1マス ＝ 風船100万個", 40, O.DIM, "lm", 4)
        text(d, (tx, cy - 20 * S), "風船1億個", 70, O.WHITE, "lm", 6)
        text(d, (tx, cy + 80 * S), "＝　1,000t", 90, O.YEL, "lm", 7)
        if P.get("times"):
            text(d, (tx, cy + 190 * S), "島はその170万倍", 56, O.RED, "lm", 5)
    else:
        yy = cy + side / 2 + 60 * S
        text(d, (cx, yy), "1マス ＝ 風船100万個", 38, O.DIM, "mm", 4)
        text(d, (cx, yy + 90 * S), "風船1億個 ＝ 1,000t", 70, O.YEL, "mm", 6)
        if P.get("times"):
            text(d, (cx, yy + 190 * S), "島はその170万倍", 60, O.RED, "mm", 5)
    head(d, box, "お祭りの風船1個で10g")


def _person(d, cx, foot, h, col=O.WHITE):
    r = h * 0.12
    d.ellipse([cx - r, foot - h, cx + r, foot - h + 2 * r], fill=col)
    d.line([(cx, foot - h + 2 * r), (cx, foot - h * 0.42)], fill=col, width=max(2, int(h * 0.07)))
    d.line([(cx, foot - h * 0.42), (cx - h * 0.14, foot)], fill=col, width=max(2, int(h * 0.07)))
    d.line([(cx, foot - h * 0.42), (cx + h * 0.14, foot)], fill=col, width=max(2, int(h * 0.07)))
    d.line([(cx - h * 0.18, foot - h * 0.6), (cx + h * 0.18, foot - h * 0.72)], fill=col, width=max(2, int(h * 0.06)))


def sc_people(img, box, t, k, P):
    grad(img, box=box)
    x0, y0, x1, y1 = box
    d = ImageDraw.Draw(img)
    bw, bh = x1 - x0, y1 - y0
    fam = P.get("family")
    npp = 4 if fam else 1
    foot = y1 - (110 if LAND else 330) * S
    h = (220 if LAND else 240) * S
    rnd = random.Random(2)
    xs = [x0 + bw * (0.5 + (i - (npp - 1) / 2) * (0.16 if LAND else 0.22)) for i in range(npp)]
    if LAND and not fam:
        xs = [x0 + bw * 0.34]
    for cx in xs:
        hx, hy = cx + h * 0.18, foot - h * 0.72
        bc = (hx, foot - h * 1.9)
        u = _ease(k * 1.5)
        nb = int(60 * u) + 6
        for i in range(nb):
            ang = rnd.random() * 2 * math.pi
            rr = (h * 0.55) * math.sqrt(rnd.random())
            bx, by = bc[0] + rr * math.cos(ang), bc[1] + rr * math.sin(ang) * 0.8 + 6 * S * math.sin(t * 1.3 + i)
            d.line([(hx, hy), (bx, by)], fill=(120, 126, 140), width=1)
            col = [BALL, (250, 200, 80), (110, 190, 240), (150, 220, 140)][i % 4]
            d.ellipse([bx - 12 * S, by - 14 * S, bx + 12 * S, by + 12 * S], fill=col)
        _person(d, cx, foot, h * (1.0 if not fam or xs.index(cx) < 2 else 0.7))
    if LAND and not fam:
        tx = x0 + bw * 0.56
        text(d, (tx, y0 + bh * 0.36), "ひとり", 60, O.WHITE, "lm", 5)
        text(d, (tx, y0 + bh * 0.52), "2万個", 130, O.YEL, "lm", 8)
        text(d, (tx, y0 + bh * 0.70), "世界の82億人に配って、やっと170兆個", 40, O.DIM, "lm", 4)
    else:
        text(d, ((x0 + x1) / 2, foot + 70 * S), "4人家族なら　8万個" if fam else "ひとり　2万個", 70, O.YEL, "mm", 6)
        text(d, ((x0 + x1) / 2, foot + 150 * S), "ひとり2万個 × 4人" if fam else "世界の82億人に配る", 42, O.DIM, "mm", 4)
    head(d, box, "世界中の人に配ると")


def sc_row(img, box, t, k, P):
    grad(img, box=(box[0], box[1], box[2], box[3]), top=(4, 8, 22), bot=(10, 18, 40))
    x0, y0, x1, y1 = box
    d = ImageDraw.Draw(img)
    bw, bh = x1 - x0, y1 - y0
    ey = (y0 + y1) / 2 + 20 * S
    ex, sx = x0 + 120 * S, x1 - 150 * S
    re_, rs = 26 * S, 90 * S
    d.ellipse([sx - rs, ey - rs, sx + rs, ey + rs], fill=(255, 196, 70))
    d.ellipse([ex - re_, ey - re_, ex + re_, ey + re_], fill=(60, 120, 200))
    text(d, (ex, ey + 60 * S), "地球", 40, O.WHITE, "ma", 4)
    text(d, (sx, ey + rs + 20 * S), "太陽", 40, O.WHITE, "ma", 4)
    u = _ease(k * 1.4)
    xe = ex + re_ + (sx - rs - ex - re_) * u
    nn = int((xe - ex) / (16 * S))
    for i in range(nn):
        bx = ex + re_ + 8 * S + i * 16 * S
        d.ellipse([bx - 6 * S, ey - 8 * S, bx + 6 * S, ey + 6 * S], fill=BALL)
    times = int(1 + 329 * _ease(k * 1.4 - 0.2)) if k > 0.15 else 1
    off = 140 if LAND else 240
    text(d, ((x0 + x1) / 2, ey - off * S), "風船170兆個を1列に並べると", 46, O.WHITE, "mm", 5)
    text(d, ((x0 + x1) / 2, ey + off * S), f"地球〜太陽の　約{times}倍" if times < 330 else "地球〜太陽の　約330倍", 70, O.YEL, "mm", 6)
    text(d, ((x0 + x1) / 2, y1 - 20 * S), "1個を直径28cmとして", 30, O.DIM, "md", 3)


def _airbox(d, cx, cy, side, n, t, seed):
    d.rectangle([cx - side / 2, cy - side / 2, cx + side / 2, cy + side / 2], fill=(20, 36, 70), outline=O.WHITE, width=max(2, int(3 * S)))
    rnd = random.Random(seed)
    for i in range(n):
        px = cx - side / 2 + side * (0.05 + 0.9 * rnd.random()) + 4 * S * math.sin(t * 3 + i)
        py = cy - side / 2 + side * (0.05 + 0.9 * rnd.random()) + 4 * S * math.cos(t * 2.6 + i * 1.7)
        d.ellipse([px - 5 * S, py - 5 * S, px + 5 * S, py + 5 * S], fill=(150, 205, 250))


def sc_airbox(img, box, t, k, P):
    grad(img, box=box)
    x0, y0, x1, y1 = box
    d = ImageDraw.Draw(img)
    bw, bh = x1 - x0, y1 - y0
    side = min(bw * 0.28, bh * 0.48) if LAND else min(bw * 0.5, bh * 0.30)
    if LAND:
        cs = [(x0 + bw * 0.28, y0 + bh * 0.5), (x0 + bw * 0.72, y0 + bh * 0.5)]
    else:
        cs = [((x0 + x1) / 2, y0 + bh * 0.30), ((x0 + x1) / 2, y0 + bh * 0.70)]
    u = _ease(k * 1.5)
    n1 = 122
    n2 = int(122 - (122 - 74) * u)
    for j, ((cx, cy), n, nm, v) in enumerate(zip(cs, (n1, n2), ("海面", "高さ5,000m"), ("1.2kg", "0.74kg"))):
        _airbox(d, cx, cy, side, n, t, j + 1)
        if LAND:
            text(d, (cx, cy - side / 2 - 40 * S), nm + "の空気 1立方メートル", 40, O.WHITE, "mm", 4)
            text(d, (cx, cy + side / 2 + 60 * S), v, 76, O.YEL, "mm", 6)
        else:
            text(d, (cx, cy - side / 2 - 34 * S), nm + "の空気 1立方メートル", 38, O.WHITE, "mm", 4)
            text(d, (cx + side / 2 + 20 * S, cy), v, 54, O.YEL, "lm", 5)
    if P.get("note"):
        label(d, ((x0 + x1) / 2, (y0 + y1) / 2 if LAND else y1 - 50 * S), P["note"], 48, O.YEL)
    head(d, box, "空気の重さ（標準大気）") if not (LAND and P.get("note")) else None


# ---- 高さの図(3章・8章) ---------------------------------------------------------------------------

def _ruler(d, box, kmax, ticks, unit_m=True):
    """左に高さの目盛り。返り値は km → y の関数と、目盛りの x。"""
    x0, y0, x1, y1 = box
    gy0, gy1 = y0 + 110 * S, y1 - 50 * S
    gx = x0 + (190 if LAND else 150) * S
    py = lambda km: gy1 - (gy1 - gy0) * km / kmax
    d.line([(gx, gy0), (gx, gy1)], fill=O.DIM, width=max(2, int(3 * S)))
    for v in ticks:
        yy = py(v)
        d.line([(gx - 12 * S, yy), (gx, yy)], fill=O.DIM, width=max(2, int(3 * S)))
        s = f"{int(v * 1000):,}m" if unit_m else f"{v:g}km"
        text(d, (gx - 18 * S, yy), s, 28, O.DIM, "rm", 3)
    d.line([(x0 + 30 * S, gy1), (x1 - 30 * S, gy1)], fill=(110, 150, 110), width=max(2, int(4 * S)))
    return py, gx


def sc_alt(img, box, t, k, P):
    sky(img, box)
    x0, y0, x1, y1 = box
    d = ImageDraw.Draw(img)
    st = P.get("stage", 0)
    py, gx = _ruler(d, box, 6.2, [0, 1, 2, 3, 4, 5, 6])
    bw = x1 - x0
    ix = x0 + bw * (0.62 if LAND else 0.62)
    if st >= 1:
        fx = x0 + bw * (0.34 if LAND else 0.36)
        fh = py(0) - py(3.776)
        fw = fh * 2.4
        d.polygon([(fx - fw / 2, py(0)), (fx - fw * 0.07, py(3.776)), (fx + fw * 0.07, py(3.776)), (fx + fw / 2, py(0))], fill=(70, 90, 120))
        d.polygon([(fx - fw * 0.07, py(3.776)), (fx + fw * 0.07, py(3.776)), (fx + fw * 0.16, py(3.3)), (fx - fw * 0.16, py(3.3))], fill=(230, 236, 245))
        text(d, (fx, py(3.776) - 30 * S), "富士山 3,776m", 36, O.WHITE, "md", 4)
        dashed(d, (fx + fw * 0.1, py(3.776)), (ix + 140 * S, py(3.776)), O.DIM, 2)
        vbr(d, ix + 140 * S if LAND else ix + 120 * S, py(5.0), py(3.776), "約1,200m上", O.YEL, 36)
    clouds(img, (x0, py(5.6), x1, py(4.2)), t, 0, n=3, speed=8, alpha=0.6, size=0.35, seed=4)
    clouds(img, (x0, py(2.2), x1, py(0.6)), t, 1, n=3, speed=12, alpha=0.5, size=0.35, seed=8)
    w = (150 if LAND else 120) * S
    island(img, ix, py(5.0) + 6 * S * math.sin(t), w)
    d = ImageDraw.Draw(img)
    dashed(d, (gx, py(5.0)), (ix - w * 0.6, py(5.0)), O.YEL, 3)
    label(d, (gx + 90 * S, py(5.0) - 34 * S), "高さ5,000m", 40, O.YEL, "lm")
    if P.get("tag"):
        tagbox(d, box, P["tag"])
    head(d, box, "雲の上の一例として置く高さ")


def sc_gasbar(img, box, t, k, P):
    grad(img, box=box)
    x0, y0, x1, y1 = box
    d = ImageDraw.Draw(img)
    bw, bh = x1 - x0, y1 - y0
    u = _ease(k * 1.3)
    alt = 5000 * u
    vol = 1 + 0.664 * u
    text(d, ((x0 + x1) / 2, y0 + 130 * S), f"高さ {int(alt / 100) * 100:,}m", 70, O.WHITE, "mm", 6)
    gx0 = x0 + (bw * 0.36 if LAND else 60 * S)
    gx1 = x1 - 80 * S
    unit = (gx1 - gx0) / 2.1
    rows = [("要るガスの量", 1.0, "海面と同じ　1gも増えない", GRN), ("袋の大きさ", vol, f"{vol:.1f}倍", BLU)]
    for i, (nm, v, s, col) in enumerate(rows):
        cy = y0 + bh * (0.45 + 0.25 * i) if LAND else y0 + bh * (0.40 + 0.28 * i)
        bh2 = 60 * S
        if LAND:
            text(d, (gx0 - 24 * S, cy), nm, 46, O.WHITE, "rm", 5)
        else:
            text(d, (gx0, cy - bh2 / 2 - 14 * S), nm, 44, O.WHITE, "ld", 5)
        d.rectangle([gx0, cy - bh2 / 2, gx0 + unit * v, cy + bh2 / 2], fill=col)
        text(d, (gx0 + unit * v + 16 * S, cy) if LAND or i == 1 else (gx0, cy + bh2 / 2 + 40 * S), s, 40, O.YEL, "lm", 4)
    d.line([(gx0 + unit, y0 + bh * 0.3), (gx0 + unit, y1 - 40 * S)], fill=O.DIM, width=max(2, int(2 * S)))
    text(d, ((x0 + x1) / 2, y1 - 20 * S), "袋が自由にふくらめる場合", 32, O.DIM, "md", 3)


def sc_rise(img, box, t, k, P):
    sky(img, box)
    x0, y0, x1, y1 = box
    d = ImageDraw.Draw(img)
    py, gx = _ruler(d, box, 6.2, [0, 1, 2, 3, 4, 5, 6])
    bw = x1 - x0
    if P.get("still"):
        alt = 0.0
    else:
        alt = 5.0 * _ease(k * 1.2)
    # 標準大気の密度比(対流圏)
    T = 288.15 - 6.5 * alt
    rho = (T / 288.15) ** 4.256
    r = 80 * S * (1 / rho) ** (1 / 3)
    cx = x0 + bw * 0.55
    cy = py(alt) - r * 1.6
    if P.get("still"):
        cy = py(0) - r * 2.2
    balloon_at(d, cx, cy, r, sway=t)
    text(d, (cx + r + 30 * S, cy), f"高さ {int(alt * 1000 / 100) * 100:,}m" if not P.get("still") else "雲の高さでは？", 44, O.WHITE, "lm", 5)
    if not P.get("still"):
        text(d, (cx + r + 30 * S, cy + 60 * S), f"大きさ {1 / rho:.2f}倍", 40, O.YEL, "lm", 4)
    head(d, box, "上へ行くほど、中のガスもふくらむ")


def sc_snack(img, box, t, k, P):
    grad(img, box=box)
    x0, y0, x1, y1 = box
    d = ImageDraw.Draw(img)
    bw, bh = x1 - x0, y1 - y0
    u = _ease(k * 1.6)
    if LAND:
        cs = [(x0 + bw * 0.28, y0 + bh * 0.55), (x0 + bw * 0.72, y0 + bh * 0.48)]
    else:
        cs = [((x0 + x1) / 2, y0 + bh * 0.32), ((x0 + x1) / 2, y0 + bh * 0.70)]
    # 右(下)は山の上
    mx, my = cs[1]
    d.polygon([(mx - 300 * S, my + 230 * S), (mx, my + 60 * S), (mx + 300 * S, my + 230 * S)], fill=(60, 84, 112))
    for j, (cx, cy) in enumerate(cs):
        bulge = 0.08 if j == 0 else 0.08 + 0.32 * u
        wd, ht = 230 * S, 280 * S
        pts = []
        for i in range(21):
            a = i / 20
            yy = cy - ht / 2 + ht * a
            xx = wd / 2 * (1 + bulge * math.sin(math.pi * a))
            pts.append((cx + xx, yy))
        pts2 = [(2 * cx - x, y) for x, y in pts[::-1]]
        d.polygon(pts + pts2, fill=(230, 160, 60), outline=O.WHITE)
        d.rectangle([cx - wd / 2 - 6 * S, cy - ht / 2 - 10 * S, cx + wd / 2 + 6 * S, cy - ht / 2 + 8 * S], fill=(200, 120, 40))
        d.rectangle([cx - wd / 2 - 6 * S, cy + ht / 2 - 8 * S, cx + wd / 2 + 6 * S, cy + ht / 2 + 10 * S], fill=(200, 120, 40))
        text(d, (cx, cy), "おかし", 46, O.NAVY, "mm", 0)
        nm = "ふもと" if j == 0 else "高い山の上"
        if LAND:
            text(d, (cx, cy + ht / 2 + 60 * S), nm, 46, O.WHITE, "mm", 5)
        else:
            text(d, (cx + wd / 2 + 70 * S, cy), nm, 42, O.WHITE, "lm", 5) if False else text(d, (cx, cy - ht / 2 - 40 * S), nm, 42, O.WHITE, "mm", 5)
    if LAND:
        text(d, (cs[1][0] + 200 * S, cs[1][1] - 120 * S), "パンパン", 54, O.YEL, "lm", 5)
    head(d, box, "まわりの空気が薄いと、中のガスがふくらむ")


def sc_two(img, box, t, k, P):
    grad(img, box=box)
    x0, y0, x1, y1 = box
    d = ImageDraw.Draw(img)
    bw, bh = x1 - x0, y1 - y0
    st = P.get("stage", 0)
    r1 = (130 if LAND else 140) * S
    r2 = r1 * 1.664 ** (1 / 3)
    if LAND:
        cs = [(x0 + bw * 0.27, y0 + bh * 0.48), (x0 + bw * 0.70, y0 + bh * 0.48)]
    else:
        cs = [((x0 + x1) / 2, y0 + bh * 0.25), ((x0 + x1) / 2, y0 + bh * 0.66)]
    for j, ((cx, cy), r, nm, dens) in enumerate(zip(cs, (r1, r2), ("海面", "高さ5,000m"), (1.0, 0.6))):
        d.ellipse([cx - r - 40 * S, cy - r - 40 * S, cx + r + 40 * S, cy + r + 40 * S], fill=mix((60, 110, 170), BG1, 0.35 + 0.4 * dens))
        rnd = random.Random(j)
        for i in range(int(90 * dens)):
            a = rnd.random() * 2 * math.pi
            rr = (r + 40 * S) * math.sqrt(rnd.random())
            px, py_ = cx + rr * math.cos(a), cy + rr * math.sin(a)
            if math.hypot(px - cx, py_ - cy) > r:
                d.ellipse([px - 3 * S, py_ - 3 * S, px + 3 * S, py_ + 3 * S], fill=(170, 215, 250))
        rr2 = r * (1 + 0.02 * math.sin(t * 2))
        d.ellipse([cx - rr2, cy - rr2, cx + rr2, cy + rr2], fill=(236, 120, 140), outline=O.WHITE, width=max(2, int(3 * S)))
        if LAND:
            text(d, (cx, cy + r + 80 * S), nm, 46, O.WHITE, "mm", 5)
        else:
            text(d, (cx - r - 60 * S, cy), nm, 40, O.WHITE, "rm", 4) if False else text(d, (cx, cy - r - 70 * S), nm, 40, O.WHITE, "mm", 4)
        text(d, (cx, cy), "ガス 同じ量", 40, O.NAVY, "mm", 0)
    if LAND:
        text(d, ((x0 + x1) / 2, y0 + bh * 0.48), "＝", 90, O.YEL, "mm", 6)
        text(d, ((x0 + x1) / 2, y1 - 30 * S), "空気は薄い × 押しのける量は多い　→　浮く力は同じ", 42, O.YEL, "mm", 5)
    else:
        text(d, ((x0 + x1) / 2, y1 - 80 * S), "空気は薄い × 押しのける量は多い", 40, O.WHITE, "mm", 4)
        text(d, ((x0 + x1) / 2, y1 - 26 * S), "浮く力は同じ", 50, O.YEL, "mm", 5)
    if st >= 1:
        cx, cy = cs[1]
        label(d, (cx + r2 + 30 * S, cy - r2) if LAND else (cx + r2 + 10 * S, cy - r2 - 10 * S), "袋は約1.7倍", 44, O.YEL, "lm" if LAND else "rm")
    head(d, box, "差し引きで、浮く力は変わらない") if LAND else None


# ---- 4章の気球 ------------------------------------------------------------------------------------

def sc_weather(img, box, t, k, P):
    sky(img, box)
    x0, y0, x1, y1 = box
    d = ImageDraw.Draw(img)
    st = P.get("stage", 0)
    bw, bh = x1 - x0, y1 - y0
    cx = x0 + bw * 0.5
    if st < 2:
        gy = y1 - 60 * S
        d.line([(x0, gy), (x1, gy)], fill=(110, 150, 110), width=max(2, int(5 * S)))
        r = 90 * S
        cy = gy - 330 * S + 8 * S * math.sin(t * 1.2)
        d.ellipse([cx - r, cy - r * 1.1, cx + r, cy + r], fill=(240, 240, 236), outline=(180, 180, 176), width=max(1, int(2 * S)))
        d.line([(cx, cy + r), (cx, cy + r + 150 * S)], fill=(220, 220, 230), width=max(1, int(2 * S)))
        d.rectangle([cx - 18 * S, cy + r + 150 * S, cx + 18 * S, cy + r + 180 * S], fill=(230, 120, 60))
        text(d, (cx + 40 * S, cy + r + 165 * S), "観測の機械", 32, O.DIM, "lm", 3)
        if st == 1:
            label(d, (cx, cy), "水素", 56, O.YEL)
            text(d, (cx + r + 40 * S, cy - 60 * S), "毎日2回", 56, O.WHITE, "lm", 5) if LAND else text(d, (cx, cy - r * 1.1 - 50 * S), "毎日2回", 52, O.WHITE, "mm", 5)
        head(d, box, "気象庁の気球（高層気象観測）")
        return
    py, gx = _ruler(d, box, 32, [0, 10, 20, 30], unit_m=False)
    u = _ease(k * 1.15)
    alt = 30 * min(1.0, u)
    rr = 30 * S * (1 + 4.0 * (alt / 30) ** 1.4)
    cy = py(alt) + rr * 0.2 if alt < 29 else py(30)
    if u < 0.97:
        d.ellipse([cx - rr, cy - rr * 1.1, cx + rr, cy + rr], fill=(240, 240, 236))
    else:
        for i in range(12):
            a = i * math.pi / 6 + 0.2
            d.line([(cx + rr * 0.6 * math.cos(a), cy + rr * 0.6 * math.sin(a)), (cx + rr * 1.3 * math.cos(a), cy + rr * 1.3 * math.sin(a))], fill=O.YEL, width=max(2, int(5 * S)))
        label(d, (cx + rr * 1.5, cy), "ぱちん", 50, O.YEL, "lm")
    text(d, (x1 - 40 * S, py(alt) + 60 * S if alt < 25 else py(22)), f"高さ 約{int(alt)}km", 44, O.WHITE, "rm", 5)
    dashed(d, (gx, py(30)), (x1 - 40 * S, py(30)), O.YEL, 2)
    head(d, box, "上がるにつれてふくらみ、約30kmで割れる")


def sc_nasa(img, box, t, k, P):
    sky(img, box)
    x0, y0, x1, y1 = box
    d = ImageDraw.Draw(img)
    st = P.get("stage", 0)
    bw, bh = x1 - x0, y1 - y0
    cx = x0 + bw * (0.38 if LAND else 0.5)
    R = (min(bh * 0.30, bw * 0.2) if LAND else bw * 0.30) * (1 + 0.15 * _ease(k) if st == 2 else 1)
    mouth = y0 + bh * (0.85 if LAND else 0.62)
    top = mouth - 1.7 * R
    nasa_shape(d, cx, mouth + 6 * S * math.sin(t), top + 6 * S * math.sin(t), R, (225, 232, 240))
    d.line([(cx, mouth), (cx, mouth + 60 * S)], fill=(220, 220, 230), width=max(1, int(2 * S)))
    tx = cx + R + 50 * S if LAND else (x0 + x1) / 2
    ty = y0 + bh * 0.35 if LAND else y0 + bh * 0.80
    anc = "lm" if LAND else "mm"
    if st == 0:
        text(d, (tx, ty), "NASAの科学気球", 60, O.WHITE, anc, 5)
    if st == 1:
        text(d, (tx, ty), "膜の厚さ 0.02mm", 64, O.YEL, anc, 6)
        text(d, (tx, ty + 80 * S), "食品を包むラップほどの薄さ", 44, O.WHITE, anc, 5)
    if st == 2:
        text(d, (tx, ty), "ふくらむと", 50, O.WHITE, anc, 5)
        text(d, (tx, ty + 90 * S), "113万立方メートル", 70, O.YEL, anc, 6)
    head(d, box, "NASAの科学気球（NASA Balloon Program）")


def sc_domevs(img, box, t, k, P):
    sky(img, box)
    x0, y0, x1, y1 = box
    d = ImageDraw.Draw(img)
    bw, bh = x1 - x0, y1 - y0
    gy = y1 - (130 if LAND else 260) * S
    d.line([(x0, gy), (x1, gy)], fill=(110, 150, 110), width=max(2, int(5 * S)))
    # 体積が同じくらいの 2 つ(ドームは平たい、気球は丸い)。縮尺は見た目の比べ
    dw = bw * (0.36 if LAND else 0.60)
    dcx = x0 + bw * (0.28 if LAND else 0.5)
    if LAND:
        _dome(d, dcx, gy, dw, (210, 214, 226), O.WHITE)
        text(d, (dcx, gy + 40 * S), "東京ドーム　約124万立方メートル", 40, O.WHITE, "ma", 4)
        R = bh * 0.25
        bcx = x0 + bw * 0.72
        mouth = gy - 60 * S + 6 * S * math.sin(t)
        nasa_shape(d, bcx, mouth, mouth - 1.7 * R, R, (225, 232, 240))
        text(d, (bcx, gy + 40 * S), "NASAの気球　113万立方メートル", 40, O.WHITE, "ma", 4)
    else:
        _dome(d, dcx, gy, dw, (210, 214, 226), O.WHITE)
        text(d, (dcx, gy + 40 * S), "東京ドーム　約124万立方メートル", 38, O.WHITE, "ma", 4)
        R = bw * 0.22
        mouth = gy - dw * 0.64 - 80 * S + 6 * S * math.sin(t)
        nasa_shape(d, dcx, mouth, mouth - 1.7 * R, R, (225, 232, 240))
        text(d, (dcx + R + 20 * S, mouth - R), "NASAの気球", 38, O.WHITE, "lm", 4)
        text(d, (dcx + R + 20 * S, mouth - R + 50 * S), "113万立方メートル", 38, O.WHITE, "lm", 4)
    label(d, ((x0 + x1) / 2, y0 + 130 * S), "ほぼドーム1つ分", 50, O.YEL)
    text(d, (x1 - 30 * S, y0 + 130 * S), "形はおおまかな図です", 28, O.DIM, "rm", 3)


def sc_ship(img, box, t, k, P):
    sky(img, box)
    x0, y0, x1, y1 = box
    d = ImageDraw.Draw(img)
    bw, bh = x1 - x0, y1 - y0
    gy = y1 - 60 * S
    d.line([(x0, gy), (x1, gy)], fill=(110, 150, 110), width=max(2, int(5 * S)))
    sc = (gy - y0 - 140 * S) / 333.0 if LAND else (bw - 140 * S) / 333.0
    if LAND:
        tx = x0 + bw * 0.18
        th = 333 * sc
        d.polygon([(tx - th * 0.13, gy), (tx, gy - th), (tx + th * 0.13, gy)], outline=(240, 110, 70), fill=None, width=max(2, int(6 * S)))
        for f in (0.3, 0.5, 0.75):
            yy = gy - th * f
            ww = th * 0.13 * (1 - f)
            d.line([(tx - ww, yy), (tx + ww, yy)], fill=(240, 110, 70), width=max(2, int(4 * S)))
        text(d, (tx + 40 * S, gy - th * 0.5), "東京タワー\n333m", 38, O.WHITE, "lm", 4)
        L = 245 * sc
        sx0 = x0 + bw * 0.38 + 10 * S * math.sin(t * 0.6)
        sy = y0 + bh * 0.42
        d.ellipse([sx0, sy - L * 0.085, sx0 + L, sy + L * 0.085], fill=(190, 196, 206), outline=O.WHITE, width=max(2, int(3 * S)))
        d.rectangle([sx0 + L * 0.4, sy + L * 0.08, sx0 + L * 0.5, sy + L * 0.11], fill=(150, 150, 160))
        hbr(d, sx0, sx0 + L, sy - L * 0.085 - 40 * S, "ヒンデンブルク号　全長245m", O.YEL, 40)
        d.line([(sx0 + L, sy), (sx0 + 333 * sc, sy)], fill=O.DIM, width=max(2, int(2 * S)))
        text(d, (sx0 + L + 20 * S, sy + 60 * S), "東京タワーの約7割", 44, O.YEL, "la", 5)
    else:
        lx = x0 + 70 * S
        yy = y0 + bh * 0.35
        L1, L2 = 333 * sc, 245 * sc
        d.rectangle([lx, yy, lx + L1, yy + 40 * S], fill=(240, 110, 70))
        text(d, (lx, yy - 20 * S), "東京タワー（高さ）333m", 40, O.WHITE, "ld", 4)
        yy2 = yy + 220 * S
        d.ellipse([lx, yy2, lx + L2, yy2 + L2 * 0.17], fill=(190, 196, 206), outline=O.WHITE, width=max(2, int(3 * S)))
        text(d, (lx, yy2 - 20 * S), "ヒンデンブルク号（全長）245m", 40, O.WHITE, "ld", 4)
        text(d, ((x0 + x1) / 2, yy2 + L2 * 0.17 + 120 * S), "東京タワーの約7割", 56, O.YEL, "mm", 5)
    head(d, box, "昔の飛行船")


def sc_spheres(img, box, t, k, P):
    grad(img, box=box)
    x0, y0, x1, y1 = box
    d = ImageDraw.Draw(img)
    st = P.get("stage", 0)
    bw, bh = x1 - x0, y1 - y0
    if st < 2:
        r = (100 if LAND else 110) * S
        if LAND:
            cs = [(x0 + bw * 0.28, y0 + bh * 0.52, r), (x0 + bw * 0.66, y0 + bh * 0.52, 2 * r)]
        else:
            cs = [((x0 + x1) / 2, y0 + bh * 0.22, r), ((x0 + x1) / 2, y0 + bh * 0.62, 2 * r)]
        for j, (cx, cy, rr) in enumerate(cs):
            rr2 = rr * (1 + 0.015 * math.sin(t * 2 + j))
            d.ellipse([cx - rr2, cy - rr2, cx + rr2, cy + rr2], fill=(150, 196, 236), outline=O.WHITE, width=max(2, int(4 * S)))
            text(d, (cx, cy), "大きさ 1" if j == 0 else "大きさ 2倍", 44, O.NAVY, "mm", 0)
            if st == 1:
                if LAND:
                    text(d, (cx, cy + rr + 60 * S), "膜 1　体積 1" if j == 0 else "膜 4倍　体積 8倍", 52, O.WHITE if j == 0 else O.YEL, "mm", 5)
                else:
                    text(d, (cx + rr + 30 * S, cy), "膜 1\n体積 1" if j == 0 else "", 40, O.WHITE, "lm", 4)
                    if j == 1:
                        text(d, (cx, cy + rr + 50 * S), "膜 4倍　体積 8倍", 52, O.YEL, "mm", 5)
        head(d, box, "袋は大きいほど得")
        return
    # 2: 膜(2乗)と浮く力(3乗)の伸び
    gx0, gx1 = x0 + 140 * S, x1 - 80 * S
    gy0, gy1 = y0 + 160 * S, y1 - 90 * S
    d.line([(gx0, gy1), (gx1, gy1)], fill=O.WHITE, width=max(2, int(3 * S)))
    d.line([(gx0, gy0), (gx0, gy1)], fill=O.WHITE, width=max(2, int(3 * S)))
    u = _ease(k * 1.4)
    n = 60
    pa, pv = [], []
    for i in range(int(n * u) + 1):
        s = 1 + 3 * i / n
        pa.append((gx0 + (gx1 - gx0) * (s - 1) / 3, gy1 - (gy1 - gy0) * (s * s - 1) / 63))
        pv.append((gx0 + (gx1 - gx0) * (s - 1) / 3, gy1 - (gy1 - gy0) * (s ** 3 - 1) / 63))
    if len(pa) > 1:
        d.line(pa, fill=AMBER, width=max(3, int(6 * S)))
        d.line(pv, fill=GRN, width=max(3, int(6 * S)))
        text(d, (pa[-1][0] - 10 * S, pa[-1][1] - 20 * S), "膜の重さ（2乗）", 38, AMBER, "rd", 4)
        text(d, (pv[-1][0] - 20 * S, pv[-1][1] + 10 * S), "浮く力（3乗）", 38, GRN, "ra", 4)
    text(d, ((gx0 + gx1) / 2, gy1 + 20 * S), "袋の大きさ　1 → 4倍", 32, O.DIM, "ma", 3)
    head(d, box, "浮く力のほうが速く増える")


def sc_column(img, box, t, k, P):
    grad(img, (2, 4, 16), (24, 50, 96), box)
    x0, y0, x1, y1 = box
    d = ImageDraw.Draw(img)
    bw, bh = x1 - x0, y1 - y0
    gy = y1 - 80 * S
    py = lambda km: gy - (gy - y0 - 110 * S) * km / 1300
    cx = x0 + bw * 0.5
    u = _ease(k * 1.3)
    cw = 60 * S
    top = py(1207 * u)
    d.rectangle([cx - cw / 2, top, cx + cw / 2, gy - 20 * S], fill=(150, 196, 236), outline=O.WHITE)
    island(img, cx, gy - 10 * S, cw)
    d = ImageDraw.Draw(img)
    for km, s in ((400, "宇宙ステーション 約400km"), (1207, "袋の柱 約1,200km")):
        yy = py(km)
        dashed(d, (x0 + 40 * S, yy), (x1 - 40 * S, yy), O.YEL if km > 1000 else O.DIM, 2)
        text(d, (cx + cw + 30 * S, yy - 12 * S), s, 40, O.YEL if km > 1000 else O.WHITE, "ld", 4)
    text(d, (cx - cw - 30 * S, py(800)), "宇宙ステーションの3倍", 44, O.YEL, "rm", 5) if u > 0.9 else None
    text(d, (x0 + 40 * S, y1 - 14 * S), "島の真上に積んだ場合（島の幅1.7km）。島は大きく描いています", 26, O.DIM, "ld", 3)
    head(d, box, "2.74兆立方メートルを島の真上に積むと")


# ---- 5・6章 ---------------------------------------------------------------------------------------

def sc_under(img, box, t, k, P):
    x0, y0, x1, y1 = box
    sky(img, (x0, y0, x1, y0 + (y1 - y0) * 0.3))
    grad(img, (110, 84, 60), (60, 44, 34), (x0, y0 + (y1 - y0) * 0.3, x1, y1))
    d = ImageDraw.Draw(img)
    st = P.get("stage", 0)
    bw, bh = x1 - x0, y1 - y0
    gs = y0 + bh * 0.3
    for i in range(1, 4):
        yy = gs + bh * 0.7 * i / 4
        d.line([(x0, yy + 10 * S * math.sin(i)), (x1, yy - 10 * S * math.sin(i))], fill=(90, 66, 50), width=max(2, int(3 * S)))
    pockets = [(0.25, 0.62), (0.52, 0.78), (0.78, 0.58)] if st else [(0.5, 0.66)]
    for i, (fx, fy) in enumerate(pockets):
        cx, cy = x0 + bw * fx, y0 + bh * fy
        rw, rh = bw * (0.14 if LAND else 0.2), bh * 0.08
        d.ellipse([cx - rw, cy - rh, cx + rw, cy + rh], fill=(70, 110, 150), outline=(160, 200, 240), width=max(2, int(3 * S)))
        if st == 0:
            text(d, (cx, cy), "天然ガス（ヘリウムを含む）", 36, O.WHITE, "mm", 4)
            d.line([(cx, cy - rh), (cx, gs)], fill=(180, 180, 190), width=max(3, int(8 * S)))
            balloon_at(d, cx + 60 * S, gs - 90 * S, 40 * S, (240, 230, 160), sway=t)
            text(d, (cx + 120 * S, gs - 100 * S), "ヘリウム", 44, O.YEL, "lm", 5)
        else:
            u = _ease(k * 1.5 - i * 0.2)
            arrow(d, (cx, cy - rh), (cx + ((x0 + x1) / 2 - cx) * u * 0.8, gs - 30 * S - (gs - y0 - 120 * S) * u * 0.4), O.YEL, 5)
    if st >= 1:
        text(d, ((x0 + x1) / 2, y0 + 120 * S), "地下で見つかっているヘリウムを全部", 46, O.WHITE, "mm", 5)
    if st == 2:
        label(d, ((x0 + x1) / 2, y0 + bh * 0.42), "全部で約400億立方メートル", 54, O.YEL)
        text(d, ((x0 + x1) / 2, y1 - 20 * S), "アメリカの回収できる量と、アメリカ以外の確認された資源の合計（USGS）", 26, O.WHITE, "md", 3)


def sc_timeline(img, box, t, k, P):
    grad(img, box=box)
    x0, y0, x1, y1 = box
    d = ImageDraw.Draw(img)
    bw, bh = x1 - x0, y1 - y0
    ly = (y0 + y1) / 2 + 20 * S
    xa, xb = x0 + 80 * S, x1 - 80 * S
    px = lambda yr: xb - (xb - xa) * yr / 8700
    d.line([(xa, ly), (xb, ly)], fill=O.WHITE, width=max(3, int(6 * S)))
    u = _ease(k * 1.4)
    xc = xb - (xb - xa) * u
    d.line([(xc, ly), (xb, ly)], fill=O.YEL, width=max(4, int(10 * S)))
    marks = [(8700, "8,700年前", O.YEL, -1), (5200, "文字が生まれる\n約5,200年前", O.WHITE, 1), (4500, "ピラミッド\n約4,500年前", O.DIM, -1), (0, "今", O.WHITE, 1)]
    for yr, s, col, side in marks:
        x = px(yr)
        d.line([(x, ly - 20 * S), (x, ly + 20 * S)], fill=col, width=max(2, int(4 * S)))
        an = ("l" if yr == 8700 else "r" if yr == 0 else "m") + ("d" if side < 0 else "a")
        text(d, (x - (20 * S if yr == 8700 else 0), ly + side * 40 * S), s, 38 if LAND else 32, col, an, 4)
    text(d, ((x0 + x1) / 2, y0 + 150 * S), "ヘリウムを8,700年前から作り続けて、やっと届く", 44 if LAND else 36, O.YEL, "mm", 5)
    text(d, ((x0 + x1) / 2, y1 - 20 * S), "文字は紀元前3200年ごろ（楔形文字）", 28, O.DIM, "md", 3)


def hot_shape(d, cx, cy, r, col=(230, 110, 70)):
    pts = []
    for i in range(41):
        a = math.pi * i / 40
        pts.append((cx + r * math.cos(a - math.pi / 2) * 0, 0))
    d.ellipse([cx - r, cy - r * 1.1, cx + r, cy + r * 0.7], fill=col, outline=O.WHITE, width=max(2, int(3 * S)))
    d.polygon([(cx - r * 0.85, cy + r * 0.3), (cx + r * 0.85, cy + r * 0.3), (cx + r * 0.25, cy + r * 1.25), (cx - r * 0.25, cy + r * 1.25)], fill=col)
    for j in (-0.5, 0, 0.5):
        d.line([(cx + j * r, cy - r * 1.05), (cx + j * r * 0.5, cy + r * 1.2)], fill=mix(O.WHITE, col, 0.4), width=max(1, int(3 * S)))
    by = cy + r * 1.25
    d.line([(cx - r * 0.25, by), (cx - r * 0.18, by + r * 0.35)], fill=(200, 200, 200), width=max(1, int(2 * S)))
    d.line([(cx + r * 0.25, by), (cx + r * 0.18, by + r * 0.35)], fill=(200, 200, 200), width=max(1, int(2 * S)))
    d.rectangle([cx - r * 0.2, by + r * 0.35, cx + r * 0.2, by + r * 0.55], fill=(150, 104, 60))
    return by


def sc_hot(img, box, t, k, P):
    sky(img, box)
    x0, y0, x1, y1 = box
    d = ImageDraw.Draw(img)
    st = P.get("stage", 0)
    bw, bh = x1 - x0, y1 - y0
    r = (min(bh * 0.28, 220 * S)) if LAND else bw * 0.26
    cx = x0 + bw * (0.38 if LAND else 0.5)
    cy = y0 + bh * (0.42 if LAND else 0.36) + 8 * S * math.sin(t)
    by = hot_shape(d, cx, cy, r)
    fl = (1.0 if st >= 1 else 0.6) * (1 + 0.25 * math.sin(t * 13) + (0.6 if st == 3 else 0))
    d.polygon([(cx - 14 * S, by), (cx + 14 * S, by), (cx, by - 70 * S * fl)], fill=(255, 190, 60))
    d.polygon([(cx - 7 * S, by), (cx + 7 * S, by), (cx, by - 40 * S * fl)], fill=(255, 240, 160))
    tx = cx + r + 60 * S if LAND else (x0 + x1) / 2
    ty = y0 + bh * 0.40 if LAND else y0 + bh * 0.82
    anc = "lm" if LAND else "mm"
    if st == 0:
        text(d, (tx, ty), "熱気球", 80, O.WHITE, anc, 6)
    if st == 1:
        text(d, (tx, ty), "ガスはいらない", 60, O.YEL, anc, 5)
        text(d, (tx, ty + 80 * S), "空気を温めるだけ", 46, O.WHITE, anc, 5)
    if st == 2:
        # 温度計
        thx = cx - r - 80 * S if LAND else x0 + 90 * S
        ty0, ty1 = cy - r, cy + r * 0.8
        d.rounded_rectangle([thx - 14 * S, ty0, thx + 14 * S, ty1], int(14 * S), fill=(230, 230, 236))
        lv = ty1 - (ty1 - ty0) * 0.85 * _ease(k * 1.4)
        d.rectangle([thx - 7 * S, lv, thx + 7 * S, ty1], fill=RED_)
        d.ellipse([thx - 24 * S, ty1 - 10 * S, thx + 24 * S, ty1 + 38 * S], fill=RED_)
        text(d, (tx, ty), "121℃", 100, O.YEL, anc, 7)
        text(d, (tx, ty + 100 * S), "多くの熱気球が続けて使ってよい上限", 40, O.WHITE, anc, 4)
    if st == 3:
        text(d, (tx, ty), "ずっと燃やし続ける", 64, O.RED, anc, 6)
    head(d, box, "候補のひとつ目　熱した空気")


def sc_share(img, box, t, k, P):
    grad(img, box=box)
    x0, y0, x1, y1 = box
    d = ImageDraw.Draw(img)
    bw, bh = x1 - x0, y1 - y0
    gx0, gx1 = x0 + 80 * S, x1 - 80 * S
    cy = y0 + bh * 0.48
    hh = 110 * S
    d.rectangle([gx0, cy - hh / 2, gx1, cy + hh / 2], fill=(50, 66, 100), outline=O.WHITE, width=max(2, int(3 * S)))
    u = _ease(k * 1.4)
    w6, w10 = (gx1 - gx0) * 0.06, (gx1 - gx0) * 0.10
    d.rectangle([gx0, cy - hh / 2, gx0 + w6 * u, cy + hh / 2], fill=RED_)
    d.rectangle([gx0 + w6 * u, cy - hh / 2, gx0 + w10 * u, cy + hh / 2], fill=mix(RED_, (50, 66, 100), 0.5))
    text(d, ((x0 + x1) / 2, cy - hh / 2 - 40 * S), "世界で使うエネルギー（1年 592EJ）＝ 100%", 40, O.WHITE, "md", 4)
    text(d, (gx0, cy + hh / 2 + 30 * S), "真ん中の島を浮かせ続ける熱気球　6〜10%", 46, O.YEL, "la", 5)
    # 炎のゆらぎ
    for i in range(6):
        fx = gx0 + 30 * S + i * 40 * S
        fy = cy + hh / 2 + 170 * S
        fl = 1 + 0.3 * math.sin(t * 11 + i)
        d.polygon([(fx - 12 * S, fy), (fx + 12 * S, fy), (fx, fy - 50 * S * fl)], fill=(255, 170, 60))
    if P.get("tag"):
        tagbox(d, box, P["tag"])
    head(d, box, "熱気球で真ん中の島を浮かせると")


def sc_mix4(img, box, t, k, P):
    grad(img, box=box)
    x0, y0, x1, y1 = box
    d = ImageDraw.Draw(img)
    bw, bh = x1 - x0, y1 - y0
    side = min(bh * 0.6, bw * 0.34) if LAND else bw * 0.7
    cx = x0 + bw * (0.32 if LAND else 0.5)
    cy = y0 + bh * (0.52 if LAND else 0.42)
    d.rectangle([cx - side / 2, cy - side / 2, cx + side / 2, cy + side / 2], fill=(20, 36, 70), outline=O.WHITE, width=max(2, int(3 * S)))
    nn = 10
    c = side / nn
    for i in range(100):
        a, b = divmod(i, nn)
        px, py_ = cx - side / 2 + (b + 0.5) * c, cy - side / 2 + (a + 0.5) * c
        red = i in (12, 47, 63, 88)
        rr = c * (0.28 if red else 0.2)
        d.ellipse([px - rr, py_ - rr, px + rr, py_ + rr], fill=RED_ if red else (150, 205, 250))
    if k > 0.5:
        fl = 1 + 0.3 * math.sin(t * 12)
        fx, fy = cx, cy + side / 2
        d.polygon([(fx - 60 * S, fy), (fx + 60 * S, fy), (fx, fy - 160 * S * fl)], fill=(255, 150, 50))
        d.polygon([(fx - 30 * S, fy), (fx + 30 * S, fy), (fx, fy - 90 * S * fl)], fill=(255, 230, 140))
    if LAND:
        tx = x0 + bw * 0.58
        text(d, (tx, y0 + bh * 0.38), "空気100粒に、水素4粒", 50, O.WHITE, "lm", 5)
        text(d, (tx, y0 + bh * 0.52), "それだけで火がつく", 64, O.RED, "lm", 6)
        text(d, (tx, y0 + bh * 0.66), "燃える濃さは 4〜75%", 40, O.DIM, "lm", 4)
    else:
        text(d, ((x0 + x1) / 2, cy + side / 2 + 70 * S), "空気100粒に、水素4粒で火がつく", 44, O.RED, "mm", 5)
        text(d, ((x0 + x1) / 2, cy + side / 2 + 130 * S), "燃える濃さは 4〜75%", 36, O.DIM, "mm", 4)
    head(d, box, "水素は燃える")


# ---- 7章: 空の高さの壁 ------------------------------------------------------------------------------

def _isa_rho(z):
    """標準大気の密度比(海面=1)。0〜32km。"""
    if z <= 11:
        T = 288.15 - 6.5 * z
        return (T / 288.15) ** 4.2559
    r11 = (216.65 / 288.15) ** 4.2559
    if z <= 20:
        return r11 * math.exp(-(z - 11) / 6.3416)
    r20 = r11 * math.exp(-9 / 6.3416)
    T = 216.65 + (z - 20)
    return r20 * (T / 216.65) ** (-35.16)


def sc_bag(img, box, t, k, P):
    x0, y0, x1, y1 = box
    st = P.get("stage", 0)
    d = ImageDraw.Draw(img)
    gy0, gy1 = y0 + 110 * S, y1 - 40 * S
    kmax = 23.0
    pyk = (gy1 - gy0) / kmax if LAND else min((gy1 - gy0) / kmax, (x1 - x0 - 340 * S) / 18.5)
    py = lambda km: gy1 - pyk * km
    # 空の濃さ(st>=2 は高さで変える。0・1 は 5,000m で一様)
    for i in range(0, int(gy1 - gy0), 4):
        z = (gy1 - (gy0 + i)) / pyk
        rho = _isa_rho(5.0) if st < 2 else _isa_rho(z)
        a = min(1.0, rho / 0.75)
        col = mix((70, 130, 200), (8, 14, 34), a)
        d.rectangle([x0, gy0 + i, x1, gy0 + i + 4], fill=col)
    d.rectangle([x0, y0, x1, gy0], fill=(8, 14, 34))
    d.rectangle([x0, gy1, x1, y1], fill=(40, 70, 50))
    gx = x0 + (130 if LAND else 110) * S
    for v in (0, 5, 10, 15, 20):
        yy = py(v)
        d.line([(gx - 12 * S, yy), (gx, yy)], fill=O.DIM, width=max(2, int(3 * S)))
        text(d, (gx - 18 * S, yy), f"{v}km", 28, O.DIM, "rm", 3)
    cx = x0 + (x1 - x0) * 0.50 if LAND else x0 + 150 * S + 9.25 * pyk
    mouth = py(5.0)
    if st < 2:
        R = 18.5 / 2 * pyk
        cy = mouth - R
        d.ellipse([cx - R, cy - R, cx + R, cy + R], fill=(236, 120, 140), outline=O.WHITE, width=max(2, int(3 * S)))
        if st == 0:
            label(d, (cx, cy - R - 50 * S if cy - R - 50 * S > y0 + 120 * S else cy), "まわりの空気は5,000mの濃さのまま", 36, O.WHITE)
        else:
            hbr(d, cx - R, cx + R, cy + 30 * S, "直径18.5km", O.YEL, 48)
    else:
        R = 18.5 / 2 * pyk
        top = py(21.0)
        nasa_shape(d, cx, mouth, top, R, (236, 120, 140))
        vbr(d, cx + R + 30 * S, top, mouth, "高さ16km" if LAND else "高さ\n16km", O.YEL, 38)
        dashed(d, (gx, top), (cx - 20 * S, top), O.YEL, 2)
        text(d, (gx + 20 * S, top - 12 * S), "てっぺん 21km", 34, O.YEL, "ld", 4)
        if st >= 3:
            ra = _isa_rho(21) / _isa_rho(5)
            label(d, (cx, top + 120 * S) if LAND else (cx, top + 110 * S), f"てっぺんの空気は口の1割", 38, O.YEL)
    dashed(d, (gx, mouth), (cx - 30 * S, mouth), O.WHITE, 2)
    text(d, (gx + 20 * S, mouth + 30 * S), "袋の口 5,000m", 32, O.WHITE, "la", 4)
    head(d, box, "真ん中の島に要る水素の袋" if st < 2 else "NASAの気球と同じ形（高さ／直径 0.864）")


def sc_aircol(img, box, t, k, P):
    x0, y0, x1, y1 = box
    st = P.get("stage", 0)
    d = ImageDraw.Draw(img)
    gy0, gy1 = y0 + 110 * S, y1 - 40 * S
    kmax = 32.0
    pyk = (gy1 - gy0) / kmax
    py = lambda km: gy1 - pyk * km
    for i in range(0, int(gy1 - gy0), 4):
        z = (gy1 - (gy0 + i)) / pyk
        a = min(1.0, _isa_rho(z) / 0.8)
        d.rectangle([x0, gy0 + i, x1, gy0 + i + 4], fill=mix((70, 130, 200), (8, 14, 34), a))
    d.rectangle([x0, y0, x1, gy0], fill=(8, 14, 34))
    cx = x0 + (x1 - x0) * (0.42 if LAND else 0.5)
    cw = (120 if LAND else 110) * S
    base = py(5.0)
    u = _ease(k * 1.3) if st == 0 else 1.0
    ov = Image.new("RGBA", img.size, (0, 0, 0, 0))
    od = ImageDraw.Draw(ov)
    od.rectangle([cx - cw / 2, gy0 + (base - gy0) * (1 - u), cx + cw / 2, base], fill=(255, 214, 64, 120), outline=(255, 214, 64, 255), width=max(2, int(3 * S)))
    img.alpha_composite(ov)
    d = ImageDraw.Draw(img)
    island(img, cx, base + 30 * S, cw * 0.9)
    d = ImageDraw.Draw(img)
    text(d, (cx, gy0 + 10 * S), "空の上の端まで", 32, O.DIM, "ma", 3)
    dashed(d, (x0 + 40 * S, base), (cx - cw, base), O.WHITE, 2)
    text(d, (x0 + 50 * S, base - 12 * S), "5,000m", 34, O.WHITE, "ld", 4)
    tx = cx + cw / 2 + 40 * S
    if st >= 1:
        text(d, (tx, py(16)), "1平方メートルの上の空気", 40 if LAND else 34, O.WHITE, "lm", 4)
        text(d, (tx, py(16) + 80 * S), "5.5t", 110 if LAND else 90, O.YEL, "lm", 7)
    if st >= 2:
        label(d, (tx, py(16) + 190 * S), "押しのけられるのは、この重さまで", 38 if LAND else 30, O.YEL, "lm", maxw=(x1 - tx - 40 * S))
    head(d, box, "根っこにあるのは、空気そのものの重さ")


def sc_area(img, box, t, k, P):
    grad(img, box=box)
    x0, y0, x1, y1 = box
    d = ImageDraw.Draw(img)
    st = P.get("stage", 0)
    bw, bh = x1 - x0, y1 - y0
    side_km = 2 * math.sqrt(316 / math.pi)          # 316平方キロメートルの円の直径
    pxkm = min((bh - 220 * S) / side_km, (bw * (0.5 if LAND else 0.9)) / side_km)
    cx = x0 + bw * (0.33 if LAND else 0.5)
    cy = y0 + bh * (0.55 if LAND else 0.42)
    sd = side_km * pxkm
    u = _ease(k * 1.6) if st == 0 else 1.0
    d.ellipse([cx - sd / 2 * u, cy - sd / 2 * u, cx + sd / 2 * u, cy + sd / 2 * u], outline=O.YEL, width=max(3, int(5 * S)), fill=mix(O.YEL, BG1, 0.12))
    if st >= 1:
        r = math.sqrt(63 / math.pi) * pxkm
        cs = [(-0.37, -0.37), (0.37, -0.37), (-0.37, 0.37), (0.37, 0.37), (0, 0)]
        shown = 5 if st >= 2 else int(1 + 4.99 * _ease(k * 1.6))
        for i, (a, b) in enumerate(cs[:shown]):
            ox, oy = cx + a * sd * 0.62, cy + b * sd * 0.62
            d.ellipse([ox - r, oy - r * 0.75, ox + r, oy + r * 0.75], outline=(110, 220, 140), width=max(3, int(6 * S)))
    if st >= 2:
        rr = 9.25 * pxkm * (_ease(k * 1.5))
        ov = Image.new("RGBA", img.size, (0, 0, 0, 0))
        ImageDraw.Draw(ov).ellipse([cx - rr, cy - rr, cx + rr, cy + rr], fill=(236, 120, 140, 150), outline=(255, 255, 255, 255), width=max(2, int(4 * S)))
        img.alpha_composite(ov)
        d = ImageDraw.Draw(img)
    if LAND:
        tx = x0 + bw * 0.62
        text(d, (tx, y0 + bh * 0.30), "真ん中の島に要る空", 44, O.WHITE, "lm", 4)
        text(d, (tx, y0 + bh * 0.42), "316平方キロメートル", 64, O.YEL, "lm", 6)
        if st >= 1:
            text(d, (tx, y0 + bh * 0.56), "山手線の内側（約63）が5つ", 42, (110, 220, 140), "lm", 4)
        if st >= 2:
            text(d, (tx, y0 + bh * 0.70), "直径18.5kmの袋の影　269", 44, (236, 140, 160), "lm", 4)
            label(d, (tx, y0 + bh * 0.84), "届かない", 54, O.RED, "lm")
    else:
        ty = cy + sd / 2 + 60 * S
        text(d, ((x0 + x1) / 2, ty), "要る空　316平方キロメートル", 48, O.YEL, "mm", 5)
        if st >= 1:
            text(d, ((x0 + x1) / 2, ty + 70 * S), "山手線の内側（約63）が5つ", 40, (110, 220, 140), "mm", 4)
        if st >= 2:
            text(d, ((x0 + x1) / 2, ty + 140 * S), "袋の影 269　届かない", 44, O.RED, "mm", 4)
    text(d, ((x0 + x1) / 2, y1 - 14 * S), "山手線の内側は輪で、広さだけ合わせて描いています", 26, O.DIM, "md", 3)
    head(d, box, "少なくとも要る空の広さ")


def sc_cluster(img, box, t, k, P):
    sky(img, box)
    x0, y0, x1, y1 = box
    d = ImageDraw.Draw(img)
    bw, bh = x1 - x0, y1 - y0
    cx = (x0 + x1) / 2
    iy = y1 - 120 * S
    by = y0 + bh * 0.38
    n = 7 if LAND else 5
    span = bw * 0.8
    r = span / n / 2 * 0.85
    u = _ease(k * 1.5)
    for i in range(n):
        bx0 = cx - span / 2 + span * (i + 0.5) / n
        bx = bx0 + (cx - bx0) * 0.12 * u * math.copysign(1, cx - bx0) * (abs(cx - bx0) / (span / 2))
        d.line([(cx, iy - 60 * S), (bx, by + r)], fill=(230, 230, 236), width=max(2, int(3 * S)))
        d.ellipse([bx - r, by - r, bx + r, by + r], fill=(236, 120, 140), outline=O.WHITE, width=max(2, int(3 * S)))
        if abs(bx0 - cx) > r:
            sgn = 1 if bx0 < cx else -1
            arrow(d, (bx - sgn * r * 0.2, by), (bx + sgn * r * 0.9, by), O.YEL, 5)
    island(img, cx, iy, 110 * S)
    d = ImageDraw.Draw(img)
    label(d, (cx, y0 + 130 * S), "ひもが斜めに引っぱり、袋が内側へ寄せられる", 40, O.YEL, maxw=bw - 80 * S)


def sc_low(img, box, t, k, P):
    sky(img, box)
    x0, y0, x1, y1 = box
    d = ImageDraw.Draw(img)
    st = P.get("stage", 0)
    py, gx = _ruler(d, box, 12.5, [0, 1, 2, 4, 6, 8, 10, 12], unit_m=True)
    bw = x1 - x0
    ix = x0 + bw * (0.55 if LAND else 0.58)
    clouds(img, (x0, py(1.6), x1, py(0.5)), t, 0, n=3, speed=10, alpha=0.55, size=0.35, seed=2)
    clouds(img, (x0, py(5.6), x1, py(4.4)), t, 1, n=3, speed=8, alpha=0.5, size=0.35, seed=6)
    d = ImageDraw.Draw(img)
    if st == 0:
        iz = 5.0
    elif st == 1:
        iz = 5.0 - 4.0 * _ease(k * 1.4)
    else:
        iz = 1.0
    w = (90 if LAND else 80) * S
    if st >= 2:
        mz = 5.8
        R = (py(0) - py(1)) * 2.4
        mouth = py(mz)
        u = _ease(k * 1.4) if st == 2 else 1.0
        mouth = py(iz + 0.6 + (mz - iz - 0.6) * u)
        nasa_shape(d, ix, mouth, mouth - R * 1.5, R, (236, 120, 140))
        for sx in (-0.3, 0, 0.3):
            d.line([(ix + sx * w, py(iz) - 0.6 * w), (ix, mouth)], fill=(230, 230, 236), width=max(2, int(2 * S)))
        if st >= 3:
            dashed(d, (gx, py(5.8)), (ix - 20 * S, py(5.8)), O.YEL, 3)
            label(d, (gx + 30 * S, py(5.8) + 36 * S), "袋の口 5,800m", 38, O.YEL, "lm")
            text(d, (ix + R + 30 * S, py(5.0)), "元の島の高さ（5,000m）とほぼ同じ", 36, O.WHITE, "lm", 4) if LAND and st == 3 else None
        if st == 4:
            gx2 = ix + (260 if LAND else 220) * S
            ov = Image.new("RGBA", img.size, (0, 0, 0, 0))
            od = ImageDraw.Draw(ov)
            od.rectangle([gx2 - R, py(10.6), gx2 + R, py(10.6) + 4 * S], fill=(255, 214, 64, 255))
            img.alpha_composite(ov)
            d = ImageDraw.Draw(img)
            island(img, gx2, py(5.0), w * 0.8, alpha=0.5)
            d = ImageDraw.Draw(img)
            nasa_shape(d, gx2, py(10.6), py(10.6) - R * 1.5, R, (120, 90, 110), outline=O.DIM)
            d.line([(gx2, py(5.0) - 0.6 * w), (gx2, py(10.6))], fill=O.DIM, width=max(2, int(2 * S)))
            label(d, (gx2, py(10.6) + 40 * S) if LAND else (gx2 - 10 * S, py(8.2)), "島が5,000mなら　口は11km", 34, O.WHITE, "mm")
    island(img, ix, py(iz), w)
    d = ImageDraw.Draw(img)
    if st <= 1:
        label(d, (ix + w * 0.8 + 20 * S, py(iz)), f"島 {int(round(iz * 1000 / 100) * 100):,}m", 38, O.YEL, "lm")
    else:
        label(d, (ix + w * 0.8 + 20 * S, py(1.0)), "島 1,000m", 38, O.YEL, "lm")
    if P.get("tag"):
        tagbox(d, box, P["tag"])
    head(d, box, "島を低い雲へ下ろす")


# ---- 9〜11章: 座布団の袋 -----------------------------------------------------------------------------

def cgeom(box, kmax=21.0):
    x0, y0, x1, y1 = box
    gy1 = y1 - 40 * S
    gy0 = y0 + 110 * S
    pk = min((gy1 - gy0) / kmax, (x1 - x0 - (220 if LAND else 60) * S) / 33)
    cx = (x0 + x1) / 2 + (40 * S if LAND else 0)
    return dict(pk=pk, cx=cx, py=lambda km: gy1 - pk * km, gy1=gy1, gy0=gy0)


def draw_cush(img, G, t, st=1, straps_hot=False, dx=0.0, tilt=0.0):
    """座布団の袋(直径32km・厚さ12km・口5.8km)と、漏斗のひもと島(1,000m、幅1.7km)。dx はずらし(km)。"""
    d = ImageDraw.Draw(img)
    pk, py = G["pk"], G["py"]
    cx = G["cx"] + dx * pk
    R = 16 * pk
    zb, zt = 5.8, 17.8
    yb, yt = py(zb), py(zt)
    iw = 1.7 * pk
    iy = py(1.0)
    # 袋
    d.rounded_rectangle([cx - R, yt, cx + R, yb], int(pk * 2.2), fill=(150, 196, 236), outline=O.WHITE, width=max(2, int(4 * S)))
    step = max(6 * S, R / 22)
    xx = cx - R + step
    col = RED_ if straps_hot else (205, 228, 248)
    while xx < cx + R - step * 0.5:
        d.line([(xx, yt + 3 * S), (xx, yb - 3 * S)], fill=col, width=max(1, int((5 if straps_hot else 2) * S)))
        xx += step
    # ひも(漏斗)
    if st >= 1:
        nn = 17
        for i in range(nn):
            bx = cx - R * 0.97 + 2 * R * 0.97 * i / (nn - 1)
            ax = cx - iw * 0.35 + iw * 0.7 * i / (nn - 1)
            d.line([(ax, iy - 0.55 * iw), (bx, yb)], fill=(232, 232, 238), width=max(1, int(2 * S)))
    island(img, cx, iy, iw)
    return dict(cx=cx, R=R, yb=yb, yt=yt, iy=iy, iw=iw)


def sc_cushion(img, box, t, k, P):
    sky(img, box)
    x0, y0, x1, y1 = box
    st = P.get("stage", 0)
    G = cgeom(box)
    d = ImageDraw.Draw(img)
    d.rectangle([x0, G["gy1"], x1, y1], fill=(50, 80, 60))
    clouds(img, (x0, G["py"](1.8), x1, G["py"](0.4)), t, 0, n=3, speed=8, alpha=0.45, size=0.30, seed=5)
    g = draw_cush(img, G, t, st=1 if st >= 1 else 0, straps_hot=(st == 6))
    d = ImageDraw.Draw(img)
    cx, R, yb, yt, iy, iw = g["cx"], g["R"], g["yb"], g["yt"], g["iy"], g["iw"]
    pk = G["pk"]
    bw = x1 - x0
    if st == 0:
        label(d, (cx, (yt + yb) / 2), "横に広い座布団の形", 46, O.NAVY if False else O.WHITE)
    if P.get("wlabel"):
        hbr(d, cx - R, cx + R, yt - 26 * S, "袋の幅", O.YEL, 38)
        label(d, (cx + iw * 2 + 10 * S, iy - 20 * S), "島　袋の幅の20分の1ほど", 34, O.YEL, "lm")
    if st in (2, 3, 4):
        u = _ease(k * 1.6) if st == 2 else 1.0
        for sgn in (-1, 1):
            xa = cx + sgn * R * 0.98
            arrow(d, (xa, yb + 30 * S), (xa - sgn * R * 0.35 * u, yb + 30 * S), O.YEL, 7 if st != 4 else 10, 28)
        if st == 2:
            label(d, (cx, yb + 80 * S if yb + 80 * S < iy - 60 * S else (yt + yb) / 2), "外側のひもが、袋を内側へ引き寄せる", 34, O.YEL)
    if st == 3:
        ox, oy = cx + R * 0.97, yb
        ax, ay = cx + iw * 0.35, iy - 0.55 * iw
        d.line([(ax, ay), (ox, oy)], fill=O.RED, width=max(3, int(6 * S)))
        d.line([(ox, oy), (ox, ay)], fill=O.DIM, width=max(2, int(2 * S)))
        d.line([(ax, ay), (ox, ay)], fill=O.DIM, width=max(2, int(2 * S)))
        text(d, ((ax + ox) / 2, ay + 18 * S), "横 3", 44, O.YEL, "ma", 5)
        text(d, (ox + 16 * S, (oy + ay) / 2), "縦 1", 44, O.YEL, "lm", 5)
        label(d, (cx, (yt + yb) / 2), "いちばん外のひもは、真下の3倍の力で横に引く", 34, O.WHITE, maxw=2 * R - 40 * S)
    if st == 4:
        label(d, (cx, (yt + yb) / 2), "横の力　島の重さの約2倍" if P.get("two") else "横の力　島の重さの2倍以上", 44, O.RED, maxw=2 * R - 40 * S)
    if st == 5:
        u = _ease(k * 1.5) if not P.get("balance") else 1.0
        cyy = (yt + yb) / 2
        for sgn in (-1, 1):
            for f in (-0.25, 0.25):
                xa = cx + sgn * R * 0.55
                arrow(d, (xa, cyy + f * (yb - yt)), (xa + sgn * R * 0.38 * u, cyy + f * (yb - yt)), (255, 255, 255), 6, 24)
        if P.get("balance"):
            for sgn in (-1, 1):
                xa = cx + sgn * R * 0.98
                arrow(d, (xa, yb + 30 * S), (xa - sgn * R * 0.25, yb + 30 * S), O.YEL, 6, 24)
        s = P.get("plabel") or ("余裕を持たせて押し返す" if P.get("balance") else "口を閉じて、中の圧力で押し返す")
        label(d, (cx, yt - 40 * S), s, 38, O.YEL, maxw=2 * R)
    if st == 6:
        label(d, (cx, (yt + yb) / 2), "圧力を閉じ込める帯が重すぎる", 44, O.RED, maxw=2 * R - 40 * S)
    if st == 7:
        hbr(d, cx - R, cx + R, yt - 26 * S, "直径32km", O.YEL, 48)
        vbr(d, cx + R + 26 * S, yt, yb, "厚さ\n12km", O.YEL, 40) if LAND else vbr(d, cx - R - 4 * S, yt, yb, "", O.YEL, 40, "l")
        if not LAND:
            label(d, (cx, (yt + yb) / 2), "厚さ12km", 44, O.YEL)
    if st == 8:
        sx, sy = x1 - 120 * S, y0 + 160 * S
        d.ellipse([sx - 50 * S, sy - 50 * S, sx + 50 * S, sy + 50 * S], fill=(255, 210, 80))
        for i in range(10):
            a = i * math.pi / 5 + t * 0.4
            d.line([(sx + 65 * S * math.cos(a), sy + 65 * S * math.sin(a)), (sx + 90 * S * math.cos(a), sy + 90 * S * math.sin(a))], fill=(255, 210, 80), width=max(2, int(4 * S)))
        label(d, (cx, (yt + yb) / 2), "口を閉じた袋　温まってもガスは逃げない", 36, O.WHITE, maxw=2 * R - 40 * S)
    if st == 9:
        for j in range(4):
            yy = yt + (yb - yt) * (0.2 + 0.2 * j)
            xx = x0 + 30 * S + ((t * 120 * S + j * 70 * S) % (120 * S))
            arrow(d, (xx, yy), (xx + 80 * S, yy), (230, 240, 255), 5, 20)
        label(d, (cx, (yt + yb) / 2), "風 秒速20m　押す力は島の重さの0.1%足らず", 36, O.WHITE, maxw=2 * R - 40 * S)
    if P.get("tag"):
        tagbox(d, box, P["tag"])
    head(d, box, "座布団の袋と漏斗のひも（縮尺どおり）")


def sc_final(img, box, t, k, P):
    x0, y0, x1, y1 = box
    st = P.get("stage", 0)
    sky(img, box)
    G = cgeom(box)
    d = ImageDraw.Draw(img)
    pk, py = G["pk"], G["py"]
    drift = st == 6
    # 地面(流される回は地面が後ろへ流れる)
    d.rectangle([x0, G["gy1"], x1, y1], fill=(50, 80, 60))
    off = (t * 60 * S) % (200 * S) if drift else 0
    xx = x0 - off
    while xx < x1:
        d.polygon([(xx, G["gy1"]), (xx + 60 * S, G["gy1"] - 26 * S), (xx + 120 * S, G["gy1"])], fill=(60, 96, 70))
        xx += 200 * S
    clouds(img, (x0, py(1.9), x1, py(0.3)), t * (2.5 if drift else 1), 0, n=4, speed=8, alpha=0.5, size=0.28, seed=9)
    g = draw_cush(img, G, t, st=1, dx=(0.6 * math.sin(t * 0.3) if drift else 0))
    d = ImageDraw.Draw(img)
    cx, R, yb, yt, iy, iw = g["cx"], g["R"], g["yb"], g["yt"], g["iy"], g["iw"]
    clouds(img, (x0, py(1.6), x1, py(0.6)), t * (2.5 if drift else 1), 1, n=2, speed=12, alpha=0.35, size=0.25, seed=11)
    d = ImageDraw.Draw(img)
    gx = x0 + (90 if LAND else 70) * S
    allx = P.get("all")
    if 1 <= st <= 5:
        dashed(d, (gx, iy), (cx - iw, iy), O.YEL, 2)
        text(d, (gx, iy - 10 * S), "1,000m", 30, O.YEL, "ld", 3)
    if st == 1:
        label(d, (cx + iw * 1.2 + 20 * S, iy - 6 * S), "城と巨木と岩の島", 34, O.YEL, "lm")
    if st == 2 or allx:
        hbr(d, cx - R, cx + R, yt - 24 * S, "直径32km　東京23区がすっぽり隠れる", O.YEL, 38 if LAND else 32)
        if st == 2:
            vbr(d, cx + R * 0.55, yb, iy - iw * 0.6, "4.8km", O.YEL, 36)
    if st == 3 and not allx:
        ox = cx + R * 0.97
        d.line([(cx + iw * 0.35, iy - 0.55 * iw), (ox, yb)], fill=O.YEL, width=max(3, int(6 * S)))
        label(d, (cx + R * 0.55, (yb + iy) / 2 + 10 * S), "長いもので17kmのひも", 36, O.YEL)
    if st == 4:
        dashed(d, (gx, yt), (cx - R, yt), O.YEL, 2)
        text(d, (gx, yt - 10 * S), "17.8km", 30, O.YEL, "ld", 3)
        label(d, (cx, (yt + yb) / 2), "てっぺんは地上17.8km", 44, O.YEL)
        ay = py(10.0)
        ax = x0 + ((t * 80 * S) % (x1 - x0))
        d.polygon([(ax, ay), (ax - 50 * S, ay - 8 * S), (ax - 50 * S, ay + 8 * S)], fill=O.WHITE)
        d.polygon([(ax - 28 * S, ay), (ax - 40 * S, ay - 22 * S), (ax - 34 * S, ay)], fill=O.WHITE)
        text(d, (ax - 60 * S, ay), "旅客機 約10km", 30, O.WHITE, "rm", 3)
    if st == 5:
        r = (105 if LAND else 95) * S
        zx, zy = cx + R * 0.62, yb + (iy - yb) * 0.42
        d.ellipse([cx - iw * 1.2, iy - iw * 1.3, cx + iw * 1.2, iy + iw * 1.3], outline=O.YEL, width=max(2, int(3 * S)))
        d.line([(cx + iw * 1.2, iy), (zx - r, zy)], fill=O.YEL, width=max(2, int(2 * S)))
        d.ellipse([zx - r, zy - r, zx + r, zy + r], fill=(60, 100, 150), outline=O.YEL, width=max(2, int(4 * S)))
        island(img, zx, zy + 10 * S, r * 0.95)
        d = ImageDraw.Draw(img)
        label(d, (cx - R * 0.5, yb + (iy - yb) * 0.42), "島の幅は袋の約19分の1", 36, O.YEL)
    if drift:
        for j in range(3):
            yy = yt + (yb - yt) * (0.3 + 0.25 * j)
            xa = x0 + 20 * S + ((t * 140 * S + j * 60 * S) % (140 * S))
            arrow(d, (xa, yy), (xa + 70 * S, yy), (230, 240, 255), 4, 18)
        if P.get("speed"):
            label(d, (cx, (yt + yb) / 2), "風と一緒に　時速72km", 50, O.YEL)
        else:
            label(d, (cx, (yt + yb) / 2), "横から押さえるものが無い", 40, O.WHITE)
    head(d, box, "結末の絵（縮尺どおり）" if not drift else "島は風と一緒に流される")


# ---- ショートだけの図 ---------------------------------------------------------------------------------

def sc_counter(img, box, t, k, P):
    grad(img, box=box)
    x0, y0, x1, y1 = box
    d = ImageDraw.Draw(img)
    cx = (x0 + x1) / 2
    n = int(1 + (t * 1.0) % 9999)
    sec = (t % 1.0)
    r = 60 * S * (0.4 + 0.6 * _ease(sec * 2))
    balloon_at(d, cx, y0 + (y1 - y0) * 0.36, r, sway=t)
    text(d, (cx, y0 + (y1 - y0) * 0.62), "1秒に1個", 80, O.YEL, "mm", 6)
    text(d, (cx, y0 + (y1 - y0) * 0.75), "休まず、ふくらませる", 46, O.WHITE, "mm", 5)
    head(d, box, "170兆個をふくらませる")


def sc_three(img, box, t, k, P):
    grad(img, box=box)
    x0, y0, x1, y1 = box
    d = ImageDraw.Draw(img)
    st = P.get("stage", 1)
    bw, bh = x1 - x0, y1 - y0
    wz = bw * 0.30
    icx, icy = (x0 + x1) / 2, y0 + bh * 0.28
    island(img, icx, icy, wz)
    d = ImageDraw.Draw(img)
    hbr(d, icx - wz / 2, icx + wz / 2, icy + 30 * S, "", O.YEL, 30, up=False)
    rows = [("柳田理科雄", "パズーの身長1.4mとして", "1.6km"), ("岡田斗司夫", "凧の操縦席1m・崩れたあとの段", "1.76km"), ("QuizKnock", "作中の画面から", "1.8km")]
    for i, (nm, why, v) in enumerate(rows):
        if i >= st:
            continue
        cy = y0 + bh * (0.56 + 0.15 * i)
        a = 1.0 if i < st - 1 else _ease(k * 3)
        on = i == st - 1
        d.rounded_rectangle([x0 + 30 * S, cy - 70 * S, x1 - 30 * S, cy + 70 * S], int(16 * S), fill=mix((40, 60, 100) if on else (26, 38, 70), BG1, a), outline=O.YEL if on else O.DIM, width=max(2, int(3 * S)))
        text(d, (x0 + 60 * S, cy - 22 * S), nm, 44, O.WHITE, "lm", 4)
        vtext(d, (x0 + 60 * S, cy + 32 * S), why, 32, O.DIM, "lm", maxw=bw * 0.6)
        text(d, (x1 - 60 * S, cy), v, 64, O.YEL, "rm", 5)
    head(d, box, "城のいちばん下の段の幅")


def sc_lattice(img, box, t, k, P):
    grad(img, box=box)
    x0, y0, x1, y1 = box
    d = ImageDraw.Draw(img)
    cx = (x0 + x1) / 2
    cy = (y0 + y1) / 2 + (10 if LAND else -40) * S
    s = 34 * S
    hei = 440 * S
    Rr = 130 * S
    d.rounded_rectangle([cx - Rr, cy - hei / 2, cx + Rr, cy + hei / 2], int(Rr), fill=(24, 44, 84), outline=O.WHITE, width=int(4 * S))
    dy = math.sqrt(3) * s
    wid = math.pi * Rr * 0.98
    for i in range(-12, 13):
        for j in range(-8, 9):
            hx = i * 1.5 * s
            hy = j * dy + (i % 2) * dy / 2 + (t * 10 * S) % dy
            if abs(hx) > wid / 2 or abs(hy) > hei * 0.42:
                continue
            pts = []
            for a in range(6):
                th = math.radians(60 * a)
                vx, vy = hx + s * math.cos(th), hy + s * math.sin(th)
                if abs(vx) > wid / 2 or abs(vy) > hei * 0.43:
                    pts = None
                    break
                pts.append((cx + Rr * math.sin(vx / Rr), cy + vy))
            if pts:
                d.polygon(pts, outline=(110, 200, 235))
    if LAND:
        text(d, (cx + Rr + 70 * S, cy - 40 * S), "炭素の原子が", 46, O.WHITE, "lm", 5)
        text(d, (cx + Rr + 70 * S, cy + 20 * S), "筒になった、細い糸", 46, O.YEL, "lm", 5)
        text(d, (cx - Rr - 70 * S, cy - 10 * S), "実験室で作られた", 40, O.WHITE, "rm", 4)
    else:
        text(d, (cx, cy + hei / 2 + 60 * S), "炭素の原子が筒になった、細い糸", 44, O.YEL, "mm", 5)
    head(d, box, "カーボンナノチューブ")
    text(d, ((x0 + x1) / 2, y1 - 14 * S), "並びを模式的に描いています", 26, O.DIM, "md", 3)


KINDS = dict(island=sc_island, formula=sc_formula, bars=sc_bars, table=sc_table, big=sc_big, fill=sc_fill, domes=sc_domes, balloon=sc_balloon,
             cube=sc_cube, people=sc_people, row=sc_row, airbox=sc_airbox, alt=sc_alt, gasbar=sc_gasbar, rise=sc_rise, snack=sc_snack, two=sc_two,
             weather=sc_weather, nasa=sc_nasa, domevs=sc_domevs, ship=sc_ship, spheres=sc_spheres, column=sc_column, under=sc_under,
             timeline=sc_timeline, hot=sc_hot, share=sc_share, mix4=sc_mix4, bag=sc_bag, aircol=sc_aircol, area=sc_area, cluster=sc_cluster,
             low=sc_low, cushion=sc_cushion, final=sc_final, counter=sc_counter, three=sc_three, lattice=sc_lattice)
SELF_TAG = ("alt", "low", "cushion", "share")      # 自分で札(tag)を描く図


def region(P=None):
    return (0, 100, W, 880) if LAND else (0, 240, W, 1370)


def paint(sc, t, k):
    img = Image.new("RGBA", (W, H), BG0 + (255,))
    box = region(sc)
    grad(img, box=box)
    KINDS[sc["kind"]](img, box, t, k, sc)
    dd = ImageDraw.Draw(img)                       # 図の範囲の外(字幕の所)へはみ出した雲などを消す
    dd.rectangle([0, 0, W, box[1] - 1], fill=BG0)
    dd.rectangle([0, box[3] + 1, W, H], fill=BG0)
    if sc.get("tag") and sc["kind"] not in SELF_TAG:
        tagbox(ImageDraw.Draw(img), box, sc["tag"])
    return img


def draw(img, dr, t, ctx):
    lines, defs = ctx["lines"], ctx["defs"]
    scs = ctx.setdefault("_scenes", mapscene.scenes(lines, defs))
    cur = ctx["cur"] or lines[0]
    i = next(j for j, l in enumerate(lines) if l["id"] == cur["id"])
    now, prev = scs[i], (scs[i - 1] if i > 0 else None)
    k = ctx["k"]
    if prev is now:      # 前の行から引き継いだ図は、描き直さずそのまま見せる
        k = 1.0
    u = _ease((t - cur["start"]) / 0.5)
    b = paint(prev, t, 1.0) if prev is not None and prev is not now and u < 1 else None
    O.BOXES.clear()
    a = paint(now, t, k)
    if b is not None:
        a = Image.blend(b, a, u)
    # ゆっくり寄ったり引いたり(画面を止めない)
    z = 1.0 + 0.03 * (0.5 + 0.5 * math.sin(2 * math.pi * t / 12.0))
    if z > 1.0005:
        zw, zh = int(W * z), int(H * z)
        a = a.resize((zw, zh), Image.BILINEAR).crop(((zw - W) // 2, (zh - H) // 2, (zw - W) // 2 + W, (zh - H) // 2 + H))
    img.paste(a, (0, 0))


def sfx_for(lines_def, L):
    ev = mapscene.sfx(lines_def, L)
    for d in lines_def:
        s = d.get("scene") or {}
        if (s.get("mark") or s.get("kind") == "formula" and s.get("mark")) and d["id"] in L:
            ev.append((L[d["id"]]["start"] + 0.05, "pop"))
        elif s.get("kind") == "bars" and s.get("mark") and d["id"] in L:
            l = L[d["id"]]
            ev.append((l["start"] + 0.4 * (l["end"] - l["start"]), "pop"))
    return sorted(ev)

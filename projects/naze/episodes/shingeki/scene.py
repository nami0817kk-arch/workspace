"""進撃の巨人の回の画面。行の scene=dict(kind=…) を描く(無い行は前の行を引き継ぐ)。場面が変わると 0.5 秒で溶け合わせる。

kind: wall / grow / box3 / elephants / bonesec / coin / formula / meter / curve / steel / thigh / styro / galileo / photo
作品の絵は使わない。巨人は人の形の影絵(作品の見た目に寄せない)。動物の写真風の絵は Gemini で作った(assets/*_gemini.jpg)。
数字の出どころは research.md。骨の負担 = 歩く 10MPa(走る 30MPa)× 身長の倍率、つぶれる強さ 200MPa。
"""
from __future__ import annotations

import math
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

from naze import mapscene, overlay as O
from naze.config import H, W

LAND = W > H
S = min(W, H) / 1080
ASSETS = Path(__file__).resolve().parent / "assets"
COLS = dict(dim=O.DIM, white=O.WHITE, yel=O.YEL, red=O.RED, green=O.GREEN)
SKIN = (196, 120, 96)
GIANT = (150, 70, 60)
BG0, BG1 = (10, 18, 40), (16, 30, 62)
STRENGTH, WALK, RUN, H0 = 200.0, 10.0, 30.0, 1.7


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


def label(d, xy, s, size=40, col=O.WHITE, anchor="mm"):
    """白い字の小さな札(箱つき)。重なりの点検に載せる。"""
    f = O.font(int(size * S))
    bb = d.textbbox(xy, s, font=f, anchor=anchor)
    pad = 12 * S
    box = (bb[0] - pad, bb[1] - pad * 0.7, bb[2] + pad, bb[3] + pad * 0.7)
    d.rounded_rectangle(box, int(10 * S), fill=O.NAVY + (220,), outline=col, width=max(2, int(3 * S)))
    d.text(xy, s, font=f, fill=col, anchor=anchor)
    O.BOXES.append(("label", box, s, 1.0))


def person(d, x, yb, hp, col=SKIN, outline=None):
    """足元 (x, yb)、高さ hp ピクセルの人の影絵(正面)。"""
    u = hp / 8.0                                    # 8 頭身
    hw = u * 0.42
    d.ellipse([x - hw, yb - hp, x + hw, yb - hp + u], fill=col, outline=outline)
    d.rounded_rectangle([x - u * 0.95, yb - hp + u * 1.05, x + u * 0.95, yb - u * 3.9], radius=max(1, int(u * 0.35)), fill=col, outline=outline)
    lw = max(2, int(u * 0.62))
    d.line([(x - u * 0.45, yb - u * 4.0), (x - u * 0.55, yb)], fill=col, width=lw)
    d.line([(x + u * 0.45, yb - u * 4.0), (x + u * 0.55, yb)], fill=col, width=lw)
    aw = max(2, int(u * 0.42))
    d.line([(x - u * 1.0, yb - hp + u * 1.3), (x - u * 1.35, yb - u * 4.1)], fill=col, width=aw)
    d.line([(x + u * 1.0, yb - hp + u * 1.3), (x + u * 1.35, yb - u * 4.1)], fill=col, width=aw)


def elephant(d, x, yb, s, col=(170, 175, 185)):
    """足元 (x, yb)、幅 s の小さなゾウの形。"""
    d.ellipse([x - s * 0.45, yb - s * 0.78, x + s * 0.35, yb - s * 0.28], fill=col)
    d.ellipse([x + s * 0.18, yb - s * 0.86, x + s * 0.55, yb - s * 0.5], fill=col)
    d.line([(x + s * 0.5, yb - s * 0.6), (x + s * 0.56, yb - s * 0.15)], fill=col, width=max(1, int(s * 0.1)))
    for dx in (-0.33, -0.15, 0.08, 0.24):
        d.rectangle([x + s * dx, yb - s * 0.4, x + s * (dx + 0.1), yb], fill=col)


def load(h, mode):
    return (RUN if mode == "run" else WALK) * h / H0


# ---- 場面 -------------------------------------------------------------------------------

def sc_wall(img, box, t, k, P):
    x0, y0, x1, y1 = box
    grad(img, (60, 90, 130), (150, 175, 200), box)
    d = ImageDraw.Draw(img)
    gy = y1 - 30 * S
    sc = (gy - y0 - 70 * S) / 62.0                   # 1m あたりのピクセル
    d.rectangle([x0, gy, x1, y1], fill=(70, 80, 60))
    gx = x0 + (x1 - x0) * (0.62 if LAND else 0.6)
    bob = 0.6 * sc * math.sin(t * 0.9)
    person(d, gx, gy + bob, 60 * sc, GIANT)
    wy = gy - 50 * sc
    d.rectangle([x0, wy, x1, gy], fill=(120, 112, 100))
    for i in range(int((x1 - x0) / (60 * S)) + 1):
        d.line([(x0 + i * 60 * S, wy), (x0 + i * 60 * S, gy)], fill=(100, 94, 84), width=2)
    d.rectangle([x0, wy - 6 * S, x1, wy + 4 * S], fill=(140, 132, 118))
    hx = x0 + (x1 - x0) * 0.12
    person(d, hx, gy, max(6 * S, 1.7 * sc), O.YEL)
    # 縦は地面の近くが結びのお願いの画面と重なるので、壁の上に出す
    label(d, (hx + 10 * S, gy - 40 * S if LAND else wy + 50 * S), "人 1.7m", 30, O.YEL)
    label(d, (x0 + (x1 - x0) * 0.3, wy + 50 * S), "壁 50m", 40, O.WHITE)
    label(d, (max(x0 + 90 * S, gx - 60 * sc * 0.16 - 90 * S), gy - 57 * sc), "60m", 44, O.YEL)
    if P.get("building"):
        bx0, bx1 = x0 + (x1 - x0) * 0.82, x0 + (x1 - x0) * 0.95
        a = _ease(k * 3)
        top = gy - 60 * sc * a
        d.rectangle([bx0, top, bx1, gy], fill=(70, 90, 120), outline=(200, 210, 230), width=2)
        for f in range(1, 20):
            fy = gy - f * 3 * sc
            if fy > top:
                d.line([(bx0, fy), (bx1, fy)], fill=(150, 170, 200), width=1)
        if a > 0.95:
            label(d, ((bx0 + bx1) / 2, top - 40 * S), "ビル 約20階", 34, O.WHITE)


def sc_grow(img, box, t, k, P):
    x0, y0, x1, y1 = box
    grad(img, box=box)
    d = ImageDraw.Draw(img)
    h0, h1 = P["h"]
    h = h0 * (h1 / h0) ** _ease(k * 1.4) if h1 != h0 else h0
    gy = y1 - 40 * S
    top = max(h1, 1.7) * 1.08
    sc = (gy - y0 - 40 * S) / top
    d.line([(x0, gy), (x1, gy)], fill=O.DIM, width=int(3 * S))
    cx = (x0 + x1) / 2 + (x1 - x0) * 0.08
    person(d, cx, gy, h * sc, GIANT if h > 3 else SKIN)
    rx = x0 + (x1 - x0) * 0.16                          # 目盛り
    d.line([(rx, gy), (rx, gy - top * sc / 1.08)], fill=O.DIM, width=int(3 * S))
    step = 10 if top > 30 else (5 if top > 8 else 1)
    for m in range(0, int(top) + 1, step):
        yy = gy - m * sc
        d.line([(rx - 12 * S, yy), (rx, yy)], fill=O.DIM, width=int(2 * S))
        text(d, (rx - 20 * S, yy), f"{m}m", 28, O.DIM, "rm", 3)
    if h1 > 3:
        person(d, cx - (x1 - x0) * 0.2, gy, max(4 * S, 1.7 * sc), O.YEL)
    label(d, (x0 + (x1 - x0) * 0.78, y0 + 50 * S), f"身長 {h:.1f}m" if h < 10 else f"身長 {h:.0f}m", 46, O.YEL)
    w = 65 * (h / H0) ** 3
    label(d, (x0 + (x1 - x0) * 0.78, y0 + 130 * S), f"体重 約{w:,.0f}kg" if w < 1000 else (f"体重 約{w / 1000:,.0f}トン" if w < 1e6 else f"体重 約{round(w / 1e4) * 10:,.0f}トン"), 40, O.WHITE)


def _cube(d, cx, cy, w, h, dep, col):
    dx, dy = dep * 0.6, -dep * 0.45
    front = [(cx - w / 2, cy - h / 2), (cx + w / 2, cy - h / 2), (cx + w / 2, cy + h / 2), (cx - w / 2, cy + h / 2)]
    topf = [front[0], front[1], (front[1][0] + dx, front[1][1] + dy), (front[0][0] + dx, front[0][1] + dy)]
    side = [front[1], (front[1][0] + dx, front[1][1] + dy), (front[2][0] + dx, front[2][1] + dy), front[2]]
    d.polygon(side, fill=tuple(int(c * 0.6) for c in col), outline=O.WHITE)
    d.polygon(topf, fill=tuple(min(255, int(c * 1.2)) for c in col), outline=O.WHITE)
    d.polygon(front, fill=col, outline=O.WHITE)


def sc_box3(img, box, t, k, P):
    x0, y0, x1, y1 = box
    grad(img, box=box)
    d = ImageDraw.Draw(img)
    m = min(x1 - x0, y1 - y0)
    base = m * 0.12
    big = m * 0.42
    u = [_ease(k * 4 - i) for i in range(3)]
    w = base + (big - base) * u[0]
    h = base + (big - base) * u[1]
    dep = base + (big - base) * u[2]
    cx, cy = (x0 + x1) / 2 - dep * 0.3, (y0 + y1) / 2 + dep * 0.2
    _cube(d, cx, cy, w, h, dep, (150, 80, 70))
    names = ["背 ×35", "肩幅 ×35", "厚み ×35"]
    order = [1, 0, 2]
    pos = [(cx + w / 2 + 120 * S, cy), (cx, cy + h / 2 + 50 * S), (cx + w / 2 + dep * 0.3 + 60 * S, cy - h / 2 - dep * 0.35)]
    for i, j in enumerate(order):
        if u[i] > 0.3:
            label(d, pos[j], names[j], 40, O.YEL)
    if k > 0.8:
        label(d, ((x0 + x1) / 2, y0 + 50 * S), "重さ = 35 × 35 × 35 ＝ 約4万4千倍", 44, O.WHITE)


def sc_elephants(img, box, t, k, P):
    x0, y0, x1, y1 = box
    grad(img, box=box)
    d = ImageDraw.Draw(img)
    n = P.get("n", 480)
    cols = 30 if LAND else 20
    rows = math.ceil(n / cols)
    cw = (x1 - x0 - 80 * S) / cols
    ch = (y1 - y0 - 160 * S) / rows
    s = min(cw * 0.9, ch * 1.3)
    shown = int(n * _ease(k * 1.6))
    for i in range(shown):
        r, c = divmod(i, cols)
        elephant(d, x0 + 40 * S + (c + 0.5) * cw - s * 0.05, y0 + 130 * S + (r + 1) * ch, s)
    label(d, ((x0 + x1) / 2, y0 + 55 * S), f"ゾウ {shown}頭  ＝ 約{shown * 6:,}トン" if shown < n else "ゾウ 約480頭分 ＝ 約2,860トン", 44, O.YEL)


def sc_bonesec(img, box, t, k, P):
    x0, y0, x1, y1 = box
    grad(img, box=box)
    d = ImageDraw.Draw(img)
    m = min(x1 - x0, y1 - y0)
    lx, ly = x0 + (x1 - x0) * (0.22 if LAND else 0.25), (y0 + y1) / 2 + 20 * S
    r = m * 0.07
    d.ellipse([lx - r, ly - r, lx + r, ly + r], fill=(235, 230, 210))
    d.ellipse([lx - r * 0.5, ly - r * 0.5, lx + r * 0.5, ly + r * 0.5], fill=(150, 80, 70))
    label(d, (lx, ly + r + 50 * S), "人の骨の断面", 34, O.DIM)
    gx, gy = x0 + (x1 - x0) * (0.48 if LAND else 0.5), y0 + 120 * S
    side = min(x1 - gx - 40 * S, y1 - gy - 60 * S)
    n = 35
    c = side / n
    fill = int(n * n * _ease(k * 1.5))
    for i in range(fill):
        rr, cc = divmod(i, n)
        d.rectangle([gx + cc * c, gy + rr * c, gx + (cc + 1) * c - 1, gy + (rr + 1) * c - 1], fill=(235, 230, 210))
    for j in range(0, n + 1, 5):
        d.line([(gx + j * c, gy), (gx + j * c, gy + side)], fill=(150, 140, 120), width=1)
        d.line([(gx, gy + j * c), (gx + side, gy + j * c)], fill=(150, 140, 120), width=1)
    d.rectangle([gx, gy, gx + side, gy + side], outline=O.WHITE, width=2)
    label(d, (gx + side / 2, y0 + 55 * S), f"断面 ×{fill:,}" if fill < n * n else "断面 約1,250倍（35×35）", 42, O.YEL)


def sc_coin(img, box, t, k, P):
    x0, y0, x1, y1 = box
    grad(img, box=box)
    d = ImageDraw.Draw(img)
    m = min(x1 - x0, y1 - y0)
    cx, cy = x0 + (x1 - x0) * 0.3, (y0 + y1) / 2 + 30 * S
    r = m * 0.18 * (1 + 0.02 * math.sin(t * 2))
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(205, 210, 215), outline=(240, 240, 245), width=int(4 * S))
    text(d, (cx, cy), "1", int(r / S * 0.9), (150, 155, 160), "mm", 0)
    label(d, (cx, cy + r + 50 * S), "1円玉の広さ（約314平方mm）", 32, O.DIM)
    a = _ease(k * 2 - 0.4)
    if a > 0:
        ex = x0 + (x1 - x0) * 0.72
        elephant(d, ex - m * 0.12, cy + m * 0.2 - (1 - a) * 80 * S, m * 0.4)
        label(d, (ex, cy - m * 0.3), "約6トン（ゾウ1頭）", 40, O.YEL)
    label(d, ((x0 + x1) / 2, y0 + 50 * S), "骨は 1平方mmに 約20kg でつぶれる", 40, O.WHITE)


def sc_formula(img, box, t, k, P):
    grad(img, box=box)
    x0, y0, x1, y1 = box
    d = ImageDraw.Draw(img)
    cx = (x0 + x1) / 2
    rows = P["rows"]
    gap = (y1 - y0) / (len(rows) + 1)
    for i, (s, size, col) in enumerate(rows):
        a = _ease(k * (len(rows) + 0.5) * 1.8 - i)
        if a <= 0:
            continue
        cc = COLS[col]
        c = tuple(int(v * a + 20 * (1 - a)) for v in cc)
        text(d, (cx, y0 + gap * (i + 1) + 6 * S * math.sin(t * 1.3 + i)), s, size, c, "mm", 6)


def sc_meter(img, box, t, k, P):
    """骨にかかる負担のメーター(つぶれる強さを 100%)。seq の身長を行の中で順に動く。"""
    x0, y0, x1, y1 = box
    grad(img, box=box)
    d = ImageDraw.Draw(img)
    seq = P["seq"]
    if len(seq) == 1:
        h, mode = seq[0]
        pct = load(h, mode) / STRENGTH
    else:
        n = len(seq) - 1
        u = _ease(k * 1.3) * n
        i = min(n - 1, int(u))
        f = _ease(u - i)
        (ha, ma), (hb, mb) = seq[i], seq[i + 1]
        h = ha + (hb - ha) * f
        mode = mb if f > 0.5 else ma
        pct = (load(ha, ma) + (load(hb, mb) - load(ha, ma)) * f) / STRENGTH
    # 左: 人の影絵(身長に合わせて大きく。60m を枠いっぱい)
    gy = y1 - 50 * S
    lx = x0 + (x1 - x0) * (0.18 if LAND else 0.2)
    hp = (gy - y0 - 140 * S) * (0.12 + 0.88 * min(1.0, h / 60))
    person(d, lx, gy, hp, GIANT if h > 3 else SKIN)
    d.line([(x0 + 20 * S, gy), (x0 + (x1 - x0) * 0.36, gy)], fill=O.DIM, width=int(3 * S))
    label(d, (lx, y0 + 50 * S), f"身長 {h:.1f}m" if h < 10 else f"身長 {h:.0f}m", 42, O.YEL)
    label(d, (lx, y0 + 120 * S), "走る" if mode == "run" else "歩く", 36, O.WHITE)
    # 右: 横のメーター 0〜200%
    mx0, mx1 = x0 + (x1 - x0) * 0.42, x1 - (x1 - x0) * 0.06
    my = (y0 + y1) / 2 + 20 * S
    bh = 70 * S
    full = 2.0
    px = lambda p: mx0 + (mx1 - mx0) * min(p, full) / full
    d.rounded_rectangle([mx0, my - bh / 2, mx1, my + bh / 2], int(14 * S), fill=(30, 40, 60), outline=O.DIM, width=int(3 * S))
    col = O.GREEN if pct < 0.5 else (O.YEL if pct < 1.0 else O.RED)
    if pct > 0.005:
        d.rounded_rectangle([mx0, my - bh / 2, max(mx0 + 14 * S, px(pct)), my + bh / 2], int(14 * S), fill=col)
    xb = px(1.0)
    d.line([(xb, my - bh), (xb, my + bh)], fill=O.WHITE, width=int(5 * S))
    text(d, (xb, my + bh + 14 * S), "骨がつぶれる強さ", 32, O.WHITE, "ma", 4)
    for p, s in ((0, "0"), (0.5, "50%"), (1.5, "150%"), (2.0, "200%")):
        text(d, (px(p), my - bh - 14 * S), s, 28, O.DIM, "md", 3)
    shake = 4 * S * math.sin(t * 40) if pct >= 1 else 0
    big = f"強さの {pct * 100:.0f}%" if pct < 1 else f"強さの {math.floor(pct * 10 + 1e-6) / 10:.1f}倍"
    label(d, ((mx0 + mx1) / 2 + shake, y0 + 70 * S), big, 64, col)
    if pct >= 1:
        label(d, ((mx0 + mx1) / 2, my + bh + 120 * S), "骨が折れる", 50, O.RED)


def sc_curve(img, box, t, k, P):
    x0, y0, x1, y1 = box
    grad(img, box=box)
    d = ImageDraw.Draw(img)
    gx0, gx1 = x0 + (x1 - x0) * 0.14, x1 - (x1 - x0) * 0.08
    gy0, gy1 = y0 + (y1 - y0) * 0.16, y1 - (y1 - y0) * 0.14
    K = 10
    px = lambda kk: gx0 + (gx1 - gx0) * (kk - 1) / (K - 1)
    py = lambda v: gy1 - (gy1 - gy0) * min(v, 1000) / 1000
    d.line([(gx0, gy1), (gx1, gy1)], fill=O.DIM, width=int(3 * S))
    d.line([(gx0, gy0), (gx0, gy1)], fill=O.DIM, width=int(3 * S))
    for kk in (1, 5, 10):
        text(d, (px(kk), gy1 + 12 * S), f"{kk}倍", 30, O.DIM, "ma", 3)
    text(d, (gx1, gy1 + 56 * S), "背の高さ →", 30, O.DIM, "ra", 3)
    u = _ease(k * 1.5)
    kmax = 1 + (K - 1) * u
    n = 80
    p3 = [(px(1 + (kmax - 1) * i / n), py((1 + (kmax - 1) * i / n) ** 3)) for i in range(n + 1)]
    p2 = [(px(1 + (kmax - 1) * i / n), py((1 + (kmax - 1) * i / n) ** 2)) for i in range(n + 1)]
    d.line(p3, fill=O.RED, width=int(8 * S), joint="curve")
    d.line(p2, fill=O.BLUE, width=int(8 * S), joint="curve")
    if kmax >= 6:  # 線が伸びきる前は2つの札が原点に重なる
        label(d, (px(min(kmax, 8.2)) - 160 * S, py(min(kmax, 8.2) ** 3) - 10 * S), "重さ（3乗）", 38, O.RED)
        label(d, (px(kmax) - 120 * S, py(kmax ** 2) - 50 * S), "骨の強さ（2乗）", 38, O.BLUE)
    text(d, (gx0, gy0 - 50 * S), "人を1として何倍になるか", 34, O.DIM, "la", 4)


def sc_steel(img, box, t, k, P):
    x0, y0, x1, y1 = box
    grad(img, box=box)
    d = ImageDraw.Draw(img)
    st = P.get("stage", 1)
    if st == 4:
        cx = (x0 + x1) / 2
        m = min(x1 - x0, y1 - y0)
        s1, s2 = m * 0.18, m * 0.18
        bx, sx = cx - m * 0.35, cx + m * 0.15
        by = (y0 + y1) / 2 + 80 * S
        d.rectangle([bx, by - s1, bx + s1, by], fill=(235, 230, 210))
        d.rectangle([sx, by - s2, sx + s2, by], fill=(120, 130, 145))
        label(d, (bx + s1 / 2, by + 50 * S), "骨 1.9g", 38, O.WHITE)
        label(d, (sx + s2 / 2, by + 50 * S), "鉄 7.9g", 38, O.WHITE)
        label(d, (cx, y0 + 60 * S), "同じ大きさで 鉄は骨の約4倍重い", 42, O.YEL)
        text(d, (cx, by + 120 * S), "1立方cmあたり", 30, O.DIM, "ma", 3)
        return
    items = [("人の骨", 200, 34, (235, 230, 210))]
    if st >= 1:
        items.append(("ふつうの鋼", 245, 42, (150, 160, 175)))
    else:
        items.append(("鉄？", 0, 0, (150, 160, 175)))
    if st >= 3:
        items.append(("橋の強い鋼", 460, 78, (110, 150, 200)))
    gx0, gx1 = x0 + (x1 - x0) * 0.26, x1 - (x1 - x0) * 0.08
    n = len(items)
    rh = (y1 - y0 - 120 * S) / max(3, n)
    u = _ease(k * 1.6)
    for i, (name, mpa, hm, col) in enumerate(items):
        cy = y0 + 120 * S + rh * (i + 0.5)
        text(d, (gx0 - 20 * S, cy), name, 42, O.WHITE, "rm")
        if mpa:
            w = (gx1 - gx0) * mpa / 680 * (u if i == n - 1 and st in (1, 3) else 1)
            d.rectangle([gx0, cy - rh * 0.22, gx0 + w, cy + rh * 0.22], fill=col)
            text(d, (gx0 + w + 14 * S, cy), f"1平方mmに約{mpa / 9.8:.0f}kg", 34, O.DIM, "lm", 4)
            if st >= 2:
                lp = (gx0 + w - 130 * S, cy) if LAND else (gx0 + w / 2, cy + rh * 0.36)
                label(d, lp, f"歩ける {hm}m", 36, O.YEL if hm < 60 else O.GREEN)
        else:
            text(d, (gx0 + 20 * S, cy), "?", 60, O.YEL, "lm")
    text(d, ((x0 + x1) / 2, y0 + 40 * S), "つぶれ始める強さ", 40, O.DIM, "ma", 4)


def sc_thigh(img, box, t, k, P):
    x0, y0, x1, y1 = box
    grad(img, box=box)
    d = ImageDraw.Draw(img)
    st = P.get("stage", 1)
    m = min((x1 - x0) / (2 if LAND else 1), (y1 - y0) / (1 if LAND else 2))
    R = m * 0.31
    if LAND:
        c1, c2 = (x0 + (x1 - x0) * 0.27, (y0 + y1) / 2 + 30 * S), (x0 + (x1 - x0) * 0.73, (y0 + y1) / 2 + 30 * S)
    else:
        c1, c2 = ((x0 + x1) / 2, y0 + (y1 - y0) * 0.28), ((x0 + x1) / 2, y0 + (y1 - y0) * 0.74)
    for (cx, cy), frac, name in ((c1, 0.15, "人の太もも"), (c2, 0.92, "巨人の太もも")):
        if name.startswith("巨人") and st == 0:
            text(d, (cx, cy), "?", 160, O.YEL, "mm")
            continue
        f = frac if name.startswith("人") else 0.15 + (frac - 0.15) * _ease(k * 1.6)
        d.ellipse([cx - R, cy - R, cx + R, cy + R], fill=(170, 70, 60), outline=(240, 200, 190), width=int(4 * S))
        r = R * f
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(235, 230, 210))
        label(d, (cx, cy - R - 40 * S), name, 38, O.WHITE)
        label(d, (cx, cy + R + 40 * S), f"骨は太さの {f * 100:.0f}%", 36, O.YEL)
    if st >= 1 and LAND:
        text(d, ((x0 + x1) / 2, y1 - 20 * S), "赤＝筋肉　白＝骨", 30, O.DIM, "md", 3)


def sc_styro(img, box, t, k, P):
    x0, y0, x1, y1 = box
    grad(img, box=box)
    d = ImageDraw.Draw(img)
    st = P.get("stage", 0)
    cx = (x0 + x1) / 2
    if st <= 1:
        u = _ease(k * 1.5)
        w = 2860 if st == 0 else 2860 - (2860 - 80) * u
        bars = [("人の体のまま", 2860, O.RED), ("歩ける重さ", 80, O.GREEN)]
        if st == 1:
            bars.append(("最大級の恐竜", 70, O.DIM))
        gx0, gx1 = x0 + (x1 - x0) * 0.3, x1 - (x1 - x0) * 0.24
        rh = (y1 - y0 - 140 * S) / 3
        for i, (name, v, col) in enumerate(bars):
            cy = y0 + 140 * S + rh * (i + 0.5)
            vv = v if i != 1 else (2860 if st == 0 else w)
            if st == 0 and i == 1:
                vv = 2860 * (1 - u) + 80 * u
            ww = max(6 * S, (gx1 - gx0) * vv / 2860)
            d.rectangle([gx0, cy - rh * 0.22, gx0 + ww, cy + rh * 0.22], fill=col)
            text(d, (gx0 - 20 * S, cy), name, 40, O.WHITE, "rm")
            text(d, (gx0 + ww + 14 * S, cy), f"約{vv:,.0f}トン", 36, O.DIM, "lm", 4)
        label(d, (cx, y0 + 60 * S), "重さを 35分の1 に", 46, O.YEL)
        return
    # 1 リットルあたりの重さ
    items = [("水", 1000, (90, 150, 230)), ("歩ける巨人の体", 28, O.YEL), ("発泡スチロール", 20, (245, 245, 245))]
    gy = y1 - 80 * S
    bw = (x1 - x0) / 5
    for i, (name, g, col) in enumerate(items):
        bx = x0 + bw * (0.7 + i * 1.4)
        hh = (gy - y0 - 200 * S) * max(0.02, g / 1000) * _ease(k * 2 - i * 0.3)
        d.rectangle([bx, gy - hh, bx + bw, gy], fill=col)
        text(d, (bx + bw / 2, gy + 14 * S), name, 34, O.WHITE, "ma", 4)
        text(d, (bx + bw / 2, gy - hh - 14 * S), f"{g}g", 40, O.WHITE, "md", 4)
    label(d, (cx, y0 + 60 * S), "1リットルあたりの重さ", 42, O.YEL)


def sc_galileo(img, box, t, k, P):
    x0, y0, x1, y1 = box
    grad(img, (40, 34, 26), (70, 60, 44), box)
    d = ImageDraw.Draw(img)
    col = (235, 225, 200)

    def bone(cx, cy, L, wdt):
        d.rounded_rectangle([cx - wdt / 2, cy - L / 2, cx + wdt / 2, cy + L / 2], int(wdt / 2), fill=col)
        for sy in (-1, 1):
            for sx in (-1, 1):
                d.ellipse([cx + sx * wdt * 0.55 - wdt * 0.6, cy + sy * L / 2 - wdt * 0.6, cx + sx * wdt * 0.55 + wdt * 0.6, cy + sy * L / 2 + wdt * 0.6], fill=col)
    my = (y0 + y1) / 2 + 20 * S
    Lb = (y1 - y0) * 0.62
    bone(x0 + (x1 - x0) * 0.3, my, Lb / 3, Lb / 3 * 0.16)
    u = _ease(k * 1.5)
    bone(x0 + (x1 - x0) * 0.65, my, Lb * (0.4 + 0.6 * u), Lb / 3 * 0.16 * (1 + 3.2 * u))
    label(d, (x0 + (x1 - x0) * 0.3, my + Lb / 6 + 60 * S), "ふつうの骨", 34, O.WHITE)
    label(d, (x0 + (x1 - x0) * 0.65, y0 + 50 * S), "長さ3倍なら、こんなに太く", 38, O.YEL)
    text(d, ((x0 + x1) / 2, y1 - 10 * S), "ガリレオ『新科学対話』（1638年）の図をもとに描いた", 28, O.DIM, "md", 3)


def _dino(d, x, yb, L, col):
    """足元の真ん中 (x, yb)、全長 L の首の長い恐竜の影絵。"""
    u = L / 37.0
    d.ellipse([x - 7 * u, yb - 13 * u, x + 7 * u, yb - 5 * u], fill=col)
    d.line([(x + 5 * u, yb - 10 * u), (x + 12 * u, yb - 19 * u), (x + 15 * u, yb - 20 * u)], fill=col, width=max(2, int(2.4 * u)))
    d.ellipse([x + 14 * u, yb - 21.5 * u, x + 18 * u, yb - 18.5 * u], fill=col)
    d.line([(x - 6 * u, yb - 9 * u), (x - 13 * u, yb - 7 * u), (x - 19 * u, yb - 4 * u)], fill=col, width=max(2, int(1.6 * u)))
    for dx in (-5, -2.5, 2.5, 5):
        d.rectangle([x + (dx - 0.9) * u, yb - 7 * u, x + (dx + 0.9) * u, yb], fill=col)


def _whale(d, x, yc, L, col):
    u = L / 30.0
    d.ellipse([x - 15 * u, yc - 2.2 * u, x + 13 * u, yc + 2.2 * u], fill=col)
    d.polygon([(x - 14 * u, yc), (x - 18 * u, yc - 3 * u), (x - 18 * u, yc + 3 * u)], fill=col)


ANIMALS = [("human", "人", "65kg"), ("elephant", "アフリカゾウ", "約6トン"), ("dino", "最大級の恐竜", "約70トン（推定）"), ("whale", "シロナガスクジラ", "約150トン（水の中）")]


def sc_animals(img, box, t, k, P):
    """人・ゾウ・恐竜・クジラを同じ縮尺で並べる(長さ m)。hl の動物を明るくする。縦は人と hl の動物だけ。"""
    x0, y0, x1, y1 = box
    grad(img, (40, 70, 110), (120, 150, 180), box)
    d = ImageDraw.Draw(img)
    hl = P.get("hl")
    gy = y1 - (40 if LAND else 60) * S
    d.rectangle([x0, gy, x1, y1], fill=(70, 80, 60))
    on = lambda name: (230, 225, 210) if name == hl else (90, 100, 120)
    if LAND:
        sc = (x1 - x0) / 95
        xs = dict(human=x0 + 60 * S, elephant=x0 + 160 * S, dino=x0 + (x1 - x0) * 0.42, whale=x0 + (x1 - x0) * 0.78)
        person(d, xs["human"], gy, 1.7 * sc, on("human"))
        elephant(d, xs["elephant"], gy, 4.6 * sc, on("elephant"))
        _dino(d, xs["dino"], gy, 37 * sc, on("dino"))
        d.rectangle([x0 + (x1 - x0) * 0.6, gy - 9 * sc, x1, gy], fill=(40, 90, 140))
        _whale(d, xs["whale"], gy - 4.5 * sc, 30 * sc, on("whale"))
    else:
        span = dict(elephant=9, dino=42, whale=36).get(hl, 9)
        sc = (x1 - x0 - 80 * S) / span
        person(d, x0 + 60 * S, gy, 1.7 * sc, (230, 225, 210))
        if hl == "elephant":
            elephant(d, x0 + (x1 - x0) * 0.6, gy, 4.6 * sc, on("elephant"))
        elif hl == "dino":
            _dino(d, x0 + 100 * S + 20 * sc, gy, 37 * sc, on("dino"))
        else:
            d.rectangle([x0, gy - 9 * sc, x1, gy], fill=(40, 90, 140))
            _whale(d, x0 + 60 * S + 19 * sc, gy - 4.5 * sc, 30 * sc, on("whale"))
    for name, jp, w in ANIMALS:
        if name == hl:
            label(d, ((x0 + x1) / 2, y0 + 50 * S), f"{jp}　{w}", 50, O.YEL)
    text(d, (x1 - 20 * S, y1 - 10 * S), "人と同じ縮尺で描いた影絵", 26, O.DIM, "rd", 3)

_PH = {}


def sc_photo(img, box, t, k, P):
    name = P["name"]
    x0, y0, x1, y1 = box
    path = ASSETS / f"{name}_gemini.jpg"
    if not path.exists():
        grad(img, box=box)
        label(ImageDraw.Draw(img), ((x0 + x1) / 2, (y0 + y1) / 2), P.get("note", name), 44, O.WHITE)
        return
    key = (name, W, H)
    if key not in _PH:
        im = Image.open(path).convert("RGB")

        def cover(w, h):
            s = max(w / im.width, h / im.height)
            r = im.resize((int(im.width * s + 1), int(im.height * s + 1)), Image.LANCZOS)
            return r.crop(((r.width - w) // 2, (r.height - h) // 2, (r.width - w) // 2 + w, (r.height - h) // 2 + h))
        if LAND:
            out = cover(W, H)
        else:
            out = cover(W, H).filter(ImageFilter.GaussianBlur(28))
            out = Image.eval(out, lambda v: int(v * 0.55))
            out.paste(cover(int(x1 - x0), int(y1 - y0)), (int(x0), int(y0)))
        out = out.convert("RGBA")
        sh = Image.new("RGBA", out.size, (0, 0, 0, 0))
        ds = ImageDraw.Draw(sh)
        y_sub = 975 if LAND else 1640
        for i in range(260):
            ds.line([(0, y_sub - 200 + i), (W, y_sub - 200 + i)], fill=(5, 10, 25, int(min(1, i / 160) * 170)))
        ds.rectangle([0, y_sub + 60, W, H], fill=(5, 10, 25, 170))
        out.alpha_composite(sh)
        _PH[key] = out
    img.alpha_composite(_PH[key])
    d = ImageDraw.Draw(img)
    text(d, (W - 24 * S, (24 if LAND else 120) * S), "絵はAIで作成", 26, O.DIM, "ra", 3)
    if P.get("note"):
        label(d, ((x0 + x1) / 2, y0 + 60 * S), P["note"], 42, O.WHITE)


KINDS = dict(wall=sc_wall, grow=sc_grow, box3=sc_box3, elephants=sc_elephants, bonesec=sc_bonesec, coin=sc_coin, formula=sc_formula,
             meter=sc_meter, curve=sc_curve, steel=sc_steel, thigh=sc_thigh, styro=sc_styro, galileo=sc_galileo, photo=sc_photo, animals=sc_animals)


def region(P):
    if P.get("panel"):
        return (0, 100, W * 0.5, 880) if LAND else (0, 230, W, 740)
    return (0, 100, W, 880) if LAND else (0, 240, W, 1480)


def paint(sc, t, k):
    img = Image.new("RGBA", (W, H), BG0 + (255,))
    KINDS[sc["kind"]](img, region(sc), t, k, sc)
    return img


def draw(img, dr, t, ctx):
    lines, defs = ctx["lines"], ctx["defs"]
    scs = ctx.setdefault("_scenes", mapscene.scenes(lines, defs))
    cur = ctx["cur"] or lines[0]
    i = next(j for j, l in enumerate(lines) if l["id"] == cur["id"])
    now, prev = scs[i], (scs[i - 1] if i > 0 else None)
    k = ctx["k"]
    u = _ease((t - cur["start"]) / 0.5)
    b = paint(prev, t, 1.0) if prev is not None and prev is not now and u < 1 else None
    O.BOXES.clear()                                  # 重なりの点検は今の場面の札だけ見る
    a = paint(now, t, k)
    if b is not None:
        a = Image.blend(b, a, u)
    z = 1.0 + 0.025 * (0.5 + 0.5 * math.sin(2 * math.pi * t / 14.0))   # ゆっくり寄り引き(画面を止めない)
    if z > 1.0005:
        zw, zh = int(W * z), int(H * z)
        a = a.resize((zw, zh), Image.BILINEAR).crop(((zw - W) // 2, (zh - H) // 2, (zw - W) // 2 + W, (zh - H) // 2 + H))
    img.paste(a, (0, 0))
    P = now.get("panel")
    if P and not ctx.get("cta"):
        if prev is not None and prev.get("panel") is P:
            mapscene.draw_panel(img, P, 1.0, 1.0)
        else:
            t0 = cur["start"] + P.get("at", 0.0) * (cur["end"] - cur["start"])
            mapscene.draw_panel(img, P, _ease((t - t0) / 0.4), _ease((t - t0) / max(0.4, P.get("grow", 1.2))))


def sfx_for(lines_def, L):
    return mapscene.sfx(lines_def, L)

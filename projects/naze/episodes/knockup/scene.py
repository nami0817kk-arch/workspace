"""ワンピースのノックアップストリーム(計算の回)の画面。行の scene=dict(kind=…) を描く(無い行は前の行を引き継ぐ)。
場面が変わると 0.5 秒で溶け合わせる。作品の絵は使わない。計算の図は全部コードで描く。
船の想像図だけ assets/ship_gemini.jpg(AI で作った絵)があれば使い、無ければ影絵にする。
数字の出どころは research.md。
kind: column / ruler / bars / speed / gdial / decel / plume / push / widen / fountain / drops / dropfly / airarrow / rain /
      persong / ship / hull / coin / struct / skytree / weightless / conds / formula
"""
from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

from naze import mapscene, overlay as O
from naze.config import H, W

LAND = W > H
S = min(W, H) / 1080
ASSETS = Path(__file__).resolve().parent / "assets"
COLS = dict(dim=O.DIM, white=O.WHITE, yel=O.YEL, red=O.RED, green=O.GREEN)
BG0, BG1 = (10, 18, 40), (16, 30, 62)
WATER = (90, 170, 235)
TAGGED = [False]   # 縦で「実験N」の札が左上に出ている間は、上の見出しを下げる


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


def head(d, box, s, col=O.YEL, size=44):
    x0, y0, x1, y1 = box
    label(d, ((x0 + x1) / 2, y0 + (130 if (TAGGED[0] and not LAND) else 50) * S), s, size, col)


def person(d, x, yb, hp, col=(196, 120, 96)):
    u = hp / 8.0
    hw = u * 0.42
    d.ellipse([x - hw, yb - hp, x + hw, yb - hp + u], fill=col)
    d.rounded_rectangle([x - u * 0.95, yb - hp + u * 1.05, x + u * 0.95, yb - u * 3.9], radius=max(1, int(u * 0.35)), fill=col)
    lw = max(2, int(u * 0.62))
    d.line([(x - u * 0.45, yb - u * 4.0), (x - u * 0.55, yb)], fill=col, width=lw)
    d.line([(x + u * 0.45, yb - u * 4.0), (x + u * 0.55, yb)], fill=col, width=lw)
    aw = max(2, int(u * 0.42))
    d.line([(x - u * 1.0, yb - hp + u * 1.3), (x - u * 1.35, yb - u * 4.1)], fill=col, width=aw)
    d.line([(x + u * 1.0, yb - hp + u * 1.3), (x + u * 1.35, yb - u * 4.1)], fill=col, width=aw)


def arrow(d, x0, y0, x1, y1, w, col):
    """(x0,y0)→(x1,y1) の太い矢印。"""
    ang = math.atan2(y1 - y0, x1 - x0)
    L = math.hypot(x1 - x0, y1 - y0)
    hl = min(L * 0.5, w * 2.2)
    bx, by = x1 - math.cos(ang) * hl, y1 - math.sin(ang) * hl
    d.line([(x0, y0), (bx, by)], fill=col, width=int(w))
    nx, ny = -math.sin(ang), math.cos(ang)
    d.polygon([(x1, y1), (bx + nx * w * 1.1, by + ny * w * 1.1), (bx - nx * w * 1.1, by - ny * w * 1.1)], fill=col)


def mix(c, bg, a):
    return tuple(int(c[i] * a + bg[i] * (1 - a)) for i in range(3))


def ship_sil(d, cx, yb, w, col=(70, 50, 40), sail=(235, 230, 215)):
    """帆船の影絵。足元(水面)の真ん中 (cx, yb)、船体の長さ w。"""
    u = w / 100.0
    d.polygon([(cx - 50 * u, yb - 14 * u), (cx + 50 * u, yb - 14 * u), (cx + 38 * u, yb), (cx - 38 * u, yb)], fill=col)
    d.polygon([(cx + 50 * u, yb - 14 * u), (cx + 62 * u, yb - 20 * u), (cx + 44 * u, yb - 8 * u)], fill=col)
    for mx, mh in ((-18, 62), (6, 72), (28, 52)):
        d.line([(cx + mx * u, yb - 14 * u), (cx + mx * u, yb - (14 + mh) * u)], fill=col, width=max(2, int(1.6 * u)))
        d.polygon([(cx + (mx - 9) * u, yb - 20 * u), (cx + (mx + 9) * u, yb - 20 * u), (cx + (mx + 7) * u, yb - (10 + mh) * u), (cx + (mx - 7) * u, yb - (10 + mh) * u)], fill=sail)


# ---- 棒グラフ -----------------------------------------------------------------------------

def bars(d, box, rows, vmax, k=1.0, grow_from=0, marks=(), names_above=None, y_top=None):
    """rows = [(名前, 値 or 範囲の下, 範囲の上 or None, 数字の札, 色)]。値は vmax に対する横の長さ。"""
    x0, y0, x1, y1 = box
    na = (not LAND) if names_above is None else names_above
    ya = y_top if y_top is not None else y0 + (210 if not LAND else 130) * S
    n = len(rows)
    rh = min((200 if not na else 230) * S, (y1 - 50 * S - ya) / n)
    if y_top is None:   # 行が少ないときは、空いた所の真ん中に寄せる
        ya = max(ya, ya + ((y1 - 50 * S - ya) - rh * n) * 0.4)
    gx0 = x0 + 50 * S if na else x0 + (x1 - x0) * 0.27
    gx1 = x1 - 50 * S
    px = lambda v: gx0 + (gx1 - gx0) * min(v, vmax) / vmax
    bh = rh * (0.3 if na else 0.44)
    f = O.font(int(36 * S))
    for i, (name, lo, hi, txt, col) in enumerate(rows):
        a = 1.0 if i < grow_from else _ease(k * 1.8 - 0.35 * (i - grow_from))
        cy = ya + rh * (i + 0.5) + (12 * S if na else 0)
        nsz = 36 if na else 38
        while O.font(int(nsz * S)).getlength(name) > ((x1 - x0 - 100 * S) if na else (gx0 - x0 - 40 * S)) and nsz > 22:
            nsz -= 2
        if na:
            text(d, (gx0, cy - bh / 2 - 12 * S), name, nsz, O.WHITE, "ld", 4)
        else:
            text(d, (gx0 - 20 * S, cy), name, nsz, O.WHITE, "rm", 4)
        if a <= 0:
            continue
        end = px(hi if hi is not None else lo)
        e = gx0 + max(8 * S, (end - gx0)) * a
        if hi is not None:
            m = gx0 + (px(lo) - gx0) * a
            d.rectangle([gx0, cy - bh / 2, e, cy + bh / 2], fill=mix(col, BG1, 0.5))
            d.rectangle([gx0, cy - bh / 2, m, cy + bh / 2], fill=col)
        else:
            d.rectangle([gx0, cy - bh / 2, e, cy + bh / 2], fill=col)
        tw = f.getlength(txt)
        if a > 0.6:
            if e + 14 * S + tw > x1 - 20 * S:
                text(d, (e - 14 * S, cy), txt, 36, O.WHITE, "rm", 5)
            else:
                text(d, (e + 14 * S, cy), txt, 36, O.WHITE, "lm", 4)
    for v, s, col in marks:
        xm = px(v)
        d.line([(xm, ya - 6 * S), (xm, ya + rh * n)], fill=col, width=max(2, int(4 * S)))
        text(d, (min(xm, x1 - 20 * S), ya - 14 * S), s, 32, col, "md" if xm < x1 - 200 * S else "rd", 4)


# ---- ダイヤル -----------------------------------------------------------------------------

def dial(d, cx, cy, R, vmax, val, ticks, zones=(), shake=0.0):
    """半円のメーター。val が vmax を超えると針は端で振り切れる。zones = [(a, b, 色)]。"""
    w = int(34 * S)
    d.arc([cx - R, cy - R, cx + R, cy + R], 180, 360, fill=(40, 52, 78), width=w)
    for a, b, c in zones:
        d.arc([cx - R, cy - R, cx + R, cy + R], 180 + 180 * a / vmax, 180 + 180 * b / vmax, fill=c, width=w)
    for v, s in ticks:
        th = math.radians(180 + 180 * v / vmax)
        d.line([(cx + math.cos(th) * (R - w * 0.6), cy + math.sin(th) * (R - w * 0.6)), (cx + math.cos(th) * (R + w * 0.7), cy + math.sin(th) * (R + w * 0.7))], fill=O.WHITE, width=max(2, int(4 * S)))
        text(d, (cx + math.cos(th) * (R + w * 1.5), cy + math.sin(th) * (R + w * 1.5)), s, 30, O.DIM, "mm", 3)
    th = math.radians(180 + 180 * min(val, vmax * 1.02) / vmax) + math.radians(shake)
    d.line([(cx, cy), (cx + math.cos(th) * (R - w * 0.2), cy + math.sin(th) * (R - w * 0.2))], fill=O.WHITE, width=int(10 * S))
    d.ellipse([cx - 18 * S, cy - 18 * S, cx + 18 * S, cy + 18 * S], fill=O.WHITE)


# ---- 場面 -------------------------------------------------------------------------------

def sc_column(img, box, t, k, P):
    x0, y0, x1, y1 = box
    st = P.get("stage", 0)
    grad(img, (110, 165, 225), (225, 238, 250), box)
    d = ImageDraw.Draw(img)
    sea = y1 - 80 * S
    d.rectangle([x0, sea, x1, y1], fill=(25, 80, 140))
    for i in range(14):
        wx = x0 + (x1 - x0) * i / 13 + 14 * S * math.sin(t * 1.5 + i)
        d.arc([wx - 50 * S, sea - 10 * S, wx + 50 * S, sea + 24 * S], 200, 340, fill=(140, 200, 240), width=int(3 * S))
    cloud_y = y0 + (y1 - y0) * 0.17
    for i in range(9):
        cx = x0 + (x1 - x0) * (0.05 + 0.11 * i)
        for j, (dx, dy, r) in enumerate(((0, 0, 70), (60, -25, 60), (-60, -15, 55), (30, 20, 65))):
            d.ellipse([cx + dx * S - r * S, cloud_y + dy * S - r * S * 0.6 + 30 * S, cx + dx * S + r * S, cloud_y + dy * S + r * S * 0.6 + 30 * S], fill=(250, 250, 255))
    cx = (x0 + x1) / 2
    f = 1.0 if st >= 1 else _ease(k * 1.4)
    top = sea - (sea - cloud_y - 30 * S) * f
    wd = 90 * S
    d.rectangle([cx - wd / 2, top, cx + wd / 2, sea], fill=WATER)
    d.rectangle([cx - wd / 2, top, cx - wd / 2 + 8 * S, sea], fill=(190, 225, 250))
    off = (t * 260 * S) % (60 * S)
    yy = sea - off
    while yy > top + 8 * S:
        d.line([(cx - wd * 0.3, yy), (cx - wd * 0.3, yy - 26 * S)], fill=(220, 240, 255), width=int(4 * S))
        d.line([(cx + wd * 0.25, yy - 30 * S), (cx + wd * 0.25, yy - 54 * S)], fill=(220, 240, 255), width=int(4 * S))
        yy -= 60 * S
    d.ellipse([cx - wd * 0.8, top - 26 * S, cx + wd * 0.8, top + 26 * S], fill=(200, 230, 252))
    ship_sil(d, cx, sea + 18 * S, 200 * S) if st < 2 else None
    if st == 2:
        ship_sil(d, cx, cloud_y + 50 * S, 240 * S)
        head(d, box, "船は 雲の海（白海 7000m）に到着", O.YEL)
    elif st == 1:
        head(d, box, "先頭は 約39秒後に 7000m へ", O.YEL)
    elif st == 3:
        head(d, box, "音より速く昇る水  秒速370m以上", O.YEL)
    else:
        head(d, box, "海から雲へ、水の柱", O.YEL)
    text(d, (x0 + 30 * S, cloud_y + 60 * S), "7000m", 38, O.NAVY, "lm", 0)
    text(d, (x0 + 30 * S, sea - 30 * S), "海面", 34, O.WHITE, "lm", 4)


def sc_ruler(img, box, t, k, P):
    x0, y0, x1, y1 = box
    st = P.get("stage", 0)
    grad(img, (22, 50, 100), (120, 170, 220), box)
    d = ImageDraw.Draw(img)
    gy = y1 - 60 * S
    top = y0 + 110 * S
    sc = (gy - top) / 10000.0
    rx = x0 + (x1 - x0) * (0.2 if LAND else 0.22)
    d.line([(rx, gy), (rx, top)], fill=O.WHITE, width=int(5 * S))
    for hm in range(0, 10001, 1000):
        yy = gy - hm * sc
        d.line([(rx - 12 * S, yy), (rx, yy)], fill=O.DIM, width=int(3 * S))
        text(d, (rx - 20 * S, yy), f"{hm}", 26, O.DIM, "rm", 3)
    text(d, (rx - 20 * S, top - 40 * S), "高さ（m）", 28, O.DIM, "rm", 3)
    d.rectangle([x0, gy, x1, y1], fill=(25, 80, 140))

    def layer(h, name, col):
        yy = gy - h * sc
        for i in range(6):
            cx = rx + 170 * S + (x1 - rx - 260 * S) * (i / 5)
            d.ellipse([cx - 90 * S, yy - 22 * S, cx + 90 * S, yy + 22 * S], fill=(250, 250, 255))
        d.line([(rx, yy), (x1 - 20 * S, yy)], fill=col, width=int(4 * S))
        label(d, ((rx + x1) / 2 + (40 * S if LAND else 0), yy - 50 * S), name, 38, col)
    a = _ease(k * 2)
    layer(7000, "白海　高さ7000m（作中の設定）", O.YEL)
    if st >= 1:
        if a > 0.3:
            layer(10000, "白々海　1万m（作中の設定）", O.WHITE)
        fx = rx + (x1 - rx) * 0.3
        fy = gy - 3776 * sc
        d.polygon([(fx - 260 * S, gy), (fx, fy), (fx + 260 * S, gy)], fill=(95, 105, 120))
        d.polygon([(fx - 60 * S, gy - 3776 * sc * 0.82), (fx, fy), (fx + 60 * S, gy - 3776 * sc * 0.82)], fill=(240, 245, 250))
        label(d, (fx, fy - 40 * S) if not LAND else (fx + 190 * S, fy + 10 * S), "富士山 3776m（7000mは約2倍）", 34, O.WHITE)
    text(d, (rx + 20 * S, gy - 24 * S), "海面", 32, O.WHITE, "lm", 4)


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
        sz = size
        f = O.font(int(sz * S))
        while f.getlength(s) > (x1 - x0) - 80 * S and sz > 30:
            sz -= 4
            f = O.font(int(sz * S))
        text(d, (cx, y0 + gap * (i + 1) + 6 * S * math.sin(t * 1.3 + i)), s, sz, c, "mm", 6)


def sc_bars(img, box, t, k, P):
    grad(img, box=box)
    d = ImageDraw.Draw(img)
    bars(d, box, P["rows"], P["vmax"], k, P.get("grow_from", 0), P.get("marks", ()))
    if P.get("head"):
        head(d, box, P["head"], P.get("hcol", O.YEL))
    if P.get("foot"):
        x0, y0, x1, y1 = box
        text(d, ((x0 + x1) / 2, y1 - 14 * S), P["foot"], 28, O.DIM, "md", 3)


def sc_speed(img, box, t, k, P):
    """速さのメーター(秒速0〜400m)。bars=True なら新幹線・噴水・音と並べる。"""
    x0, y0, x1, y1 = box
    grad(img, box=box)
    d = ImageDraw.Draw(img)
    both = P.get("bars", False)
    v = 370.5 * _ease(k * 1.5)
    if both:
        if LAND:
            dx0, dx1, dy0, dy1 = x0, x0 + (x1 - x0) * 0.48, y0, y1
            bbox = (x0 + (x1 - x0) * 0.5, y0, x1, y1)
        else:
            dx0, dx1, dy0, dy1 = x0, x1, y0 + 120 * S, y0 + (y1 - y0) * 0.42
            bbox = (x0, y0 + (y1 - y0) * 0.44, x1, y1)
    else:
        dx0, dx1, dy0, dy1 = x0, x1, y0, y1
    cx = (dx0 + dx1) / 2
    R = min((dx1 - dx0) * 0.34, (dy1 - dy0) * (0.5 if not both else 0.62))
    cy = (dy0 + dy1) / 2 + R * 0.45 + (30 * S if not both else 0)
    dial(d, cx, cy, R, 400, v, [(0, "0"), (100, "100"), (200, "200"), (300, "300"), (400, "400")], zones=[(340, 400, O.RED)])
    text(d, (cx, cy + 60 * S), f"秒速 {v:.0f}m", 64, O.YEL, "mm", 6)
    text(d, (cx, cy + 135 * S), f"時速 約{v * 3.6 / 100:.0f}00km" if v > 50 else "", 40, O.WHITE, "mm", 5)
    text(d, (cx, cy - R - 100 * S), "7000m でちょうど止まる出だしの速さ", 34, O.DIM, "mm", 4) if not both else None
    if not both:
        label(d, (cx + R * 0.72, cy - R * 0.35 - 60 * S), "赤＝音より速い（秒速340m〜）", 30, O.RED)
    if both:
        rows = [("新幹線", 88.9, None, "秒速89m（時速320km）", (120, 150, 190)),
                ("世界一の噴水", 104.2, None, "秒速104m（時速375km）", (90, 170, 235)),
                ("音", 340.3, None, "秒速340m", O.DIM),
                ("要る速さ", 370.5, None, "秒速370m", O.RED)]
        bars(d, bbox, rows, 560, k, 0, (), True, y_top=bbox[1] + (20 if LAND else 10) * S + (60 * S if LAND else 0))
        label(d, (cx, y0 + 55 * S), "新幹線の約4倍　世界一の噴水の約3.5倍", 36, O.YEL)


def sc_decel(img, box, t, k, P):
    x0, y0, x1, y1 = box
    grad(img, box=box)
    d = ImageDraw.Draw(img)
    gx0, gx1 = x0 + (x1 - x0) * 0.15, x1 - (x1 - x0) * 0.07
    gy0, gy1 = y0 + 150 * S, y1 - 90 * S
    px = lambda s: gx0 + (gx1 - gx0) * s / 40.0
    py = lambda v: gy1 - (gy1 - gy0) * v / 400.0
    d.line([(gx0, gy1), (gx1, gy1)], fill=O.DIM, width=int(3 * S))
    d.line([(gx0, gy0), (gx0, gy1)], fill=O.DIM, width=int(3 * S))
    for s in (0, 10, 20, 30, 40):
        text(d, (px(s), gy1 + 12 * S), f"{s}秒", 28, O.DIM, "ma", 3)
    for v in (0, 100, 200, 300, 400):
        text(d, (gx0 - 14 * S, py(v)), f"{v}", 28, O.DIM, "rm", 3)
    text(d, (gx0, gy0 - 40 * S), "速さ（秒速m）", 30, O.DIM, "la", 3)
    u = _ease(k * 1.3)
    n = 60
    pts = [(px(37.8 * u * i / n), py(370.5 * (1 - u * i / n))) for i in range(n + 1)]
    d.line(pts, fill=O.YEL, width=int(8 * S), joint="curve")
    d.ellipse([pts[-1][0] - 12 * S, pts[-1][1] - 12 * S, pts[-1][0] + 12 * S, pts[-1][1] + 12 * S], fill=O.WHITE)
    label(d, (gx0 + (gx1 - gx0) * 0.3, py(370) + 10 * S), "出だし 秒速370m", 38, O.YEL)
    if u > 0.9:
        label(d, (px(37.8) - 110 * S, py(0) - 60 * S), "約38秒で止まる（頂上）", 36, O.WHITE)
    head(d, box, "1秒ごとに 秒速9.8mずつ遅くなる", O.WHITE, 40)


def _plume_body(d, bx, by, hgt, wd, t, col=(120, 118, 125)):
    n = 26
    for i in range(n):
        u = i / (n - 1)
        r = (wd * (0.25 + 0.9 * u ** 0.8)) * (0.9 + 0.1 * math.sin(t * 2 + i * 1.7))
        yy = by - hgt * u
        xx = bx + wd * 0.25 * math.sin(i * 1.3 + t * 0.8) * u
        c = mix(col, (230, 230, 235), u * 0.55)
        d.ellipse([xx - r, yy - r * 0.8, xx + r, yy + r * 0.8], fill=c)


def sc_plume(img, box, t, k, P):
    x0, y0, x1, y1 = box
    st = P.get("stage", 0)
    grad(img, (70, 90, 130), (190, 200, 215), box)
    d = ImageDraw.Draw(img)
    gy = y1 - 40 * S
    cx = (x0 + x1) / 2 - (x1 - x0) * (0.18 if LAND else 0)
    if st == 2:
        cx = x0 + (x1 - x0) * 0.35
    h_full = gy - y0 - 150 * S
    if st == 2:
        _plume_body(d, cx, gy - 60 * S, h_full, 120 * S, t)
        top = gy - 60 * S - h_full
    else:
        f = 0.55 if st == 1 else 0.15 + 0.5 * _ease(k * 1.4)
        _plume_body(d, cx, gy - 70 * S, h_full * f * 0.9, 100 * S, t)
        top = gy - 70 * S - h_full * f * 0.9
    d.polygon([(cx - 330 * S, gy), (cx - 40 * S, gy - 90 * S), (cx + 40 * S, gy - 90 * S), (cx + 330 * S, gy)], fill=(60, 50, 45))
    d.rectangle([x0, gy, x1, y1], fill=(60, 50, 45))
    d.ellipse([cx - 44 * S, gy - 110 * S, cx + 44 * S, gy - 70 * S], fill=(255, 120, 40))
    if st == 0:
        head(d, box, "火山の噴火で打ち上げる", O.YEL)
    elif st == 1:
        head(d, box, "1980年 セントヘレンズ山", O.WHITE)
        arrow(d, cx + 130 * S, gy - 140 * S, cx + 130 * S, gy - 340 * S, 14 * S, O.YEL)
        label(d, (cx + 150 * S + (230 * S if LAND else 20 * S), gy - 250 * S), "噴き出す速さ 秒速200〜330m", 40, O.YEL)
    else:
        head(d, box, "ピナトゥボ山 1991年　噴煙は40km近く", O.WHITE)
        bk = gy - 60 * S - h_full * 0.1
        d.line([(cx + 220 * S, gy - 60 * S), (cx + 220 * S, bk)], fill=O.YEL, width=int(14 * S))
        label(d, (cx + 260 * S + (130 * S if LAND else 20 * S), (gy - 60 * S + bk) / 2 + (70 * S if not LAND else 0)), "勢いで昇る部分", 38, O.YEL)
        # 熱気球
        bx, by = x0 + (x1 - x0) * 0.72, y0 + (y1 - y0) * 0.38
        d.ellipse([bx - 70 * S, by - 100 * S, bx + 70 * S, by + 50 * S], fill=(230, 90, 70))
        d.line([(bx - 40 * S, by + 40 * S), (bx - 18 * S, by + 100 * S)], fill=O.WHITE, width=int(3 * S))
        d.line([(bx + 40 * S, by + 40 * S), (bx + 18 * S, by + 100 * S)], fill=O.WHITE, width=int(3 * S))
        d.rectangle([bx - 22 * S, by + 100 * S, bx + 22 * S, by + 128 * S], fill=(120, 80, 50))
        label(d, (bx, by + 190 * S), "熱い煙は 熱気球のように浮いて昇る", 34, O.WHITE)


def sc_push(img, box, t, k, P):
    x0, y0, x1, y1 = box
    st = P.get("stage", 0)
    grad(img, (20, 36, 70), (40, 70, 120), box)
    d = ImageDraw.Draw(img)
    cx = (x0 + x1) / 2
    hy = y0 + (y1 - y0) * (0.45 - 0.04 * math.sin(t * 2))
    wd = 90 * S
    d.rectangle([cx - wd / 2, hy, cx + wd / 2, y1], fill=WATER)
    d.pieslice([cx - wd / 2, hy - wd / 2, cx + wd / 2, hy + wd / 2], 180, 360, fill=WATER)
    # 空気の粒: 先頭の前では左右に押しのけられる
    import random
    rnd = random.Random(5)
    for i in range(70):
        ax = x0 + 40 * S + (x1 - x0 - 80 * S) * rnd.random()
        ay = y0 + 120 * S + (hy - y0 - 60 * S) * rnd.random()
        dx = ax - cx
        near = max(0.0, 1 - abs(ay - hy + 40 * S) / (200 * S)) * max(0.0, 1 - abs(dx) / (260 * S))
        ax += math.copysign(1, dx or 1) * 90 * S * near
        d.ellipse([ax - 6 * S, ay - 6 * S, ax + 6 * S, ay + 6 * S], fill=(200, 210, 225))
    for sgn in (-1, 1):
        arrow(d, cx + sgn * 70 * S, hy - 70 * S, cx + sgn * 190 * S, hy - 20 * S, 12 * S, O.YEL)
    label(d, (cx + 330 * S, hy - 110 * S) if LAND else (cx, hy - 200 * S), "空気を押しのけて進む", 36, O.WHITE)
    label(d, (cx + 300 * S, hy + 180 * S) if LAND else (cx + 140 * S, hy + 200 * S), "後ろの水は 先頭が開けた道を通る", 34, O.WHITE)
    text(d, (cx - 300 * S if LAND else cx - 200 * S, hy + 20 * S), "空気", 30, O.DIM, "mm", 3)
    if st >= 1:
        head(d, box, "水は 空気の約800倍 重い", O.YEL)
        label(d, ((x0 + x1) / 2, y1 - 70 * S), "先頭の速さは 後ろの水の約97%", 38, O.GREEN)
    else:
        head(d, box, "先頭が空気を押しのける", O.YEL)


def sc_widen(img, box, t, k, P):
    """柱の太さの変わり方。高さ h で 太さ = 根元の (1 - h/7000)^(-1/4) 倍。"""
    x0, y0, x1, y1 = box
    st = P.get("stage", 0)
    grad(img, (110, 165, 225), (225, 238, 250), box)
    d = ImageDraw.Draw(img)
    gy = y1 - 60 * S
    top = y0 + 140 * S
    cx = x0 + (x1 - x0) * (0.4 if LAND else 0.2)
    sc = (gy - top) / 7000.0
    w0 = 40 * S
    hs = [i * 7000 / 400 for i in range(0, 400)] + [6990, 6998]
    ws = [w0 * (1 - h / 7000.0) ** -0.25 for h in hs]
    grow = 1.0 if st >= 1 else _ease(k * 1.5)
    n = int(len(hs) * grow)
    n = max(3, n)
    left = [(cx - ws[i] / 2, gy - hs[i] * sc) for i in range(n)]
    right = [(cx + ws[i] / 2, gy - hs[i] * sc) for i in range(n)]
    d.polygon(left + right[::-1], fill=WATER)
    d.rectangle([x0, gy, x1, y1], fill=(25, 80, 140))
    cy = top - 6 * S
    for i in range(8):
        ex = cx + (-170 + i * 50) * S
        d.ellipse([ex - 60 * S, cy - 20 * S, ex + 60 * S, cy + 30 * S], fill=(250, 250, 255))
    d.line([(x0 + 20 * S, top), (x1 - 20 * S, top)], fill=O.YEL, width=int(3 * S))
    text(d, (x0 + 24 * S, top - 14 * S), "7000m", 30, O.NAVY, "ld", 0)
    if st >= 2:  # 頂上で傘のように開く
        for sgn in (-1, 1):
            pts = [(cx + sgn * j * 12 * S, top + 40 * S * math.sin(j / 12 * math.pi / 2) ** 0.5 * 0 + (j / 12) ** 2 * 120 * S) for j in range(0, 13)]
            d.line([(cx, top)] + pts, fill=WATER, width=int(12 * S))
    mk = [(6000, "×1.6"), (6900, "×約3")]
    if st >= 1:
        for h, s in mk:
            wi = w0 * (1 - h / 7000.0) ** -0.25
            yy = gy - h * sc
            d.line([(cx + wi / 2 + 6 * S, yy), (cx + (330 if LAND else 150) * S, yy)], fill=O.YEL, width=int(3 * S))
            lab = f"高さ{h}m　太さ 根元の{s[1:]}倍".replace("倍倍", "倍")
            if LAND:
                label(d, (cx + 560 * S, yy + (40 if h == 6000 else 0) * S), lab, 34, O.YEL)
            else:
                label(d, (cx + 170 * S, yy + (10 if h == 6000 else -30) * S), lab, 34, O.YEL, "lm")
        text(d, (cx, gy + 30 * S), "根元", 32, O.WHITE, "ma", 4)
    if st == 3:
        label(d, (cx - (330 * S if LAND else 0) - (0 if LAND else 0), top + (250 if LAND else 330) * S), "秒速400mで噴き出せば 7000mで秒速150m", 36, O.GREEN, "mm")
        arrow(d, cx, top + 70 * S, cx, top - 70 * S, 16 * S, O.GREEN)
    head(d, box, {0: "柱は上ほど 遅くなって 太る", 1: "上ほど 太くなる", 2: "頂上で 傘のように開く", 3: "雲に飛び込む勢いは残る"}[st], O.YEL, 42)


def sc_fountain(img, box, t, k, P):
    x0, y0, x1, y1 = box
    grad(img, (110, 165, 225), (200, 225, 245), box)
    d = ImageDraw.Draw(img)
    gy = y1 - (280 if LAND else 170) * S
    cx = (x0 + x1) / 2
    d.ellipse([cx - 360 * S, gy - 40 * S, cx + 360 * S, gy + 70 * S], fill=(120, 130, 140))
    d.ellipse([cx - 320 * S, gy - 26 * S, cx + 320 * S, gy + 50 * S], fill=(60, 130, 200))
    top = gy - (y1 - y0) * (0.46 if LAND else 0.58)
    d.rectangle([cx - 10 * S, top, cx + 10 * S, gy], fill=(230, 245, 255))
    for j in range(-6, 7):
        pts = []
        for i in range(0, 21):
            u = i / 20
            wob = 3 * S * math.sin(t * 5 + j + i)
            pts.append((cx + j * 38 * S * u + wob, top + 330 * S * u * u - 40 * S * u * (1 - abs(j) / 7)))
        d.line(pts, fill=(235, 248, 255), width=int(5 * S))
    label(d, (cx, y0 + 60 * S), "てっぺんで 水が止まって 広がる", 40, O.WHITE, "mm")
    text(d, ((x0 + x1) / 2, y1 - (130 if LAND else 30) * S), "噴き出す速さが 高さを決める", 34, O.NAVY, "md", 0)


def sc_drops(img, box, t, k, P):
    x0, y0, x1, y1 = box
    st = P.get("stage", 0)
    grad(img, box=box)
    d = ImageDraw.Draw(img)
    if st == 0:
        rs = [14, 34, 75, 150]
        names = [("10cm", "ペットボトル1本分"), ("1m", ""), ("10m", ""), ("100m", "")]
        gap = 100
        total = sum(2 * r for r in rs) + gap * 3
        sf = min(1.6, (x1 - x0) * 0.86 / total)
        gx = x0 + ((x1 - x0) - total * sf) / 2
        cy = (y0 + y1) / 2 + 20 * S
        for i, (r, (a, b)) in enumerate(zip(rs, names)):
            R = r * sf * S
            cxx = gx + R
            gx += 2 * R + gap * sf * S
            u = _ease(k * 3 - i * 0.5)
            d.ellipse([cxx - R * u, cy - R * u, cxx + R * u, cy + R * u], fill=WATER, outline=(210, 235, 252), width=int(3 * S))
            if u > 0.5:
                yy = cy + 150 * sf * S + 40 * S + (i % 2) * 66 * S
                text(d, (cxx, yy), f"直径{a}", 36, O.WHITE, "mm", 4)
                if b:
                    text(d, (cxx, yy + 44 * S), b, 32, O.DIM, "mm", 4)
        head(d, box, "水の玉の大きさ（直径を10倍ずつ）", O.YEL, 40)
    else:
        cy = (y0 + y1) / 2 + 20 * S
        r1, r2 = 38 * S, 150 * S
        c1, c2 = x0 + (x1 - x0) * 0.25, x0 + (x1 - x0) * 0.68
        d.ellipse([c1 - r1, cy - r1, c1 + r1, cy + r1], fill=WATER)
        d.ellipse([c2 - r2, cy - r2, c2 + r2, cy + r2], fill=WATER)
        text(d, (c1, cy + r1 + 40 * S), "直径10m", 34, O.WHITE, "mm", 4)
        text(d, (c2, cy + r2 + 40 * S), "直径100m", 34, O.WHITE, "mm", 4)
        label(d, ((x0 + x1) / 2, y1 - 120 * S), "直径10倍で 空気を受ける面は100倍　重さは1000倍", 34 if LAND else 28, O.YEL)
        head(d, box, "大きい玉ほど 空気に強い", O.WHITE, 42)


def sc_dropfly(img, box, t, k, P):
    x0, y0, x1, y1 = box
    grad(img, (40, 70, 130), (140, 190, 235), box)
    d = ImageDraw.Draw(img)
    gy = y1 - 70 * S
    top = y0 + 150 * S
    cx = x0 + (x1 - x0) * 0.35
    d.rectangle([x0, gy, x1, y1], fill=(25, 80, 140))
    d.line([(x0 + 30 * S, top), (x1 - 30 * S, top)], fill=O.YEL, width=int(4 * S))
    text(d, (x0 + 40 * S, top - 12 * S), "7000m", 36, O.YEL, "ld", 4)
    stop = gy - (gy - top) * 0.58
    f = _ease(k * 1.2)
    yy = gy - (gy - stop) * f
    d.line([(cx, gy), (cx, yy)], fill=(190, 225, 250), width=int(4 * S))
    r = 22 * S * (1 - 0.25 * f)
    d.ellipse([cx - r, yy - r, cx + r, yy + r], fill=WATER, outline=O.WHITE, width=int(3 * S))
    if f > 0.9:
        for a in range(0, 360, 45):
            d.line([(cx + math.cos(math.radians(a)) * 40 * S, yy + math.sin(math.radians(a)) * 40 * S), (cx + math.cos(math.radians(a)) * 66 * S, yy + math.sin(math.radians(a)) * 66 * S)], fill=O.RED, width=int(5 * S))
        label(d, (cx + 220 * S, yy), "途中で止まる", 44, O.RED)
        label(d, (cx + 220 * S, top + 90 * S), "7000mには届かない", 36, O.WHITE)
    head(d, box, "ペットボトル1本分の玉を 秒速20kmで打つ", O.YEL, 38 if LAND else 34)


def sc_airarrow(img, box, t, k, P):
    x0, y0, x1, y1 = box
    grad(img, box=box)
    d = ImageDraw.Draw(img)
    cy = (y0 + y1) / 2 + 40 * S
    for j, (cxx, mult, lab) in enumerate(((x0 + (x1 - x0) * 0.27, 1, "速さ ×1"), (x0 + (x1 - x0) * 0.73, 4, "速さ ×2"))):
        d.ellipse([cxx - 40 * S, cy - 40 * S, cxx + 40 * S, cy + 40 * S], fill=WATER)
        arrow(d, cxx, cy + 180 * S, cxx, cy + 60 * S, 16 * S, O.DIM)  # 動く向き(上)の反対ではなく、玉が進む向き
        text(d, (cxx + 30 * S, cy + 130 * S), "進む向き", 26, O.DIM, "lm", 3) if False else None
        a = 1.0 if j == 0 else _ease(k * 2 - 0.4)
        w = (14 + 22 * (mult - 1) / 3 * a) * S if j == 1 else 14 * S
        arrow(d, cxx, cy - 220 * S, cxx, cy - 70 * S, w, O.RED)
        label(d, (cxx, cy - 270 * S), "空気の押し返し ×1" if mult == 1 else ("空気の押し返し ×4" if a > 0.8 else "空気の押し返し ×…"), 36, O.RED)
        label(d, (cxx, cy + 230 * S), lab, 40, O.YEL)
    head(d, box, "空気は 速いものほど 強く押し返す", O.WHITE, 40)


def sc_rain(img, box, t, k, P):
    x0, y0, x1, y1 = box
    grad(img, (70, 85, 110), (130, 150, 175), box)
    d = ImageDraw.Draw(img)
    for i in range(6):
        cx = x0 + (x1 - x0) * (0.1 + 0.16 * i)
        d.ellipse([cx - 120 * S, y0 + 120 * S, cx + 120 * S, y0 + 230 * S], fill=(210, 215, 225))
    span = y1 - y0 - 450 * S
    for i in range(10):
        bx = x0 + 80 * S + (x1 - x0 - 160 * S) * (i / 9)
        big = i % 2
        v = 330 if big else 120
        yy = y0 + 260 * S + ((t * v * S + i * 77 * S) % span)
        r = (13 if big else 5) * S
        d.ellipse([bx - r, yy - r, bx + r, yy + r * 1.5], fill=(190, 225, 255))
    label(d, (x0 + (x1 - x0) * 0.3, y1 - 90 * S), "小さな粒は ゆっくり", 36, O.WHITE)
    label(d, (x0 + (x1 - x0) * 0.72, y1 - 90 * S), "大きな粒は 速く", 36, O.WHITE)
    head(d, box, "雨粒で見る 空気の強さ", O.YEL, 42)


def sc_persong(img, box, t, k, P):
    x0, y0, x1, y1 = box
    st = P.get("stage", 0)
    grad(img, box=box)
    d = ImageDraw.Draw(img)
    gy = y1 - 90 * S
    hp = (gy - y0 - 260 * S)
    if st == 0:
        cx = x0 + (x1 - x0) * 0.32
        person(d, cx, gy, hp)
        arrow(d, cx, gy - hp - 70 * S, cx, gy - hp + 10 * S, 14 * S, O.DIM) if False else None
        arrow(d, cx + hp * 0.35, gy - hp * 0.6, cx + hp * 0.35, gy + 10 * S, 14 * S, O.GREEN)
        label(d, (cx, y0 + 60 * S), "地上で立っているとき　1G", 44, O.GREEN)
        d.line([(x0 + 20 * S, gy), (x1 - 20 * S, gy)], fill=O.DIM, width=int(3 * S))
        label(d, (x0 + (x1 - x0) * 0.72, (y0 + y1) / 2), "押す距離が短いほど\n体にかかる力が強い".replace("\n", ""), 34 if LAND else 28, O.YEL)
    else:
        for i, (cx, mult, s, col) in enumerate(((x0 + (x1 - x0) * 0.27, 1.0, "46G　耐えた記録（ほんの一瞬）", O.YEL), (x0 + (x1 - x0) * 0.74, 0.42, "230G　問題外", O.RED))):
            h = hp * (1.0 if i == 0 else 0.7)
            person(d, cx, gy, h * (1 - 0.25 * i))
            arrow(d, cx, gy - h - 30 * S, cx, gy - h * (1 - 0.25 * i) * 0.55, (10 if i == 0 else 40) * S, col)
            label(d, (cx, y0 + 60 * S + i * 0), s, 34 if LAND else 28, col)
        text(d, ((x0 + x1) / 2, y1 - 20 * S), "1954年 ロケットそり", 28, O.DIM, "md", 3)


def sc_ship(img, box, t, k, P):
    """船の想像図。assets/ship_gemini.jpg があれば AI の絵、無ければ影絵。"""
    x0, y0, x1, y1 = box
    path = ASSETS / "ship_gemini.jpg"
    if path.exists():
        key = ("ship", W, H)
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
    else:
        grad(img, (110, 165, 225), (225, 238, 250), box)
        d = ImageDraw.Draw(img)
        sea = y1 - (y1 - y0) * 0.28
        d.rectangle([x0, sea, x1, y1], fill=(25, 80, 140))
        bob = 6 * S * math.sin(t * 1.6)
        ship_sil(d, (x0 + x1) / 2, sea + 20 * S + bob, min(x1 - x0 - 160 * S, 900 * S))
        for i in range(10):
            wx = x0 + (x1 - x0) * i / 9 + 10 * S * math.sin(t * 1.4 + i)
            d.arc([wx - 60 * S, sea - 8 * S, wx + 60 * S, sea + 30 * S], 200, 340, fill=(140, 200, 240), width=int(3 * S))
    d = ImageDraw.Draw(img)
    label(d, ((x0 + x1) / 2, y0 + (130 if (TAGGED[0] and not LAND) else 55) * S), "仮に置いた船　全長30m・200トン", 42, O.YEL)
    if P.get("mayflower", True) and LAND:
        label(d, ((x0 + x1) / 2, y1 - 40 * S), "復元船マイフラワー2世は 全長約32m・約240トン", 34, O.WHITE)


_PH = {}


def sc_hull(img, box, t, k, P):
    x0, y0, x1, y1 = box
    grad(img, (110, 165, 225), (225, 238, 250), box)
    d = ImageDraw.Draw(img)
    sea = y0 + (y1 - y0) * 0.5
    d.rectangle([x0, sea, x1, y1], fill=(25, 80, 140))
    cx = (x0 + x1) / 2
    ship_sil(d, cx, sea + 26 * S, min(x1 - x0 - 200 * S, 440 * S))
    n = 9
    a = _ease(k * 2)
    for i in range(n):
        ax = cx - 300 * S + 600 * S * i / (n - 1)
        arrow(d, ax, sea + 270 * S - 20 * S * math.sin(t * 6 + i), ax, sea + 70 * S, 18 * S * (0.4 + 0.6 * a), O.RED)
    head(d, box, "船底が水から受ける力", O.YEL)
    label(d, (cx, sea + 340 * S), "約4万7000トン分（200トン × 約230G）", 40, O.RED)


def sc_coin(img, box, t, k, P):
    x0, y0, x1, y1 = box
    grad(img, box=box)
    d = ImageDraw.Draw(img)
    gy = y1 - 110 * S
    cx = x0 + (x1 - x0) * 0.3
    hp = (gy - y0 - 240 * S)
    person(d, cx, gy, hp)
    label(d, (cx, y0 + 140 * S), "大人1人分　約100kg", 40, O.YEL)
    rx = x0 + (x1 - x0) * 0.72
    r = 120 * S * (1 + 0.02 * math.sin(t * 2))
    cy = (y0 + y1) / 2 - 20 * S
    d.ellipse([rx - r, cy - r, rx + r, cy + r], fill=(205, 210, 215), outline=(240, 240, 245), width=int(5 * S))
    text(d, (rx, cy), "1", int(r / S * 1.0), (150, 155, 160), "mm", 0)
    label(d, (rx, cy + r + 50 * S), "1円玉1枚の面積", 36, O.WHITE)
    arrow(d, cx + hp * 0.4, (y0 + y1) / 2, rx - r - 30 * S, cy, 12 * S, O.RED)
    head(d, box, "それが 船底全体にかかる", O.RED, 42)


def sc_struct(img, box, t, k, P):
    """板(kind=plank)と、大砲を乗せた梁(kind=beam)。上に絵、下に棒グラフ。stage=1 の梁は折れる。"""
    x0, y0, x1, y1 = box
    grad(img, box=box)
    d = ImageDraw.Draw(img)
    which = P["which"]
    st = P.get("stage", 0)
    if LAND:
        ybox = (x0, y0, x1, y0 + (y1 - y0) * 0.5)
        bbox = (x0, y0 + (y1 - y0) * 0.5, x1, y1)
    else:
        ybox = (x0, y0, x1, y0 + (y1 - y0) * 0.45)
        bbox = (x0, y0 + (y1 - y0) * 0.45, x1, y1)
    ax0, ax1 = ybox[0] + (ybox[2] - ybox[0]) * 0.12, ybox[2] - (ybox[2] - ybox[0]) * 0.12
    ay = ybox[1] + (ybox[3] - ybox[1]) * (0.62 if which == "plank" else 0.74)
    bend = _ease(k * 1.5)
    if which == "plank":
        th = 22 * S
        sag = 34 * S * (0.3 + 0.7 * bend)
        pts_t = [(ax0 + (ax1 - ax0) * i / 40, ay + sag * (1 - ((i / 20) - 1) ** 2)) for i in range(41)]
        pts_b = [(x, y + th) for x, y in pts_t]
        d.polygon(pts_t + pts_b[::-1], fill=(170, 125, 80), outline=(230, 200, 150))
        for i in range(1, 6):
            xx = ax0 + (ax1 - ax0) * i / 6
            d.line([(xx, ay + th + sag * (1 - ((i / 3) - 1) ** 2)), (xx, ay + th + 90 * S)], fill=(120, 85, 55), width=int(10 * S))
        d.line([(ax0, ay + th + 90 * S), (ax1, ay + th + 90 * S)], fill=(120, 85, 55), width=int(10 * S))
        label(d, (ax0 + 90 * S, ay - 70 * S), "厚さ 8cm", 34, O.YEL)
        label(d, ((ax0 + ax1) / 2, ay + th + 130 * S), "骨組みの間隔 40cm", 34, O.YEL)
        rows = [("オークの生木", 232, None, "約230G", O.GREEN), ("乾いた木", 428, None, "約430G", O.GREEN)]
        mk = [(234, "30mで押し上げる 約230G", O.RED)]
        head(d, ybox, "船底の板（30mで押し上げたとき）", O.WHITE, 40)
    else:
        L = ax1 - ax0
        cxm = (ax0 + ax1) / 2
        th = 26 * S
        if st == 0:
            sag = 26 * S * (0.3 + 0.7 * bend)
            pts_t = [(ax0 + L * i / 40, ay + sag * (1 - ((i / 20) - 1) ** 2)) for i in range(41)]
            d.polygon(pts_t + [(x, y + th) for x, y in pts_t[::-1]], fill=(170, 125, 80), outline=(230, 200, 150))
            cy_c = ay + sag - 6 * S
        else:
            f = _ease(k * 2)
            for sgn in (-1, 1):
                xs = cxm + sgn * 10 * S
                xe = ax0 if sgn < 0 else ax1
                dy = 120 * S * f
                d.polygon([(xs, ay + dy * 0.2), (xe, ay), (xe, ay + th), (xs, ay + th + dy * 0.2 + dy * 0.2)], fill=(170, 125, 80), outline=(230, 200, 150))
            cy_c = ay + 40 * S + 150 * S * f
        for xx in (ax0, ax1):
            d.polygon([(xx - 28 * S, ay + th + 50 * S), (xx + 28 * S, ay + th + 50 * S), (xx, ay + th)], fill=(120, 85, 55))
        # 大砲
        cs = 46 * S
        d.rounded_rectangle([cxm - cs * 1.4, cy_c - cs * 0.9, cxm + cs * 1.6, cy_c - cs * 0.2], int(cs * 0.3), fill=(50, 55, 65), outline=(160, 165, 175), width=2)
        d.ellipse([cxm - cs * 0.7, cy_c - cs * 0.5, cxm + cs * 0.7, cy_c + cs * 0.9], fill=(90, 70, 50), outline=(160, 165, 175), width=2) if False else None
        d.ellipse([cxm - cs * 0.5, cy_c - cs * 0.3, cxm + cs * 0.5, cy_c + cs * 0.7], fill=(90, 70, 50))
        label(d, (cxm, ybox[1] + 120 * S), "1トンの大砲", 34, O.WHITE)
        label(d, (ax0 + 120 * S, ay + th + 120 * S), "長さ2mの梁", 34, O.YEL)
        if st == 1 and k > 0.4:
            label(d, (cxm, ay + th + 120 * S), "折れる", 46, O.RED)
        rows = [("乾いたオーク", 56, None, "約56G", O.YEL), ("オークの生木", 30, None, "約30G", O.RED)]
        mk = [(234, "30mで押し上げる 約230G", O.RED)]
        head(d, ybox, "荷物の梁（1トンの大砲）", O.WHITE, 40)
    bars(d, bbox, rows, 640 if which == "plank" else 250, k, 0, mk, names_above=False, y_top=bbox[1] + (90 if LAND else 140) * S)


def sc_gbars(img, box, t, k, P):
    grad(img, box=box)
    d = ImageDraw.Draw(img)
    bars(d, box, P["rows"], P["vmax"], k, P.get("grow_from", 0), P.get("marks", ()))
    if P.get("head"):
        head(d, box, P["head"], P.get("hcol", O.YEL))


def sc_gdial(img, box, t, k, P):
    x0, y0, x1, y1 = box
    grad(img, box=box)
    d = ImageDraw.Draw(img)
    cx = (x0 + x1) / 2
    R = min((x1 - x0) * 0.32, (y1 - y0) * 0.5)
    cy = (y0 + y1) / 2 + R * 0.55
    val = 234 * _ease(k * 1.8)
    pegged = val > 50
    shake = 3 * math.sin(t * 50) if pegged else 0
    dial(d, cx, cy, R, 50, val, [(0, "0"), (10, "10"), (20, "20"), (30, "30"), (40, "40"), (50, "50G")], zones=[(46, 50, O.RED)], shake=shake)
    text(d, (cx, cy + 70 * S), f"約{min(val, 234):.0f}G" if val < 234 * 0.98 else "約230G", 80, O.RED if pegged else O.YEL, "mm", 6)
    if pegged:
        label(d, (cx, cy + 170 * S), "メーターが振り切れる", 44, O.RED)
    label(d, (cx, y0 + 70 * S), "30mで押し上げると", 44, O.WHITE)
    text(d, (cx + R * 0.95, cy - R * 0.55 - 70 * S), "人が耐えた記録 46G", 28, O.RED, "rm", 3)


def sc_skytree(img, box, t, k, P):
    x0, y0, x1, y1 = box
    grad(img, (110, 165, 225), (225, 238, 250), box)
    d = ImageDraw.Draw(img)
    gy = y1 - 50 * S
    top = y0 + 80 * S
    unit = (gy - top) / 5.5
    cx = x0 + (x1 - x0) * (0.3 if LAND else 0.35)
    d.rectangle([x0, gy, x1, y1], fill=(70, 80, 60))
    n = int(5.5 * 2 * _ease(k * 1.6)) / 2.0
    for i in range(6):
        if n <= i:
            break
        frac = min(1.0, n - i)
        yb = gy - unit * i
        h = unit * frac
        col = (96 + 24 * (i % 2), 112 + 22 * (i % 2), 150)
        d.polygon([(cx - 50 * S, yb), (cx + 50 * S, yb), (cx + 16 * S, yb - h * 0.72), (cx - 16 * S, yb - h * 0.72)], fill=col, outline=O.WHITE)
        d.rectangle([cx - 60 * S, yb - h * 0.56, cx + 60 * S, yb - h * 0.5], fill=O.WHITE) if frac > 0.6 else None
        d.line([(cx, yb - h * 0.72), (cx, yb - h)], fill=col, width=max(2, int(5 * S)))
    d.line([(cx + 130 * S, gy), (cx + 130 * S, gy - unit * n)], fill=O.YEL, width=int(5 * S))
    label(d, (cx + 150 * S + (340 * S if LAND else 100 * S), (gy + gy - unit * n) / 2), f"スカイツリー（634m）×{n:g}", 38, O.YEL)
    if n >= 5.5:
        label(d, (cx + 150 * S + (340 * S if LAND else 100 * S), (gy + gy - unit * n) / 2 + 100 * S), "3Gなら 押し上げは 約3.5km", 40, O.GREEN)


def sc_weightless(img, box, t, k, P):
    x0, y0, x1, y1 = box
    grad(img, box=box)
    d = ImageDraw.Draw(img)
    if LAND:
        bx = (x0 + (x1 - x0) * 0.04, y0 + 130 * S, x0 + (x1 - x0) * 0.46, y1 - 60 * S)
        gb = (x0 + (x1 - x0) * 0.5, y0, x1, y1)
    else:
        bx = (x0 + 60 * S, y0 + 200 * S, x1 - 60 * S, y0 + (y1 - y0) * 0.5)
        gb = (x0, y0 + (y1 - y0) * 0.52, x1, y1)
    d.rounded_rectangle(bx, int(20 * S), fill=(40, 60, 95), outline=(190, 205, 230), width=int(5 * S))
    cx, cy = (bx[0] + bx[2]) / 2, (bx[1] + bx[3]) / 2
    fl = 14 * S * math.sin(t * 1.3)
    hp = (bx[3] - bx[1]) * 0.45
    person(d, cx + 10 * S * math.sin(t * 0.8), cy + hp / 2 + fl, hp)
    for i, (dx, dy) in enumerate(((-0.28, -0.3), (0.3, -0.2), (-0.25, 0.25), (0.32, 0.22))):
        xx = cx + (bx[2] - bx[0]) * dx
        yy = cy + (bx[3] - bx[1]) * dy + 12 * S * math.sin(t * 1.1 + i)
        d.ellipse([xx - 22 * S, yy - 22 * S, xx + 22 * S, yy + 22 * S], fill=(220, 190, 110))
    label(d, (cx, bx[1] - 40 * S), "船の中は無重力", 40, O.YEL)
    rows = [("無重力の時間", 38, None, "約38秒", O.YEL), ("訓練機", 25, None, "約25秒", O.DIM)]
    bars(d, gb, rows, 45, k, 0, (), True if not LAND else True, y_top=gb[1] + (130 if LAND else 40) * S + (120 * S if LAND else 0))
    label(d, ((gb[0] + gb[2]) / 2, gb[3] - 70 * S), "訓練機の約1.5倍", 40, O.GREEN)


def sc_conds(img, box, t, k, P):
    x0, y0, x1, y1 = box
    grad(img, box=box)
    d = ImageDraw.Draw(img)
    items = [("1", "水は 秒速370m以上", "音より速く噴き出す", O.YEL),
             ("2", "太い柱で 途切れさせない", "空気にも負けない", O.BLUE),
             ("3", "数kmかけて ゆっくり押し上げる", "3Gなら 船も人も持つ", O.GREEN)]
    n = 3
    if LAND:
        gap = 30 * S
        cw = ((x1 - x0) - 100 * S - gap * 2) / 3
        for i, (num, a, b, col) in enumerate(items):
            u = _ease(k * 3.2 - i * 0.9)
            if u <= 0:
                continue
            cxl = x0 + 50 * S + i * (cw + gap)
            cy0 = y0 + 160 * S + (1 - u) * 40 * S
            d.rounded_rectangle([cxl, cy0, cxl + cw, cy0 + 440 * S], int(24 * S), fill=(24, 40, 78), outline=col, width=int(5 * S))
            text(d, (cxl + cw / 2, cy0 + 90 * S), num, 110, col, "mm", 6)
            text(d, (cxl + cw / 2, cy0 + 230 * S), a, 36, O.WHITE, "mm", 5)
            text(d, (cxl + cw / 2, cy0 + 330 * S), b, 32, O.DIM, "mm", 4)
    else:
        ch = ((y1 - y0) - 200 * S - 2 * 30 * S) / 3
        for i, (num, a, b, col) in enumerate(items):
            u = _ease(k * 3.2 - i * 0.9)
            if u <= 0:
                continue
            cy0 = y0 + 120 * S + i * (ch + 30 * S) + (1 - u) * 40 * S
            d.rounded_rectangle([x0 + 50 * S, cy0, x1 - 50 * S, cy0 + ch], int(24 * S), fill=(24, 40, 78), outline=col, width=int(5 * S))
            text(d, (x0 + 150 * S, cy0 + ch / 2), num, 110, col, "mm", 6)
            text(d, (x0 + 250 * S, cy0 + ch / 2 - 28 * S), a, 34, O.WHITE, "lm", 5)
            text(d, (x0 + 250 * S, cy0 + ch / 2 + 40 * S), b, 30, O.DIM, "lm", 4)
    head(d, box, "届く条件は 3つ", O.WHITE, 44)


KINDS = dict(column=sc_column, ruler=sc_ruler, formula=sc_formula, bars=sc_bars, speed=sc_speed, decel=sc_decel, plume=sc_plume,
             push=sc_push, widen=sc_widen, fountain=sc_fountain, drops=sc_drops, dropfly=sc_dropfly, airarrow=sc_airarrow, rain=sc_rain,
             persong=sc_persong, ship=sc_ship, hull=sc_hull, coin=sc_coin, struct=sc_struct, gbars=sc_gbars, gdial=sc_gdial,
             skytree=sc_skytree, weightless=sc_weightless, conds=sc_conds)


def region(P):
    return (0, 100, W, 880) if LAND else (0, 240, W, 1370)


def paint(sc, t, k):
    img = Image.new("RGBA", (W, H), BG0 + (255,))
    KINDS[sc["kind"]](img, region(sc), t, k, sc)
    return img


def _tag(img, box, n):
    """左上の「実験N」の札。"""
    d = ImageDraw.Draw(img)
    x0, y0 = box[0], box[1]
    s = f"実験{n}" if isinstance(n, int) else str(n)
    f = O.font(int(44 * S))
    w = f.getlength(s)
    bx = (x0 + 24 * S, y0 + 14 * S, x0 + 24 * S + w + 40 * S, y0 + 14 * S + 70 * S)
    d.rounded_rectangle(bx, int(14 * S), fill=O.YEL, outline=O.NAVY, width=int(3 * S))
    d.text(((bx[0] + bx[2]) / 2, (bx[1] + bx[3]) / 2), s, font=f, fill=O.NAVY, anchor="mm")
    O.BOXES.append(("label", bx, s, 1.0))


def _stamp(img, box, kind, u):
    """大きな「失敗」(赤)・「成功」(緑)の札。u=0→1 で、大きく出てすっと落ち着く。"""
    s, col = ("失敗", O.RED) if kind == "fail" else ("成功", O.GREEN)
    sz = int(190 * S)
    f = O.font(sz)
    pad = int(36 * S)
    tw = int(f.getlength(s))
    lay = Image.new("RGBA", (tw + pad * 2, sz + pad * 2), (0, 0, 0, 0))
    ld = ImageDraw.Draw(lay)
    ld.rounded_rectangle([4, 4, lay.width - 5, lay.height - 5], int(30 * S), fill=(8, 16, 36, 235), outline=col, width=int(12 * S))
    ld.text((lay.width / 2, lay.height / 2 - int(6 * S)), s, font=f, fill=col, anchor="mm")
    sc = 1.0 + 0.5 * (1 - _ease(u * 3))
    lay = lay.resize((int(lay.width * sc), int(lay.height * sc)), Image.LANCZOS).rotate(8, expand=True, resample=Image.BICUBIC)
    cx = box[2] - lay.width / 2 - 40 * S
    cy = box[1] + lay.height / 2 + (24 if LAND else 90) * S
    img.alpha_composite(lay, (int(cx - lay.width / 2), int(cy - lay.height / 2)))


def draw(img, dr, t, ctx):
    lines, defs = ctx["lines"], ctx["defs"]
    scs = ctx.setdefault("_scenes", mapscene.scenes(lines, defs))
    cur = ctx["cur"] or lines[0]
    i = next(j for j, l in enumerate(lines) if l["id"] == cur["id"])
    now, prev = scs[i], (scs[i - 1] if i > 0 else None)
    dd = defs.get(cur["id"], {})
    k = ctx["k"]
    if prev is now:      # 前の行から引き継いだ図は、描き直さずそのまま見せる
        k = 1.0
    tag = dd.get("exp") if now["kind"] != "formula" else None
    TAGGED[0] = bool(tag) and not LAND
    u = _ease((t - cur["start"]) / 0.5)
    TAGGED_prev = TAGGED[0]
    b = paint(prev, t, 1.0) if prev is not None and prev is not now and u < 1 else None
    O.BOXES.clear()
    a = paint(now, t, k)
    if b is not None:
        a = Image.blend(b, a, u)
    z = 1.0 + 0.025 * (0.5 + 0.5 * math.sin(2 * math.pi * t / 14.0))
    if z > 1.0005:
        zw, zh = int(W * z), int(H * z)
        a = a.resize((zw, zh), Image.BILINEAR).crop(((zw - W) // 2, (zh - H) // 2, (zw - W) // 2 + W, (zh - H) // 2 + H))
    img.paste(a, (0, 0))
    box = region(now)
    if tag:
        _tag(img, box, tag)
    v = dd.get("verdict")
    if v and not ctx.get("cta"):
        frac = v[1]
        t0 = cur["start"] + frac * (cur["end"] - cur["start"])
        if t >= t0:
            _stamp(img, box, v[0], (t - t0) / 0.5)


def sfx_for(lines_def, L):
    ev = mapscene.sfx(lines_def, L)
    for d in lines_def:
        v = d.get("verdict")
        if v and d["id"] in L:
            l = L[d["id"]]
            ev.append((l["start"] + v[1] * (l["end"] - l["start"]), "pop"))
    return sorted(ev)

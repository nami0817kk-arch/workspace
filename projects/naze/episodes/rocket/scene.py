"""ロケットの回(計算の回)の画面。行の scene=dict(kind=…) を描く(無い行は前の行を引き継ぐ)。
場面が変わると 0.5 秒で溶け合わせる。作品・実機の写真は使わない。図は全部コードで描く(AI 絵は今回は無し)。
数字の出どころは research.md。台本は scripts.md。
kind: stack(縦の積み棒) / cargo(荷物メーター) / speedo(速さのメーター) / range(幅と目印) / hstack(足し算の横棒) / orbit / route / rotation /
      kg / massfig / ratio(倍率のメーター) / ton / f9 / balloon / growtank / limit / compound / fails / alt / xfig / tl / stages / bars / formula
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




# ---- ロケット用の色と部品 ------------------------------------------------------------------
AMBER = (240, 170, 70)
GREY = (170, 178, 192)
GRN = (110, 220, 140)
BLU = (90, 170, 235)
ORG = (240, 150, 40)
RED_ = (240, 90, 80)
COLS["orange"] = ORG


def fitsize(s, size, maxw):
    sz = size
    while O.font(int(sz * S)).getlength(s) > maxw and sz > 22:
        sz -= 2
    return sz


def vtext(d, xy, s, size, col=O.WHITE, anchor="mm", maxw=None, stroke=4):
    if maxw:
        size = fitsize(s, size, maxw)
    text(d, xy, s, size, col, anchor, stroke)


def body(d, cx, yb, w, h, col, nose=0.0, fins=0.0, outline=None):
    """ロケットの胴体。足元(yb)の真ん中 cx、幅 w、高さ h。nose＝先端の三角の高さ(h に対する割合)。"""
    top = yb - h
    d.rectangle([cx - w / 2, top, cx + w / 2, yb], fill=col, outline=outline, width=max(2, int(3 * S)) if outline else 0)
    if nose:
        nh = h * nose
        d.polygon([(cx - w / 2, top), (cx + w / 2, top), (cx, top - nh)], fill=col, outline=outline)
    if fins:
        fh = h * fins
        d.polygon([(cx - w / 2, yb), (cx - w / 2 - w * 0.5, yb + fh * 0.2), (cx - w / 2, yb - fh)], fill=col)
        d.polygon([(cx + w / 2, yb), (cx + w / 2 + w * 0.5, yb + fh * 0.2), (cx + w / 2, yb - fh)], fill=col)


def flame(d, cx, yb, w, t, hgt=None):
    hgt = hgt or w * 2.2
    f = 0.85 + 0.15 * math.sin(t * 30)
    d.polygon([(cx - w * 0.4, yb), (cx + w * 0.4, yb), (cx, yb + hgt * f)], fill=(255, 190, 70))
    d.polygon([(cx - w * 0.2, yb), (cx + w * 0.2, yb), (cx, yb + hgt * f * 0.6)], fill=(255, 245, 200))


def dashed(d, p0, p1, col, w=3, dash=14):
    x0, y0 = p0
    x1, y1 = p1
    L = math.hypot(x1 - x0, y1 - y0)
    n = max(1, int(L / (dash * S)))
    for i in range(0, n, 2):
        a, b = i / n, min(1.0, (i + 1) / n)
        d.line([(x0 + (x1 - x0) * a, y0 + (y1 - y0) * a), (x0 + (x1 - x0) * b, y0 + (y1 - y0) * b)], fill=col, width=max(2, int(w * S)))


def fmt_pct(v):
    if v < 0.05:
        return "0%"
    return f"約{v:.0f}%" if abs(v - round(v)) < 0.05 else f"約{v:.1f}%"


# ---- 縦の積み棒 -----------------------------------------------------------------------------

def sc_stack(img, box, t, k, P):
    """cols=[dict(name, segs=[(名前, %, 色, 札)])]。上から下の順。合計 100%。"""
    x0, y0, x1, y1 = box
    grad(img, box=box)
    d = ImageDraw.Draw(img)
    cols = P["cols"]
    n = len(cols)
    top = y0 + (150 if LAND else 230) * S
    bot = y1 - 60 * S
    Hh = bot - top
    gk = _ease(k * 1.6)
    slot = (x1 - x0) / n
    bw = min(230 * S, slot * (0.34 if n > 1 else 0.2))
    for i, c in enumerate(cols):
        sx = x0 + slot * i
        bx = sx + slot * (0.1 if n > 1 else 0.3)
        text(d, (bx + bw / 2, top - 34 * S), c["name"], fitsize(c["name"], 36, slot * 0.85), O.YEL if c.get("hl") else O.WHITE, "mm", 4)
        y = bot
        labs = []
        for name, pct, col, txt in reversed(c["segs"]):
            h = Hh * pct / 100.0 * gk
            d.rectangle([bx, y - h, bx + bw, y], fill=col, outline=O.NAVY, width=max(2, int(3 * S)))
            labs.append([y - h / 2, name, txt, col])
            y -= h
        labs.sort()
        gap = 46 * S
        for j in range(1, len(labs)):
            if labs[j][0] - labs[j - 1][0] < gap:
                labs[j][0] = labs[j - 1][0] + gap
        if gk > 0.5:
            for yy, name, txt, col in labs:
                if not name and not txt:
                    continue
                lx = bx + bw + 24 * S
                s = txt if not name else f"{txt}  {name}"
                vtext(d, (lx, yy), s, 38, O.WHITE, "lm", maxw=x0 + slot * (i + 1) - lx - 10 * S)
    if P.get("head"):
        head(d, box, P["head"], P.get("hcol", O.YEL))
    if P.get("foot"):
        text(d, ((x0 + x1) / 2, y1 - 14 * S), P["foot"], 28, O.DIM, "md", 3)


# ---- 荷物メーター ---------------------------------------------------------------------------

def sc_cargo(img, box, t, k, P):
    x0, y0, x1, y1 = box
    grad(img, box=box)
    d = ImageDraw.Draw(img)
    val, frm = P["val"], P.get("frm", P["val"])
    v = frm + (val - frm) * _ease(k * 1.5)
    gx0, gx1 = x0 + 90 * S, x1 - 90 * S
    cy = (y0 + y1) / 2 + (60 if LAND else 70) * S
    bh = 120 * S
    px = lambda p: gx0 + (gx1 - gx0) * p / 10.0
    d.rounded_rectangle([gx0, cy - bh / 2, gx1, cy + bh / 2], int(14 * S), fill=(30, 42, 70), outline=O.DIM, width=int(3 * S))
    if v > 0.02:
        d.rounded_rectangle([gx0, cy - bh / 2, max(gx0 + 12 * S, px(v)), cy + bh / 2], int(14 * S), fill=GRN)
    for p in range(0, 11, 2):
        d.line([(px(p), cy + bh / 2), (px(p), cy + bh / 2 + 16 * S)], fill=O.DIM, width=int(3 * S))
        text(d, (px(p), cy + bh / 2 + 24 * S), f"{p}%", 30, O.DIM, "ma", 3)
    if P.get("ghost") is not None:
        gx = px(P["ghost"])
        dashed(d, (gx, cy - bh / 2 - 70 * S), (gx, cy + bh / 2 + 10 * S), O.YEL, 4)
        text(d, (gx, cy - bh / 2 - 82 * S), P.get("ghost_txt", ""), 32, O.YEL, "md", 4)
    big = P.get("big") or fmt_pct(v)
    text(d, ((x0 + x1) / 2, cy - bh / 2 - (185 if P.get("ghost") is not None else 120) * S), big, 120, GRN if v > 0.02 else O.WHITE, "mm", 7)
    ny = cy + bh / 2 + 120 * S
    for s in P.get("note", []):
        vtext(d, ((x0 + x1) / 2, ny), s, 40, O.WHITE, "mm", maxw=x1 - x0 - 80 * S, stroke=5)
        ny += 56 * S
    head(d, box, P.get("head", "荷物メーター　荷物が全体の何%か"), O.YEL)


# ---- 速さのメーター ---------------------------------------------------------------------------

def sc_speedo(img, box, t, k, P):
    x0, y0, x1, y1 = box
    grad(img, box=box)
    d = ImageDraw.Draw(img)
    val = P["val"]
    v = val * _ease(k * 1.5)
    if LAND:
        dx0, dx1, dy0, dy1 = x0, x0 + (x1 - x0) * 0.5, y0, y1
        bbox = (x0 + (x1 - x0) * 0.5, y0 + 60 * S, x1, y1)
    else:
        dx0, dx1, dy0, dy1 = x0, x1, y0 + 120 * S, y0 + (y1 - y0) * 0.46
        bbox = (x0, y0 + (y1 - y0) * 0.5, x1, y1)
    cx = (dx0 + dx1) / 2
    R = min((dx1 - dx0) * 0.34, (dy1 - dy0) * 0.6)
    cy = (dy0 + dy1) / 2 + R * 0.5
    dial(d, cx, cy, R, 12, v, [(0, "0"), (2, "2"), (4, "4"), (6, "6"), (8, "8"), (10, "10"), (12, "12")], zones=[(9.3, 10.0, O.YEL)])
    text(d, (cx, cy + 70 * S), f"秒速 {v:.1f}km", 66, O.YEL, "mm", 6)
    text(d, (cx, cy + 140 * S), P.get("sub", ""), 38, O.WHITE, "mm", 5)
    mult = val * 1000 / 88.9
    rows = [("新幹線", 0.0889, None, "時速320km", (120, 150, 190)),
            (P.get("name", "ロケット"), val, None, P.get("rowtxt", f"秒速{val}km"), O.RED if val > 9 else (240, 200, 70))]
    bars(d, bbox, rows, 10, k, 0, (), True, y_top=bbox[1] + 40 * S)
    if P.get("mult"):
        label(d, (cx if not LAND else (bbox[0] + bbox[2]) / 2, y0 + 55 * S), f"新幹線の約{mult:.0f}倍", 38, O.YEL)


# ---- 幅と目印 -------------------------------------------------------------------------------

def sc_range(img, box, t, k, P):
    """axis=(lo, hi)、bands=[(lo, hi, 札, 色)]、marks=[(値, 札, 色, 段)]。"""
    x0, y0, x1, y1 = box
    grad(img, box=box)
    d = ImageDraw.Draw(img)
    lo, hi = P.get("axis", (8.4, 10.4))
    gx0, gx1 = x0 + 100 * S, x1 - 100 * S
    px = lambda v: gx0 + (gx1 - gx0) * (v - lo) / (hi - lo)
    cy = (y0 + y1) / 2 - 30 * S
    a = _ease(k * 2)
    d.line([(gx0, cy), (gx1, cy)], fill=O.WHITE, width=int(5 * S))
    v = math.ceil(lo * 2) / 2
    while v <= hi + 1e-9:
        d.line([(px(v), cy), (px(v), cy + 16 * S)], fill=O.DIM, width=int(3 * S))
        text(d, (px(v), cy + 22 * S), f"{v:g}", 30, O.DIM, "ma", 3)
        v += 0.5
    text(d, (gx1, cy + 70 * S), "必要な速さ（km/s）", 30, O.DIM, "ra", 3)
    for blo, bhi, s, col in P.get("bands", []):
        d.rectangle([px(blo), cy - 70 * S, px(bhi), cy], fill=mix(col, BG1, 0.9 * a + 0.1))
        hw = O.font(int(36 * S)).getlength(s) / 2 + 30 * S
        label(d, (min(max((px(blo) + px(bhi)) / 2, x0 + hw), x1 - hw), cy - 130 * S), s, 36, col)
    for i, (val, s, col, row) in enumerate(P.get("marks", [])):
        u = _ease(k * 2.2 - 0.3 * i)
        if u <= 0:
            continue
        xm = px(val)
        ly = cy + (130 + 76 * row) * S
        d.line([(xm, cy - 90 * S), (xm, ly - 28 * S)], fill=col, width=max(3, int(5 * S)))
        d.ellipse([xm - 9 * S, cy - 9 * S, xm + 9 * S, cy + 9 * S], fill=col)
        label(d, (min(max(xm, x0 + 190 * S), x1 - 190 * S), ly), s, 34, col)
    if P.get("head"):
        head(d, box, P["head"], O.YEL)


# ---- 足し算の横棒 -----------------------------------------------------------------------------

def sc_hstack(img, box, t, k, P):
    """segs=[(名前, 値, 色, 札)]。vmax は軸の端。順に伸びる。marks=[(値, 札, 色)]。"""
    x0, y0, x1, y1 = box
    grad(img, box=box)
    d = ImageDraw.Draw(img)
    vmax = P["vmax"]
    gx0, gx1 = x0 + 70 * S, x1 - 70 * S
    px = lambda v: gx0 + (gx1 - gx0) * v / vmax
    cy = (y0 + y1) / 2 - 30 * S
    bh = 130 * S
    segs = P["segs"]
    n = len(segs)
    pos = 0.0
    kk = k * 1.4
    for i, (name, val, col, txt) in enumerate(segs):
        u = _ease(kk * n - i)
        w = (px(pos + val) - px(pos)) * u
        if u > 0:
            d.rectangle([px(pos), cy - bh / 2, px(pos) + w, cy + bh / 2], fill=col, outline=O.NAVY, width=int(3 * S))
            mid = px(pos) + w / 2
            fw = (px(pos + val) - px(pos))
            if u > 0.8:
                if fw > 170 * S and txt:
                    text(d, (mid, cy), txt, fitsize(txt, 44, fw - 20 * S), O.NAVY, "mm", 0)
                row = i % 3
                ly = cy + bh / 2 + (70 + 62 * row) * S
                d.line([(mid, cy + bh / 2), (mid, ly - 26 * S)], fill=mix(col, BG1, 0.7), width=int(3 * S))
                lab = name if (fw > 170 * S or not txt) else f"{name} {txt}"
                if lab:
                    label(d, (min(max(mid, x0 + 200 * S), x1 - 200 * S), ly), lab, 32, col if col != GREY else O.WHITE)
        pos += val
    for v, s, col in P.get("marks", []):
        xm = px(v)
        dashed(d, (xm, cy - bh / 2 - 40 * S), (xm, cy + bh / 2 + 20 * S), col, 4)
        text(d, (xm, cy - bh / 2 - 52 * S), s, 32, col, "md", 4)
    if P.get("total") and kk * n >= n:
        text(d, ((x0 + x1) / 2, cy - bh / 2 - 150 * S), P["total"], 60, O.YEL, "mm", 6)
    if P.get("head"):
        head(d, box, P["head"], O.YEL)


# ---- 軌道・東京大阪・自転 ----------------------------------------------------------------------

def earth(d, cx, cy, r):
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(40, 105, 185))
    for dx, dy, rx, ry in ((-0.3, -0.25, 0.28, 0.2), (0.25, 0.1, 0.22, 0.28), (-0.15, 0.4, 0.18, 0.12)):
        d.ellipse([cx + (dx - rx) * r, cy + (dy - ry) * r, cx + (dx + rx) * r, cy + (dy + ry) * r], fill=(70, 150, 90))
    d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=(150, 205, 250), width=int(4 * S))


def sc_orbit(img, box, t, k, P):
    x0, y0, x1, y1 = box
    grad(img, (6, 10, 28), (12, 22, 50), box)
    d = ImageDraw.Draw(img)
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2 + 40 * S
    Rr = min(x1 - x0, y1 - y0) * 0.36
    Re = Rr * 0.78
    d.ellipse([cx - Rr, cy - Rr, cx + Rr, cy + Rr], outline=O.YEL, width=int(5 * S))
    earth(d, cx, cy, Re)
    th = t * 0.9 - math.pi / 2
    sx, sy = cx + math.cos(th) * Rr, cy + math.sin(th) * Rr
    d.rectangle([sx - 20 * S, sy - 9 * S, sx + 20 * S, sy + 9 * S], fill=O.WHITE)
    d.rectangle([sx - 46 * S, sy - 4 * S, sx - 22 * S, sy + 4 * S], fill=BLU)
    d.rectangle([sx + 22 * S, sy - 4 * S, sx + 46 * S, sy + 4 * S], fill=BLU)
    head(d, box, "軌道　地球のまわりを回り続ける道", O.YEL)
    text(d, (cx, y1 - 30 * S), "地上200kmの軌道（図は高さを大きく描いています）", 28, O.DIM, "md", 3)
    text(d, (cx, cy), "地球", 44, O.WHITE, "mm", 5)


def sc_route(img, box, t, k, P):
    x0, y0, x1, y1 = box
    grad(img, box=box)
    d = ImageDraw.Draw(img)
    ax, ay = x0 + (x1 - x0) * 0.2, (y0 + y1) / 2 - 80 * S
    bx, by = x1 - (x1 - x0) * 0.2, ay - 30 * S
    d.line([(ax, ay), (bx, by)], fill=O.DIM, width=int(6 * S))
    u = _ease(k * 1.8)
    d.line([(ax, ay), (ax + (bx - ax) * u, ay + (by - ay) * u)], fill=O.YEL, width=int(10 * S))
    for (px_, py_, nm) in ((ax, ay, "東京"), (bx, by, "大阪")):
        d.ellipse([px_ - 20 * S, py_ - 20 * S, px_ + 20 * S, py_ + 20 * S], fill=O.WHITE, outline=O.NAVY, width=int(3 * S))
        text(d, (px_, py_ + 36 * S), nm, 52, O.WHITE, "ma", 5)
    d.ellipse([ax + (bx - ax) * u - 16 * S, ay + (by - ay) * u - 16 * S, ax + (bx - ax) * u + 16 * S, ay + (by - ay) * u + 16 * S], fill=RED_)
    text(d, ((ax + bx) / 2, ay - 90 * S), "約400km", 54, O.WHITE, "mm", 6)
    text(d, ((x0 + x1) / 2, ay + 250 * S), "約51秒" if u > 0.95 else f"{51 * u:.0f}秒", 130, O.YEL, "mm", 8)
    text(d, ((x0 + x1) / 2, ay + 380 * S), "地球を 約90分で1周する速さ", 44, O.WHITE, "mm", 5)
    head(d, box, "秒速7.8kmで東京から大阪まで", O.YEL)


def sc_rotation(img, box, t, k, P):
    x0, y0, x1, y1 = box
    st = P.get("stage", 0)
    grad(img, (6, 10, 28), (12, 22, 50), box)
    d = ImageDraw.Draw(img)
    if st == 0:
        cx, cy = (x0 + x1) / 2, (y0 + y1) / 2 - 10 * S
        r = min(x1 - x0, y1 - y0) * 0.26
    elif LAND:
        cx, cy = x0 + (x1 - x0) * 0.25, (y0 + y1) / 2 - 10 * S
        r = min(x1 - x0, y1 - y0) * 0.24
    else:
        cx, cy = (x0 + x1) / 2, y0 + (y1 - y0) * 0.3
        r = min(x1 - x0, y1 - y0) * 0.17
    earth(d, cx, cy, r)
    ar = r * 1.25
    d.arc([cx - ar, cy - ar, cx + ar, cy + ar], 20, 160, fill=O.YEL, width=int(10 * S))
    th = math.radians(20)
    ex, ey = cx + math.cos(th) * ar, cy + math.sin(th) * ar
    dx, dy = math.sin(th), -math.cos(th)
    nx, ny = -dy, dx
    d.polygon([(ex + dx * 34 * S, ey + dy * 34 * S), (ex + nx * 26 * S, ey + ny * 26 * S), (ex - nx * 26 * S, ey - ny * 26 * S)], fill=O.YEL)
    text(d, (cx, cy + ar + 34 * S), "東向きに回る（北極の上から見た図）", 34, O.YEL, "mm", 5)
    px_, py_ = cx + r * 0.84, cy + r * 0.18
    d.ellipse([px_ - 12 * S, py_ - 12 * S, px_ + 12 * S, py_ + 12 * S], fill=RED_, outline=O.WHITE, width=int(3 * S))
    text(d, (px_ + 26 * S, py_ + 30 * S), "種子島", 36, O.WHITE, "la", 4)
    if st == 1:
        if LAND:
            bb = (x0 + (x1 - x0) * 0.5, y0 + 120 * S, x1, y1)
        else:
            bb = (x0, y0 + (y1 - y0) * 0.55, x1, y1)
        rows = [("打つ前から付いている速さ", 0.4, None, "秒速約400m", GRN), ("軌道の速さ", 7.8, None, "秒速7.8km", BLU)]
        bars(d, bb, rows, 8.4, k, 0, (), True, y_top=bb[1] + 60 * S)
        label(d, ((bb[0] + bb[2]) / 2, bb[1] + 40 * S), "7.8kmの 約5%", 40, O.YEL)
    else:
        text(d, ((x0 + x1) / 2, y1 - 50 * S), "ロケットは東へ傾けて、地球の回る勢いに乗る", 34, O.WHITE, "mm", 4)


# ---- 1kg と 25kg ・ 倍率の図 ---------------------------------------------------------------------

def crate(d, x, yb, w, h, col, s, size=40):
    d.rectangle([x - w / 2, yb - h, x + w / 2, yb], fill=col, outline=O.NAVY, width=int(4 * S))
    d.line([(x - w / 2, yb - h * 0.55), (x + w / 2, yb - h * 0.55)], fill=O.NAVY, width=int(3 * S))
    text(d, (x, yb - h * 0.28), s, size, O.NAVY, "mm", 0)


def sc_kg(img, box, t, k, P):
    x0, y0, x1, y1 = box
    st = P.get("stage", 0)
    grad(img, box=box)
    d = ImageDraw.Draw(img)
    yb = y1 - 160 * S
    u = _ease(k * 1.6)
    if st == 0:
        cx = (x0 + x1) / 2 - (200 if LAND else 120) * S
        crate(d, cx, yb, 150 * S, 150 * S, GRN, "1kg", 54)
        text(d, (cx, yb + 30 * S), "荷物（衛星など）", 36, O.WHITE, "ma", 4)
        for i in range(2):   # ペットボトル2本
            bx = cx + (300 + 100 * i) * S
            d.rounded_rectangle([bx - 30 * S, yb - 190 * S, bx + 30 * S, yb], int(14 * S), fill=(150, 210, 245), outline=O.WHITE, width=int(3 * S))
            d.rectangle([bx - 12 * S, yb - 226 * S, bx + 12 * S, yb - 190 * S], fill=(150, 210, 245))
        text(d, (cx + 350 * S, yb + 30 * S), "ペットボトル2本ぶん", 36, O.WHITE, "ma", 4)
        head(d, box, "運びたい荷物 1kg", O.YEL)
    else:
        cx = x0 + (x1 - x0) * (0.12 if LAND else 0.14)
        crate(d, cx, yb, 120 * S, 120 * S, GRN, "1kg", 44)
        text(d, (cx, yb + 30 * S), "荷物", 36, O.WHITE, "ma", 4)
        sx0 = x0 + (x1 - x0) * (0.26 if LAND else 0.3)
        bw, gap = (150 if LAND else 118) * S, (28 if LAND else 14) * S
        for i in range(5):
            if u * 5 > i:
                bx = sx0 + i * (bw + gap)
                d.rounded_rectangle([bx, yb - 190 * S, bx + bw, yb], int(24 * S), fill=(235, 225, 190), outline=O.NAVY, width=int(4 * S))
                text(d, (bx + bw / 2, yb - 95 * S), "5kg", 44, O.NAVY, "mm", 0)
        text(d, ((sx0 + sx0 + 5 * bw + 4 * gap) / 2, yb + 30 * S), "お米の袋 5つぶん ＝ 約25kg", 36, O.WHITE, "ma", 4)
        head(d, box, "燃料も機体も入れて 約25kg を打ち上げる", O.YEL, 40)


def sc_massfig(img, box, t, k, P):
    x0, y0, x1, y1 = box
    grad(img, box=box)
    d = ImageDraw.Draw(img)
    base = y1 - 130 * S
    Ht = (base - y0 - 190 * S)
    u = _ease(k * 1.6)
    cx1 = x0 + (x1 - x0) * (0.28 if LAND else 0.24)
    cx2 = x0 + (x1 - x0) * (0.66 if LAND else 0.76)
    wd = 200 * S
    d.rectangle([cx1 - wd / 2, base - Ht * u, cx1 + wd / 2, base], fill=AMBER, outline=O.NAVY, width=int(4 * S))
    d.rectangle([cx2 - wd / 2, base - Ht / 24.4, cx2 + wd / 2, base], fill=GREY, outline=O.NAVY, width=int(4 * S))
    text(d, (cx1, base + 14 * S), "離陸のときの重さ", fitsize("離陸のときの重さ", 36, (x1 - x0) * 0.4), O.WHITE, "ma", 4)
    text(d, (cx2, base + 14 * S), "燃え尽きたあとの重さ", fitsize("燃え尽きたあとの重さ", 36, (x1 - x0) * 0.4), O.WHITE, "ma", 4)
    if u > 0.9:
        dashed(d, (cx1 + wd / 2, base - Ht), (cx2 - wd / 2, base - Ht), O.YEL, 4)
        text(d, ((cx1 + cx2) / 2, base - Ht * 0.5), "何倍？", 90, O.YEL, "mm", 7)
    head(d, box, "倍率 ＝ 離陸の重さ ÷ 燃え尽きたあとの重さ", O.YEL, 38)


def sc_ratio(img, box, t, k, P):
    """rows=[(名前, 倍率, 色, 札)]。need＝必要な倍率の目印。"""
    x0, y0, x1, y1 = box
    grad(img, box=box)
    d = ImageDraw.Draw(img)
    vmax = P.get("vmax", 36)
    gx0, gx1 = x0 + 70 * S, x1 - 70 * S
    px = lambda v: gx0 + (gx1 - gx0) * v / vmax
    rows = P["rows"]
    n = len(rows)
    rh = 150 * S
    ya = (y0 + y1) / 2 - rh * n / 2 + 10 * S
    for i, (name, val, col, txt) in enumerate(rows):
        cy = ya + rh * (i + 0.5)
        u = _ease(k * 1.5 - 0.25 * i)
        d.rectangle([gx0, cy - 34 * S, gx1, cy + 34 * S], fill=(30, 42, 70))
        d.rectangle([gx0, cy - 34 * S, gx0 + (px(val) - gx0) * u, cy + 34 * S], fill=col)
        text(d, (gx0, cy - 56 * S), name, 36, O.WHITE, "ld", 4)
        if u > 0.6:
            xe = gx0 + (px(val) - gx0) * u
            if xe + 300 * S < x1:
                vtext(d, (xe + 14 * S, cy), txt, 40, O.WHITE, "lm", maxw=gx1 + 60 * S - xe - 14 * S)
            else:
                vtext(d, (xe - 14 * S, cy), txt, 40, O.NAVY, "rm", stroke=0, maxw=xe - gx0 - 20 * S)
    top = ya - 20 * S
    for v in range(0, int(vmax) + 1, 5):
        text(d, (px(v), ya + rh * n + 14 * S), f"{v}", 28, O.DIM, "ma", 3)
    text(d, (gx1, ya + rh * n + 54 * S), "倍率（離陸の重さ÷燃え尽きたあとの重さ）", 28, O.DIM, "ra", 3)
    if P.get("need"):
        xn = px(P["need"])
        dashed(d, (xn, top - 10 * S), (xn, ya + rh * n), O.RED, 5)
        text(d, (xn, top - 20 * S), P.get("need_txt", "必要 約24倍"), 34, O.RED, "md", 4)
    for i, l in enumerate(P.get("extra", [])):
        text(d, ((x0 + x1) / 2, y1 - 70 * S + 52 * S * i), l, 40, O.YEL, "mm", 5)
    if P.get("head"):
        head(d, box, P["head"], O.YEL)


# ---- 1トンの箱 ・ ファルコン9 ・ タンク -----------------------------------------------------------

def sc_ton(img, box, t, k, P):
    x0, y0, x1, y1 = box
    st = P.get("stage", 0)
    grad(img, box=box)
    d = ImageDraw.Draw(img)
    u = _ease(k * 1.6)
    if st < 2:
        top = y0 + (140 if LAND else 220) * S
        bot = y1 - 60 * S
        Hh = bot - top
        bx = x0 + (x1 - x0) * (0.2 if LAND else 0.12)
        bw = 240 * S
        fh = Hh * 0.96 * u if P.get("split", True) else Hh
        d.rectangle([bx, bot - Hh, bx + bw, bot], outline=O.WHITE, width=int(4 * S), fill=GREY if P.get("split", True) else AMBER)
        if P.get("split", True):
            d.rectangle([bx, bot - fh, bx + bw, bot], fill=AMBER, outline=O.NAVY, width=int(3 * S))
        text(d, (bx + bw / 2, top - 40 * S), "離陸の重さ 1トン", 38, O.YEL, "mm", 4)
        if P.get("split", True) and u > 0.7:
            lx = bx + bw + 30 * S
            text(d, (lx, bot - Hh * 0.5), "燃料 約960kg", 44, O.WHITE, "lm", 5)
            text(d, (lx, top + 10 * S + 40 * S), "残り 約40kg", 44, O.YEL, "lm", 5)
            d.line([(bx + bw, top + Hh * 0.02), (lx - 6 * S, top + 50 * S)], fill=O.YEL, width=int(3 * S))
            # 軽自動車
            cx = x0 + (x1 - x0) * (0.62 if LAND else 0.55)
            cyb = bot - 20 * S
            d.rounded_rectangle([cx - 150 * S, cyb - 90 * S, cx + 150 * S, cyb - 30 * S], int(24 * S), fill=(120, 150, 200), outline=O.NAVY, width=int(3 * S))
            d.rounded_rectangle([cx - 90 * S, cyb - 150 * S, cx + 70 * S, cyb - 85 * S], int(24 * S), fill=(120, 150, 200), outline=O.NAVY, width=int(3 * S))
            for wx in (-90, 90):
                d.ellipse([cx + wx * S - 30 * S, cyb - 60 * S, cx + wx * S + 30 * S, cyb], fill=(30, 30, 40), outline=O.WHITE, width=int(3 * S))
            text(d, (cx, cyb + 28 * S), "軽自動車1台ぶん", 38, O.WHITE, "ma", 4)
    else:
        rows = [("使える残り（1トンの4%）", 40, None, "約40kg", GRN),
                ("ファルコン9 1段目の空の機体（約5%）", 51, None, "約51kg", RED_)]
        bars(d, box, rows, 60, k, 0, (), True, y_top=y0 + 140 * S)
        head(d, box, "1トンで比べる　51kg は 40kg より重い", O.YEL, 40)


def f9_parts(d, cx, yb, H, t, gap=0.0, fuelfill=False):
    """簡略図。下から 1段目(0.6)・段の継ぎ目・2段目(0.2)・フェアリング(0.15)。gap＝段を離す量(px)。"""
    w1, w2 = 78 * S, 70 * S
    h1, h2, hf = H * 0.58, H * 0.2, H * 0.16
    y1b = yb
    y1t = yb - h1
    y2b = y1t - gap
    y2t = y2b - h2
    d.rectangle([cx - w1 / 2, y1t, cx + w1 / 2, y1b], fill=(225, 228, 235), outline=O.NAVY, width=int(3 * S))
    for i in range(4):
        d.rectangle([cx - w1 / 2 + i * w1 / 4 + 3 * S, y1b, cx - w1 / 2 + (i + 1) * w1 / 4 - 3 * S, y1b + 14 * S], fill=(90, 90, 100))
    d.rectangle([cx - w2 / 2, y2t, cx + w2 / 2, y2b], fill=(200, 205, 215), outline=O.NAVY, width=int(3 * S))
    d.polygon([(cx - w2 / 2, y2t), (cx + w2 / 2, y2t), (cx + w2 * 0.38, y2t - hf * 0.6), (cx, y2t - hf), (cx - w2 * 0.38, y2t - hf * 0.6)], fill=(235, 238, 245), outline=O.NAVY)
    return (y1t, y1b, y2t, y2b, w1, w2, y2t - hf)


def sc_f9(img, box, t, k, P):
    x0, y0, x1, y1 = box
    st = P.get("stage", 0)
    grad(img, box=box)
    d = ImageDraw.Draw(img)
    H_ = (y1 - y0) - 260 * S
    yb = y1 - 110 * S
    cx = x0 + (x1 - x0) * (0.32 if LAND else 0.3)
    gap = 70 * S * _ease(k * 1.5) if st == 1 else 0.0
    y1t, y1b, y2t, y2b, w1, w2, ytop = f9_parts(d, cx, yb, H_, t, gap)
    lx = cx + 140 * S
    if st == 0:
        text(d, (lx, (y1t + y1b) / 2), "ファルコン9", 70, O.YEL, "lm", 6)
        text(d, (lx, (y1t + y1b) / 2 + 80 * S), "アメリカ　スペースX社のロケット", 38, O.WHITE, "lm", 4)
        text(d, (lx, (y1t + y1b) / 2 + 140 * S), "（簡略図）", 30, O.DIM, "lm", 3)
    elif st == 1:
        label(d, (lx + 140 * S, (y2t + y2b) / 2), "2段目（上）", 40, O.WHITE)
        label(d, (lx + 140 * S, (y1t + y1b) / 2), "1段目（下）", 40, O.WHITE)
        text(d, (lx - 20 * S, y2b + (y1t - y2b) / 2 + 0), "", 30)
        text(d, ((x0 + x1) / 2 + 200 * S, y1 - 60 * S), "燃料タンクを上下に重ねた形（簡略図）", 34, O.DIM, "mm", 3)
    else:
        # 1段目の中身: 燃料95% ＋ 空の機体5%
        d.rectangle([cx - w1 / 2, y1t, cx + w1 / 2, y1b], fill=AMBER, outline=O.NAVY, width=int(3 * S))
        eh = (y1b - y1t) * 0.05
        d.rectangle([cx - w1 / 2, y1b - eh * 3, cx + w1 / 2, y1b], fill=GREY, outline=O.NAVY, width=int(3 * S))
        label(d, (lx + 230 * S, (y1t + y1b) / 2 - 40 * S), "燃料 約95%", 40, AMBER)
        label(d, (lx + 230 * S, y1b - eh * 1.5 - 60 * S), "空の機体 約5%", 40, O.WHITE)
        text(d, (lx + 40 * S, y1t - 10 * S), "1段目の中身（公開資料から割った値）", 30, O.DIM, "lm", 3)
    head(d, box, P.get("head", "ファルコン9"), O.YEL)


def tank(d, cx, cy, w, h, wall, fill=None, gas=False, collapsed=False):
    """横から見た円筒のタンク。中心 (cx, cy)。"""
    if collapsed:
        pts = []
        for i in range(0, 21):
            u = i / 20
            x = cx - w / 2 + w * u
            pts.append((x + 6 * S * math.sin(u * 22), cy - h * 0.18 * (0.4 + 0.6 * math.sin(u * 3.14)) - 14 * S * abs(math.sin(u * 14))))
        for i in range(20, -1, -1):
            u = i / 20
            x = cx - w / 2 + w * u
            pts.append((x - 5 * S * math.sin(u * 17), cy + h * 0.18 * (0.4 + 0.6 * math.sin(u * 3.14)) + 10 * S * abs(math.sin(u * 11))))
        d.polygon(pts, fill=(120, 126, 140), outline=O.WHITE)
        for i in range(5):
            d.line([(cx - w * 0.3 + i * w * 0.15, cy - h * 0.1), (cx - w * 0.25 + i * w * 0.15, cy + h * 0.1)], fill=(70, 74, 86), width=int(3 * S))
        return
    d.rounded_rectangle([cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2], int(w * 0.35), fill=(185, 190, 200), outline=O.WHITE, width=int(max(2, wall) * S))
    d.rounded_rectangle([cx - w / 2 + wall * S, cy - h / 2 + wall * S, cx + w / 2 - wall * S, cy + h / 2 - wall * S], int(w * 0.3), fill=(22, 36, 64) if not fill else fill)
    if gas:
        import random
        rnd = random.Random(7)
        for _ in range(26):
            gx = cx + rnd.uniform(-w * 0.38, w * 0.38)
            gy = cy + rnd.uniform(-h * 0.4, h * 0.4)
            d.ellipse([gx - 5 * S, gy - 5 * S, gx + 5 * S, gy + 5 * S], fill=(190, 225, 255))


def sc_balloon(img, box, t, k, P):
    x0, y0, x1, y1 = box
    st = P.get("stage", 0)
    grad(img, box=box)
    d = ImageDraw.Draw(img)
    cy = (y0 + y1) / 2 + 30 * S
    if st == 0:
        cx = (x0 + x1) / 2 - 120 * S if LAND else x0 + 200 * S
        w, h = 240 * S, (460 if LAND else 560) * S
        tank(d, cx, cy, w, h, 6, fill=(150, 90, 30))
        d.rounded_rectangle([cx - w / 2 + 6 * S, cy - h / 2 + 6 * S, cx + w / 2 - 6 * S, cy - h * 0.1], int(w * 0.3), fill=(22, 36, 64))
        tank(d, cx, cy, w, h, 6, fill=None) if False else None
        import random
        rnd = random.Random(3)
        for _ in range(24):
            gx, gy = cx + rnd.uniform(-w * 0.38, w * 0.38), cy - h * 0.4 + rnd.uniform(0, h * 0.28)
            d.ellipse([gx - 5 * S, gy - 5 * S, gx + 5 * S, gy + 5 * S], fill=(190, 225, 255))
        lx = cx + w / 2 + 50 * S
        d.line([(cx + w / 2 - 2 * S, cy - h / 2 + 10 * S), (lx, cy - h / 2 + 30 * S)], fill=O.WHITE, width=int(3 * S))
        text(d, (lx + 8 * S, cy - h / 2 + 30 * S), "薄いステンレスの壁", 38, O.WHITE, "lm", 4)
        text(d, (lx + 8 * S, cy - h * 0.28), "窒素のガス（内側から押す）", 38, (190, 225, 255), "lm", 4)
        text(d, (lx + 8 * S, cy + h * 0.15), "燃料", 38, AMBER, "lm", 4)
        head(d, box, "風船のようなタンクの断面（簡略図）", O.YEL, 40)
    elif st == 1:
        half = (x1 - x0) / 2
        w, h = (200 if LAND else 180) * S, (320 if LAND else 400) * S
        c1, c2 = x0 + half * 0.5, x0 + half * 1.5
        tank(d, c1, cy, w, h, 6, gas=True)
        tank(d, c2, cy, w * 1.15, h, 6, collapsed=True)
        text(d, (c1, cy + h / 2 + 50 * S), "窒素で膨らませる", 40, GRN, "mm", 5)
        text(d, (c1, cy + h / 2 + 100 * S), "形を保つ", 36, O.WHITE, "mm", 4)
        text(d, (c2, cy + h / 2 + 50 * S), "空のまま", 40, RED_, "mm", 5)
        text(d, (c2, cy + h / 2 + 100 * S), "自分の重さでつぶれる", 36, O.WHITE, "mm", 4)
        head(d, box, "空でも、ガスで膨らませないと…", O.YEL, 40)
    else:
        cx = (x0 + x1) / 2 - 60 * S
        H_ = (y1 - y0) - 280 * S
        yb = y1 - 110 * S
        mw = 80 * S
        body(d, cx, yb, mw, H_ * 0.8, (205, 210, 220), nose=0.2, outline=O.NAVY)
        for sx in (-1, 1):
            bx = cx + sx * (mw / 2 + 36 * S)
            body(d, bx, yb, 52 * S, H_ * 0.32, AMBER, nose=0.1, outline=O.NAVY)
        label(d, (cx + 420 * S, yb - H_ * 0.12) if LAND else (cx, yb + 55 * S), "横の補助エンジン＝ブースター", 34, AMBER)
        label(d, (cx + 330 * S, yb - H_ * 0.52), "本体（風船のタンク）", 34, O.WHITE)
        text(d, (cx + 330 * S, yb - H_ * 0.9), "途中で捨てる形＝1.5段式", 36, O.YEL, "mm", 4)
        head(d, box, "アトラス（簡略図）", O.YEL)


def sc_growtank(img, box, t, k, P):
    x0, y0, x1, y1 = box
    grad(img, box=box)
    d = ImageDraw.Draw(img)
    u = _ease(k * 1.4)
    cy = (y0 + y1) / 2 + 20 * S
    c1, c2 = x0 + (x1 - x0) * (0.25 if LAND else 0.2), x0 + (x1 - x0) * (0.72 if LAND else 0.74)
    for cx, w, h, wall, nm in ((c1, 150 * S, 250 * S, 6, "いまのタンク"), (c2, 150 * S + 130 * S * u, 250 * S + 190 * S * u, 6 + 6 * u, "燃料を増やしたタンク")):
        tank(d, cx, cy, w, h, wall, fill=(150, 90, 30))
        eh = h * 0.0465
        d.rectangle([cx - w / 2 + 6 * S, cy + h / 2 - 6 * S - eh * 2.2, cx + w / 2 - 6 * S, cy + h / 2 - 6 * S], fill=GREY)
        text(d, (cx, cy + h / 2 + 40 * S), nm, 36, O.WHITE, "mm", 4)
        text(d, (cx, cy + h / 2 + 90 * S), "空の機体 4.65%", 36, O.YEL, "mm", 4)
    arrow(d, c1 + 130 * S, cy, c2 - 190 * S, cy, 14 * S, O.YEL)
    text(d, ((c1 + c2) / 2 - (0 if LAND else 70 * S), cy - 70 * S), "入れ物も大きく、重く", 34 if LAND else 30, O.WHITE, "mm", 4)
    head(d, box, "燃料が増えれば、タンクも増える", O.YEL, 40)


def sc_limit(img, box, t, k, P):
    x0, y0, x1, y1 = box
    grad(img, box=box)
    d = ImageDraw.Draw(img)
    gx0, gx1 = x0 + 150 * S, x1 - 80 * S
    gy0, gy1 = y0 + 190 * S, y1 - 120 * S
    px = lambda f: gx0 + (gx1 - gx0) * f / 1.7
    py = lambda r: gy1 - (gy1 - gy0) * r / 36.0
    d.line([(gx0, gy1), (gx1, gy1)], fill=O.DIM, width=int(3 * S))
    d.line([(gx0, gy0), (gx0, gy1)], fill=O.DIM, width=int(3 * S))
    for r in (0, 10, 20, 30):
        text(d, (gx0 - 14 * S, py(r)), f"{r}", 28, O.DIM, "rm", 3)
    text(d, (gx0, gy0 - 40 * S), "倍率", 30, O.DIM, "la", 3)
    text(d, (gx1, gy1 + 24 * S), "燃料を増やす →", 30, O.DIM, "ra", 3)
    u = _ease(k * 1.4)
    n = 40
    f_end = 0.3 + (1.7 - 0.3) * u
    pa = [(px(0.3 + (f_end - 0.3) * i / n), py(1 + 20.5 * (0.3 + (f_end - 0.3) * i / n))) for i in range(n + 1)]
    d.line(pa, fill=BLU, width=int(7 * S))
    pb = [(px(0.3), py(21.5)), (px(f_end), py(21.5))]
    d.line(pb, fill=O.YEL, width=int(8 * S))
    xn = py(24.4)
    dashed(d, (gx0, xn), (gx1, xn), O.RED, 4)
    text(d, (gx1, xn - 12 * S), "必要 約24倍", 32, O.RED, "rd", 4)
    label(d, (gx0 + (gx1 - gx0) * 0.30, py(33)), "タンクはそのまま燃料だけ足せたら", 30, BLU)
    label(d, (gx0 + (gx1 - gx0) * 0.62, py(15)), "現実：約21.5倍で頭打ち（100÷4.65）", 30, O.YEL)
    head(d, box, "燃料を足しても、倍率は上がらない", O.YEL, 40)


def sc_compound(img, box, t, k, P):
    x0, y0, x1, y1 = box
    grad(img, box=box)
    d = ImageDraw.Draw(img)
    base = y1 - 150 * S
    Ht = base - y0 - 260 * S
    vals = [(9.0, 21.5), (10.0, 30.2), (11.0, 42.4)]
    n = 3
    slot = (x1 - x0) / n
    bw = slot * 0.4
    for i, (v, r) in enumerate(vals):
        u = _ease(k * 2.2 - 0.5 * i)
        cx = x0 + slot * (i + 0.5)
        h = Ht * r / 42.4 * u
        d.rectangle([cx - bw / 2, base - h, cx + bw / 2, base], fill=[AMBER, (240, 130, 70), RED_][i], outline=O.NAVY, width=int(3 * S))
        if u > 0.6:
            text(d, (cx, base - h - 26 * S), f"約{r:.0f}倍" if i else "約21.5倍", 42, O.WHITE, "md", 5)
        text(d, (cx, base + 16 * S), f"速さ {v:.1f}km/s", 36, O.WHITE, "ma", 4)
        if i:
            text(d, (cx - slot * 0.5, base - Ht * 0.55), "×1.4", 56, O.YEL, "mm", 6)
    head(d, box, "速さを1km/s足すたび、倍率は約1.4倍", O.YEL, 40)


def sc_fails(img, box, t, k, P):
    x0, y0, x1, y1 = box
    grad(img, box=box)
    d = ImageDraw.Draw(img)
    items = [("実験1", "1つの機体で打つ"), ("実験2", "限界まで軽くする"), ("実験3", "燃料を増やす")]
    for i, (a, b) in enumerate(items):
        u = _ease(k * 3.2 - i)
        if u <= 0:
            continue
        if LAND:
            w = (x1 - x0 - 160 * S) / 3
            bx0 = x0 + 40 * S + i * (w + 40 * S)
            by0, by1 = y0 + 200 * S, y1 - 120 * S
        else:
            h = (y1 - y0 - 330 * S) / 3
            bx0, w = x0 + 60 * S, x1 - x0 - 120 * S
            by0 = y0 + 190 * S + i * (h + 20 * S)
            by1 = by0 + h
        d.rounded_rectangle([bx0, by0, bx0 + w, by1], int(24 * S), fill=(40, 20, 28), outline=RED_, width=int(8 * S))
        text(d, (bx0 + w / 2, by0 + (by1 - by0) * 0.2), a, 50, O.WHITE, "mm", 5)
        text(d, (bx0 + w / 2, by0 + (by1 - by0) * 0.5), "失敗", 110, RED_, "mm", 7)
        vtext(d, (bx0 + w / 2, by0 + (by1 - by0) * 0.8), b, 38, O.WHITE, "mm", maxw=w - 30 * S)
    head(d, box, "3回続けて、失敗", O.YEL)


def sc_alt(img, box, t, k, P):
    x0, y0, x1, y1 = box
    st = P.get("stage", 0)
    grad(img, box=box)
    d = ImageDraw.Draw(img)
    base = y1 - 150 * S
    Ht = base - y0 - 200 * S
    u = _ease(k * 1.4)
    items = [("軌道の高さ", 200, "約200km", BLU)]
    items.append(("DC-X", 2.5, "最高 約2.5km", AMBER))
    if st >= 1:
        items.append(("DC-XA", 3.1, "約3.1km", GRN))
    n = len(items)
    slot = (x1 - x0) / 3
    for i, (nm, v, txt, col) in enumerate(items):
        cx = x0 + slot * (i + 0.5)
        h = max(7 * S, Ht * v / 200.0) * u
        d.rectangle([cx - 70 * S, base - h, cx + 70 * S, base], fill=col, outline=O.NAVY, width=int(3 * S))
        text(d, (cx, base + 18 * S), nm, 40, O.WHITE, "ma", 4)
        text(d, (cx, base - h - 24 * S), txt, 38, O.WHITE, "md", 4)
    if st >= 1 and u > 0.8:
        label(d, (x0 + slot * 2.0, base - Ht * 0.45), "軌道の高さの 約60分の1", 40, O.YEL)
    head(d, box, "1段式の試作機が上がった高さ", O.YEL, 40)


def sc_xfig(img, box, t, k, P):
    x0, y0, x1, y1 = box
    grad(img, box=box)
    d = ImageDraw.Draw(img)
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2 - 20 * S
    w = min(x1 - x0 - 200 * S, 760 * S)
    # くさび形の機体(簡略)
    pts = [(cx - w / 2, cy), (cx + w * 0.1, cy - 90 * S), (cx + w / 2, cy - 70 * S), (cx + w / 2, cy + 70 * S), (cx + w * 0.1, cy + 90 * S)]
    d.polygon(pts, fill=(205, 210, 220), outline=O.WHITE)
    d.polygon([(cx + w * 0.2, cy - 80 * S), (cx + w * 0.42, cy - 190 * S), (cx + w / 2, cy - 70 * S)], fill=(170, 176, 190))
    d.polygon([(cx + w * 0.2, cy + 80 * S), (cx + w * 0.42, cy + 190 * S), (cx + w / 2, cy + 70 * S)], fill=(170, 176, 190))
    flame(d, cx + w / 2, cy, 80 * S, t, 0) if False else None
    text(d, (cx, cy + 250 * S), "X-33　水素の1段式の宇宙船の、小さな試験機", fitsize("X-33　水素の1段式の宇宙船の、小さな試験機", 40, x1 - x0 - 60 * S), O.WHITE, "mm", 5)
    text(d, (cx, cy + 310 * S), "実機の計画名は ベンチャースター（簡略図）", fitsize("実機の計画名は ベンチャースター（簡略図）", 36, x1 - x0 - 60 * S), O.DIM, "mm", 4)
    head(d, box, "X-33（1996年に受注）", O.YEL)


def sc_tl(img, box, t, k, P):
    """items=[(年, 文)]、cur＝いま話している行(0 始まり)。そこまでを出し、いまを黄色にする。"""
    x0, y0, x1, y1 = box
    grad(img, box=box)
    d = ImageDraw.Draw(img)
    items = P["items"]
    cur = P["cur"]
    n = len(items)
    top = y0 + (140 if LAND else 220) * S
    step = min(80 * S, (y1 - top - 40 * S) / n)
    xl = x0 + 80 * S
    d.line([(xl + 130 * S, top), (xl + 130 * S, top + step * (n - 1))], fill=O.DIM, width=int(4 * S))
    for i, (yr, s) in enumerate(items):
        if i > cur:
            break
        y = top + step * i
        on = i == cur
        col = O.YEL if on else O.DIM
        text(d, (xl + 110 * S, y), yr, 40 if on else 34, col, "rm", 4)
        d.ellipse([xl + 130 * S - 11 * S, y - 11 * S, xl + 130 * S + 11 * S, y + 11 * S], fill=col)
        vtext(d, (xl + 165 * S, y), s, 40 if on else 34, O.WHITE if on else O.DIM, "lm", maxw=x1 - xl - 190 * S)
    if P.get("big"):
        label(d, ((x0 + x1) / 2, y1 - 60 * S), P["big"], 44, O.YEL)
    head(d, box, P.get("head", "1段で軌道を目指した試み"), O.YEL, 40)


def sc_stages(img, box, t, k, P):
    """mode: cut＝切り離しの図 / single＝1つの機体 / drop＝使い終わった段を捨てる。"""
    x0, y0, x1, y1 = box
    mode = P.get("mode", "cut")
    grad(img, box=box)
    d = ImageDraw.Draw(img)
    u = _ease(k * 1.4)
    H_ = (y1 - y0) - 300 * S
    yb = y1 - 150 * S
    cx = x0 + (x1 - x0) * (0.3 if LAND else 0.32)
    w = 90 * S
    if mode == "single":
        body(d, cx, yb, w, H_, (215, 220, 230), nose=0.14, fins=0.1, outline=O.NAVY)
        flame(d, cx, yb, w, t)
        text(d, (cx + 120 * S, yb - H_ * 0.5), "段を捨てない　1つの機体", 44, O.YEL, "lm", 5)
        head(d, box, "もし、1つの機体で行けたら", O.YEL)
        return
    sep = 0 if mode == "cut" and k < 0.25 else (120 * S * _ease((k - 0.25) * 1.3 if mode == "cut" else k * 1.2))
    drop = 90 * S * _ease(k * 1.2) if mode == "drop" else sep
    lowh = H_ * 0.55
    uph = H_ * 0.45
    # 下の段
    ylow_b = yb + drop * 1.0
    d.rectangle([cx - w / 2, ylow_b - lowh, cx + w / 2, ylow_b], fill=(150, 156, 170) if mode != "drop" else mix((150, 156, 170), BG1, 1 - 0.5 * (1 - u)), outline=O.NAVY, width=int(3 * S))
    # 上の段
    yup_b = yb - lowh - sep * 0.2 - (60 * S * u if mode == "drop" else 0)
    body(d, cx, yup_b, w * 0.86, uph, (215, 220, 230), nose=0.2, outline=O.NAVY)
    flame(d, cx, yup_b, w * 0.86, t)
    lx = cx + 120 * S
    label(d, (lx + 150 * S, yup_b - uph * 0.5), "上の段（まだ燃えている）" if mode == "drop" else "2段目（上）", 36, O.WHITE)
    label(d, (lx + 150 * S, ylow_b - lowh * 0.5), "燃料を使い切った段を切り離す" if mode == "drop" else "1段目（下）", 36, O.YEL if mode == "drop" else O.WHITE)
    if mode == "cut":
        text(d, (lx + 150 * S, yb - H_ * 0.5 - lowh * 0.0 + 0), "", 30)
        text(d, (cx + 150 * S, y0 + (y1 - y0) * 0.5), "この区切りを「段」という", 44, O.YEL, "lm", 5)
    if P.get("note"):
        text(d, (lx + 80 * S, y0 + (y1 - y0) * 0.5), P["note"], 40, O.YEL, "lm", 5)
    head(d, box, P.get("head", "段"), O.YEL)


KINDS = dict(formula=sc_formula, bars=sc_bars, stack=sc_stack, cargo=sc_cargo, speedo=sc_speedo, range=sc_range, hstack=sc_hstack,
             orbit=sc_orbit, route=sc_route, rotation=sc_rotation, kg=sc_kg, massfig=sc_massfig, ratio=sc_ratio, ton=sc_ton, f9=sc_f9,
             balloon=sc_balloon, growtank=sc_growtank, limit=sc_limit, compound=sc_compound, fails=sc_fails, alt=sc_alt, xfig=sc_xfig,
             tl=sc_tl, stages=sc_stages)


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
    """大きな「失敗」(赤)・「成功」(緑)・「ほぼ失敗」(橙)の札。u=0→1 で、大きく出てすっと落ち着く。"""
    s, col = {"fail": ("失敗", O.RED), "ok": ("成功", O.GREEN), "almost": ("ほぼ失敗", ORG)}[kind]
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

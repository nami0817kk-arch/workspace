"""宇宙エレベーターの回(計算の回)の画面。行の scene=dict(kind=…) を描く(無い行は前の行を引き継ぐ)。
場面が変わると 0.5 秒で溶け合わせる。作品・実機の写真は使わない。図は全部コードで描く(AI 絵は作らない)。
数字の出どころは research.md。台本は scripts.md。
kind: formula(札) / meter(切れる長さの横棒) / table(○×の表) / cable(地球とケーブル) / gcurve(重力・遠心力・差を足す図) /
      taper(先細りの図) / hang(糸を垂らす) / loop(山手線) / wire(針金の断面) / twothread(太さを変える) /
      big(大きな数字と0の並び) / areas(箱の大きさ比べ) / lattice(原子の筒・膜) / flaw(欠けのある糸)
"""
from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw

from naze import mapscene, overlay as O
from naze.config import H, W

LAND = W > H
S = min(W, H) / 1080
COLS = dict(dim=O.DIM, white=O.WHITE, yel=O.YEL, red=O.RED, green=O.GREEN)
BG0, BG1 = (10, 18, 40), (16, 30, 62)
TAGGED = [False]   # 縦で「実験N」の札が左上に出ている間は、上の見出しを下げる

AMBER = (240, 170, 70)
GREY = (170, 178, 192)
GRN = (110, 220, 140)
BLU = (90, 170, 235)
RED_ = (240, 90, 80)
ORG = (240, 150, 40)
TEAL = (80, 210, 190)
VIO = (185, 140, 245)
COLS["orange"] = ORG


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


def mix(c, bg, a):
    return tuple(int(c[i] * a + bg[i] * (1 - a)) for i in range(3))


def fitsize(s, size, maxw):
    sz = size
    while O.font(int(sz * S)).getlength(s) > maxw and sz > 22:
        sz -= 2
    return sz


def vtext(d, xy, s, size, col=O.WHITE, anchor="mm", maxw=None, stroke=4):
    if maxw:
        size = fitsize(s, size, maxw)
    text(d, xy, s, size, col, anchor, stroke)


def dashed(d, p0, p1, col, w=3, dash=14):
    x0, y0 = p0
    x1, y1 = p1
    L = math.hypot(x1 - x0, y1 - y0)
    n = max(1, int(L / (dash * S)))
    for i in range(0, n, 2):
        a, b = i / n, min(1.0, (i + 1) / n)
        d.line([(x0 + (x1 - x0) * a, y0 + (y1 - y0) * a), (x0 + (x1 - x0) * b, y0 + (y1 - y0) * b)], fill=col, width=max(2, int(w * S)))


# ---- 物理(静止軌道・重力・遠心力) --------------------------------------------------------------
GM, OM, RE, G0 = 3.986004418e14, 7.2921159e-5, 6378137.0, 9.80665
RG = (GM / OM ** 2) ** (1 / 3)
HG = (RG - RE) / 1e3                    # 静止軌道の高さ(km) 約35,786


def g_rel(h):                           # 重力(地上を1とする)
    r = RE + h * 1e3
    return GM / r ** 2 / G0


def c_rel(h):                           # 遠心力
    r = RE + h * 1e3
    return OM ** 2 * r / G0


def net_rel(h):
    return g_rel(h) - c_rel(h)


_NF = 400
_HS = [HG * i / _NF for i in range(_NF + 1)]
_CUM = [0.0]
for _i in range(_NF):
    _CUM.append(_CUM[-1] + (net_rel(_HS[_i]) + net_rel(_HS[_i + 1])) / 2 * (_HS[_i + 1] - _HS[_i]))
SUM_KM = _CUM[-1]                       # 約4,938km(台本は約4,940km)


# ---- 横棒(切れる長さ) -----------------------------------------------------------------------

def bars(d, box, rows, vmax, k=1.0, marks=(), names_above=None):
    """rows = [(名前, 値, None, 数字の札, 色)]。marks = [(値, 札, 色)] は縦の目印(札は線の左側に置く)。"""
    x0, y0, x1, y1 = box
    na = (not LAND) if names_above is None else names_above
    ya = y0 + ((210 if not LAND else 130) + (50 if marks else 0)) * S
    n = len(rows)
    rh = min((200 if not na else 230) * S, (y1 - 50 * S - ya) / n)
    ya = max(ya, ya + ((y1 - 50 * S - ya) - rh * n) * 0.4)
    gx0 = x0 + 50 * S if na else x0 + (x1 - x0) * 0.34
    gx1 = x1 - 50 * S
    px = lambda v: gx0 + (gx1 - gx0) * min(v, vmax) / vmax
    bh = rh * (0.3 if na else 0.44)
    f = O.font(int(36 * S))
    for i, (name, lo, hi, txt, col) in enumerate(rows):
        a = _ease(k * 3.2 - 0.25 * i)
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
        end = px(lo)
        e = gx0 + max(8 * S, (end - gx0)) * a
        d.rectangle([gx0, cy - bh / 2, e, cy + bh / 2], fill=col)
        tw = f.getlength(txt)
        if a > 0.6:
            if e + 14 * S + tw > x1 - 20 * S:
                text(d, (e - 14 * S, cy), txt, 36, O.NAVY if col != GREY else O.NAVY, "rm", 0)
            else:
                text(d, (e + 14 * S, cy), txt, 36, O.WHITE, "lm", 4)
    for j, (v, s, col) in enumerate(marks):
        xm = px(v)
        d.line([(xm, ya - 6 * S), (xm, ya + rh * n)], fill=col, width=max(2, int(4 * S)))
        sz = fitsize(s, 32, (x1 - x0) - 60 * S)
        tw = O.font(int(sz * S)).getlength(s)
        yy = ya - 14 * S - j * 44 * S
        if xm - tw - 10 * S < x0 + 10 * S:
            text(d, (xm + 12 * S, yy), s, sz, col, "ld", 4)
        else:
            text(d, (xm - 12 * S, yy), s, sz, col, "rd", 4)


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


def sc_meter(img, box, t, k, P):
    """切れる長さの横棒。rows・marks・note(下の赤い札)。done=True なら伸び終わった形で出す。"""
    grad(img, box=box)
    x0, y0, x1, y1 = box
    d = ImageDraw.Draw(img)
    note = P.get("note")
    bb = (x0, y0, x1, y1 - (90 * S if note else 0))
    bars(d, bb, P["rows"], P.get("vmax", 7000), 1.0 if P.get("done") else k, P.get("marks", ()))
    if P.get("head"):
        head(d, box, P["head"], O.YEL)
    if note:
        label(d, ((x0 + x1) / 2, y1 - 42 * S), note, 40, P.get("ncol", O.RED))
    if P.get("foot"):
        text(d, ((x0 + x1) / 2, y1 - 8 * S), P["foot"], 26, O.DIM, "md", 3)


def sc_table(img, box, t, k, P):
    """rows = [(札, 名前, 印, 説明)]。印は × ○ △ ？。old 行目までは最初から出す。"""
    grad(img, box=box)
    x0, y0, x1, y1 = box
    d = ImageDraw.Draw(img)
    rows = P["rows"]
    n = len(rows)
    rh = min(100 * S, (y1 - y0 - 200 * S) / max(n, 1))
    top = y0 + 150 * S
    w = x1 - x0
    cx_tag, cx_name, cx_mark, cx_det = x0 + 40 * S, x0 + w * 0.15, x0 + w * 0.56, x0 + w * 0.62
    text(d, (cx_mark, top - 40 * S), "判定", 34, O.DIM, "mm", 3)
    old = P.get("old", 0)
    mark_col = {"×": O.RED, "○": O.GREEN, "△": O.YEL, "？": O.DIM}
    for i, (tag, name, mk, det) in enumerate(rows):
        a = 1.0 if i < old else _ease(k * (n - old) * 1.3 - (i - old))
        if a <= 0:
            continue
        cy = top + rh * (i + 0.5)
        d.rounded_rectangle([x0 + 20 * S, cy - rh * 0.44, x1 - 20 * S, cy + rh * 0.44], int(12 * S), fill=mix((30, 44, 78), BG1, a), outline=mix(O.DIM, BG1, 0.4 * a), width=max(2, int(2 * S)))
        if tag:
            text(d, (cx_tag, cy), tag, 36, O.YEL, "lm", 4)
        vtext(d, (cx_name, cy), name, 38, O.WHITE, "lm", maxw=cx_mark - cx_name - 50 * S)
        text(d, (cx_mark, cy), mk, 64, mark_col[mk], "mm", 5)
        vtext(d, (cx_det, cy), det, 36, O.WHITE, "lm", maxw=x1 - cx_det - 40 * S)
    head(d, box, P.get("head", "実験の結果"), O.YEL)


# ---- 地球とケーブル -------------------------------------------------------------------------------

def earth(d, cx, cy, r):
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(40, 105, 185))
    for dx, dy, rx, ry in ((-0.3, -0.25, 0.28, 0.2), (0.25, 0.1, 0.22, 0.28), (-0.15, 0.4, 0.18, 0.12)):
        d.ellipse([cx + (dx - rx) * r, cy + (dy - ry) * r, cx + (dx + rx) * r, cy + (dy + ry) * r], fill=(70, 150, 90))
    d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=(150, 205, 250), width=max(2, int(3 * S)))


def sc_cable(img, box, t, k, P):
    """stage 0=地球からケーブル 1=静止軌道と高さ 2=赤道の上に真上に1本。縮尺どおり(高さは地球の半径の約5.6倍)。"""
    x0, y0, x1, y1 = box
    st = P.get("stage", 0)
    grad(img, (6, 10, 28), (12, 22, 50), box)
    d = ImageDraw.Draw(img)
    avail = (y1 - y0) - 200 * S
    r = avail / 7.6
    cx = x0 + (x1 - x0) * (0.30 if LAND else 0.42)
    cy = y1 - 60 * S - r
    earth(d, cx, cy, r)
    text(d, (cx, cy + r * 0.2), "地球", 36, O.WHITE, "mm", 4)
    top = cy - r
    geo_y = top - 5.6 * r
    u = _ease(k * 1.6) if not P.get("still") else 1.0
    ey = top - (top - geo_y) * u
    Rg = 6.6 * r
    if st >= 1:
        d.arc([cx - Rg, cy - Rg, cx + Rg, cy + Rg], (232 if LAND else 242), (308 if LAND else 298), fill=mix(O.YEL, BG1, 0.6), width=max(2, int(3 * S)))
    d.line([(cx, top), (cx, ey)], fill=O.WHITE, width=max(3, int(6 * S)))
    if u > 0.95:
        d.rectangle([cx - 26 * S, geo_y - 12 * S, cx + 26 * S, geo_y + 12 * S], fill=O.YEL, outline=O.NAVY, width=int(2 * S))
    tx = cx + (330 if LAND else 120) * S
    mid = (top + geo_y) / 2
    mw = x1 - tx - 30 * S
    if st == 0:
        vtext(d, (tx, mid), "地球から宇宙へ", 54, O.WHITE, "lm", maxw=mw)
        vtext(d, (tx, mid + 70 * S), "ケーブルを伸ばす構想", 54, O.WHITE, "lm", maxw=mw)
    if st >= 1 and u > 0.9:
        vtext(d, (tx, geo_y + 10 * S), "静止軌道", 80, O.YEL, "lm", maxw=mw)
        vtext(d, (tx, geo_y + 90 * S), "地球の自転と同じ周期で回る", 40, O.WHITE, "lm", maxw=mw)
        vtext(d, (tx, geo_y + 140 * S), "真上に止まって見える場所", 40, O.WHITE, "lm", maxw=mw)
        dx = cx - 90 * S
        d.line([(dx, top), (dx, geo_y)], fill=O.YEL, width=max(2, int(4 * S)))
        for yy in (top, geo_y):
            d.line([(dx - 14 * S, yy), (dx + 14 * S, yy)], fill=O.YEL, width=max(2, int(4 * S)))
        text(d, (dx - 22 * S, mid), "高さ", 40, O.YEL, "rm", 4)
        text(d, (dx - 22 * S, mid + 52 * S), "約3万6千km", 40, O.YEL, "rm", 4)
    if st == 2:
        label(d, (cx + r * 0.95, top + r * 0.55), "赤道", 36, O.WHITE, "lm")
        vtext(d, (tx, mid + 160 * S), "赤道の上に、真上に1本", 46, O.WHITE, "lm", maxw=mw)
    text(d, ((x0 + x1) / 2, y1 - 14 * S), "高さと地球の大きさは縮尺どおり　ケーブルは線で描いています", 26, O.DIM, "md", 3)
    if P.get("head"):
        head(d, box, P["head"], O.YEL)


# ---- 重力・遠心力・差を足す図 ------------------------------------------------------------------

def sc_gcurve(img, box, t, k, P):
    """stage 0=地上の重力のままなら(長方形) 1=重力 2=遠心力を足す 3=静止軌道で同じ 4=差を足す 5=7分の1。"""
    grad(img, box=box)
    x0, y0, x1, y1 = box
    d = ImageDraw.Draw(img)
    st = P["stage"]
    gx0, gx1 = x0 + (210 if LAND else 130) * S, x1 - 70 * S
    gy0, gy1 = y0 + 190 * S, y1 - 120 * S
    px = lambda h: gx0 + (gx1 - gx0) * h / HG
    py = lambda v: gy1 - (gy1 - gy0) * v
    d.line([(gx0, gy1), (gx1, gy1)], fill=O.WHITE, width=max(2, int(4 * S)))
    d.line([(gx0, gy0), (gx0, gy1)], fill=O.WHITE, width=max(2, int(4 * S)))
    text(d, (gx0, gy1 + 22 * S), "地上", 32, O.DIM, "ma", 3)
    text(d, (gx1, gy1 + 22 * S), "静止軌道（約3万6千km）", 32, O.DIM, "ra", 3)
    text(d, (gx0 - 16 * S, gy0), "1", 32, O.DIM, "rm", 3)
    text(d, (gx0 - 16 * S, gy1), "0", 32, O.DIM, "rm", 3)
    text(d, (gx0 - 16 * S, (gy0 + gy1) / 2), "力", 32, O.DIM, "rm", 3)
    text(d, (gx0 + 10 * S, gy0 - 36 * S), "地上の重力を1とする", 28, O.DIM, "la", 3)
    npts = 120
    hs = [HG * i / npts for i in range(npts + 1)]
    if st == 0:
        d.rectangle([gx0, gy0, gx1, gy1], outline=O.YEL, width=max(2, int(3 * S)), fill=mix(O.YEL, BG1, 0.25))
        label(d, ((gx0 + gx1) / 2, (gy0 + gy1) / 2), "地上の重力のままなら　3万6千kmぶんの重さ", 40, O.YEL)
        head(d, box, "ケーブルにかかる力", O.YEL)
        return
    if st >= 4:
        kk = _ease(k * 1.3) if st == 4 and not P.get("done") else 1.0
        hk = HG * kk
        pts = [(px(h), py(net_rel(h))) for h in hs if h <= hk]
        if len(pts) >= 2:
            d.polygon([(px(0), gy1)] + pts + [(pts[-1][0], gy1)], fill=mix(O.YEL, BG1, 0.45))
        dashed(d, (gx0, gy0), (gx1, gy0), O.DIM, 3)
        dashed(d, (gx1, gy0), (gx1, gy1), O.DIM, 3)
    gp = [(px(h), py(g_rel(h))) for h in hs]
    cp = [(px(h), py(c_rel(h))) for h in hs]
    d.line(gp, fill=BLU, width=max(3, int(6 * S)))
    if st >= 2:
        d.line(cp, fill=ORG, width=max(3, int(6 * S)))
    if st >= 4:
        np_ = [(px(h), py(net_rel(h))) for h in hs]
        d.line(np_, fill=GRN, width=max(3, int(7 * S)))
    # 札
    if st == 1:
        label(d, (px(HG * 0.22), py(0.62)), "重力　上へ行くほど弱くなる", 38, BLU, "lm")
        d.ellipse([gx1 - 12 * S, py(g_rel(HG)) - 12 * S, gx1 + 12 * S, py(g_rel(HG)) + 12 * S], outline=BLU, width=int(4 * S))
        label(d, (gx1 - 20 * S, py(0.25)), "静止軌道では地上の約2%", 38, BLU, "rm")
    if st == 2:
        label(d, (px(HG * 0.22), py(0.62)), "重力", 38, BLU, "lm")
        label(d, (px(HG * 0.5), py(0.22)), "遠心力　外へ振り回す力", 38, ORG, "lm")
    if st == 3:
        label(d, (px(HG * 0.22), py(0.62)), "重力", 38, BLU, "lm")
        label(d, (px(HG * 0.42), py(0.30)), "遠心力", 38, ORG, "lm")
        d.ellipse([gx1 - 16 * S, py(g_rel(HG)) - 16 * S, gx1 + 16 * S, py(g_rel(HG)) + 16 * S], outline=O.YEL, width=int(5 * S))
        label(d, (gx1 - 30 * S, py(0.50)), "静止軌道では同じ強さ　打ち消し合う", 38, O.YEL, "rm")
    if st >= 4:
        label(d, (px(HG * 0.30), py(0.78)), "重力と遠心力の差を足す", 36, GRN, "lm")
        label(d, (px(HG * 0.34), py(0.46)), "色の面積 ＝ 約4,940kmぶん", 38, O.YEL, "lm")
        label(d, (px(HG * 0.62), py(0.92)), "全部が地上の重力なら　3万6千kmぶん", 32, O.DIM, "mm")
    if st == 5:
        label(d, (px(HG * 0.5), py(0.17)), "3万6千kmの　約7分の1", 46, O.YEL)
    head(d, box, "ケーブルにかかる力", O.YEL)


# ---- 先細りの図 ---------------------------------------------------------------------------------

def sc_taper(img, box, t, k, P):
    """断面積の倍率 ratio(上/地上)で、地上から静止軌道までの太さ(=断面積)を描く。左に太さ一定の線。"""
    grad(img, box=box)
    x0, y0, x1, y1 = box
    d = ImageDraw.Draw(img)
    r = P.get("ratio", 10)
    top, bot = y0 + 200 * S, y1 - 90 * S
    cx = x0 + (x1 - x0) * (0.40 if LAND else 0.42)
    w0 = 26 * S
    half = lambda a: w0 * a / 2
    u = _ease(k * 1.4)
    n = 80
    ys = [bot + (top - bot) * i / n * u for i in range(n + 1)]
    A = [math.exp(_CUM[min(_NF, int(i / n * _NF))] / SUM_KM * math.log(r)) for i in range(n + 1)]
    left = [(cx - half(a), y) for a, y in zip(A, ys)]
    right = [(cx + half(a), y) for a, y in zip(A, ys)]
    d.polygon(left + right[::-1], fill=mix(GRN, BG1, 0.9), outline=O.WHITE)
    # 太さ一定(比べる線)
    dx = cx - (w0 * r / 2 + 70 * S)
    d.rectangle([dx - w0 / 2, top, dx + w0 / 2, bot], outline=O.DIM, width=max(2, int(3 * S)))
    text(d, (dx, top - 24 * S), "太さ一定", 30, O.DIM, "md", 3)
    d.line([(x0 + 60 * S, bot), (x1 - 60 * S, bot)], fill=O.WHITE, width=max(2, int(4 * S)))
    text(d, (cx, bot + 14 * S), "地上", 32, O.WHITE, "ma", 4)
    tx = cx + w0 * r / 2 + 50 * S
    mw = x1 - tx - 30 * S
    if u > 0.9:
        text(d, (cx, top - 24 * S), "静止軌道", 32, O.WHITE, "md", 4)
        vtext(d, (tx, (top + bot) / 2 - 60 * S), "上ほど太く", 56, O.YEL, "lm", maxw=mw)
        vtext(d, (tx, (top + bot) / 2 + 10 * S), "下の全部の重さを支える", 40, O.WHITE, "lm", maxw=mw)
        if P.get("frame"):
            vtext(d, (tx, (top + bot) / 2 + 80 * S), "枠　上の断面積は地上の10倍まで", 40, O.YEL, "lm", maxw=mw)
    head(d, box, P.get("head", "先細り（テーパー）"), O.YEL)


# ---- 糸を垂らす・山手線・針金・太さを変える -----------------------------------------------------

def sc_hang(img, box, t, k, P):
    grad(img, box=box)
    x0, y0, x1, y1 = box
    d = ImageDraw.Draw(img)
    cx = (x0 + x1) / 2 - 200 * S if LAND else x0 + (x1 - x0) * 0.2
    ty, by = y0 + 130 * S, y1 - 90 * S
    d.rectangle([cx - 160 * S, ty - 26 * S, cx + 160 * S, ty], fill=GREY)
    for i in range(-6, 7):
        d.line([(cx + i * 24 * S, ty - 26 * S), (cx + i * 24 * S - 14 * S, ty - 40 * S)], fill=GREY, width=max(2, int(3 * S)))
    u = _ease(k * 1.5)
    brk = ty + (by - ty) * 0.62
    ey = ty + (brk - ty) * min(1.0, u * 1.3)
    d.line([(cx, ty), (cx, ey)], fill=O.WHITE, width=max(3, int(6 * S)))
    if u >= 0.77:
        f = _ease((u - 0.77) / 0.23)
        d.line([(cx - 14 * S, brk), (cx + 14 * S, brk + 8 * S)], fill=O.RED, width=max(3, int(5 * S)))
        fall = f * 150 * S
        d.line([(cx + 10 * S, brk + 14 * S + fall), (cx + 36 * S, brk + 14 * S + fall + 150 * S * 0.8)], fill=mix(O.WHITE, BG1, 0.7), width=max(3, int(6 * S)))
        label(d, (cx + 80 * S, brk), "ここで、自分の重さで切れる", 40, O.RED, "lm")
    tx = cx + 130 * S
    text(d, (tx, ty + 70 * S), P.get("name", "鋼のケーブル"), 56, O.WHITE, "lm", 5)
    text(d, (tx, ty + 140 * S), P.get("val", "約23km"), 90, O.YEL, "lm", 7)
    text(d, ((x0 + x1) / 2, y1 - 14 * S), "図は長さを縮めて描いています", 26, O.DIM, "md", 3)
    head(d, box, "同じ素材の糸を上から垂らす", O.YEL)


def sc_loop(img, box, t, k, P):
    grad(img, box=box)
    x0, y0, x1, y1 = box
    d = ImageDraw.Draw(img)
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2 + 20 * S
    rx = (330 if LAND else 360) * S
    ry = (210 if LAND else 270) * S
    bb = [cx - rx, cy - ry, cx + rx, cy + ry]
    d.arc(bb, 0, 360, fill=(60, 80, 120), width=int(26 * S))
    u = _ease(k * 1.5)
    a1 = -90 + 241 * u
    d.arc(bb, -90, a1, fill=O.YEL, width=int(26 * S))
    text(d, (cx, cy - 30 * S), "山手線　1周", 50, O.WHITE, "mm", 5)
    text(d, (cx, cy + 40 * S), "約23kmは、これより短い", 38, O.YEL, "mm", 4)
    th = math.radians(a1)
    ex, ey = cx + rx * math.cos(th), cy + ry * math.sin(th)
    d.ellipse([ex - 18 * S, ey - 18 * S, ex + 18 * S, ey + 18 * S], fill=O.RED, outline=O.WHITE, width=int(3 * S))
    if u > 0.9:
        label(d, (ex - 40 * S if LAND else ex - 20 * S, ey + 70 * S), "約23km", 44, O.YEL)
    text(d, ((x0 + x1) / 2, y1 - 14 * S), "輪はおおまかな形です", 26, O.DIM, "md", 3)
    head(d, box, "鋼が自分の重さで切れる長さ", O.YEL)


def sc_wire(img, box, t, k, P):
    grad(img, box=box)
    x0, y0, x1, y1 = box
    d = ImageDraw.Draw(img)
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2 + 10 * S
    r = 150 * S * (0.92 + 0.08 * math.sin(t * 1.2))
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=GREY, outline=O.WHITE, width=int(5 * S))
    d.line([(cx - r, cy + r + 50 * S), (cx + r, cy + r + 50 * S)], fill=O.YEL, width=int(5 * S))
    for xx in (cx - r, cx + r):
        d.line([(xx, cy + r + 36 * S), (xx, cy + r + 64 * S)], fill=O.YEL, width=int(5 * S))
    text(d, (cx, cy + r + 110 * S), "直径 約1.1mm", 56, O.YEL, "mm", 5)
    text(d, (cx, cy), "断面", 56, O.NAVY, "mm", 0)
    text(d, (cx, cy - r - 60 * S), "1平方ミリ", 80, O.WHITE, "mm", 6)
    head(d, box, "針金の断面", O.YEL)


def sc_twothread(img, box, t, k, P):
    grad(img, box=box)
    x0, y0, x1, y1 = box
    d = ImageDraw.Draw(img)
    ty, by = y0 + 140 * S, y1 - 230 * S
    cxs = [x0 + (x1 - x0) * 0.28, x0 + (x1 - x0) * 0.72]
    for cx, wd, nm, wt in zip(cxs, (36 * S, 72 * S), ("太さ 1倍", "太さ 2倍"), ("重さ 1倍", "重さ 2倍")):
        d.rectangle([cx - 100 * S, ty - 24 * S, cx + 100 * S, ty], fill=GREY)
        d.rectangle([cx - wd / 2, ty, cx + wd / 2, by], fill=O.WHITE)
        vtext(d, (cx, by + 44 * S), nm, 46, O.YEL, "mm", maxw=(x1 - x0) * 0.4)
        vtext(d, (cx, by + 100 * S), wt, 40, O.WHITE, "mm", maxw=(x1 - x0) * 0.4)
        vtext(d, (cx, by + 156 * S), "切れる長さ　約23km", 40, O.GREEN, "mm", maxw=(x1 - x0) * 0.44)
    text(d, ((x0 + x1) / 2, (ty + by) / 2), "＝", 120, O.YEL, "mm", 7)
    head(d, box, "太くした分、重くなる", O.YEL)


# ---- 大きな数・箱の大きさ比べ ----------------------------------------------------------------------

def sc_big(img, box, t, k, P):
    grad(img, box=box)
    x0, y0, x1, y1 = box
    d = ImageDraw.Draw(img)
    cx = (x0 + x1) / 2
    zeros = P.get("zeros")
    vtext(d, (cx, y0 + (210 if zeros else 330) * S), P["big"], 150, O.YEL, "mm", maxw=(x1 - x0) - 60 * S, stroke=8)
    vtext(d, (cx, y0 + (330 if zeros else 470) * S), P["sub"], 46, O.WHITE, "mm", maxw=(x1 - x0) - 60 * S)
    if zeros:
        per = 32 if LAND else 24
        n_show = int(round(93 * _ease(k * 1.5)))
        pitch = ((x1 - x0) - 120 * S) / per
        fs = int(min(46 * S, pitch * 1.05))
        f = O.font(fs)
        chars = ["2"] + ["0"] * n_show
        for i, ch in enumerate(chars):
            row, col = divmod(i, per)
            xx = x0 + 60 * S + pitch * (col + 0.5)
            yy = y0 + 430 * S + row * (fs + 22 * S)
            d.text((xx, yy), ch, font=f, fill=O.YEL if i == 0 else O.WHITE, anchor="mm", stroke_width=3, stroke_fill=O.NAVY)
        if n_show >= 93:
            text(d, (cx, y1 - 70 * S), "0 が 93 個", 56, O.YEL, "mm", 6)
    head(d, box, P.get("head", "先細りにした断面積の倍率"), O.YEL)


def sc_areas(img, box, t, k, P):
    """stage 1=地上1平方ミリの点と座布団(炭素繊維の上) 2=座布団とテニスコート2面(ケブラーの上)。"""
    grad(img, box=box)
    x0, y0, x1, y1 = box
    d = ImageDraw.Draw(img)
    st = P["stage"]
    base = y1 - 150 * S
    u = _ease(k * 1.5)
    if st == 1:
        side = 250 * S * u
        cx = x0 + (x1 - x0) * 0.66
        d.rectangle([cx - side / 2, base - side, cx + side / 2, base], fill=mix(BLU, BG1, 0.9), outline=O.WHITE, width=int(4 * S))
        vtext(d, (cx, base + 56 * S), "炭素繊維の上　約0.24平方メートル", 40, O.WHITE, "mm", maxw=(x1 - x0) * 0.62)
        vtext(d, (cx, base + 106 * S), "座布団1枚ほど", 44, O.YEL, "mm", maxw=(x1 - x0) * 0.5)
        dx = x0 + (x1 - x0) * 0.2
        d.ellipse([dx - 4 * S, base - 8 * S, dx + 4 * S, base], fill=O.YEL)
        vtext(d, (dx, base + 56 * S), "地上　1平方ミリ", 40, O.WHITE, "mm", maxw=(x1 - x0) * 0.34)
        vtext(d, (dx, base + 106 * S), "点にしか見えない", 38, O.DIM, "mm", maxw=(x1 - x0) * 0.34)
        head(d, box, "炭素繊維　先細りの上の断面積", O.YEL)
    else:
        side = min((x1 - x0) * 0.42, 400 * S) * u
        cx = x0 + (x1 - x0) * 0.64
        d.rectangle([cx - side / 2, base - side, cx + side / 2, base], fill=mix(AMBER, BG1, 0.8), outline=O.WHITE, width=int(4 * S))
        d.line([(cx - side / 2, base - side / 2), (cx + side / 2, base - side / 2)], fill=O.WHITE, width=max(2, int(3 * S)))
        vtext(d, (cx, base - side / 2 - 0), "", 20, O.WHITE)
        vtext(d, (cx, base + 56 * S), "ケブラーの上　約600平方メートル", 40, O.WHITE, "mm", maxw=(x1 - x0) * 0.6)
        vtext(d, (cx, base + 106 * S), "テニスコート2面より広い", 44, O.YEL, "mm", maxw=(x1 - x0) * 0.6)
        sx = x0 + (x1 - x0) * 0.2
        s2 = side / 50.0
        d.rectangle([sx - s2 / 2, base - s2, sx + s2 / 2, base], fill=BLU, outline=O.WHITE)
        vtext(d, (sx, base + 56 * S), "炭素繊維の上", 40, O.WHITE, "mm", maxw=(x1 - x0) * 0.3)
        vtext(d, (sx, base + 106 * S), "座布団1枚ほど", 40, O.DIM, "mm", maxw=(x1 - x0) * 0.3)
        head(d, box, "上の断面積の大きさ比べ", O.YEL)


# ---- 原子の筒・膜 / 欠けのある糸 ------------------------------------------------------------------

def _hexes(d, cx, cy, wid, hei, s, mapx, col):
    dy = math.sqrt(3) * s
    nx = int(wid / (1.5 * s)) + 3
    ny = int(hei / dy) + 3
    for i in range(-nx, nx + 1):
        for j in range(-ny, ny + 1):
            hx = i * 1.5 * s
            hy = j * dy + (i % 2) * dy / 2
            if abs(hx) > wid / 2 + s or abs(hy) > hei / 2 + s:
                continue
            pts = []
            for a in range(6):
                th = math.radians(60 * a)
                vx, vy = hx + s * math.cos(th), hy + s * math.sin(th)
                if abs(vx) > wid / 2 + 1e-6 or abs(vy) > hei / 2 + 1e-6:
                    pts = None
                    break
                pts.append((cx + mapx(vx), cy + vy))
            if pts:
                d.polygon(pts, outline=col)
                for p in pts:
                    d.ellipse([p[0] - 3 * S, p[1] - 3 * S, p[0] + 3 * S, p[1] + 3 * S], fill=O.WHITE)


def sc_lattice(img, box, t, k, P):
    """mode=tube(カーボンナノチューブ) / sheet(グラフェン)。炭素の原子の六角形のつながり(図は模式)。"""
    grad(img, box=box)
    x0, y0, x1, y1 = box
    d = ImageDraw.Draw(img)
    mode = P["mode"]
    cx = (x0 + x1) / 2
    cy = (y0 + y1) / 2 + (10 if LAND else -40) * S
    s = 34 * S
    if mode == "tube":
        wid, hei = 3.3 * 60 * S * (1 if LAND else 1.0), 440 * S
        Rr = 130 * S
        # 筒: 縦長に描く。展開した幅 π*Rr の半分ずつ
        d.rounded_rectangle([cx - Rr, cy - hei / 2, cx + Rr, cy + hei / 2], int(Rr), fill=(24, 44, 84), outline=O.WHITE, width=int(4 * S))
        _hexes(d, cx, cy, math.pi * Rr * 0.98, hei * 0.86, s, lambda x: Rr * math.sin(x / Rr) if abs(x) < math.pi * Rr / 2 else Rr * (1 if x > 0 else -1), (110, 200, 235))
        text(d, (cx + Rr + 70 * S, cy - 40 * S), "炭素の原子が", 46, O.WHITE, "lm", 5)
        text(d, (cx + Rr + 70 * S, cy + 20 * S), "筒になった素材", 46, O.YEL, "lm", 5)
        text(d, (cx - Rr - 70 * S, cy - 10 * S), "髪の毛の", 40, O.WHITE, "rm", 4)
        text(d, (cx - Rr - 70 * S, cy + 44 * S), "1万分の1ほどの太さ", 40, O.WHITE, "rm", 4)
        head(d, box, "カーボンナノチューブ", O.YEL)
    else:
        wid, hei = 640 * S, 380 * S
        d.rounded_rectangle([cx - wid / 2, cy - hei / 2, cx + wid / 2, cy + hei / 2], int(16 * S), fill=(24, 44, 84), outline=O.WHITE, width=int(4 * S))
        _hexes(d, cx, cy, wid * 0.94, hei * 0.9, s, lambda x: x, (150, 230, 170))
        text(d, (cx, cy + hei / 2 + 54 * S), "炭素の原子が、平らに1層だけ並んだ膜", 44, O.YEL, "mm", 5)
        head(d, box, "グラフェン", O.YEL)
    text(d, ((x0 + x1) / 2, y1 - 14 * S), "並びを模式的に描いています", 26, O.DIM, "md", 3)


def sc_flaw(img, box, t, k, P):
    grad(img, box=box)
    x0, y0, x1, y1 = box
    d = ImageDraw.Draw(img)
    cy = (y0 + y1) / 2 - 20 * S
    xa, xb = x0 + 70 * S, x1 - 70 * S
    fx = (xa + xb) * 0.58
    u = _ease(k * 1.4)
    gap = 36 * S * u
    d.line([(xa, cy), (fx - gap / 2, cy)], fill=O.WHITE, width=max(4, int(12 * S)))
    d.line([(fx + gap / 2, cy + 6 * S * u), (xb, cy + 6 * S * u)], fill=O.WHITE, width=max(4, int(12 * S)))
    d.polygon([(fx - 18 * S, cy - 8 * S), (fx + 18 * S, cy - 8 * S), (fx, cy + 4 * S)], fill=BG1)
    d.ellipse([fx - 30 * S, cy - 30 * S, fx + 30 * S, cy + 30 * S], outline=O.RED, width=max(2, int(4 * S)))
    label(d, (fx, cy - 100 * S), "1か所の欠け", 44, O.RED)
    text(d, (xa, cy + 70 * S), "長い糸", 44, O.WHITE, "la", 4)
    text(d, (fx, cy + 150 * S), "欠けのある所から切れる", 48, O.YEL, "mm", 5)
    text(d, (fx, cy + 220 * S), "長いほど、欠けに当たりやすい", 40, O.WHITE, "mm", 4)
    head(d, box, "長い糸は1か所でも欠けると切れる", O.YEL)


KINDS = dict(formula=sc_formula, meter=sc_meter, table=sc_table, cable=sc_cable, gcurve=sc_gcurve, taper=sc_taper, hang=sc_hang,
             loop=sc_loop, wire=sc_wire, twothread=sc_twothread, big=sc_big, areas=sc_areas, lattice=sc_lattice, flaw=sc_flaw)


def region(P=None):
    return (0, 100, W, 880) if LAND else (0, 240, W, 1370)


def room_box(box):
    """「失敗」の札を置く場所をあけた描画範囲(横は右、縦は下)。"""
    x0, y0, x1, y1 = box
    return (x0, y0, x1 - 470 * S, y1) if LAND else (x0, y0, x1, y1 - 330 * S)


def paint(sc, t, k):
    img = Image.new("RGBA", (W, H), BG0 + (255,))
    box = region(sc)
    grad(img, box=box)
    if sc.get("room"):
        box = room_box(box)
    KINDS[sc["kind"]](img, box, t, k, sc)
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
    """大きな「失敗」(赤)・「成功」(緑)の札。あけてある場所(右・下)に、大きく出てすっと落ち着く。"""
    s, col = {"fail": ("失敗", O.RED), "ok": ("成功", O.GREEN), "almost": ("ほぼ失敗", ORG)}[kind]
    sz = int(150 * S)
    f = O.font(sz)
    pad = int(30 * S)
    tw = int(f.getlength(s))
    lay = Image.new("RGBA", (tw + pad * 2, sz + pad * 2), (0, 0, 0, 0))
    ld = ImageDraw.Draw(lay)
    ld.rounded_rectangle([4, 4, lay.width - 5, lay.height - 5], int(26 * S), fill=(8, 16, 36, 235), outline=col, width=int(10 * S))
    ld.text((lay.width / 2, lay.height / 2 - int(5 * S)), s, font=f, fill=col, anchor="mm")
    sc = 1.0 + 0.4 * (1 - _ease(u * 3))
    lay = lay.resize((int(lay.width * sc), int(lay.height * sc)), Image.LANCZOS).rotate(8, expand=True, resample=Image.BICUBIC)
    rb = room_box(box)
    if LAND:
        cx, cy = (rb[2] + box[2]) / 2, (box[1] + box[3]) / 2
    else:
        cx, cy = (box[0] + box[2]) / 2, (rb[3] + box[3]) / 2
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

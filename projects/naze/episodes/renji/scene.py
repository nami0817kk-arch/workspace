"""電子レンジの回の画面。行の scene=dict(kind=…) を描く(無い行は前の行を引き継ぐ)。場面が変わると 0.5 秒で溶け合わせる。
全部コードで描いた計算の図(写真・生成画像は使わない)。

kind: slab(食べ物の断面と電波)/ oven(電子レンジ)/ field(向きが変わる波)/ decay(電波が弱まるグラフ)/
      heat(厚さ 2・4・6・10cm を温める計算)/ pulse(6cm を続けて/休み休み)/ mol(水の分子)/ depth(周波数ごとの届く深さ)/
      absorb(水が吸う強さと周波数)/ wavelen(波の長さ)/ standing(庫内の定在波)/ turn(回る皿・まだら)/
      shrink(水の中で縮む波とブドウ)/ grape(半分のブドウの火花)/ icewater(水と氷)/ thaw(解凍ムラ)
scene に panel=dict(kind="big"|…) があれば naze.mapscene の枠を右(縦は下)に重ね、絵は残りの場所に寄せる。

数字の出どころ(../research.md):
  水の誘電率はデバイの式(静的誘電率 78.36・緩和時間 8.27ps・ε∞ 5.2、25℃)。2.45GHz で ε'=77.2、ε''=9.2
  電力が 37% になる深さ Dp: 0.915GHz 13.3cm / 2.45GHz 1.87cm / 5.8GHz 0.35cm / 20GHz 0.04cm。氷は ε''≈0.003 で約 12m
  厚さを変えて温める計算(heat_run): 10cm 四方の水の板、5℃から、500W を上下から入れ、厚さの向きの熱伝導だけ(../heat_calc.py と同じ式)
  波長 12.2cm(真空)、水の中 1.39cm、定在波の強い所は半波長の約 6cm おき
"""
from __future__ import annotations

import math
import random

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

from naze import mapscene, overlay as O
from naze.config import H, W

LAND = W > H
S = min(W, H) / 1080
QUIET = [False]              # 問いの行は札を出さない(大きな問いの字と重なるので)


def _ease(u):
    u = max(0.0, min(1.0, u))
    return u * u * (3 - 2 * u)


def lerp(a, b, u):
    return tuple(int(a[i] + (b[i] - a[i]) * u) for i in range(3))


def grad(img, top, bot, box=None):
    x0, y0, x1, y1 = box or (0, 0, W, H)
    d = ImageDraw.Draw(img)
    n = int(y1 - y0)
    for i in range(0, n, 2):
        d.rectangle([x0, y0 + i, x1, y0 + i + 2], fill=lerp(top, bot, i / max(1, n)))


def bg(img):
    grad(img, (10, 18, 40), (16, 30, 62))


def text(d, xy, s, size, col=O.WHITE, anchor="la", stroke=5):
    d.text(xy, s, font=O.font(int(size * S)), fill=col, anchor=anchor, stroke_width=stroke, stroke_fill=O.NAVY)


def label(d, xy, s, size=40, col=O.WHITE, anchor="mm"):
    """白い字の小さな札(箱つき)。重なりの点検に載せる。"""
    if QUIET[0]:
        return
    f = O.font(int(size * S))
    bb = d.textbbox(xy, s, font=f, anchor=anchor)
    pad = 12 * S
    box = (bb[0] - pad, bb[1] - pad * 0.7, bb[2] + pad, bb[3] + pad * 0.7)
    d.rounded_rectangle(box, int(10 * S), fill=O.NAVY + (220,), outline=col, width=max(2, int(3 * S)))
    d.text(xy, s, font=f, fill=col, anchor=anchor)
    O.BOXES.append(("label", box, s, 1.0))


def arrow(d, a, b, col, w=6, head=22):
    d.line([a, b], fill=col, width=int(w * S))
    ang = math.atan2(b[1] - a[1], b[0] - a[0])
    h = head * S
    d.polygon([b, (b[0] - h * math.cos(ang - 0.45), b[1] - h * math.sin(ang - 0.45)),
               (b[0] - h * math.cos(ang + 0.45), b[1] - h * math.sin(ang + 0.45))], fill=col)


def glow(img, cx, cy, r, col, a=1.0):
    lay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(lay)
    for i in range(10, 0, -1):
        rr = r * (1 + i * 0.3)
        d.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], fill=col + (int(16 * a),))
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=col + (int(200 * a),))
    img.alpha_composite(lay)


# ---- 温度の色(5℃ 青 → 100℃ 赤) ----------------------------------------------------------
TSTOPS = [(0, (40, 60, 160)), (5, (50, 90, 200)), (25, (50, 170, 215)), (45, (90, 205, 120)), (65, (245, 215, 70)),
          (85, (248, 130, 40)), (100, (225, 40, 40))]


def tcol(T):
    T = max(0.0, min(100.0, T))
    for (a, ca), (b, cb) in zip(TSTOPS, TSTOPS[1:]):
        if T <= b:
            return lerp(ca, cb, (T - a) / (b - a))
    return TSTOPS[-1][1]


def legend(d, cx, y, w):
    x0 = cx - w / 2
    for i in range(int(w)):
        d.line([(x0 + i, y), (x0 + i, y + 18 * S)], fill=tcol(5 + 95 * i / w))
    text(d, (x0 - 14 * S, y + 9 * S), "5℃", 30, O.DIM, "rm", 4)
    text(d, (x0 + w + 14 * S, y + 9 * S), "100℃", 30, O.DIM, "lm", 4)


# ---- 水の計算(デバイの式・浸透深さ・熱の伝わり方) -------------------------------------------
C0 = 299792458.0
ES, EINF, TAU = 78.36, 5.2, 8.27e-12


def eps(f):
    w = 2 * math.pi * f
    e = EINF + (ES - EINF) / (1 + 1j * w * TAU)
    return e.real, -e.imag


def dp(f, e1=None, e2=None):
    """電力が 37% になる深さ(m)。"""
    if e1 is None:
        e1, e2 = eps(f)
    l0 = C0 / f
    return l0 / (2 * math.pi * math.sqrt(2 * e1)) / math.sqrt(math.sqrt(1 + (e2 / e1) ** 2) - 1)


DP = dp(2.45e9) * 100            # cm(1.87)
DP_ICE = dp(2.45e9, 3.17, 0.003) * 100
LAM0 = C0 / 2.45e9 * 100          # 12.24cm
LAM_W = LAM0 / math.sqrt(eps(2.45e9)[0])   # 1.39cm

_HR = {}


def heat_run(T, pulse=None, P=500.0, stop=100.0):
    """heat_calc.py と同じ計算(厚さ T m の水の板、上下から電波)。時刻・断面の温度(48 点)・真ん中・電波の入切の記録を返す。"""
    key = (T, pulse)
    if key in _HR:
        return _HR[key]
    A, N = 0.01, 200
    z = np.linspace(0, T, N)
    dz = z[1] - z[0]
    rc = 4.18e6
    a = 0.6 / rc
    D = DP / 100
    shape = np.exp(-z / D) + np.exp(-(T - z) / D)
    shape = shape / (shape.sum() * dz * A)
    Tm = np.full(N, 5.0)
    t = 0.0
    dt = 0.4 * dz * dz / a
    pick = np.linspace(0, N - 1, 48).round().astype(int)
    ts, prof, cen, ons = [0.0], [Tm[pick].copy()], [5.0], [1.0]
    while Tm.max() < stop and t < 7200:
        on = 1.0 if pulse is None else (1.0 if (t % pulse[1]) < pulse[0] else 0.0)
        lap = np.zeros(N)
        lap[1:-1] = (Tm[2:] - 2 * Tm[1:-1] + Tm[:-2]) / dz ** 2
        lap[0] = 2 * (Tm[1] - Tm[0]) / dz ** 2
        lap[-1] = 2 * (Tm[-2] - Tm[-1]) / dz ** 2
        Tm = Tm + dt * (a * lap + P * shape * on / rc)
        t += dt
        ts.append(t)
        prof.append(Tm[pick].copy())
        cen.append(float(Tm[N // 2]))
        ons.append(on)
    r = dict(t=np.array(ts), prof=np.array(prof), cen=np.array(cen), on=np.array(ons), end=t)
    _HR[key] = r
    return r


def snap(r, tt):
    i = int(min(len(r["t"]) - 1, np.searchsorted(r["t"], tt)))
    return r["prof"][i], r["cen"][i], r["on"][i]


THICK = [2, 4, 6, 10]
PULSE = (10, 30)


# ---- 部品 --------------------------------------------------------------------------------

def squiggle(d, x, y0, y1, t, col, amp=10, lam=40, w=4, fade=None):
    """縦向きのくねる線(電波)。y0 → y1 へ進む向きに模様が流れる。"""
    n = int(abs(y1 - y0) / 3)
    sgn = 1 if y1 > y0 else -1
    pts = []
    for i in range(n + 1):
        y = y0 + sgn * i * 3
        ph = 2 * math.pi * ((i * 3) / (lam * S) - t * 1.2)
        pts.append((x + amp * S * math.sin(ph), y))
    d.line(pts, fill=col, width=int(w * S), joint="curve")


def hsquiggle(d, x0, x1, y, t, col, amp=10, lam=40, w=4, decay=None):
    """横向きのくねる線。decay(cm あたり px の換算, 深さ Dp cm)で振幅が弱まる。"""
    pts = []
    for x in range(int(x0), int(x1), 3):
        u = x - x0
        A = amp * S
        if decay:
            pxcm, D = decay
            A *= math.exp(-u / pxcm / (2 * D))
        pts.append((x, y + A * math.sin(2 * math.pi * (u / (lam * S) - t * 1.2))))
    if len(pts) > 1:
        d.line(pts, fill=col, width=int(w * S), joint="curve")


def block(img, x, y, w, h, prof, dim=False, outline=O.WHITE, ow=3):
    """断面(上が表面・下が裏面)を温度の色で塗る。prof は厚さ方向の温度。"""
    d = ImageDraw.Draw(img)
    n = len(prof)
    step = max(2, int(h / 90))
    for yy in range(0, int(h), step):
        z = (yy + step / 2) / h * (n - 1)
        i = int(z)
        f = z - i
        T = prof[i] * (1 - f) + prof[min(n - 1, i + 1)] * f
        c = tcol(T)
        if dim:
            c = lerp(c, (20, 28, 50), 0.6)
        d.rectangle([x, y + yy, x + w, y + min(h, yy + step)], fill=c)
    d.rectangle([x, y, x + w, y + h], outline=outline, width=int(ow * S))


def dashed(d, a, b, t, col, w=3, dash=16):
    L = math.dist(a, b)
    if L < 1:
        return
    ux, uy = (b[0] - a[0]) / L, (b[1] - a[1]) / L
    off = (t * 40) % (dash * 2)
    s = -dash * 2 + off
    while s < L:
        s0, s1 = max(0, s), min(L, s + dash)
        if s1 > s0:
            d.line([(a[0] + ux * s0, a[1] + uy * s0), (a[0] + ux * s1, a[1] + uy * s1)], fill=col, width=int(w * S))
        s += dash * 2


# ---- 場面 -------------------------------------------------------------------------------

def sc_slab(img, box, t, k, P):
    """食べ物の断面。上下から電波が入り、表面から約 2cm で弱まる。mode: reach / layer / conduct。"""
    bg(img)
    x0, y0, x1, y1 = box
    bw = (x1 - x0)
    cm = min((y1 - y0) * 0.62 / 8, bw * 0.8 / 12)              # 8cm の厚さが入る
    sx0, sx1 = x0 + bw * 0.14, x1 - bw * 0.06
    th = 8 * cm
    cy = (y0 + y1) / 2 + 10 * S
    sy0, sy1 = cy - th / 2, cy + th / 2
    mode = P.get("mode", "reach")
    d = ImageDraw.Draw(img)
    n = int(th / 2)
    for i in range(n):
        z = (i + 0.5) / n * 8
        pw = math.exp(-z / DP) + math.exp(-(8 - z) / DP)
        if mode == "conduct":
            # 外が熱く、中へ伝わっていく(仮の形: 外は 100℃ 近く、真ん中へ下がる)
            T = 15 + 85 * min(1, pw) ** 0.8 + 8 * k * (1 - min(1, pw))
            c = tcol(T)
        else:
            glow_k = 0.85 + 0.15 * math.sin(t * 3) if mode == "layer" else 1.0
            c = lerp((40, 46, 70), (255, 150, 50), min(1, pw) ** 1.4 * glow_k)
        d.rectangle([sx0, sy0 + i * 2, sx1, sy0 + i * 2 + 2], fill=c)
    d.rectangle([sx0, sy0, sx1, sy1], outline=O.WHITE, width=int(3 * S))
    # 電波(上と下から)
    col = (150, 220, 255)
    for j in range(5):
        x = sx0 + (sx1 - sx0) * (j + 0.5) / 5
        squiggle(d, x, sy0 - 110 * S, sy0 - 8 * S, t + j * 0.13, col, amp=9, lam=34, w=4)
        squiggle(d, x, sy1 + 110 * S, sy1 + 8 * S, t + j * 0.13, col, amp=9, lam=34, w=4)
    # 中へ入った波(弱まる)
    lay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    dl = ImageDraw.Draw(lay)
    for j in range(5):
        x = sx0 + (sx1 - sx0) * (j + 0.5) / 5
        for side in (0, 1):
            pts = []
            for i in range(0, int(th / 2), 3):
                A = 9 * S * math.exp(-(i / cm) / (2 * DP))
                ph = 2 * math.pi * (i / (LAM_W * cm) - t * 1.2)
                y = sy0 + i if side == 0 else sy1 - i
                pts.append((x + A * math.sin(ph), y))
            dl.line(pts, fill=(200, 240, 255, 150), width=int(3 * S))
    img.alpha_composite(lay)
    d = ImageDraw.Draw(img)
    if mode == "conduct":
        # 外から中へ流れる熱(矢じりが流れる)
        for j in range(4):
            x = sx0 + (sx1 - sx0) * (j + 1) / 5
            for side in (0, 1):
                ph = (t * 0.45 + j * 0.21) % 1.0
                yy = sy0 + th * (0.1 + 0.32 * ph) if side == 0 else sy1 - th * (0.1 + 0.32 * ph)
                a = int(255 * math.sin(math.pi * ph))
                dd = 1 if side == 0 else -1
                d.line([(x - 22 * S, yy - dd * 14 * S), (x, yy + dd * 4 * S), (x + 22 * S, yy - dd * 14 * S)], fill=(255, 245, 220), width=int(6 * S))
        dashed(d, (sx0, cy), (sx1, cy), t, (255, 255, 255), 3)
        label(d, (sx0 + (sx1 - sx0) * 0.5, cy), "外から伝わる熱で温まる", 36, O.WHITE)
    else:
        # 約 2cm の目盛り(左)
        bx = sx0 - 34 * S
        d.line([(bx, sy0), (bx, sy0 + 2 * cm)], fill=O.YEL, width=int(5 * S))
        d.line([(bx - 12 * S, sy0), (bx + 12 * S, sy0)], fill=O.YEL, width=int(5 * S))
        d.line([(bx - 12 * S, sy0 + 2 * cm), (bx + 12 * S, sy0 + 2 * cm)], fill=O.YEL, width=int(5 * S))
        text(d, (bx - 18 * S, sy0 + cm), "約2cm", 34, O.YEL, "rm", 5)
        if mode == "layer":
            label(d, ((sx0 + sx1) / 2, sy0 + cm * 1.0), "熱が生まれる層", 36, O.YEL)
            label(d, ((sx0 + sx1) / 2, cy), "真ん中", 34, O.DIM)
        else:
            label(d, ((sx0 + sx1) / 2, cy), "真ん中には、ほとんど届かない", 36, O.DIM)
    text(d, (sx1, sy0 - 120 * S), "食べ物の断面", 34, O.DIM, "rb", 4)


def sc_oven(img, box, t, k, P):
    """電子レンジ(正面)。庫内で電波がはね返り、皿が回る。"""
    bg(img)
    x0, y0, x1, y1 = box
    bw, bh = x1 - x0, y1 - y0
    ow = min(bw * 0.8, bh * 0.82 * 1.6)
    oh = ow / 1.6
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2 + 10 * S
    ox0, oy0, ox1, oy1 = cx - ow / 2, cy - oh / 2, cx + ow / 2, cy + oh / 2
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([ox0, oy0, ox1, oy1], int(28 * S), fill=(205, 212, 222), outline=(240, 244, 250), width=int(4 * S))
    px0 = ox1 - ow * 0.22
    d.line([(px0, oy0 + 16 * S), (px0, oy1 - 16 * S)], fill=(160, 168, 180), width=int(3 * S))
    # 操作の部分
    d.rounded_rectangle([px0 + ow * 0.03, oy0 + oh * 0.12, ox1 - ow * 0.03, oy0 + oh * 0.28], int(8 * S), fill=(30, 40, 50))
    tick = int(t) % 2
    text(d, ((px0 + ox1) / 2, oy0 + oh * 0.2), "0:3" + ("0" if tick else "1"), 34, (120, 255, 160), "mm", 0)
    for i in range(2):
        bxc = (px0 + ox1) / 2
        byc = oy0 + oh * (0.48 + i * 0.22)
        r = ow * 0.045
        d.ellipse([bxc - r, byc - r, bxc + r, byc + r], fill=(150, 158, 170), outline=(110, 118, 130), width=int(3 * S))
        a = t * (0.8 if i == 0 else -0.5)
        d.line([(bxc, byc), (bxc + r * 0.8 * math.cos(a), byc + r * 0.8 * math.sin(a))], fill=(60, 66, 80), width=int(4 * S))
    # 窓(庫内)
    wx0, wy0, wx1, wy1 = ox0 + ow * 0.05, oy0 + oh * 0.1, px0 - ow * 0.04, oy1 - oh * 0.1
    d.rounded_rectangle([wx0, wy0, wx1, wy1], int(14 * S), fill=(30, 26, 18), outline=(90, 96, 110), width=int(6 * S))
    lay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    dl = ImageDraw.Draw(lay)
    dl.rounded_rectangle([wx0 + 6, wy0 + 6, wx1 - 6, wy1 - 6], int(12 * S), fill=(255, 190, 90, 60))
    img.alpha_composite(lay)
    d = ImageDraw.Draw(img)
    # はね返る電波(斜めの道すじを光の玉が進む)
    for j in range(3):
        ph = (t * 0.35 + j / 3) % 1.0
        pts = []
        for i in range(60):
            u = (ph + i * 0.004) % 1.0
            xx = wx0 + 20 * S + (wx1 - wx0 - 40 * S) * (1 - abs(1 - 2 * ((u * 3 + j * 0.3) % 1.0)))
            yy = wy0 + 20 * S + (wy1 - wy0 - 40 * S) * (1 - abs(1 - 2 * ((u * 2.1 + j * 0.5) % 1.0)))
            pts.append((xx, yy))
        d.line(pts, fill=(170, 225, 255), width=int(3 * S))
    # 回る皿と食べ物
    pcx, pcy = (wx0 + wx1) / 2, wy1 - (wy1 - wy0) * 0.2
    pr = (wx1 - wx0) * 0.36
    d.ellipse([pcx - pr, pcy - pr * 0.22, pcx + pr, pcy + pr * 0.22], fill=(200, 205, 210), outline=(240, 240, 240), width=int(3 * S))
    a = t * 0.9
    fx = pcx + pr * 0.35 * math.cos(a)
    fy = pcy + pr * 0.07 * math.sin(a)
    fw, fh = pr * 0.55, pr * 0.32
    d.rounded_rectangle([fx - fw / 2, fy - fh, fx + fw / 2, fy], int(10 * S), fill=(230, 120, 70), outline=(255, 200, 150), width=int(3 * S))
    for i in range(4):                                         # 湯気
        ph = (t * 0.5 + i * 0.25) % 1.0
        sx = fx - fw * 0.3 + fw * 0.2 * i + 8 * S * math.sin(t * 2 + i)
        sy = fy - fh - ph * (wy1 - wy0) * 0.35
        r = (8 + 10 * ph) * S
        d.ellipse([sx - r, sy - r, sx + r, sy + r], outline=(255, 255, 255, int(180 * (1 - ph))), width=int(3 * S))
    if P.get("note"):
        label(d, (cx, oy1 + 50 * S), P["note"], 38, O.WHITE)


def sc_field(img, box, t, k, P):
    """1 秒に 24 億 5 千万回、向きが変わる波(ゆっくりにして見せる)。"""
    bg(img)
    x0, y0, x1, y1 = box
    d = ImageDraw.Draw(img)
    cy = (y0 + y1) / 2
    gx0, gx1 = x0 + (x1 - x0) * 0.06, x1 - (x1 - x0) * 0.06
    amp = (y1 - y0) * 0.26
    lam = (gx1 - gx0) / 2.5
    d.line([(gx0, cy), (gx1, cy)], fill=(90, 100, 130), width=int(3 * S))
    pts = [(x, cy - amp * math.sin(2 * math.pi * ((x - gx0) / lam - t * 0.5))) for x in range(int(gx0), int(gx1), 3)]
    d.line(pts, fill=(150, 220, 255), width=int(7 * S), joint="curve")
    for i in range(21):
        x = gx0 + (gx1 - gx0) * i / 20
        v = math.sin(2 * math.pi * ((x - gx0) / lam - t * 0.5))
        if abs(v) > 0.12:
            arrow(d, (x, cy), (x, cy - amp * v * 0.92), O.YEL if v > 0 else (255, 140, 90), 4, 16)
    label(d, (x0 + (x1 - x0) * 0.24, y0 + 50 * S), "↑ 上向き", 34, O.YEL)
    label(d, (x0 + (x1 - x0) * 0.76, y1 - 50 * S), "↓ 下向き", 34, (255, 140, 90))
    text(d, ((x0 + x1) / 2, y1 - 6 * S), "（ゆっくりにして見せています）", 30, O.DIM, "md", 4)


def sc_decay(img, box, t, k, P):
    """水の中で電波が弱まる。強さ = exp(-深さ / 1.87cm)。下は断面の帯と、弱まりながら進む波。"""
    bg(img)
    x0, y0, x1, y1 = box
    d = ImageDraw.Draw(img)
    gx0, gx1 = x0 + (x1 - x0) * 0.1, x1 - (x1 - x0) * 0.05
    gy0, gy1 = y0 + (y1 - y0) * 0.14, y0 + (y1 - y0) * 0.66
    zmax = 8.0
    px = lambda z: gx0 + (gx1 - gx0) * z / zmax
    py = lambda v: gy1 - (gy1 - gy0) * v / 100
    d.line([(gx0, gy1), (gx1, gy1)], fill=O.DIM, width=int(3 * S))
    d.line([(gx0, gy0), (gx0, gy1)], fill=O.DIM, width=int(3 * S))
    for v in (0, 50, 100):
        text(d, (gx0 - 14 * S, py(v)), f"{v}%", 30, O.DIM, "rm", 3)
    for z in range(0, 9, 2):
        text(d, (px(z), gy1 + 12 * S), f"{z}cm", 30, O.DIM, "ma", 3)
    text(d, (gx0, gy0 - 44 * S), "電波の強さ（表面を100%）", 36, O.DIM, "la", 4)
    marks = P.get("marks", [])
    u = 1.0 if marks else _ease(k * 1.4)
    pts = [(px(z / 20), py(100 * math.exp(-(z / 20) / DP))) for z in range(0, int(zmax * 20) + 1) if z / 20 / zmax <= u]
    if len(pts) > 1:
        d.line(pts, fill=O.YEL, width=int(7 * S), joint="curve")
    names = {2: "約3分の1", 4: "約10分の1", 6: "約30分の1"}
    for i, z in enumerate(marks):
        v = 100 * math.exp(-z / DP)
        a = _ease(k * 3 - i * 0.8) if i == len(marks) - 1 and len(marks) > 1 else 1.0
        if marks == [2, 4, 6] and i > 0:
            a = _ease(k * 3.2 - (i - 1) * 1.4)
        if a <= 0:
            continue
        dashed(d, (px(z), py(v)), (px(z), gy1), t, (255, 255, 255), 2, 10)
        r = 11 * S
        d.ellipse([px(z) - r, py(v) - r, px(z) + r, py(v) + r], fill=O.WHITE)
        label(d, (px(z) + (14 if LAND else 0) * S, py(v) - 62 * S), names[z], 34 if not LAND else 38, O.YEL)
    # 断面の帯
    sy0, sy1 = gy1 + 70 * S, y1 - 10 * S
    for x in range(int(gx0), int(gx1), 3):
        z = (x - gx0) / (gx1 - gx0) * zmax
        c = lerp((40, 46, 70), (255, 150, 50), math.exp(-z / DP))
        d.rectangle([x, sy0, x + 3, sy1], fill=c)
    d.rectangle([gx0, sy0, gx1, sy1], outline=O.WHITE, width=int(2 * S))
    pxcm = (gx1 - gx0) / zmax
    hsquiggle(d, gx0 - 70 * S, gx0, (sy0 + sy1) / 2, t, (150, 220, 255), amp=(sy1 - sy0) * 0.32 / S, lam=LAM_W * pxcm / S * 1.0, w=4)
    hsquiggle(d, gx0, gx1, (sy0 + sy1) / 2, t, (210, 240, 255), amp=(sy1 - sy0) * 0.32 / S, lam=LAM_W * pxcm / S, w=4, decay=(pxcm, DP))
    text(d, (gx0 - 14 * S, (sy0 + sy1) / 2), "水", 34, O.WHITE, "rm", 4)


def _heat_layout(box):
    x0, y0, x1, y1 = box
    out = []
    if LAND:
        cw = (x1 - x0) / 4
        bw = cw * 0.72
        cm = bw / 10
        cy = y0 + (y1 - y0) * 0.54
        for i, th in enumerate(THICK):
            cx = x0 + cw * (i + 0.5)
            out.append((cx - bw / 2, cy - th * cm / 2, bw, th * cm, cx))
    else:
        cw = (x1 - x0) / 2
        bw = cw * 0.72
        cm = bw / 10
        for i, th in enumerate(THICK):
            r, c = divmod(i, 2)
            cx = x0 + cw * (c + 0.5)
            cy = y0 + 330 * S if r == 0 else y0 + 880 * S
            out.append((cx - bw / 2, cy - th * cm / 2, bw, th * cm, cx))
    return out


def sc_heat(img, box, t, k, P):
    """厚さ 2・4・6・10cm の水の板を、上下からの電波で温める計算。一番熱い所が 100℃ になるまで。"""
    bg(img)
    x0, y0, x1, y1 = box
    d = ImageDraw.Draw(img)
    if "frac" in P:
        frac = P["frac"]
    elif P.get("run"):
        frac = _ease(k / 0.92)
    else:
        frac = 1.0
    hl = P.get("hl", [])
    legend(d, (x0 + x1) / 2, y0 + 22 * S, 420 * S)
    for i, (bx, by, bw, bh, cx) in enumerate(_heat_layout(box)):
        r = heat_run(THICK[i] / 100)
        prof, cen, on = snap(r, frac * r["end"])
        dim = bool(hl) and i not in hl
        block(img, bx, by, bw, bh, prof, dim=dim, outline=O.YEL if i in hl else O.WHITE, ow=6 if i in hl else 3)
        d = ImageDraw.Draw(img)
        col = (150, 220, 255) if not dim else (70, 90, 110)
        for j in range(3):
            xx = bx + bw * (j + 0.5) / 3
            squiggle(d, xx, by - 64 * S, by - 6 * S, t + j * 0.2, col, amp=7, lam=26, w=3)
            squiggle(d, xx, by + bh + 64 * S, by + bh + 6 * S, t + j * 0.2, col, amp=7, lam=26, w=3)
        dashed(d, (bx, by + bh / 2), (bx + bw, by + bh / 2), t, (255, 255, 255) if not dim else (90, 100, 120), 2, 10)
        text(d, (cx, by - 74 * S), f"厚さ{THICK[i]}cm", 40, O.YEL if i in hl else (O.WHITE if not dim else (110, 120, 140)), "md", 5)
        if not dim or i in hl:
            label(d, (cx, by + bh + 92 * S), f"真ん中 {cen:.0f}℃", 36, O.YEL if i in hl else O.WHITE)


def sc_pulse(img, box, t, k, P):
    """厚さ 6cm を、続けて温める/10 秒温めて 20 秒休む。下は真ん中の温度の移り変わり。"""
    bg(img)
    x0, y0, x1, y1 = box
    d = ImageDraw.Draw(img)
    rc = heat_run(0.06)
    rp = heat_run(0.06, PULSE)
    if "frac" in P:
        frac = P["frac"]
    elif P.get("run"):
        frac = _ease(k / 0.92)
    else:
        frac = 1.0
    tt = frac * rp["end"]
    hl = P.get("hl")
    if LAND:
        bw = (x1 - x0) * 0.19
        cxs = [x0 + (x1 - x0) * 0.14, x0 + (x1 - x0) * 0.39]
        bcy = (y0 + y1) / 2 - 20 * S
        gbox = (x0 + (x1 - x0) * 0.56, y0 + 70 * S, x1 - (x1 - x0) * 0.04, y1 - 80 * S)
    else:
        bw = (x1 - x0) * 0.34
        cxs = [x0 + (x1 - x0) * 0.27, x0 + (x1 - x0) * 0.73]
        bcy = y0 + 300 * S
        gbox = (x0 + 150 * S, y0 + 690 * S, x1 - 60 * S, y1 - 90 * S)
    cm = bw / 10
    bh = 6 * cm
    names = ["続けて温める", "10秒温めて20秒休む"]
    cols = [(255, 140, 70), O.YEL]
    for i, r in enumerate((rc, rp)):
        prof, cen, on = snap(r, min(tt, r["end"]))
        bx, by = cxs[i] - bw / 2, bcy - bh / 2
        dim = hl is not None and hl != i
        block(img, bx, by, bw, bh, prof, dim=dim, outline=O.YEL if hl == i else O.WHITE, ow=6 if hl == i else 3)
        d = ImageDraw.Draw(img)
        running = tt < r["end"] and on > 0
        if running or not P.get("run"):
            for j in range(3):
                xx = bx + bw * (j + 0.5) / 3
                c = (150, 220, 255) if (running or tt >= r["end"]) else (70, 90, 110)
                squiggle(d, xx, by - 56 * S, by - 6 * S, t + j * 0.2, c, amp=6, lam=24, w=3)
                squiggle(d, xx, by + bh + 56 * S, by + bh + 6 * S, t + j * 0.2, c, amp=6, lam=24, w=3)
        dashed(d, (bx, by + bh / 2), (bx + bw, by + bh / 2), t, (255, 255, 255), 2, 10)
        if P.get("arrows") and i == 1:
            for j in range(3):
                xx = bx + bw * (j + 0.5) / 3
                for side in (0, 1):
                    ph = (t * 0.5 + j * 0.3) % 1.0
                    dd = 1 if side == 0 else -1
                    yy = (by + bh * (0.08 + 0.3 * ph)) if side == 0 else (by + bh - bh * (0.08 + 0.3 * ph))
                    d.line([(xx - 16 * S, yy - dd * 10 * S), (xx, yy + dd * 3 * S), (xx + 16 * S, yy - dd * 10 * S)], fill=(255, 245, 220), width=int(5 * S))
        text(d, (cxs[i], by - 66 * S), names[i], 36, cols[i] if not dim else (110, 120, 140), "md", 5)
        if not dim:
            label(d, (cxs[i], by + bh + 100 * S), f"真ん中 {cen:.0f}℃", 36, cols[i])
        if i == 1 and P.get("run") and tt < r["end"]:
            text(d, (cxs[i], by + bh + 150 * S), "温め中" if on > 0 else "休み中", 32, O.YEL if on > 0 else O.DIM, "ma", 4)
    # 真ん中の温度の移り変わり
    gx0, gy0, gx1, gy1 = gbox
    tmax = 1200.0
    gpx = lambda s: gx0 + (gx1 - gx0) * s / tmax
    gpy = lambda T: gy1 - (gy1 - gy0) * T / 100
    d.line([(gx0, gy1), (gx1, gy1)], fill=O.DIM, width=int(3 * S))
    d.line([(gx0, gy0), (gx0, gy1)], fill=O.DIM, width=int(3 * S))
    for T in (0, 50, 100):
        text(d, (gx0 - 12 * S, gpy(T)), f"{T}℃", 28, O.DIM, "rm", 3)
    for s in (0, 600, 1200):
        text(d, (gpx(s), gy1 + 10 * S), f"{s}秒", 28, O.DIM, "ma", 3)
    text(d, (gx0, gy0 - 40 * S), "真ん中の温度", 32, O.DIM, "la", 4)
    for i, r in enumerate((rc, rp)):
        m = r["t"] <= tt
        idx = np.nonzero(m)[0]
        if len(idx) < 2:
            continue
        sel = idx[:: max(1, len(idx) // 300)]
        pts = [(gpx(r["t"][j]), gpy(r["cen"][j])) for j in sel] + [(gpx(r["t"][idx[-1]]), gpy(r["cen"][idx[-1]]))]
        dim = hl is not None and hl != i
        d.line(pts, fill=cols[i] if not dim else (100, 100, 110), width=int(5 * S), joint="curve")
        ex, ey = pts[-1]
        d.ellipse([ex - 8 * S, ey - 8 * S, ex + 8 * S, ey + 8 * S], fill=cols[i] if not dim else (100, 100, 110))
    if P.get("diff") and frac >= 1:
        ya, yb = gpy(rc["cen"][-1]), gpy(rp["cen"][-1])
        xb = gpx(rp["end"]) - 40 * S
        d.line([(gpx(rc["end"]), ya), (xb, ya)], fill=(255, 140, 70), width=int(2 * S))
        arrow(d, (xb, ya), (xb, yb + 6 * S), O.WHITE, 4, 14)
        label(d, (xb - 90 * S, (ya + yb) / 2 + 40 * S), "＋16℃", 34, O.YEL)


def molecule(d, cx, cy, ang, r, plus=True, col=(225, 70, 70), ice=False):
    """水の分子。ang は プラス側(水素の側)の向き。"""
    hc = (235, 240, 250)
    for s in (-1, 1):
        a = ang + s * math.radians(52)
        hx, hy = cx + r * 1.05 * math.cos(a), cy + r * 1.05 * math.sin(a)
        d.ellipse([hx - r * 0.58, hy - r * 0.58, hx + r * 0.58, hy + r * 0.58], fill=hc, outline=(150, 160, 180), width=max(1, int(2 * S)))
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(150, 200, 235) if ice else col, outline=(255, 255, 255), width=max(1, int(2 * S)))
    if plus and r > 16 * S:
        d.text((cx, cy), "−", font=O.font(int(r * 0.9)), fill=O.WHITE, anchor="mm")
        for s in (-1, 1):
            a = ang + s * math.radians(52)
            d.text((cx + r * 1.05 * math.cos(a), cy + r * 1.05 * math.sin(a)), "＋", font=O.font(int(r * 0.6)), fill=(30, 60, 160), anchor="mm")


def _field_angle(t, period=1.6):
    """電場の向き(0=右, π=左)。半周期ごとに入れ替わる。"""
    n = int(t / (period / 2))
    return 0.0 if n % 2 == 0 else math.pi, (t % (period / 2)) / (period / 2), n


def sc_mol(img, box, t, k, P):
    """水の分子。mode: one(1 つを大きく)/ many / field(電波の向きにそろって回る)/ ice(氷: 固まって回れない)。"""
    bg(img)
    x0, y0, x1, y1 = box
    mode = P.get("mode", "many")
    if P.get("heat"):
        lay = Image.new("RGBA", img.size, (0, 0, 0, 0))
        ImageDraw.Draw(lay).rectangle(box, fill=(255, 90, 30, int(30 + 70 * k)))
        img.alpha_composite(lay)
    d = ImageDraw.Draw(img)
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    if mode == "one":
        r = min(x1 - x0, y1 - y0) * 0.17
        ang = -math.pi / 2 + 0.25 * math.sin(t * 0.9)
        molecule(d, cx, cy + 30 * S, ang, r)
        hx, hy = cx + r * 1.8 * math.cos(ang), cy + 30 * S + r * 1.8 * math.sin(ang)
        label(d, (cx + r * 2.4, cy - r * 1.0), "プラスの側（水素）", 36, (140, 190, 255))
        label(d, (cx + r * 2.4, cy + r * 1.3), "マイナスの側（酸素）", 36, (255, 140, 130))
        return
    rnd = random.Random(11)
    fa, fu, fn = _field_angle(t)
    field = mode in ("field", "ice")
    if field:
        ay = y0 + 46 * S
        L = (x1 - x0) * 0.22
        if fa == 0:
            arrow(d, (cx - L, ay), (cx + L, ay), O.YEL, 8, 30)
        else:
            arrow(d, (cx + L, ay), (cx - L, ay), O.YEL, 8, 30)
        label(d, (x0 + (x1 - x0) * 0.13, ay), "電波の向き", 32, O.YEL)
    if mode == "ice":
        r = min(x1 - x0, y1 - y0) * 0.055
        dx = r * 4.2
        dy = dx * 0.87
        pts = []
        ny = int((y1 - y0 - 150 * S) / dy)
        nx = int((x1 - x0 - 60 * S) / dx)
        for j in range(ny):
            for i in range(nx):
                px = x0 + (x1 - x0 - (nx - 1) * dx) / 2 + i * dx + (dx / 2 if j % 2 else 0) - dx / 4
                py = y0 + 130 * S + j * dy + dy / 2
                pts.append((px, py))
        for (ax, ay2) in pts:
            for (bx, by) in pts:
                if 0 < math.dist((ax, ay2), (bx, by)) < dx * 1.05 and (ax, ay2) < (bx, by):
                    d.line([(ax, ay2), (bx, by)], fill=(120, 170, 210), width=max(1, int(2 * S)))
        for n, (px, py) in enumerate(pts):
            base = rnd.uniform(0, 2 * math.pi)
            jit = 0.07 * math.sin(t * 9 + n)
            molecule(d, px, py, base + jit, r, plus=False, ice=True)
        label(d, (cx, y1 - 36 * S), "氷：分子が固まって、回れない", 36, O.WHITE)
        return
    r = min(x1 - x0, y1 - y0) * 0.06
    nx, ny = (7, 4) if LAND and (x1 - x0) > 1200 else (5, 5)
    gx0, gy0 = x0 + (x1 - x0) * 0.1, y0 + (y1 - y0) * (0.2 if field else 0.12)
    gw, gh = (x1 - x0) * 0.8, (y1 - y0) * (0.72 if field else 0.78)
    for j in range(ny):
        for i in range(nx):
            px = gx0 + gw * (i + 0.5) / nx + rnd.uniform(-0.18, 0.18) * gw / nx + 6 * S * math.sin(t * 1.3 + i + j)
            py = gy0 + gh * (j + 0.5) / ny + rnd.uniform(-0.15, 0.15) * gh / ny + 6 * S * math.cos(t * 1.1 + i * 2 + j)
            base = rnd.uniform(0, 2 * math.pi)
            spin = rnd.choice((-1, 1))
            lag = rnd.uniform(0, 0.25)
            if field:
                prev = math.pi - fa
                u = _ease((fu - lag) / 0.5)
                ang = prev + spin * math.pi * u + 0.25 * math.sin(t * 7 + i * 3 + j)
                ang = ang if fa == 0 else ang
            else:
                ang = base + 0.5 * math.sin(t * rnd.uniform(0.4, 1.0) + base)
            molecule(d, px, py, ang, r)
            if P.get("heat") and rnd.random() < 0.35:
                ph = (t * 1.7 + rnd.random()) % 1.0
                if ph < 0.35:
                    sx, sy = px + r * 2.2, py - r * 0.6
                    rr = r * 0.25 * (1 - ph / 0.35)
                    d.line([(sx - rr * 2, sy), (sx + rr * 2, sy)], fill=(255, 230, 120), width=int(3 * S))
                    d.line([(sx, sy - rr * 2), (sx, sy + rr * 2)], fill=(255, 230, 120), width=int(3 * S))
    if P.get("heat"):
        label(d, (cx, y1 - 36 * S), "こすれ合って、熱になる", 36, (255, 200, 120))


DEPTHS = [(0.915, "0.9GHz", "約13cm"), (2.45, "2.45GHz（電子レンジ）", "約1.9cm"), (5.8, "5.8GHz", "約3.5mm"), (20, "20GHz", "約0.4mm")]


def sc_depth(img, box, t, k, P):
    """周波数ごとの、電波の強さが 3 分の 1 になる深さ(対数の目盛り)。"""
    bg(img)
    x0, y0, x1, y1 = box
    d = ImageDraw.Draw(img)
    show = P.get("show", [])
    hl = P.get("hl")
    gx0, gx1 = x0 + (x1 - x0) * 0.08, x1 - (x1 - x0) * 0.06
    lo, hi = -1.0, 2.4                                         # 0.1mm 〜 25cm(log10 mm)
    px = lambda mm: gx0 + (gx1 - gx0) * (math.log10(mm) - lo) / (hi - lo)
    top, bot = y0 + (y1 - y0) * 0.1, y1 - (y1 - y0) * 0.12
    rh = (bot - top) / 4
    text(d, (gx0, top - 34 * S), "電波の強さが3分の1になる深さ（水）", 34, O.DIM, "la", 4)
    for mm, s in ((0.1, "0.1mm"), (1, "1mm"), (10, "1cm"), (100, "10cm")):
        x = px(mm)
        d.line([(x, top + 10 * S), (x, bot)], fill=(50, 64, 96), width=int(2 * S))
        text(d, (x, bot + 10 * S), s, 28, O.DIM, "ma", 3)
    for i, (f, name, val) in enumerate(DEPTHS):
        ry = top + rh * i
        on = f in show
        is_hl = f == hl
        col = O.YEL if is_hl else ((150, 210, 240) if on else (80, 90, 110))
        text(d, (gx0, ry + rh * 0.3), name, 38, col, "lm", 5)
        if not on:
            continue
        mm = dp(f * 1e9) * 1000
        bx1 = px(mm)
        by0, by1 = ry + rh * 0.52, ry + rh * 0.82
        grow = _ease(k * 2.5) if is_hl and not P.get("good") else 1.0
        bx1g = gx0 + (bx1 - gx0) * grow
        for x in range(int(gx0), int(bx1g), 3):
            u = (x - gx0) / max(1, bx1 - gx0)
            c = lerp(col, (30, 50, 90), u * 0.7)
            d.rectangle([x, by0, x + 3, by1], fill=c)
        ph = (t * 0.5 + i * 0.27) % 1.0
        dxp = gx0 + (bx1g - gx0) * ph
        d.ellipse([dxp - 7 * S, (by0 + by1) / 2 - 7 * S, dxp + 7 * S, (by0 + by1) / 2 + 7 * S], fill=(255, 255, 255))
        s = val + ("  ちょうどいい" if P.get("good") and f == 2.45 else "")
        label(d, (gx1, ry + rh * 0.3), s, 34, col, "rm")


def sc_absorb(img, box, t, k, P):
    """水が電波を吸う強さ(ε''、デバイの式)と周波数。山は約 20GHz、電子レンジは 2.45GHz。"""
    bg(img)
    x0, y0, x1, y1 = box
    d = ImageDraw.Draw(img)
    gx0, gx1 = x0 + (x1 - x0) * 0.08, x1 - (x1 - x0) * 0.05
    gy0, gy1 = y0 + (y1 - y0) * 0.2, y1 - (y1 - y0) * 0.14
    lo, hi = math.log10(0.5), math.log10(200)
    px = lambda f: gx0 + (gx1 - gx0) * (math.log10(f) - lo) / (hi - lo)
    py = lambda e: gy1 - (gy1 - gy0) * e / 40
    d.line([(gx0, gy1), (gx1, gy1)], fill=O.DIM, width=int(3 * S))
    d.line([(gx0, gy0), (gx0, gy1)], fill=O.DIM, width=int(3 * S))
    for f, s in ((1, "1GHz"), (10, "10GHz"), (100, "100GHz")):
        text(d, (px(f), gy1 + 10 * S), s, 28, O.DIM, "ma", 3)
    text(d, (gx0, gy0 - 60 * S), "水が電波を吸う強さ", 36, O.DIM, "la", 4)
    u = _ease(k * 1.5)
    pts = []
    for i in range(0, 241):
        lf = lo + (hi - lo) * i / 240
        if i / 240 > u:
            break
        f = 10 ** lf
        pts.append((px(f), py(eps(f * 1e9)[1])))
    if len(pts) > 1:
        d.line(pts, fill=(120, 200, 255), width=int(7 * S), joint="curve")
    fpk = 1 / (2 * math.pi * TAU) / 1e9
    if u >= 0.75:
        e = eps(fpk * 1e9)[1]
        d.ellipse([px(fpk) - 11 * S, py(e) - 11 * S, px(fpk) + 11 * S, py(e) + 11 * S], fill=O.WHITE)
        label(d, (px(fpk), py(e) - 56 * S), "一番よく吸う 約20GHz", 34, O.WHITE)
    if u >= 0.3:
        e = eps(2.45e9)[1]
        d.ellipse([px(2.45) - 11 * S, py(e) - 11 * S, px(2.45) + 11 * S, py(e) + 11 * S], fill=O.YEL)
        dashed(d, (px(2.45), py(e)), (px(2.45), gy1), t, O.YEL, 2, 10)
        label(d, (px(2.45) + (10 if LAND else 40) * S, py(e) - 70 * S), "電子レンジ 2.45GHz", 34, O.YEL)
    if u >= 1:
        ph = 0.5 + 0.5 * math.sin(t * 0.7)
        f = 10 ** (lo + (hi - lo) * ph)
        d.ellipse([px(f) - 6 * S, py(eps(f * 1e9)[1]) - 6 * S, px(f) + 6 * S, py(eps(f * 1e9)[1]) + 6 * S], fill=(255, 255, 255))


def sc_wavelen(img, box, t, k, P):
    """2.45GHz の波の長さ 12.2cm(定規つき)。"""
    bg(img)
    x0, y0, x1, y1 = box
    d = ImageDraw.Draw(img)
    gx0, gx1 = x0 + (x1 - x0) * 0.06, x1 - (x1 - x0) * 0.06
    span = 36.0 if LAND else 26.0
    cm = (gx1 - gx0) / span
    cy = y0 + (y1 - y0) * 0.42
    amp = (y1 - y0) * 0.18
    d.line([(gx0, cy), (gx1, cy)], fill=(80, 90, 120), width=int(2 * S))
    amp *= 0.93 + 0.07 * math.sin(t * 1.6)                     # 波は止めて、ゆっくり息をさせる(目盛りと山を合わせるため)
    pts = [(x, cy - amp * math.sin(2 * math.pi * (x - gx0) / (LAM0 * cm))) for x in range(int(gx0), int(gx1), 3)]
    d.line(pts, fill=(150, 220, 255), width=int(7 * S), joint="curve")
    ph = (t * 0.12) % 1.0                                         # 波の上を進む光の玉
    qx = gx0 + (gx1 - gx0) * ph
    qy = cy - amp * math.sin(2 * math.pi * (qx - gx0) / (LAM0 * cm))
    glow(img, qx, qy, 9 * S, (255, 240, 180))
    d = ImageDraw.Draw(img)
    ry = y0 + (y1 - y0) * 0.78
    d.rectangle([gx0, ry, gx1, ry + 40 * S], fill=(230, 210, 150))
    for c in range(int(span) + 1):
        x = gx0 + c * cm
        hh = 26 if c % 5 == 0 else 14
        d.line([(x, ry), (x, ry + hh * S)], fill=(60, 50, 30), width=int(2 * S))
        if c % 10 == 0:
            text(d, (x, ry + 44 * S), f"{c}cm", 26, O.DIM, "ma", 3)
    bx0 = gx0 + LAM0 * cm * 0.25
    bx1 = bx0 + LAM0 * cm
    by = ry - 30 * S
    d.line([(bx0, by), (bx1, by)], fill=O.YEL, width=int(5 * S))
    for x in (bx0, bx1):
        d.line([(x, by - 14 * S), (x, by + 14 * S)], fill=O.YEL, width=int(5 * S))
        dashed(d, (x, cy - amp), (x, by), t, (255, 214, 64), 2, 10)
    label(d, ((bx0 + bx1) / 2, by - 50 * S), "波の長さ 約12cm", 36, O.YEL)


def sc_standing(img, box, t, k, P):
    """庫内(幅 30.5cm = 波長の 2.5 倍)で、行く波とはね返る波が重なる。強い所は約 6cm おき。"""
    bg(img)
    x0, y0, x1, y1 = box
    d = ImageDraw.Draw(img)
    mode = P.get("mode", "sum")
    wx0, wx1 = x0 + (x1 - x0) * 0.08, x1 - (x1 - x0) * 0.08
    L = 2.5 * LAM0
    cm = (wx1 - wx0) / L
    cy = y0 + (y1 - y0) * 0.5
    amp = (y1 - y0) * 0.16
    for x in (wx0, wx1):
        d.rectangle([x - 16 * S, y0 + 40 * S, x, y1 - 40 * S] if x == wx0 else [x, y0 + 40 * S, x + 16 * S, y1 - 40 * S], fill=(160, 168, 180))
    text(d, (wx0 - 8 * S, y1 - 30 * S), "壁", 30, O.DIM, "rd", 4)
    text(d, (wx1 + 8 * S, y1 - 30 * S), "壁", 30, O.DIM, "ld", 4)
    w = 2 * math.pi / 2.4
    kx = 2 * math.pi / (LAM0 * cm)

    def line(f, col, wd):
        pts = [(x, cy - f(x - wx0)) for x in range(int(wx0), int(wx1) + 1, 3)]
        d.line(pts, fill=col, width=int(wd * S), joint="curve")
    a1 = 1.0 if mode == "reflect" else 0.45
    line(lambda u: amp * math.sin(kx * u - w * t), lerp((10, 18, 40), (255, 214, 64), a1), 5)
    line(lambda u: -amp * math.sin(-kx * u - w * t), lerp((10, 18, 40), (120, 220, 255), a1), 5)
    if mode == "reflect":
        label(d, (x0 + (x1 - x0) * 0.3, y0 + 70 * S), "行く波 →", 36, O.YEL)
        label(d, (x0 + (x1 - x0) * 0.7, y1 - 70 * S), "← はね返る波", 36, (120, 220, 255))
        return
    # 重なった波(その場で上下するだけ)と強い所
    line(lambda u: 2 * amp * math.sin(kx * u) * math.cos(w * t), O.WHITE, 8)
    n = 5
    xs = [wx0 + (LAM0 / 4 + i * LAM0 / 2) * cm for i in range(n)]
    for x in xs:
        glow(img, x, cy, 16 * S + 10 * S * abs(math.cos(w * t)), (255, 120, 40), 0.9)
    d = ImageDraw.Draw(img)
    for i in range(n + 1):
        x = wx0 + i * LAM0 / 2 * cm
        d.ellipse([x - 7 * S, cy - 7 * S, x + 7 * S, cy + 7 * S], outline=(140, 160, 200), width=int(3 * S))
    label(d, (x0 + (x1 - x0) * 0.5, y0 + 60 * S), "強い所（熱くなる）", 36, (255, 160, 80))
    if mode == "gap":
        by = cy + 2 * amp + 50 * S
        a, b = xs[1], xs[2]
        d.line([(a, by), (b, by)], fill=O.YEL, width=int(5 * S))
        for x in (a, b):
            d.line([(x, by - 14 * S), (x, by + 14 * S)], fill=O.YEL, width=int(5 * S))
        label(d, ((a + b) / 2, by + 56 * S), "約6cm", 38, O.YEL)


_PAT = {}


def _pattern(w, h, cm):
    """真上から見た強い所の並び(縦横とも半波長おき)。"""
    key = (int(w), int(h), round(cm, 2))
    if key not in _PAT:
        yy, xx = np.mgrid[0:int(h), 0:int(w)]
        kx = 2 * math.pi / (LAM0 * cm)
        I = (np.sin(kx * xx + 0.7) ** 2) * (np.sin(kx * 0.92 * yy + 0.3) ** 2)
        I = 0.6 * I + 0.4 * (np.sin(kx * 0.7 * (xx + yy) + 1.0) ** 2) * I ** 0.3
        _PAT[key] = I / I.max()
    return _PAT[key]


def sc_turn(img, box, t, k, P):
    """真上から見た庫内。強い所(オレンジ)がまだらに並ぶ。spin=True で皿が回り、食べ物が強い所を順番に通る。"""
    bg(img)
    x0, y0, x1, y1 = box
    bw, bh = x1 - x0, y1 - y0
    side = min(bw * 0.9, bh * 0.9)
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2 + 10 * S
    fx0, fy0 = cx - side / 2, cy - side / 2
    cm = side / 32.0
    I = _pattern(side, side, cm)
    spin = P.get("spin", True)
    if spin:
        base = np.zeros((int(side), int(side), 4), np.uint8)
        base[..., 0] = (30 + 225 * I).astype(np.uint8)
        base[..., 1] = (30 + 100 * I).astype(np.uint8)
        base[..., 2] = (50 - 20 * I).clip(0, 255).astype(np.uint8)
        base[..., 3] = (90 + 120 * I).astype(np.uint8)
        img.alpha_composite(Image.fromarray(base, "RGBA"), (int(fx0), int(fy0)))
        d = ImageDraw.Draw(img)
        pr = side * 0.42
        d.ellipse([cx - pr, cy - pr, cx + pr, cy + pr], outline=(230, 235, 245), width=int(6 * S))
        a = t * 0.6
        for j in range(3):
            aa = a + j * 2 * math.pi / 3
            d.line([(cx, cy), (cx + pr * math.cos(aa), cy + pr * math.sin(aa))], fill=(160, 170, 190), width=int(2 * S))
        # 食べ物(皿に乗って回る)。色は今いる場所の強さ
        fxc, fyc = cx + pr * 0.5 * math.cos(a), cy + pr * 0.5 * math.sin(a)
        ii = I[int(min(side - 1, max(0, fyc - fy0))), int(min(side - 1, max(0, fxc - fx0)))]
        r = side * 0.1
        d.ellipse([fxc - r, fyc - r, fxc + r, fyc + r], fill=lerp((90, 140, 220), (255, 110, 50), ii), outline=O.WHITE, width=int(4 * S))
        label(d, (cx, y0 + 40 * S) if LAND else (cx, cy + pr + 50 * S), "回る皿で、強い所を順番に通る", 34, O.WHITE)
    else:
        # まだらに温まった食べ物(真上から)
        fw, fh = (bw * 0.62, bh * 0.62) if LAND else (bw * 0.86, bh * 0.5)
        sub = _pattern(fw, fh, cm)
        T = 10 + 85 * sub
        rgb = np.zeros(sub.shape + (3,), np.uint8)
        for j, (a, ca) in enumerate(TSTOPS[:-1]):
            b, cb = TSTOPS[j + 1]
            m = (T >= a) & (T <= b)
            u = ((T - a) / (b - a))[m][:, None]
            rgb[m] = (np.array(ca) + (np.array(cb) - np.array(ca)) * u).astype(np.uint8)
        im = Image.fromarray(rgb, "RGB").filter(ImageFilter.GaussianBlur(3))
        ox, oy = int(cx - fw / 2), int(cy - fh / 2)
        img.paste(im, (ox, oy))
        d = ImageDraw.Draw(img)
        d.rounded_rectangle([ox, oy, ox + fw, oy + fh], int(10 * S), outline=O.WHITE, width=int(4 * S))
        rnd = random.Random(4)
        for i in range(14):                                     # 熱い所から湯気
            ys, xs = np.unravel_index(np.argsort(sub, axis=None)[-1 - i * 997 % sub.size], sub.shape)
            ph = (t * 0.4 + rnd.random()) % 1.0
            sx = ox + xs + 10 * S * math.sin(t * 2 + i)
            sy = oy + ys - ph * 120 * S
            rr = (6 + 10 * ph) * S
            d.ellipse([sx - rr, sy - rr, sx + rr, sy + rr], outline=(255, 255, 255), width=max(1, int(2 * S)))
        d.rounded_rectangle([ox, oy, ox + fw, oy + fh], int(10 * S), outline=O.WHITE, width=int(4 * S))
        legend(d, cx, oy + fh + 40 * S, 360 * S)
        label(d, (cx, oy - 50 * S), "熱い所と冷たい所が、まだらに", 36, O.WHITE)


def sc_shrink(img, box, t, k, P):
    """空気の中の波(12.2cm)と、水の中の波(1.39cm)。同じ縮尺。grape=True でブドウ 1 粒を並べる。"""
    bg(img)
    x0, y0, x1, y1 = box
    d = ImageDraw.Draw(img)
    gx0, gx1 = x0 + (x1 - x0) * 0.2, x1 - (x1 - x0) * 0.05
    span = 24.5 if LAND else 13.0
    cm = (gx1 - gx0) / span
    ya, yw = y0 + (y1 - y0) * 0.28, y0 + (y1 - y0) * 0.66
    amp = 60 * S
    text(d, (gx0 - 24 * S, ya), "空気の中", 38, O.WHITE, "rm", 5)
    pts = [(x, ya - amp * math.sin(2 * math.pi * ((x - gx0) / (LAM0 * cm) - t * 0.4))) for x in range(int(gx0), int(gx1), 3)]
    d.line(pts, fill=(150, 220, 255), width=int(6 * S), joint="curve")
    d.line([(gx0, ya + amp + 26 * S), (gx0 + LAM0 * cm, ya + amp + 26 * S)], fill=O.DIM, width=int(4 * S))
    label(d, (gx0 + LAM0 * cm / 2, ya + amp + 66 * S), "約12cm", 34, O.DIM)
    water = P.get("water", True)
    d.rectangle([gx0, yw - amp - 20 * S, gx1, yw + amp + 20 * S], fill=(30, 70, 140) if water else (24, 34, 60))
    text(d, (gx0 - 24 * S, yw), "水の中", 38, O.WHITE if water else (100, 110, 130), "rm", 5)
    if not water:
        return
    lw = LAM_W * cm
    pts = [(x, yw - amp * 0.8 * math.sin(2 * math.pi * ((x - gx0) / lw - t * 0.4))) for x in range(int(gx0), int(gx1), 2)]
    d.line(pts, fill=(200, 240, 255), width=int(5 * S), joint="curve")
    bx = gx0 + lw * 2
    by = yw + amp + 50 * S
    d.line([(bx, by), (bx + lw, by)], fill=O.YEL, width=int(5 * S))
    for x in (bx, bx + lw):
        d.line([(x, by - 12 * S), (x, by + 12 * S)], fill=O.YEL, width=int(5 * S))
    label(d, (bx + lw / 2 + (0 if LAND else 60) * S, by + 50 * S), "約1.4cm", 34, O.YEL)
    if P.get("grape"):
        gr = 0.8 * cm                                          # 直径 1.6cm ほどの粒
        gcx, gcy = bx + lw * 4.5, by + 20 * S
        d.ellipse([gcx - gr, gcy - gr, gcx + gr, gcy + gr], fill=(110, 40, 140), outline=(200, 150, 230), width=int(3 * S))
        d.ellipse([gcx - gr * 0.5, gcy - gr * 0.6, gcx - gr * 0.1, gcy - gr * 0.25], fill=(190, 140, 220))
        d.line([(gcx, gcy - gr), (gcx + 4 * S, gcy - gr - 16 * S)], fill=(120, 160, 80), width=int(4 * S))
        label(d, (gcx + gr + 110 * S if LAND else gcx + 40 * S, gcy + (0 if LAND else 80) * S), "ブドウ1粒", 34, (210, 170, 240))


def sc_grape(img, box, t, k, P):
    """半分に切ったブドウ 2 つ。触れ合う所に電波が集まり、火花が出る。"""
    bg(img)
    x0, y0, x1, y1 = box
    d = ImageDraw.Draw(img)
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2 + 20 * S
    r = min(x1 - x0, y1 - y0) * 0.24
    gap = r * 0.22
    # 切り口(平らな面)を向かい合わせた半球 2 つ。左は左半分の円、右は右半分の円
    for s, (a0, a1) in ((-1, (90, 270)), (1, (270, 90))):
        ox = cx + s * gap
        d.pieslice([ox - r, cy - r, ox + r, cy + r], a0, a1, fill=(120, 50, 150), outline=(200, 150, 230), width=int(4 * S))
        rr = r * 0.88
        d.pieslice([ox - rr, cy - rr, ox + rr, cy + rr], a0, a1, fill=(190, 225, 150))
        d.ellipse([ox + s * r * 0.35 - r * 0.08, cy - r * 0.2, ox + s * r * 0.35 + r * 0.08, cy + r * 0.2], fill=(160, 200, 120))
    # 皮でつながった所
    d.rectangle([cx - gap - 2 * S, cy + r - 22 * S, cx + gap + 2 * S, cy + r], fill=(120, 50, 150))
    # 電波が集まる所(脈打つ)と火花
    p = 0.5 + 0.5 * math.sin(t * 6)
    glow(img, cx, cy + r * 0.85, 10 * S + 10 * S * p, (255, 230, 140), 0.9)
    d = ImageDraw.Draw(img)
    rnd = random.Random(int(t * 12))
    for i in range(9):
        a = rnd.uniform(0, 2 * math.pi)
        L = rnd.uniform(0.2, 0.55) * r
        sx, sy = cx, cy + r * 0.85
        d.line([(sx, sy), (sx + L * math.cos(a), sy + L * math.sin(a))], fill=(255, 245, 190), width=int(3 * S))
    label(d, (cx, y0 + 50 * S), "粒の中に電波が集まる", 36, O.WHITE)


def sc_icewater(img, box, t, k, P):
    """水と氷に電波を当てる。水は約 1.9cm で 3 分の 1、氷は約 12m(ほぼ素通り)。横は 30cm。"""
    bg(img)
    x0, y0, x1, y1 = box
    d = ImageDraw.Draw(img)
    gx0, gx1 = x0 + (x1 - x0) * (0.16 if LAND else 0.22), x1 - (x1 - x0) * 0.04
    span = 30.0
    cm = (gx1 - gx0) / span
    lanes = [("水", (30, 80, 150), DP, LAM_W, 0.32), ("氷", (170, 210, 235), DP_ICE, LAM0 / math.sqrt(3.17), 0.72)]
    hh = (y1 - y0) * 0.16
    for i, (name, col, D, lam, fy) in enumerate(lanes):
        y = y0 + (y1 - y0) * fy
        on = i == 0 or P.get("ice", True)
        d.rectangle([gx0, y - hh, gx1, y + hh], fill=col if on else (24, 34, 60), outline=O.WHITE if on else (60, 70, 90), width=int(3 * S))
        if i == 1 and on:
            rnd = random.Random(2)
            for _ in range(18):
                cx2, cy2 = rnd.uniform(gx0 + 20, gx1 - 20), rnd.uniform(y - hh + 10, y + hh - 10)
                rr = rnd.uniform(10, 26) * S
                d.line([(cx2 - rr, cy2), (cx2 + rr, cy2)], fill=(230, 245, 255), width=max(1, int(2 * S)))
                d.line([(cx2 - rr * 0.5, cy2 - rr * 0.86), (cx2 + rr * 0.5, cy2 + rr * 0.86)], fill=(230, 245, 255), width=max(1, int(2 * S)))
        text(d, (gx0 - 66 * S, y), name, 44, O.WHITE if on else (100, 110, 130), "rm", 5)
        if not on:
            continue
        hsquiggle(d, gx0 - 50 * S, gx0, y, t, (255, 230, 120), amp=hh * 0.6 / S, lam=lam * cm / S, w=5)
        hsquiggle(d, gx0, gx1, y, t, (255, 230, 120), amp=hh * 0.6 / S, lam=lam * cm / S, w=5, decay=(cm, D))
        if i == 0:
            x = gx0 + D * cm
            d.line([(x, y - hh), (x, y + hh)], fill=O.YEL, width=int(4 * S))
            label(d, (gx0 + (x1 - x0) * 0.32, y - hh - 44 * S), "約1.9cmで3分の1", 34, O.YEL)
        else:
            label(d, (gx0 + (gx1 - gx0) * 0.62, y - hh - 44 * S), "約12mで3分の1（ほぼ素通り）", 34, O.YEL)
    for c in (0, 10, 20, 30):
        text(d, (gx0 + c * cm, y1 - 30 * S), f"{c}cm", 26, O.DIM, "ma", 3)


def sc_thaw(img, box, t, k, P):
    """凍った食べ物の断面。mode: outer(外は煮え、中は凍ったまま)/ melt(解けた所が電波を吸う)/ runaway(そこだけ煮える)。"""
    bg(img)
    x0, y0, x1, y1 = box
    bw, bh = x1 - x0, y1 - y0
    fw, fh = (bw * 0.78, min(bh * 0.6, bw * 0.45)) if LAND else (bw * 0.86, bh * 0.52)
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2 + 20 * S
    fx0, fy0 = cx - fw / 2, cy - fh / 2
    mode = P.get("mode", "outer")
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([fx0, fy0, fx0 + fw, fy0 + fh], int(18 * S), fill=(190, 220, 240))
    rnd = random.Random(8)
    for _ in range(40):                                        # 氷の結晶の模様
        px, py = rnd.uniform(fx0 + 20, fx0 + fw - 20), rnd.uniform(fy0 + 20, fy0 + fh - 20)
        rr = rnd.uniform(8, 20) * S
        for a in range(3):
            aa = a * math.pi / 3
            d.line([(px - rr * math.cos(aa), py - rr * math.sin(aa)), (px + rr * math.cos(aa), py + rr * math.sin(aa))], fill=(235, 248, 255), width=max(1, int(2 * S)))
    if mode == "outer":
        rim = fh * 0.14
        lay = Image.new("RGBA", img.size, (0, 0, 0, 0))
        dl = ImageDraw.Draw(lay)
        for i in range(int(rim)):
            a = int(255 * (1 - i / rim) ** 0.7)
            c = (200, 70, 40, a)
            dl.rounded_rectangle([fx0 + i, fy0 + i, fx0 + fw - i, fy0 + fh - i], int(max(2, 18 * S - i)), outline=c, width=1)
        img.alpha_composite(lay)
        d = ImageDraw.Draw(img)
        label(d, (cx, fy0 - 50 * S), "外は煮える", 36, (255, 140, 100))
        label(d, (cx, cy), "中は凍ったまま", 36, (170, 220, 255))
    else:
        spots = [(rnd.uniform(0.15, 0.85), rnd.uniform(0.15, 0.85), rnd.uniform(0.6, 1.2)) for _ in range(6)]
        for j, (u, v, s) in enumerate(spots):
            sx, sy = fx0 + fw * u, fy0 + fh * v
            appear = _ease(k * 3 - j * 0.35) if mode == "melt" else 1.0
            if appear <= 0:
                continue
            if mode == "melt":
                r = (16 + 10 * appear) * S * s
                c = lerp((90, 160, 230), (240, 150, 60), _ease(k * 2 - 0.6 - j * 0.15))
            else:
                r = (26 + 40 * _ease(k * 1.3)) * S * s
                c = lerp((240, 150, 60), (220, 40, 40), _ease(k * 1.5))
            glow(img, sx, sy, r, c, 1.0)
            d = ImageDraw.Draw(img)
            for q in range(3):                                 # 電波がその場所へ集まる
                ph = (t * 0.8 + q / 3 + j * 0.1) % 1.0
                rr = r * (2.6 - 1.6 * ph)
                d.ellipse([sx - rr, sy - rr, sx + rr, sy + rr], outline=(255, 240, 160), width=max(1, int(2 * S)))
        d.rounded_rectangle([fx0, fy0, fx0 + fw, fy0 + fh], int(18 * S), outline=O.WHITE, width=int(4 * S))
        label(d, (cx, fy0 - 50 * S), "解けた所だけが電波を吸う" if mode == "melt" else "熱い所はさらに解け、さらに吸う", 36, O.WHITE)
        return
    d.rounded_rectangle([fx0, fy0, fx0 + fw, fy0 + fh], int(18 * S), outline=O.WHITE, width=int(4 * S))
    for i in range(5):                                          # 湯気
        ph = (t * 0.5 + i * 0.2) % 1.0
        sx = fx0 + fw * (0.15 + 0.17 * i) + 8 * S * math.sin(t * 2 + i)
        sy = fy0 - ph * 90 * S
        r = (6 + 10 * ph) * S
        d.ellipse([sx - r, sy - r, sx + r, sy + r], outline=(255, 255, 255), width=max(1, int(2 * S)))


KINDS = dict(slab=sc_slab, oven=sc_oven, field=sc_field, decay=sc_decay, heat=sc_heat, pulse=sc_pulse, mol=sc_mol, depth=sc_depth,
             absorb=sc_absorb, wavelen=sc_wavelen, standing=sc_standing, turn=sc_turn, shrink=sc_shrink, grape=sc_grape,
             icewater=sc_icewater, thaw=sc_thaw)


def region(P):
    if P.get("panel"):
        return (0, 100, W * 0.5, 880) if LAND else (0, 230, W, 740)
    return (0, 100, W, 880) if LAND else (0, 240, W, 1480)


def paint(sc, t, k):
    img = Image.new("RGBA", (W, H), (10, 18, 40, 255))
    KINDS[sc["kind"]](img, region(sc), t, k, sc)
    return img


def draw(img, dr, t, ctx):
    lines, defs = ctx["lines"], ctx["defs"]
    scs = ctx.setdefault("_scenes", mapscene.scenes(lines, defs))
    cur = ctx["cur"] or lines[0]
    i = next(j for j, l in enumerate(lines) if l["id"] == cur["id"])
    now, prev = scs[i], (scs[i - 1] if i > 0 else None)
    k = ctx["k"]
    QUIET[0] = defs.get(cur["id"], {}).get("style") == "question" and not ctx.get("cta")
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

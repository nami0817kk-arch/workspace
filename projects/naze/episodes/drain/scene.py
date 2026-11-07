"""海の水を全部抜いたら(世界版)の画面。下地は世界の立体の地図(naze/worldmap.py)に「海面を下げる」層を足したものと、ここで描く図:

  地図の層 drain  {level: 50, frm: 0, fall_s: 3}  海面を frm から level まで下げる。出てきた海の底を砂と岩の色に塗り、残る水はそのまま
  slice    海を切った断面(ETOPO 2022、cache/etopo/world_sur.npy)。a→b の線に沿って、海の底・陸と、下がっていく水面
  icons    同じ物を n 個並べる(japan)。hl=最初の何個を色付きに
  bars     棒で比べる。cards は答えの並べ直し

数字は sim/calc.txt と sim/straits.txt。"""
from __future__ import annotations

import math
from pathlib import Path

import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

from naze import overlay as ov
from naze import shots, worldmap
from naze.config import CACHE, H, W

HERE = Path(__file__).resolve().parent
LAND = W > H
STEPS = ["1 抜いていく", "2 最初の200m", "3 海の中の山脈", "4 一気に干上がる", "5 最後の水たまり"]
YEL, WHITE, NAVY, DIM = ov.YEL, ov.WHITE, ov.NAVY, ov.DIM
RED, BLUE, ICE = (240, 90, 80), (120, 190, 255), (226, 238, 248)
LEVEL = 50.0


def region():
    return (0, 110, W, 905) if LAND else (0, 230, W, 1450)


def ease(u):
    u = max(0.0, min(1.0, u))
    return u * u * (3 - 2 * u)


def text(d, xy, s, size, col=WHITE, anchor="mm", sw=6, reg=True):
    f = ov.font(size)
    d.text(xy, s, font=f, fill=col, anchor=anchor, stroke_width=sw, stroke_fill=NAVY)
    if reg:
        ov.BOXES.append(("label", d.textbbox(xy, s, font=f, anchor=anchor), s, 1.0))


def back(img):
    g = np.linspace(0, 1, H, dtype=np.float32)[:, None, None]
    a = np.array([10, 20, 40], np.float32) * (1 - g) + np.array([24, 40, 70], np.float32) * g
    img.paste(Image.fromarray(np.broadcast_to(a, (H, W, 3)).astype(np.uint8)).convert("RGBA"), (0, 0))



# ---- 海面を下げる地図 ----------------------------------------------------------------------------------
DRY = [(-11000, (52, 42, 40)), (-8000, (72, 60, 54)), (-5000, (104, 86, 72)), (-3000, (128, 104, 84)),
       (-1000, (152, 124, 94)), (-200, (178, 152, 112)), (0, (204, 184, 140))]


class DrainMap(worldmap.Map):
    """worldmap.Map に drain の層を足す。下地ごとに、干上がった海の底の色(深さの色分け×陰影)と高さを 1 回作って持つ。"""

    def _dry(self, b):
        if getattr(b, "_drypyr", None) is None:
            e = b.e
            sh = worldmap.shade_of(e, 40075000 / 360 / b.ppd)
            col = np.zeros(e.shape + (3,), np.float32)
            xs = [s[0] for s in DRY]
            for c in range(3):
                col[..., c] = np.interp(np.minimum(e, 0), xs, [s[1][c] for s in DRY])
            col *= np.clip(0.5 + 0.5 * sh, 0.4, 1.45)[..., None]
            if col.shape[:2] != b.levels[0].shape[:2]:
                col = cv2.resize(col, (b.levels[0].shape[1], b.levels[0].shape[0]), interpolation=cv2.INTER_LINEAR)
                e = cv2.resize(e, (b.levels[0].shape[1], b.levels[0].shape[0]), interpolation=cv2.INTER_LINEAR)
            cp, ep = [np.clip(col, 0, 255).astype(np.uint8)], [np.where(e < 0, e, 9999).astype(np.float32)]
            while len(cp) < len(b.levels):
                cp.append(cv2.pyrDown(cp[-1]))
                ep.append(cv2.pyrDown(ep[-1]))
            b._drypyr = (cp, ep)
        return b._drypyr

    def layer(self, img, v, L, a, k):
        if L["kind"] != "drain":
            return super().layer(img, v, L, a, k)
        if a <= 0:
            return
        b, lv = self.best(v)
        cp, ep = self._dry(b)
        e = self._gather(self._warp(b, v, ep[lv], lv, 9999, ext=True), fill=9999)
        col = self._gather(self._warp(b, v, cp[lv], lv, 0, ext=True), fill=0)
        frm = L.get("frm", 0.0)
        lvl = frm + (L.get("level", LEVEL) - frm) * ease(L.get("_u", 9.0) / L.get("fall_s", 3.0))
        m = np.clip((e + lvl) / max(8.0, lvl * 0.01) + 0.5, 0, 1).astype(np.float32) * (e < 9000)
        m = cv2.GaussianBlur(m, (0, 0), 0.8)
        out = np.zeros((H, W, 4), np.uint8)
        out[..., :3] = col[..., :3]
        out[..., 3] = (m * 255 * a).astype(np.uint8)
        img.alpha_composite(Image.fromarray(out, "RGBA"))
        eg = cv2.morphologyEx((m > 0.5).astype(np.uint8) * 255, cv2.MORPH_GRADIENT, np.ones((3, 3), np.uint8)).astype(np.float32) / 255
        e4 = np.zeros((H, W, 4), np.uint8)
        e4[..., :3] = (205, 240, 255)
        e4[..., 3] = (np.clip(cv2.GaussianBlur(eg, (0, 0), 2) * 0.7 + eg * 0.5, 0, 1) * 170 * a).astype(np.uint8)
        img.alpha_composite(Image.fromarray(e4, "RGBA"))


MAP = DrainMap(lat0=32, bases=[((-180, -60, 179.99, 84), 4),
                               ((90, -15, 179.99, 60), 6), ((-30, 25, 40, 66), 6), ((-180, 45, -140, 75), 6),
                               ((-60, -40, 20, 50), 5)])

# ---- 海を切った断面 --------------------------------------------------------------------------------------
_Z = {}


def world():
    if "z" not in _Z:
        _Z["z"] = np.load(CACHE / "etopo" / "world_sur.npy").astype(np.float32)
    return _Z["z"]


def profile(a, b, n=1400):
    """a→b(経度, 緯度)をまっすぐ(経緯度で線形に)結んで高さを引く。0.1 度の格子。"""
    z = world()
    lo = np.linspace(a[0], b[0], n)
    la = np.linspace(a[1], b[1], n)
    i = np.clip((90 - la) / 0.1 - 0.5, 0, z.shape[0] - 1).astype(np.float32)
    j = (((lo + 180) / 0.1 - 0.5) % z.shape[1]).astype(np.float32)
    return cv2.remap(z, j[None, :], i[None, :], cv2.INTER_LINEAR, borderMode=cv2.BORDER_WRAP)[0]


def draw_slice(img, sc, t, u):
    back(img)
    x0, y0, x1, y1 = region()
    x0, x1 = x0 + (90 if LAND else 40), x1 - (90 if LAND else 40)
    top = y0 + (150 if sc.get("title") else 90)
    zmax, zmin = sc.get("zmax", 2000), sc.get("zmin", -11000)
    bot = y1 - (70 if sc.get("note") else 30)
    p = profile(sc["a"], sc["b"])
    n = len(p)
    X = x0 + (x1 - x0) * np.arange(n) / (n - 1)

    def Y(z):
        return top + (zmax - np.asarray(z)) / (zmax - zmin) * (bot - top)

    lv = -(sc.get("frm", 0) + (sc.get("level", 0) - sc.get("frm", 0)) * ease(u * 1.6))
    d = ImageDraw.Draw(img, "RGBA")
    ys = Y(p)
    wl = Y(lv)
    for i in range(n - 1):                                        # 水(水面より下で、底より上)
        if p[i] < lv:
            d.rectangle([X[i], wl, X[i + 1] + 1, ys[i]], fill=(40, 110, 200, 235))
    poly = [(X[0], bot + 4)] + list(zip(X, ys)) + [(X[-1], bot + 4)]
    d.polygon(poly, fill=(120, 98, 80, 255))
    land = p > 0
    for i in range(n - 1):
        if land[i]:
            d.rectangle([X[i], ys[i], X[i + 1] + 1, Y(0)], fill=(96, 140, 72, 255))
    dry = (p < 0) & (p >= lv)
    for i in range(n - 1):
        if dry[i]:
            d.line([(X[i], ys[i]), (X[i + 1], ys[i + 1])], fill=(226, 196, 140, 255), width=5)
    d.line(list(zip(X, ys)), fill=(60, 46, 38, 255), width=2)
    d.line([(x0, Y(0)), (x1, Y(0))], fill=(255, 255, 255, 120), width=2)
    text(d, (x0 + 8, Y(0) - 8), "いまの海面", 30 if LAND else 28, WHITE, "ld")
    if abs(lv) > 1:
        d.line([(x0, wl), (x1, wl)], fill=YEL + (230,), width=4)
        text(d, (x1 - 8, wl - 8), f"海面 −{abs(lv):,.0f}m", 40 if LAND else 34, YEL, "rd")
    for frac, z_, s, *c in sc.get("labels", []):
        if u > 0.25:
            text(d, (x0 + (x1 - x0) * frac, Y(z_)), s, 40 if LAND else 34, tuple(c[0]) if c else WHITE)
    for frac, s in sc.get("ends", []):
        text(d, (x0 + (x1 - x0) * frac, bot + 30), s, 34 if LAND else 30, DIM)
    if sc.get("title"):
        text(d, (W / 2, y0 + 55), sc["title"], 58 if LAND else 46, YEL)
    if sc.get("note"):
        text(d, (W / 2, y1 - 10), sc["note"], 38 if LAND else 32, WHITE, "md")


_JP = []


def _japan():
    """日本の大きい島の形を、真ん中 (0, 0)・半分の幅 1 に縮めた点の列で。"""
    if not _JP:
        rings = sorted(worldmap.shapes("JPN"), key=len, reverse=True)[:4]
        pts = np.array([p for r in rings for p in r])
        c = (pts.max(0) + pts.min(0)) / 2
        k = 2 / (pts.max(0) - pts.min(0)).max()
        for r in rings:
            _JP.append([((x - c[0]) * k * 0.85, -(y - c[1]) * k) for x, y in r[::3]])
    return _JP


def _icon(d, kind, cx, cy, s, a, hl):
    A_ = int(255 * a)
    col = (BLUE if hl else (150, 160, 180))
    if kind == "japan":                                       # 日本の形(Natural Earth の大きい島 4 つ)
        for ring in _japan():
            d.polygon([(cx + x * s, cy + y * s) for x, y in ring], fill=(RED if hl else (230, 230, 240)) + (A_,))
    elif kind == "city":
        for j, (dx, hh) in enumerate(((-0.6, 0.9), (-0.15, 1.4), (0.35, 1.1), (0.75, 0.7))):
            d.rectangle([cx + dx * s - s * 0.2, cy + s * 0.7 - hh * s, cx + dx * s + s * 0.2, cy + s * 0.7], fill=col + (A_,))
        if hl:
            d.rectangle([cx - s, cy + s * 0.1, cx + s, cy + s * 0.75], fill=(40, 110, 200, int(A_ * 0.8)))
    elif kind == "dome":
        d.chord([cx - s, cy - s * 0.7, cx + s, cy + s * 0.7], 180, 360, fill=(230, 236, 246, A_))
        d.rectangle([cx - s, cy, cx + s, cy + s * 0.2], fill=(180, 190, 206, A_))


def draw_icons(img, sc, t, u):
    back(img)
    x0, y0, x1, y1 = region()
    d = ImageDraw.Draw(img, "RGBA")
    n, kind, hl = sc["n"], sc["kind"], sc.get("hl", 0)
    if kind == "floor":
        s = (y1 - y0 - 160) / n
        bw = 150 if LAND else 120
        cx = W * (0.62 if LAND else 0.5)
        shown = int(round(n * ease(u * 2.2)))
        for i in range(shown):
            yb = y1 - 30 - i * s
            d.rectangle([cx - bw, yb - s + 2, cx + bw, yb], fill=(200, 206, 220), outline=NAVY, width=1)
            for wx in range(-bw + 14, bw - 10, 34):
                d.rectangle([cx + wx, yb - s * 0.75, cx + wx + 16, yb - s * 0.3], fill=(90, 120, 170))
        wy = y1 - 30 - n * s * ease(u * 1.6)
        d.rectangle([cx - bw - 60, wy, cx + bw + 60, y1 - 30], fill=(40, 110, 200, 70), outline=BLUE + (200,), width=3)
        text(d, (cx + bw + 30, y1 - 30 - shown * s), f"{shown}階", 64 if LAND else 52, YEL, "lm")
    else:
        cols = sc.get("cols", (10 if LAND else 6) if n > 12 else min(n, 5 if LAND else 3))
        rows = math.ceil(n / cols)
        cell = min((x1 - x0 - 160) / cols, (y1 - y0 - 240) / rows)
        s = cell * 0.40
        gx0 = W / 2 - cell * (cols - 1) / 2
        gy0 = (y0 + y1) / 2 + 40 - cell * (rows - 1) / 2
        hk = ease((u - 0.45) * 3) if hl else 0
        for i in range(n):
            a = ease(u * 3.5 - i * (1.2 / max(4, n)))
            if a <= 0:
                continue
            r_, c_ = divmod(i, cols)
            _icon(d, kind, gx0 + c_ * cell, gy0 + r_ * cell - (1 - a) * 20, s, a, i < hl * hk)
    if sc.get("title"):
        text(d, (W / 2, y0 + 60), sc["title"], 64 if LAND else 52, YEL)
    if sc.get("note"):
        text(d, (W / 2, y1 - 6), sc["note"], 42 if LAND else 36, WHITE, "md")


def draw_bars(img, sc, t, u):
    back(img)
    x0, y0, x1, y1 = region()
    d = ImageDraw.Draw(img, "RGBA")
    items = sc["items"]
    vmax = max(v for _, v, _ in items)
    bx0 = x0 + (520 if LAND else 60)
    vw = max(d.textlength(sc.get("fmt", "{}").format(v), font=ov.font(50 if LAND else 44)) for _, v, _ in items)
    bx1 = x1 - max(320 if LAND else 260, vw + 60)                # 値の字が右にはみ出さない幅を空ける
    top = y0 + (140 if sc.get("title") else 60)
    gap = min(150 if LAND else 220, (y1 - top) / len(items))
    for i, (name, v, col) in enumerate(items):
        a = ease(u * 2.4 - i * 0.35)
        y = top + i * gap
        if LAND:
            text(d, (bx0 - 30, y + 40), name, 46, WHITE, "rm")
            yb = y + 10
        else:
            text(d, (bx0, y + 10), name, 40, WHITE, "lm")
            yb = y + 50
        L = (bx1 - bx0) * v / vmax * a
        d.rounded_rectangle([bx0, yb, bx0 + max(8, L), yb + 64], 10, fill=tuple(col) + (240,))
        if a > 0.2:
            text(d, (bx0 + L + 20, yb + 32), sc.get("fmt", "{}").format(v), 50 if LAND else 44, tuple(col), "lm")
    if sc.get("title"):
        text(d, (W / 2, y0 + 50), sc["title"], 60 if LAND else 48, YEL)
    if sc.get("note"):
        text(d, (W / 2, y1 - 10), sc["note"], 42 if LAND else 36, WHITE, "md")


def draw_cards(img, sc, t, u):
    shots._blur_back(img, MAP, sc, t)
    items, n = sc["items"], sc.get("n", len(sc["items"]))
    x0, x1 = (W * 0.16, W * 0.84) if LAND else (W * 0.06, W * 0.94)
    top, gap = (H * 0.12, H * 0.136) if LAND else (H * 0.16, H * 0.125)
    hh = gap * 0.82
    d = ImageDraw.Draw(img, "RGBA")
    for i, (title, sub) in enumerate(items[:n]):
        a = 1.0 if i < n - 1 else ease(u * 4)
        y = top + i * gap + (1 - a) * 30
        d.rounded_rectangle([x0, y, x1, y + hh], 18, fill=NAVY + (int(225 * a),), outline=YEL + (int(255 * a),) if i == n - 1 else (255, 255, 255, int(110 * a)), width=3)
        d.ellipse([x0 + 20, y + hh / 2 - 32, x0 + 84, y + hh / 2 + 32], fill=YEL + (int(255 * a),))
        d.text((x0 + 52, y + hh / 2), str(i + 1), font=ov.font(44), fill=NAVY, anchor="mm")
        d.text((x0 + 108, y + hh / 2 - 16), title, font=ov.font(46 if LAND else 38), fill=(255, 255, 255, int(255 * a)), anchor="lm")
        d.text((x0 + 108, y + hh / 2 + 28), sub, font=ov.font(30 if LAND else 28), fill=DIM + (int(255 * a),), anchor="lm")
        ov.BOXES.append(("label", (x0, y, x1, y + hh), title, 1.0))


CUSTOM = dict(cards=draw_cards, slice=draw_slice, icons=draw_icons, bars=draw_bars)
_orig = shots.render_one


def _render_one(img, mp, t, ctx, i, steps=None):
    sc = shots._scenes(ctx)[i]
    shot = (sc or {}).get("shot", "map")
    if shot not in CUSTOM:
        return _orig(img, mp, t, ctx, i, steps)
    lines = ctx["lines"]
    j = i
    while j > 0 and shots._scenes(ctx)[j - 1] is sc:
        j -= 1
    k = i
    while k + 1 < len(lines) and shots._scenes(ctx)[k + 1] is sc:
        k += 1
    t0 = worldmap.start_of(sc, lines, lines[j]) if sc.get("on") else lines[j]["start"]
    t1 = lines[k]["end"]
    u = max(0.0, min(1.0, (t - t0) / max(1e-6, t1 - t0)))
    CUSTOM[shot](img, sc, t, u)
    if steps and sc.get("step") is not None:
        mp.steps_band(img, steps, sc["step"])


shots.render_one = _render_one


def draw(img, dr, t, ctx):
    shots.draw(img, t, ctx, MAP, steps=STEPS if LAND else None)


def sfx_for(lines_def, L):
    return shots.sfx(lines_def, L)


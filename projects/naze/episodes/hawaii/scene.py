"""ハワイの水はどこから(地理)の画面。下地は立体の地図(naze/worldmap.py。線・矢印・札・地名はそちらの層)と、ここで描く図:

  slice    島を切った断面(Terrain Tiles、cache/etopo/win_hawaii.npy)。a→b の線に沿って山の形・海の底。
           wind=True で風上から風が吹き上がって雲と雨になる絵、inv=高さ で逆転層の線(雲はそこで止まる)、wet=風上の緑の割合
  lens     島の地下の断面。雨がしみこみ、海水の上に真水がレンズの形で浮く
  icons    同じ物を n 個並べる(japan)。bars は棒で比べる。cards は答えの並べ直し

数字は sim/facts.md。"""
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
STEPS = ["1 雨の島", "2 風", "3 山の高さ", "4 地下の水", "5 答え"]
YEL, WHITE, NAVY, DIM = ov.YEL, ov.WHITE, ov.NAVY, ov.DIM
RED, BLUE, ICE = (240, 90, 80), (120, 190, 255), (226, 238, 248)


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



# ---- 地図 -------------------------------------------------------------------------------------------------
MAP = worldmap.Map(lat0=20, bases=[((-180, -60, 179.99, 84), 4), ((-170, 10, -110, 45), 5), ((-161, 18.5, -154.5, 22.5), 9),
                                   ((-160.6, 21.4, -158.8, 22.7), 11), ((-158.7, 21.0, -157.4, 21.9), 10),
                                   ((-156.4, 18.7, -154.6, 20.5), 10)])

# ---- 島を切った断面 --------------------------------------------------------------------------------------
_Z = {}
HI = (-160.5, 18.8, -154.7, 22.4)
PPD = 240


def hz():
    if "z" not in _Z:
        _Z["z"] = cv2.GaussianBlur(np.load(CACHE / "etopo" / "win_hawaii.npy").astype(np.float32), (0, 0), 0.8)
    return _Z["z"]


def profile(a, b, n=900):
    z = hz()
    lo = np.linspace(a[0], b[0], n)
    la = np.linspace(a[1], b[1], n)
    i = ((HI[3] - la) * PPD).astype(np.float32)
    j = ((lo - HI[0]) * PPD).astype(np.float32)
    return cv2.remap(z, j[None, :], i[None, :], cv2.INTER_LINEAR, borderMode=cv2.BORDER_REPLICATE)[0]


def draw_slice(img, sc, t, u):
    back(img)
    x0, y0, x1, y1 = region()
    x0, x1 = x0 + (90 if LAND else 40), x1 - (90 if LAND else 40)
    top = y0 + (150 if sc.get("title") else 90)
    zmax, zmin = sc.get("zmax", 5000), sc.get("zmin", -1500)
    bot = y1 - (70 if sc.get("note") else 30)
    p = profile(sc["a"], sc["b"])
    n = len(p)
    X = x0 + (x1 - x0) * np.arange(n) / (n - 1)

    def Y(z):
        return top + (zmax - np.asarray(z, dtype=np.float32)) / (zmax - zmin) * (bot - top)

    d = ImageDraw.Draw(img, "RGBA")
    ys = Y(np.maximum(p, zmin))
    d.rectangle([x0, Y(0), x1, bot], fill=(30, 90, 170, 230))                     # 海
    under = np.where(p > 0, Y(0), ys)
    d.polygon([(X[0], bot + 4)] + list(zip(X, under)) + [(X[-1], bot + 4)], fill=(96, 80, 68, 255))
    wet = sc.get("wet")                                                          # 風上(左)ほど緑、風下は茶
    inv = sc.get("inv", 99999)
    for i in range(n - 1):
        if p[i] > 0:
            if wet is None:
                col = (96, 140, 72)
            else:
                k = 1.0 if i / n < wet else max(0.0, 1 - (i / n - wet) * 6)
                col = tuple(int(g * k + r * (1 - k)) for g, r in zip((70, 140, 64), (176, 146, 100)))
            d.rectangle([X[i], ys[i], X[i + 1] + 1, Y(0)], fill=col + (255,))
            if p[i] > inv:                                                       # 雲のふたより上は乾いた岩
                d.rectangle([X[i], ys[i], X[i + 1] + 1, Y(inv)], fill=(150, 128, 110, 255))
    d.line(list(zip(X, ys)), fill=(40, 34, 30, 255), width=2)
    if sc.get("inv"):
        yi = float(Y(inv))
        for xx in range(int(x0), int(x1), 28):
            d.line([(xx, yi), (xx + 16, yi)], fill=YEL + (210,), width=3)
        text(d, (x1 - 8, yi - 10), sc.get("inv_label", f"雲のふた {inv:,}m"), 34 if LAND else 30, YEL, "rd")
    if sc.get("wind"):                                                            # 風が左から吹いて山を登る
        peak = int(np.argmax(p))
        k = ease(u * 1.6)
        for r_ in range(3):
            pts = []
            for i in range(0, int(peak * k) + 1, 6):
                lift = min(max(0.0, float(p[i])) + 250 + r_ * 300, inv - 120 + r_ * 50, float(p.max()) + 150 + r_ * 120)
                pts.append((X[i], float(Y(lift))))
            if len(pts) > 1:
                d.line(pts, fill=(235, 245, 255, 150 - r_ * 30), width=5)
        if k > 0.45:
            ca = ease((k - 0.45) * 3)
            for c_ in range(6):
                ii = int(peak * (0.45 + 0.08 * c_))
                cx = X[ii]
                cy = float(Y(min(max(0.0, float(p[ii])) + 800, inv - 200)))
                for dx, dy, rr in ((-30, 0, 34), (10, -14, 42), (48, 2, 32)):
                    d.ellipse([cx + dx - rr, cy + dy - rr * 0.7, cx + dx + rr, cy + dy + rr * 0.7], fill=(236, 240, 246, int(230 * ca)))
                if k > 0.7:
                    for rx in range(-30, 50, 14):
                        d.line([(cx + rx, cy + 26), (cx + rx - 6, cy + 70)], fill=(160, 200, 255, int(200 * ca)), width=3)
    for frac, z_, s, *c in sc.get("labels", []):
        if u > 0.2:
            text(d, (x0 + (x1 - x0) * frac, Y(z_)), s, 40 if LAND else 34, tuple(c[0]) if c else WHITE)
    for frac, s in sc.get("ends", []):
        text(d, (x0 + (x1 - x0) * frac, bot + 30), s, 34 if LAND else 30, DIM)
    if sc.get("title"):
        text(d, (W / 2, y0 + 55), sc["title"], 58 if LAND else 46, YEL)
    if sc.get("note"):
        text(d, (W / 2, y1 - 10), sc["note"], 38 if LAND else 32, WHITE, "md")


def draw_lens(img, sc, t, u):
    """島の地下: 雨がしみこみ、海水(下)の上に真水(上)がレンズの形で浮く。"""
    back(img)
    x0, y0, x1, y1 = region()
    d = ImageDraw.Draw(img, "RGBA")
    cx = W / 2
    sea = y0 + (y1 - y0) * (0.40 if LAND else 0.36)
    half = (x1 - x0) * (0.34 if LAND else 0.42)
    hmax = (y1 - y0) * 0.18
    d.rectangle([x0, sea, x1, y1], fill=(28, 82, 160, 255))                       # 海水
    xs = np.linspace(cx - half, cx + half, 200)
    q = np.clip(1 - ((xs - cx) / half) ** 2, 0, 1)
    k = ease(u * 1.5) if sc.get("grow", True) else 1.0
    head = hmax * 0.12 * k                                                         # 地下の真水の面(海面より少し上)
    depth = (y1 - sea) * 0.62 * k                                                  # 海面より下の真水
    ground = [(x, sea - hmax * qq ** 0.7) for x, qq in zip(xs, q)]
    d.polygon([(cx - half - 40, sea)] + ground + [(cx + half + 40, sea)], fill=(110, 92, 74, 255))
    top = [(x, sea - head * qq) for x, qq in zip(xs, q)]
    lens = [(x, sea + depth * qq) for x, qq in zip(xs, q)]
    d.polygon(top + lens[::-1], fill=(120, 200, 255, 235))                         # 真水のレンズ
    d.line(ground, fill=(80, 140, 70, 255), width=8)
    d.line([(x0, sea), (x1, sea)], fill=WHITE + (160,), width=2)
    if sc.get("rain", True):
        for i in range(26):
            rx = cx - half * 0.8 + (i * 97 % int(half * 1.6))
            ry = y0 + 40 + ((t * 300 + i * 53) % max(1.0, sea - y0 - hmax - 40))
            d.line([(rx, ry), (rx - 6, ry + 22)], fill=(170, 210, 255, 200), width=3)
    if k > 0.3:
        text(d, (cx, sea + depth * 0.45), sc.get("lens_label", "真水（地下水）"), 46 if LAND else 38, NAVY, "mm", sw=0)
    text(d, (x0 + (x1 - x0) * 0.1, sea + (y1 - sea) * 0.75), "海水", 44 if LAND else 38, WHITE)
    for s, pos, c in sc.get("labels", []):
        if u > 0.3:
            text(d, (x0 + (x1 - x0) * pos[0], y0 + (y1 - y0) * pos[1]), s, 40 if LAND else 34, c)
    if sc.get("title"):
        text(d, (W / 2, y0 + 50), sc["title"], 58 if LAND else 46, YEL)
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


CUSTOM = dict(cards=draw_cards, slice=draw_slice, lens=draw_lens, icons=draw_icons, bars=draw_bars)
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


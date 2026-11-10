"""青ヶ島(地理)の画面。ハワイの回(episodes/hawaii/scene.py)を写した。下地は立体の地図(naze/worldmap.py。
島は国土地理院の空中写真)と、ここで描く図:

  slice    島を切った断面(国土地理院の標高タイル z14)。a→b の線に沿って外輪山・火口の底・丸山。
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
STEPS = ["1 火口の村", "2 水", "3 電気", "4 船と畑", "5 答え"]
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
MAP = worldmap.Map(lat0=33, bases=[((122, 24, 150, 42), 5), ((138.6, 31.8, 140.8, 35.8), 9),
                                   ((139.6, 32.3, 139.95, 33.25), 12), ((139.70, 32.40, 139.83, 32.52), 15)])

# ---- 島を切った断面 --------------------------------------------------------------------------------------
_Z = {}


def hz():
    if "z" not in _Z:
        from naze import dem
        _Z["z"] = dem.load(139.735, 32.43, 139.79, 32.48, z=14)
    return _Z["z"]


def profile(a, b, n=900):
    D = hz()
    h = np.nan_to_num(D.h, nan=-60.0)                                  # 海は浅く描く(深さは測っていない)
    pts = [D.pixel(x, y) for x, y in zip(np.linspace(a[0], b[0], n), np.linspace(a[1], b[1], n))]
    j = np.array([p[0] for p in pts], np.float32)
    i = np.array([p[1] for p in pts], np.float32)
    return cv2.remap(h.astype(np.float32), j[None, :], i[None, :], cv2.INTER_LINEAR, borderMode=cv2.BORDER_REPLICATE)[0]


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
    for frac, s in sc.get("ends", []):                                           # 端の字は内側へ寄せる(縦ではみ出さない)
        text(d, (x0 if frac < 0.5 else x1, bot + 30), s, 34 if LAND else 30, DIM, "lm" if frac < 0.5 else "rm")
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


# ---- 図の質を上げた版(2026-11-11「2Dの画像の質を上げたい」) ------------------------------------------------
# 2 倍の大きさで描いて縮める(縁がギザギザしない)。地面は草・土・岩の層と細かい模様、斜面に光、海は深さで色が変わる。
# 断面には高さの目盛りと、高さを何倍に強調したかを書く。札は地面の点から線を引いて出す。
SS = 2
GRASS, SOIL, ROCK, DEEP, SAND_ = (np.array(c, np.float32) for c in ((88, 142, 72), (124, 98, 72), (86, 72, 64), (44, 38, 40), (150, 132, 104)))
_NZ = {}


def _noise(h, w, seed=3):
    k = (h, w, seed)
    if k not in _NZ:
        rng = np.random.default_rng(seed)
        a = cv2.resize(rng.standard_normal((h // 10 + 2, w // 10 + 2)).astype(np.float32), (w, h), interpolation=cv2.INTER_CUBIC)
        b = cv2.GaussianBlur(rng.standard_normal((h, w)).astype(np.float32), (0, 0), 1.0)
        _NZ[k] = a * 0.7 + b * 0.5
    return _NZ[k]


def _vgrad(h, w, c0, c1):
    g = np.linspace(0, 1, h, dtype=np.float32)[:, None, None]
    return np.broadcast_to(np.array(c0, np.float32) * (1 - g) + np.array(c1, np.float32) * g, (h, w, 3)).copy()


def _ground(depth, hpx, n, under=None):
    """地表からの深さ(画素)ごとの色。浅い所は草、その下は土、深いほど暗い岩。under は海の下の地表(砂)。"""
    d = depth[..., None]
    t1 = np.clip((d - 8 * SS) / (14 * SS), 0, 1)
    top = GRASS if under is None else np.where(under[..., None], SAND_, GRASS)
    c = top * (1 - t1) + SOIL * t1
    t2 = np.clip((d - 14 * SS) / (hpx * 0.35), 0, 1)
    c = c * (1 - t2) + ROCK * t2
    t3 = np.clip((d - hpx * 0.5) / (hpx * 0.8), 0, 1)
    c = c * (1 - t3) + DEEP * t3
    strata = np.sin((depth + n * 9 * SS) / (11 * SS)) * np.clip((depth - 20 * SS) / (40 * SS), 0, 1)
    return c * (1 + 0.09 * n[..., None] + 0.07 * strata[..., None])


def _paste(img, arr, x, y, w, h):
    im = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8)).resize((int(w), int(h)), Image.LANCZOS)
    img.paste(im.convert("RGBA"), (int(x), int(y)))


def _dist_m(a, b):
    p1, p2 = math.radians(a[1]), math.radians(b[1])
    dl, dp = math.radians(b[0] - a[0]), p2 - p1
    return 2 * 6371000 * math.asin(math.sqrt(math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2))


def draw_slice2(img, sc, t, u):
    back(img)
    x0, y0, x1, y1 = region()
    x0, x1 = x0 + (130 if LAND else 112), x1 - (70 if LAND else 40)
    top = y0 + (150 if sc.get("title") else 90)
    bot = y1 - (80 if sc.get("note") else 56)
    zmax, zmin = sc.get("zmax", 5000), sc.get("zmin", -1500)
    p = profile(sc["a"], sc["b"])
    wpx, hpx = int(x1 - x0), int(bot - top)
    W2, H2 = wpx * SS, hpx * SS
    surf = np.interp(np.linspace(0, len(p) - 1, W2), np.arange(len(p)), p).astype(np.float32)

    def Yf(z):
        return (zmax - np.asarray(z, np.float32)) / (zmax - zmin) * H2

    ys = Yf(np.maximum(surf, zmin))
    ysea = float(Yf(0))
    step = 100 if zmax - zmin <= 1200 else 500
    key = (tuple(sc["a"]), tuple(sc["b"]), zmax, zmin, W2, H2)
    if key not in _SL:
        _SL.clear()
        _SL[key] = _slice_canvas(W2, H2, surf, ys, ysea, Yf, zmin, zmax, step)
    can = _SL[key].copy()
    _slice_rest(img, sc, t, u, can, W2, H2, ys, ysea, Yf, zmin, zmax, step, x0, x1, top, bot, wpx, hpx, y0, y1)


_SL = {}


def _slice_canvas(W2, H2, surf, ys, ysea, Yf, zmin, zmax, step):
    """断面の動かない部分(空・海・目盛り・地面)。行が変わるまで使い回す。"""
    yy = np.arange(H2, dtype=np.float32)[:, None]
    depth = yy - ys[None, :]
    cov = np.clip(depth / SS + 0.5, 0, 1)
    can = _vgrad(H2, W2, (14, 26, 52), (52, 80, 118))                                  # 空
    sg = np.clip((yy - ysea) / max(1.0, H2 - ysea), 0, 1)[..., None]
    sea = np.array((46, 130, 196), np.float32) * (1 - sg) + np.array((14, 44, 96), np.float32) * sg
    scov = np.clip((yy - ysea) / SS + 0.5, 0, 1)[..., None]
    can = can * (1 - scov) + sea * scov
    dash =(np.arange(W2) // (13 * SS)) % 2 == 0
    for z in range(int(math.ceil(max(zmin, 0) / step) * step), int(zmax) + 1, step):    # 高さの目盛り(地面の下には出さない)
        yv = int(Yf(z))
        can[max(0, yv - SS // 2):yv + SS // 2 + 1, dash] = can[max(0, yv - SS // 2):yv + SS // 2 + 1, dash] * 0.8 + 255 * 0.2
    n = _noise(H2, W2)
    col = _ground(np.maximum(depth, 0), H2, n, under=np.broadcast_to(surf[None, :] <= 0, depth.shape))
    slope = np.gradient(ys) / SS                                                     # 左(北)から光: 左を向く斜面を明るく
    lit = np.clip(1 - slope * 0.35, 0.7, 1.3)[None, :, None]
    near = np.clip(1 - depth / (60 * SS), 0, 1)[..., None]
    col = col * (1 + (lit - 1) * near)
    wet = np.clip((yy - ysea) / SS, 0, 1)[..., None] * 0.35                           # 海の下の地面は青みがかる
    col = col * (1 - wet) + np.array((30, 80, 140), np.float32) * wet
    return can * (1 - cov[..., None]) + col * cov[..., None]


def _slice_rest(img, sc, t, u, can, W2, H2, ys, ysea, Yf, zmin, zmax, step, x0, x1, top, bot, wpx, hpx, y0, y1):
    rv = ease(u * 2.2) if sc.get("reveal", True) else 1.0                               # 左から切っていく
    xr = int(W2 * rv)
    if xr < W2:
        can[:, xr:] = _vgrad(H2, W2 - xr, (14, 26, 52), (52, 80, 118))
    im = Image.fromarray(np.clip(can, 0, 255).astype(np.uint8)).convert("RGBA")
    d2 = ImageDraw.Draw(im, "RGBA")
    pts =[(i, float(ys[i])) for i in range(0, xr, 2)]
    if len(pts) > 1:
        d2.line(pts, fill=(255, 255, 255, 60), width=7 * SS)                         # 地表の光
        d2.line(pts, fill=(226, 240, 214, 255), width=2 * SS)
    d2.line([(0, ysea), (xr, ysea)], fill=(200, 230, 255, 170), width=2 * SS)
    if xr < W2:
        d2.line([(xr, 0), (xr, H2)], fill=YEL + (200,), width=3 * SS)
    _paste(img, np.asarray(im.convert("RGB")), x0, top, wpx, hpx)
    d = ImageDraw.Draw(img, "RGBA")
    for z in range(int(math.ceil(max(zmin, 0) / step) * step), int(zmax) + 1, step):
        text(d, (x0 - 14, top + float(Yf(z)) / SS), f"{z}m", 26 if LAND else 24, DIM, "rm", sw=4, reg=False)
    for frac, z_, s, *c in sc.get("labels", []):
        if u > 0.25 and frac <= rv:
            i = int(frac * (W2 - 1))
            gx, gy = x0 + i / SS, top + float(ys[i]) / SS
            ty = top + float(Yf(z_)) / SS
            colr = tuple(c[0]) if c else WHITE
            d.line([(gx, gy - 6), (gx, ty + 24)], fill=colr + (200,), width=3)
            d.ellipse([gx - 7, gy - 7, gx + 7, gy + 7], fill=colr + (255,), outline=NAVY + (255,), width=2)
            text(d, (gx, ty), s, 40 if LAND else 34, colr)
    for frac, s in sc.get("ends", []):
        text(d, (x0 if frac < 0.5 else x1, bot + 28), s, 32 if LAND else 28, DIM, "lm" if frac < 0.5 else "rm", sw=4, reg=False)
    ex = (_dist_m(sc["a"], sc["b"]) / wpx) / ((zmax - zmin) / hpx)
    text(d, (W / 2, bot + 28), f"高さは約{ex:.0f}倍に強調", 28 if LAND else 24, DIM, "mm", sw=4, reg=False)
    if sc.get("title"):
        text(d, (W / 2, y0 + 55), sc["title"], 58 if LAND else 46, YEL)
    if sc.get("note"):
        text(d, (W / 2, y1 - 10), sc["note"], 38 if LAND else 32, WHITE, "md")


def draw_lens2(img, sc, t, u):
    """島の地下: 雨がしみこみ、海水の上に真水が薄く浮く。島の岩・海・真水を、なめらかな色の移りで描く。"""
    back(img)
    x0, y0, x1, y1 = region()
    wpx, hpx = int(x1 - x0), int(y1 - y0)
    W2, H2 = wpx * SS, hpx * SS
    sea = H2 * (0.40 if LAND else 0.36)
    half = W2 * (0.34 if LAND else 0.42)
    hmax = H2 * 0.18
    cx = W2 / 2
    X = np.arange(W2, dtype=np.float32)[None, :]
    yy = np.arange(H2, dtype=np.float32)[:, None]
    q = np.clip(1 - ((X - cx) / half) ** 2, 0, 1)
    gtop = sea - hmax * q ** 0.7                                                        # 地面の上の線
    can = _vgrad(H2, W2, (14, 26, 52), (52, 80, 118))
    sg = np.clip((yy - sea) / (H2 - sea), 0, 1)[..., None]
    water = np.array((44, 124, 196), np.float32) * (1 - sg) + np.array((12, 40, 92), np.float32) * sg
    can = np.where((yy >= sea)[..., None], water, can)
    inside = np.clip(1 - np.abs(X - cx) / (half + 30 * SS), 0, 1) > 0
    body = (yy >= gtop) & (q > 0) | ((yy >= sea) & (np.abs(X - cx) < half * (1 + 0.15 * np.clip((yy - sea) / (H2 - sea), 0, 1))))
    n = _noise(H2, W2, 7)
    depth = np.maximum(yy - gtop, 0)
    rock = _ground(depth, H2, n)
    salt = np.clip((yy - sea) / SS, 0, 1)[..., None]                                    # 海面より下の岩は海水を含む
    rock = rock * (1 - salt * 0.38) + np.array((34, 90, 150), np.float32) * salt * 0.38
    can = np.where(body[..., None], rock, can)
    k = ease(u * 1.5) if sc.get("grow", True) else 1.0
    head = hmax * 0.10 * k
    dep = (H2 - sea) * sc.get("lens_depth", 0.30) * k
    ltop, lbot = sea - head * q, sea + dep * q
    inner = np.clip(np.minimum(yy - ltop, lbot - yy) / (14 * SS), 0, 1) * (q > 0)      # 縁はぼかして海水とまざる
    fresh = np.array((130, 210, 255), np.float32)
    can = can * (1 - inner[..., None] * 0.9) + fresh * inner[..., None] * 0.9
    im = Image.fromarray(np.clip(can, 0, 255).astype(np.uint8)).convert("RGBA")
    d2 = ImageDraw.Draw(im, "RGBA")
    xs = np.linspace(cx - half, cx + half, 240)
    qq = np.clip(1 - ((xs - cx) / half) ** 2, 0, 1)
    d2.line([(x, sea - hmax * v ** 0.7) for x, v in zip(xs, qq)], fill=(120, 190, 96, 255), width=5 * SS)
    d2.line([(0, sea), (W2, sea)], fill=(210, 235, 255, 150), width=2 * SS)
    if sc.get("rain", True):
        for i in range(30):
            rx = cx - half * 0.85 + (i * 0.618 % 1.0) * half * 1.7
            ry = 100 * SS + ((t * 300 * SS + i * 53 * SS) % max(1.0, sea - hmax - 120 * SS))
            d2.line([(rx, ry), (rx - 6 * SS, ry + 24 * SS)], fill=(180, 215, 255, 210), width=2 * SS)
        for i in range(5):                                                              # しみこむ水の矢印
            ax = cx - half * 0.6 + i * half * 0.3
            ay0 = sea - hmax * (1 - ((ax - cx) / half) ** 2) ** 0.7 + 20 * SS
            ph = (t * 0.6 + i * 0.2) % 1.0
            ay = ay0 + ph * (sea - ay0 + head * 0.5)
            d2.line([(ax, ay - 30 * SS), (ax, ay)], fill=(170, 220, 255, int(200 * (1 - ph))), width=3 * SS)
            d2.polygon([(ax - 8 * SS, ay - 6 * SS), (ax + 8 * SS, ay - 6 * SS), (ax, ay + 8 * SS)], fill=(170, 220, 255, int(200 * (1 - ph))))
    _paste(img, np.asarray(im.convert("RGB")), x0, y0, wpx, hpx)
    d = ImageDraw.Draw(img, "RGBA")
    if k > 0.3:
        text(d, (x0 + wpx / 2, y0 + (sea + dep * 0.45) / SS), sc.get("lens_label", "真水（地下水）"), 42 if LAND else 36, NAVY, "mm", sw=0)
    text(d, (x0 + wpx * 0.1, y0 + hpx * 0.8), "海水", 44 if LAND else 38, WHITE)
    text(d, (x0 + wpx / 2, y0 + hpx * 0.86), "海水をふくんだ岩", 34 if LAND else 30, (200, 220, 240))
    for s, pos, c in sc.get("labels", []):
        if u > 0.3:
            text(d, (x0 + wpx * pos[0], y0 + hpx * pos[1]), s, 40 if LAND else 34, c)
    if sc.get("title"):
        text(d, (W / 2, y0 + 50), sc["title"], 58 if LAND else 46, YEL)
    if sc.get("note"):
        text(d, (W / 2, y1 - 10), sc["note"], 38 if LAND else 32, WHITE, "md")


def draw_bars2(img, sc, t, u):
    """棒: 2 倍で描いて縮める。棒は上が明るい色の移り、うしろに薄い溝、下に影。"""
    back(img)
    x0, y0, x1, y1 = region()
    items = sc["items"]
    vmax = max(v for _, v, _ in items)
    fmt = sc.get("fmt", "{}")
    tmp = ImageDraw.Draw(img)
    bx0 = x0 + (520 if LAND else 60)
    vw = max(tmp.textlength(fmt.format(v), font=ov.font(50 if LAND else 44)) for _, v, _ in items)
    bx1 = x1 - max(320 if LAND else 260, vw + 60)
    top = y0 + (140 if sc.get("title") else 60)
    gap = min(150 if LAND else 220, (y1 - top) / len(items))
    lay = Image.new("RGBA", (W * SS, H * SS), (0, 0, 0, 0))
    dl = ImageDraw.Draw(lay, "RGBA")
    rows = []
    for i, (name, v, col) in enumerate(items):
        a = ease(u * 2.4 - i * 0.35)
        y = top + i * gap
        yb = y + 10 if LAND else y + 50
        L = (bx1 - bx0) * v / vmax * a
        rows.append((name, v, col, a, y, yb, L))
        dl.rounded_rectangle([bx0 * SS, yb * SS, bx1 * SS, (yb + 64) * SS], 32 * SS, fill=(255, 255, 255, 18))
        if L > 2:
            dl.rounded_rectangle([bx0 * SS, (yb + 7) * SS, (bx0 + max(8, L)) * SS, (yb + 71) * SS], 32 * SS, fill=(0, 0, 0, 90))
            for k_ in range(16):                                                          # 上が明るい色の移り
                f = k_ / 15
                c = tuple(int(min(255, ch * (1.22 - 0.38 * f))) for ch in col)
                yk0, yk1 = yb + 64 * k_ / 16, yb + 64 * (k_ + 1) / 16
                dl.rectangle([bx0 * SS, yk0 * SS, (bx0 + max(8, L)) * SS, yk1 * SS + 1], fill=c + (240,))
    mask = Image.new("L", (W * SS, H * SS), 0)
    dm = ImageDraw.Draw(mask)
    for name, v, col, a, y, yb, L in rows:
        dm.rounded_rectangle([bx0 * SS, yb * SS, (bx0 + max(8, L)) * SS, (yb + 64) * SS], 32 * SS, fill=255)
    bars_only = Image.new("RGBA", lay.size, (0, 0, 0, 0))
    bars_only.paste(lay, (0, 0), mask)
    back_only = lay.copy()
    back_only.paste((0, 0, 0, 0), (0, 0), mask)
    out = Image.alpha_composite(back_only, bars_only).resize((W, H), Image.LANCZOS)
    img.alpha_composite(out)
    d = ImageDraw.Draw(img, "RGBA")
    for name, v, col, a, y, yb, L in rows:
        if LAND:
            text(d, (bx0 - 30, y + 40), name, 46, WHITE, "rm")
        else:
            text(d, (bx0, y + 10), name, 40, WHITE, "lm")
        if a > 0.2:
            text(d, (bx0 + L + 20, yb + 32), fmt.format(v), 50 if LAND else 44, tuple(col), "lm")
    if sc.get("title"):
        text(d, (W / 2, y0 + 50), sc["title"], 60 if LAND else 48, YEL)
    if sc.get("note"):
        text(d, (W / 2, y1 - 10), sc["note"], 42 if LAND else 36, WHITE, "md")


CUSTOM = dict(cards=draw_cards, slice=draw_slice2, lens=draw_lens2, icons=draw_icons, bars=draw_bars2)
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


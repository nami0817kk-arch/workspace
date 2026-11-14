"""海面は平らではない(ジオイド)の画面。青ヶ島の scene.py(札・棒・地図)を土台に、この回の図を足す。

  potato   見えない海面の地球。ex=0→1 で高さの差を 1 万倍まで大きくする(じゃがいもの形)。tint で色(青=低い・赤=高い)
  gmap     平らな世界地図に見えない海面の高さを色と等高線で重ねる。view=(経度, 緯度, 幅の度), view_to で動く
  gprof    くぼみの底から縁までの海面の断面(本当の縮尺 → 大きくする)。船が進む
  plumb    糸の重りと水面。mode=mountain(山のそば)・heavy(下に重い岩)・light(下が軽い)
  ellip    まん丸と、つぶれたみかん(物差しの地球)。geo=True で見えない海面の波を重ねる
  mantle   地球の断面。沈むテチス海の板 → アフリカの下の熱い塊 → インド洋の下へ昇る柱(stage 0→1)
  levels   富士山の下の 3 つの面(物差しの地球・見えない海面・山)。3,776m と 3,818m
  iceprint 氷が海の水を引き寄せる断面。melt=True で氷が減り、近くの海が下がる
  gcard    大きな数字の札(背景は見えない海面の色がゆっくり流れる)

数字は sim/calc.txt と scripts.md の「確かめた数字」。"""
from __future__ import annotations

import importlib.util
import math
import sys
from functools import lru_cache
from pathlib import Path

import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(ROOT))
from naze import geoid, shots, worldmap  # noqa: E402
from naze import overlay as ov  # noqa: E402
from naze.config import H, W  # noqa: E402

_spec = importlib.util.spec_from_file_location("aoga_scene", ROOT / "episodes" / "aogashima" / "scene.py")
base = importlib.util.module_from_spec(_spec)
sys.modules["aoga_scene"] = base
_spec.loader.exec_module(base)

LAND = W > H
YEL, WHITE, NAVY, DIM = ov.YEL, ov.WHITE, ov.NAVY, ov.DIM
RED, BLUE, SEA, ROCK = (240, 90, 80), (120, 190, 255), (40, 110, 190), (150, 120, 95)
LOW, HIGH = np.array([40, 110, 235], np.float32), np.array([235, 80, 55], np.float32)
SS = 2
text, ease = base.text, base.ease

base.MAP = worldmap.Map(lat0=34, bases=[((100, 0, 170, 60), 5), ((120, 18, 158, 48), 7),
                                         ((126.3, 25.5, 129.1, 27.2), 10), ((139.2, 37.0, 143.6, 39.8), 10),
                                         ((143.5, 43.0, 146.5, 45.0), 10), ((137.6, 34.6, 139.9, 36.1), 11)])
MAP = base.MAP
base.STEPS = ["1 平らなはずの海", "2 水は重力にそろう", "3 インド洋の下", "4 日本の見えない海面", "5 水平とは"]

LOW_PT, HIGH_PT = (78.75, 4.67), (147.33, -8.42)          # (経度, 緯度) sim/calc.txt


# ---- 見えない海面の色 ---------------------------------------------------------------------------------------
def gcolor(n: np.ndarray, a: float = 1.0) -> np.ndarray:
    """高さ(m) → 色。低い=青、0=うすい灰、高い=赤。"""
    k = np.clip(n / 100.0, -1, 1)[..., None]
    mid = np.array([225, 225, 215], np.float32)
    c = np.where(k < 0, mid + (LOW - mid) * (-k), mid + (HIGH - mid) * k)
    return c


@lru_cache(maxsize=1)
def _gtex():
    """地球全体の海面の高さ(1 度 12 画素、経度 -180〜180)と、衛星写真を同じ網目にしたもの。"""
    N, _, _ = geoid.grid()
    N = np.roll(N, N.shape[1] // 2, axis=1)                  # 経度 0〜360 → -180〜180
    world, ppd = shots._world()
    bm = cv2.resize(world, (N.shape[1], N.shape[0]), interpolation=cv2.INTER_AREA)
    return N.astype(np.float32), bm.astype(np.float32), N.shape[1] / 360.0


@lru_cache(maxsize=1)
def _contours():
    N, _, _ = _gtex()
    lv = np.floor(N / 20.0)
    e = (np.abs(np.diff(lv, axis=0, prepend=lv[:1])) + np.abs(np.diff(lv, axis=1, prepend=lv[:, :1]))) > 0
    return e.astype(np.float32)


def _supersample(fn, img, sc, t, u):
    lay = Image.new("RGBA", (W * SS, H * SS), (0, 0, 0, 0))
    fn(ImageDraw.Draw(lay, "RGBA"), sc, t, u)
    img.alpha_composite(lay.resize((W, H), Image.LANCZOS))


def _space(img, t):
    g = np.linspace(0, 1, H, dtype=np.float32)[:, None, None]
    a = np.array([6, 10, 24], np.float32) * (1 - g) + np.array([14, 24, 48], np.float32) * g
    a = np.broadcast_to(a, (H, W, 3)).copy()
    rng = np.random.default_rng(5)
    sx, sy = rng.integers(0, W, 420), rng.integers(0, H, 420)
    tw = 0.6 + 0.4 * np.sin(t * 1.3 + rng.uniform(0, 6.3, 420))
    a[sy, sx] = (rng.uniform(70, 200, 420) * tw)[:, None]
    img.paste(Image.fromarray(a.astype(np.uint8)).convert("RGBA"), (0, 0))


# ---- じゃがいもの地球 ---------------------------------------------------------------------------------------
def _geo_xy(lat, lon, la0, lo0):
    """視点(la0, lo0)から見た正射影の画面の向き(x 右・y 上・z 手前)。"""
    cl = np.cos(lat)
    x = cl * np.sin(lon - lo0)
    y = np.cos(la0) * np.sin(lat) - np.sin(la0) * cl * np.cos(lon - lo0)
    z = np.sin(la0) * np.sin(lat) + np.cos(la0) * cl * np.cos(lon - lo0)
    return x, y, z


def draw_potato(img, sc, t, u):
    N, bm, ppd = _gtex()
    _space(img, t)
    c0, c1 = sc.get("center", (80, 0)), sc.get("to", sc.get("center", (80, 0)))
    k = ease(u)
    lon0 = c0[0] + (c1[0] - c0[0]) * k + sc.get("spin", 6.0) * u
    lat0 = c0[1] + (c1[1] - c0[1]) * k
    e0, e1 = sc.get("ex", (1.0, 1.0)) if isinstance(sc.get("ex"), tuple) else (sc.get("ex", 1.0),) * 2
    ex = e0 + (e1 - e0) * ease(u * 1.6)
    tint = sc.get("tint", 1.0)
    scale = 10000.0 / 6371000.0 * ex                      # 1 万倍に大きくした高さ(地球の半径を 1)
    R = sc.get("r", 0.40) * H / (1 + 85 * scale * 1.0) * (1 + 0.03 * u)
    cx, cy = W / 2 + sc.get("dx", 0.0) * W, H / 2 + sc.get("dy", 0.0) * H
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    x, y = (xx - cx) / R, -(yy - cy) / R
    la0, lo0 = math.radians(lat0), math.radians(lon0)
    rho = np.ones_like(x)
    for _ in range(4):                                     # 光線と、でこぼこの面の交わりを 4 回で詰める
        z = np.sqrt(np.clip(rho * rho - x * x - y * y, 0, None)) / rho
        xs, ys = x / rho, y / rho
        lat = np.arcsin(np.clip(z * math.sin(la0) + ys * math.cos(la0), -1, 1))
        lon = lo0 + np.arctan2(xs, z * math.cos(la0) - ys * math.sin(la0))
        mx = (((np.degrees(lon) + 180) % 360) * ppd).astype(np.float32)
        my = ((90 - np.degrees(lat)) * ppd).astype(np.float32)
        n = cv2.remap(N, mx, my, cv2.INTER_LINEAR, borderMode=cv2.BORDER_WRAP)
        rho = 1 + scale * n
    inside = (x * x + y * y) <= rho * rho
    zz = np.sqrt(np.clip(rho * rho - x * x - y * y, 0, None))
    gx = cv2.Sobel(zz, cv2.CV_32F, 1, 0, ksize=3) / 8 * R
    gy = cv2.Sobel(zz, cv2.CV_32F, 0, 1, ksize=3) / 8 * R
    nrm = np.stack([-gx, gy, np.ones_like(gx)], -1)
    nrm /= np.linalg.norm(nrm, axis=-1, keepdims=True) + 1e-6
    col = cv2.remap(bm, mx, my, cv2.INTER_LINEAR, borderMode=cv2.BORDER_WRAP)
    col = col * 0.75 + np.array([6, 18, 40], np.float32) * 0.25
    if tint > 0:
        col = col * (1 - 0.72 * tint) + gcolor(n) * 0.72 * tint
        cl = cv2.remap(_contours(), mx, my, cv2.INTER_LINEAR, borderMode=cv2.BORDER_WRAP)[..., None]
        col = col * (1 - 0.35 * tint * cl)
    L = np.array([-0.45, 0.4, 0.8], np.float32)
    L /= np.linalg.norm(L)
    light = np.clip(0.30 + 0.85 * (nrm @ L), 0.22, 1.2)[..., None]
    col = col * light
    bg = np.asarray(img.convert("RGB")).astype(np.float32)
    rr = np.sqrt(x * x + y * y) / rho
    glow = np.clip(1 - (rr - 1) / 0.07, 0, 1) * (rr > 1)
    bg = bg + glow[..., None] * np.array([70, 140, 255], np.float32) * 0.7
    m = cv2.GaussianBlur(inside.astype(np.float32), (0, 0), 0.8)[..., None]
    out = col * m + bg * (1 - m)
    img.paste(Image.fromarray(np.clip(out, 0, 255).astype(np.uint8)).convert("RGBA"), (0, 0))
    d = ImageDraw.Draw(img, "RGBA")
    for (plon, plat), lab, colr in sc.get("marks", []):
        px, py, pz = _geo_xy(math.radians(plat), math.radians(plon), la0, lo0)
        if pz < 0.15:
            continue
        nn = geoid.at(plat, plon)
        rr_ = 1 + scale * nn
        sx_, sy_ = cx + px * rr_ * R, cy - py * rr_ * R
        a = ease(u * 4 - 0.3)
        d.ellipse([sx_ - 12, sy_ - 12, sx_ + 12, sy_ + 12], fill=colr + (int(255 * a),), outline=WHITE + (int(255 * a),), width=4)
        if a > 0.05:
            text(d, (sx_, sy_ - 56), lab, 58 if LAND else 52, colr)
    if sc.get("title"):
        text(d, (W / 2, 160 if LAND else 300), sc["title"], 60 if LAND else 52, WHITE)
    if sc.get("note"):
        text(d, (W / 2, H - (200 if LAND else 520)), sc["note"], 40 if LAND else 38, DIM)
    if tint > 0.3 and sc.get("legend", True):
        _legend(d)


def _legend(d):
    x0, y0 = (W - 330, H - 330) if LAND else (W / 2 - 300, H - 430)
    w, h = (40, 220) if LAND else (600, 36)
    for i in range(60):
        v = 100 - 200 * i / 59 if LAND else -100 + 200 * i / 59
        c = tuple(int(q) for q in gcolor(np.array([v]))[0])
        if LAND:
            d.rectangle([x0, y0 + h * i / 60, x0 + w, y0 + h * (i + 1) / 60 + 1], fill=c + (255,))
        else:
            d.rectangle([x0 + w * i / 60, y0, x0 + w * (i + 1) / 60 + 1, y0 + h], fill=c + (255,))
    if LAND:
        text(d, (x0 + w + 16, y0), "+100m", 32, WHITE, "lm", reg=False)
        text(d, (x0 + w + 16, y0 + h / 2), "0", 32, WHITE, "lm", reg=False)
        text(d, (x0 + w + 16, y0 + h), "-100m", 32, WHITE, "lm", reg=False)
    else:
        text(d, (x0, y0 + h + 30), "-100m", 30, WHITE, "lm", reg=False)
        text(d, (x0 + w, y0 + h + 30), "+100m", 30, WHITE, "rm", reg=False)


# ---- 平らな地図 ----------------------------------------------------------------------------------------------
def draw_gmap(img, sc, t, u):
    N, bm, ppd = _gtex()
    v0 = sc.get("view", (80, 0, 120))
    v1 = sc.get("view_to", v0)
    k = ease(u)
    lon, lat, span = (a + (b - a) * k for a, b in zip(v0, v1))
    span *= 1 - 0.03 * u
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    dpp = span / W
    glon = lon + (xx - W / 2) * dpp
    glat = lat - (yy - H / 2) * dpp
    mx = (((glon + 180) % 360) * ppd).astype(np.float32)
    my = (np.clip(90 - glat, 0, 179.99) * ppd).astype(np.float32)
    col = cv2.remap(bm, mx, my, cv2.INTER_LINEAR, borderMode=cv2.BORDER_WRAP)
    n = cv2.remap(N, mx, my, cv2.INTER_LINEAR, borderMode=cv2.BORDER_WRAP)
    tint = sc.get("tint", 1.0) * ease(u * 2.5) if sc.get("fade_in") else sc.get("tint", 1.0)
    col = col * (1 - 0.5 * tint) + gcolor(n) * 0.5 * tint
    cl = cv2.remap(_contours(), mx, my, cv2.INTER_LINEAR, borderMode=cv2.BORDER_WRAP)[..., None]
    col = col * (1 - 0.1 * tint * cl) + 35 * tint * cl
    # 周りを少し暗く
    vg = 1 - 0.35 * (((xx - W / 2) / W) ** 2 + ((yy - H / 2) / H) ** 2)[..., None] * 2
    img.paste(Image.fromarray(np.clip(col * vg, 0, 255).astype(np.uint8)).convert("RGBA"), (0, 0))
    d = ImageDraw.Draw(img, "RGBA")
    for i, ((plon, plat), lab, colr) in enumerate(sc.get("marks", [])):
        sx_, sy_ = W / 2 + (plon - lon) / dpp, H / 2 - (plat - lat) / dpp
        a = ease(u * 4 - 0.4 - 0.35 * i)
        if a <= 0:
            continue
        rr = 14 + 10 * math.sin(t * 4) * 0.3
        d.ellipse([sx_ - rr, sy_ - rr, sx_ + rr, sy_ + rr], fill=colr + (int(230 * a),), outline=WHITE + (int(255 * a),), width=4)
        text(d, (sx_, sy_ - 60), lab, 56 if LAND else 50, colr)
    if sc.get("line"):
        (a_lon, a_lat), (b_lon, b_lat) = sc["line"]
        p0 = (W / 2 + (a_lon - lon) / dpp, H / 2 - (a_lat - lat) / dpp)
        p1 = (W / 2 + (b_lon - lon) / dpp, H / 2 - (b_lat - lat) / dpp)
        q = ease(u * 2)
        pe = (p0[0] + (p1[0] - p0[0]) * q, p0[1] + (p1[1] - p0[1]) * q)
        d.line([p0, pe], fill=YEL + (255,), width=8)
        if sc.get("line_label") and q > 0.6:
            text(d, ((p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2 - 50), sc["line_label"], 52, YEL)
    for (plon, plat), lab in sc.get("names", []):
        sx_, sy_ = W / 2 + (plon - lon) / dpp, H / 2 - (plat - lat) / dpp
        text(d, (sx_, sy_), lab, 40 if LAND else 36, WHITE)
    if sc.get("title"):
        text(d, (W / 2, 160 if LAND else 300), sc["title"], 60 if LAND else 52, WHITE)
    _legend(d)


# ---- くぼみの断面 ----------------------------------------------------------------------------------------------
@lru_cache(maxsize=1)
def _east_profile():
    """くぼみの底から東へ、海面が 0m に戻るまで(緯度は底と同じ)。"""
    lons = np.linspace(LOW_PT[0], LOW_PT[0] + 26, 400)
    ns = np.array([geoid.at(LOW_PT[1], lo) for lo in lons])
    km = (lons - LOW_PT[0]) * 111.2 * math.cos(math.radians(LOW_PT[1]))
    return km, ns


def _draw_gprof(d, sc, t, u):
    km, ns = _east_profile()
    S = SS
    x0, x1 = (220, W - 160) if LAND else (90, W - 70)
    ym = H * (0.48 if LAND else 0.45)
    ex = sc.get("ex", (1.0, 1.0))
    e = ex[0] + (ex[1] - ex[0]) * ease(u * 1.5)
    # 本当の縮尺: 横 2,900km を画面の幅、縦も同じ縮尺 → 107m は 0.05 画素。e=1 で 1 万倍
    kx = (x1 - x0) / km[-1]
    ky = kx * (1 + (10000 - 1) * e) / 1000.0
    pts = [((x0 + a * kx) * S, (ym - n * ky) * S) for a, n in zip(km, ns)]
    sea = pts + [(x1 * S, (H - 120) * S), (x0 * S, (H - 120) * S)]
    d.polygon(sea, fill=SEA + (200,))
    d.line(pts, fill=(170, 220, 255, 255), width=5 * S)
    d.line([(x0 * S, ym * S), (x1 * S, ym * S)], fill=(255, 255, 255, 110), width=2 * S)
    # 船(海面に乗って進む)
    q = (0.08 + 0.84 * ((t * 0.04) % 1.0)) if sc.get("ship", True) else 0.5
    i = int(q * (len(km) - 1))
    sx, sy = pts[i]
    j = min(i + 3, len(pts) - 1)
    ang = math.atan2(pts[j][1] - sy, pts[j][0] - sx + 1e-6)
    hull = [(-36, -6), (36, -6), (26, 12), (-26, 12)]
    ca, sa = math.cos(ang), math.sin(ang)
    d.polygon([(sx + (px * ca - py * sa) * S, sy - 10 * S + (px * sa + py * ca) * S) for px, py in hull], fill=(250, 250, 250, 255))
    d.rectangle([sx - 6 * S, sy - 40 * S, sx + 6 * S, sy - 16 * S], fill=(240, 90, 80, 255))
    if e > 0.5:
        lab_y = (ym - ns[0] * ky) * S
        d.line([(x0 * S, ym * S), (x0 * S, lab_y)], fill=YEL + (255,), width=4 * S)


def draw_gprof(img, sc, t, u):
    base.back(img)
    _supersample(_draw_gprof, img, sc, t, u)
    d = ImageDraw.Draw(img, "RGBA")
    x0, x1 = (220, W - 160) if LAND else (90, W - 70)
    ex = sc.get("ex", (1.0, 1.0))
    e = ex[0] + (ex[1] - ex[0]) * ease(u * 1.5)
    text(d, (W / 2, 170 if LAND else 330), sc.get("title", "くぼみの底から東へ、海面を切る"), 56 if LAND else 48, WHITE)
    text(d, (W / 2, 240 if LAND else 410), "本当の縮尺" if e < 0.3 else "高さを1万倍にして描いています", 42 if LAND else 38, YEL if e >= 0.3 else DIM)
    text(d, (x0 + 10, H * (0.48 if LAND else 0.45) + (60 if e < 0.3 else 140)), "底 -107m", 44, BLUE, "lm")
    text(d, (x1 - 10, H * (0.48 if LAND else 0.45) - 50), "2,700km先で 0m", 44, WHITE, "rm")
    if sc.get("note"):
        text(d, (W / 2, H - (170 if LAND else 420)), sc["note"], 44 if LAND else 40, YEL)


# ---- 糸の重りと水面 ------------------------------------------------------------------------------------------
def _draw_plumb(d, sc, t, u):
    S = SS
    mode = sc.get("mode", "mountain")
    a = ease(u * 2.2)
    ym = H * (0.52 if LAND else 0.42)
    # 海と海面(下の重さで曲がる)
    xs = np.linspace(0, W, 200)
    c = W * 0.5
    amp = {"mountain": 0, "heavy": 70, "light": -70, "plain": 0}[mode] * a
    surf = ym - amp * np.exp(-((xs - c) / (W * 0.18)) ** 2)
    if mode == "mountain":
        surf = ym - 46 * a * np.exp(-((xs - W * 0.70) / (W * 0.16)) ** 2)
    poly = [(x * S, y * S) for x, y in zip(xs, surf)] + [(W * S, H * S), (0, H * S)]
    d.polygon(poly, fill=SEA + (210,))
    d.line([(x * S, y * S) for x, y in zip(xs, surf)], fill=(180, 225, 255, 255), width=5 * S)
    d.line([(0, ym * S), (W * S, ym * S)], fill=(255, 255, 255, 90), width=2 * S)
    if mode == "plain":
        pass
    elif mode == "mountain":
        mx = W * 0.78
        d.polygon([((mx - 330) * S, H * S), (mx * S, (ym - 210) * S), ((mx + 330) * S, H * S)], fill=ROCK + (255,))
    else:
        col = (110, 80, 60) if mode == "heavy" else (240, 140, 80)
        r = 160
        by = H - 230 if LAND else ym + 330
        d.ellipse([(c - r * 1.4) * S, by * S, (c + r * 1.4) * S, (by + r * 1.2) * S], fill=col + (int(255 * a),))
    # 糸の重り
    px = W * (0.55 if mode == "mountain" else 0.32)
    py0 = ym - 330
    tilt = (0.13 * a if mode == "mountain" else 0.0) + 0.012 * math.sin(t * 2.2)
    L = 230
    ex_, ey_ = px + L * math.sin(tilt), py0 + L * math.cos(tilt)
    d.line([((px - 80) * S, py0 * S), ((px + 80) * S, py0 * S)], fill=(220, 220, 230, 255), width=6 * S)
    d.line([(px * S, py0 * S), (ex_ * S, ey_ * S)], fill=(255, 255, 255, 255), width=3 * S)
    d.ellipse([(ex_ - 20) * S, (ey_ - 20) * S, (ex_ + 20) * S, (ey_ + 20) * S], fill=YEL + (255,))
    d.line([(px * S, py0 * S), (px * S, (py0 + L + 30) * S)], fill=(255, 255, 255, 80), width=2 * S)


def draw_plumb(img, sc, t, u):
    base.back(img)
    _supersample(_draw_plumb, img, sc, t, u)
    d = ImageDraw.Draw(img, "RGBA")
    mode = sc.get("mode", "mountain")
    lab = {"plain": "重りは真下を指し、水面はそれに直角", "mountain": "山のそばでは、重りが山へ引かれる", "heavy": "下が重い → 水が寄って盛り上がる", "light": "下が軽い → 水が離れてへこむ"}[mode]
    text(d, (W / 2, 160 if LAND else 330), sc.get("title", lab), 56 if LAND else 46, WHITE)
    c = W * 0.5
    if mode == "heavy":
        text(d, (c, H - 150 if LAND else H * 0.42 + 425), "重い岩", 48, WHITE)
    elif mode == "light":
        text(d, (c, H - 150 if LAND else H * 0.42 + 425), "熱くて軽い岩", 48, WHITE)
    elif mode == "mountain":
        text(d, (W * 0.78, H * (0.52 if LAND else 0.42) - 260), "山", 52, WHITE)
    if sc.get("note"):
        text(d, (W / 2, H * 0.52 - 420 if LAND else 420), sc["note"], 44, YEL)


# ---- まん丸と、つぶれたみかん ---------------------------------------------------------------------------------
def _draw_ellip(d, sc, t, u):
    S = SS
    cx, cy = W / 2, H * 0.54
    R = H * (0.32 if LAND else 0.22)
    a = ease(u * 2)
    f = 0.16 * a                                  # 本当は 300 分の 1。見えるように大きくした
    d.ellipse([(cx - R) * S, (cy - R) * S, (cx + R) * S, (cy + R) * S], outline=(255, 255, 255, 120), width=3 * S)
    ry = R * (1 - f)
    rx = R * (1 + f * 0.4)
    d.ellipse([(cx - rx) * S, (cy - ry) * S, (cx + rx) * S, (cy + ry) * S], fill=(230, 150, 50, 150), outline=(255, 190, 80, 255), width=5 * S)
    if sc.get("geo"):
        g = ease(u * 2 - 0.6)
        pts = []
        for i in range(361):
            th = math.radians(i)
            wob = 1 + g * 0.08 * (math.sin(3 * th + 0.7) + 0.6 * math.sin(5 * th + 2.0) + 0.4 * math.sin(2 * th + t * 0.3))
            pts.append(((cx + rx * wob * math.cos(th)) * S, (cy - ry * wob * math.sin(th)) * S))
        d.line(pts, fill=(120, 210, 255, 255), width=8 * S)
    d.line([(cx * S, (cy - ry) * S), (cx * S, cy * S)], fill=WHITE + (200,), width=3 * S)
    d.line([(cx * S, cy * S), ((cx + rx) * S, cy * S)], fill=WHITE + (200,), width=3 * S)


def draw_ellip(img, sc, t, u):
    base.back(img)
    _supersample(_draw_ellip, img, sc, t, u)
    d = ImageDraw.Draw(img, "RGBA")
    cx, cy = W / 2, H * 0.54
    R = H * (0.32 if LAND else 0.22)
    a = ease(u * 2)
    f = 0.16 * a
    text(d, (cx + R * (1 + f * 0.4) * 0.5, cy + 44), "赤道 6,378km", 44, WHITE)
    text(d, (cx + 26, cy - R * (1 - f) * 0.5), "北極 6,357km", 44, WHITE, "lm")
    text(d, (W / 2, 150 if LAND else 330), sc.get("title", "地球は、つぶれたみかんの形"), 56 if LAND else 46, WHITE)
    text(d, (W / 2, H - (70 if LAND else 360)), "つぶれ方は大きくして描いています", 34, DIM)
    if sc.get("geo"):
        text(d, (W / 2, H - (130 if LAND else 430)), "青い線：本当の海面（でこぼこを大きくして描いています）", 40, BLUE)


# ---- 地球の断面(マントル) -------------------------------------------------------------------------------------
def _draw_mantle(d, sc, t, u):
    S = SS
    cx, cy = W / 2, H * (1.02 if LAND else 0.70)
    R = H * 0.72 if LAND else W * 0.46
    st = sc.get("stage", (0.0, 1.0))
    s = st[0] + (st[1] - st[0]) * ease(u * 1.3)
    # 半円の断面: 地殻・マントル・核
    d.pieslice([(cx - R) * S, (cy - R) * S, (cx + R) * S, (cy + R) * S], 180, 360, fill=(150, 75, 45, 255))
    Rc = R * 0.546
    d.pieslice([(cx - Rc) * S, (cy - Rc) * S, (cx + Rc) * S, (cy + Rc) * S], 180, 360, fill=(250, 170, 60, 255))
    d.arc([(cx - R) * S, (cy - R) * S, (cx + R) * S, (cy + R) * S], 180, 360, fill=SEA + (255,), width=10 * S)

    def P(ang, rr):
        th = math.radians(ang)
        return ((cx + rr * math.cos(th)) * S, (cy - rr * math.sin(th)) * S)
    # アフリカの下の熱い塊(核の上、左寄り)
    blob = [P(a_, Rc + 70 + 40 * math.sin(a_ * 0.2 + t * 0.4)) for a_ in range(120, 161, 2)] + [P(a_, Rc) for a_ in range(160, 119, -2)]
    d.polygon(blob, fill=(235, 80, 40, 255))
    # テチス海の板: 地表(右上)から沈んで塊を押す
    k1 = min(1.0, s * 2)
    seg = [P(70 + 50 * q * k1, R - (R - Rc - 60) * q * k1) for q in np.linspace(0, 1, 30)]
    if k1 > 0.02:
        d.line(seg, fill=(90, 160, 255, 255), width=26 * S)
    # 熱い柱: 塊からインド洋の下へ昇る
    k2 = max(0.0, min(1.0, s * 2 - 1))
    if k2 > 0.02:
        col = [P(128 - 38 * q, Rc + 80 + (R - Rc - 150) * q) for q in np.linspace(0, k2, 30)]
        d.line(col, fill=(255, 120, 60, 230), width=34 * S)
        hx, hy = col[-1]
        d.ellipse([hx - 40 * S, hy - 30 * S, hx + 40 * S, hy + 30 * S], fill=(255, 140, 70, 230))
        # 上の海面がへこむ
        dip = 40 * k2
        sx, sy = P(90, R)
        d.arc([sx - 160 * S, sy - 20 * S, sx + 160 * S, sy + dip * S * 2], 200, 340, fill=(140, 210, 255, 255), width=8 * S)


def draw_mantle(img, sc, t, u):
    _space(img, t)
    _supersample(_draw_mantle, img, sc, t, u)
    d = ImageDraw.Draw(img, "RGBA")
    st = sc.get("stage", (0.0, 1.0))
    s = st[0] + (st[1] - st[0]) * ease(u * 1.3)
    text(d, (W / 2, 160 if LAND else 330), sc.get("title", "地球を切った断面"), 56 if LAND else 46, WHITE)
    cx, cy = W / 2, H * (1.02 if LAND else 0.70)
    R = H * 0.72 if LAND else W * 0.46
    Rc = R * 0.546
    labs = [(0.0, "マントル（深さ2,900kmまで）" if LAND else "マントル", (cx + R * 0.62, cy - R * 0.45), WHITE),
            (0.0, "核", (cx, cy - Rc * 0.45), WHITE),
            (0.15, "沈むテチス海の板", (cx + R * 0.58, cy - R * 0.82), BLUE),
            (0.25, "アフリカの下の熱い塊", (cx - R * 0.62, cy - Rc - 140), (255, 150, 90)),
            (0.6, "熱い岩の柱", (cx - R * 0.05, cy - R * 0.66), (255, 160, 100)),
            (0.8, "インド洋の海面がへこむ", (cx, cy - R - 60), YEL)]
    for s0, lab, xy, col in labs:
        if s >= s0 and (s0 > 0 or sc.get("names", True)):
            text(d, xy, lab, 44 if LAND else 38, col)
    if sc.get("note"):
        text(d, (W / 2, 190 if LAND else 400), sc["note"], 44, YEL)


# ---- 富士山の下の 3 つの面 ------------------------------------------------------------------------------------
def _draw_levels(d, sc, t, u):
    S = SS
    yE = H * 0.80                                          # 物差しの地球
    yG = yE - 120                                          # 見えない海面(43m を大きくして描く)
    a = ease(u * 2)
    xs = np.linspace(0, W, 120)
    d.line([(0, yE * S), (W * S, yE * S)], fill=(255, 190, 80, 255), width=5 * S)
    g = [(x * S, (yG - 14 * math.sin(x / 260 + t * 0.4)) * S) for x in xs]
    d.line(g, fill=(120, 200, 255, 255), width=5 * S)
    top = H * 0.24
    cx = W * 0.5
    d.polygon([((cx - 520) * S, (yG + 30) * S), (cx * S, top * S), ((cx + 520) * S, (yG + 30) * S)], fill=(110, 95, 85, 255))
    d.polygon([((cx - 120) * S, (top + 110) * S), (cx * S, top * S), ((cx + 120) * S, (top + 110) * S)], fill=(240, 240, 245, 255))
    if a > 0.2:
        x1, x2 = cx + 300, cx - 330
        d.line([(x1 * S, top * S), (x1 * S, yG * S)], fill=(120, 200, 255, 255), width=5 * S)
        k = ease(u * 2 - 0.8)
        if k > 0:
            d.line([(x2 * S, top * S), (x2 * S, (top + (yE - top) * k) * S)], fill=(255, 190, 80, 255), width=5 * S)


def draw_levels(img, sc, t, u):
    base.back(img)
    _supersample(_draw_levels, img, sc, t, u)
    d = ImageDraw.Draw(img, "RGBA")
    yE = H * 0.80
    yG = yE - 120
    cx = W * 0.5
    top = H * 0.24
    text(d, (W - 40, yE + 40), "物差しの地球（衛星の高さの0m）", 38, (255, 190, 80), "rm")
    text(d, (40, yG - 50), "見えない海面（標高の0m）", 38, BLUE, "lm")
    text(d, (cx, (yG + yE) / 2 + 6), "43m", 46, YEL)
    a = ease(u * 2)
    if a > 0.2:
        text(d, (cx + 320, (top + yG) / 2), "3,776m", 54, BLUE, "lm")
    if ease(u * 2 - 0.8) > 0.6:
        text(d, (cx - 350, (top + yE) / 2), "3,818m", 54, (255, 190, 80), "rm")
    text(d, (W / 2, 160 if LAND else 330), sc.get("title", "富士山の山頂を、2つの0mから測る"), 52 if LAND else 44, WHITE)
    text(d, (W / 2, H - 40), "43mの差は大きくして描いています", 32, DIM, "md")


# ---- 氷と海面 -------------------------------------------------------------------------------------------------
def _draw_ice(d, sc, t, u):
    S = SS
    ym = H * 0.56
    melt = ease(u * 1.6) if sc.get("melt") else 0.0
    ice_w = W * 0.30 * (1 - 0.45 * melt)
    ice_h = 240 * (1 - 0.45 * melt)
    xs = np.linspace(W * 0.30, W, 200)
    pull = 70 * (1 - 0.8 * melt)
    rise = 26 * melt
    surf = ym - pull * np.exp(-(xs - W * 0.30) / (W * 0.20)) - rise * (1 - np.exp(-(xs - W * 0.30) / (W * 0.30)))
    d.rectangle([0, (ym + 40) * S, W * 0.32 * S, H * S], fill=ROCK + (255,))
    d.polygon([(x * S, y * S) for x, y in zip(xs, surf)] + [(W * S, H * S), (W * 0.30 * S, H * S)], fill=SEA + (220,))
    d.line([(x * S, y * S) for x, y in zip(xs, surf)], fill=(180, 225, 255, 255), width=5 * S)
    d.line([(W * 0.30 * S, ym * S), (W * S, ym * S)], fill=(255, 255, 255, 90), width=2 * S)
    x0 = W * 0.30 - ice_w
    d.polygon([(x0 * S, (ym + 40) * S), ((x0 + ice_w * 0.25) * S, (ym + 40 - ice_h) * S), ((W * 0.30 - 20) * S, (ym + 40 - ice_h * 0.6) * S),
               (W * 0.30 * S, (ym + 40) * S)], fill=(235, 245, 255, 255))
    for i in range(5):                                      # 氷が水を引く矢印
        y = ym - 30 + i * 0.0
        ax = W * 0.36 + i * 140 + 30 * math.sin(t * 2 + i)
        al = int(220 * (1 - 0.7 * melt))
        d.line([(ax * S, (ym + 80) * S), ((ax - 70) * S, (ym + 80) * S)], fill=(255, 255, 255, al), width=4 * S)
        d.polygon([((ax - 90) * S, (ym + 80) * S), ((ax - 65) * S, (ym + 68) * S), ((ax - 65) * S, (ym + 92) * S)], fill=(255, 255, 255, al))


def draw_iceprint(img, sc, t, u):
    base.back(img)
    _supersample(_draw_ice, img, sc, t, u)
    d = ImageDraw.Draw(img, "RGBA")
    melt = sc.get("melt")
    text(d, (W / 2, 140 if LAND else 330), sc.get("title", "重い氷は、まわりの海の水を引き寄せる"), 52 if LAND else 44, WHITE)
    text(d, (W * 0.20, H * 0.56 - 260), "氷", 54, WHITE)
    if melt and u > 0.4:
        text(d, (W * 0.45, H * 0.56 - 130), "近くは下がる", 50, BLUE)
        text(d, (W * 0.85, H * 0.56 - 110), "遠くは上がる", 50, RED)
        text(d, (W * 0.62, H - 120), "氷から最大2,000km（NASA）", 42, YEL)


# ---- 数字の札 -------------------------------------------------------------------------------------------------
@lru_cache(maxsize=1)
def _gback():
    N, _, _ = _gtex()
    c = gcolor(cv2.resize(N, (720, 360), interpolation=cv2.INTER_AREA))
    c = cv2.GaussianBlur(c, (0, 0), 6)
    return c * 0.35 + np.array([8, 14, 30], np.float32) * 0.65


def draw_gcard(img, sc, t, u):
    bgw = _gback()
    off = (t * 6.0) % 720
    wrap = np.concatenate([bgw, bgw], axis=1)
    cw = 360 * W // H
    crop = wrap[:, int(off):int(off) + cw]
    if crop.shape[1] < cw:
        crop = wrap[:, :cw]
    img.paste(Image.fromarray(cv2.resize(crop, (W, H)).astype(np.uint8)).convert("RGBA"), (0, 0))
    _card_text(img, sc, t, u)


def _card_text(img, sc, t, u):
    d = ImageDraw.Draw(img)
    a = shots._ease(u * 5)
    big = sc["big"]
    if sc.get("count", True):
        big = worldmap.count_text(big, min(1.0, u * sc.get("_dur", 3.0) / 0.9))
    size = sc.get("size", 230 if LAND else 180)
    while size > 60 and ov.font(size).getlength(sc["big"]) > W * 0.86:
        size -= 6
    size = int(size * (1.15 - 0.15 * a))
    f = ov.font(size)
    cy = H * (0.42 if LAND else 0.38)
    d.text((W / 2, cy), big, font=f, fill=tuple(sc.get("color", YEL)) + (int(255 * a),), anchor="mm", stroke_width=10, stroke_fill=NAVY)
    ov.BOXES.append(("label", d.textbbox((W / 2, cy), sc["big"], font=f, anchor="mm"), big, 1.0))
    if sc.get("sub"):
        d.text((W / 2, cy - size * 0.5 - 60), sc["sub"], font=ov.font(56 if LAND else 46), fill=DIM, anchor="mm")
    if sc.get("note"):
        b2 = shots._ease(u * 3 - 0.5)
        d.text((W / 2, cy + size * 0.5 + 70), sc["note"], font=ov.font(56 if LAND else 46), fill=(255, 255, 255, int(255 * b2)), anchor="mm", stroke_width=6, stroke_fill=NAVY)
    L = W * 0.32 * shots._ease(u * 2.5)
    d.line([(W / 2 - L / 2, cy + size * 0.5 + 12), (W / 2 + L / 2, cy + size * 0.5 + 12)], fill=YEL, width=6)


# ---- 止まった画面にしない: 図はゆっくり寄る ---------------------------------------------------------------------
def _drift(fn, k=0.035):
    def g(img, sc, t, u):
        fn(img, sc, t, u)
        if sc.get("shot") in ("potato", "gmap"):
            return
        s = 1 + k * u
        im = img.resize((int(W * s), int(H * s)), Image.BILINEAR)
        ox, oy = (im.width - W) // 2, (im.height - H) // 2
        img.paste(im.crop((ox, oy, ox + W, oy + H)), (0, 0))
    return g


def _bars_drift(img, sc, t, u):
    base.draw_bars2(img, sc, t, u)


base.CUSTOM.update({k: _drift(v) for k, v in dict(
    potato=draw_potato, gmap=draw_gmap, gprof=draw_gprof, plumb=draw_plumb, ellip=draw_ellip, mantle=draw_mantle,
    levels=draw_levels, iceprint=draw_iceprint, gcard=draw_gcard, bars=_bars_drift).items()})

draw, sfx_for = base.draw, base.sfx_for

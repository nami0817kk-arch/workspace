"""南極の氷が全部とけたら(世界版)の画面。下地は世界の立体の地図(naze/worldmap.py)に「海面を上げる」層を足したものと、ここで描く図:

  地図の層 flood  {level: 58, rise_s: 3}  海から低い所を伝ってつながる陸だけを、海面が上がるように塗る(sim/flood.py と同じ考え方)
  polar    南極を真上から見た図(ETOPO 2022、cache/etopo)。mode="ice"(氷の表面)|"bed"(氷を取った岩盤。海面より下は海)|"shelf"(浮かぶ氷を赤く)
           |"strip"(氷から岩盤へ、下から抜いていく)。line=True で断面の切り線
  section  南極を切った断面(氷の表面と岩盤と海面)。mode="ice"|"below"(海面より下の氷を赤く)|"melt"(氷が消えて海が入る)
  glass    コップの氷水。mode="float"(浮かぶ氷がとけても水位は同じ)|"rock"(岩に乗った氷がとけると水位が上がる)
  icons    同じ物を n 個並べる(floor・japan・city・dome)。hl=最初の何個を色付きに
  bars     棒で比べる。cards は答えの並べ直し

数字は sim/calc.txt(氷の量・58 m・熱)と sim/flood.txt(沈む陸・都市)。"""
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
STEPS = ["1 沈む世界", "2 氷の量", "3 消えた11m", "4 とかす熱", "5 答え"]
YEL, WHITE, NAVY, DIM = ov.YEL, ov.WHITE, ov.NAVY, ov.DIM
RED, BLUE, ICE = (240, 90, 80), (120, 190, 255), (226, 238, 248)
WATER = (46, 150, 236)                                       # 沈んだ陸(いまの海より明るい青)
LEVEL = 58.0


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


# ---- 海面を上げる地図 ----------------------------------------------------------------------------------

class FloodMap(worldmap.Map):
    """worldmap.Map に flood の層を足す。下地ごとに「海につながる高さ」(くぼ地を埋めた高さ)を 1 回計算して cache に置く。"""

    def _fill(self, b):
        if getattr(b, "_fillpyr", None) is None:
            lo0, la0, lo1, la1 = b.bbox
            key = worldmap.TT / f"fill_{b.z}_{lo0}_{la0}_{lo1}_{la1}_{b.w}.npz"
            if key.exists():
                f = np.load(key)["f"].astype(np.float32)
            else:
                from skimage.morphology import reconstruction
                e = b.e
                n, lab = cv2.connectedComponents((e <= 0).astype(np.uint8), connectivity=8)
                sizes = np.bincount(lab.ravel())
                edge = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
                keep = np.zeros(n, bool)
                for i in range(1, n):
                    keep[i] = i in edge or sizes[i] > e.size * 0.002
                ocean = keep[lab] & (e <= 0)
                seed = np.where(ocean, e, e.max() + 1)
                f = reconstruction(seed, e, method="erosion").astype(np.float32)
                np.savez_compressed(key, f=np.clip(f, -999, 9999).astype(np.int16))
            pyr = [np.where(b.e > 0, f, 9999).astype(np.float32)]
            while len(pyr) < len(b.levels):
                pyr.append(cv2.pyrDown(pyr[-1]))
            b._fillpyr = pyr
        return b._fillpyr

    def layer(self, img, v, L, a, k):
        if L["kind"] != "flood":
            return super().layer(img, v, L, a, k)
        if a <= 0:
            return
        b, lv = self.best(v)
        f = self._gather(self._warp(b, v, self._fill(b)[lv], lv, 9999, ext=True), fill=9999)
        lvl = L.get("level", LEVEL) * ease(L.get("_u", 9.0) / L.get("rise_s", 3.0))
        m = np.clip((lvl - f) / 2.5 + 0.5, 0, 1).astype(np.float32)
        m = cv2.GaussianBlur(m, (0, 0), 0.8)
        out = np.zeros((H, W, 4), np.uint8)
        out[..., :3] = L.get("color", WATER)
        out[..., 3] = (m * 225 * a).astype(np.uint8)
        img.alpha_composite(Image.fromarray(out, "RGBA"))
        eg = cv2.morphologyEx((m > 0.5).astype(np.uint8) * 255, cv2.MORPH_GRADIENT, np.ones((3, 3), np.uint8)).astype(np.float32) / 255
        e4 = np.zeros((H, W, 4), np.uint8)
        e4[..., :3] = (215, 245, 255)
        e4[..., 3] = (np.clip(cv2.GaussianBlur(eg, (0, 0), 2) * 0.8 + eg * 0.6, 0, 1) * 200 * a).astype(np.uint8)
        img.alpha_composite(Image.fromarray(e4, "RGBA"))


MAP = FloodMap(lat0=32, bases=[((-180, -60, 179.99, 84), 4),
                               ((98, 15, 150, 50), 7), ((-12, 40, 30, 62), 7), ((-108, 17, -50, 49), 7),
                               ((76, 14, 100, 30), 8), ((108, 27, 126, 43), 8), ((133, 33, 142, 37.5), 9)])

# ---- 南極(ETOPO 2022) ------------------------------------------------------------------------------------
E = CACHE / "etopo"
_POLAR = {}
RI, RW = 917.0, 1027.0


def _ant():
    if "sur" not in _POLAR:
        _POLAR["sur"] = np.load(E / "ant_sur.npy").astype(np.float32)
        _POLAR["bed"] = np.load(E / "ant_bed.npy").astype(np.float32)
    return _POLAR["sur"], _POLAR["bed"]


def sample(arr, lat, lon):
    """南緯55〜90度の格子(0.05度、上が北)を緯度経度で引く。"""
    i = np.clip((-55.075 - lat) / 0.05, 0, arr.shape[0] - 1).astype(np.float32)
    j = ((lon + 179.975) / 0.05) % arr.shape[1]
    return cv2.remap(arr, j.astype(np.float32), i, cv2.INTER_LINEAR, borderMode=cv2.BORDER_WRAP)


SEA = worldmap.SEA
LANDC = [(0, (120, 112, 86)), (500, (146, 132, 98)), (1500, (172, 156, 120)), (3000, (200, 190, 170)), (4500, (232, 230, 226))]


def _pal(e, stops):
    xs = [s[0] for s in stops]
    out = np.zeros(e.shape + (3,), np.float32)
    for c in range(3):
        out[..., c] = np.interp(e, xs, [s[1][c] for s in stops])
    return out


def _shade(e, px_m, ex=4.0):
    gy, gx = np.gradient(e)
    gx, gy = gx / px_m * ex, -gy / px_m * ex
    sh = (gx * 0.6 - gy * 0.6 + 0.53) / np.sqrt(gx * gx + gy * gy + 1)
    return np.clip(0.4 + 1.1 * sh / 0.53 * 0.53, 0.45, 1.35)


def polar_maps(size):
    """南極を真上から(正距方位、南極点が真ん中、経度0が上)。ice・bed・shelf の 3 枚の絵と、緯度経度の格子。"""
    key = ("maps", size)
    if key in _POLAR:
        return _POLAR[key]
    sur, bed = _ant()
    r_deg = 31.0                                              # 真ん中から端まで(南緯59度)
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
    x, y = (xx - size / 2) / (size / 2), (yy - size / 2) / (size / 2)
    rho = np.sqrt(x * x + y * y) * r_deg
    lat = -90 + rho
    lon = np.degrees(np.arctan2(x, -y))
    s = sample(sur, lat, lon)
    bd = sample(bed, lat, lon)
    H_ = np.clip(s - bd, 0, None)
    ice = H_ > 1
    floating = ice & (bd < 0) & (H_ * RI < -bd * RW)
    px_m = r_deg * 111320 / (size / 2)
    sea_c = _pal(np.minimum(bd, 0), SEA) * _shade(bd, px_m, 6)[..., None]
    ice_c = (np.array(ICE, np.float32) * _shade(s, px_m, 30)[..., None] * 0.92)
    ice_c = ice_c * (1 - 0.1 * np.clip(s / 4000, 0, 1))[..., None] + np.array([0, 6, 14], np.float32)
    ice_img = np.where(ice[..., None], ice_c, sea_c)
    land_c = _pal(np.maximum(bd, 0), LANDC) * _shade(bd, px_m, 5)[..., None]
    bed_img = np.where((bd > 0)[..., None], land_c, _pal(np.minimum(bd, 0), SEA) * _shade(bd, px_m, 6)[..., None])
    shelf_img = ice_img.copy()
    shelf_img[floating] = shelf_img[floating] * 0.35 + np.array(RED, np.float32) * 0.65
    mask = (rho <= r_deg).astype(np.float32)
    mask = cv2.GaussianBlur(mask, (0, 0), 2)[..., None]
    res = {}
    for k, im in (("ice", ice_img), ("bed", bed_img), ("shelf", shelf_img)):
        res[k] = np.clip(im, 0, 255).astype(np.uint8)
    res["mask"] = mask
    res["below"] = (ice & ~floating & (bd < 0)).astype(np.float32)
    res["lat"], res["lon"] = lat, lon
    _POLAR[key] = res
    return res


SECT_LON = (-110.0, 70.0)                                     # 断面の線: 西経110度(アムンゼン海)→ 南極点 → 東経70度


def section_data(n=900):
    sur, bed = _ant()
    a, b = SECT_LON
    lat_a, lat_b = -72.5, -69.0
    t = np.linspace(0, 1, n)
    d_a, d_b = (90 + lat_a), (90 + lat_b)                       # 南極点からの度
    dist = t * (d_a + d_b) - d_a                                # 負は西経110度側
    lat = -90 + np.abs(dist)
    lon = np.where(dist < 0, a, b)
    s = sample(sur, lat.reshape(1, -1).astype(np.float32), lon.reshape(1, -1).astype(np.float32))[0]
    bd = sample(bed, lat.reshape(1, -1).astype(np.float32), lon.reshape(1, -1).astype(np.float32))[0]
    km = (dist + d_a) * 111.32
    return km, np.where(s - bd > 1, s, np.maximum(bd, 0)), bd


def _place(img, sc, u):
    """polar の絵を画面に置く大きさと位置。"""
    x0, y0, x1, y1 = region()
    size = int((y1 - y0) * (1.08 if LAND else 0.82) if LAND else W * 0.96)
    z = 1.0 + 0.05 * u * sc.get("zoom", 1)
    cx = W * sc.get("cx", 0.5)
    cy = (y0 + y1) / 2 + (20 if LAND else 0)
    return size, z, cx, cy


def draw_polar(img, sc, t, u):
    back(img)
    size0, z, cx, cy = _place(img, sc, u)
    P = polar_maps(900)
    mode = sc.get("mode", "ice")
    if mode == "strip":                                       # 氷を下から抜いていく: 上の行から岩盤に変わる
        k = ease(u * 1.6)
        rows = np.arange(900, dtype=np.float32)[:, None] / 900
        mix = np.clip((k * 1.3 - rows) / 0.12, 0, 1)[..., None]
        arr = P["ice"].astype(np.float32) * (1 - mix) + P["bed"].astype(np.float32) * mix
    elif mode == "fade":
        k = ease(u * 2.0)
        arr = P["ice"].astype(np.float32) * (1 - k) + P["bed"].astype(np.float32) * k
    elif mode == "below":
        arr = P["ice"].astype(np.float32)
        m = P["below"][..., None] * min(1.0, u * 3)
        arr = arr * (1 - 0.6 * m) + np.array(RED, np.float32) * 0.6 * m
    else:
        arr = P[mode].astype(np.float32)
    rgba = np.dstack([np.clip(arr, 0, 255).astype(np.uint8), (P["mask"][..., 0] * 255).astype(np.uint8)])
    s = int(size0 * z)
    im = Image.fromarray(rgba, "RGBA").resize((s, s), Image.LANCZOS)
    sh = Image.new("RGBA", img.size, (0, 0, 0, 0))
    sh.paste((0, 0, 0, 140), (int(cx - s / 2 + 14), int(cy - s / 2 + 22)), im.split()[3])
    img.alpha_composite(sh.filter(ImageFilter.GaussianBlur(14)))
    img.alpha_composite(im, (int(cx - s / 2), int(cy - s / 2)))
    d = ImageDraw.Draw(img, "RGBA")

    def ll(lat, lon):
        r = (90 + lat) / 31.0 * s / 2
        return cx + r * math.sin(math.radians(lon)), cy - r * math.cos(math.radians(lon))

    if sc.get("line"):
        k = ease(u * 2)
        a, b = SECT_LON
        p0, p1 = ll(-72.5, a), ll(-69.0, b)
        pm = (cx, cy)
        pts = [p0, pm, p1]
        tot = k * 2
        seg = [p0, pm] if tot <= 1 else [p0, pm]
        end1 = (p0[0] + (pm[0] - p0[0]) * min(1, tot), p0[1] + (pm[1] - p0[1]) * min(1, tot))
        d.line([p0, end1], fill=YEL + (255,), width=7)
        if tot > 1:
            end2 = (pm[0] + (p1[0] - pm[0]) * (tot - 1), pm[1] + (p1[1] - pm[1]) * (tot - 1))
            d.line([pm, end2], fill=YEL + (255,), width=7)
        for q in (p0, p1):
            d.ellipse([q[0] - 10, q[1] - 10, q[0] + 10, q[1] + 10], fill=YEL)
    for lab in sc.get("labels", []):
        (lat, lon), s_, col = lab[0], lab[1], (lab[2] if len(lab) > 2 else WHITE)
        at = lab[3] if len(lab) > 3 else 0.0
        if u >= at:
            text(d, ll(lat, lon), s_, 52 if LAND else 46, col)
    if sc.get("title"):
        x0, y0, x1, y1 = region()
        text(d, (W / 2 if not LAND else W * 0.5, y0 + 40), sc["title"], 60 if LAND else 50, YEL)
    if sc.get("note"):
        x0, y0, x1, y1 = region()
        text(d, (W / 2, y1 - 6), sc["note"], 42 if LAND else 36, WHITE, "md")


def draw_section(img, sc, t, u):
    back(img)
    x0, y0, x1, y1 = region()
    d = ImageDraw.Draw(img, "RGBA")
    km, s, bd = section_data()
    L_, R_ = x0 + (120 if LAND else 70), x1 - (90 if LAND else 50)
    top, bot = y0 + (150 if LAND else 190), y1 - (90 if LAND else 120)
    zmax, zmin = 4500.0, -3000.0
    X = L_ + (km - km[0]) / (km[-1] - km[0]) * (R_ - L_)

    def Y(z):
        return top + (zmax - z) / (zmax - zmin) * (bot - top)

    mode = sc.get("mode", "ice")
    sea_y = Y(0)
    k = ease(u * 1.5) if mode == "melt" else 0.0
    # 海(海面より下の全体)
    d.rectangle([L_, sea_y, R_, bot], fill=(26, 64, 120, 255))
    # 岩盤
    poly_b = [(X[i], Y(bd[i])) for i in range(len(km))] + [(R_, bot), (L_, bot)]
    d.polygon(poly_b, fill=(110, 92, 74, 255))
    # 氷
    rise = 0.0                                                # 58m はこの縮尺では線の太さほど。海面は動かさず、氷が消えた所に海が入る
    if mode != "melt" or k < 1:
        ice_top = s * (1 - k) + np.maximum(bd, 0) * k
        poly_i = [(X[i], Y(ice_top[i])) for i in range(len(km))] + [(X[i], Y(max(bd[i], -9999) if s[i] - bd[i] > 1 else s[i])) for i in range(len(km) - 1, -1, -1)]
        d.polygon(poly_i, fill=ICE + (int(255 * (1 - 0.8 * k)),))
    if mode == "below":                                       # 海面より下の氷を赤く(岩盤に乗っているもの)
        a = int(200 * min(1, u * 3))
        for i in range(len(km) - 1):
            if s[i] - bd[i] > 1 and bd[i] < 0 and (s[i] - bd[i]) * RI >= -bd[i] * RW:
                d.rectangle([X[i], sea_y, X[i + 1] + 1, Y(bd[i])], fill=RED + (a,))
    if mode == "melt":                                        # 氷が消え、海が入りこむ
        sy = Y(rise)
        for i in range(len(km) - 1):
            if bd[i] < rise:
                d.rectangle([X[i], sy, X[i + 1] + 1, Y(bd[i]) if bd[i] > 0 else sea_y], fill=(40, 100, 180, int(230 * k)))
    d.line([(L_, sea_y), (R_, sea_y)], fill=BLUE + (255,), width=3)
    text(d, (L_ + 10, sea_y - 26), "いまの海面", 34 if LAND else 30, BLUE, "lm")
    text(d, (L_, bot + 40), "西経110度の海", 34 if LAND else 28, DIM, "lm")
    text(d, (R_, bot + 40), "東経70度の海", 34 if LAND else 28, DIM, "rm")
    ip = int(np.argmin(np.abs(km - (90 - 72.5) * 111.32)))
    text(d, (X[ip], Y(s[ip]) - 34), "南極点", 36 if LAND else 30, WHITE)
    for lab in sc.get("labels", []):
        fx, z, s_, col = lab
        text(d, (L_ + fx * (R_ - L_), Y(z)), s_, 46 if LAND else 40, col)
    if sc.get("title"):
        text(d, (W / 2, y0 + 50), sc["title"], 58 if LAND else 48, YEL)
    if sc.get("note"):
        text(d, (W / 2, bot + 40 if not LAND else y1 - 6), sc["note"], 38 if LAND else 34, WHITE, "md" if LAND else "mm")


def draw_glass(img, sc, t, u):
    back(img)
    x0, y0, x1, y1 = region()
    d = ImageDraw.Draw(img, "RGBA")
    mode = sc.get("mode", "float")
    cx = W / 2
    gw, gh = (300, 420) if LAND else (340, 520)
    gy1 = (y0 + y1) / 2 + gh / 2 + (30 if LAND else 0)
    gy0 = gy1 - gh
    k = ease((u - 0.15) * 1.6)
    base_lv = gy1 - gh * 0.45
    if mode == "float":
        lv = base_lv
    else:
        lv = base_lv - gh * 0.12 * k
    d.rectangle([cx - gw / 2, lv, cx + gw / 2, gy1], fill=(70, 140, 220, 200))
    if mode == "rock":                                        # 岩の上に乗った氷
        d.rectangle([cx - gw * 0.32, gy1 - gh * 0.58, cx + gw * 0.32, gy1], fill=(120, 100, 80, 255))
        top = gy1 - gh * 0.58
        hh = gh * 0.36 * (1 - k)
        if hh > 2:
            d.rounded_rectangle([cx - gw * 0.26, top - hh, cx + gw * 0.26, top], 10, fill=ICE + (250,), outline=(180, 210, 240), width=3)
    else:
        s_ = (1 - k)
        if s_ > 0.03:
            bw, bh = gw * 0.42 * math.sqrt(s_), gh * 0.30 * math.sqrt(s_)
            sub = bh * 0.89
            d.rounded_rectangle([cx - bw / 2, lv - (bh - sub), cx + bw / 2, lv + sub], 12, fill=ICE + (235,), outline=(180, 210, 240), width=3)
    d.line([(cx - gw / 2, gy0), (cx - gw / 2, gy1), (cx + gw / 2, gy1), (cx + gw / 2, gy0)], fill=WHITE + (230,), width=6)
    d.line([(cx - gw / 2 - 60, base_lv), (cx + gw / 2 + 60, base_lv)], fill=YEL + (230,), width=3)
    text(d, (cx + gw / 2 + 70, base_lv), "とける前の水面", 36 if LAND else 32, YEL, "lm" if LAND else "lm")
    if sc.get("title"):
        text(d, (W / 2, y0 + 50), sc["title"], 60 if LAND else 48, YEL)
    if sc.get("note") and u > 0.55:
        text(d, (W / 2, y1 - 6), sc["note"], 44 if LAND else 38, WHITE, "md")


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


CUSTOM = dict(cards=draw_cards, polar=draw_polar, section=draw_section, glass=draw_glass, icons=draw_icons, bars=draw_bars)
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

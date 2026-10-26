"""2D の地図の場面(計算の回の draw から使う)。世界の陸地・日本の周りの海底地形・プレートの境目・震源の点・地名・矢印・範囲の四角。

素材(cache/geo、gitignore):
  ne_50m_land.geojson   Natural Earth 1:50m 陸地(パブリックドメイン)
  etopo_jp.npz          NOAA ETOPO1 の北緯18〜50度・東経118〜158度を 3 分ごと(海底の深さと陸の高さ)
  pb2002_*.json         Bird (2003) のプレート境界(fraxen/tectonicplates、ODC-BY。出典に「プレート境界 Bird (2003)」)
地図の投影: 正距円筒で、経度を cos(36°) 倍(日本の辺りで形が崩れないように)。経度は太平洋を真ん中(東経150度)に回す。

場面の書き方(行ごと。無ければ前の行の場面が続く):
  scene=dict(view=(経度, 緯度, 横幅の度), layers=[...], panel=...)
  layers: {"kind": "quakes"|"plates"|"box"|"label"|"arrow"|"line", "id": 名前, "at": 0〜1(行の中で出る時刻), ...}
  view は行の頭の 1.2 秒で前の行から移る。前の場面にも同じ id の層があれば、出たまま続く。
"""
from __future__ import annotations

import csv
import json
import math
from functools import lru_cache
from pathlib import Path
from typing import Dict, List, Sequence, Tuple

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

from . import overlay as ov
from .config import CACHE, H, W

GEO = CACHE / "geo"
QK = CACHE / "quakes"
KX = math.cos(math.radians(36))           # 経度の縮め
LON_C = 150.0                             # 世界図の真ん中の経度
OCEAN = (10, 30, 62)
WORLD_LAND = (78, 92, 70)
NORTH_AMERICA = {"NA", "OK"}
EURASIA = {"EU", "AM", "ON", "YA"}
PLATE_COL = {"PA": (90, 150, 230), "PS": (80, 200, 170), "NA": (240, 170, 70), "EU": (230, 100, 110)}
PLATE_NAME = {"PA": "太平洋プレート", "PS": "フィリピン海プレート", "NA": "北米プレート", "EU": "ユーラシアプレート"}


def wrap(lon: float) -> float:
    """太平洋が真ん中に来るように経度を回す(-180〜180 → 東経150度が 0)。"""
    return ((lon - LON_C + 180.0) % 360.0) - 180.0


def group(code: str) -> str:
    return "NA" if code in NORTH_AMERICA else "EU" if code in EURASIA else code


# ---- 下地 -------------------------------------------------------------------------------

WPX = 14                                   # 世界図の 1 度あたりの画素(経度は KX 倍)


@lru_cache(maxsize=1)
def world_base() -> Image.Image:
    w, h = int(360 * KX * WPX), int(180 * WPX)
    img = Image.new("RGB", (w, h), OCEAN)
    d = ImageDraw.Draw(img)
    gj = json.loads((GEO / "ne_50m_land.geojson").read_text(encoding="utf-8"))

    def xy(lon, lat):
        return ((lon + 180.0) * KX * WPX, (90.0 - lat) * WPX)

    for f in gj["features"]:
        g = f["geometry"]
        polys = g["coordinates"] if g["type"] == "MultiPolygon" else [g["coordinates"]]
        for poly in polys:
            ring = poly[0]
            # 経度を回し、つなぎ目をまたぐ多角形は 3 回(左・真ん中・右)描く
            pts = []
            prev = None
            for lon, lat in ring:
                x = wrap(lon)
                if prev is not None:
                    while x - prev > 180:
                        x -= 360
                    while x - prev < -180:
                        x += 360
                pts.append((x, lat))
                prev = x
            for off in (-360, 0, 360):
                d.polygon([xy(x + off, lat) for x, lat in pts], fill=WORLD_LAND)
    return img


RPX = 60                                    # 日本の周りの下地の 1 度あたりの画素


@lru_cache(maxsize=1)
def relief_base() -> Tuple[Image.Image, Tuple[float, float, float, float]]:
    """海底地形と陸の高さを色分けし、陰影を付けた下地。返り値は (画像, (西経度, 南緯度, 東経度, 北緯度))。"""
    z = np.load(GEO / "etopo_jp.npz")
    h = z["h"].astype(np.float32)
    lon0, lon1, lat0, lat1 = float(z["lon0"]), float(z["lon1"]), float(z["lat0"]), float(z["lat1"])
    w, hh = int((lon1 - lon0) * KX * RPX), int((lat1 - lat0) * RPX)
    big = np.asarray(Image.fromarray(h).resize((w, hh), Image.BICUBIC), np.float32)
    sea = [(-9500, (4, 12, 32)), (-7000, (8, 22, 52)), (-5000, (12, 36, 78)), (-3000, (18, 56, 108)),
           (-1500, (28, 82, 140)), (-400, (44, 110, 168)), (0, (70, 140, 190))]
    land = [(0, (58, 92, 58)), (300, (86, 116, 66)), (1000, (140, 140, 90)), (2000, (196, 178, 132)), (3200, (240, 232, 214))]
    col = np.zeros(big.shape + (3,), np.float32)
    for stops, mask in ((sea, big < 0), (land, big >= 0)):
        xs = [s[0] for s in stops]
        for c in range(3):
            col[..., c] = np.where(mask, np.interp(big, xs, [s[1][c] for s in stops]), col[..., c])
    gy, gx = np.gradient(big)
    shade = np.clip(1.0 + (-gx * 0.6 + gy * 0.6) / np.where(big < 0, 380.0, 160.0), 0.55, 1.35)
    col *= shade[..., None]
    return Image.fromarray(np.clip(col, 0, 255).astype(np.uint8)), (lon0, lat0, lon1, lat1)


# ---- 投影 -------------------------------------------------------------------------------

class View:
    def __init__(self, lon: float, lat: float, span: float):
        self.lon, self.lat, self.span = lon, lat, span      # span は画面の横幅に入る経度の幅
        self.s = W / (span * KX)                              # 1 度(経度 KX 倍後)あたりの画素

    def px(self, lon: float, lat: float) -> Tuple[float, float]:
        dx = wrap(lon) - wrap(self.lon)
        if dx > 180:
            dx -= 360
        elif dx < -180:
            dx += 360
        return W / 2 + dx * KX * self.s, H / 2 - (lat - self.lat) * self.s

    @staticmethod
    def lerp(a: "View", b: "View", u: float) -> "View":
        span = math.exp(math.log(a.span) + (math.log(b.span) - math.log(a.span)) * u)
        dl = wrap(b.lon) - wrap(a.lon)
        return View(a.lon + dl * u, a.lat + (b.lat - a.lat) * u, span)


def _warp(arr: np.ndarray, box, border, interp=None) -> np.ndarray:
    """arr の box=(x0, y0, x1, y1) の範囲を画面(W×H)に引き伸ばす(OpenCV。PIL の transform より何十倍も速い)。"""
    import cv2
    x0, y0, x1, y1 = box
    m = np.array([[(x1 - x0) / W, 0, x0], [0, (y1 - y0) / H, y0]], np.float64)
    return cv2.warpAffine(arr, m, (W, H), flags=(interp if interp is not None else cv2.INTER_LINEAR) | cv2.WARP_INVERSE_MAP,
                          borderMode=cv2.BORDER_CONSTANT, borderValue=border)


@lru_cache(maxsize=1)
def _arrays():
    """(世界図, 海底地形の下地に世界図を縁でなじませて混ぜた絵, 範囲)。混ぜるのは一度だけ(毎コマ混ぜると遅い)。"""
    import cv2
    rb, (lo0, la0, lo1, la1) = relief_base()
    wa, ra = np.asarray(world_base()), np.asarray(rb)
    h, w = ra.shape[:2]
    # 海底地形の下地の画素 → 世界図の画素
    x0 = (wrap(lo0) + 180.0) * KX * WPX
    y0 = (90.0 - la1) * WPX
    k = WPX / RPX
    m = np.array([[k, 0, x0], [0, k, y0]], np.float64)
    wr = cv2.warpAffine(wa, m, (w, h), flags=cv2.INTER_LINEAR | cv2.WARP_INVERSE_MAP, borderMode=cv2.BORDER_CONSTANT, borderValue=OCEAN)
    mask = (np.asarray(relief_mask()).astype(np.float32) / 255.0)[..., None]
    comb = (ra * mask + wr * (1 - mask)).astype(np.uint8)
    return wa, comb, (lo0, la0, lo1, la1)


def base(v: View) -> Image.Image:
    """その見え方の下地(世界図の上に、寄ったときは海底地形の下地を重ねる)。"""
    import cv2
    wa, comb, (lo0, la0, lo1, la1) = _arrays()
    fade = min(1.0, max(0.0, (75.0 - v.span) / 25.0))
    img = None
    if fade < 1:
        k = v.s / WPX
        x0 = (wrap(v.lon) + 180.0) * KX * WPX - (W / 2) / k
        y0 = (90.0 - v.lat) * WPX - (H / 2) / k
        img = _warp(wa, (x0, y0, x0 + W / k, y0 + H / k), OCEAN)
    if fade > 0:
        k2 = v.s / RPX
        cx = (wrap(v.lon) - wrap(lo0)) * KX * RPX
        cy = (la1 - v.lat) * RPX
        box2 = (cx - (W / 2) / k2, cy - (H / 2) / k2, cx + (W / 2) / k2, cy + (H / 2) / k2)
        r = _warp(comb, box2, OCEAN, cv2.INTER_AREA if k2 < 0.5 else cv2.INTER_LINEAR)
        img = r if img is None else cv2.addWeighted(r, fade, img, 1 - fade, 0)
    rgba = np.empty((H, W, 4), np.uint8)
    rgba[..., :3] = img
    rgba[..., 3] = 255
    return Image.fromarray(rgba, "RGBA")


@lru_cache(maxsize=1)
def relief_mask() -> Image.Image:
    """海底地形の下地の縁をぼかした重ね方の濃さ(一度だけ作る。毎コマぼかすと遅い)。"""
    rb, _ = relief_base()
    m = Image.new("L", rb.size, 0)
    e = 90
    ImageDraw.Draw(m).rectangle([e, e, rb.size[0] - e, rb.size[1] - e], fill=255)
    return m.filter(ImageFilter.GaussianBlur(40))


_QCACHE: dict = {}
MARGIN = 1.35                              # 点の下書きは画面より少し広く描く(ゆっくりした寄り引きでも端が切れないように)


def _quake_raster(L: dict, ref: View):
    """震源の点を ref の見え方で一度だけ描いた (色, 何番目の点か) の 2 枚。点は古い順に上に重ねる。"""
    key = (L.get("id"), L["data"], ref.lon, ref.lat, round(ref.span, 5), L.get("size", 1.0), L.get("by_depth", True))
    if key in _QCACHE:
        return _QCACHE[key]
    qs = quakes(L["data"], L.get("minmag", 0.0))
    f = L.get("filter")
    if f:
        qs = [q for q in qs if f(q)]
    w, h = int(W * MARGIN), int(H * MARGIN)
    ox, oy = (w - W) / 2, (h - H) / 2
    col = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    idx = Image.new("I", (w, h), 2 ** 30)
    dc, di = ImageDraw.Draw(col), ImageDraw.Draw(idx)
    sc = L.get("size", 1.0) * min(2.0, max(0.5, ref.s / 60))
    for i in range(len(qs) - 1, -1, -1):              # 新しい順に描き、古い点で上書き(idx は「いちばん古い点の番号」)
        lon, lat, dep, mag, _ = qs[i]
        x, y = ref.px(lon, lat)
        x, y = x + ox, y + oy
        if -10 < x < w + 10 and -10 < y < h + 10:
            r = (1.2 + max(0.0, mag - 4) * 1.5) * sc
            c = depth_col(dep) if L.get("by_depth", True) else tuple(L.get("color", ov.YEL))
            dc.ellipse([x - r, y - r, x + r, y + r], fill=c + (204,))
            di.ellipse([x - r, y - r, x + r, y + r], fill=i)
    if len(_QCACHE) > 24:
        _QCACHE.clear()
    _QCACHE[key] = (np.asarray(col).copy(), np.asarray(idx).astype(np.int32), len(qs))
    return _QCACHE[key]


def _ref_to_view(ref: View, v: View):
    """今の見え方 v の画素 → 下書き(ref、余白つき)の画素 の変換(Image.AFFINE に渡す係数)。"""
    w, h = W * MARGIN, H * MARGIN
    ox, oy = (w - W) / 2, (h - H) / 2
    dl = wrap(v.lon) - wrap(ref.lon)
    if dl > 180:
        dl -= 360
    elif dl < -180:
        dl += 360
    a = ref.s / v.s
    # x_ref = W/2 + ox + ((x - W/2)/(KX*v.s) + dl) * KX*ref.s
    c = W / 2 + ox + (-W / 2) * a + dl * KX * ref.s
    f = H / 2 + oy + (-H / 2) * a - (v.lat - ref.lat) * ref.s
    return (a, 0, c, 0, a, f)


# ---- データ -----------------------------------------------------------------------------

@lru_cache(maxsize=8)
def quakes(name: str, minmag: float = 0.0) -> List[Tuple[float, float, float, float, str]]:
    """cache/quakes の CSV(USGS)。name は 'japan_m4_2014_2023' か 'world_m6_2014-2023' のような年の範囲。"""
    files = []
    if name.startswith("world_m6_"):
        a, b = name[len("world_m6_"):].split("-")
        files = [QK / f"world_m6_{y}.csv" for y in range(int(a), int(b) + 1)]
    else:
        files = [QK / f"{name}.csv"]
    out = []
    for p in files:
        with open(p, encoding="utf-8") as f:
            for r in csv.DictReader(f):
                if r["type"] != "earthquake" or float(r["mag"]) < minmag:
                    continue
                out.append((float(r["longitude"]), float(r["latitude"]), float(r["depth"]), float(r["mag"]), r["time"]))
    out.sort(key=lambda q: q[4])
    return out


@lru_cache(maxsize=1)
def boundaries() -> List[dict]:
    gj = json.loads((GEO / "pb2002_boundaries.json").read_text(encoding="utf-8"))
    out = []
    for f in gj["features"]:
        p = f["properties"]
        a, b = group(p["PlateA"]), group(p["PlateB"])
        if a == b:
            continue
        out.append(dict(a=a, b=b, sub=p.get("Type") == "subduction", pts=f["geometry"]["coordinates"]))
    return out


@lru_cache(maxsize=1)
def plate_polys() -> Dict[str, list]:
    gj = json.loads((GEO / "pb2002_plates.json").read_text(encoding="utf-8"))
    out: Dict[str, list] = {}
    for f in gj["features"]:
        g = group(f["properties"]["Code"])
        if g not in PLATE_COL:
            continue
        geom = f["geometry"]
        polys = geom["coordinates"] if geom["type"] == "MultiPolygon" else [geom["coordinates"]]
        out.setdefault(g, []).extend(p[0] for p in polys)
    return out


SEEDS = {"PA": [(150, 30), (155, 40), (148, 20)], "PS": [(135, 25), (138, 30), (132, 20)],
         "NA": [(141, 40), (145, 46), (140, 37.5), (150, 48)], "EU": [(128, 38), (125, 30), (135, 40), (120, 45), (133, 34.5)]}


@lru_cache(maxsize=1)
def plate_raster() -> Tuple[Image.Image, Tuple[float, float, float, float]]:
    """日本の周りを、境目の線で区切って 4 枚のプレートの色で塗った RGBA(下地と同じ大きさ・範囲)。"""
    from scipy import ndimage
    rb, (lo0, la0, lo1, la1) = relief_base()
    w, h = rb.size
    wall = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(wall)

    def xy(lon, lat):
        return ((wrap(lon) - wrap(lo0)) * KX * RPX, (la1 - lat) * RPX)

    for bd in boundaries():
        seg = []
        for p in bd["pts"]:
            q = xy(*p)
            if seg and abs(q[0] - seg[-1][0]) > w / 2:     # 日付変更線で切る
                if len(seg) > 1:
                    d.line(seg, fill=255, width=7)
                seg = []
            seg.append(q)
        if len(seg) > 1:
            d.line(seg, fill=255, width=7)
    lab, n = ndimage.label(np.asarray(wall) == 0)
    rgba = np.zeros((h, w, 4), np.uint8)
    for g, seeds in SEEDS.items():
        for lon, lat in seeds:
            x, y = xy(lon, lat)
            if 0 <= int(x) < w and 0 <= int(y) < h and lab[int(y), int(x)] > 0:
                m = lab == lab[int(y), int(x)]
                rgba[m] = PLATE_COL[g] + (80,)
    return Image.fromarray(rgba, "RGBA"), (lo0, la0, lo1, la1)


# ---- 層 ---------------------------------------------------------------------------------

def depth_col(d: float) -> tuple:
    if d < 30:
        return (255, 222, 90)
    if d < 100:
        return (255, 150, 60)
    if d < 300:
        return (235, 70, 70)
    return (190, 90, 230)


def _poly_px(v: View, pts) -> list:
    out, prev = [], None
    for lon, lat in pts:
        x, y = v.px(lon, lat)
        if prev is not None and abs(x - prev[0]) > W:      # つなぎ目で線が画面を横切らないように切る
            out.append(None)
        out.append((x, y))
        prev = (x, y)
    return out


def draw_layer(img: Image.Image, v: View, L: dict, a: float, k: float, ref: View = None) -> None:
    """a は不透明度(0〜1)、k は出方の進み(0〜1。点の数・線の長さ)。ref を渡すと震源の点は下書きを使い回す(速い)。"""
    if a <= 0:
        return
    kind = L["kind"]
    if kind == "quakes" and ref is not None:
        import cv2
        col, idx, n_all = _quake_raster(L, ref)
        a0, _, c, _, a1, f = _ref_to_view(ref, v)
        m = np.array([[a0, 0, c], [0, a1, f]], np.float64)
        ct = cv2.warpAffine(col, m, (W, H), flags=cv2.INTER_LINEAR | cv2.WARP_INVERSE_MAP, borderMode=cv2.BORDER_CONSTANT, borderValue=(0, 0, 0, 0))
        it = cv2.warpAffine(idx, m, (W, H), flags=cv2.INTER_NEAREST | cv2.WARP_INVERSE_MAP, borderMode=cv2.BORDER_CONSTANT, borderValue=2 ** 30)
        ct[..., 3] = (ct[..., 3].astype(np.float32) * (it < int(n_all * k)) * a).astype(np.uint8)
        img.alpha_composite(Image.fromarray(ct, "RGBA"))
        return
    lay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(lay)
    A = int(255 * a)
    if kind == "quakes":
        qs = quakes(L["data"], L.get("minmag", 0.0))
        f = L.get("filter")
        if f:
            qs = [q for q in qs if f(q)]
        n = int(len(qs) * k)
        sc = L.get("size", 1.0) * min(2.0, max(0.5, v.s / 60))
        for lon, lat, dep, mag, _ in qs[:n]:
            x, y = v.px(lon, lat)
            if -10 < x < W + 10 and -10 < y < H + 10:
                r = (1.2 + max(0.0, mag - 4) * 1.5) * sc
                c = depth_col(dep) if L.get("by_depth", True) else L.get("color", ov.YEL)
                d.ellipse([x - r, y - r, x + r, y + r], fill=c + (int(A * 0.8),))
    elif kind == "plates":
        if L.get("fill"):
            pm, (lo0, la0, lo1, la1) = plate_raster()
            k2 = v.s / RPX
            cx = (wrap(v.lon) - wrap(lo0)) * KX * RPX
            cy = (la1 - v.lat) * RPX
            box2 = (cx - (W / 2) / k2, cy - (H / 2) / k2, cx + (W / 2) / k2, cy + (H / 2) / k2)
            fill = pm.transform((W, H), Image.EXTENT, box2, Image.NEAREST, fillcolor=(0, 0, 0, 0))
            if a < 1:
                fill.putalpha(fill.getchannel("A").point(lambda q: int(q * a)))
            lay.alpha_composite(fill)
        for bd in boundaries():
            q = _poly_px(v, bd["pts"])
            seg = []
            for pt in q + [None]:
                if pt is None:
                    if len(seg) > 1:
                        n = max(2, int(len(seg) * k))
                        d.line(seg[:n], fill=(255, 255, 255, A), width=5 if bd["sub"] else 3, joint="curve")
                    seg = []
                else:
                    seg.append(pt)
    elif kind == "box":
        (lo0, la0), (lo1, la1) = L["sw"], L["ne"]
        x0, y0 = v.px(lo0, la1)
        x1, y1 = v.px(lo1, la0)
        d.rectangle([x0, y0, x1, y1], outline=(255, 255, 255, A), width=4)
    elif kind == "line":
        (lo0, la0), (lo1, la1) = L["a"], L["b"]
        x0, y0 = v.px(lo0, la0)
        x1, y1 = v.px(lo1, la1)
        x1, y1 = x0 + (x1 - x0) * k, y0 + (y1 - y0) * k
        Lx = math.hypot(x1 - x0, y1 - y0)
        for s in range(0, int(Lx), 28):
            f0, f1 = s / max(1, Lx), min(Lx, s + 16) / max(1, Lx)
            d.line([(x0 + (x1 - x0) * f0, y0 + (y1 - y0) * f0), (x0 + (x1 - x0) * f1, y0 + (y1 - y0) * f1)], fill=(255, 255, 255, A), width=6)
    elif kind == "arrow":
        (lo0, la0), (lo1, la1) = L["a"], L["b"]
        x0, y0 = v.px(lo0, la0)
        x1, y1 = v.px(lo1, la1)
        x1, y1 = x0 + (x1 - x0) * k, y0 + (y1 - y0) * k
        col = tuple(L.get("color", ov.YEL))
        d.line([(x0, y0), (x1, y1)], fill=col + (A,), width=14)
        ang = math.atan2(y1 - y0, x1 - x0)
        hs = 34
        d.polygon([(x1 + math.cos(ang) * hs, y1 + math.sin(ang) * hs),
                   (x1 + math.cos(ang + 2.4) * hs, y1 + math.sin(ang + 2.4) * hs),
                   (x1 + math.cos(ang - 2.4) * hs, y1 + math.sin(ang - 2.4) * hs)], fill=col + (A,))
    img.alpha_composite(lay)
    if kind == "label":
        x, y = v.px(*L["at_ll"])
        f = ov.font(L.get("size", 44))
        t = L["text"]
        col = tuple(L.get("color", ov.WHITE))
        dd = ImageDraw.Draw(img)
        dd.text((x - f.getlength(t) / 2, y - f.size / 2), t, font=f, fill=col + (A,), stroke_width=6, stroke_fill=ov.NAVY + (A,))
        if a > 0.5:
            ov.BOXES.append(("label", (x - f.getlength(t) / 2, y - f.size / 2, x + f.getlength(t) / 2, y + f.size * 0.6), t, 1.0))


# ---- 場面 -------------------------------------------------------------------------------

def _ease(u: float) -> float:
    u = max(0.0, min(1.0, u))
    return u * u * (3 - 2 * u)


def scenes(lines: Sequence[dict], defs: Dict[str, dict]) -> List[dict]:
    """行ごとの場面(scene が無い行は前の行を引き継ぐ)。"""
    out, cur = [], None
    for l in lines:
        d = defs.get(l["id"], {})
        if d.get("scene") is not None:
            cur = d["scene"]
        out.append(cur)
    return out


def render(img: Image.Image, t: float, ctx: dict, drift: float = 0.02) -> View:
    """ctx は sim_ep の ctx。下地と層を描き、見え方を返す(パネルは呼んだ側で)。"""
    lines, defs = ctx["lines"], ctx["defs"]
    sc = ctx.setdefault("_scenes", scenes(lines, defs))
    cur = ctx["cur"] or lines[0]
    i = next(j for j, l in enumerate(lines) if l["id"] == cur["id"])
    now, prev = sc[i], sc[i - 1] if i > 0 else sc[i]
    vn = View(*now["view"])
    vp = View(*prev["view"]) if prev else vn
    u = _ease((t - cur["start"]) / 1.2)
    v = View.lerp(vp, vn, u) if now is not prev else vn
    v = View(v.lon, v.lat, v.span * (1 - drift * math.sin(2 * math.pi * t / 16.0)))   # 画面を止めない
    img.paste(base(v), (0, 0))
    dur = max(1e-6, cur["end"] - cur["start"])
    prev_ids = {L.get("id") for L in (prev or {}).get("layers", [])} if now is not prev else set()
    for L in now.get("layers", []):
        if L["kind"] == "label" and ctx.get("cta"):
            continue                                          # 登録のお願いの間は地図の札を消す(帯と重なるので)
        if L.get("id") in prev_ids:
            a, k = 1.0, 1.0
        else:
            t0 = cur["start"] + L.get("at", 0.0) * dur
            a = _ease((t - t0) / 0.5)
            k = _ease((t - t0) / max(0.3, L.get("grow", 0.6) * dur)) if L["kind"] in ("quakes", "plates", "line", "arrow") else 1.0
        draw_layer(img, v, L, a, k, ref=vn)
    return v


# ---- 重ねる枠(パネル) --------------------------------------------------------------------
# scene["panel"] = {"kind": "bars"|"section"|"big"|"quote"|"image"|"compare", "at": 0〜1, "box": (x0, y0, x1, y1)?, ...}

def _box(P: dict) -> tuple:
    if P.get("box"):
        return P["box"]
    if P["kind"] == "section" and H > W:
        return (W * 0.04, H * 0.40, W * 0.96, H * 0.78)     # 縦の断面図は大きく
    return (W * 0.52, H * 0.12, W * 0.96, H * 0.80) if W > H else (W * 0.06, H * 0.50, W * 0.94, H * 0.74)


def _frame(img: Image.Image, box, a: float) -> None:
    lay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(lay).rounded_rectangle(box, 22, fill=ov.NAVY + (int(222 * a),), outline=(255, 255, 255, int(110 * a)), width=2)
    img.alpha_composite(lay)


def draw_panel(img: Image.Image, P: dict, a: float, k: float) -> None:
    if a <= 0:
        return
    kind = P["kind"]
    box = _box(P)
    x0, y0, x1, y1 = box
    if kind == "compare":
        ov.compare(img, k, P, box)
        return
    _frame(img, box, a)
    d = ImageDraw.Draw(img)
    pad = 34
    if P.get("title"):
        f = ov.font(40)
        d.text((x0 + pad, y0 + 22), P["title"], font=f, fill=ov.DIM)
    if kind == "bars":
        items = P["items"]                                  # [(名前, 値)]
        top = max(v for _, v in items)
        n = len(items)
        gx0, gx1 = x0 + pad + 10, x1 - pad
        gy0, gy1 = y0 + 100, y1 - 70
        bw = (gx1 - gx0) / n
        longest = max(max(len(p) for p in nm.split("\n")) for nm, _ in items)
        fl, fv = ov.font(int(min(34, (bw * 0.95) / max(1, longest)))), ov.font(30 if n > 6 else 36)
        for i, (name, v) in enumerate(items):
            h = (gy1 - gy0) * (v / top) * _ease(k * n - i)
            bx0, bx1 = gx0 + i * bw + bw * 0.16, gx0 + (i + 1) * bw - bw * 0.16
            hl = i in P.get("hl", [])
            d.rectangle([bx0, gy1 - h, bx1, gy1], fill=ov.YEL if hl else ov.OCHRE)
            lab = P.get("fmt", "{:,}").format(v)
            if h > 2:
                d.text(((bx0 + bx1) / 2 - fv.getlength(lab) / 2, gy1 - h - 42), lab, font=fv, fill=ov.WHITE)
            for j, part in enumerate(name.split("\n")):
                d.text(((bx0 + bx1) / 2 - fl.getlength(part) / 2, gy1 + 12 + j * (fl.size + 4)), part, font=fl, fill=ov.DIM)
    elif kind == "section":
        from . import chart
        pts = P["pts"]                                      # [(経度, 深さ km)]
        lo0, lo1 = P["lon"]
        dmax = P.get("dmax", 200)
        ax = chart.Axes(int(x0 + 120), int(y0 + 90), int(x1 - pad), int(y1 - 80), (lo0, lo1), (-dmax, 0))
        ax.frame(d, [], [0, -dmax / 2, -dmax], "", "", fmt="{:g}")
        f = ov.font(30)
        d.text((x0 + 120, y1 - 62), P.get("left", "西"), font=f, fill=ov.DIM)
        rt = P.get("right", "東")
        d.text((x1 - pad - f.getlength(rt), y1 - 62), rt, font=f, fill=ov.DIM)
        n = int(len(pts) * k)
        for lon, dep in pts[:n]:
            px, py = ax.px(lon, -min(dep, dmax))
            c = depth_col(dep)
            d.ellipse([px - 5, py - 5, px + 5, py + 5], fill=c)
        if P.get("trend") and k >= 1:
            d.line([ax.px(*P["trend"][0]), ax.px(*P["trend"][1])], fill=ov.WHITE, width=5)
    elif kind == "big":
        f = ov.font(P.get("size", 150))
        t = P["text"]
        cy = (y0 + y1) / 2 - f.size * 0.6
        d.text(((x0 + x1) / 2 - f.getlength(t) / 2, cy), t, font=f, fill=ov.YEL, stroke_width=6, stroke_fill=ov.NAVY)
        if P.get("sub"):
            g = ov.font(44)
            d.text(((x0 + x1) / 2 - g.getlength(P["sub"]) / 2, cy + f.size * 1.15), P["sub"], font=g, fill=ov.WHITE)
    elif kind == "quote":
        ov.rows(d, P["text"], (y0 + y1) / 2 - 10, P.get("size", 52), maxw=int(x1 - x0 - pad * 2), cx=(x0 + x1) / 2, stroke=0)
        if P.get("src"):
            g = ov.font(30)
            d.text((x1 - pad - g.getlength(P["src"]), y1 - 56), P["src"], font=g, fill=ov.DIM)
    elif kind == "image":
        im = Image.open(P["path"]).convert("RGB")
        bw, bh = int(x1 - x0 - 16), int(y1 - y0 - 16)
        s = min(bw / im.width, bh / im.height)
        im = im.resize((int(im.width * s), int(im.height * s)), Image.LANCZOS)
        img.paste(im, (int((x0 + x1) / 2 - im.width / 2), int((y0 + y1) / 2 - im.height / 2)))
    ov.BOXES.append(("panel", box, "パネル", 1.0))


def draw(img: Image.Image, dr: ImageDraw.ImageDraw, t: float, ctx: dict) -> None:
    """計算の回の draw にそのまま使う(ep.py で from naze.mapscene import draw)。"""
    render(img, t, ctx)
    lines, defs = ctx["lines"], ctx["defs"]
    sc = ctx["_scenes"]
    cur = ctx["cur"] or lines[0]
    i = next(j for j, l in enumerate(lines) if l["id"] == cur["id"])
    P = (sc[i] or {}).get("panel")
    if P and not ctx.get("cta"):
        prevP = (sc[i - 1] or {}).get("panel") if i > 0 else None
        if prevP is P:
            draw_panel(img, P, 1.0, 1.0)
        else:
            t0 = cur["start"] + P.get("at", 0.0) * (cur["end"] - cur["start"])
            draw_panel(img, P, _ease((t - t0) / 0.4), _ease((t - t0) / max(0.4, P.get("grow", 1.2))))


def sfx(lines_def: Sequence[dict], L: dict) -> list:
    """場面が変わる行の頭に「シュッ」、パネルが出る瞬間に「ポン」。"""
    ev, prev = [], None
    for d in lines_def:
        if d["id"] not in L:
            continue
        s = d.get("scene")
        l = L[d["id"]]
        if s is not None and prev is not None:
            ev.append((l["start"], "whoosh"))
            if s.get("panel"):
                ev.append((l["start"] + s["panel"].get("at", 0.0) * (l["end"] - l["start"]), "pop"))
        if s is not None:
            prev = s
    return ev

"""世界のどこでも描ける立体の地図(計算の回の draw から使う)。下地は1本のあいだ1つで、寄り引き・傾きで動かし、上に層を足していく。

素材(cache/、gitignore):
  terrarium/{z}/{x}/{y}.png  Terrain Tiles(AWS Open Data、アカウント不要で課金なし。陸は SRTM・GMTED2010(USGS)、海底は ETOPO1(NOAA))
                             高さ = R*256 + G + B/256 - 32768 (m)。初めて使う範囲は自動で取ってくる
  ne/ne_10m_*.geojson        Natural Earth 10m の国・国境・都市(著作権放棄)
概要欄の出典: 「標高: Terrain Tiles(AWS Open Data。USGS SRTM・GMTED2010、NOAA ETOPO1)／国境: Natural Earth」

使い方(題材の scene.py か ep.py):
  M = worldmap.Map(lat0=-35, bases=[((-100, -62, -20, 16), 5), ((-78, -57, -64, -16), 8)])
  M.draw(img, t, ctx)             # 行の scene を描く(scene の無い行は前の行の場面が続く)
行の書き方: scene=dict(view=(経度, 緯度, 横幅の度, 傾きの度), layers=[...], panel=..., step=章の番号)
  view は行の頭の 1.4 秒で前の行から移る。前の場面にも同じ id の層があれば、出たまま続く(足していく見せ方)
  layers の kind:
    fill    {code: "CHL", color, alpha}               国を塗る(下地と同じ形で歪むので傾けてもずれない)
    outline {code, color, width}                      国の縁
    border  {a: "CHL", b: "ARG", color, width}        2国の境の線(k で伸びる)
    line    {pts: [(経度, 緯度), …], color, width, dash}  線(k で伸びる)
    arrow   {a, b, color}                             矢印
    hlines  {rows: [(緯度, 西経度, 東経度), …]}        輪切りの線(k で上から順に)
    label   {at_ll, text, size, color}                地図の上の字
    pin     {at_ll, text}                             点と地名
    ghost   {code: "JPN", at_ll, color}               国の形を本当の大きさのまま別の場所へ重ねる
    latline {lat, text}                               緯線
  panel: mapscene の draw_panel のもの(big・bars・compare・quote・steps)に加えて
    profile {a, b, title, names: [(0〜1, 名前)], exag}   2点を結ぶ線の地面の高さ・海の深さ
"""
from __future__ import annotations

import json
import math
import urllib.request
from functools import lru_cache
from pathlib import Path
from typing import Dict, List, Sequence, Tuple

import numpy as np
from PIL import Image, ImageDraw

from . import overlay as ov
from .config import CACHE, H, W

TT = CACHE / "terrarium"
NE = CACHE / "ne"
TT_URL = "https://s3.amazonaws.com/elevation-tiles-prod/terrarium/{z}/{x}/{y}.png"
SKY0, SKY1 = (14, 22, 40), (40, 58, 86)
SEA_EDGE = (16, 34, 64)
SEA = [(-8000, (5, 12, 32)), (-6000, (9, 22, 52)), (-4000, (15, 38, 80)), (-2000, (22, 58, 110)),
       (-200, (38, 92, 146)), (0, (62, 126, 172))]
LAND = [(0, (112, 120, 82)), (400, (138, 136, 92)), (1500, (166, 148, 108)), (3000, (184, 164, 132)),
        (4500, (210, 200, 184)), (6000, (246, 246, 248))]


# ---- 高さのタイル ---------------------------------------------------------------------------

def tile(z: int, x: int, y: int) -> np.ndarray:
    p = TT / str(z) / str(x) / f"{y}.png"
    if not p.exists():
        p.parent.mkdir(parents=True, exist_ok=True)
        req = urllib.request.Request(TT_URL.format(z=z, x=x, y=y), headers={"User-Agent": "naze-worldmap"})
        with urllib.request.urlopen(req, timeout=60) as r:
            p.write_bytes(r.read())
    a = np.asarray(Image.open(p).convert("RGB"), np.float32)
    return a[..., 0] * 256 + a[..., 1] + a[..., 2] / 256 - 32768


def merc_y(lat: float, n: int) -> float:
    s = math.log(math.tan(math.pi / 4 + math.radians(lat) / 2))
    return (1 - s / math.pi) / 2 * n


def heights(bbox, z: int, ppd: float) -> np.ndarray:
    """bbox=(西, 南, 東, 北) の高さを、緯度経度が等間隔の格子(1 度に ppd 画素)で返す。上が北。"""
    import cv2
    lo0, la0, lo1, la1 = bbox
    n = 256 * 2 ** z
    tx0, tx1 = int((lo0 + 180) / 360 * 2 ** z), int((lo1 + 180) / 360 * 2 ** z)
    ty0, ty1 = int(merc_y(la1, 2 ** z)), int(merc_y(la0, 2 ** z))
    from concurrent.futures import ThreadPoolExecutor
    mos = np.zeros(((ty1 - ty0 + 1) * 256, (tx1 - tx0 + 1) * 256), np.float32)
    jobs = [(tx, ty) for ty in range(ty0, ty1 + 1) for tx in range(tx0, tx1 + 1)]
    with ThreadPoolExecutor(8) as ex:
        for (tx, ty), a in zip(jobs, ex.map(lambda j: tile(z, *j), jobs)):
            mos[(ty - ty0) * 256:(ty - ty0 + 1) * 256, (tx - tx0) * 256:(tx - tx0 + 1) * 256] = a
    w, h = int((lo1 - lo0) * ppd), int((la1 - la0) * ppd)
    lons = lo0 + (np.arange(w) + 0.5) / ppd
    lats = la1 - (np.arange(h) + 0.5) / ppd
    mx = ((lons + 180) / 360 * n - tx0 * 256).astype(np.float32)
    my = np.array([merc_y(la, n) for la in lats], np.float32) - ty0 * 256
    return cv2.remap(mos, np.tile(mx, (h, 1)), np.tile(my[:, None], (1, w)), cv2.INTER_LINEAR)


def colorize(e: np.ndarray, px_m: float, kx: float) -> np.ndarray:
    """高さ → 色分け＋陰影(北西から光)。px_m は南北 1 画素の m、東西は kx 倍。"""
    col = np.zeros(e.shape + (3,), np.float32)
    for stops, m in ((SEA, e < 0), (LAND, e >= 0)):
        xs = [s[0] for s in stops]
        for c in range(3):
            col[..., c] = np.where(m, np.interp(e, xs, [s[1][c] for s in stops]), col[..., c])
    gy, gx = np.gradient(e)
    gx, gy = gx / (px_m * kx), -gy / px_m                    # 東へ・北へ の傾き
    ex = np.where(e < 0, 6.0, 3.0)                            # 起伏を強める(海底はもっと)
    nx, ny = -gx * ex, -gy * ex
    lx, ly, lz = -0.6, 0.6, 0.53                              # 北西の高い空から
    shade = (nx * lx + ny * ly + lz) / np.sqrt(nx * nx + ny * ny + 1)
    shade = np.clip(0.35 + 1.25 * shade, 0.45, 1.4)
    return np.clip(col * shade[..., None], 0, 255).astype(np.uint8)


# ---- 国境のデータ ---------------------------------------------------------------------------

@lru_cache(maxsize=1)
def countries() -> Dict[str, list]:
    gj = json.loads((NE / "ne_10m_admin_0_countries.geojson").read_text(encoding="utf-8"))
    out: Dict[str, list] = {}
    for f in gj["features"]:
        g = f["geometry"]
        polys = g["coordinates"] if g["type"] == "MultiPolygon" else [g["coordinates"]]
        out[f["properties"]["ADM0_A3"]] = [p[0] for p in polys]
    return out


@lru_cache(maxsize=1)
def land_borders() -> List[Tuple[str, str, list]]:
    gj = json.loads((NE / "ne_10m_admin_0_boundary_lines_land.geojson").read_text(encoding="utf-8"))
    out = []
    for f in gj["features"]:
        p, g = f["properties"], f["geometry"]
        parts = g["coordinates"] if g["type"] == "MultiLineString" else [g["coordinates"]]
        for pts in parts:
            out.append((p["ADM0_A3_L"], p["ADM0_A3_R"], pts))
    return out


def border_between(a: str, b: str) -> list:
    """a と b の境の線を、北から南(または西から東)へつないだ点の列(つながらない所は None で区切る)。"""
    segs = [pts for l, r, pts in land_borders() if {l, r} == {a, b}]
    out = []
    for s in sorted(segs, key=lambda s: -max(p[1] for p in s)):
        if s[0][1] < s[-1][1]:
            s = s[::-1]
        if out:
            out.append(None)
        out.extend(s)
    return out


# ---- 地図 -------------------------------------------------------------------------------------

class Base:
    """1 つの範囲の下地。cols は色＋陰影＋国境、e は高さ、ppd は 1 度あたりの画素(経度は kx 倍で縮めない。等間隔の格子)。"""

    def __init__(self, bbox, z: int, kx: float):
        import cv2
        self.bbox, self.z = bbox, z
        lo0, la0, lo1, la1 = bbox
        self.ppd = 256 * 2 ** z / 360 * 1.0
        key = TT / f"base_{z}_{lo0}_{la0}_{lo1}_{la1}.npz"
        if key.exists():
            self.e = np.load(key)["e"]
        else:
            self.e = heights(bbox, z, self.ppd).astype(np.float32)
            np.savez_compressed(key, e=self.e.astype(np.int16))
        self.e = self.e.astype(np.float32)
        h, w = self.e.shape
        # 東西に kx 倍縮めた格子に置き直す(画面で形が崩れないように)
        self.w = int(w * kx)
        self.e = cv2.resize(self.e, (self.w, h), interpolation=cv2.INTER_AREA)
        self.kx = kx
        col = colorize(self.e, 111320 / self.ppd, 1.0)
        im = Image.fromarray(col)
        d = ImageDraw.Draw(im, "RGBA")
        lw = max(1, int(round(self.ppd / 60)))
        for code, rings in countries().items():
            for r in rings:
                if self._near(r):
                    d.line([self.xy(*p) for p in r], fill=(225, 232, 240, 70), width=lw)
        for _, _, pts in land_borders():
            if self._near(pts):
                d.line([self.xy(*p) for p in pts], fill=(250, 250, 250, 170), width=lw + 1)
        self.levels = [np.asarray(im)]
        while self.levels[-1].shape[1] > 1200:
            self.levels.append(cv2.pyrDown(self.levels[-1]))
        self._masks: Dict[str, list] = {}

    def _near(self, pts) -> bool:
        lo0, la0, lo1, la1 = self.bbox
        return any(lo0 - 2 <= x <= lo1 + 2 and la0 - 2 <= y <= la1 + 2 for x, y in pts[:: max(1, len(pts) // 50)] + [pts[-1]])

    def xy(self, lon: float, lat: float) -> Tuple[float, float]:
        lo0, la0, lo1, la1 = self.bbox
        return (lon - lo0) * self.ppd * self.kx, (la1 - lat) * self.ppd

    def covers(self, lon, lat, span) -> bool:
        lo0, la0, lo1, la1 = self.bbox
        return lo0 <= lon - span / 2 and lon + span / 2 <= lo1 and la0 <= lat <= la1

    def mask(self, code: str, level: int) -> np.ndarray:
        import cv2
        if code not in self._masks:
            h, w = self.levels[0].shape[:2]
            m = np.zeros((h, w), np.uint8)
            for r in countries()[code]:
                if self._near(r):
                    cv2.fillPoly(m, [np.array([self.xy(*p) for p in r], np.int32)], 255, lineType=cv2.LINE_AA)
            ms = [m]
            while len(ms) < len(self.levels):
                ms.append(cv2.pyrDown(ms[-1]))
            self._masks[code] = ms
        return self._masks[code][level]

    def height_at(self, lon: float, lat: float) -> float:
        x, y = self.xy(lon, lat)
        h, w = self.e.shape
        return float(self.e[min(h - 1, max(0, int(y))), min(w - 1, max(0, int(x)))])


class View:
    """lon, lat を画面の真ん中に、横幅 span 度(経度)、tilt 度だけ手前に傾けて見る。"""

    def __init__(self, lon: float, lat: float, span: float, tilt: float = 0.0, kx: float = 1.0):
        self.lon, self.lat, self.span, self.tilt, self.kx = lon, lat, span, tilt, kx
        self.s = W / (span * kx)                              # 平らにしたときの 1 度あたりの画素
        t = math.radians(tilt)
        D = 1.0 * H
        self.M = np.array([[D, (W / 2) * math.sin(t), (W / 2) * D],
                           [0, -D * math.cos(t) + (H / 2) * math.sin(t), (H / 2) * D],
                           [0, math.sin(t), D]], np.float64)

    def ground(self, lon, lat):
        """平らな地面の上の、真ん中からの画素(X 東、Y 北)。"""
        return (lon - self.lon) * self.kx * self.s, (lat - self.lat) * self.s

    def px(self, lon: float, lat: float) -> Tuple[float, float]:
        X, Y = self.ground(lon, lat)
        v = self.M @ np.array([X, Y, 1.0])
        return v[0] / v[2], v[1] / v[2]

    @staticmethod
    def lerp(a: "View", b: "View", u: float) -> "View":
        span = math.exp(math.log(a.span) + (math.log(b.span) - math.log(a.span)) * u)
        return View(a.lon + (b.lon - a.lon) * u, a.lat + (b.lat - a.lat) * u, span, a.tilt + (b.tilt - a.tilt) * u, a.kx)


def _ease(u: float) -> float:
    u = max(0.0, min(1.0, u))
    return u * u * (3 - 2 * u)


class Map:
    def __init__(self, lat0: float, bases: Sequence[tuple]):
        self.kx = math.cos(math.radians(lat0))
        self.spec = list(bases)
        self._bases = None

    @property
    def bases(self) -> List[Base]:
        if self._bases is None:
            self._bases = [Base(bb, z, self.kx) for bb, z in self.spec]     # 粗い順
        return self._bases

    def view(self, lon, lat, span, tilt=0.0) -> View:
        return View(lon, lat, span, tilt, self.kx)

    # -- 下地 --
    def _warp(self, b: Base, v: View, src: np.ndarray, level: int, border) -> np.ndarray:
        import cv2
        f = 2 ** level
        bx, by = b.xy(v.lon, v.lat)
        k = v.s / b.ppd                                       # 下地の画素 → 平らな画面の画素
        T = np.array([[k * f, 0, -bx * k], [0, -k * f, by * k], [0, 0, 1]], np.float64)
        return cv2.warpPerspective(src, v.M @ T, (W, H), flags=cv2.INTER_LINEAR, borderMode=cv2.BORDER_CONSTANT, borderValue=border)

    def _level(self, b: Base, v: View) -> int:
        k = v.s / b.ppd
        lv = 0
        while lv + 1 < len(b.levels) and k * 2 ** (lv + 1) <= 1.3:
            lv += 1
        return lv

    def base_img(self, v: View) -> np.ndarray:
        import cv2
        out = None
        for b in self.bases:
            if out is not None and not b.covers(v.lon, v.lat, v.span * 0.6):
                continue
            if out is not None and v.s / b.ppd < 0.35:        # 引いているときは細かい下地は要らない
                continue
            lv = self._level(b, v)
            r = self._warp(b, v, b.levels[lv], lv, SEA_EDGE)
            if out is None:
                out = r
            else:
                a = np.full(b.levels[lv].shape[:2], 255, np.uint8)
                e = max(4, a.shape[1] // 40)
                a[:e], a[-e:], a[:, :e], a[:, -e:] = 0, 0, 0, 0
                m = cv2.GaussianBlur(self._warp(b, v, a, lv, 0), (0, 0), 6).astype(np.float32)[..., None] / 255
                out = (r * m + out * (1 - m)).astype(np.uint8)
        if v.tilt > 1:                                         # 奥をかすませて空に溶かす
            hz = v.px(v.lon, v.lat + 400)[1]
            ys = np.arange(H, dtype=np.float32)[:, None]
            fog = np.clip(1 - (ys - hz) / (H * 0.45), 0, 1) ** 2 * 0.75
            sky = np.array(SKY1, np.float32)
            out = (out * (1 - fog[..., None]) + sky * fog[..., None]).astype(np.uint8)
        return out

    def best(self, v: View) -> Tuple[Base, int]:
        b = next((b for b in reversed(self.bases) if b.covers(v.lon, v.lat, v.span * 0.6) and v.s / b.ppd >= 0.35), self.bases[0])
        return b, self._level(b, v)

    # -- 層 --
    def layer(self, img: Image.Image, v: View, L: dict, a: float, k: float) -> None:
        if a <= 0:
            return
        kind = L["kind"]
        A = int(255 * a)
        col = tuple(L.get("color", ov.RED))
        if kind in ("fill", "outline"):
            import cv2
            out = np.zeros((H, W, 4), np.uint8)
            for b in self.bases:
                if b is not self.best(v)[0]:
                    continue
                lv = self._level(b, v)
                m = self._warp(b, v, b.mask(L["code"], lv), lv, 0)
                if kind == "outline":
                    wd = L.get("width", 4)
                    m = cv2.morphologyEx(m, cv2.MORPH_GRADIENT, np.ones((wd, wd), np.uint8))
                out[..., :3] = col
                out[..., 3] = (m.astype(np.float32) * (L.get("alpha", 0.45) if kind == "fill" else 1.0) * a).astype(np.uint8)
            img.alpha_composite(Image.fromarray(out, "RGBA"))
            return
        lay = Image.new("RGBA", img.size, (0, 0, 0, 0))
        d = ImageDraw.Draw(lay)
        if kind in ("border", "line"):
            pts = border_between(L["a"], L["b"]) if kind == "border" else list(L["pts"])
            pts = self._dense(pts)
            n = max(2, int(len(pts) * k))
            seg = []
            for p in pts[:n] + [None]:
                if p is None:
                    if len(seg) > 1:
                        if L.get("glow"):
                            d.line(seg, fill=col + (int(A * 0.35),), width=L.get("width", 6) * 3, joint="curve")
                        d.line(seg, fill=col + (A,), width=L.get("width", 6), joint="curve")
                    seg = []
                else:
                    seg.append(v.px(*p))
        elif kind == "arrow":
            x0, y0 = v.px(*L["a"])
            x1, y1 = v.px(*L["b"])
            x1, y1 = x0 + (x1 - x0) * k, y0 + (y1 - y0) * k
            col = tuple(L.get("color", ov.YEL))
            d.line([(x0, y0), (x1, y1)], fill=col + (A,), width=L.get("width", 14))
            ang = math.atan2(y1 - y0, x1 - x0)
            hs = 36
            d.polygon([(x1 + math.cos(ang) * hs, y1 + math.sin(ang) * hs),
                       (x1 + math.cos(ang + 2.4) * hs, y1 + math.sin(ang + 2.4) * hs),
                       (x1 + math.cos(ang - 2.4) * hs, y1 + math.sin(ang - 2.4) * hs)], fill=col + (A,))
        elif kind == "hlines":
            rows = L["rows"]
            n = int(round(len(rows) * k))
            for i, (lat, w0, w1) in enumerate(rows[:n]):
                last = i == n - 1
                d.line([v.px(w0, lat), v.px(w1, lat)], fill=(ov.YEL if last else (255, 255, 255)) + (A if last else int(A * 0.55),), width=5 if last else 3)
        elif kind == "latline":
            pts = [v.px(lo, L["lat"]) for lo in np.linspace(v.lon - v.span, v.lon + v.span, 40)]
            for i in range(0, len(pts) - 1, 2):
                d.line([pts[i], pts[i + 1]], fill=(255, 255, 255, int(A * 0.8)), width=3)
        elif kind == "ghost":
            self._ghost(d, v, L, A)
        img.alpha_composite(lay)
        if kind == "label":
            x, y = v.px(*L["at_ll"])
            f = ov.font(L.get("size", 44))
            t = L["text"]
            col = tuple(L.get("color", ov.WHITE))
            dd = ImageDraw.Draw(img)
            anchor = L.get("anchor", "mm")
            dd.text((x, y), t, font=f, fill=col + (A,), anchor=anchor, stroke_width=6, stroke_fill=ov.NAVY + (A,))
            if a > 0.5:
                bx = dd.textbbox((x, y), t, font=f, anchor=anchor)
                ov.BOXES.append(("label", bx, t, 1.0))
        elif kind == "pin":
            x, y = v.px(*L["at_ll"])
            ov.pin(img, x, y, L["text"], alpha=0.95 * a, size=L.get("size", 36))

    def _dense(self, pts):
        """長い線分を細かく切る(傾けたときに曲がって見えるように)。"""
        out = []
        for i, p in enumerate(pts):
            if p is None or not out or out[-1] is None:
                out.append(p)
                continue
            q = out[-1]
            n = int(max(abs(p[0] - q[0]), abs(p[1] - q[1])) / 0.25)
            for j in range(1, n):
                out.append((q[0] + (p[0] - q[0]) * j / n, q[1] + (p[1] - q[1]) * j / n))
            out.append(p)
        return out

    @lru_cache(maxsize=8)
    def _ghost_km(self, code: str):
        """その国の形を、国の真ん中から東へ・北へ何 km かの点の列に(小さな島は省く)。"""
        rings = [r for r in countries()[code] if len(r) > 8]
        lons = [p[0] for r in rings for p in r]
        lats = [p[1] for r in rings for p in r]
        c = ((min(lons) + max(lons)) / 2, (min(lats) + max(lats)) / 2)
        out = []
        for r in rings:
            out.append([((x - c[0]) * 111.32 * math.cos(math.radians(y)), (y - c[1]) * 111.32) for x, y in r[::2]])
        return tuple(tuple(r) for r in out)

    def _ghost(self, d, v: View, L: dict, A: int) -> None:
        lon0, lat0 = L["at_ll"]
        col = tuple(L.get("color", (255, 255, 255)))
        for r in self._ghost_km(L["code"]):
            pts = []
            for ex, ny in r:
                lat = lat0 + ny / 111.32
                pts.append(v.px(lon0 + ex / (111.32 * math.cos(math.radians(lat))), lat))
            if len(pts) > 2:
                d.polygon(pts, fill=col + (int(A * 0.35),), outline=col + (A,), width=3)

    # -- 断面 --
    def profile(self, a, b, n: int = 400):
        """a→b の大円に沿った (距離 km, 高さ m) の列。いちばん細かい下地で測る。"""
        out = []
        p1, l1, p2, l2 = map(math.radians, (a[1], a[0], b[1], b[0]))
        dist = 2 * 6371 * math.asin(math.sqrt(math.sin((p2 - p1) / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin((l2 - l1) / 2) ** 2))
        for i in range(n + 1):
            u = i / n
            lon, lat = a[0] + (b[0] - a[0]) * u, a[1] + (b[1] - a[1]) * u
            bb = next((x for x in reversed(self.bases) if x.bbox[0] <= lon <= x.bbox[2] and x.bbox[1] <= lat <= x.bbox[3]), self.bases[0])
            out.append((dist * u, bb.height_at(lon, lat)))
        return out

    def draw_profile(self, img: Image.Image, P: dict, a: float, k: float, box) -> None:
        x0, y0, x1, y1 = box
        lay = Image.new("RGBA", img.size, (0, 0, 0, 0))
        dl = ImageDraw.Draw(lay)
        dl.rounded_rectangle(box, 22, fill=ov.NAVY + (int(225 * a),), outline=(255, 255, 255, int(110 * a)), width=2)
        img.alpha_composite(lay)
        d = ImageDraw.Draw(img)
        pr = P.get("_pts") or self.profile(P["a"], P["b"])
        P["_pts"] = pr
        pad = 34
        if P.get("title"):
            d.text((x0 + pad, y0 + 20), P["title"], font=ov.font(38), fill=ov.DIM)
        gx0, gx1, gy0, gy1 = x0 + pad, x1 - pad, y0 + 90, y1 - 70
        lo = min(min(e for _, e in pr), P.get("min", 0))
        hi = max(max(e for _, e in pr), P.get("max", 1000))
        dist = pr[-1][0]

        def q(x, e):
            return gx0 + (gx1 - gx0) * x / dist, gy1 - (gy1 - gy0) * (e - lo) / (hi - lo)

        n = max(2, int(len(pr) * k))
        y_sea = q(0, 0)[1]
        if lo < 0:
            d.rectangle([gx0, y_sea, gx0 + (gx1 - gx0) * n / len(pr), gy1], fill=(22, 58, 110))
        poly = [q(x, e) for x, e in pr[:n]]
        d.polygon(poly + [(poly[-1][0], gy1), (poly[0][0], gy1)], fill=(166, 148, 108))
        d.line(poly, fill=ov.WHITE, width=3)
        d.line([(gx0, y_sea), (gx1, y_sea)], fill=(140, 190, 230), width=2)
        f = ov.font(30)
        d.text((gx0, gy1 + 14), "0km", font=f, fill=ov.DIM)
        t = f"{dist:,.0f}km"
        d.text((gx1 - f.getlength(t), gy1 + 14), t, font=f, fill=ov.DIM)
        for u, name in P.get("names", []):
            if u * len(pr) <= n:
                x, e = pr[min(len(pr) - 1, int(u * (len(pr) - 1)))]
                px, py = q(x, e)
                d.text((px, py - 10), name, font=ov.font(32), fill=ov.YEL, anchor="md", stroke_width=4, stroke_fill=ov.NAVY)
        ov.BOXES.append(("panel", box, "断面", 1.0))

    # -- 上の帯(いまどこか) --
    @staticmethod
    def steps_band(img: Image.Image, items: Sequence[str], cur: int) -> None:
        f = ov.font(30)
        widths = [f.getlength(s) + 44 for s in items]
        x = W / 2 - (sum(widths) + 10 * (len(items) - 1)) / 2
        y0, y1 = 34, 84
        lay = Image.new("RGBA", img.size, (0, 0, 0, 0))
        d = ImageDraw.Draw(lay)
        for i, (s, w) in enumerate(zip(items, widths)):
            on = i == cur
            d.rounded_rectangle([x, y0, x + w, y1], 12, fill=(ov.YEL + (235,)) if on else (ov.NAVY + (190,)),
                                outline=(255, 255, 255, 120), width=2)
            d.text((x + w / 2, (y0 + y1) / 2), s, font=f, fill=ov.NAVY if on else (200, 208, 222), anchor="mm")
            x += w + 10
        img.alpha_composite(lay)
        ov.BOXES.append(("corner", (W / 2 - sum(widths) / 2, y0, W / 2 + sum(widths) / 2, y1), "帯", 1.0))

    # -- 場面 --
    def scenes(self, lines, defs):
        out, cur = [], None
        for l in lines:
            d = defs.get(l["id"], {})
            if d.get("scene") is not None:
                cur = d["scene"]
            out.append(cur)
        return out

    def draw(self, img: Image.Image, t: float, ctx: dict, steps: Sequence[str] = None) -> View:
        from . import mapscene
        lines, defs = ctx["lines"], ctx["defs"]
        sc = ctx.setdefault("_wscenes", self.scenes(lines, defs))
        cur = ctx["cur"] or lines[0]
        i = next(j for j, l in enumerate(lines) if l["id"] == cur["id"])
        now = sc[i]
        prev = sc[i - 1] if i > 0 else now
        vn = self.view(*now["view"])
        vp = self.view(*prev["view"]) if prev else vn
        v = View.lerp(vp, vn, _ease((t - cur["start"]) / 1.4)) if now is not prev else vn
        v = View(v.lon, v.lat, v.span * (1 - 0.025 * math.sin(2 * math.pi * t / 18.0)), v.tilt, v.kx)   # 画面を止めない
        img.paste(Image.fromarray(self.base_img(v)).convert("RGBA"), (0, 0))
        dur = max(1e-6, cur["end"] - cur["start"])
        prev_ids = {L.get("id") for L in (prev or {}).get("layers", [])} if now is not prev else set()
        for L in now.get("layers", []):
            if ctx.get("cta") and L["kind"] in ("label", "pin"):
                continue
            if L.get("id") in prev_ids:
                a, k = 1.0, 1.0
            else:
                t0 = cur["start"] + L.get("at", 0.0) * dur
                a = _ease((t - t0) / 0.5)
                k = _ease((t - t0) / max(0.3, L.get("grow", 0.6) * dur)) if L["kind"] in ("border", "line", "arrow", "hlines") else 1.0
            self.layer(img, v, L, a, k)
        P = now.get("panel")
        if P and not ctx.get("cta"):
            same = (prev or {}).get("panel") is P
            t0 = cur["start"] + P.get("at", 0.0) * dur
            a, k = (1.0, 1.0) if same else (_ease((t - t0) / 0.4), _ease((t - t0) / max(0.4, P.get("grow", 1.4))))
            if a > 0:
                if P["kind"] == "profile":
                    self.draw_profile(img, P, a, k, mapscene._box(P))
                else:
                    mapscene.draw_panel(img, P, a, k)
        if steps and now.get("step") is not None:
            self.steps_band(img, steps, now["step"])
        return v


def sfx(lines_def: Sequence[dict], L: dict) -> list:
    """場面が変わる行の頭に「シュッ」、層やパネルが出る瞬間に「ポン」。"""
    ev, prev_ids, prevP = [], set(), None
    for d in lines_def:
        s = d.get("scene")
        if d["id"] not in L or s is None:
            continue
        l = L[d["id"]]
        dur = l["end"] - l["start"]
        if prev_ids or prevP:
            ev.append((l["start"], "whoosh"))
        for Ly in s.get("layers", []):
            if Ly.get("id") not in prev_ids and Ly["kind"] in ("label", "pin", "ghost", "fill"):
                ev.append((l["start"] + Ly.get("at", 0.0) * dur, "pop"))
        if s.get("panel") and s["panel"] is not prevP:
            ev.append((l["start"] + s["panel"].get("at", 0.0) * dur, "pop"))
        prev_ids = {Ly.get("id") for Ly in s.get("layers", [])}
        prevP = s.get("panel")
    return sorted(set(ev))

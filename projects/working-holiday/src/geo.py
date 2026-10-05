"""世界地図とヨーロッパ拡大図を、ビルド時に SVG の path にする。

元データは data/geo/countries-50m.json（world-atlas 2.0.2。Natural Earth 由来、ISC ライセンス）。
TopoJSON を自前で読み、Equal Earth 図法で平面に移し、画面上で見分けられない細かい点を間引く。
ページには <svg> をそのまま埋め込む（外部のスクリプトも地図タイルも使わない）。
"""
from __future__ import annotations

import json
import math
from functools import lru_cache
from pathlib import Path

_GEO = Path(__file__).resolve().parent.parent / "data" / "geo" / "countries-50m.json"

# サイトの国 id → ISO 3166-1 数字コード（world-atlas の id）。日本は出発地として別の色にする。
ISO_NUM = {
    "australia": "036", "new-zealand": "554", "canada": "124", "korea": "410", "france": "250",
    "germany": "276", "uk": "826", "ireland": "372", "denmark": "208", "taiwan": "158",
    "hong-kong": "344", "norway": "578", "portugal": "620", "poland": "616", "slovakia": "703",
    "austria": "040", "hungary": "348", "spain": "724", "argentina": "032", "chile": "152",
    "iceland": "352", "czechia": "203", "lithuania": "440", "sweden": "752", "estonia": "233",
    "netherlands": "528", "uruguay": "858", "finland": "246", "latvia": "428", "luxembourg": "442",
    "malta": "470", "italy": "380",
}
JAPAN = "392"
ANTARCTICA = "010"

# 地図上で面が小さすぎて押せない国には、首都の位置に点を打つ（経度, 緯度）。
MARKERS = {
    "hong-kong": (114.17, 22.32),
    "luxembourg": (6.13, 49.61),
    "malta": (14.51, 35.90),
}

# 国旗のファイル名（static/flags/<code>.svg。flag-icons 7.2.3、MIT ライセンス）。
FLAG = {
    "australia": "au", "new-zealand": "nz", "canada": "ca", "korea": "kr", "france": "fr",
    "germany": "de", "uk": "gb", "ireland": "ie", "denmark": "dk", "taiwan": "tw", "hong-kong": "hk",
    "norway": "no", "portugal": "pt", "poland": "pl", "slovakia": "sk", "austria": "at",
    "hungary": "hu", "spain": "es", "argentina": "ar", "chile": "cl", "iceland": "is", "czechia": "cz",
    "lithuania": "lt", "sweden": "se", "estonia": "ee", "netherlands": "nl", "uruguay": "uy",
    "finland": "fi", "latvia": "lv", "luxembourg": "lu", "malta": "mt", "italy": "it",
}

_A1, _A2, _A3, _A4 = 1.340264, -0.081106, 0.000893, 0.003796
_M = math.sqrt(3) / 2


def equal_earth(lon: float, lat: float) -> tuple[float, float]:
    """Equal Earth 図法（Šavrič ほか 2018）。単位は地球半径1。y は北が負（SVG の向き）。"""
    lam, phi = math.radians(lon), math.radians(lat)
    t = math.asin(_M * math.sin(phi))
    t2 = t * t
    t6 = t2 * t2 * t2
    x = 2 * math.sqrt(3) * lam * math.cos(t) / (3 * (9 * _A4 * t6 * t2 + 7 * _A3 * t6 + 3 * _A2 * t2 + _A1))
    y = t * (_A4 * t6 * t2 + _A3 * t6 + _A2 * t2 + _A1)
    return x, -y


@lru_cache(maxsize=1)
def _topology() -> tuple[list[list[tuple[float, float]]], list[dict]]:
    topo = json.loads(_GEO.read_text(encoding="utf-8"))
    sx, sy = topo["transform"]["scale"]
    tx, ty = topo["transform"]["translate"]
    arcs = []
    for arc in topo["arcs"]:
        x = y = 0
        pts = []
        for dx, dy in arc:
            x += dx
            y += dy
            pts.append((x * sx + tx, y * sy + ty))
        arcs.append(pts)
    return arcs, topo["objects"]["countries"]["geometries"]


def _ring(arcs, indexes: list[int]) -> list[tuple[float, float]]:
    pts: list[tuple[float, float]] = []
    for i in indexes:
        seg = arcs[i] if i >= 0 else list(reversed(arcs[~i]))
        pts.extend(seg if not pts else seg[1:])
    return pts


def _polygons(geom: dict, arcs) -> list[list[list[tuple[float, float]]]]:
    if geom["type"] == "Polygon":
        return [[_ring(arcs, r) for r in geom["arcs"]]]
    if geom["type"] == "MultiPolygon":
        return [[_ring(arcs, r) for r in poly] for poly in geom["arcs"]]
    return []


class Frame:
    """投影した座標を、指定した経緯度の範囲が width の幅に収まる SVG 座標へ移す。"""

    def __init__(self, lon0: float, lat0: float, lon1: float, lat1: float, width: float):
        # 経線は赤道で最も外へ張り出すので、範囲に赤道が入るなら赤道の点も含めて枠を決める
        lats = (lat0, lat1, min(max(0.0, lat0), lat1))
        corners = [equal_earth(lo, la) for lo in (lon0, lon1, (lon0 + lon1) / 2) for la in lats]
        self.x0 = min(c[0] for c in corners)
        self.y0 = min(c[1] for c in corners)
        x1 = max(c[0] for c in corners)
        y1 = max(c[1] for c in corners)
        self.k = width / (x1 - self.x0)
        self.width = width
        self.height = (y1 - self.y0) * self.k

    def xy(self, lon: float, lat: float) -> tuple[float, float]:
        x, y = equal_earth(lon, lat)
        return (x - self.x0) * self.k, (y - self.y0) * self.k


# 本土だけを塗る国（経度・緯度の範囲）。フランスのワーキング・ホリデー査証は本土だけで有効
# （在日フランス大使館）なので、南米のフランス領ギアナなどの海外県は塗らない。
MAINLAND = {
    "250": (-6, 41, 10, 52),   # フランス
    "528": (2, 50, 8, 54),     # オランダ（カリブ海の島を除く）
}


def _unwrap(ring: list[tuple[float, float]]) -> list[tuple[float, float]]:
    """日付変更線をまたぐ輪（ロシア東端・フィジーなど）は、経度を片側にそろえて横一線の線が出ないようにする。"""
    if not any(abs(a[0] - b[0]) > 180 for a, b in zip(ring, ring[1:])):
        return ring
    east = sum(1 for lon, _ in ring if lon > 0) >= len(ring) / 2
    return [((lon + 360 if east and lon < 0 else lon - 360 if not east and lon > 0 else lon), lat) for lon, lat in ring]


def _path(polys, frame: Frame, tol: float, keep=None) -> str:
    """多角形を SVG の d 属性にする。tol ピクセルより近い点は間引く。画面外の輪は落とす。"""
    out = []
    for poly in polys:
        for ring in poly:
            ring = _unwrap(ring)
            if keep and not any(keep[0] <= lon <= keep[2] and keep[1] <= lat <= keep[3] for lon, lat in ring):
                continue
            pts = []
            for lon, lat in ring:
                x, y = frame.xy(lon, lat)
                if pts and abs(x - pts[-1][0]) < tol and abs(y - pts[-1][1]) < tol:
                    continue
                pts.append((x, y))
            if len(pts) < 3:
                continue
            xs = [p[0] for p in pts]
            ys = [p[1] for p in pts]
            if max(xs) < 0 or min(xs) > frame.width or max(ys) < 0 or min(ys) > frame.height:
                continue
            if max(xs) - min(xs) < tol * 2.5 and max(ys) - min(ys) < tol * 2.5:
                continue
            out.append(_compact(pts))
    return "".join(out)


def _compact(pts: list[tuple[float, float]]) -> str:
    """点の列を短い d 属性にする。0.5px 単位に丸め、2点目以降は直前からの差（l コマンド）で書く。
    同じ位置に丸まった点は落とす。地図の幅は 320〜960px なので、0.5px の丸めは目に見えない。"""
    q = [(round(x * 2) / 2, round(y * 2) / 2) for x, y in pts]
    fmt = lambda v: (f"{v:.1f}".rstrip("0").rstrip(".") or "0")
    x0, y0 = q[0]
    parts = [f"M{fmt(x0)} {fmt(y0)}l"]
    px, py = x0, y0
    steps = []
    for x, y in q[1:]:
        if (x, y) == (px, py):
            continue
        steps.append(f"{fmt(x - px)} {fmt(y - py)}")
        px, py = x, y
    if len(steps) < 2:
        return ""
    return parts[0] + " ".join(steps).replace(" -", "-") + "z"


def build_map(frame: Frame, tol: float) -> dict:
    """地図1枚分の部品を返す。base は対象外の国、countries はサイトの国（id → d）、japan は日本。"""
    arcs, geoms = _topology()
    by_iso = {iso: cid for cid, iso in ISO_NUM.items()}
    base, countries, japan = [], {}, ""
    for g in geoms:
        gid = str(g.get("id", ""))
        if gid == ANTARCTICA:
            continue
        d = _path(_polygons(g, arcs), frame, tol, MAINLAND.get(gid))
        if not d:
            continue
        if gid in by_iso:
            countries[by_iso[gid]] = d
        elif gid == JAPAN:
            japan = d
        else:
            base.append(d)
    markers = {}
    for cid, (lon, lat) in MARKERS.items():
        x, y = frame.xy(lon, lat)
        if 0 <= x <= frame.width and 0 <= y <= frame.height:
            markers[cid] = (round(x, 1), round(y, 1))
    return {
        "width": round(frame.width),
        "height": round(frame.height),
        "base": "".join(base),
        "countries": countries,
        "japan": japan,
        "markers": markers,
    }


@lru_cache(maxsize=1)
def world() -> dict:
    return build_map(Frame(-180, -58, 180, 84, 960), tol=1.6)


@lru_cache(maxsize=1)
def europe() -> dict:
    return build_map(Frame(-25, 34, 35, 71.5, 640), tol=1.4)


@lru_cache(maxsize=None)
def locator(cid: str) -> dict:
    """国のページの小さな位置図。その国の周りを切り出す。"""
    arcs, geoms = _topology()
    iso = ISO_NUM[cid]
    if cid in MARKERS:
        lon, lat = MARKERS[cid]
        lon0, lon1, lat0, lat1 = lon - 9, lon + 9, lat - 6, lat + 6
    else:
        g = next(g for g in geoms if str(g.get("id")) == iso)
        # 海外領土や遠い離島（フランス領ギアナ、スヴァールバルなど）で範囲が広がらないよう、
        # 面積の大きい順に本土の輪だけで範囲を決める（最大の輪の 1/8 以上の輪）。
        rings = [poly[0] for poly in _polygons(g, arcs)]
        size = lambda r: (max(p[0] for p in r) - min(p[0] for p in r)) * (max(p[1] for p in r) - min(p[1] for p in r))
        biggest = max(size(r) for r in rings)
        main = [r for r in rings if size(r) >= biggest / 8 and max(p[0] for p in r) - min(p[0] for p in r) < 180]
        lons = [p[0] for r in main for p in r]
        lats = [p[1] for r in main for p in r]
        lon0, lon1, lat0, lat1 = min(lons), max(lons), min(lats), max(lats)
        if lon1 - lon0 < (lat1 - lat0) * 0.8:  # 細長い国（チリなど）は左右を広げて形が分かるようにする
            mid, half = (lon0 + lon1) / 2, (lat1 - lat0) * 0.4
            lon0, lon1 = mid - half, mid + half
        padx = max((lon1 - lon0) * 0.35, 4)
        pady = max((lat1 - lat0) * 0.35, 3)
        lon0, lon1, lat0, lat1 = lon0 - padx, lon1 + padx, lat0 - pady, lat1 + pady
    frame = Frame(max(lon0, -180), max(lat0, -60), min(lon1, 180), min(lat1, 84), 320)
    m = build_map(frame, tol=0.6)
    return {**m, "focus": m["countries"].get(cid, ""), "marker": m["markers"].get(cid)}

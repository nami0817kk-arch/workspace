"""ガラパゴス諸島を自分で測る。
- 島: Terrain Tiles(z10)の標高 0m より上を陸として、面積・島の数・いちばん高い所
- 本土からの距離: Natural Earth 10m のエクアドルの形(いちばん大きい多角形が本土)から、いちばん近い島まで
- 本土との間の海の深さ: 本土の岸からいちばん近い島までの線の上の標高(z7)
- 西の端(フェルナンディナ)と東の端(サンクリストバル)の間の距離
出力: measure.json"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT))
from naze import worldmap  # noqa: E402
import cv2  # noqa: E402
import numpy as np  # noqa: E402
from shapely.geometry import LineString, MultiPolygon, Point, shape  # noqa: E402
from shapely.ops import nearest_points, transform  # noqa: E402

R = 6371008.8
BBOX = (-92.1, -1.6, -89.1, 0.8)
PPD = 360                                           # 1 度に 360 画素(約 300m)


def laea(lon0, lat0):
    l0, p0 = np.radians(lon0), np.radians(lat0)

    def f(x, y, z=None):
        lam, phi = np.radians(np.asarray(x)), np.radians(np.asarray(y))
        k = np.sqrt(2 / (1 + np.sin(p0) * np.sin(phi) + np.cos(p0) * np.cos(phi) * np.cos(lam - l0)))
        return R * k * np.cos(phi) * np.sin(lam - l0), R * k * (np.cos(p0) * np.sin(phi) - np.sin(p0) * np.cos(phi) * np.cos(lam - l0))
    return f


def km(a, b):
    """大円の距離(km)。"""
    (x1, y1), (x2, y2) = np.radians(a), np.radians(b)
    return 2 * R / 1000 * np.arcsin(np.sqrt(np.sin((y2 - y1) / 2) ** 2 + np.cos(y1) * np.cos(y2) * np.sin((x2 - x1) / 2) ** 2))


def main():
    out = {}
    e = worldmap.heights(BBOX, 10, PPD)
    land = (e > 0).astype(np.uint8)
    lo0, la0, lo1, la1 = BBOX
    h, w = e.shape
    lats = la1 - (np.arange(h) + 0.5) / PPD
    px_km2 = (111.32 / PPD) ** 2 * np.cos(np.radians(lats))[:, None]
    n, lab, st, _ = cv2.connectedComponentsWithStats(land, connectivity=8)
    isl = []
    for i in range(1, n):
        m = lab == i
        a = float((px_km2 * m).sum())
        if a < 1:
            continue
        yy, xx = np.unravel_index(np.argmax(np.where(m, e, -1e9)), e.shape)
        isl.append(dict(area=round(a, 1), top=round(float(e[yy, xx])), lon=round(lo0 + (xx + 0.5) / PPD, 3), lat=round(la1 - (yy + 0.5) / PPD, 3)))
    isl.sort(key=lambda d: -d["area"])
    out["islands_over_1km2"] = len(isl)
    out["islands_over_10km2"] = sum(d["area"] >= 10 for d in isl)
    out["land_km2"] = round(sum(d["area"] for d in isl))
    out["top"] = max(isl, key=lambda d: d["top"])
    out["islands"] = isl[:20]
    # 本土からの距離
    a0 = json.load(open(worldmap.NE / "ne_10m_admin_0_countries.geojson", encoding="utf-8"))
    ecu = shape(next(f for f in a0["features"] if f["properties"].get("ADM0_A3") == "ECU")["geometry"])
    polys = list(ecu.geoms) if isinstance(ecu, MultiPolygon) else [ecu]
    main_ = max(polys, key=lambda p: p.area)
    gal = MultiPolygon([p for p in polys if p.centroid.x < -88])
    tr = laea(-85, -1)
    pm, pg = nearest_points(transform(tr, main_), transform(tr, gal))
    dist = pm.distance(pg) / 1000
    # 投影から経緯度へは、近い点を元の形の上で探し直す
    a_ll = nearest_points(main_, gal)
    out["mainland_to_nearest_island_km"] = round(dist)
    out["mainland_pt"], out["island_pt"] = [round(v, 3) for v in a_ll[0].coords[0]], [round(v, 3) for v in a_ll[1].coords[0]]
    # 海の深さ(本土の岸 → 島)
    A, B = a_ll[0].coords[0], a_ll[1].coords[0]
    bb = (min(A[0], B[0]) - 0.5, min(A[1], B[1]) - 0.5, max(A[0], B[0]) + 0.5, max(A[1], B[1]) + 0.5)
    e7 = worldmap.heights(bb, 7, 40)
    ts = np.linspace(0, 1, 400)
    deps = []
    for t in ts:
        lon, lat = A[0] + (B[0] - A[0]) * t, A[1] + (B[1] - A[1]) * t
        xx, yy = int((lon - bb[0]) * 40), int((bb[3] - lat) * 40)
        deps.append(float(e7[min(max(yy, 0), e7.shape[0] - 1), min(max(xx, 0), e7.shape[1] - 1)]))
    out["sea_min_m"] = round(min(deps))
    out["sea_profile_every_10"] = [round(d) for d in deps[::10]]
    # 西と東の端
    fern = (-91.55, -0.37)
    sanc = (-89.43, -0.85)
    out["fernandina_to_sancristobal_km"] = round(km(fern, sanc))
    out["sancristobal_moved_km_2p35Ma_at_51km_per_Ma"] = round(2.35 * 51)
    # 日本の島との比べ
    out["note"] = "陸は標高0mより上(Terrain Tiles z10、1画素約300m)。島の名前は地図で読む"
    json.dump(out, open(Path(__file__).with_suffix(".json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print(json.dumps({k: v for k, v in out.items() if k not in ("islands", "sea_profile_every_10")}, ensure_ascii=False, indent=1))
    for d in isl[:15]:
        print(d)


if __name__ == "__main__":
    main()

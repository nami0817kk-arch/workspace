"""シベリア(ロシアのシベリア連邦管区＋極東連邦管区)の広さと、町がどこに集まっているかを Natural Earth で自分で測る。
- 広さ: 州(admin-1)の多角形を、正積の図法(ランベルト正積方位図法・中心 100E 60N)に移して面積を足す
- 町: populated places の pop_max(都市圏の人口の見積もり)を、州の内側の町について緯度ごとに足す
出力: measure.json"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT))
from naze import worldmap  # noqa: E402
import numpy as np  # noqa: E402
from shapely.geometry import Point, shape  # noqa: E402
from shapely.ops import transform, unary_union  # noqa: E402
import warnings  # noqa: E402
warnings.filterwarnings("ignore", category=DeprecationWarning)

NE = worldmap.NE
R = 6371008.8                                                 # 地球の半径(面積が同じになる球)


def laea(lon0, lat0):
    """ランベルト正積方位図法(球)。面積がそのまま測れる。"""
    l0, p0 = np.radians(lon0), np.radians(lat0)

    def f(x, y, z=None):
        lam, phi = np.radians(np.asarray(x)), np.radians(np.asarray(y))
        k = np.sqrt(2 / (1 + np.sin(p0) * np.sin(phi) + np.cos(p0) * np.cos(phi) * np.cos(lam - l0)))
        return R * k * np.cos(phi) * np.sin(lam - l0), R * k * (np.cos(p0) * np.sin(phi) - np.sin(p0) * np.cos(phi) * np.cos(lam - l0))
    return f


tr, trj = laea(100, 60), laea(138, 36)


def main():
    a1 = json.load(open(NE / "ne_10m_admin_1_states_provinces.geojson", encoding="utf-8"))
    sib = [f for f in a1["features"] if f["properties"].get("adm0_a3") == "RUS" and f["properties"].get("region") in ("Siberian", "Far Eastern")]
    geo = unary_union([shape(f["geometry"]) for f in sib])
    area = transform(tr, geo).area / 1e6
    a0 = json.load(open(NE / "ne_10m_admin_0_countries.geojson", encoding="utf-8"))
    jp = next(f for f in a0["features"] if f["properties"].get("ADM0_A3") == "JPN")
    ajp = transform(trj, shape(jp["geometry"])).area / 1e6
    print(f"州の数 {len(sib)}  シベリア＋極東 {area:,.0f} km2  日本 {ajp:,.0f} km2  → {area / ajp:.1f} 倍")
    # 緯度ごとの土地の広さ
    from shapely.geometry import box
    bands = [(40, 55), (55, 60), (60, 66.5), (66.5, 82)]
    land = {f"{a}-{b}": round(transform(tr, geo.intersection(box(-180, a, 180, b))).area / 1e6) for a, b in bands}
    # 町
    pp = json.load(open(NE / "ne_10m_populated_places_simple.geojson", encoding="utf-8"))
    towns = []
    for f in pp["features"]:
        p = f["properties"]
        if p.get("adm0_a3") != "RUS":
            continue
        pt = Point(p["longitude"], p["latitude"])
        if geo.contains(pt):
            towns.append((p["name"], p["latitude"], p["longitude"], p["pop_max"]))
    tot = sum(t[3] for t in towns)
    pop = {f"{a}-{b}": sum(t[3] for t in towns if a <= t[1] < b) for a, b in bands}
    print("町の数", len(towns), "町の人口の合計", f"{tot:,}")
    for k in land:
        print(f"  北緯{k}度: 土地 {land[k]:,} km2 ({land[k] / area:.0%}) / 町の人口 {pop[k]:,} ({pop[k] / tot:.0%})")
    big = sorted(towns, key=lambda t: -t[3])[:15]
    for t in big:
        print("  ", t)
    g = geo.simplify(0.15)                                    # 画面に塗る外形(粗くしてよい)
    polys = list(g.geoms) if hasattr(g, "geoms") else [g]
    rings = [[(round(x, 3), round(y, 3)) for x, y in q.exterior.coords] for q in polys if q.area > 0.5]
    (Path(__file__).parent / "measure.json").write_text(json.dumps(dict(area=area, japan=ajp, land=land, pop=pop, total=tot, rings=rings,
                                                                       towns=sorted(towns, key=lambda t: -t[3])), ensure_ascii=False), encoding="utf-8")


if __name__ == "__main__":
    main()

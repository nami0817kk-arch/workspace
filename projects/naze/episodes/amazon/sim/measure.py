"""アマゾン川の谷の幅を、標高データ(Terrain Tiles、ここは SRTM)で自分で測る。
マナウスからサンタレンのあいだを南北に何本か切り、いちばん低い所(川の水面)から 20m 以内の低い土地の幅を数える(南北に 3km ならして、森の木の凸凹を消す)。
雨季に水につかる氾濫原(バルゼア)の幅の目安。森の木の高さが SRTM に乗るので、幅は少なめに出る。
出力: profile.json(切った線ごとの、緯度と高さの列)"""
import json
import sys
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT))
from naze import worldmap  # noqa: E402

BOX = (-60.5, -4.5, -54.0, -0.8)
Z = 10
PPD = 256 * 2 ** Z / 360


def main():
    e = worldmap.heights(BOX, Z, PPD).astype(np.float32)
    km_y = 111.32 / PPD
    out = {}
    for lon in (-59.5, -58.5, -57.5, -56.5, -55.5):
        x = int((lon - BOX[0]) * PPD)
        col = e[:, max(0, x - 2):x + 3].mean(axis=1)
        k = max(1, int(3 / (111.32 / PPD)))
        col = np.convolve(col, np.ones(k) / k, mode="same")
        floor = float(np.percentile(col, 0.5))
        low = col < floor + 20
        # いちばん低い所を含む、ひと続きの低い帯
        i0 = int(np.argmin(col))
        a = i0
        while a > 0 and low[a - 1]:
            a -= 1
        b = i0
        while b < len(col) - 1 and low[b + 1]:
            b += 1
        w = (b - a + 1) * km_y
        print(f"西経{-lon}度: 水面 約{floor:.0f}m、低い帯の幅 {w:.1f}km(南緯{-(BOX[3] - a / PPD):.2f}〜{-(BOX[3] - b / PPD):.2f}度)")
        lat = [round(BOX[3] - i / PPD, 4) for i in range(0, len(col), 4)]
        out[str(lon)] = dict(floor=floor, width_km=w, lat=lat, h=[round(float(v), 1) for v in col[::4]])
    (Path(__file__).parent / "profile.json").write_text(json.dumps(out), encoding="utf-8")


if __name__ == "__main__":
    main()


def state():
    """アマゾナス州の外形と面積(Natural Earth の州。正積の図法は ../siberia/sim/measure.py の laea)。出力: amazonas.json"""
    sys.path.insert(0, str(ROOT / "episodes" / "siberia" / "sim"))
    import measure as M
    import shapely.ops as so
    from shapely.geometry import shape
    a1 = json.load(open(worldmap.NE / "ne_10m_admin_1_states_provinces.geojson", encoding="utf-8"))
    f = next(f for f in a1["features"] if f["properties"].get("adm0_a3") == "BRA" and f["properties"]["name"] == "Amazonas")
    g = shape(f["geometry"])
    area = so.transform(M.laea(-63, -4), g).area / 1e6
    s = g.simplify(0.05)
    polys = list(s.geoms) if hasattr(s, "geoms") else [s]
    rings = [[(round(x, 3), round(y, 3)) for x, y in q.exterior.coords] for q in polys if q.area > 0.05]
    (Path(__file__).parent / "amazonas.json").write_text(json.dumps(dict(area=area, rings=rings)), encoding="utf-8")
    print("アマゾナス州", round(area), "km2")


if __name__ == "__main__" and len(sys.argv) > 1 and sys.argv[1] == "state":
    state()

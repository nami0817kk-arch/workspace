"""屋久島と種子島の高さと坂を、国土地理院の標高タイル(naze.dem)で自分で測る。
- 島の面積(標高 0m より上)、いちばん高い所、1,000m より高い土地の広さ
- いちばん高い所から、いちばん近い海岸までのまっすぐな距離(坂のきつさ)
- 屋久島を南北に切った断面(画面の断面図用) → profile.json"""
import json
import sys
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT))
from naze import dem  # noqa: E402

ISL = {"屋久島": (130.36, 30.22, 130.69, 30.48), "種子島": (130.82, 30.32, 131.10, 30.86)}


def main():
    res = {}
    for name, bb in ISL.items():
        D = dem.load(*bb, z=13)
        h = np.nan_to_num(D.h, nan=0.0)
        land = h > 0.5
        px_km = D.mpp / 1000
        area = land.sum() * px_km ** 2
        iy, ix = np.unravel_index(np.argmax(h), h.shape)
        ys, xs = np.nonzero(~land)
        dmin = float(np.min(np.hypot(ys - iy, xs - ix))) * px_km
        hi = float(h.max())
        a1000 = (h > 1000).sum() * px_km ** 2
        res[name] = dict(area=round(area, 1), top=round(hi), coast_km=round(dmin, 1), over1000=round(a1000, 1))
        print(f"{name}: 面積 {area:.0f}km2 / いちばん高い所 {hi:.0f}m / そこから海岸まで {dmin:.1f}km / 1,000m より上 {a1000:.0f}km2 / 1km あたり {hi / dmin:.0f}m 上る")
        if name == "屋久島":
            col = h[:, ix]
            res["profile"] = dict(h=[round(float(v)) for v in col[::3]], km=round(len(col) * px_km, 1))
    (Path(__file__).parent / "measure.json").write_text(json.dumps(res, ensure_ascii=False), encoding="utf-8")


if __name__ == "__main__":
    main()

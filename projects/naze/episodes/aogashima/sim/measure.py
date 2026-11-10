"""青ヶ島の形を国土地理院の標高タイル(dem_png、z14。1画素 約8m)で測る。結果は facts.md へ。
python episodes/aogashima/sim/measure.py"""
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[3]))
from naze import dem  # noqa: E402

D = dem.load(139.745, 32.440, 139.782, 32.475, z=14)
h = D.h
land = np.isfinite(h) & (h > 0)
print("1画素", round(D.mpp, 2), "m  陸の面積", round(land.sum() * D.mpp ** 2 / 1e6, 2), "km2  最高", round(np.nanmax(h), 1), "m")
iy, ix = np.unravel_index(np.nanargmax(np.where(land, h, -1)), h.shape)
print("最高の地点 画素", ix, iy)
# 池之沢(カルデラの底)のまわり 1.2km 四方で、いちばん低い所
px, py = D.pixel(139.7679, 32.4529)
r = int(600 / D.mpp)
sub = h[int(py) - r:int(py) + r, int(px) - r:int(px) + r]
print("池之沢のまわり 最低", round(np.nanmin(sub), 1), "m")
for name, ll in [("池之沢", (139.7679, 32.4529)), ("村役場", (139.76333, 32.46694)), ("三宝港", (139.75898, 32.44652))]:
    print(name, round(D.height_at(*ll), 1), "m")
# 島を北北西→南南東に切ると、外輪山・カルデラの底・丸山が並ぶ
a, b = (139.758, 32.474), (139.773, 32.441)
n = 400
lo, la = np.linspace(a[0], b[0], n), np.linspace(a[1], b[1], n)
prof = np.array([D.height_at(x, y, r=1) for x, y in zip(lo, la)])
step = np.hypot((b[0] - a[0]) * 94000, (b[1] - a[1]) * 111000) / (n - 1)
print("断面の長さ", round(step * (n - 1)), "m")
print(" ".join(f"{i * step / 1000:.1f}km:{0 if np.isnan(v) else int(v)}" for i, v in list(enumerate(prof))[::20]))
# 縁の高さより低い、内側の窪みの広さ
from scipy import ndimage  # noqa: E402
for lev in (200, 250, 300):
    low = land & (h < lev)
    lab, _ = ndimage.label(low)
    k = lab[int(py), int(px)]
    if k:
        area = (lab == k).sum() * D.mpp ** 2 / 1e6
        ys, xs = np.where(lab == k)
        print(f"標高{lev}m より低い窪み 広さ {area:.2f}km2 東西 {(xs.max() - xs.min()) * D.mpp:.0f}m 南北 {(ys.max() - ys.min()) * D.mpp:.0f}m")

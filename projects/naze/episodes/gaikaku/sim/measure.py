"""首都圏外郭放水路まわりを自分で測る(国土地理院の標高タイル z12)。出力: measure.json
- 立坑 5 つの位置(OpenStreetMap の点)の標高、立坑どうしの直線距離
- 中川・綾瀬川の流域のおおよその箱(139.65〜139.95, 35.80〜36.15)で、標高 5m 以下の割合
- 春日部から東京湾(荒川河口)まで、標高がどれだけ下がるか"""
import json
import math
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT))
import numpy as np  # noqa: E402
from naze import dem  # noqa: E402

SH = {1: (139.8100016, 35.9954424), 2: (139.7971368, 35.9902974), 3: (139.7760807, 35.9919309), 4: (139.7606763, 35.9934593), 5: (139.7471646, 35.9929905)}


def km(a, b):
    dx = (a[0] - b[0]) * 111.32 * math.cos(math.radians((a[1] + b[1]) / 2))
    dy = (a[1] - b[1]) * 110.57
    return math.hypot(dx, dy)


d = dem.load(139.55, 35.55, 139.98, 36.20, z=12)
out = {"shafts": {}, "dist": {}}
for k, p in SH.items():
    out["shafts"][k] = round(d.height_at(*p, r=1), 1)
out["dist"]["1-5"] = round(km(SH[1], SH[5]), 2)
out["dist"]["path"] = round(sum(km(SH[i], SH[i + 1]) for i in range(1, 5)), 2)
PL = {"春日部市役所": (139.7548, 35.9740), "杉戸町役場": (139.7367, 36.0258), "幸手市役所": (139.7258, 36.0781), "越谷": (139.7907, 35.8911),
      "荒川河口": (139.8470, 35.6560), "野田・江戸川": (139.8330, 35.9800), "中川(吉川)": (139.8420, 35.8890), "東京駅": (139.7671, 35.6812)}
out["pts"] = {k: round(d.height_at(*v, r=1), 1) for k, v in PL.items()}
# 箱の中の標高の分布(陸だけ)
x0, y0 = d.pixel(139.65, 36.15)
x1, y1 = d.pixel(139.95, 35.80)
a = d.h[int(y0):int(y1), int(x0):int(x1)]
v = a[np.isfinite(a)]
out["box"] = {"n": int(v.size), "le5": round(float((v <= 5).mean()), 3), "le10": round(float((v <= 10).mean()), 3), "median": round(float(np.median(v)), 1)}
out["slope"] = {"kasukabe_to_bay_km": round(km(PL["春日部市役所"], PL["荒川河口"]), 1)}
json.dump(out, open(Path(__file__).parent / "measure.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
print("ok")

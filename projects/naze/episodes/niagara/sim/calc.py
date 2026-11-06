"""ナイアガラの回の自分で出す数字。標高は Terrain Tiles(naze.worldmap)、川の道すじは地図から読んだ点。
python episodes/niagara/sim/calc.py > episodes/niagara/sim/calc.txt"""
import math, sys
from pathlib import Path
import numpy as np
sys.path.insert(0, str(Path(__file__).resolve().parents[3]))
from naze import worldmap as wm

BB = (-79.20, 42.80, -78.80, 43.30)
E = wm.heights(BB, 13, 256 * 2 ** 13 / 360)
PPD = 256 * 2 ** 13 / 360

def h(lat, lon, r=3, f=np.min):
    x, y = int((lon - BB[0]) * PPD), int((BB[3] - lat) * PPD)
    return float(f(E[y - r:y + r + 1, x - r:x + r + 1]))

def km(a, b):
    R = 6371.0
    p1, p2 = math.radians(a[0]), math.radians(b[0])
    dl = math.radians(b[1] - a[1])
    return R * math.acos(min(1, math.sin(p1) * math.sin(p2) + math.cos(p1) * math.cos(p2) * math.cos(dl)))

# 川の道すじ: OpenStreetMap の川の線(river.json、西の流れ＝チッパワ水路)を上流からつないだもの
import json
PTS = [tuple(p) for p in json.loads((Path(__file__).parent / "river.json").read_text(encoding="utf-8"))["pts"]]
C = [0.0]
for a_, b_ in zip(PTS, PTS[1:]):
    C.append(C[-1] + km(a_, b_))
def along(ll):
    j = min(range(len(PTS)), key=lambda k: km(PTS[k], ll))
    return C[j]
NAMED = [("馬蹄滝の縁", (43.0775, -79.0755)), ("レインボー橋", (43.0900, -79.0680)), ("渦巻き", (43.119, -79.069)),
         ("クイーンストン橋(崖の口)", (43.1532, -79.0447))]
print("== 川の道すじ(OpenStreetMap の線、上流から)")
print(f"川の長さ {C[-1]:.1f} km")
for name, ll in NAMED:
    print(f"エリー湖の出口から {along(ll):5.1f} km  {name}")
falls = along(NAMED[0][1])
gorge = along(NAMED[3][1]) - falls
print(f"エリー湖から滝まで {falls:.1f} km、滝から崖の口まで(峡谷) {gorge:.1f} km")
# 崖の高さ: 峡谷の縁と川面
for name, la, lo in [("滝の上の台地", 43.075, -79.085), ("滝つぼの下の川面", 43.085, -79.070), ("クイーンストンの崖の上", 43.160, -79.060),
                     ("崖の下の平地(ルイストン)", 43.170, -79.035)]:
    print(f"{name}: 低い所 {h(la, lo):.0f} m / 高い所 {h(la, lo, f=np.max):.0f} m")

print("\n== 後退の速さから")
for rate in (1.0, 1.5, 0.3, 0.1):
    print(f"年 {rate} m で 滝からエリー湖まで {falls:.1f} km → {falls*1000/rate:,.0f} 年")
for yrs in (12500,):
    print(f"峡谷 {gorge:.1f} km を {yrs} 年 → 平均 年 {gorge*1000/yrs:.2f} m")

print("\n== 流量")
for cfs in (100000, 50000, 202000):
    print(f"{cfs:,} cfs = {cfs*0.0283168:,.0f} m3/s")
v_bath = 0.2  # 浴槽 200L
print(f"2,832 m3/s は 1 秒に浴槽(200L) {2832/0.2:,.0f} 杯、25m プール(25x10x1.2=300m3) {2832/300:.1f} 杯")

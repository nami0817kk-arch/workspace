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

# ---- 物理で出す(2026-11-06 ユーザー「資料ではなく、物理で計算してよ」) -----------------------
RHO, G = 1000.0, 9.81
print("\n== 1. 滝が崖を叩く力(落ちる水の仕事率 P = ρ g Q H、H = 垂直の落差 51m)")
H = 51.0
for name, q in [("自然の流れ(人が抜く前)", 5760), ("いまの昼(条約の最低)", 2832), ("いまの夜と冬", 1416)]:
    print(f"{name}: Q {q:,} m3/s → {RHO*G*q*H/1e9:.2f} GW(100万kW の発電所 {RHO*G*q*H/1e9:.1f} 基ぶん)")

print("\n== 2. 後退の速さ(川が岩を削る速さは、縁の長さ 1m あたりに当たる水の力に比べる、という川の浸食の式)")
r0, q0, w0 = 1.28, 5760 * 0.9, 420.0      # 1842〜1906年: 年1.28m、馬蹄滝に自然の流れの9割、縁 420m(1842年)
q_now, w_now = 1593.0, 762.0             # いま: 馬蹄滝の年平均 1,593 m3/s、縁 762m(2000年)
k = r0 / (q0 / w0)
print(f"昔: 縁 1m あたり {q0/w0:.1f} m3/s → 年 {r0} m(この比で式の係数を決める)")
r_now = k * q_now / w_now
r_nat = k * q0 / w_now
r_lip = k * q_now / w0
print(f"いま: 縁 1m あたり {q_now/w_now:.2f} m3/s → 年 {r_now:.2f} m(昔の {r_now/r0*100:.0f}%)")
print(f"  水を抜かずに縁だけ伸びた場合 年 {r_nat:.2f} m / 縁はそのままで水だけ抜いた場合 年 {r_lip:.2f} m")
print(f"  峡谷 11km を 1万2,500年 → 平均 年 {11000/12500:.2f} m(昔の式の値と同じ大きさ)")

print("\n== 3. エリー湖に届くまで(川に沿って 35.1km、OpenStreetMap の線で測った)")
D = falls * 1000
for name, r in [("いまの水で", r_now), ("人が水を抜かなかったら", r_nat), ("1842〜1906年の速さのままなら", r0)]:
    print(f"{name}: 年 {r:.2f} m → {D/r:,.0f} 年")

print("\n== 4. エリー湖の高さを決めるもの(湖の出口の岩をせきと見る。広いせきの式 Q = b √g (2/3 h)^1.5)")
b = 600.0                                # 出口のいちばん狭い所の水面の幅(Terrain Tiles で測った 595〜637m)
for Q in (5760, 2 * 5760):
    hh = 1.5 * (Q / (b * math.sqrt(G))) ** (2 / 3)
    print(f"流れ {Q:,} m3/s、幅 {b:.0f}m → 湖の水面は出口の岩より {hh:.1f} m 上")
print("滝はうしろへ削るだけで、出口の岩を下へは削らない → 届いても、湖の高さは出口の岩の高さのまま")

print("\n== 5. もし出口の岩が一気に D m 削れたら(思考の実験。湖の面積 25,700 km2、入る水 5,760 m3/s のまま)")
A = 25700e6
for Dcut, bw in [(10, 600), (10, 762), (64, 762)]:
    zc = -Dcut                            # 出口の岩の新しい高さ(いまの岩を 0)
    z = 1.5 * (5760 / (b * math.sqrt(G))) ** (2 / 3)   # いまの水面
    t, dt = 0.0, 3600.0
    marks = {}
    z0 = z
    while True:
        h_ = max(0.0, z - zc)
        qout = bw * math.sqrt(G) * (2 / 3 * h_) ** 1.5
        dz = (5760 - qout) / A * dt
        z += dz; t += dt
        for m in (1, 5):
            if z0 - z >= m and m not in marks: marks[m] = t / 86400
        if abs(dz) < 1e-7 or t > 86400 * 365 * 30: break
    peak = bw * math.sqrt(G) * (2 / 3 * (z0 - zc)) ** 1.5
    print(f"{Dcut}m 削れ・幅 {bw}m: 出始めの流れ {peak:,.0f} m3/s(いまの {peak/5760:.0f} 倍)、"
          f"1m 下がるのに {marks.get(1, float('nan')):.0f} 日・5m に {marks.get(5, float('nan')):.0f} 日、"
          f"落ち着くのは {t/86400/365:.1f} 年後、水面は {z0 - z:.1f} m 下がる")

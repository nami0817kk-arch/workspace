"""宇宙はマイナス270℃なのに、なぜ冷えないのか: 台本の数字を全部ここで計算する。python episodes/space-heat/sim/calc.py > calc.txt
測った値・定数の出どころは ../research.md。ここで足した定数:
  太陽の光の強さ(地球のあたり) 1361 W/m²   Kopp & Lean 2011, GRL 38, L01706 "1360.8 ± 0.5 W m-2"
  地球が宇宙へ出す赤外線(平均) 240 W/m²    NASA CERES(地球のエネルギー収支、宇宙へ出る長波 約240)
  氷が蒸発(昇華)する熱 2.83 MJ/kg      0℃の氷の昇華熱 2834 kJ/kg(Feistel & Wagner 2007)
  人の皮膚の放射率 0.98                   Steketee 1973(皮膚 0.98)
  人の体の比熱 3.47 kJ/(kg·K)、体重 70kg、体の表面 1.8 m²(LCVG が覆う 1.776 m²、research.md)
  体のうち外へ向いて光を出す面の割合 0.73(立った人、Fanger の有効放射面積の比)"""
import math

SIG = 5.670374419e-8
S = 1361.0
OLR = 240.0
K0 = 273.15


def C(Tk):
    return Tk - K0


print("== 1. 空気の濃さ")
rho0, rho_lo, rho_hi = 1.225, 2.8e-13, 1.4e-11
print(f"  400km の空気 {rho_lo:.1e}〜{rho_hi:.1e} kg/m³ → 地上の {rho0 / rho_hi:.1e}〜{rho0 / rho_lo:.1e} 分の1(約1兆分の1)")
room = 5 * 4 * 2.5
print(f"  6畳ほどの部屋(50m³)の空気: 地上 {room * rho0:.0f} kg ／ 400km {room * 1e-12 * 1e6:.2f} mg(1e-12 kg/m³ で)")

print("== 2. 日なたの板の温度(放射だけで釣り合う)")
for name, a, e, sides in [("黒い板・片面だけ光を出す", 1.0, 1.0, 1), ("黒い板・両面から出す", 1.0, 1.0, 2), ("白い塗料(Z-93)・両面", 0.14, 0.9, 2),
                          ("白い塗料・片面", 0.14, 0.9, 1), ("黒い球", 1.0, 1.0, 4)]:
    T = (a * S / (sides * e * SIG)) ** 0.25
    print(f"  {name}: {T:.0f}K = {C(T):+.0f}℃")
print("  (JAXA の +120℃ と、黒い板・片面の計算が合う)")

print("== 3. 裸の人が真空の日陰で出す熱")
A, eps, frac, Tskin, m, cp, meta = 1.8, 0.98, 0.73, 273.15 + 33, 70, 3470, 100
P = eps * SIG * A * frac * (Tskin ** 4 - 2.725 ** 4)
print(f"  皮膚 33℃ で出す赤外線 {P:.0f} W(体が作る熱 約{meta} W)")
net = P - meta
rate = net / (m * cp) * 3600
print(f"  差し引き {net:.0f} W 失う → 体全体で 1時間に {rate:.1f}℃ 下がる")
print(f"  37℃→27℃(10℃下がる)まで {10 / rate:.1f} 時間")
ice = 3.34e5
print(f"  比べ: 70kg の水を 0℃ で凍らせきるには {m * ice / net / 3600:.0f} 時間(凍るまで出す熱 {m * ice / 1e6:.0f} MJ)")

print("== 4. ISS の熱")
Q = 70e3
print(f"  捨てる熱 {Q / 1e3:.0f} kW = 人 {Q / meta:.0f} 人ぶん(1人 {meta}W)、家庭用ストーブ(1.2kW)の {Q / 1200:.0f} 台ぶん")
T = 273.15 + 2.8
H = (6371 + 400) / 6371
F = (math.atan(1 / math.sqrt(H * H - 1)) - math.sqrt(H * H - 1) / H / H) / math.pi
out = 0.9 * SIG * T ** 4
inn = 0.9 * F * OLR
print(f"  放熱板 2.8℃・放射率0.9 の 1m² が出す {out:.0f} W／地球の赤外線を受ける {inn:.0f} W(地球が見える割合 {F:.2f})→ 差 {out - inn:.0f} W")
need1 = Q / (out - inn)
print(f"  70kW を捨てるのに要る面 {need1:.0f} m²(片面)／{need1 / 2:.0f} m²(両面)")
panel = 23.3 * 3.4
print(f"  実物 1基 {panel:.0f} m² × 6基 = {6 * panel:.0f} m²(片面)→ 片面だけで計算の {6 * panel / need1:.1f} 倍")
print(f"  テニスコート(23.77×10.97={23.77 * 10.97:.0f} m²)で {6 * panel / (23.77 * 10.97):.1f} 面ぶん")
sun_in = 0.14 * S
print(f"  白い板が日なたで受ける太陽 {sun_in:.0f} W/m²、黒なら {S:.0f} W/m²(白は 86% はね返す)")
T_b = ((S + 0.9 * F * OLR) / (2 * SIG)) ** 0.25
print(f"  黒い放熱板を日なたに置くと(熱を運ばないとき): {C(T_b):+.0f}℃ → 2.8℃ の水より熱く、熱を捨てられない")

print("== 5. 宇宙服")
L = 2.834e6
for W_ in (100, 191, 300):
    print(f"  {W_} W を 8時間 = {W_ * 8 * 3600 / 1e6:.1f} MJ → 氷 {W_ * 8 * 3600 / L:.2f} kg を蒸発させる")
print(f"  捨てる水 3.6kg × 昇華の熱 = {3.6 * L / 1e6:.1f} MJ → 8時間ならして {3.6 * L / (8 * 3600):.0f} W")
Asuit = 2.0
Tout = 273.15 - 0
print(f"  服の外の面で放射して捨てるなら(白い服 2m²・ε0.9・外側 10℃): {0.9 * SIG * 2.0 * (283.15 ** 4):.0f} W ─ ただし日なたの太陽 0.14×1361×1m² = {0.14 * S:.0f} W が入る")
print(f"  水 3.6kg は 500mLペットボトル {3.6 / 0.5:.1f} 本")

print("== 6. 1日の日の出")
print(f"  90分で1周 → 1日 {24 * 60 / 90:.0f} 周、日なた60分・日陰30分(JAXA)")
print(f"  アポロの回転 0.3°/秒 → 1時間 {0.3 * 3600 / 360:.0f} 回転")

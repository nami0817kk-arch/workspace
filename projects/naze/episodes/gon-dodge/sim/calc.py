"""ゴンのドッジボール回 下調べの計算(2026-10-31)。再実行で research.md の数字が全部出る。
実行: python episodes/gon-dodge/sim/calc.py
置いた値は research.md の表と同じ。仮=仮置き。
"""
import math

G = 9.81
KMH = 3.6
M_BALL = 0.33          # モルテン D3C5000-L(全日本ドッジボール選手権全国大会試合球、軽量3号・検定球) 約330g・直径約21cm
D_BALL = 0.21
A_BALL = math.pi * (D_BALL / 2) ** 2
RHO = 1.204            # 空気 20℃
C_SOUND = 340.0
M_GON = 49.0           # 公式ガイド(ハンターズ・ガイド)の値。ファンwiki経由、本は未読


def kmh(v):
    return v * KMH


def line(name, v):
    return f"{name}: {v:8.1f} m/s = {kmh(v):8.0f} km/h = マッハ {v / C_SOUND:4.2f}"


print("=" * 70)
print("2章 普通に投げる: 球の重さと速さ(Fleisig ほか 2017 の重い球の実測で式を合わせる)")
# (m_e + m) v^2 = K。4oz 35.4m/s と 7oz 31.9m/s から m_e と K を決める
m4, v4, m7, v7 = 4 * 0.02835, 35.4, 7 * 0.02835, 31.9
m_e = (m7 * v7 ** 2 - m4 * v4 ** 2) / (v4 ** 2 - v7 ** 2)
K = (m_e + m4) * v4 ** 2
print(f"腕の有効質量 m_e = {m_e:.3f} kg、K = {K:.1f}")
for oz, vm in [(5, 34.2), (6, 33.1)]:
    m = oz * 0.02835
    print(f"  確かめ {oz}oz: 式 {math.sqrt(K / (m_e + m)):.1f} m/s / 実測 {vm}")
# 直線(力-速度)の置き方も並べる
slope = (v4 - v7) / (m7 - m4)


def ratio_energy(m_from, m_to):
    return math.sqrt((m_e + m_from) / (m_e + m_to))


def ratio_linear(m_from, m_to, v_from_ref=v4, m_ref=m4):
    vf = v_from_ref - slope * (m_from - m_ref)
    vt = v_from_ref - slope * (m_to - m_ref)
    return vt / vf


m_base = 0.145
print(f"  高校・大学の投手(実測 5oz 34.2m/s)がドッジボールを投げると: "
      f"{kmh(34.2 * ratio_energy(m_base, M_BALL)):.0f}〜{kmh(34.2 * ratio_linear(m_base, M_BALL)):.0f} km/h(エネルギーの式/直線の式)")
print(f"  ハンドボール経験者 0.409kg 21.5m/s(van den Tillaar & Ettema 2004) → 330g: "
      f"{kmh(21.5 * ratio_energy(0.409, M_BALL)):.0f} km/h")

print("=" * 70)
print("4章 人間の限界: いろいろな最速球をドッジボールに置き換える")
rows = [
    ("野球 最速 Chapman 105.8mph(MLB)", 105.8 * 0.44704, 0.145),
    ("ハンドボール EHF EURO 2026 最速 134.1km/h", 134.1 / KMH, 0.45),
    ("ハンドボール EHF EURO 2024 最速 129.46km/h", 129.46 / KMH, 0.45),
]
for name, v, m in rows:
    print(f"  {name}: {kmh(v):.0f} km/h({m*1000:.0f}g) → 330g: "
          f"{kmh(v * ratio_energy(m, M_BALL)):.0f} km/h(エネルギー) / {kmh(v * ratio_linear(m, M_BALL)):.0f} km/h(直線)")
# バレーのスパイク: 手 20.43m/s → ボール 31m/s(Guo & Li)。手の有効質量を逆算して 330g に
vh, vb, mv = 20.43, 31.0, 0.27
for e in (0.5, 0.65, 0.8):
    # vb = (1+e) M vh /(M+mv) → M
    x = vb / ((1 + e) * vh)
    if x < 1:
        Mh = x * mv / (1 - x)
        v330 = (1 + e) * Mh * vh / (Mh + M_BALL)
        print(f"  バレー最速スパイク 31m/s(270g、手 20.43m/s) e={e}: 手の有効質量 {Mh:.2f}kg → 330g なら {kmh(v330):.0f} km/h")
    else:
        print(f"  バレー e={e}: 成り立たない")

print("=" * 70)
print("3章 拳で打つ: v = (1+e) M V/(M+m)。MuJoCo は punch_mj.py(式と一致)")
for V, lab in [(9.14, "五輪ボクサーの平均"), (11.2, "平均+1SD"), (13.3, "平均+2SD")]:
    for M in (2.9, 6.9, 1e9):
        for e in (0.5, 0.8):
            v = (1 + e) * M * V / (M + M_BALL)
            print(f"  拳 {V:5.2f}m/s({lab}) M={M if M < 1e8 else '∞':>5} e={e}: {kmh(v):5.0f} km/h")
print("  → どれほど体重を乗せても(M→∞)、ボールは拳の (1+e) 倍 = 1.5〜1.8 倍まで")

print("=" * 70)
print("1章 ゴンの球の見積り")
print("-- 道すじA: レイザーの球でゴン(49kg)が場外へ飛ばされた(16巻163話)。")
print("   ゴンの1球目は『レイザーの球と同じくらい』(17巻165話の説明、ファンwikiの要約)")
print("   ゴンが受ける速さ U = (1+e) m v/(M+m) → v = U (M+m)/((1+e) m)")
for U, e, lab in [(3.0, 1.0, "下限"), (4.85, 0.5, "中央"), (7.0, 0.0, "上限")]:
    v = U * (M_GON + M_BALL) / ((1 + e) * M_BALL)
    print(f"   {lab}: U={U} m/s e={e}: {line('レイザーの球≒ゴンの1球目', v)}")
print("   (U: 2m を摩擦0.6で滑る速さ = √(2·0.6·9.81·2) = %.2f m/s)" % math.sqrt(2 * 0.6 * G * 2))

print("-- 道すじB: 最後の球(3球目)は『捕れるが、捕れば場外へ押し出される』とレイザーが読む(17巻167〜168話)")
print("   床の摩擦で止まれる限界: v ≥ (M_R+m)/m · √(2 μ g d)")
resB = {}
for MR, mu, d, lab in [(100, 0.5, 0.5, "下限"), (120, 0.6, 1.5, "中央"), (150, 0.8, 3.0, "上限")]:
    v = (MR + M_BALL) / M_BALL * math.sqrt(2 * mu * G * d)
    resB[lab] = v
    print(f"   {lab}: レイザー {MR}kg μ={mu} 外まで {d}m: {line('最後の球', v)}")

print("-- 道すじC: 念を込めた球は、ボポボの顔を砕いた念弾と同じ威力(16巻161話の台詞、ファンwikiの要約)")
for E, lab in [(1767, "5.56mm NATO 弾 約1.77kJ"), (3500, "7.62×51mm 弾 約3.5kJ")]:
    v = math.sqrt(2 * E / M_BALL)
    print(f"   頭を吹き飛ばす小銃弾のエネルギー {lab} を 330g の球に: {line('普通の球の下限', v)}")

print("-- 空気で落ちる分: 超音速の球の抵抗係数 Cd≈0.9(仮)、亜音速 Cd≈0.47(仮)")
for Cd in (0.47, 0.9):
    k = 0.5 * RHO * Cd * A_BALL / M_BALL
    for L in (5, 10, 15):
        print(f"   Cd={Cd}: {L}m 飛ぶと速さは {math.exp(-k*L)*100:.0f}% に")
print("-- 球の正面の空気の温度(よどみ点、15℃から): T0 = T(1+0.2 M^2)")
for lab, v in resB.items():
    Mach = v / C_SOUND
    T0 = 288.15 * (1 + 0.2 * Mach ** 2)
    print(f"   {lab} マッハ{Mach:.1f}: {T0 - 273.15:.0f} ℃")

print("=" * 70)
print("6章 何倍か(人間の限界 = ドッジボールに置き換えた最速 約150km/h、投げの最速は野球 170.3km/h)")
human = 150 / KMH
for lab, v in resB.items():
    print(f"   {lab}: {kmh(v):.0f} km/h → 人間の限界(150km/h)の {v / human:.0f} 倍 / "
          f"野球の最速(170km/h)の {v / (170.3 / KMH):.0f} 倍 / ボクサーの拳で打った球(50km/h)の {v / (50 / KMH):.0f} 倍")
v_need_fist = {lab: v / 1.8 for lab, v in resB.items()}
for lab, vf in v_need_fist.items():
    print(f"   {lab}: 拳で打ってこの速さを出すには、拳が {vf:.0f} m/s = {kmh(vf):.0f} km/h(ボクサーの平均 9.14m/s の {vf / 9.14:.0f} 倍)")

print("=" * 70)
print("5章 受け止める力: 止まる距離 s で止めるときの平均の力 F = (1/2) m v^2 / s、接触の時間 t = 2s/v")
cases = [("人間の限界 150km/h", human), ("ゴン 下限", resB["下限"]), ("ゴン 中央", resB["中央"]), ("ゴン 上限", resB["上限"])]
for lab, v in cases:
    E = 0.5 * M_BALL * v * v
    for s in (0.3, 0.1):
        F = E / s
        print(f"   {lab} {kmh(v):6.0f}km/h: 運動エネルギー {E/1000:8.2f} kJ、{s*100:.0f}cm で止めると {F/1000:9.1f} kN"
              f"(= {F/G/1000:7.2f} t の重さ)、接触 {2*s/v*1000:.2f} ms")
print("   比べる骨: 手首の上の橈骨が折れる力 1.6〜3.4 kN(献体の実験、Frykman 1967 / Myers / Spadaro / Burkhart 2012)")
print("   比べる拳: 五輪ボクサーのパンチ 3,427 N(Walilko 2005)")
F_h = 0.5 * M_BALL * human ** 2 / 0.3
for lab, v in cases[1:]:
    F = 0.5 * M_BALL * v * v / 0.3
    print(f"   {lab}: 30cm で止めても 橈骨の折れる力(2.3kN)の {F/2300:.0f} 倍、人間の限界の球の {F/F_h:.0f} 倍")

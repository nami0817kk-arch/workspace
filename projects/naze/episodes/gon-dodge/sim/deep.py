"""ゴンのドッジボール回 6版の掘り下げ計算(2026-11-01)。結果は deep.txt。
実行: python episodes/gon-dodge/sim/deep.py
置いた値(仮)は research.md の「9. 掘り下げ」の表と同じ。
"""
import math

G = 9.81
KMH = 3.6
C_SOUND = 340.0            # 15℃ 付近
RHO = 1.225                # 15℃・1気圧
P_ATM = 101325.0
GAMMA = 1.4
M_BALL, D_BALL = 0.33, 0.21
A_BALL = math.pi * (D_BALL / 2) ** 2
M_GON = 49.0
CASES = {  # 選手の体重, 床の摩擦, 場の外までの距離
    "控えめ": (100.0, 0.5, 0.5),
    "真ん中": (120.0, 0.6, 1.5),
    "大きめ": (150.0, 0.8, 3.0),
}
FLIGHT = 10.0              # 仮: 打った所から相手まで 10m
CD_SUP = 0.92              # 仮: 超音速の球の抗力係数(文献の目安 0.9〜1.0、Mach 1.6〜4.7 で変化は1割程度)
E_MAX = 0.8                # 拳と球のはね返り(上限と置く)
M_FIST = 2.9               # 五輪ボクサーの有効質量の平均(Walilko 2005)
V_BOXER = 9.14
ARM_STROKE = 0.5           # 仮: 拳が加速する道のり 0.5m
P_HUMAN = 6000.0           # 人の最大の瞬間の仕事率の目安(重量挙げのスーパーヘビー級 約6,000W)
VB_PRESS = (0.30 * 98066.5, 0.325 * 98066.5)  # バレーボールの内圧(FIVB 規則 0.30〜0.325kg/cm²、ゲージ圧)
CONTACT_FIST = 0.001       # 仮: 拳と球の接触 1ms


def kmh(v):
    return v * KMH


def cd(mach):
    """球の抗力係数の目安(仮)。亜音速0.47→音速付近で上がり→超音速 0.92 で一定。"""
    if mach < 0.6:
        return 0.47
    if mach < 1.0:
        return 0.47 + (0.8 - 0.47) * (mach - 0.6) / 0.4
    if mach < 1.5:
        return 0.8 + (1.0 - 0.8) * (mach - 1.0) / 0.5
    if mach < 2.0:
        return 1.0 - (1.0 - CD_SUP) * (mach - 1.5) / 0.5
    return CD_SUP


def launch_speed(v_arrive, L=FLIGHT, dx=1e-3):
    """L 先で v_arrive になるための打った瞬間の速さ(後ろ向きに積分。重力は入れない)"""
    v = v_arrive
    x = 0.0
    while x < L:
        k = 0.5 * RHO * cd(v / C_SOUND) * A_BALL / M_BALL
        v += k * v * dx  # 進む向きには dv/dx = -k v。相手の所から打った所へ戻すので +k v dx
        x += dx
    return v


def pitot(mach):
    """超音速の球の正面(衝撃波の後ろのよどみ点)の圧力 / 周りの圧力(レイリーのピトー管の式)"""
    if mach <= 1:
        return (1 + (GAMMA - 1) / 2 * mach ** 2) ** (GAMMA / (GAMMA - 1))
    a = ((GAMMA + 1) * mach ** 2 / 2) ** (GAMMA / (GAMMA - 1))
    b = ((2 * GAMMA * mach ** 2 - (GAMMA - 1)) / (GAMMA + 1)) ** (1 / (GAMMA - 1))
    return a / b


print("=" * 70)
print("1 式を1段ずつ(床で止まれる限界)")
for lab, (M, mu, d) in CASES.items():
    F = mu * (M + M_BALL) * G
    a = mu * G
    V = math.sqrt(2 * a * d)
    v = (M + M_BALL) / M_BALL * V
    print(f"  {lab}: 踏んばれる力の上限 μ(M+m)g = {F:.0f} N({F/G:.0f}kgの重さ)、減速 {a:.2f} m/s²、"
          f"場の外まで{d}mで止まれる速さ V={V:.2f} m/s({kmh(V):.1f}km/h)、"
          f"球 v=(M+m)V/m = {v:.0f} m/s = {kmh(v):.0f} km/h(重さの比 {(M+M_BALL)/M_BALL:.0f}倍)")

print("=" * 70)
print(f"2 空気の抵抗(打った所から相手まで {FLIGHT:.0f}m と置く。超音速の抗力係数 {CD_SUP})")
res = {}
for lab, (M, mu, d) in CASES.items():
    v_arr = (M + M_BALL) / M_BALL * math.sqrt(2 * mu * G * d)
    v0 = launch_speed(v_arr)
    res[lab] = (v_arr, v0)
    drag_force = 0.5 * RHO * CD_SUP * A_BALL * v0 ** 2
    print(f"  {lab}: 相手の所で {kmh(v_arr):.0f} km/h → 打った瞬間 {kmh(v0):.0f} km/h(マッハ{v0/C_SOUND:.1f})、"
          f"打った瞬間の空気の抵抗 {drag_force/1000:.1f} kN = 球の重さの {drag_force/(M_BALL*G):.0f} 倍")
for cdx in (0.9, 1.0):
    CD_SUP_SAVE = CD_SUP
    globals()["CD_SUP"] = cdx
    v_arr = res["真ん中"][0]
    print(f"   (抗力係数 {cdx} なら 真ん中の打った瞬間 {kmh(launch_speed(v_arr)):.0f} km/h)")
    globals()["CD_SUP"] = CD_SUP_SAVE
for L in (5.0, 15.0):
    print(f"   (距離 {L:.0f}m なら 真ん中の打った瞬間 {kmh(launch_speed(res['真ん中'][0], L=L)):.0f} km/h)")

print("=" * 70)
print("3 球は耐えられるか(球の正面の圧力)")
for lab, (v_arr, v0) in res.items():
    for name, v in (("相手の所", v_arr), ("打った瞬間", v0)):
        mach = v / C_SOUND
        p0 = pitot(mach) * P_ATM
        gauge = p0 - P_ATM
        F_peak = gauge * A_BALL           # よどみ点の圧力を断面全体に掛けた値(上限。実際より約2倍大きい)
        F = 0.5 * RHO * cd(mach) * A_BALL * v ** 2   # 正面全体で受ける力 ≒ 空気の抵抗
        print(f"  {lab} {name} マッハ{mach:.1f}: 正面(よどみ点)の圧力 {p0/P_ATM:.1f} 気圧(ゲージ {gauge/1e6:.2f} MPa)、"
              f"バレーボールの内圧(0.29〜0.32気圧)の {gauge/VB_PRESS[1]:.0f}〜{gauge/VB_PRESS[0]:.0f} 倍、"
              f"球が正面全体で受ける力(=空気の抵抗) {F/1000:.0f} kN({F/G/1000:.1f} トン)"
              f"[参考: よどみ点の圧力×断面 {F_peak/1000:.0f} kN は過大]")
# 拳で打つ瞬間の力: 打った瞬間の運動量を 1ms で
for lab, (v_arr, v0) in res.items():
    J = M_BALL * v0
    print(f"  [台本では使わない] {lab}: 打った瞬間の球の運動量 {J:.0f} N·s、拳の接触を {CONTACT_FIST*1000:.0f}ms と置くと平均 {J/CONTACT_FIST/1000:.0f} kN"
          f"({J/CONTACT_FIST/G/1000:.0f} トン)")

print("=" * 70)
print(f"5 ゴンの拳とゴンの体(拳の有効質量 {M_FIST}kg、拳が加速する道のり {ARM_STROKE}m と置く)")
for lab, (v_arr, v0) in res.items():
    for name, v in (("空気なし", v_arr), ("空気あり", v0)):
        vf = v / (1 + E_MAX)
        KE = 0.5 * M_FIST * vf ** 2
        KE_boxer = 0.5 * M_FIST * V_BOXER ** 2
        t = 2 * ARM_STROKE / vf
        P = KE / t
        p_ball = M_BALL * v
        V_back = p_ball / M_GON
        slide = V_back ** 2 / (2 * 0.6 * G)
        print(f"  {lab} {name}: 拳 {vf:.0f} m/s({kmh(vf):.0f}km/h、ボクサーの{vf/V_BOXER:.1f}倍)、"
              f"拳の運動エネルギー {KE/1000:.0f} kJ(ボクサー {KE_boxer:.0f} J の {KE/KE_boxer:.0f} 倍)、"
              f"加速 {t*1000:.2f} ms、仕事率 {P/1e6:.0f} MW(人の最大 6kW の {P/P_HUMAN:,.0f} 倍)、"
              f"反動でゴン(49kg)が受ける速さ {V_back:.1f} m/s({kmh(V_back):.0f}km/h)、摩擦0.6なら {slide:.1f}m 滑る")

print("=" * 70)
print("6 捕っていたら")
for lab, (M, mu, d) in CASES.items():
    v_arr = res[lab][0]
    V = M_BALL * v_arr / (M + M_BALL)
    print(f"  {lab}: 捕った瞬間に選手が動き出す速さ {V:.2f} m/s({kmh(V):.1f}km/h)、"
          f"摩擦で止まるまで {V**2/(2*mu*G):.2f} m(=場の外までの距離)、止まるまで {V/(mu*G):.2f} 秒")

print("=" * 70)
print("7章で使う組: 控えめ・空気あり(はね返り0.8・拳の重さ無限大と見た 1.8倍の上限で割る=拳の速さの下限)")
v0 = res["控えめ"][1]
vf = v0 / (1 + E_MAX)
KE = 0.5 * M_FIST * vf ** 2
t = 2 * ARM_STROKE / vf
P = KE / t
Vb = M_BALL * v0 / M_GON
print(f"  打った瞬間の球 {kmh(v0):.0f} km/h → 拳 {vf:.1f} m/s(音の {vf/C_SOUND:.2f} 倍、ボクサーの {vf/V_BOXER:.1f} 倍)")
print(f"  拳のエネルギー {KE/1000:.0f} kJ(ボクサー {0.5*M_FIST*V_BOXER**2:.0f} J の {KE/(0.5*M_FIST*V_BOXER**2):.0f} 倍)")
print(f"  加速 {t*1000:.2f} ms、仕事率(1秒あたりに注ぐエネルギー) {P/1e6:.0f} MW = 人の目安 6kW の {P/P_HUMAN:,.0f} 倍")
print(f"  反動 {Vb:.2f} m/s({kmh(Vb):.1f} km/h)、摩擦0.6(仮)だけで {Vb**2/(2*0.6*G):.2f} m 滑る")
print("  (拳の有効質量を2.9kgとすると、球は拳の (1+e)M/(M+m)=" + f"{(1+E_MAX)*M_FIST/(M_FIST+M_BALL):.3f}" + " 倍なので、拳はさらに速い: "
      f"{v0*(M_FIST+M_BALL)/((1+E_MAX)*M_FIST):.0f} m/s)")

# ===================== 8版で足した計算 =====================
REACT = 0.2                 # 人が見てから反応できる時間の目安(単純な視覚反応 約0.18〜0.21秒の測定)
SG_K = 1.7415e-4            # サットン・グレイブスの式の係数(地球の空気、SI)。極超音速向けの式で、マッハ2〜4では粗い目安(仮)
R_NOSE = D_BALL / 2
SKIN = dict(k=0.15, rho=1100.0, c=1900.0)   # 仮: 球の表面の材料(ゴム・樹脂に近い値)の熱の伝わりやすさ・密度・比熱
SQUASH = 0.10               # 仮: 拳が当たって球がつぶれる深さ 10cm(直径21cmの約半分)
PUNCH_N = 3427.0            # 五輪ボクサーのパンチ力の平均(Walilko 2005)


def trajectory(v_arrive, L=FLIGHT, dx=1e-3):
    """打った所(x=0)から相手(x=L)までの速さの並び(後ろ向きに積分して前向きに並べ直す)"""
    vs = [v_arrive]
    v = v_arrive
    n = int(L / dx)
    for _ in range(n):
        k = 0.5 * RHO * cd(v / C_SOUND) * A_BALL / M_BALL
        v += k * v * dx
        vs.append(v)
    vs.reverse()
    return vs, dx


print("=" * 70)
print("8 時間の目盛り(10m を飛ぶ時間と、人が見て反応できる時間)")
for lab in ("控えめ", "真ん中"):
    vs, dx = trajectory(res[lab][0])
    T = sum(dx / v for v in vs[:-1])
    print(f"  {lab}・空気あり: 10m を {T*1000:.1f} ms で飛ぶ。反応の目安 {REACT}s の {REACT/T:.0f} 分の1")

print("=" * 70)
print("9 球の熱(9版: 置いた値の真ん中・空気ありを台本で使う。控えめも並べる)")


def surface_heat(lab):
    vs, dx = trajectory(res[lab][0])
    ts, qs = [0.0], []
    for v in vs[:-1]:
        qs.append(SG_K * math.sqrt(RHO / R_NOSE) * v ** 3)
        ts.append(ts[-1] + dx / v)
    e = math.sqrt(SKIN["k"] * SKIN["rho"] * SKIN["c"])

    def dT(t):
        acc = 0.0
        for i in range(len(qs)):
            if ts[i + 1] > t:
                break
            acc += qs[i] * (ts[i + 1] - ts[i]) / math.sqrt(max(t - ts[i] - (ts[i + 1] - ts[i]) / 2, 1e-9))
        return acc / (math.sqrt(math.pi) * e)
    Tend = ts[-1]
    pk = max((dT(Tend * k / 40), Tend * k / 40) for k in range(1, 41))
    end = dT(Tend * 0.9999)
    M0 = vs[0] / C_SOUND
    T0 = 288.15 * (1 + 0.2 * M0 ** 2) - 273.15
    return vs[0], M0, T0, qs[0], Tend, pk, end


for lab in ("真ん中", "控えめ"):
    v0_, M0, T0, q0, Tend, pk, end = surface_heat(lab)
    print(f"  {lab}・空気あり: 打った瞬間 マッハ{M0:.2f}、よどみ点の温度 {T0:.0f}℃(理想気体。マッハ8では空気の分解で実際は下がる)、"
          f"熱の流れ {q0/1e6:.1f} MW/m²")
    print(f"     表面の温度の上がり: いちばん高いとき +{pk[0]:.0f}℃({pk[1]*1000:.2f} ms)、届くとき +{end:.0f}℃ → 15℃から {15+pk[0]:.0f}℃・{15+end:.0f}℃(飛ぶ時間 {Tend*1000:.2f} ms)")
vs, dx = trajectory(res["控えめ"][0])
v0 = vs[0]

print("=" * 70)
print("10 拳の側(控えめ・空気あり)")
vf = v0 / (1 + E_MAX)
t_c = math.pi * SQUASH / vf   # 9版: 球をばねとして解く(拳の重さ無限大、いちばん深いつぶれが SQUASH)。半周期 π/ω、ω=v/つぶれ
F_fist = M_BALL * v0 / t_c
print(f"  [8版の式 つぶれ÷拳の速さ={SQUASH/vf*1e3:.3f} ms は短すぎ。9版はばねの半周期]")
print(f"  拳 {vf:.1f} m/s、球のいちばん深いつぶれ {SQUASH*100:.0f}cm と置くと接触 {t_c*1e3:.3f} ms、拳が受ける平均の力 {F_fist/1e6:.2f} MN({F_fist/G/1000:.0f} トン)"
      f" = 五輪ボクサーのパンチ力 {PUNCH_N:.0f} N の {F_fist/PUNCH_N:.0f} 倍、橈骨が折れる力の上の端 3.4kN の {F_fist/3400:.0f} 倍")
for sq in (0.05, 0.15):
    tc = math.pi * sq / vf
    print(f"   (つぶれ {sq*100:.0f}cm なら {M_BALL*v0/tc/1e6:.2f} MN、パンチ力の {M_BALL*v0/tc/PUNCH_N:.0f} 倍)")

print("=" * 70)
print("11 反動(控えめ・空気あり、ゴンの床の摩擦0.6は仮)")
Vb = M_BALL * v0 / M_GON
print(f"  ゴン(49kg)が受ける速さ {Vb:.2f} m/s({kmh(Vb):.1f} km/h)、床の摩擦だけで止めると {Vb**2/(2*0.6*G):.2f} m 滑る")

"""8版の作戦：横に広い「空気の座布団」の袋で、真ん中・重い島を浮かせる（2026-11-01）。

python -X utf8 episodes/laputa/sim/cushion.py

袋の形：半径 R・厚さ h の平たい円柱（座布団）。上と下の膜を、縦の帯（テンドン）で 3m ごとにつなぐ。
中の水素は外より p_s だけ高い圧力（口を閉じたスーパープレッシャー）。
島は袋の下から、漏斗のように張ったひもで吊る（島は袋の口の d 下）。
ひもは斜めに袋の底を内側へ引く。その横の力を、袋の中の圧力が膜をふくらませる力で押し返す（空気で支える輪）。

つり合い（力の向きごとに確かめる）
- 上下：浮く力 = 島 + ひも + 膜 + 帯（浮く力は高さごとの空気とガスの密度の差を積分）
- 横：ひもが袋を内側へ引く力の合計 H = Σ w·g·r/d。袋の上下の膜の外向きの張力 p_s·h·π·R が H の 1.5 倍を超えるように p_s を決める
- 浮く力は、口より上の空気の重さ × 影の面積 を超えない（コードで確かめる）
置いた値：帯の間隔 3m、膜と帯とひもはケブラー級（強さ/密度 2.40MJ/kg、安全率2）、膜はポリエチレン 25MPa（安全率2）、ガスの温度=外の気温。
"""
import math
import deep

G0 = deep.G0
KEV = deep.KEVLAR
SF = 2.0
LOBE = 3.0
PE_SIG = 25e6
PE_RHO = 920.0
MEMBRANE = "pe"        # "pe": 膜をポリエチレンの厚さで持たせる / "fiber": 0.02mm のポリエチレン＋繊維で持たせる
H2_YEAR = 100e9


def cushion(R, h, d, z_island, M, n=60):
    zb = z_island + d                      # 袋の底（口）の高さ
    A = math.pi * R * R
    # ひも（漏斗）: 島から袋の底へ一様に張る。重さの割合 k、横の力 H
    k = SF * G0 * (R * R / 2 + d * d) / (d * KEV)
    if k >= 1:
        return None
    rope = M * k / (1 - k)
    W = M + rope                            # 袋が持ち上げる、島とひもの重さ（kg）
    H = W * G0 * (2 * R / 3) / d            # ひもが袋の底を内側へ引く力の合計（N）
    p_s = 1.5 * H / (math.pi * R * h)       # 外向きの膜の張力で押し返すのに要る、中の圧力の上乗せ（Pa）
    # 浮く力（高さごとに積分、中の圧力は口で外+p_s）
    _, p_air0, _ = deep.isa(zb)
    p_g = p_air0 + p_s
    dz = h / n
    lift = gas = 0.0
    dp_top = p_s
    int_dp = 0.0
    for i in range(n):
        z = zb + (i + 0.5) * dz
        T, pa, ra = deep.isa(z)
        rg = p_g * deep.M_H2 / (deep.R * T)
        lift += (ra - rg) * A * dz
        gas += rg * A * dz
        int_dp += (p_g - rg * G0 * dz / 2 - pa) * dz
        p_g -= rg * G0 * dz
        dp_top = p_g - deep.isa(zb + (i + 1) * dz)[1]
    col = deep.isa(zb)[1] / G0 * A           # 口より上の空気の重さ × 影（上限）
    # 膜（上・下・横）: 帯の間 3m でふくらむ。圧力差の大きい上で厚さを決める（下は p_s）
    area = 2 * A + 2 * math.pi * R * h
    if MEMBRANE == "pe":
        t_top = max(20e-6, dp_top * LOBE * SF / PE_SIG)
        t_bot = max(20e-6, p_s * LOBE * SF / PE_SIG)
        film = (A * t_top + A * t_bot + 2 * math.pi * R * h * t_top) * PE_RHO
    else:  # ガスを止めるポリエチレン 0.02mm ＋ 張力を受ける繊維（ひもと同じ材料）
        t_top = t_bot = 20e-6
        film = area * 20e-6 * PE_RHO + (A * dp_top * LOBE * SF + A * p_s * LOBE * SF + 2 * math.pi * R * h * dp_top * LOBE * SF) / KEV
    # 膜の外向きの張力 p_s·h·π·R を受け持つ分の繊維（上下の膜を半径方向に補強する帯）: 張力 N=p_s·h/2 を半径 R にわたって
    hoop = SF * (p_s * h / 2) * 2 * A * 2 / KEV   # 上下2枚 × 2方向（膜は縦横に張られる）、面全体で N を持つ繊維の重さ
    # 縦の帯: 上の膜を引き下ろす力 dp_top·A を、長さ h で
    tendon = SF * dp_top * A * h / KEV
    # ビリアル定理の下限: 圧力を閉じ込めて荷を吊る構造の Σ(張力×長さ) ≥ A(h·Δp_top + 2∫Δp dz) − W g R²/(2d)（点検 chk_laputa.py と同じ式）
    virial = A * (h * dp_top + 2 * int_dp) - (M + rope) * G0 * R * R / (2 * d)
    vmin = SF * max(virial, 0.0) / KEV
    fiber_film = film - area * 20e-6 * PE_RHO if MEMBRANE != "pe" else 0.0
    struct = hoop + tendon + fiber_film
    if struct < vmin:                      # 下限に満たなければ、輪の帯を足して下限にそろえる
        hoop += vmin - struct
    need = M + rope + film + hoop + tendon
    return dict(R=R, h=h, d=d, zb=zb, z=z_island, k=k, rope=rope, H=H, p_s=p_s, lift=lift, gas=gas,
                film=film, hoop=hoop, tendon=tendon, need=need, ok=lift >= need, col=col, dp_top=dp_top,
                t_top=t_top, t_bot=t_bot, vmin=vmin)


MATERIALS = {"ケブラー": 3.45e9 / 1440, "炭素繊維T1100G": 7.0e9 / 1790, "CNT束(実験室)": 80e9 / 1300}


def best(M, z_island, Rs=range(4, 81, 2), hs=tuple(float(x) for x in range(2000, 30001, 2000)), top_lim=32000.0):
    out = None
    for R in [x * 1000.0 for x in Rs]:
        for h in hs:
            for frac in (0.03, 0.05, 0.07, 0.1, 0.15, 0.2, 0.3, 0.5, 0.7, 1.0, 1.4):
                if z_island + R * frac + h > top_lim:
                    continue
                r = cushion(R, h, R * frac, z_island, M, n=30)
                if r and r["ok"]:
                    assert r["lift"] <= r["col"] * 1.0001, "上限を超えた"
                    if out is None or r["gas"] < out["gas"]:
                        out = r
    return out


def ratio_best(M, z, top_lim=32000.0):
    """浮く力/要る重さ が一番大きい組み合わせ（届かないときの近さ）。"""
    out = None
    for R in [x * 1000.0 for x in range(4, 81, 2)]:
        for h in [float(x) for x in range(2000, 30001, 2000)]:
            for frac in (0.03, 0.05, 0.07, 0.1, 0.15, 0.2, 0.3, 0.5, 0.7, 1.0, 1.4):
                if z + R * frac + h > top_lim:
                    continue
                r = cushion(R, h, R * frac, z, M, n=30)
                if r and (out is None or r["lift"] / r["need"] > out[0]):
                    out = (r["lift"] / r["need"], r)
    return out


def main():
    global KEV, MEMBRANE
    MEMBRANE = "fiber"
    M = 1.74e12
    mats = dict(MATERIALS)
    mats["CNT繊維(8.8GPa)"] = 8.8e9 / 1300
    print("== 座布団の袋＋漏斗のひも（島1,000m、てっぺん32km以下、厚さ2〜30km、口の高さ÷半径0.03〜1.4）")
    for mname, sr in mats.items():
        KEV = sr
        r = best(M, 1000.0)
        if r:
            print(f"  {mname}（{sr/1e6:.2f}MJ/kg）: 浮く。直径{2*r['R']/1e3:.0f}km 厚さ{r['h']/1e3:.0f}km 口{r['zb']/1e3:.1f}km 水素{r['gas']/H2_YEAR:.1f}年分")
        else:
            q, rr = ratio_best(M, 1000.0)
            print(f"  {mname}（{sr/1e6:.2f}MJ/kg）: 浮かない（一番近くて 浮く力/要る重さ = {q:.2f}）")
    print("== 境目（強さ÷密度）")
    for s in (4e6, 5e6, 5.5e6, 6e6, 7e6, 8e6):
        KEV = s
        r = best(M, 1000.0)
        print(f"  {s/1e6:.1f}MJ/kg: " + ("浮かない" if not r else f"浮く 直径{2*r['R']/1e3:.0f}km 厚さ{r['h']/1e3:.0f}km 水素{r['gas']/H2_YEAR:.1f}年分"))
    print(f"  参考: ケブラー {MATERIALS['ケブラー']/1e6:.2f}、T1100G {MATERIALS['炭素繊維T1100G']/1e6:.2f}、6MJ/kg はケブラーの {6e6/MATERIALS['ケブラー']:.1f}倍・T1100G の {6e6/MATERIALS['炭素繊維T1100G']:.1f}倍")

    KEV = MATERIALS["CNT束(実験室)"]
    r = best(M, 1000.0)
    print("== 台本の作戦（CNT束 80GPa・密度1.3と置く、島1,000m、真ん中17.4億t）")
    print(f"  袋: 直径 {2*r['R']/1e3:.0f}km、厚さ {r['h']/1e3:.0f}km、口 {r['zb']/1e3:.1f}km（島の {r['d']/1e3:.1f}km 上）、てっぺん {(r['zb']+r['h'])/1e3:.1f}km、影 {math.pi*r['R']**2/1e6:.0f}km2")
    print(f"  口より上の空気 {deep.isa(r['zb'])[1]/G0/1e3:.2f}t/m2、下限の影 {M/(deep.isa(r['zb'])[1]/G0)/1e6:.0f}km2。浮く力 {r['lift']/1e3:.4g}t、上限の {r['lift']/r['col']*100:.0f}%")
    print(f"  中の圧力の上乗せ {r['p_s']/1e3:.0f}kPa（外 {deep.isa(r['zb'])[1]/1e3:.0f}kPa）。ひもの横の力 {r['H']/G0/1e3:.3g}t重 = 島の {r['H']/G0/M:.1f}倍、外側のひも 水平/鉛直 {r['R']/r['d']:.1f}")
    st = r['film'] + r['hoop'] + r['tendon'] + r['rope']
    print(f"  重さ: ひも {r['rope']/1e3:.3g}t、膜 {r['film']/1e3:.3g}t、輪の帯 {r['hoop']/1e3:.3g}t、縦の帯 {r['tendon']/1e3:.3g}t（ビリアル下限 {r['vmin']/1e3:.3g}t）、"
          f"全部で {st/1e3:.3g}t = 島の {st/M*100:.1f}%。要る重さ {r['need']/1e3:.4g}t")
    print(f"  水素 {r['gas']/1e3:.3g}t = 年産の {r['gas']/H2_YEAR:.1f}年分")
    for cd in (0.2, 0.5):
        rho_mid = deep.isa(r["zb"] + r["h"] / 2)[2]
        F = 0.5 * rho_mid * 20 ** 2 * cd * (2 * r["R"] * r["h"])
        print(f"  風20m/s・Cd{cd}: 横の力 {F/G0/1e3:.3g}t重（島の {F/G0/M*100:.2f}%）")
    print(f"  島1.7km ÷ 袋 {2*r['R']/1e3:.0f}km = {1.7/(2*r['R']/1e3):.3f}、ひもの長さ（いちばん外）{math.hypot(r['R'], r['d'])/1e3:.1f}km")
    # 同じ形でケブラー・炭素繊維
    for mname in ("ケブラー", "炭素繊維T1100G"):
        KEV = MATERIALS[mname]
        rr = cushion(r['R'], r['h'], r['d'], 1000.0, M, n=30)
        if rr:
            print(f"  同じ形で{mname}: 浮く力 {rr['lift']/1e3:.3g}t、ひも＋帯 {(rr['rope']+rr['hoop']+rr['tendon'])/1e3:.3g}t、要る重さ {rr['need']/1e3:.3g}t、横の力は島の {rr['H']/G0/M:.1f}倍")
        else:
            print(f"  同じ形で{mname}: ひもだけで吊る重さを超える")
    KEV = MATERIALS["CNT束(実験室)"]
    q, rr = ratio_best(4.83e12, 1000.0)
    print(f"== 重い島（CNT束・1,000m、てっぺん32km以下まで広げて）: 一番近くても 浮く力/要る重さ = {q:.2f}（直径{2*rr['R']/1e3:.0f}km 厚さ{rr['h']/1e3:.0f}km 口{rr['zb']/1e3:.1f}km）")
    # 島5,000m のときの口の高さ
    r5 = best(M, 5000.0)
    if r5:
        print(f"== 島5,000m（CNT束）: 直径{2*r5['R']/1e3:.0f}km 口{r5['zb']/1e3:.1f}km 水素{r5['gas']/H2_YEAR:.1f}年分")


if __name__ == "__main__":
    main()

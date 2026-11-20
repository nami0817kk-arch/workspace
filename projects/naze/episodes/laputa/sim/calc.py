"""ラピュタを風船で浮かせる計算（下調べ用、2026-10-31）。

python episodes/laputa/sim/calc.py で、research.md の表の数字が全部出る。
出典は episodes/laputa/research.md の 1。ここでは式と置いた値だけを書く。
"""
import math

R = 8.314462618          # J/(mol K)
M_AIR = 0.0289644        # kg/mol（国際標準大気）
M_HE = 0.0040026
M_H2 = 0.002016
G0 = 9.80665
TOKYO_DOME = 1.24e6      # m3
HE_YEAR = 190e6          # m3（15℃・1気圧）USGS MCS 2026、2025年の世界生産（推計）
HE_RESOURCES = 8.49e9 + 31.3e9   # m3 米国の回収可能量＋米国以外の確認資源量（USGS MCS 2026）
H2_YEAR = 100e9          # kg（IEA Global Hydrogen Review 2025、2024年の需要ほぼ1億t）
WORLD_POWER = 592e18 / (365.25 * 86400)   # W（Energy Institute 2025年版、2024年の一次エネルギー 592EJ、二次資料で確認）
PEOPLE = 8.2e9           # 世界の人口（概数、仮）


def isa(h):
    """国際標準大気（対流圏 0〜11km）。温度K・気圧Pa・空気の密度kg/m3。"""
    T = 288.15 - 0.0065 * h
    p = 101325.0 * (T / 288.15) ** (G0 * M_AIR / (R * 0.0065))
    return T, p, p * M_AIR / (R * T)


def gas_density(M, T, p):
    return p * M / (R * T)


# ---- 島の重さ（3通り）----
# 上：城と町（円柱、中身の詰まり具合 fill）、下：岩（逆円錐か半球）。密度は花崗岩の値。
CASES = {
    #        上の直径m 上の高さm 上の詰まり 下の形   下の直径m 下の詰まり 密度kg/m3
    "下限": (1600, 260, 0.15, "cone", 1200, 0.15, 2600),
    "中央": (1700, 300, 0.30, "hemi", 1200, 1.00, 2650),
    "上限": (1800, 450, 1.00, "hemi", 1350, 1.00, 2700),
}


def island(c):
    D1, H1, f1, shape, D2, f2, rho = c
    v_up = math.pi * (D1 / 2) ** 2 * H1
    r2 = D2 / 2
    v_low = math.pi / 3 * r2 ** 2 * r2 if shape == "cone" else 2 / 3 * math.pi * r2 ** 3
    m_up = v_up * f1 * rho
    m_low = v_low * f2 * rho
    return v_up, v_low, m_up, m_low, m_up + m_low


def lift_per_m3(h, kind):
    """1m3 あたりの正味の浮く力（ガスだけ、膜は入れない）kg/m3。"""
    T, p, rho_air = isa(h)
    if kind == "He":
        return rho_air - gas_density(M_HE, T, p)
    if kind == "H2":
        return rho_air - gas_density(M_H2, T, p)
    if kind == "hot":          # 中の空気を 121℃（FAA: 多くの気球の連続使用の上限 250°F）
        return rho_air - rho_air * T / (121 + 273.15)
    raise ValueError(kind)


def sphere_d(V):
    return (6 * V / math.pi) ** (1 / 3)


def sphere_area(V):
    return math.pi * sphere_d(V) ** 2


def main():
    print("== 大気（国際標準大気）")
    for h in (0, 5000):
        T, p, r = isa(h)
        print(f"  {h}m: {T-273.15:.2f}℃ {p:.0f}Pa 空気 {r:.4f} kg/m3")
    print("== 1m3 の浮く力 kg/m3")
    for k in ("He", "H2", "hot"):
        print(f"  {k}: 海面 {lift_per_m3(0,k):.4f} / 5000m {lift_per_m3(5000,k):.4f}")
    rho_he_std = gas_density(M_HE, 288.15, 101325)
    rho_h2_std = gas_density(M_H2, 288.15, 101325)
    print(f"  ヘリウム 15℃1気圧 {rho_he_std:.4f} kg/m3（USGS の換算 0.0047t/27.737m3 = {4.7/27.737:.4f}）")

    # 風船1個（Qualatex 11インチ: 0.015m3 で浮く力 10g）
    v_toy = 0.015
    gross_toy = v_toy * lift_per_m3(0, "He")
    skin = gross_toy - 0.010
    toy_hi_gross = v_toy * lift_per_m3(5000, "He")
    toy_hi_net = toy_hi_gross - skin
    print(f"== ゴム風船 11インチ: 海面のガスの浮く力 {gross_toy*1000:.1f}g、正味 10g → ゴム等 {skin*1000:.1f}g 相当")
    print(f"   同じ大きさで 5000m: ガスの力 {toy_hi_gross*1000:.2f}g、正味 {toy_hi_net*1000:.2f}g（{0.010/toy_hi_net:.2f}倍の個数）"
          f"／ガスの力だけの比 {lift_per_m3(0,'He')/lift_per_m3(5000,'He'):.3f}倍")

    print("== 島")
    res = {}
    for name, c in CASES.items():
        vu, vl, mu, ml, m = island(c)
        res[name] = m
        print(f"  {name}: 上 {vu:.3g}m3→{mu/1e3:.3g}t 下 {vl:.3g}m3→{ml/1e3:.3g}t 計 {m/1e3:.3g}t "
              f"(={m/1e3/1e8:.1f}億t)  ヒンデンブルク号の総浮力232tの {m/1e3/232:.3g}倍")

    print("== 個数・体積・ガス")
    for name, m in res.items():
        print(f"--- {name} {m/1e3/1e8:.1f}億t")
        print(f"  ゴム風船（海面・正味10g）: {m/0.010:.3g}個（1人あたり {m/0.010/PEOPLE:.3g}個）"
              f" / 5000m同じ大きさ: {m/toy_hi_net:.3g}個")
        for h in (0, 5000):
            for k in ("He", "H2", "hot"):
                V = m / lift_per_m3(h, k)
                line = f"  {h:>4}m {k:>3}: 体積 {V:.3g}m3 = 東京ドーム {V/TOKYO_DOME:.3g}個, 1個の球なら直径 {sphere_d(V)/1e3:.1f}km"
                line += f", NASA 113万m3気球 {V/1.13e6:.3g}個, ヒンデンブルク号 {V/2e5:.3g}隻"
                if k == "He":
                    std = m * M_HE / (M_AIR - M_HE) / rho_he_std   # ガスの量は高度によらない
                    line += f" | He {std:.3g}m3(15℃) = 年産 {std/HE_YEAR:.3g}年分, 資源量の {std/HE_RESOURCES:.3g}倍"
                if k == "H2":
                    mass = m * M_H2 / (M_AIR - M_H2)
                    line += f" | H2 {mass/1e3:.3g}t = 年産 {mass/H2_YEAR:.3g}年分（{mass/H2_YEAR*365:.0f}日）"
                if k == "hot":
                    A = sphere_area(V)
                    lo, hi = A * 670, A * 1070
                    line += (f" | 膜の面積 {A:.3g}m2, 保つ熱 {lo/1e12:.2f}〜{hi/1e12:.2f}TW"
                             f" = 世界の一次エネルギーの {lo/WORLD_POWER*100:.1f}〜{hi/WORLD_POWER*100:.1f}%,"
                             f" プロパン {lo/46.4e6*3.156e7/1e12:.2f}〜{hi/46.4e6*3.156e7/1e12:.2f}Gt/年")
                print(line)

    # 熱気球の熱の逃げ（FAA: 平均的な気球は 4秒の標準バーンを 25〜40秒ごと、平均的なバーナー 18.5MBTU/h）
    burner = 18.5e6 * 1055.06 / 3600   # W
    v77 = 77000 * 0.0283168
    A77 = sphere_area(v77)
    print(f"== 熱気球の例: バーナー {burner/1e6:.2f}MW、平均 {burner*4/40/1e3:.0f}〜{burner*4/25/1e3:.0f}kW、"
          f"7.7万ft3={v77:.0f}m3 の球の面積 {A77:.0f}m2 → {burner*4/40/A77:.0f}〜{burner*4/25/A77:.0f} W/m2、"
          f"燃料 {202*4/40:.0f}〜{202*4/25:.0f}ガロン/時")

    # 最小の作戦：水素の袋1つ（5000m）。膜は NASA の 20μm ポリエチレン、荷を吊るすひもは繊維。
    print("== 作戦：水素の袋1つで 5000m")
    film = 0.92e3 * 20e-6            # kg/m2
    # ひもの重さの置き方:「島の全荷重を、ひもの全長で背負う」(厳しめ。実際は袋の表面の部分は袋の圧力でも支えられる)。
    # 長さは 2 通り: 経線の道のり πD/2(1版で使った厳しめの値)／上下の高さ D(自重が効くのは高さ)。安全率は 2 と 1。
    # D が全体の重さで大きくなるので、繰り返して求める。k が増え続けて 1 を超えたら「閉じない」。
    for name, m in res.items():
      for lname, lfac in (("道のり πD/2", math.pi / 2), ("上下の高さ D", 1.0)):
       for sf in (2, 1):
        for rope, s_over_rho in (("ケブラー 3.45GPa/1.44", 3.45e9 / 1440), ("鋼 1.77GPa/7.85", 1.77e9 / 7850)):
            total = m
            ok = False
            for _ in range(200):
                V = total / lift_per_m3(5000, "H2")
                D = sphere_d(V)
                k = G0 * lfac * D * sf / s_over_rho   # ひもの重さ/吊る重さ
                if k >= 1:
                    break
                m_film = sphere_area(V) * film
                new = (m + m_film) / (1 - k)
                if abs(new - total) < 1e-9 * total:
                    ok = True; total = new; break
                total = new
            if not ok:
                print(f"  {name} [{lname}・安全率{sf}] {rope}: 閉じない（k={k:.2f}、ひもを足すほど袋が大きくなり発散）")
                continue
            V = total / lift_per_m3(5000, "H2")
            h2 = total * M_H2 / (M_AIR - M_H2)
            print(f"  {name} [{lname}・安全率{sf}] {rope}: 直径 {sphere_d(V)/1e3:.1f}km 体積 {V:.3g}m3（東京ドーム {V/TOKYO_DOME:.3g}個）"
                  f" 膜 {sphere_area(V)*film/1e3:.3g}t ひも {k*total/1e3:.3g}t（{k*100:.1f}%） 全体 {total/1e3:.3g}t"
                  f" 水素 {h2/1e3:.3g}t = 年産の {h2/H2_YEAR*365:.0f}日分")

    big60 = 60e6 * 0.0283168
    print(f"== NASA Big 60: {big60:.3g}m3 = 東京ドーム {big60/TOKYO_DOME:.2f}個")
    print(f"== スウィフトのラピュタ: 直径 {7837*0.9144:.0f}m 厚さ {300*0.9144:.0f}m")


if __name__ == "__main__":
    main()

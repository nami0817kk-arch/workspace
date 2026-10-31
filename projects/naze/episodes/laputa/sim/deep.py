"""ラピュタの袋を「高さで空気が変わる」形で計算し直す（6版の掘り下げ、2026-11-01）。

python -X utf8 episodes/laputa/sim/deep.py

calc.py は袋の中も外も 5,000m の空気で一様と置いた。直径 18.5km の袋は高さも十数 km あるので、
ここでは標準大気（0〜32km）で高さごとに空気とガスの密度を変えて、浮く力・膜の張力・風・水素の抜け・昼夜を出す。
置いた値はすべて定数の欄にまとめる。出典は research.md の 8。
"""
import math

R = 8.314462618
M_AIR = 0.0289644
M_H2 = 0.002016
M_HE = 0.0040026
G0 = 9.80665

# ---- 置いた値 ----
H_OVER_D = 121 / 140        # 袋の高さ/直径。NASA の 4,000万ft3 気球（ふくらむと直径140m・高さ121m）と同じ形
BASE = 5000.0               # 島（と袋の下の口）の高さ m
FILM_T = 20e-6              # 膜の厚さ m（NASA 0.8mil）
FILM_RHO = 920.0            # ポリエチレンの密度 kg/m3
FILM_SIGMA = (25e6, 44e6)   # ポリエチレン膜の引っ張り強さ Pa（Dow LDPE 310E 25MPa〜ExxonMobil LLDPE 44MPa、ASTM D882 の破断強さ）
LOBE_R = 3.0                # 膜が帯（ゴア）の間でふくらむ半径 m（NASA のゴアの幅 3m から置く）
SF = 2.0                    # 安全率
KEVLAR = 3.45e9 / 1440      # ケブラーの 強さ/密度
WIND = (10.0, 20.0, 30.0)   # 上空の風 m/s（置く）
CD = (0.2, 0.5)             # 球に近い形の抗力係数（とても大きいレイノルズ数で 0.2 前後、0.5 は控えめ）
H2_PERM = (9.1e-16, 2.7e-15)  # 水素のポリエチレン透過係数 mol·m/(m2·s·Pa)（HDPE 9.14e-16 の業者資料〜その3倍を置く）
SUPERHEAT = (5.0, 15.0)     # 昼にガスが外より温まる K（置く。一次資料の数字は見つけていない）
H2_YEAR = 100e9             # kg
ISLANDS = {"軽い": 2.92e11, "真ん中": 1.74e12, "重い": 4.83e12}  # kg（calc.py）


def isa(h):
    """標準大気 0〜32km。温度K・気圧Pa・密度kg/m3。32km より上は 20〜32km の式(1K/km)をそのまま延ばしている(本当の大気とはずれる。結論に使うのは 32km 以下)。"""
    if h <= 11000:
        T = 288.15 - 0.0065 * h
        p = 101325 * (T / 288.15) ** (G0 * M_AIR / (R * 0.0065))
    elif h <= 20000:
        T = 216.65
        p = 22632.06 * math.exp(-G0 * M_AIR * (h - 11000) / (R * T))
    else:
        T = 216.65 + 0.001 * (h - 20000)
        p = 5474.889 * (T / 216.65) ** (-G0 * M_AIR / (R * 0.001))
    return T, p, p * M_AIR / (R * T)


def bag(D, gas_M=M_H2, dT=0.0, n=400, base=None):
    """直径 D の袋（扁平な回転楕円体、高さ H=0.864D）を下の口 BASE から積み上げる。
    下の口でガスの圧力=外の気圧（ゼロ圧気球）。ガスの温度=外の気温+dT。
    返り値: 浮く力 kg、ガスの重さ kg、体積、表面積、てっぺんの圧力差 Pa、膜にかかる平均の気圧 Pa、密度で重みをつけた平均の空気密度"""
    base = BASE if base is None else base
    H = H_OVER_D * D
    a = D / 2
    dz = H / n
    _, p_gas, _ = isa(base)
    lift = gas = vol = 0.0
    dpdv = 0.0
    dp_top = 0.0
    p_sum = 0.0
    rho_a_area = 0.0
    for i in range(n):
        z = base + (i + 0.5) * dz
        T, p_air, rho_air = isa(z)
        Tg = T + dT
        rho_g = p_gas * gas_M / (R * Tg)
        u = (i + 0.5) / n * 2 - 1           # -1..1
        A = math.pi * a * a * max(0.0, 1 - u * u)
        lift += (rho_air - rho_g) * A * dz
        gas += rho_g * A * dz
        vol += A * dz
        p_sum += p_gas * A * dz
        dpdv += (p_gas - p_air) * A * dz
        rho_a_area += rho_air * 2 * a * math.sqrt(max(0.0, 1 - u * u)) * dz
        p_gas -= rho_g * G0 * dz
        dp_top = p_gas - isa(base + (i + 1) * dz)[1]
    c = H / 2
    e = math.sqrt(1 - (c / a) ** 2)
    area = 2 * math.pi * a * a * (1 + (1 - e * e) / e * math.atanh(e))   # 扁平な回転楕円体の表面積
    proj = rho_a_area  # 横から見た影の面積 × 空気密度 の積分（kg/m）
    return dict(lift=lift, gas=gas, vol=vol, area=area, H=H, dp_top=dp_top, p_mean=p_sum / vol, rho_proj=proj, dpdv=dpdv)


def solve(M, film_t=FILM_T, dT=0.0):
    """島 M を吊って浮く直径を求める（ひもは calc.py と同じ厳しめの置き方: 全荷重を経線の道のり πD/2 で背負う、安全率2）。"""
    lo, hi = 1000.0, 80000.0
    for _ in range(80):
        D = (lo + hi) / 2
        b = bag(D, dT=dT)
        film = b["area"] * film_t * FILM_RHO
        k = G0 * (math.pi * D / 2) * SF / KEVLAR
        need = (M + film) / (1 - k) if k < 1 else float("inf")
        if b["lift"] >= need:
            hi = D
        else:
            lo = D
    D = hi
    b = bag(D, dT=dT)
    film = b["area"] * film_t * FILM_RHO
    k = G0 * (math.pi * D / 2) * SF / KEVLAR
    total = (M + film) / (1 - k)
    return D, b, film, k * total, total


def cluster(M, d, sf_rope, dh_list=(1000, 2000, 3000, 4000, 6000, 8000, 10000, 12000, 15000, 20000), max_angle45=True):
    """直径 d の袋を N 個、島の上に横へ並べて吊る。袋の口は島より dh 上。袋は円形に敷き詰め(1個あたり d×d)、
    ひもは島から各袋へ斜めに張る。ひもの重さ/吊る重さ = g·sf·(r²+dh²)/(dh·強さ/密度) を円の中で平均。
    膜は袋ごとに要る厚さ(てっぺんの圧力差×LOBE_R×2/弱い側の強さ、最低20μm)。水素の量が最も少ない組み合わせを返す。"""
    best = None
    for dh in dh_list:
        b = bag(d, n=150, base=BASE + dh)
        t = max(FILM_T, b["dp_top"] * LOBE_R * 2 / FILM_SIGMA[0])
        film = b["area"] * t * FILM_RHO
        net = b["lift"] - film
        N = 1.0
        while N < 1e5:
            Rc = d * math.sqrt(N / math.pi)
            if max_angle45 and Rc > dh:
                break                     # 外側のひもが45°より寝る → 袋が内側へ引き寄せられ、つり合わない
            k = G0 * sf_rope * (Rc * Rc / 2 + dh * dh) / (dh * KEVLAR)
            if k >= 1:
                break
            if N * net * (1 - k) >= M:
                r = dict(N=N, d=d, dh=dh, Rc=Rc, t=t, film=N * film, rope=k * N * net, gas=N * b["gas"], k=k, H=b["H"])
                if best is None or r["gas"] < best["gas"]:
                    best = r
                break
            N *= 1.02
    return best


def single(M, sf_rope=SF, rope_len="path", struct_f=0.0):
    """袋1つ。膜の厚さは、てっぺんの圧力差から決める(最低20μm)。ひもは厳しめ(全荷重を経線の道のり πD/2 で背負う)。"""
    for D in [x * 100.0 for x in range(20, 800)]:
        b = bag(D, n=200)
        t = max(FILM_T, b["dp_top"] * LOBE_R * 2 / FILM_SIGMA[0])
        film = b["area"] * t * FILM_RHO
        L = math.pi * D / 2 if rope_len == "path" else b["H"]
        k = G0 * L * sf_rope / KEVLAR
        struct = b["dpdv"] * struct_f / KEVLAR   # 圧力を閉じ込める帯(ゴアの帯)の重さの下限 ∫Δp dV ÷ (強さ/密度) × 係数
        if k < 1 and b["lift"] * (1 - k) - film - struct >= M:
            return dict(D=D, b=b, t=t, film=film, rope=k * b["lift"], k=k, struct=struct)
    return None


def main():
    print("== 標準大気")
    for h in (0, 5000, 10000, 15000, 20000, 25000):
        T, p, r = isa(h)
        print(f"  {h/1000:>4.0f}km {T-273.15:6.1f}℃ {p/100:7.1f}hPa {r:.4f}kg/m3")
    col = isa(BASE)[1] / G0
    print(f"  5,000m より上の空気の重さ: 1m2 あたり {col/1e3:.2f}t")
    for name, M in ISLANDS.items():
        print(f"  {name}の島を支えるのに要る空の広さの下限: {M/col/1e6:.0f}km2")

    print("== 1m3 の浮く力（海面、アルキメデス: 押しのけた空気の重さ − ガスの重さ）")
    T, p, ra = isa(0)
    for name, Mg in (("ヘリウム", M_HE), ("水素", M_H2)):
        rg = p * Mg / (R * T)
        print(f"  {name}: 空気 {ra:.4f} − ガス {rg:.4f} = {ra-rg:.4f} kg")
    T, p, ra = isa(BASE)
    rg = p * M_H2 / (R * T)
    print(f"  水素 5,000m: 空気 {ra:.4f} − ガス {rg:.4f} = {ra-rg:.4f} kg")

    print("== 袋1つ・高さで空気が変わる: 直径ごとの浮く力（膜とひもを引く前）")
    for D in (9800, 13300, 18500, 25000, 30000, 40000):
        b = bag(D, n=200)
        T, p, ra = isa(BASE)
        uni = b["vol"] * (ra - p * M_H2 / (R * T))
        print(f"  直径 {D/1000:.1f}km 高さ {b['H']/1000:.1f}km てっぺん {(BASE+b['H'])/1000:.1f}km: 浮く力 {b['lift']/1e3:.3g}t"
              f"（一様5,000mなら {uni/1e3:.3g}t、{b['lift']/uni*100:.0f}%） 水素1kgで {b['lift']/b['gas']:.1f}kg（理想 {(M_AIR/M_H2-1):.1f}kg）"
              f" てっぺんの外の空気 {isa(BASE+b['H'])[2]/isa(BASE)[2]*100:.0f}%")

    print("== 袋1つで解く（膜は要る厚さ、帯は ∫Δp dV ÷ 強さ/密度 × 係数、ひもは厳しめ・安全率2）")
    sols = {}
    for f, label in ((0.0, "帯なし(6版)"), (1.0, "帯 安全率1"), (1.5, "帯 安全率1×1.5"), (3.0, "帯 安全率2×1.5")):
        for name, M in ISLANDS.items():
            s = single(M, struct_f=f)
            if f == 3.0:
                sols[name] = s
            if not s:
                print(f"  [{label}] {name}: 直径80kmまで解なし")
                continue
            b = s["b"]
            print(f"  [{label}] {name}: 直径 {s['D']/1000:.1f}km 高さ {b['H']/1000:.1f}km てっぺん {(BASE+b['H'])/1000:.1f}km 膜 {s['t']*1000:.1f}mm {s['film']/1e3:.3g}t"
                  f" 帯 {s['struct']/1e3:.3g}t（∫Δp dV {b['dpdv']:.3g}J） ひも {s['rope']/1e3:.3g}t 水素 {b['gas']/1e3:.3g}t（年産の {b['gas']/H2_YEAR*365:.0f}日）"
                  f" 影 {math.pi*(s['D']/2)**2/1e6:.0f}km2")
    for name in ("真ん中", "重い"):
        s = single(ISLANDS[name], sf_rope=1, rope_len="height")
        print(f"  {name}（帯なし・ひも 高さで数え・安全率1 にゆるめても）: {'解なし' if not s else s['D']}")
    print(f"  直径18.5km の袋の影: {math.pi*9.25**2:.0f}km2（真ん中の島の下限 {ISLANDS['真ん中']/col/1e6:.0f}km2 に足りない）")

    print("== 袋をたくさん並べる（ひもは島から各袋へ斜めに。外側のひもを45°以内に限る／限らない）")
    for name in ("軽い", "真ん中", "重い"):
        for lim in (True, False):
            for sf in (2, 1):
                best = None
                for d in (1000, 2000, 3000, 5000, 8000, 10000, 13000, 16000):
                    r = cluster(ISLANDS[name], d, sf, max_angle45=lim)
                    if r and (best is None or r["gas"] < best["gas"]):
                        best = r
                tag = "45°以内" if lim else "角度の制限なし"
                if best:
                    ratio = best["Rc"] / best["dh"]
                    print(f"  {name}・{tag}・安全率{sf}: 直径 {best['d']/1000:.0f}km×{best['N']:.0f}個 群れの半径 {best['Rc']/1000:.0f}km 口は島の {best['dh']/1000:.0f}km 上"
                          f"（外側のひもは 水平/鉛直 = {ratio:.1f}） 水素 {best['gas']/1e3:.3g}t")
                else:
                    print(f"  {name}・{tag}・安全率{sf}: 解なし")

    s = sols["軽い"]
    b = s["b"]
    D = s["D"]
    print("== 軽い島・袋1つ: 膜の強さ")
    dp = b["dp_top"]
    T_lobe = dp * LOBE_R
    for sg in FILM_SIGMA:
        cap = sg * FILM_T
        print(f"  てっぺんの圧力差 {dp:.0f}Pa（1m2 に {dp/G0/1e3:.1f}t 分）。帯の間でふくらむ膜(半径{LOBE_R}m)の張力 {T_lobe/1e3:.0f}kN/m。"
              f" 0.02mm・{sg/1e6:.0f}MPa の膜は {cap:.0f}N/m まで → {T_lobe/cap:.0f}倍足りない")
    print(f"  要る厚さ(安全率2、{FILM_SIGMA[0]/1e6:.0f}MPa): {s['t']*1000:.1f}mm、膜 {s['film']/1e3:.3g}t（島の {s['film']/ISLANDS['軽い']*100:.1f}%）")
    thin = bag(D, n=200)
    print(f"  0.02mm のままなら膜は {thin['area']*FILM_T*FILM_RHO/1e3:.3g}t")

    print("== 軽い島・袋1つ: 風")
    for v in WIND:
        for cd in CD:
            F = 0.5 * v * v * cd * b["rho_proj"]
            print(f"  風{v:.0f}m/s(時速{v*3.6:.0f}km) Cd{cd}: 横の力 {F/G0/1e3:.3g}t重（島の {F/G0/ISLANDS['軽い']*100:.2f}%）")

    print("== 軽い島・袋1つ: 水素の抜け")
    pm = b["p_mean"]
    for P in H2_PERM:
        for t_ in (FILM_T, s["t"]):
            q = P * b["area"] * pm / t_
            kg_y = q * M_H2 * 3.156e7
            print(f"  透過係数 {P:.1e}・厚さ{t_*1000:.2f}mm: 1年に {kg_y/1e3:.3g}t（袋の水素の {kg_y/b['gas']*100:.3f}%、年産の {kg_y/H2_YEAR*365:.2f}日分）")

    print("== 軽い島・袋1つ: 昼と夜（袋がいっぱい、温まったガスは下の口から逃げると置く）")
    r1 = isa(BASE)[2]; r2 = isa(BASE + 100)[2]
    dlnrho = (math.log(r1) - math.log(r2)) / 100
    for dT in SUPERHEAT:
        warm = bag(D, n=200, dT=dT)
        gain = (warm["lift"] - b["lift"]) / b["lift"]
        lost = b["gas"] - warm["gas"]
        print(f"  ガスが {dT:.0f}℃ 温まる: 浮く力 +{gain*100:.2f}%（{(warm['lift']-b['lift'])/1e3:.3g}t）→ 釣り合う高さが約 {gain/dlnrho:.0f}m 上がる。"
              f"逃げる水素 {lost/1e3:.3g}t（袋の水素の {lost/b['gas']*100:.1f}%）。毎日足すと1年で {lost*365/1e3:.3g}t = 世界の年産の {lost*365/H2_YEAR:.1f}年分")
        # 直す手: 口を閉じて逃がさない（スーパープレッシャー）。中の圧力が dT/T だけ上がる
        Tm = sum(isa(BASE + b["H"] * (i + 0.5) / 50)[0] for i in range(50)) / 50
        extra = b["p_mean"] * dT / Tm
        t_new = (b["dp_top"] + extra) * LOBE_R * 2 / FILM_SIGMA[0]
        print(f"    口を閉じる: 中の圧力が {extra:.0f}Pa 上がる → 膜 {s['t']*1000:.1f}mm → {t_new*1000:.1f}mm（{(t_new/s['t']-1)*100:.0f}%増、"
              f"膜 {b['area']*t_new*FILM_RHO/1e3:.3g}t）。ガスは逃げず、体積も変わらないので浮く力は昼夜で変わらない")

    print("== 形（結末の絵）")
    print(f"  軽い島の袋: 直径 {D/1000:.1f}km、高さ {b['H']/1000:.1f}km、口 5.0km・てっぺん {(BASE+b['H'])/1000:.1f}km、島の幅1.6kmの {D/1600:.1f}倍")
    print(f"  重さの積み上げ: 膜 {s['film']/1e3:.3g}t → 帯 {s['struct']/1e3:.3g}t → ひも {s['rope']/1e3:.3g}t（島 {ISLANDS['軽い']/1e3:.3g}t）")


if __name__ == "__main__":
    main()

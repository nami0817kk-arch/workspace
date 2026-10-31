"""8版の作戦：袋の群れ＋骨組み（2026-11-01）。

python -X utf8 episodes/laputa/sim/frame.py

形：直径 d_b の袋（NASA と同じ形）を、半径 R の円の中に敷き詰める（1個あたり d_b×d_b）。袋の口は島の d 上。
島から各袋へ、漏斗のようにひもを張る（7版の「袋を並べる」と同じ）。
7版はここで止まった：ひもが斜めに袋を内側へ引き、袋が寄せ集められてつり合わない。
8版はその横の力を、袋どうしの間に張った「押されても縮まない骨組み」（放射状の突っ張り棒＋輪）で受ける。

つり合い
- 上下：袋の浮く力の合計 = 島 + ひも + 骨組み + 袋の膜と帯（袋1個の浮く力は deep.bag で高さごとに積分）
- 横：ひもの横の力が半径 r より外で合計 F(r) = (2π q g /(3d))(R³ − r³) だけ内向きにかかる。
  それを半径 r の円の上の突っ張り棒が押し返す。骨組みの材料の重さ = 安全率 × 座屈の係数 × ∫F(r)dr ÷（押す強さ/密度）
  = SF × BUCKLE × W g R² /(2 d σc/ρ)  （W は袋の群れが島へ渡す重さ、q = W/(πR²)）
- 浮く力は、口より上の空気の重さ × 影の面積 を超えない（コードで確かめる）
置いた値：骨組みは炭素繊維の複合材（押す強さ 1GPa・密度 1.6g/cm³ と置く）、座屈で材料が2倍要ると置く、安全率2。
ひもはケブラー（3.45GPa・1.44g/cm³）・安全率2・厳しめ（各袋への全荷重をひもの全長で背負う）。
袋の膜はポリエチレン 25MPa・安全率2、帯は ∫Δp dV ÷（強さ/密度）× 3（deep.py と同じ）。
"""
import math
import deep

G0 = deep.G0
KEV = deep.KEVLAR
SF = 2.0
CF = 1.0e9 / 1600.0     # 炭素繊維複合材の 押す強さ/密度（置く）
BUCKLE = 2.0            # 座屈を防ぐために材料が2倍要ると置く
H2_YEAR = 100e9
_cache = {}


def one_bag(db, zb):
    key = (db, round(zb, -1))
    if key not in _cache:
        old = deep.BASE
        deep.BASE = zb
        b = deep.bag(db, n=80, base=zb)
        deep.BASE = old
        t = max(deep.FILM_T, b["dp_top"] * deep.LOBE_R * 2 / deep.FILM_SIGMA[0])
        film = b["area"] * t * deep.FILM_RHO
        tape = b["dpdv"] * 3.0 / KEV
        _cache[key] = (b, t, film, tape)
    return _cache[key]


def design(M, z_island, R, d, db):
    zb = z_island + d
    b, t, film, tape = one_bag(db, zb)
    N = math.pi * R * R / (db * db)
    lift = N * b["lift"]
    bagmass = N * (film + tape)
    k = SF * G0 * (R * R / 2 + d * d) / (d * KEV)        # ひもの重さ/吊る重さ（厳しめ）
    g_frame = SF * BUCKLE * G0 * R * R / (2 * d * CF)    # 骨組みの重さ/袋の群れが渡す重さ
    if k + g_frame >= 1:
        return None
    # 袋の群れが渡す重さ W = 島 + ひも + 骨組み → W = M/(1 − k − g)
    W = M / (1 - k - g_frame)
    need = W + bagmass
    col = deep.isa(zb)[1] / G0 * math.pi * R * R
    return dict(M=M, z=z_island, R=R, d=d, db=db, zb=zb, N=N, lift=lift, need=need, ok=lift >= need,
                rope=k * W, frame=g_frame * W, bags=bagmass, film=N * film, tape=N * tape, t=t,
                gas=N * b["gas"], col=col, H=b["H"], k=k, g=g_frame,
                Hside=W * G0 * (2 * R / 3) / d)


def best(M, z):
    out = None
    for R in [x * 1000.0 for x in range(3, 61)]:
        for frac in (0.3, 0.5, 0.7, 1.0, 1.4, 2.0):
            d = R * frac
            for db in (2000.0, 3000.0, 5000.0, 7000.0, 9000.0, 12000.0, 15000.0):
                r = design(M, z, R, d, db)
                if r and r["ok"]:
                    assert r["lift"] <= r["col"] * 1.0001
                    if out is None or r["gas"] < out["gas"]:
                        out = r
    return out


def show(name, r):
    print(f"  {name}: 群れの直径 {2*r['R']/1e3:.0f}km、袋 直径{r['db']/1e3:.1f}km(高さ{r['H']/1e3:.2f}km)×{r['N']:.0f}個、袋の口は島の{r['d']/1e3:.1f}km上（{r['zb']/1e3:.1f}km）")
    print(f"     浮く力 {r['lift']/1e3:.3g}t（上限 {r['col']/1e3:.3g}t の {r['lift']/r['col']*100:.0f}%） 水素 {r['gas']/1e3:.3g}t（{r['gas']/H2_YEAR:.2f}年分）")
    print(f"     島 {r['M']/1e3:.3g}t ひも {r['rope']/1e3:.3g}t 骨組み {r['frame']/1e3:.3g}t 袋の膜 {r['film']/1e3:.3g}t({r['t']*1e3:.2f}mm) 袋の帯 {r['tape']/1e3:.3g}t"
          f" ／ ひもの横の力 {r['Hside']/G0/1e3:.3g}t重（島の {r['Hside']/G0/r['M']:.1f}倍）")


def main():
    islands = {"軽い": 2.92e11, "真ん中": 1.74e12, "重い": 4.83e12}
    for z in (5000.0, 3000.0, 2000.0, 1000.0, 500.0):
        print(f"== 島の高さ {z:.0f}m")
        for name, M in islands.items():
            r = best(M, z)
            if r:
                show(name, r)
            else:
                print(f"  {name}: 解なし")


if __name__ == "__main__":
    main()

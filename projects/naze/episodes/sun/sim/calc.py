"""太陽にゴミの回の数字。python episodes/sun/sim/calc.py > episodes/sun/sim/calc.txt
もとの値: 太陽の GM・1天文単位・太陽の半径(NASA Sun Fact Sheet)、地球の GM と半径(NASA Earth Fact Sheet)。式は vis-viva とロケットの式。"""
import math

GM = 1.32712440018e20          # 太陽 m3/s2
AU = 1.495978707e11            # m
RS = 6.957e8                   # 太陽の半径 m
MU = 3.986004418e14            # 地球 m3/s2
RE = 6.378137e6
LEO = RE + 300e3               # 高さ300kmの低い軌道


def v_at(r, a):
    return math.sqrt(GM * (2 / r - 1 / a))


def from_leo(vinf):
    """地球の重力を抜けたあとに vinf が残るように、低い軌道から足す速さ。"""
    return math.sqrt(vinf ** 2 + 2 * MU / LEO) - math.sqrt(MU / LEO)


v_e = math.sqrt(GM / AU)
v_esc = math.sqrt(2 * GM / AU)
print(f"地球の公転の速さ {v_e/1e3:.2f} km/s = 時速 {v_e*3.6:,.0f} km（新幹線 時速320km の {v_e*3.6/320:.0f} 倍）")
print(f"  東京→大阪 400km を {400e3/v_e:.1f} 秒")
print(f"太陽までの距離 {AU/1e9:.1f} 百万km。新幹線で {AU/1e3/320/24/365.25:.0f} 年、光で {AU/299792458/60:.1f} 分")
print(f"太陽の直径 {2*RS/1e3:,.0f} km = 地球 {RS/RE:.0f} 個ぶん")
print(f"地球から見た太陽の見かけの大きさ {math.degrees(2*RS/AU):.2f} 度")
print()
print("横向きの速さを少しずつ消すと、太陽にいちばん近づく所はどこまで下がるか")
for dv in (0, 5, 10, 15, 20, 25, 26.92, 29.78):
    v = v_e - dv * 1e3
    if v <= 0:
        print(f"  {dv:>5} km/s 消す → まっすぐ落ちる"); continue
    a = 1 / (2 / AU - v * v / GM)
    rp = 2 * a - AU
    print(f"  {dv:>5} km/s 消す → 近日点 {rp/1e9:7.1f} 百万km（{rp/AU:.3f} 天文単位、太陽の半径の {rp/RS:.1f} 倍）")
print("  （水星の軌道は 0.387 天文単位、金星は 0.723）")
a = (AU + RS) / 2
dv_sun = v_e - v_at(AU, a)
dv_out = v_esc - v_e
print(f"太陽の表面に届かせる: {dv_sun/1e3:.2f} km/s 減らす／太陽系の外へ: {dv_out/1e3:.2f} km/s 足す → {dv_sun/dv_out:.2f} 倍")
T = 2 * math.pi * math.sqrt(AU ** 3 / GM)
print(f"速さを全部消したら、太陽まで落ちるのに {T/(4*math.sqrt(2))/86400:.1f} 日")
print()
ve = 4.4e3                     # 液体水素と液体酸素のエンジンの噴き出す速さ(比推力 約450秒)
print("低い軌道(高さ300km)から出るときに要る速さと、ロケットの式(噴き出す速さ 4.4km/s)での重さの比")
for name, vinf in (("月へ向かう", None), ("太陽系の外へ", dv_out), ("太陽へ", dv_sun)):
    d = 3.13e3 if vinf is None else from_leo(vinf)
    print(f"  {name}: {d/1e3:.2f} km/s → 出発の重さは届く重さの {math.exp(d/ve):.1f} 倍")
r_sun, r_out = math.exp(from_leo(dv_sun) / ve), math.exp(from_leo(dv_out) / ve)
sat = 118.0                    # サターンV が低い軌道へ運べる重さ t (NASA)
can = 0.5                      # ガラス固化体 1 本 t
print(f"サターンV(低い軌道へ {sat:.0f}t)1機で: 太陽へ {sat/r_sun:.2f}t = 固化体 {sat/r_sun/can:.1f} 本／外へ {sat/r_out:.1f}t = {sat/r_out/can:.0f} 本（タンクや段の重さは入れていない、いちばん甘い見積もり）")
for n in (2500, 28000):
    print(f"  固化体 {n:,} 本 → 太陽へ {n/(sat/r_sun/can):,.0f} 機／外へ {n/(sat/r_out/can):,.0f} 機")
print()
print("遠回り: いったん木星の距離(5.2天文単位)まで行ってから、そこで速さを消す")
rj = 5.2 * AU
a1 = (AU + rj) / 2
d1 = from_leo(v_at(AU, a1) - v_e)
va = v_at(rj, a1)
d2 = va - v_at(rj, (rj + RS) / 2)
print(f"  出発 {d1/1e3:.2f} km/s、木星の距離での速さ {va/1e3:.2f} km/s、そこで消す {d2/1e3:.2f} km/s → 合計 {(d1+d2)/1e3:.2f} km/s（まっすぐ行く {from_leo(dv_sun)/1e3:.2f} km/s の {(d1+d2)/from_leo(dv_sun)*100:.0f}%）")
print(f"  木星の距離までの片道 {math.pi*math.sqrt(a1**3/GM)/86400/365.25:.1f} 年、そこから太陽まで {math.pi*math.sqrt(((rj+RS)/2)**3/GM)/86400/365.25:.1f} 年")
print()
print(f"打ち上げ 2024年: 261回のうち失敗6・部分失敗2 → {8/261*100:.1f}%（失敗だけなら {6/261*100:.1f}%）。14,000機なら {14000*6/261:.0f} 回")
print()
print("太陽へまっすぐ撃つ（地球の重力を抜けたあと、太陽の向きに足す。横の速さはそのまま）")
for vr in (10, 20, 27, 40):
    v2 = (vr * 1e3) ** 2 + v_e ** 2
    a = 1 / (2 / AU - v2 / GM)
    e = math.sqrt(1 - AU / a)       # 角運動量は地球と同じなので p = 1 天文単位
    print(f"  秒速{vr}km → いちばん近づく所 {AU/(1+e)/AU:.2f} 天文単位" + ("" if a < 0 else f"、いちばん遠い所 {AU/(1-e)/AU:.2f} 天文単位"))
print("  （金星の道 0.72・水星の道 0.39 天文単位）")
print()
yen_per_launch = 995e6 * 150     # サターンV 1回 1億8,500万ドル(1969〜71年)= 2024年のドルで約9億9,500万ドル、1ドル150円
n = 2500 / (sat / r_sun / can)
print(f"費用: サターンV 1回 約{yen_per_launch/1e8:,.0f}億円 × {n:,.0f}機 = 約{yen_per_launch*n/1e12:,.0f}兆円"
      f"（地下に埋める計画は 4万本ぶんで約4.7兆円 → {yen_per_launch*n/4.7e12:.0f}倍）")

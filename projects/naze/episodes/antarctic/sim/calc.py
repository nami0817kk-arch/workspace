"""南極の氷が全部とけたら: 本編・ショートの数字を自分で計算する。python episodes/antarctic/sim/calc.py → sim/calc.txt
氷の厚さは ETOPO 2022 (NOAA NCEI, 60 秒、Ice Surface と Bedrock の差) を 3 分(0.05 度)おきに使う(cache/etopo/*.npy)。
密度: 氷 917 kg/m3、海水 1027 kg/m3、真水 1000 kg/m3。海の広さ 3.618 億 km2 (NOAA の値)。氷がとける熱 334 kJ/kg。
太陽の光 1,361 W/m2 (Kopp & Lean 2011)。地球の半径 6,371 km。地球にたまる熱 0.76 W/m2 (von Schuckmann ほか 2023、2006〜2020 年)。"""
import math
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[3]
E = ROOT / "cache" / "etopo"
out = []


def p(*a):
    s = " ".join(str(x) for x in a)
    print(s)
    out.append(s)


RI, RW, RF = 917.0, 1027.0, 1000.0
A_OCEAN = 3.618e14
sur = np.load(E / "ant_sur.npy").astype(np.float64)
bed = np.load(E / "ant_bed.npy").astype(np.float64)
lat = -55.075 - 0.05 * np.arange(sur.shape[0])          # 上が北
cell = (0.05 * 111320.0) ** 2 * np.cos(np.radians(lat))[:, None]
south = (lat < -60)[:, None] * np.ones_like(sur, bool)   # 南緯60度より南だけ
Hc = np.where(south, np.clip(sur - bed, 0, None), 0)
ice = Hc > 1
vol = (Hc * cell).sum()
p(f"氷の広さ {(ice * cell).sum() / 1e12:.2f} 百万km2、体積 {vol / 1e15:.2f} 百万km3、平均の厚さ {Hc[ice].mean():.0f} m、最大 {Hc.max():.0f} m")
floating = ice & (bed < 0) & (Hc * RI < -bed * RW)
p(f"海に浮かぶ氷(棚氷) {(floating * cell).sum() / 1e12:.2f} 百万km2、体積 {(Hc * cell * floating).sum() / 1e15:.2f} 百万km3")
below = ice & (bed < 0) & ~floating
p(f"地面に乗った氷のうち、岩盤が海面より下の広さ {(below * cell).sum() / 1e12:.2f} 百万km2(地面に乗った氷の {(below * cell).sum() / ((ice & ~floating) * cell).sum() * 100:.0f}%)")
p(f"いちばん低い岩盤 {bed[ice].min():.0f} m")
# 単純な割り算: 全部の氷を水にして、いまの海の広さで割る
naive = vol * RI / RF / A_OCEAN
p(f"単純に、全部の氷を水にして海の広さで割ると {naive:.1f} m")
# 海面を押し上げる分: 浮いている分と、海面より下で海水を押しのけている分を引く(浮く高さを超えた分だけ)
vaf = np.where(bed >= 0, Hc, Hc + (RW / RI) * bed)
vaf = np.where(ice, np.clip(vaf, 0, None), 0)
sle = (vaf * cell).sum() * RI / RF / A_OCEAN             # とけた水は真水
p(f"海面より上に出ている分(浮く高さを超えた分)だけで計算すると {sle:.1f} m (Bedmap3 は 58 m)")
p(f"差の内訳: 浮いている氷 {(Hc * cell * floating).sum() * RI / RF / A_OCEAN:.1f} m ぶん、海面より下の氷 {naive - sle - (Hc * cell * floating).sum() * RI / RF / A_OCEAN:.1f} m ぶん")
# 重さとエネルギー
M = vol * RI
p(f"氷の重さ {M:.3e} kg = {M / 1e12:.0f} 兆トン")
Q = M * 334e3
p(f"とかす熱 {Q:.2e} J")
R = 6.371e6
sun = 1361 * math.pi * R ** 2
p(f"地球が受ける太陽の光 {sun:.3e} W → 全部使っても {Q / sun / 86400 / 365.25:.2f} 年")
imb = 0.76 * 4 * math.pi * R ** 2
p(f"地球にたまっている熱 {imb:.2e} W → 全部を氷に回しても {Q / imb / 86400 / 365.25:.0f} 年")
# 1 年に 1 億 5 千万トン(=150 Gt)とけるとしたら
p(f"いまの速さ(IMBIE 2018: 2012〜2017年に1年2,190億トン)なら {M / 2.19e14:.0f} 年")
# 浮いている氷がとけても海面がほぼ変わらない(アルキメデス): 真水と海水の差だけ
fl_m = (Hc * cell * floating).sum() * RI
p(f"棚氷がとけたときの上がり(真水と海水の重さの差だけ) {fl_m * (1 / RF - 1 / RW) / A_OCEAN * 100:.1f} cm")
(Path(__file__).with_name("calc.txt")).write_text("\n".join(out) + "\n", encoding="utf-8")

"""海の水を抜く回の数字。ETOPO 2022 (60 秒の Ice Surface を 0.1 度おき、cache/etopo/world_sur.npy) で自分で計算する。
海 = 海面(0m)より低く、外の海とつながっている所(カスピ海・死海などは外す)。面積は球の上のマス目の広さ(半径 6,371km)。
python episodes/drain/sim/calc.py → calc.txt"""
from pathlib import Path

import numpy as np
from scipy import ndimage

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
z = np.load(ROOT / "cache" / "etopo" / "world_sur.npy")
NY, NX = z.shape
lat = 90 - (np.arange(NY) + 0.5) * 180 / NY
R = 6371.0
cell = (np.radians(180 / NY) * R) * (np.radians(360 / NX) * R) * np.cos(np.radians(lat))[:, None] * np.ones((1, NX))   # km2
lines = []


def p(s):
    print(s)
    lines.append(s)


def ij(lon, la):
    return int((90 - la) / 180 * NY), int((lon + 180) / 360 * NX) % NX


def label(mask):
    """東西をつないで(日付変更線をまたいで)連結成分を数える。"""
    lab, n = ndimage.label(np.concatenate([mask, mask[:, :1]], axis=1))
    a, b = lab[:, 0], lab[:, -1]                               # 左端と右端の同じ所を同じ番号に
    for u, v in set(zip(a[a > 0], b[b > 0])):
        if u != v:
            lab[lab == v] = u
    return lab[:, :-1]


below = z < 0
lab = label(below)
main = lab[ij(-150, 0)]
ocean = lab == main
A = cell[ocean].sum()
V = (-z * cell)[ocean].sum() / 1000                           # km3 (深さは m)
p(f"海の広さ {A / 1e6:.1f} 百万km2 / 地球の表面の {A / (4 * np.pi * R * R) * 100:.1f}%")
p(f"海の水の量 {V / 1e9:.3f} 十億km3 / 平均の深さ {V / A * 1000:.0f} m")
p(f"一番深い所(0.1度おき) {-z[ocean].min():.0f} m  位置 {np.unravel_index(np.argmin(np.where(ocean, z, 0)), z.shape)}")
p(f"海の水を全部積むと(陸地の上に) {V / (4 * np.pi * R * R - A) :.2f} km の厚さ")
p(f"球にすると直径 {2 * (3 * V / (4 * np.pi)) ** (1 / 3):.0f} km")
p("")
p("海面を下げたとき、出てくる海の底の広さ(合計)と、そのとき残る水")
for L in (50, 100, 120, 130, 200, 500, 1000, 2000, 3000, 4000, 5000, 6000, 7000, 8000, 9000, 10000):
    ex = ocean & (z > -L)
    left = ocean & (z <= -L)
    vl = ((-z - L) * cell)[left].sum() / 1000
    p(f"-{L:>5} m: 出てくる底 {cell[ex].sum() / 1e6:6.1f} 百万km2 ({cell[ex].sum() / A * 100:4.1f}%) / 残る水 {vl / V * 100:5.1f}% / 残る海の広さ {cell[left].sum() / 1e6:6.1f}")
p("")
p("深さの割合(海の広さのうち)")
for d0, d1 in ((0, 200), (200, 1000), (1000, 3000), (3000, 4000), (4000, 5000), (5000, 6000), (6000, 12000)):
    m = ocean & (-z >= d0) & (-z < d1)
    p(f"  {d0:>5}〜{d1:>5} m: {cell[m].sum() / A * 100:4.1f}%")
p("")
p("2 つの海が切れる深さ(0.1度おきの格子で。細い海峡は浅く・深く出ることがある)")
PAIRS = [("日本海", (135, 40), "太平洋", (150, 30)), ("地中海", (18, 35), "大西洋", (-30, 35)),
         ("北極海", (-170, 80), "太平洋(ベーリング)", (-175, 50)), ("北海", (3, 56), "大西洋(英国の西)", (-20, 52)),
         ("黒海", (34, 43), "地中海", (18, 35)), ("紅海", (38, 20), "インド洋", (65, 10)),
         ("ペルシャ湾", (51, 27), "インド洋", (65, 10)), ("大西洋", (-30, 0), "太平洋", (-150, 0)),
         ("大西洋", (-30, 0), "インド洋", (80, -20)), ("太平洋", (-150, 0), "インド洋", (80, -20))]
for n1, a, n2, b in PAIRS:
    lo, hi = 0, 11000
    while hi - lo > 5:
        mid = (lo + hi) / 2
        lb = label(z < -mid)
        if lb[ij(*a)] and lb[ij(*a)] == lb[ij(*b)]:
            lo = mid
        else:
            hi = mid
    p(f"  {n1} と {n2}: 海面を {lo:.0f} m 下げると切れる")
(HERE / "calc.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")

p("")
p("陸がつながる深さ(海面をどれだけ下げると、歩いて渡れるか)")
LAND = [("本州", (138, 36), "朝鮮半島", (127.5, 37)), ("本州", (138, 36), "北海道", (143, 43.5)), ("北海道", (143, 43.5), "サハリン", (142.7, 50)),
        ("九州", (131, 32.5), "朝鮮半島", (127.5, 37)), ("イギリス", (-2, 53), "フランス", (2, 47)), ("アラスカ", (-150, 64), "シベリア", (170, 66)),
        ("スマトラ", (102, -1), "マレー半島", (102, 4)), ("ボルネオ", (114, 1), "マレー半島", (102, 4)), ("オーストラリア", (135, -25), "ニューギニア", (142, -5)),
        ("スリランカ", (80.7, 7.8), "インド", (78, 15)), ("台湾", (121, 23.7), "中国", (114, 27)), ("沖縄本島", (127.9, 26.5), "九州", (131, 32.5))]
for n1, a, n2, b in LAND:
    lo, hi = 0, 3000
    while hi - lo > 2:
        mid = (lo + hi) / 2
        lb = label(z > -mid)
        if lb[ij(*a)] and lb[ij(*a)] == lb[ij(*b)]:
            hi = mid
        else:
            lo = mid
    p(f"  {n1} と {n2}: 海面を {hi:.0f} m 下げるとつながる")
jm = (lab == lab[ij(135, 40)])
r0, r1 = ij(128, 52)[0], ij(128, 33)[0]
c0, c1 = ij(127, 0)[1], ij(143, 0)[1]
sub = z[r0:r1, c0:c1]
p(f"日本海の一番深い所(0.1度おき) {-sub.min():.0f} m")
p(f"陸の広さ {(4 * np.pi * R * R - A) / 1e6:.1f} 百万km2 / 海は陸の {A / (4 * np.pi * R * R - A):.2f} 倍")
(HERE / "calc.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")

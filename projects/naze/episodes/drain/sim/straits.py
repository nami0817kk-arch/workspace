"""海峡の深さは 0.1 度おきでは粗いので、ETOPO 2022 の 60 秒(1 分)をそのまま切り出して確かめる。python episodes/drain/sim/straits.py → straits.txt"""
import urllib.request
from pathlib import Path

import numpy as np
from scipy import ndimage

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
C = ROOT / "cache" / "etopo"
BASE = "https://www.ngdc.noaa.gov/thredds/dodsC/global/ETOPO2022/60s/60s_surface_elev_netcdf/ETOPO_2022_v1_60s_N90W180_surface.nc.dods?"


def window(name, lon0, lon1, lat0, lat1):
    f = C / f"win_{name}.npy"
    if f.exists():
        return np.load(f)
    # 行 0 が南(-90)。確かめた: 0.1度の取得で lat[0] が南だった
    i0, i1 = int((lat0 + 90) * 60), int((lat1 + 90) * 60)
    j0, j1 = int((lon0 + 180) * 60), int((lon1 + 180) * 60)
    raw = urllib.request.urlopen(BASE + f"z%5B{i0}:1:{i1}%5D%5B{j0}:1:{j1}%5D", timeout=600).read()
    b = raw[raw.index(b"\nData:\n") + 7:]
    n = int.from_bytes(b[:4], "big")
    z = np.frombuffer(b, ">f4", n, 8).reshape(i1 - i0 + 1, j1 - j0 + 1)[::-1].astype(np.float32)   # 北を上に
    np.save(f, z)
    return z


def link(z, a, b, land, box):
    lon0, lon1, lat0, lat1 = box
    def ij(p):
        return int((lat1 - p[1]) * 60), int((p[0] - lon0) * 60)
    lo, hi = 0.0, 3000.0
    while hi - lo > 1:
        mid = (lo + hi) / 2
        m = (z > -mid) if land else (z < -mid)
        lab, _ = ndimage.label(m)
        ok = lab[ij(a)] and lab[ij(a)] == lab[ij(b)]
        if land:
            hi, lo = (mid, lo) if ok else (hi, mid)
        else:
            lo, hi = (mid, hi) if ok else (lo, mid)
    return hi if land else lo


out = []
JP = (124, 147, 30, 53)
z = window("jp", *JP)
for n1, a, n2, b in [("九州", (131, 32.5), "朝鮮半島", (127.5, 36.5)), ("本州", (139, 36.5), "北海道", (143, 43.5)),
                     ("北海道", (143, 43.5), "サハリン", (142.7, 50)), ("サハリン", (142.7, 50), "大陸", (136, 50))]:
    out.append(f"{n1} と {n2}: 海面を {link(z, a, b, True, JP):.0f} m 下げるとつながる")
for n1, a, n2, b in [("日本海", (135, 40), "東シナ海", (126, 31)), ("日本海", (135, 40), "太平洋(津軽)", (145, 40)),
                     ("日本海", (135, 40), "オホーツク海", (146, 47))]:
    out.append(f"{n1} と {n2}: 海面を {link(z, a, b, False, JP):.0f} m 下げると切れる")
jm, _ = ndimage.label(z < -150)
r, c = int((53 - 40) * 60), int((135 - 124) * 60)
out.append(f"日本海の一番深い所 {-z[jm == jm[r, c]].min():.0f} m")
BR = (-180 + 0.01, -155, 58, 72)
z = window("br", *BR)
out.append(f"アラスカ と シベリア(東経 180 度の東側だけ): 海面を {link(z, (-160, 66), (-172, 65.5), True, BR):.0f} m 下げるとつながる")
GB = (-8, 5, 47, 56)
z = window("gb", *GB)
out.append(f"イギリス と フランス: 海面を {link(z, (-1.5, 52.5), (2.5, 49), True, GB):.0f} m 下げるとつながる")
GI = (-8, -3, 34.5, 37.5)
z = window("gi", *GI)
out.append(f"地中海 と 大西洋(ジブラルタル): 海面を {link(z, (-3.5, 36), (-7.5, 36), False, GI):.0f} m 下げると切れる")
(HERE / "straits.txt").write_text("\n".join(out) + "\n", encoding="utf-8")
print("\n".join(out))

MA = (141.5, 143.5, 10.5, 12.5)
z = window("ma", *MA)
i, j = np.unravel_index(np.argmin(z), z.shape)
la, lo = MA[3] - i / 60, MA[0] + j / 60
import math
def gc(a, b):
    la1, lo1, la2, lo2 = map(math.radians, (a[1], a[0], b[1], b[0]))
    return 6371 * math.acos(math.sin(la1) * math.sin(la2) + math.cos(la1) * math.cos(la2) * math.cos(lo2 - lo1))
out.append(f"マリアナ海溝の一番深い所(ETOPO 60秒) {-z.min():.0f} m  位置 北緯{la:.2f} 東経{lo:.2f}  東京から {gc((139.75, 35.69), (lo, la)):.0f} km")
out.append(f"エベレスト 8,849 m を沈めると上に {-z.min() - 8849:.0f} m")
(HERE / "straits.txt").write_text("\n".join(out) + "\n", encoding="utf-8")
print(out[-2]); print(out[-1])

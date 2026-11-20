"""海面が 58 m 上がったら、どの陸が海につながって沈むか(Terrain Tiles z5、南緯60〜北緯84)と、大きな都市の中心の高さ(z12 の点)。
python episodes/antarctic/sim/flood.py → sim/flood.txt・sim/fill_z5.npz(海につながる高さ = その場所が沈み始める海面)
沈むのは「海から低い所を伝ってつながる陸」だけ(バスタブのように、くぼ地だけ沈むことはない)。氷の重みが消えて陸が浮き上がる分は入れない。"""
import json
import sys
from pathlib import Path

import cv2
import numpy as np
from skimage.morphology import reconstruction

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT))
from naze import worldmap  # noqa: E402

HERE = Path(__file__).resolve().parent
BB, Z = (-180, -60, 179.99, 84), 5
PPD = 256 * 2 ** Z / 360
LEVEL = 58.0
out = []


def p(*a):
    s = " ".join(str(x) for x in a)
    print(s)
    out.append(s)


key = HERE / "fill_z5.npz"
if key.exists():
    d = np.load(key)
    e, fill = d["e"].astype(np.float32), d["fill"].astype(np.float32)
else:
    e = worldmap.heights(BB, Z, PPD).astype(np.float32)
    n, lab = cv2.connectedComponents((e <= 0).astype(np.uint8), connectivity=8)
    big = np.bincount(lab.ravel())[1:].argmax() + 1
    ocean = lab == big
    seed = np.where(ocean, e, e.max() + 1)
    seed[:, 0] = np.minimum(seed[:, 0], np.where(ocean[:, -1], e[:, 0], seed[:, 0]))
    fill = reconstruction(seed, e, method="erosion").astype(np.float32)
    np.savez_compressed(key, e=e.astype(np.int16), fill=fill.astype(np.int16))
h, w = e.shape
lat = BB[3] - (np.arange(h) + 0.5) / PPD
cell = (111.32 / PPD) ** 2 * np.cos(np.radians(lat))[:, None]
land = e > 0
for L in (10, 30, 58, 66):
    fl = land & (fill <= L)
    p(f"海面 +{L} m: 沈む陸 {(fl * cell).sum() / 1e6:.2f} 百万km2(陸の {(fl * cell).sum() / (land * cell).sum() * 100:.1f}%)")
p(f"南緯60〜北緯84の陸 {(land * cell).sum() / 1e6:.1f} 百万km2")
fl = land & (fill <= LEVEL)
JPN = 377975
p(f"58 m で沈む陸は 日本 {(fl * cell).sum() / (JPN / 1):.1f} 個ぶん(日本 37.8万km2)")


def point_h(lon, lat, z=12):
    """中心の点の高さ。z12(1 画素 約30m)の 5×5 画素の中央値(建物の高さが混じるのをならす)。"""
    n = 2 ** z
    x = (lon + 180) / 360 * n
    y = worldmap.merc_y(lat, n)
    t = worldmap.tile(z, int(x), int(y))
    i, j = min(253, max(2, int((y % 1) * 256))), min(253, max(2, int((x % 1) * 256)))
    return float(np.median(t[i - 2:i + 3, j - 2:j + 3]))


def filled_at(lon, lat):
    y, x = int((BB[3] - lat) * PPD), int((lon - BB[0]) * PPD)
    win = fill[max(0, y - 1):y + 2, max(0, x - 1):x + 2]
    return float(win.min())


g = json.loads((ROOT / "cache" / "ne" / "ne_10m_populated_places_simple.geojson").read_text(encoding="utf-8"))
cities = [f["properties"] for f in g["features"] if f["properties"]["pop_max"] >= 5_000_000]
cities.sort(key=lambda c: -c["pop_max"])
under = []
rows = []
for c in cities:
    hh = point_h(c["longitude"], c["latitude"])
    sink = hh < LEVEL                     # 500万人以上の都市は、どれも海か大きな川につながる低地にある(z5 の格子では細い川の谷がつながらないので、ここは高さだけで見る)
    rows.append((c["name"], c["adm0name"], c["pop_max"], hh, sink))
    if sink:
        under.append(c)
p(f"人口500万人以上の都市 {len(cities)} のうち、中心が 58 m より低い都市 {len(under)}")
for r in rows:
    p(f"  {'沈む' if r[4] else '残る'} {r[0]}({r[1]}) 人口 {r[2] / 1e4:.0f}万 中心の高さ {r[3]:.0f} m")
(HERE / "flood.txt").write_text("\n".join(out) + "\n", encoding="utf-8")

# 国・州のうち 58 m より低い陸の割合(z7 の高さ、Natural Earth の形で切る)
p(f"人口500万人以上で中心が 58 m より低い都市の人口の合計 {sum(c['pop_max'] for c in under) / 1e8:.2f} 億人")


def share(code, bbox, z=7):
    ppd = 256 * 2 ** z / 360
    hh = worldmap.heights(bbox, z, ppd)
    m = np.zeros(hh.shape, np.uint8)
    for r in worldmap.shapes(code):
        pts = np.array([((x - bbox[0]) * ppd, (bbox[3] - y) * ppd) for x, y in r], np.int32)
        cv2.fillPoly(m, [pts], 1)
    la = bbox[3] - (np.arange(hh.shape[0]) + 0.5) / ppd
    cw = np.cos(np.radians(la))[:, None] * np.ones_like(hh)
    land = (m > 0) & (hh > 0)
    return ((land & (hh < LEVEL)) * cw).sum() / (land * cw).sum()


for code, bb, nm in (("NLD", (3.2, 50.7, 7.3, 53.6), "オランダ"), ("BGD", (88.0, 20.5, 92.7, 26.7), "バングラデシュ"),
                     ("USA:Florida", (-87.7, 24.4, -79.9, 31.1), "フロリダ州"), ("DNK", (8.0, 54.5, 12.8, 57.8), "デンマーク")):
    p(f"{nm}: 陸の {share(code, bb) * 100:.0f}% が 58 m より低い")
(HERE / "flood.txt").write_text("\n".join(out) + "\n", encoding="utf-8")

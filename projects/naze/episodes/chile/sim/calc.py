"""チリの細長さを自分で測る。国境は Natural Earth 10m（著作権放棄の公開データ、cache/ne/ に保存）。
python episodes/chile/sim/calc.py > episodes/chile/sim/calc.txt"""
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
NE = ROOT / "cache" / "ne" / "ne_10m_admin_0_countries.geojson"
R = 6371.0


def gc(a, b):
    """2点 (緯度, 経度) の大円距離 km"""
    p1, l1, p2, l2 = map(math.radians, (a[0], a[1], b[0], b[1]))
    h = math.sin((p2 - p1) / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin((l2 - l1) / 2) ** 2
    return 2 * R * math.asin(math.sqrt(h))


def rings(name, lon_min=-180, lon_max=180):
    feats = json.loads(NE.read_text(encoding="utf-8"))["features"]
    f = next(f for f in feats if f["properties"]["ADM0_A3"] == name)
    g = f["geometry"]
    polys = g["coordinates"] if g["type"] == "MultiPolygon" else [g["coordinates"]]
    out = []
    for p in polys:
        ring = p[0]
        if all(lon_min <= x <= lon_max for x, _ in ring):
            out.append(ring)
    return out


def ring_area_km2(ring):
    # 小さな多角形として球面上の面積(近似: 各点を正距円筒に投影し、緯度ごとに cos を掛ける)
    s = 0.0
    for (x1, y1), (x2, y2) in zip(ring, ring[1:]):
        s += math.radians(x2 - x1) * (2 + math.sin(math.radians(y1)) + math.sin(math.radians(y2)))
    return abs(s) * R * R / 2


def crossings(ring, lat):
    xs = []
    for (x1, y1), (x2, y2) in zip(ring, ring[1:]):
        if (y1 <= lat < y2) or (y2 <= lat < y1):
            xs.append(x1 + (lat - y1) * (x2 - x1) / (y2 - y1))
    return xs


chl = rings("CHL", lon_min=-76)            # 本土と近くの島(イースター島・フアンフェルナンデス・サンフェリクスは除く)
pts = [(y, x) for r in chl for x, y in r]
north = max(pts)
south = min(pts)
print("北の端", north, " 南の端", south)
L = gc(north, south)
print(f"北の端から南の端まで(大円) {L:.0f} km")
area = sum(ring_area_km2(r) for r in chl)
print(f"本土と近くの島の面積 {area:,.0f} km2")

# 緯度ごとの東西の幅(陸の西端から東端まで)。南の島々は陸がとぎれるので、本土の幅は 18〜41.5 度で見る
rows = []
lat = -17.6
while lat > -55.9:
    xs = sorted(x for r in chl for x in crossings(r, lat))
    if xs:
        w = gc((lat, xs[0]), (lat, xs[-1]))
        rows.append((lat, xs[0], xs[-1], w))
    lat -= 0.05
cont = [r for r in rows if -41.5 <= r[0] <= -18.4]
mn = min(cont, key=lambda r: r[3])
mx = max(rows, key=lambda r: r[3])
avg = sum(r[3] for r in cont) / len(cont)
print(f"本土(南緯18.4〜41.5度)の幅: 平均 {avg:.0f} km、いちばん狭い所 {mn[3]:.0f} km(南緯{-mn[0]:.2f}度)")
print(f"島まで含めていちばん広い所 {mx[3]:.0f} km(南緯{-mx[0]:.2f}度)")
print(f"長さ÷平均の幅 = {L / avg:.0f} 倍")
for target in (-20, -23.65, -27, -30, -31.6, -33.45, -37, -40, -45, -50, -53):
    r = min(rows, key=lambda r: abs(r[0] - target))
    print(f"  南緯{-r[0]:.2f}度 幅 {r[3]:.0f} km")

# 日本と比べる
jpn = rings("JPN")
jp = [(y, x) for r in jpn for x, y in r]
print()
soya, hateruma = (45.5228, 141.9364), (24.0453, 123.7880)   # 宗谷岬・波照間島(国土地理院の地名の位置の読み)
print(f"宗谷岬→波照間島 {gc(soya, hateruma):.0f} km → チリはその {L / gc(soya, hateruma):.2f} 倍")
wakkanai, naha = (45.4156, 141.6731), (26.2124, 127.6809)
print(f"稚内→那覇 {gc(wakkanai, naha):.0f} km")
tokyo = (35.6812, 139.7671)
for nm, p in [("宇都宮", (36.5590, 139.8983)), ("小田原", (35.2564, 139.1550)), ("静岡", (34.9715, 138.3889)),
              ("名古屋", (35.1709, 136.8815)), ("大阪", (34.7025, 135.4959)), ("福岡(博多)", (33.5897, 130.4207))]:
    print(f"東京駅→{nm}駅 {gc(tokyo, p):.0f} km")
jarea = sum(ring_area_km2(r) for r in jpn)
print(f"日本の面積(同じ計算) {jarea:,.0f} km2 → チリはその {area / jarea:.2f} 倍")

# 山と海溝
ojos = (-27.1092, -68.5414)      # オホス・デル・サラード 6,893 m(読み)
richards = (-23.30, -71.35)      # リチャーズ海淵 8,065 m(位置は海図からの読み)
d = gc(ojos, richards)
print()
print(f"オホス・デル・サラード→リチャーズ海淵 {d:.0f} km、高さの差 {6893 + 8065:,} m")
print(f"  富士山(3,776m) {(6893 + 8065) / 3776:.1f} 個分。坂にすると {(6893 + 8065) / (d * 1000) * 100:.1f}%")
for v in (6.5, 8.0):
    print(f"  プレートが年 {v} cm 近づくと、80年で {v * 80 / 100:.1f} m、1万年で {v * 1e4 / 1e5:.2f} km、100万年で {v * 1e6 / 1e5:.0f} km")

# 北へ伸びた分(1874年の境 南緯24度 → いまの北の端)
p24 = (-24.0, -70.5)
print()
print(f"南緯24度の海岸→いまの北の端 {gc(p24, north):.0f} km(国の長さの {gc(p24, north) / L * 100:.0f}%)")
r24 = min(rows, key=lambda r: abs(r[0] + 24))
print(f"南緯24度の幅 {r24[3]:.0f} km")

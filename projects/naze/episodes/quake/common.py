"""地震のセットの共通の場面・データ(本編 ch1〜ch5・ショート s1〜s5 から使う)。出典は research.md。"""
from __future__ import annotations

import csv
from functools import lru_cache
from pathlib import Path

from naze import mapscene as M
from naze import overlay as O

HERE = Path(__file__).resolve().parent
ASSETS = HERE / "assets"
from naze.config import ASPECT  # noqa: E402

CREDIT = ("地図: Natural Earth / NOAA ETOPO1 / プレート境界 Bird(2003) / 震源 USGS" if ASPECT == "landscape"
          else "Natural Earth / ETOPO1 / Bird(2003) / USGS")
JP = "japan_m4_2014_2023"
WORLD = "world_m6_2014-2023"

# 見え方 (経度, 緯度, 横幅の度)。横長(本編)は右にパネルが出るので、地図の中心を少し東へずらす
WORLD_V = (150, 8, 300)
JAPAN_V = (140, 36, 34)
BOX_V = (139, 35, 52)
JAPAN_PANEL_V = (146, 36, 40)
TOHOKU_V = (141.8, 38.6, 10)

# 縦(ショート)の見え方
P_WORLD = (150, 15, 160)
P_JAPAN = (138.5, 36, 16)
P_TOHOKU = (141.5, 38.6, 6)


def Q(**kw) -> dict:
    return dict(kind="quakes", id=kw.pop("id", "q"), data=kw.pop("data", JP), **kw)


PLATES = dict(kind="plates", id="plates")
PLATES_FILL = dict(kind="plates", id="plates_fill", fill=True)


def plate_labels(portrait: bool = False) -> list:
    pos = {"PA": (150, 33), "PS": (138.2, 31.4), "NA": (142.6, 41.3), "EU": (128, 40)}
    if portrait:
        pos = {"PA": (143.3, 33.5), "PS": (136.6, 30.8), "NA": (142.2, 42.6), "EU": (135.4, 40.4)}
    return [dict(kind="label", id=f"pl_{g}", at_ll=pos[g], text=M.PLATE_NAME[g], color=M.PLATE_COL[g], size=40 if portrait else 46, at=0.15 + i * 0.12)
            for i, g in enumerate(("PA", "PS", "NA", "EU"))]


BOX = dict(kind="box", id="box", sw=(122, 24), ne=(150, 46))
SECTION_LINE = dict(kind="line", id="secline", a=(145.0, 38.5), b=(139.0, 38.5))
TOKYO, OSAKA = (139.767, 35.681), (135.495, 34.702)


@lru_cache(maxsize=1)
def section_pts() -> list:
    """北緯37.5〜39.5度・M4以上の震源(経度, 深さ)、2000〜2023年。東北を東西に切った断面に使う(点を増やして板の形を見やすく)。"""
    out = []
    for name in ("japan_m4_2000_2013", JP):
        with open(M.QK / f"{name}.csv", encoding="utf-8") as f:
            for r in csv.DictReader(f):
                if r["type"] == "earthquake" and 37.5 <= float(r["latitude"]) <= 39.5 and 139.0 <= float(r["longitude"]) <= 145.0:
                    out.append((float(r["longitude"]), float(r["depth"])))
    return out


def section_panel(**kw) -> dict:
    return dict(kind="section", pts=section_pts(), lon=(139.0, 145.0), dmax=200, title="北緯38度の断面（深さkm・2000〜23年）",
                trend=[(144.2, -10), (140.0, -115)], **kw)


@lru_cache(maxsize=1)
def _etopo():
    import numpy as np
    z = np.load(M.GEO / "etopo_jp.npz")
    return z["h"], float(z["lon0"]), float(z["lat1"])


def on_land(lon: float, lat: float) -> bool:
    """ETOPO1 で、その地点が陸(標高 0m より上)か。陸の地震だけを見せるのに使う。"""
    h, lon0, lat1 = _etopo()
    y, x = int(round((lat1 - lat) * 20)), int(round((lon - lon0) * 20))
    return 0 <= y < h.shape[0] and 0 <= x < h.shape[1] and h[y, x] > 0


COUNTRY_BARS = [("インド\nネシア", 119), ("パプア\nニューギニア", 106), ("チリ", 77), ("バヌアツ", 67), ("フィリ\nピン", 66), ("日本", 60)]
FELT_BARS = [("2016", 6587), ("17", 2025), ("18", 2179), ("19", 1564), ("20", 1714), ("21", 2424), ("22", 1964), ("23", 2237), ("24", 3678), ("25", 4456)]
MAG_BARS = [("M4台", 10435), ("M5台", 999), ("M6台", 81), ("M7台", 6)]

JMA_QUOTE = "「確度の高い地震の予測は\n難しいと考えられています」"
JMA_SRC = "気象庁「地震予知について」"

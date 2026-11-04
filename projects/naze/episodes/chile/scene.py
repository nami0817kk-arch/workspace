"""チリはなぜ細長いのかの画面。下地は1本のあいだ南アメリカの立体の地図1つ(naze/worldmap.py)。行の scene を描く。
地点の座標は Natural Earth の都市・国境と、地名の位置の読み(parts.py の PLACES)。"""
from __future__ import annotations

import math

from naze import shots, worldmap
from naze.config import H, W

LAND = W > H
MAP = worldmap.Map(lat0=-35, bases=[((-120, -70, 0, 20), 5), ((-96, -60, -30, 8), 6), ((-78, -57, -64, -16), 8)])
STEPS = ["1 測る", "2 東の壁", "3 西の海", "4 北", "5 南"]


def chile_rows(lats):
    """緯度ごとの、チリの陸の西の端と東の端(経度)。輪切りの線に使う。"""
    rings = [r for r in worldmap.countries()["CHL"] if all(x > -76 for x, _ in r)]
    out = []
    for lat in lats:
        xs = []
        for r in rings:
            for (x1, y1), (x2, y2) in zip(r, r[1:]):
                if (y1 <= lat < y2) or (y2 <= lat < y1):
                    xs.append(x1 + (lat - y1) * (x2 - x1) / (y2 - y1))
        if xs:
            out.append((lat, min(xs), max(xs)))
    return out


def draw(img, dr, t, ctx):
    shots.draw(img, t, ctx, MAP, steps=STEPS if LAND else None)


def sfx_for(lines_def, L):
    return shots.sfx(lines_def, L)

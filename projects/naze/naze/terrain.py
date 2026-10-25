"""標高から、地形の色(テクスチャ)・メッシュ用の高さ・地点の 3D 座標を作る。

色は標高の段(stops)で決め、周りより低い所(谷)を青に寄せ、急な斜面を少し暗くする(崖・坂が浮く)。
3D の座標は km。x は東、y は北、z は標高 × 強調倍率(exag)/1000。中心が原点。
"""
from __future__ import annotations

from typing import Dict, List, Sequence, Tuple

import numpy as np
from PIL import Image
from scipy import ndimage

from .dem import Dem

# 低地 = 青、台地・山 = 黄土〜クリーム(東京の試作の色。題材ごとに stops を替えてよい)
STOPS = [(-3, (16, 40, 70)), (1, (32, 86, 128)), (6, (46, 122, 160)), (11, (70, 150, 170)),
         (16, (150, 150, 110)), (20, (196, 160, 90)), (30, (222, 184, 110)), (45, (246, 226, 170))]
SEA = (6, 12, 26)


def clean(d: Dem) -> np.ndarray:
    """海(nan)を -1 m にし、細かいノイズを少し除いた標高。"""
    h = np.where(np.isnan(d.h), -1.0, d.h)
    return ndimage.median_filter(h, size=3)


def texture(d: Dem, stops: Sequence[Tuple[float, tuple]] = STOPS, valley: float = 0.75, valley_min: float = 9.0, slope_dark: float = 0.35) -> Image.Image:
    h = clean(d)
    sea = np.isnan(d.h)
    xs = np.array([s[0] for s in stops], float)
    col = np.stack([np.interp(h, xs, [s[1][i] for s in stops]) for i in range(3)], -1)
    if valley > 0:                                                     # 周りより低い所(谷)を青に寄せる
        locmax = ndimage.gaussian_filter(ndimage.maximum_filter(h, size=81), 20)
        k = (np.clip((locmax - h - 5) / 10, 0, 1) * (h > valley_min))[..., None] * valley
        col = col * (1 - k) + np.array([60, 140, 165], float) * k
    gy, gx = np.gradient(h, d.mpp)
    col *= (1 - np.clip(np.hypot(gx, gy) / 0.25, 0, 1) * slope_dark)[..., None]
    col[sea] = SEA
    return Image.fromarray(np.clip(col, 0, 255).astype(np.uint8))


def heights(d: Dem, step: int = 2) -> np.ndarray:
    """メッシュ用に間引いた標高(m)。"""
    return clean(d)[::step, ::step].astype(np.float32)


def world(d: Dem, lon: float, lat: float, exag: float, lift: float = 0.0) -> Tuple[List[float], float]:
    """経緯度 → 3D 座標(km)と、その地点の標高(m)。"""
    H, W = d.h.shape
    Wkm, Hkm = d.size_km
    px, py = d.pixel(lon, lat)
    h = d.height_at(lon, lat)
    hz = 0.0 if not np.isfinite(h) else max(h, 0.0)
    return [round((px / W - 0.5) * Wkm, 4), round((0.5 - py / H) * Hkm, 4), round(hz * exag / 1000 + lift, 4)], h


def points(d: Dem, pts: Dict[str, Tuple[float, float]], exag: float) -> Dict[str, dict]:
    out = {}
    for k, (lo, la) in pts.items():
        w, h = world(d, lo, la, exag)
        out[k] = dict(pos=w, h=None if not np.isfinite(h) else round(h, 1))
    return out

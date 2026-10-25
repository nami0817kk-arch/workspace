"""国土地理院の標高タイル(dem_png、DEM10B を z14 で)を取って標高の配列にする。タイルは cache/dem に残す。

標高 = RGB を 24 bit の整数 x にして、x < 2^23 なら x*0.01 m、x > 2^23 なら (x-2^24)*0.01 m、x = 2^23 は無効(海など)。
出典: https://maps.gsi.go.jp/development/demtile.html (利用時は「出典：国土地理院」を表示する)
"""
from __future__ import annotations

import math
import time
import urllib.request
from dataclasses import dataclass
from typing import Tuple

import numpy as np
from PIL import Image

from .config import CACHE


def tile_xy(lon: float, lat: float, z: int) -> Tuple[float, float]:
    n = 2 ** z
    x = (lon + 180) / 360 * n
    y = (1 - math.log(math.tan(math.radians(lat)) + 1 / math.cos(math.radians(lat))) / math.pi) / 2 * n
    return x, y


@dataclass
class Dem:
    h: np.ndarray          # 標高(m)。海・無効は nan
    mpp: float             # 1 画素の地上の長さ(m)
    x0: float              # 左上のタイル座標(z の単位)
    y0: float
    z: int

    @property
    def size_km(self) -> Tuple[float, float]:
        H, W = self.h.shape
        return W * self.mpp / 1000, H * self.mpp / 1000

    def pixel(self, lon: float, lat: float) -> Tuple[float, float]:
        x, y = tile_xy(lon, lat, self.z)
        return (x - self.x0) * 256, (y - self.y0) * 256

    def height_at(self, lon: float, lat: float, r: int = 2) -> float:
        px, py = self.pixel(lon, lat)
        a = self.h[max(0, int(py) - r):int(py) + r + 1, max(0, int(px) - r):int(px) + r + 1]
        return float(np.nanmedian(a)) if np.isfinite(a).any() else float("nan")


def load(lon0: float, lat0: float, lon1: float, lat1: float, z: int = 14) -> Dem:
    """経度 lon0〜lon1、緯度 lat0(南)〜lat1(北)の範囲。"""
    tdir = CACHE / "dem"
    tdir.mkdir(parents=True, exist_ok=True)
    x0, y0 = tile_xy(lon0, lat1, z)
    x1, y1 = tile_xy(lon1, lat0, z)
    tx0, tx1, ty0, ty1 = int(x0), int(x1), int(y0), int(y1)
    dem = np.full(((ty1 - ty0 + 1) * 256, (tx1 - tx0 + 1) * 256), np.nan, np.float32)
    for ty in range(ty0, ty1 + 1):
        for tx in range(tx0, tx1 + 1):
            p = tdir / f"{z}_{tx}_{ty}.png"
            if not p.exists():
                try:
                    p.write_bytes(urllib.request.urlopen(f"https://cyberjapandata.gsi.go.jp/xyz/dem_png/{z}/{tx}/{ty}.png", timeout=30).read())
                except Exception:
                    continue                      # 海だけのタイルは無い(404)
                time.sleep(0.15)
            a = np.asarray(Image.open(p).convert("RGB")).astype(np.int64)
            x = a[..., 0] * 65536 + a[..., 1] * 256 + a[..., 2]
            h = np.where(x < 2 ** 23, x * 0.01, (x - 2 ** 24) * 0.01).astype(np.float32)
            h[x == 2 ** 23] = np.nan
            dem[(ty - ty0) * 256:(ty - ty0 + 1) * 256, (tx - tx0) * 256:(tx - tx0 + 1) * 256] = h
    cx0, cx1 = int((x0 - tx0) * 256), int((x1 - tx0) * 256)
    cy0, cy1 = int((y0 - ty0) * 256), int((y1 - ty0) * 256)
    lat_c = (lat0 + lat1) / 2
    mpp = 40075016.686 * math.cos(math.radians(lat_c)) / (2 ** z * 256)
    return Dem(dem[cy0:cy1, cx0:cx1], mpp, x0, y0, z)

"""世界の「見えない海面」(ジオイド高)。重力の模型 EGM2008 を 5 分角の網目にしたもの(GeographicLib の配布 egm2008-5.pgm)を読む。
ファイルは cache/geoid_dl/geoids/egm2008-5.pgm(git の外)。値は楕円体(WGS84)から海面までの高さ(m)。
出典の書き方: 「重力の模型 EGM2008(米国家地理空間情報局、GeographicLib の5分角の網目)」。
"""
from functools import lru_cache
from pathlib import Path

import numpy as np

PGM = Path(__file__).resolve().parents[1] / "cache" / "geoid_dl" / "geoids" / "egm2008-5.pgm"
STEP = 5 / 60          # 度


@lru_cache(maxsize=1)
def grid():
    """(N[lat, lon], lats, lons)。lat は 90 → -90、lon は 0 → 360 未満。"""
    raw = PGM.read_bytes()
    pos, fields, off, scale = 0, [], -108.0, 0.003
    while len(fields) < 4:
        end = raw.index(b"\n", pos)
        line = raw[pos:end].decode("ascii").strip()
        pos = end + 1
        if line.startswith("#"):
            k = line[1:].split()
            if k and k[0] == "Offset":
                off = float(k[1])
            if k and k[0] == "Scale":
                scale = float(k[1])
            continue
        fields += line.split()
    w, h = int(fields[1]), int(fields[2])
    v = np.frombuffer(raw[pos:pos + w * h * 2], dtype=">u2").reshape(h, w)
    N = (off + scale * v.astype(np.float64)).astype(np.float32)
    lats = 90 - np.arange(h) * STEP
    lons = np.arange(w) * STEP
    return N, lats, lons


def at(lat, lon):
    """1 点のジオイド高(双一次補間)。"""
    N, lats, lons = grid()
    y = (90 - lat) / STEP
    x = (lon % 360) / STEP
    y0, x0 = int(np.floor(y)), int(np.floor(x))
    fy, fx = y - y0, x - x0
    x1 = (x0 + 1) % N.shape[1]
    y1 = min(y0 + 1, N.shape[0] - 1)
    a = N[y0, x0] * (1 - fx) + N[y0, x1] * fx
    b = N[y1, x0] * (1 - fx) + N[y1, x1] * fx
    return float(a * (1 - fy) + b * fy)

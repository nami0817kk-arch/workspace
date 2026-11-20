"""ETOPO 2022 (NOAA NCEI, 60 秒の Ice Surface) を 6 分(0.1 度)おきに取って cache/etopo/world_sur.npy に置く(北が上、-180〜180)。"""
import urllib.request
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "cache" / "etopo"
OUT.mkdir(parents=True, exist_ok=True)
BASE = "https://www.ngdc.noaa.gov/thredds/dodsC/global/ETOPO2022/60s/60s_surface_elev_netcdf/ETOPO_2022_v1_60s_N90W180_surface.nc.dods?"


def get(q):
    raw = urllib.request.urlopen(BASE + q, timeout=600).read()
    i = raw.index(b"\nData:\n") + 7
    return raw[:i].decode("latin1"), raw[i:]


def arrays(body, n_vars, kinds):
    out, p = [], 0
    for k in kinds:
        n = int.from_bytes(body[p:p + 4], "big"); p += 8
        a = np.frombuffer(body, dtype=">" + k, count=n, offset=p); p += n * 4
        out.append(a)
    return out


hdr, body = get("lat%5B0:6:10799%5D")
lat, = arrays(body, 1, ["f4"] if "Float32" in hdr else ["f8"])
hdr, body = get("z%5B0:6:10799%5D%5B0:6:21599%5D")
print(hdr[:400])
k = "f4" if "Float32" in hdr else ("i4" if "Int32" in hdr else "i2")
n = int.from_bytes(body[0:4], "big")
z = np.frombuffer(body, dtype=">" + k, count=n, offset=8).astype(np.float32).reshape(len(lat), -1)
if lat[0] < lat[-1]:
    z, lat = z[::-1], lat[::-1]
print(z.shape, lat[0], lat[-1], z.min(), z.max())
np.save(OUT / "world_sur.npy", z)

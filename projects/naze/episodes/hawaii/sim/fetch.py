"""ハワイ諸島の高さ(Terrain Tiles の z10、海の底まで)を 1 度 240 画素(約 460m)の格子にして cache/etopo/win_hawaii.npy に置く(北が上)。
範囲は 西経160.5〜154.7度・北緯18.8〜22.4度。断面と山の高さの計算に使う。python episodes/hawaii/sim/fetch.py"""
import sys
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT))
from naze import worldmap  # noqa: E402

HI = (-160.5, 18.8, -154.7, 22.4)
PPD = 240
if __name__ == "__main__":
    f = ROOT / "cache" / "etopo" / "win_hawaii.npy"
    z = worldmap.heights(HI, 10, PPD).astype(np.float32)
    np.save(f, z)
    print(z.shape, z.min(), z.max())
    for name, (lo, la) in {"マウナケア": (-155.468, 19.821), "マウナロア": (-155.603, 19.475), "ワイアレアレ": (-159.498, 22.074)}.items():
        i, j = int((HI[3] - la) * PPD), int((lo - HI[0]) * PPD)
        print(name, z[i - 3:i + 4, j - 3:j + 4].max())

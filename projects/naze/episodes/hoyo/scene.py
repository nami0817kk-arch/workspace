"""豊予海峡(九州と四国)の画面。青ヶ島の scene.py(立体の地図・札・数字・答えの並べ直し)をそのまま使い、
地図の下地(九州と四国の細かさ)と、断面・棒を naze/fig3d.py に差し替える。断面の海の深さは Terrain Tiles(GEBCO など)を足した。"""
import importlib.util
import sys
from pathlib import Path

import cv2
import numpy as np

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(ROOT))
from naze import dem, fig3d, worldmap  # noqa: E402

_spec = importlib.util.spec_from_file_location("aoga_scene", ROOT / "episodes" / "aogashima" / "scene.py")
base = importlib.util.module_from_spec(_spec)
sys.modules["aoga_scene"] = base
_spec.loader.exec_module(base)

# ---- 地図の下地: 西日本 → 九州と四国 → 海峡 → 海峡の両岸 -------------------------------------------------
base.MAP = worldmap.Map(lat0=33.3, bases=[((122, 24, 150, 42), 5), ((128.5, 30.0, 136.5, 36.0), 9),
                                          ((131.2, 32.6, 133.2, 34.0), 11), ((131.65, 33.05, 132.25, 33.5), 12),
                                          ((131.78, 33.17, 132.12, 33.42), 14), ((131.85, 33.22, 132.06, 33.38), 15)])
MAP = base.MAP
base.STEPS = ["1 近いのに船", "2 海の底", "3 トンネルの長さ", "4 お金", "5 調べ尽くされている"]

# ---- 断面: 国土地理院の標高 + 海の深さ(Terrain Tiles) --------------------------------------------------
SLICE_BOX = (131.86, 33.235, 132.04, 33.375)


def _merged_dem():
    D = dem.load(*SLICE_BOX, z=14)
    hh, ww = D.h.shape
    bx = (SLICE_BOX[0], SLICE_BOX[1], SLICE_BOX[2], SLICE_BOX[3])
    ppd = 256 * 2 ** 10 / 360                    # z11 以上は日本の中で国土地理院の陸の標高に替わり、海が 0m になる。海の深さは z10 まで
    b = worldmap.heights(bx, 10, ppd).astype(np.float32)
    b = cv2.resize(b, (ww, hh), interpolation=cv2.INTER_CUBIC)
    b = cv2.GaussianBlur(b, (0, 0), 6)
    b = np.minimum(b, -2.0)                      # 海の下は必ず海面より下
    D.h = np.where(np.nan_to_num(D.h, nan=0.0) > 0.05, D.h, b).astype(np.float32)   # 国土地理院の標高は、海を 0 か nan で返す
    return D


fig3d.setup(SLICE_BOX, photo_z=15, dem=_merged_dem())
base.CUSTOM.update(slice=fig3d.draw_slice, lens=fig3d.draw_lens, bars=fig3d.draw_bars)

draw, sfx_for = base.draw, base.sfx_for

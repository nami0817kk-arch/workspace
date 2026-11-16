"""屋久島の画面。青ヶ島の scene.py(立体の地図・札・数字・答えの並べ直し)をそのまま使い、
地図の下地を屋久島と種子島に、断面・棒を naze/fig3d.py に差し替える(豊予海峡の回と同じ作り。国土地理院の空中写真と標高)。"""
import importlib.util
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(ROOT))
from naze import fig3d, worldmap  # noqa: E402

_spec = importlib.util.spec_from_file_location("aoga_scene", ROOT / "episodes" / "aogashima" / "scene.py")
base = importlib.util.module_from_spec(_spec)
sys.modules["aoga_scene"] = base
_spec.loader.exec_module(base)

# ---- 地図の下地: 日本の南 → 屋久島と種子島 → 屋久島 → 山 ---------------------------------------------------
base.MAP = worldmap.Map(lat0=30.4, bases=[((122, 24, 150, 42), 5), ((126.0, 26.5, 134.5, 33.5), 8),
                                          ((130.25, 30.15, 131.15, 30.9), 11), ((130.33, 30.2, 130.7, 30.5), 13)])
MAP = base.MAP
base.STEPS = ["1 雨の島", "2 隣の島と比べる", "3 空気を押し上げる", "4 雨の行方", "5 答え"]

SLICE_BOX = (130.45, 30.22, 130.56, 30.48)
fig3d.setup(SLICE_BOX, photo_z=14)
base.CUSTOM.update(slice=fig3d.draw_slice, lens=fig3d.draw_lens, bars=fig3d.draw_bars)

draw, sfx_for = base.draw, base.sfx_for

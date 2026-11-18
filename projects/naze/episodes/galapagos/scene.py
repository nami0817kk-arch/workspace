"""ガラパゴスの画面。アマゾン川の回の scene.py を写した。青ヶ島の scene.py(立体の地図・札・数字・答えの並べ直し)をそのまま使い、
地図の下地をアマゾン川の流域に、棒を naze/fig3d.py に差し替える。昔の岸は sim/shores.json(標高データの等高線)を、地図の area の層で塗る。
断面(fig3d の slice)は国土地理院の写真を使うので日本の外では使わない。湖の深さは棒で見せる。"""
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

# ---- 地図の下地: 中央アジア → アラル海 → 湖のまわり --------------------------------------------------------
base.MAP = worldmap.Map(lat0=-0.5, bases=[((-100, -16, -72, 10), 5), ((-94, -4, -78, 3), 7), ((-92.4, -1.8, -88.8, 0.9), 9), ((-91.9, -1.2, -90.7, 0.4), 11)])
MAP = base.MAP
base.STEPS = ["1 ここだけの生き物", "2 930kmの海", "3 海の底の火山", "4 赤道の冷たい海", "5 島ごとに違う"]
base.CUSTOM.update(bars=fig3d.draw_bars)

draw, sfx_for = base.draw, base.sfx_for

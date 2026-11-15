"""アラル海の画面。青ヶ島の scene.py(立体の地図・札・数字・答えの並べ直し)をそのまま使い、
地図の下地を中央アジアに、棒を naze/fig3d.py に差し替える。昔の岸は sim/shores.json(標高データの等高線)を、地図の area の層で塗る。
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
base.MAP = worldmap.Map(lat0=45.0, bases=[((48, 33, 80, 50), 6), ((56.0, 42.0, 64.0, 48.0), 8), ((57.4, 43.0, 62.6, 47.2), 9)])
MAP = base.MAP
base.STEPS = ["1 消えた湖", "2 出口のない湖", "3 川の水の行方", "4 干上がった底", "5 広さの答え"]
base.CUSTOM.update(bars=fig3d.draw_bars)

draw, sfx_for = base.draw, base.sfx_for

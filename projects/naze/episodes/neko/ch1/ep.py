"""猫の回 ch1。台本と画面は ../lines.py。"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from lines import draw_twist, draw_nycurve, draw_bias, ep_for  # noqa: E402,F401

aspect="landscape"  # __main__ が縦横を判定するための印
EP = ep_for("ch1")

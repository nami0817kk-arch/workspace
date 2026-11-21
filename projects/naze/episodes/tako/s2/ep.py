"""タコの回 s2。台本と画面は ../lines.py(台本の正は ../台本.md)。"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from lines import draw_hearts, ep_for  # noqa: E402,F401

# 縦(ショート)
EP = ep_for("s2")

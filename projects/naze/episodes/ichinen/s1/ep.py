"""1年の回 s1。台本と画面は ../lines.py。"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from lines import draw_life, draw_memory, draw_minute, draw_fall, draw_scale, draw_survey, ep_for  # noqa: E402,F401

# 縦(ショート)
EP = ep_for("s1")

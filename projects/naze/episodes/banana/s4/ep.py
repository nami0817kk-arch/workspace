"""バナナの回 s4。台本と画面は ../lines.py。"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from lines import ep_for  # noqa: E402

# 縦(ショート)
EP = ep_for("s4")

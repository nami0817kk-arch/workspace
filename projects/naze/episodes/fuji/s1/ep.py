"""ショート s1(縦)。台本は ../shorts.py。"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from shorts import ep_for  # noqa: E402

EP = ep_for("s1")

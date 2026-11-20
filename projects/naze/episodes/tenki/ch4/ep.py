"""天気の子 ch4。台本と画面は ../parts.py。"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from parts import ep_for  # noqa: E402

aspect="landscape"  # __main__ が縦横を判定するための印
EP = ep_for("ch4")

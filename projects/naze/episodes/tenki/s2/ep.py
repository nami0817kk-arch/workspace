"""天気の子 s2。台本と画面は ../parts.py。"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from parts import ep_for  # noqa: E402


EP = ep_for("s2")

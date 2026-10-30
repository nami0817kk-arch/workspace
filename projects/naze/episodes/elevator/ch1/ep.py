"""宇宙エレベーター ch1。台本と画面は ../parts.py・../scene.py。"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from parts import ep_for  # noqa: E402
from scene import draw, sfx_for  # noqa: E402,F401

aspect="landscape"  # __main__ が縦横を判定するための印
EP = ep_for("ch1")


def sfx_events(L):
    return sfx_for(EP["lines"], L)

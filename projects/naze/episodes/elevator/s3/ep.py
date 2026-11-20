"""宇宙エレベーター s3。台本と画面は ../parts.py・../scene.py。"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from parts import ep_for  # noqa: E402
from scene import draw, sfx_for  # noqa: E402,F401

EP = ep_for("s3")


def sfx_events(L):
    return sfx_for(EP["lines"], L)

"""3 対 1 の第 5 幕。中身は sanbiki.py。"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import sanbiki  # noqa: E402


def build():
    sc, rep, _ = sanbiki.build(5)
    return sc, rep

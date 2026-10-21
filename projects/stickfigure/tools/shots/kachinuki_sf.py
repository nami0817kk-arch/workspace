"""勝ち抜き戦(札なし・参考の見せ方)の sf。中身は kachinuki.py。"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import kachinuki  # noqa: E402


def build():
    sc, rep, _, _ = kachinuki.BUILDS["sf"]()
    return sc, rep

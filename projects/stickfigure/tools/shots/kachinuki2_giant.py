"""勝ち抜き戦 第 2 版(動作部品)の giant。中身は kachinuki2.py。"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import kachinuki2  # noqa: E402


def build():
    sc, rep, _, _ = kachinuki2.BUILDS["giant"]()
    return sc, rep

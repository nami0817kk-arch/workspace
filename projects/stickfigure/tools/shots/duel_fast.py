"""速い連打の試し(moves.chain): 緑が 5 連打 → 赤の反撃 → 緑の 4 連打。使い方: python tools/shots/duel_fast.py --check --out out/duel_fast"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from stickfig import bout, moves  # noqa: E402

NAME = "duel_fast"
T_END = 6.0
BG = dict(image="assets/bg/shrine_dusk.png", x0=-9.5, x1=9.0, ground=0.80)
CAST = dict(A=dict(color=[0.5, 0.85, 0.3], style="kenpo", x=-0.9, d=1),
            B=dict(color=[0.92, 0.32, 0.28], style="brawler", x=0.9, d=-1))


def script(F, T):
    A, B = F["A"], F["B"]
    T.chain(A, B, [("jab", "stagger"), ("cross", "stagger"), ("hook", "stagger"), ("belly", "fold"), ("upper", "stagger", dict(push=0.5))], 1.0, gap=0.24)
    T.chain(B, A, [("cross", "stagger"), ("hook", "stagger", dict(push=0.5))], 2.9, gap=0.28)
    T.chain(A, B, [("front", "block", dict(push=0.3)), ("round", "stagger", dict(push=0.5)), ("palm", "launch", dict(dist=2.0, stay=True))], 3.9, gap=0.30)


def build():
    return moves.build_bout(NAME, BG, T_END, CAST, script)


if __name__ == "__main__":
    sc0, rep0, beats0 = build()
    bout.run_cli(lambda: (sc0, rep0), beats0, NAME)

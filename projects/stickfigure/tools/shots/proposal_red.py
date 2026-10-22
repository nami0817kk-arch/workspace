"""絵コンテ案 決勝「緑 vs 赤(喧嘩屋)」テーマは空中。前半は互角の殴り合い(この場面)、後半は空中コンボ(動作はこれから。絵コンテは tools/storyboard_build.py の手組みの姿勢)。"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from stickfig import bout, moves  # noqa: E402

NAME = "proposal_red"
T_END = 6.4
BG = dict(image="assets/bg/shrine_dusk.png", x0=-9.5, x1=9.0, ground=0.80)
CAST = dict(A=dict(color=[0.5, 0.85, 0.3], style="kenpo", x=-0.9, d=1),
            B=dict(color=[0.92, 0.32, 0.28], style="brawler", x=0.9, d=-1))


def script(F, T):
    A, B = F["A"], F["B"]
    T.exchange(B, A, "hook", 0.90, "duck")                                                       # 赤の大振りをくぐる
    T.exchange(A, B, "upper", 1.42, "block", push=0.30)                                          # くぐって返すアッパーは腕で受けられる
    T.exchange(B, A, "cross", 1.90, "stagger", push=0.45)                                        # 赤の右が緑の顔に入る(被弾)
    T.clash(A, B, "cross", 2.55)                                                                 # 拳と拳がぶつかり、弾かれる
    T.chain(A, B, [("front", "stagger", dict(push=0.4)), ("cross", "stagger"), ("jab", "stagger", dict(push=0.3))], 3.20, gap=0.28)   # 緑の 3 連
    T.exchange(B, A, "belly", 4.30, "fold", push=0.55)                                           # 赤の腹打ちで緑が折れる
    T.exchange(A, B, "jab", 4.95, "stagger", push=0.2)                                           # 折れながら返す左


def build():
    return moves.build_bout(NAME, BG, T_END, CAST, script)


if __name__ == "__main__":
    sc0, rep0, beats0 = build()
    bout.run_cli(lambda: (sc0, rep0), beats0, NAME)

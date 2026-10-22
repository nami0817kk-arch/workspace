"""絵コンテ案 準決勝「緑 vs 紫(巨漢)」テーマは力。巨漢の一発が重く、緑は 2 度吹き飛ばされ、食らいついて連打で崩す。"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from stickfig import bout, moves  # noqa: E402

NAME = "proposal_giant"
T_END = 11.0
GIANT = 1.25
BG = dict(image="assets/bg/riverside.png", x0=-9.5, x1=9.0, ground=0.80)
CAST = dict(A=dict(color=[0.5, 0.85, 0.3], style="kenpo", x=-0.9, d=1),
            B=dict(color=[0.62, 0.35, 0.85], style="giant", x=1.1, d=-1, scale=GIANT))


def script(F, T):
    A, B = F["A"], F["B"]
    T.exchange(B, A, "hook", 1.00, "duck")                                                  # 巨漢の大振りをくぐる
    T.chain(A, B, [("jab", "block", dict(push=0.1, part="chest")), ("cross", "block", dict(push=0.1, part="chest"))], 1.50, gap=0.26)           # 緑の連打は腕で受けられる
    T.exchange(B, A, "cross", 2.10, "launch", dist=2.4, lie=0.10, getup=0.45)                # 巨漢の右で緑が吹き飛ぶ(1 度目)
    T.chain(A, B, [("cross", "stagger", dict(push=0.12, part="chest")), ("sweep", "stagger", dict(push=0.25))], 3.60, gap=0.30)               # 起き上がって走り込み、右 → 足払い
    T.exchange(A, B, "belly", 4.30, "fold", push=0.3)                                       # 腹
    T.exchange(B, A, "hook", 4.85, "launch", dist=2.0, lie=0.08, getup=0.40)                 # 巨漢の左が緑を捉える(2 度目の吹き飛び)
    T.chain(A, B, [("upper", "stagger", dict(push=0.25, part="chest")), ("cross", "stagger", dict(push=0.15, part="chest")), ("jab", "stagger", dict(push=0.15, part="chest")), ("belly", "fold", dict(push=0.35))], 6.80, gap=0.26)   # 食らいついて 4 連打
    T.exchange(B, A, "hook", 7.95, "duck")                                                  # 巨漢の最後の大振りをくぐる
    T.exchange(A, B, "jump", 8.85, "launch", dist=1.8, stay=True)                           # 跳び蹴りで巨漢が倒れる
    A.freeze(9.25, 0.8)


def build():
    return moves.build_bout(NAME, BG, T_END, CAST, script)


if __name__ == "__main__":
    sc0, rep0, beats0 = build()
    bout.run_cli(lambda: (sc0, rep0), beats0, NAME)

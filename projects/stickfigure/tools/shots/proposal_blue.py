"""絵コンテ案 第一回戦「緑 vs 青(蹴り使い)」テーマは速さ。蹴りの連続と、緑の速い連打。2026-10-22「もっと激しいアクションに」。"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from stickfig import bout, moves  # noqa: E402

NAME = "proposal_blue"
T_END = 10.4
BG = dict(image="assets/bg/dojo.png", x0=-9.5, x1=9.0, ground=0.82)
CAST = dict(A=dict(color=[0.5, 0.85, 0.3], style="kenpo", x=-0.9, d=1),
            B=dict(color=[0.25, 0.55, 0.95], style="kicker", x=0.9, d=-1))


def script(F, T):
    A, B = F["A"], F["B"]
    T.exchange(B, A, "jump", 1.00, "duck")                                                              # 青が飛び込む跳び蹴り → 緑がかがんでかわす
    T.chain(B, A, [("front", "block", dict(push=0.35)), ("round", "block", dict(push=0.35)), ("front", "stagger", dict(push=0.5))], 1.80, gap=0.30)   # 蹴り 3 連: 2 発は受け、3 発目が胸に入る
    T.chain(A, B, [("jab", "stagger"), ("cross", "stagger"), ("hook", "stagger"), ("belly", "fold", dict(push=0.5))], 3.05, gap=0.24)         # 緑の 4 連打
    T.exchange(B, A, "round", 4.20, "duck")                                                             # 青の回し蹴りをくぐる
    T.exchange(A, B, "sweep", 4.65, "hop")                                                              # 足払いを跳んでかわされる
    T.exchange(B, A, "jump", 5.30, "block", push=0.5)                                                   # 空中からの蹴りを受ける
    T.chain(A, B, [("upper", "stagger", dict(push=0.3)), ("cross", "stagger"), ("jab", "stagger"), ("belly", "fold", dict(push=0.4)), ("round", "launch", dict(dist=2.2, lie=0.1, getup=0.45))], 6.00, gap=0.27)   # 5 連: 最後の回し蹴りで吹き飛ばす
    T.exchange(A, B, "palm", 8.55, "launch", dist=2.4, stay=True)                                       # 起き上がりに掌底で倒す
    A.freeze(8.75, 0.7)


def build():
    return moves.build_bout(NAME, BG, T_END, CAST, script)


if __name__ == "__main__":
    sc0, rep0, beats0 = build()
    bout.run_cli(lambda: (sc0, rep0), beats0, NAME)

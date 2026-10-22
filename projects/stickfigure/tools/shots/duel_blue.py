"""勝ち抜き戦 第一回戦「緑 vs 青(蹴り使い)」約 11 秒。動作部品 stickfig/moves.py で組む。2026-10-22「バトルをもっと激しく」→「これで作ってみよう」(絵コンテ合意)。

青の跳び蹴りと蹴りの 3 連が続き、緑は受け、くぐり、バク転でかわし、スライディングでくぐる。緑の連打(4 連・5 連)で青を崩し、掌底で倒す。
絵コンテ: out/storyboard の第一回戦。バク転(青の回し蹴りを後ろ宙返りでかわす)とスライディング(跳び蹴りの下をくぐる)が新しい動作。

使い方: python tools/shots/duel_blue.py --out out/duel_blue [--check|--preview|--plan-only]
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from stickfig import bout, moves  # noqa: E402

NAME = "duel_blue"
T_END = 11.4
BG = dict(image="assets/bg/dojo.png", x0=-9.5, x1=9.0, ground=0.82)
CAST = dict(A=dict(color=[0.5, 0.85, 0.3], style="kenpo", x=-0.9, d=1),
            B=dict(color=[0.25, 0.55, 0.95], style="kicker", x=0.9, d=-1))


def script(F, T):
    A, B = F["A"], F["B"]
    T.exchange(B, A, "jump", 1.00, "duck")                                                              # 青が飛び込む跳び蹴り → 緑がかがんでかわす
    T.chain(B, A, [("front", "block", dict(push=0.35)), ("round", "block", dict(push=0.35))], 1.80, gap=0.30)   # 蹴り 3 連: 2 発は受け(連続の蹴り)
    T.exchange(B, A, "front", 2.50, "stagger", push=0.5)                                                # 3 発目が胸に入る
    T.chain(A, B, [("jab", "stagger"), ("cross", "stagger"), ("hook", "stagger"), ("belly", "fold", dict(push=0.5))], 3.05, gap=0.24)         # 緑の 4 連打
    T.exchange(B, A, "round", 4.80, "flip", back=1.0)                                                   # 青の高い回し蹴りを、緑がバク転でかわす
    T.exchange(A, B, "sweep", 5.55, "hop")                                                              # 着地してすぐ足払い → 青は跳んでかわす
    T.exchange(B, A, "jump", 6.25, "slide", back=0.9)                                                   # 空中からの跳び蹴りの下を、緑がスライディングでくぐる
    T.chain(A, B, [("upper", "stagger", dict(push=0.3)), ("cross", "stagger"), ("jab", "stagger"), ("belly", "fold", dict(push=0.4)), ("round", "launch", dict(dist=2.2, lie=0.1, getup=0.45, flash=True))], 7.20, gap=0.27)   # 5 連: 最後の回し蹴りで吹き飛ばす
    T.exchange(A, B, "palm", 9.75, "launch", dist=2.4, stay=True, flash=True)                           # 起き上がりに掌底で倒す
    A.freeze(9.95, 0.7)


def build():
    return moves.build_bout(NAME, BG, T_END, CAST, script)


if __name__ == "__main__":
    sc0, rep0, beats0 = build()
    bout.run_cli(lambda: (sc0, rep0), beats0, NAME)

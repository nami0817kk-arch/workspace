"""勝ち抜き戦 第一回戦「緑 vs 青(蹴り使い)」約 10 秒。動作部品 stickfig/moves.py で組む。2026-10-22「バトルをもっと激しく」。

青が蹴りで攻め込み(前蹴りは受け、回し蹴りはくぐり)、緑が返し、青の蹴りが緑に入る(緑も被弾する)。
そのあと緑が上・中・下の連打から跳び蹴りで青を吹き飛ばし、最後は掌底で倒す。

使い方: python tools/shots/duel_blue.py --out out/duel_blue [--check|--preview|--plan-only]
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from stickfig import bout, moves  # noqa: E402

NAME = "duel_blue"
T_END = 10.6
BG = dict(image="assets/bg/dojo.png", x0=-9.5, x1=9.0, ground=0.82)
CAST = dict(A=dict(color=[0.5, 0.85, 0.3], style="kenpo", x=-0.9, d=1),
            B=dict(color=[0.25, 0.55, 0.95], style="kicker", x=0.9, d=-1))


def script(F, T):
    A, B = F["A"], F["B"]
    T.exchange(B, A, "front", 1.00, "block", push=0.45)               # 青の前蹴りを、緑が両腕で受ける
    T.exchange(B, A, "round", 1.60, "duck")                           # 青の高い回し蹴りを、緑がしゃがんでくぐる
    T.exchange(A, B, "cross", 2.07, "stagger", push=0.25, ret=0.0)           # くぐった緑がすぐ返す
    T.exchange(A, B, "jab", 2.47, "lean")                             # 続けて左 → 青が反ってかわす
    T.exchange(B, A, "front", 2.90, "stagger", push=0.5)              # 青の前蹴りが緑の胸に入る(緑も被弾する)
    T.exchange(B, A, "round", 3.40, "block", push=0.5)                # 青が畳みかける回し蹴り → 緑が受ける
    T.exchange(A, B, "sweep", 3.90, "hop")                            # 緑の足払いを、青が跳んでかわす
    T.exchange(B, A, "jump", 4.60, "duck")                            # 空中から青の跳び蹴り → 緑がかがんでかわす
    T.exchange(A, B, "upper", 5.40, "stagger", push=0.25, ret=0.0)           # 緑のアッパーが顎に入る
    T.exchange(A, B, "cross", 5.77, "stagger", push=0.2, ret=0.0)           # 右
    T.exchange(A, B, "belly", 6.14, "fold", push=0.45)                # 腹
    T.exchange(A, B, "jump", 6.90, "launch", dist=2.2, lie=0.15, getup=0.5)   # 緑の跳び蹴りで青が吹き飛ぶ
    T.exchange(A, B, "palm", 8.15, "launch", dist=2.4, stay=True)     # 最後は掌底で倒す
    A.freeze(8.35, 0.7)                                                # 決めの止め絵


def build():
    return moves.build_bout(NAME, BG, T_END, CAST, script)


if __name__ == "__main__":
    sc0, rep0, beats0 = build()
    bout.run_cli(lambda: (sc0, rep0), beats0, NAME)

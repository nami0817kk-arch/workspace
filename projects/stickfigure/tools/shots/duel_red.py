"""勝ち抜き戦 決勝「緑 vs 赤(喧嘩屋)」約 11 秒。動作部品 stickfig/moves.py で組む。2026-10-22「バトルをもっと激しく」。

互角の殴り合い: 赤の大振りをくぐり、赤の右が緑に入り(被弾)、拳と拳がぶつかり、赤の腹打ちで緑が折れ、赤の跳び蹴りを受ける。
そこから緑が連打 → 回し蹴りで赤を吹き飛ばし、起き上がった赤の最後の大振りをくぐって、掌底で倒す。

使い方: python tools/shots/duel_red.py --out out/duel_red [--check|--preview|--plan-only]
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from stickfig import bout, moves  # noqa: E402

NAME = "duel_red"
T_END = 11.4
BG = dict(image="assets/bg/shrine_dusk.png", x0=-9.5, x1=9.0, ground=0.80)
CAST = dict(A=dict(color=[0.5, 0.85, 0.3], style="kenpo", x=-0.9, d=1),
            B=dict(color=[0.92, 0.32, 0.28], style="brawler", x=0.9, d=-1))


def script(F, T):
    A, B = F["A"], F["B"]
    T.exchange(B, A, "hook", 0.90, "duck")                              # 赤の大振りを、緑がしゃがんでくぐる
    T.exchange(A, B, "upper", 1.42, "block", push=0.30)                 # くぐった緑のアッパーを、赤が腕で受ける
    T.exchange(B, A, "cross", 1.90, "stagger", push=0.45)               # 赤の右が緑の顔に入る(緑も被弾する)
    T.clash(A, B, "cross", 2.55)                                        # 拳と拳がぶつかり、互いに弾かれる
    T.exchange(A, B, "front", 3.10, "stagger", push=0.4)                # 緑の前蹴り
    T.exchange(B, A, "belly", 3.60, "fold", push=0.55)                   # 赤の腹打ちで緑が折れる
    T.exchange(A, B, "sweep", 4.20, "hop")                              # 緑の足払いを、赤が跳んでかわす
    T.exchange(B, A, "jump", 4.95, "block", push=0.5)                   # 赤の跳び蹴りを、緑が両腕で受ける
    T.exchange(A, B, "jab", 5.55, "stagger", push=0.2, ret=0.0)         # ここから緑の連打
    T.exchange(A, B, "cross", 5.90, "stagger", push=0.2, ret=0.0)
    T.exchange(A, B, "upper", 6.30, "stagger", push=0.40, ret=0.0)
    T.exchange(A, B, "belly", 6.70, "fold", push=0.5, ret=0.0)
    T.exchange(A, B, "round", 7.25, "launch", dist=2.2, lie=0.12, getup=0.45)   # 回し蹴りで赤が吹き飛ぶ
    T.exchange(B, A, "hook", 8.70, "duck")                              # 起き上がった赤の最後の大振りをくぐる
    T.exchange(A, B, "palm", 9.20, "launch", dist=2.4, stay=True)       # 掌底で倒す
    A.freeze(9.40, 0.8)                                                  # 決めの止め絵


def build():
    return moves.build_bout(NAME, BG, T_END, CAST, script)


if __name__ == "__main__":
    sc0, rep0, beats0 = build()
    bout.run_cli(lambda: (sc0, rep0), beats0, NAME)

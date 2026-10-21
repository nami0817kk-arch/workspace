"""手付けの殴り合い(動作部品 stickfig/moves.py の見本)「緑 vs 赤」約 9 秒。2026-10-22「バトルをもっと激しく」。

使い方: python tools/shots/duel_a.py --out out/duel_a [--check|--preview|--plan-only]
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from stickfig import bout, moves  # noqa: E402

NAME = "duel_a"
T_END = 9.6
BG = dict(image="assets/bg/shrine_dusk.png", x0=-8.5, x1=8.0, ground=0.80)
CAST = dict(A=dict(color=[0.5, 0.85, 0.3], style="kenpo", x=-0.9, d=1),
            B=dict(color=[0.92, 0.32, 0.28], style="brawler", x=0.9, d=-1))


def script(F, T):
    A, B = F["A"], F["B"]
    T.exchange(A, B, "jab", 1.00, "lean")                    # 緑の左を、赤が反ってかわす
    T.exchange(B, A, "hook", 1.55, "duck")                   # 赤の大振りを、緑がしゃがんでくぐる
    T.exchange(A, B, "upper", 1.95, "stagger")               # 緑のアッパーが顎に入る
    T.exchange(B, A, "front", 2.65, "block")                 # 赤の前蹴りを両腕で受ける
    T.exchange(A, B, "cross", 3.10, "stagger", push=0.25)             # 受けた緑がすぐ返す
    T.exchange(A, B, "belly", 3.45, "fold", push=0.45)                # 続けて腹
    T.exchange(B, A, "round", 4.10, "duck")                  # 赤の高い回し蹴りを、しゃがんでかわす
    T.exchange(A, B, "sweep", 4.60, "hop")                   # 緑の足払いを、赤が跳んでかわす
    T.exchange(B, A, "cross", 5.10, "block")
    T.exchange(A, B, "jump", 5.80, "launch", dist=2.0, lie=0.20, getup=0.5)   # 緑の跳び蹴りで赤が吹き飛ぶ
    T.exchange(A, B, "jab", 7.30, "stagger", push=0.2)
    T.exchange(A, B, "cross", 7.65, "stagger", push=0.2)
    T.exchange(A, B, "palm", 8.05, "launch", dist=2.2, stay=True)            # 最後は掌底で倒す
    A.freeze(8.25, 0.7)                                                       # 決めの止め絵


def build():
    return moves.build_bout(NAME, BG, T_END, CAST, script)


if __name__ == "__main__":
    sc0, rep0, beats0 = build()
    bout.run_cli(lambda: (sc0, rep0), beats0, NAME)

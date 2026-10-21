"""勝ち抜き戦 準決勝「緑 vs 紫(巨漢)」約 10 秒。動作部品 stickfig/moves.py で組む。2026-10-22「バトルをもっと激しく」。

巨漢の大振りで緑が吹き飛ばされる(ピンチ)→ 起き上がって懐へ走り込む → 足払い・腹・アッパー・連打で崩し、
巨漢の最後の大振りをくぐって跳び蹴りで倒す。

使い方: python tools/shots/duel_giant.py --out out/duel_giant [--check|--preview|--plan-only]
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from stickfig import bout, moves  # noqa: E402

NAME = "duel_giant"
T_END = 10.4
GIANT = 1.25
BG = dict(image="assets/bg/riverside.png", x0=-9.5, x1=9.0, ground=0.80)
CAST = dict(A=dict(color=[0.5, 0.85, 0.3], style="kenpo", x=-0.9, d=1),
            B=dict(color=[0.62, 0.35, 0.85], style="giant", x=1.1, d=-1, scale=GIANT))


def script(F, T):
    A, B = F["A"], F["B"]
    T.exchange(B, A, "hook", 1.00, "duck")                              # 巨漢の大振りを、緑がしゃがんでくぐる
    T.exchange(A, B, "jab", 1.50, "block", push=0.10, part="chest")                   # 緑の左は、腕で受けられて効かない
    T.exchange(B, A, "cross", 1.95, "launch", dist=2.4, lie=0.12, getup=0.5)   # 巨漢の右が入り、緑が吹き飛ばされる
    T.exchange(A, B, "cross", 3.42, "stagger", push=0.12, ret=0.0, part="chest")      # 起き上がった緑が走り込んで返す
    T.exchange(B, A, "hook", 3.95, "block", push=0.6)                   # 巨漢の大振りを両腕で受ける
    T.exchange(A, B, "sweep", 4.50, "stagger", push=0.2)                # 足払い(巨漢がぐらつく)
    T.exchange(A, B, "belly", 4.92, "fold", push=0.3)                   # 腹
    T.exchange(B, A, "cross", 5.35, "duck")                             # 巨漢の右をくぐる
    T.exchange(A, B, "upper", 5.80, "stagger", push=0.25, ret=0.0, part="chest")      # アッパーで顎が上がる
    T.exchange(A, B, "cross", 6.17, "stagger", push=0.15, ret=0.0, part="chest")      # 右
    T.exchange(A, B, "jab", 6.54, "stagger", push=0.15, ret=0.0, part="chest")        # 左
    T.exchange(B, A, "hook", 7.05, "duck")                              # 巨漢の最後の大振り → くぐる
    T.exchange(A, B, "jump", 7.75, "launch", dist=1.8, stay=True)       # 跳び蹴りで巨漢が倒れる
    A.freeze(8.15, 0.8)                                                  # 決めの止め絵


def build():
    return moves.build_bout(NAME, BG, T_END, CAST, script)


if __name__ == "__main__":
    sc0, rep0, beats0 = build()
    bout.run_cli(lambda: (sc0, rep0), beats0, NAME)

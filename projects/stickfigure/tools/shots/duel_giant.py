"""勝ち抜き戦 準決勝「緑 vs 紫(巨漢)」約 10 秒。動作部品 stickfig/moves.py で組む。2026-10-22「バトルをもっと激しく」→「これで作ってみよう」。

巨漢の大振りをくぐり、緑の連打は腕で受けられ、巨漢の右で緑が吹き飛ぶ(ピンチ)。起き上がって足払い・腹で崩し、
巨漢が地面を叩いて衝撃波 → 緑が跳んでかわす(新しい動作・エフェクト)。食らいついて 4 連打、最後は大振りをくぐって跳び蹴りで倒す。

使い方: python tools/shots/duel_giant.py --out out/duel_giant [--check|--preview|--plan-only]
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from stickfig import bout, moves  # noqa: E402

NAME = "duel_giant"
T_END = 11.2
GIANT = 1.25
BG = dict(image="assets/bg/riverside.png", x0=-9.5, x1=9.0, ground=0.80)
CAST = dict(A=dict(color=[0.5, 0.85, 0.3], style="kenpo", x=-0.9, d=1),
            B=dict(color=[0.62, 0.35, 0.85], style="giant", x=1.1, d=-1, scale=GIANT))


def script(F, T):
    A, B = F["A"], F["B"]
    T.exchange(B, A, "hook", 1.00, "duck")                                                  # 巨漢の大振りをくぐる
    T.chain(A, B, [("jab", "block", dict(push=0.1, part="chest")), ("cross", "block", dict(push=0.1, part="chest"))], 1.50, gap=0.26)           # 緑の連打は腕で受けられる
    T.exchange(B, A, "cross", 2.10, "launch", dist=2.4, lie=0.10, getup=0.45, flash=True)   # 巨漢の右で緑が吹き飛ぶ
    T.exchange(A, B, "cross", 3.60, "stagger", push=0.12, part="chest")                      # 起き上がって走り込み、右
    T.exchange(A, B, "sweep", 4.05, "stagger", push=0.25)                                   # 足払い
    T.exchange(A, B, "belly", 4.55, "fold", push=0.3)                                       # 腹
    A.dash(5.00, 5.23, B.x - 2.7)                                                           # 緑が跳び退いて間合いを取る
    T.slam_wave(B, A, 5.95, "hop")                                                          # 巨漢が地面を叩いて衝撃波 → 緑は跳んでかわす
    T.chain(A, B, [("upper", "stagger", dict(push=0.25, part="chest")), ("cross", "stagger", dict(push=0.15, part="chest")), ("jab", "stagger", dict(push=0.15, part="chest")), ("belly", "fold", dict(push=0.35))], 7.15, gap=0.26)   # 食らいついて 4 連打
    T.exchange(B, A, "hook", 8.40, "duck")                                                  # 巨漢の最後の大振りをくぐる
    T.exchange(A, B, "jump", 9.25, "launch", dist=1.8, stay=True, flash=True)               # 跳び蹴りで巨漢が倒れる
    A.freeze(9.65, 0.8)


def build():
    sc, rep, beats = moves.build_bout(NAME, BG, T_END, CAST, script)
    sc["qa"] = dict(sc.get("qa") or {}, ground_tol=0.10)          # 深いしゃがみ(アッパー・足払い)で緑の前脚が最大 6 cm 床に沈む。影があるので見分けがつかない範囲
    return sc, rep, beats


if __name__ == "__main__":
    sc0, rep0, beats0 = build()
    bout.run_cli(lambda: (sc0, rep0), beats0, NAME)

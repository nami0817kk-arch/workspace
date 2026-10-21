"""勝ち抜き戦の出場者紹介(約 7 秒)。4 人が並んで立ち、1 人ずつ自分の型で構える(青 → 紫 → 赤 → 緑)。カメラは構えた人へ寄る。

使い方: python tools/shots/bout_intro.py --out out/bout_intro [--preview]
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from stickfig import bout, keyshot as ks  # noqa: E402
from stickfig.bout import GUARD_F, GUARD_R, RELAX_F, RELAX_R, FPS  # noqa: E402

NAME = "bout_intro"
T_END = 7.0
BG = dict(image="assets/bg/dojo.png", x0=-6.5, x1=6.0, ground=0.82)
# 人: (色, 大きさ, 型, 立つ x, 向き, 構える時刻)
CAST = dict(B=([0.25, 0.55, 0.95], 1.0, "kicker", -0.9, -1, 1.0),
            C=([0.62, 0.35, 0.85], 1.25, "giant", 0.75, -1, 2.0),
            D=([0.92, 0.32, 0.28], 1.0, "brawler", 2.5, -1, 3.0),
            A=([0.5, 0.85, 0.3], 1.0, "kenpo", -2.6, 1, 4.0))


def tracks(x, d, tp, sc):
    w = 0.22 * sc                                                    # 立ち姿の足幅の半分
    body = [dict(t=0.0, x=x, hz=0.84, lean=0.03, ht=0.0, dir=d, face="fight"),
            dict(t=tp - 0.25, hz=0.84, lean=0.03, ht=0.05),
            dict(t=tp - 0.10, hz=0.76, lean=0.20, ht=-0.10),                              # 沈んで
            dict(t=tp + 0.08, hz=0.80, lean=0.12, ht=0.0, ease="in"),                       # 構える(stylize で型の値になる)
            dict(t=T_END, hz=0.80, lean=0.12, ht=0.0)]
    f = [dict(t=0.0, p=(x + d * w, 0)), dict(t=tp - 0.12, p=(x + d * w, 0)), dict(t=tp + 0.06, p=(x + d * 0.30 * sc, 0), lift=0.05), dict(t=T_END, p=(x + d * 0.30 * sc, 0))]
    r = [dict(t=0.0, p=(x - d * w, 0)), dict(t=tp - 0.10, p=(x - d * w, 0)), dict(t=tp + 0.08, p=(x - d * 0.30 * sc, 0), lift=0.05), dict(t=T_END, p=(x - d * 0.30 * sc, 0))]
    fh = [dict(t=0.0, ang=RELAX_F), dict(t=tp - 0.12, ang=RELAX_F), dict(t=tp + 0.08, ang=GUARD_F, ease="in"), dict(t=T_END, ang=GUARD_F)]
    rh = [dict(t=0.0, ang=RELAX_R), dict(t=tp - 0.12, ang=RELAX_R), dict(t=tp + 0.08, ang=GUARD_R, ease="in"), dict(t=T_END, ang=GUARD_R)]
    return dict(body=body, f_foot=f, r_foot=r, f_hand=fh, r_hand=rh)


def build():
    base = bout.new_scene(NAME, BG, T_END, {w: dict(color=c[0], scale=(c[1] if c[1] != 1.0 else None)) for w, c in CAST.items()})
    keys, rep = {}, []
    for w, (col, sc, style, x, d, tp) in CAST.items():
        holds = [dict(kind="windup", t=tp + 0.08, hold=3, burst=3)]
        keys[w] = ks.bake(ks.widen_stance(bout.stylize(tracks(x, d, tp, sc), style), scale=sc), base["actors"][w], FPS, T_END, report=rep, holds=holds)
    shots = [dict(t=0.0, follow="mid", scale=5.6, yaw=-4.0, pitch=3.0, lens=40.0, target_z=1.1, lag=0.3)]
    for w, (col, sc, style, x, d, tp) in sorted(CAST.items(), key=lambda kv: kv[1][5]):
        shots.append(dict(t=round(tp - 0.30, 3), follow=w, scale=2.4 * sc ** 2, yaw=(14.0 if d < 0 else -14.0), pitch=-6.0, lens=34.0, target_z=1.0 * sc ** 2, lag=0.0))   # 巨漢は頭が切れたので引いて上へ
    shots.append(dict(t=5.10, follow="mid", scale=5.8, yaw=-4.0, pitch=2.0, lens=40.0, target_z=1.1, lag=0.4))
    base = bout.finish(base, keys, [], shots, [], flashes=[CAST["A"][5] + 0.08], speed_lines=[[3.95, 4.30]])
    base["shots"] = shots                                            # 当たりが無いので cut_plan を通さず、そのまま
    return base, rep


if __name__ == "__main__":
    bout.run_cli(build, [], NAME)

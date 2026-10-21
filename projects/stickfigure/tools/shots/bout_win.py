"""勝ち抜き戦の勝ち名乗り(約 5.5 秒)。決勝のあと、緑が沈んでから拳を突き上げて止まる。カメラは下から寄る。

使い方: python tools/shots/bout_win.py --out out/bout_win [--preview]
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from stickfig import bout, keyshot as ks  # noqa: E402
from stickfig.bout import RELAX_F, RELAX_R, FPS  # noqa: E402

NAME = "bout_win"
T_END = 5.5
BG = dict(image="assets/bg/shrine_dusk.png", x0=-6.0, x1=6.5, ground=0.80)


def tracks_a():
    body = [dict(t=0.00, x=0.0, hz=0.84, lean=0.05, ht=0.10, dir=1, face="fight"),
            dict(t=0.50, hz=0.84, lean=0.05, ht=0.0),
            dict(t=0.95, hz=0.62, lean=0.38, ht=-0.20),                                   # 沈む(溜め)
            dict(t=1.12, hz=0.63, lean=0.40, ht=-0.22),
            dict(t=1.22, hz=0.77, lean=-0.12, ht=0.38, st=0.30, ease="in"),               # 一気に伸び上がって突き上げる
            dict(t=1.40, hz=0.76, lean=-0.10, ht=0.35, st=0.0, ease="out"),
            dict(t=5.50, hz=0.76, lean=-0.10, ht=0.35)]
    f = [dict(t=0.0, p=(0.25, 0)), dict(t=0.60, p=(0.25, 0)), dict(t=0.90, p=(0.45, 0), lift=0.04), dict(t=5.5, p=(0.45, 0))]
    r = [dict(t=0.0, p=(-0.25, 0)), dict(t=0.65, p=(-0.25, 0)), dict(t=0.92, p=(-0.45, 0), lift=0.04), dict(t=5.5, p=(-0.45, 0))]
    fh = [dict(t=0.0, ang=RELAX_F), dict(t=0.55, ang=RELAX_F), dict(t=0.95, ang=(0.2, 2.4)), dict(t=1.12, ang=(0.1, 2.5)),
          dict(t=1.22, ang=(2.55, 0.15), ease="in"), dict(t=5.5, ang=(2.55, 0.15))]                      # 前の拳を斜め前の上へ(真上だと頭の後ろに隠れた)
    rh = [dict(t=0.0, ang=RELAX_R), dict(t=0.55, ang=RELAX_R), dict(t=0.95, ang=(0.6, 2.2)), dict(t=1.22, ang=(-0.5, 2.3), ease="in"), dict(t=5.5, ang=(-0.5, 2.3))]   # 後ろの拳は脇に引く
    return dict(body=body, f_foot=f, r_foot=r, f_hand=fh, r_hand=rh)


def build():
    base = bout.new_scene(NAME, BG, T_END, dict(A=dict(color=[0.5, 0.85, 0.3])))
    aA = base["actors"]["A"]
    rep = []
    ka = ks.bake(tracks_a(), aA, FPS, T_END, report=rep, holds=[dict(kind="windup", t=1.22, hold=4, burst=3)])
    shots = [dict(t=0.0, follow="A", scale=3.2, yaw=-8.0, pitch=2.0, lens=40.0, target_z=1.0, lag=0.2),
             dict(t=0.90, follow="A", scale=2.3, yaw=14.0, pitch=-4.0, lens=34.0, target_z=1.0, lag=0.0),      # 沈む: 寄り
             dict(t=1.18, follow="A", scale=2.9, yaw=-18.0, pitch=-12.0, lens=30.0, target_z=1.5, lag=0.0),    # 突き上げ: 下から
             dict(t=2.30, follow="A", scale=3.6, yaw=-6.0, pitch=-6.0, lens=40.0, target_z=1.3, lag=0.6)]      # ゆっくり引く
    base = bout.finish(base, dict(A=ka), [], shots, [], flashes=[1.22], speed_lines=[[1.18, 1.70]])
    return base, rep


if __name__ == "__main__":
    bout.run_cli(build, [], NAME)

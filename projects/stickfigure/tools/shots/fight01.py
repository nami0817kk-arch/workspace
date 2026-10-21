"""手付けの戦い「境内の一戦」(約 9.4 秒、素手)。stickfig.keyshot で 2 人の腰・足・手を付け、当たる位置は相手の焼き込んだ体から取る。

振り付け:
  0.00-0.90 構え合う(緑は弾んで半歩詰める)
  0.90-1.40 緑のジャブ → 赤が上体を反らしてかわす(空振り)
  1.30-1.80 赤の大振りフック → 緑がしゃがんでかわす
  1.72-2.60 緑がしゃがみから伸び上がってアッパー → 赤の顎が跳ね、2 歩よろける
  2.55-3.55 赤が怒って首を振り、踏み込んで前蹴り → 緑が腕で受け、石畳を滑って下がる
  3.60-4.70 緑が回りながら踏み込んで後ろ回し蹴り → 赤が吹き飛び、背中から落ちて滑る
  4.70-6.30 赤が起き上がり、顎をぬぐう(緑は構えを少し解いて待つ)
  6.20-7.20 赤が走り込む → 拳と拳がぶつかり、互いに弾かれる
  7.20-8.40 赤の大振り → 緑がくぐって腹に一発 → 体を折った赤の顔に掌底 → 赤は尻もち
  8.40-9.40 赤は目を回し、緑は構えを解く

使い方: python tools/shots/fight01.py --out out/shot_fight01 [--preview] [--plan-only]
"""
from __future__ import annotations

import argparse
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from stickfig import fk, keyshot as ks  # noqa: E402

FPS = 30
T_END = 9.4
GUARD_F, GUARD_R = (1.15, 1.7), (0.75, 2.3)      # 構えの腕(前の腕は顔の前、後ろの腕はあご)
RELAX_F, RELAX_R = (0.35, 0.6), (0.25, 0.7)
BG = dict(image="assets/bg/shrine_dusk.png", x0=-6.0, x1=6.5, ground=0.80)
# アニメの溜め・一気・止め(keyshot.warp_fn): 当たりの前で全身を止め、残りを数コマに縮めて打つ。キーは止めない流れで書いておく
HOLDS_A = [dict(kind="windup", t=1.08, hold=3, burst=3), dict(kind="windup", t=1.8667, hold=5, burst=3),
           dict(kind="windup", t=3.8667, hold=4, burst=4), dict(kind="windup", t=6.95, hold=4, burst=3),
           dict(kind="windup", t=7.5667, hold=3, burst=3), dict(kind="windup", t=7.8667, hold=4, burst=3),
           dict(kind="freeze", t0=8.00, t1=8.75)]                                   # 掌底のあと、振り抜いた形で 0.6 秒止まる(決めの止め絵)
HOLDS_B = [dict(kind="windup", t=1.55, hold=4, burst=3), dict(kind="windup", t=3.22, hold=3, burst=2), dict(kind="windup", t=6.95, hold=4, burst=3)]
BEATS = [dict(t=1.08, by="A", to="B", limb="st", miss=True), dict(t=1.55, by="B", to="A", limb="rst", miss=True), dict(t=1.8667, by="A", to="B", big=True, limb="rst"),
         dict(t=3.22, by="B", to="A", limb="lst"), dict(t=3.8667, by="A", to="B", big=True, limb="rlst"), dict(t=6.95, by="A", to="B", big=True, limb="rst"),
         dict(t=7.5667, by="A", to="B", limb="rst"), dict(t=7.8667, by="A", to="B", big=True, limb="st")]


def skel(keys, actor, t):
    k = keys[min(len(keys) - 1, int(round(t * FPS)))]
    pose = dict(ks.POSE0, **{n: v for n, v in k.items() if n in ks.POSE0})
    return fk.skeleton(pose, 1 if k["dir"] > 0 else -1, actor["base_x"] + k["dx"], 1.0)


def chest(sk):
    a, b = sk["torso"]
    return ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)


def belly(sk):
    a, b = sk["torso"]
    return (a[0] + (b[0] - a[0]) * 0.3, a[1] + (b[1] - a[1]) * 0.3)


def face(sk, toward):            # 顔の前面(相手側へ頭の半径ぶん)
    hx, hz = sk["head"]
    return (hx + toward * sk["head_r"] * 0.8, hz - 0.03)


def chin(sk, toward):
    hx, hz = sk["head"]
    return (hx + toward * sk["head_r"] * 0.5, hz - sk["head_r"] * 0.85)


# ---------------- 赤(B、左向き)----------------
def tracks_b(tgt):
    body = [
        dict(t=0.00, x=0.75, hz=0.80, lean=0.12, ht=0.0, dir=-1, face="fight"),
        dict(t=0.45, hz=0.79), dict(t=0.90, hz=0.80),
        # ジャブをかわす(上体を反らす)
        dict(t=0.98, x=0.75, lean=0.12, ht=0.0), dict(t=1.10, x=0.90, lean=-0.32, ht=0.15, ease="out"), dict(t=1.24, lean=-0.18, ht=0.05),
        # フック: 溜め → 踏み込んで振り抜く(体が流れる)
        dict(t=1.32, x=0.90, hz=0.78, lean=-0.20, rst=0.0), dict(t=1.40, x=0.90, hz=0.78, lean=-0.22), dict(t=1.52, x=0.82, hz=0.79, lean=0.18, rst=0.16, ease="in"), dict(t=1.58, rst=0.16), dict(t=1.66, lean=0.26, ht=-0.05, rst=0.0),
        dict(t=1.8667, x=0.80, hz=0.80, lean=0.22, ht=0.0),
        # アッパーを受ける → よろける
        dict(t=1.93, x=0.96, hz=0.86, rz=0.24, lean=-0.58, ht=0.85, ease="out"),
        dict(t=2.10, x=1.10, hz=0.78, rz=0.0, lean=-0.30, ht=0.35), dict(t=2.35, x=1.35, hz=0.79, lean=-0.12, ht=0.18), dict(t=2.55, x=1.40, hz=0.80, lean=0.08, ht=0.0),
        # 怒る: 首を振って踏み鳴らす
        dict(t=2.60, ht=0.22), dict(t=2.66, ht=-0.20), dict(t=2.72, ht=0.18), dict(t=2.78, ht=-0.08), dict(t=2.84, ht=0.0, hz=0.80), dict(t=2.88, hz=0.76), dict(t=2.94, hz=0.80),
        # 踏み込んで前蹴り
        dict(t=2.96, x=1.40, lean=0.10), dict(t=3.10, x=0.55, hz=0.80, lean=0.05, ease="inout"),
        dict(t=3.16, lean=-0.12, hz=0.82, lst=0.0), dict(t=3.19, lean=-0.14, hz=0.82), dict(t=3.22, x=0.50, lean=-0.32, lst=0.15, ease="in"), dict(t=3.30, x=0.58, lean=-0.34, lst=0.0), dict(t=3.46, x=0.62, lean=0.10, hz=0.80, ease="out"),
        # 後ろ回し蹴りを受けて吹き飛ぶ
        dict(t=3.8667, x=0.62, lean=0.12, hz=0.80, rz=0.0, roll=0.0, ht=0.0),
        dict(t=3.95, x=0.90, lean=-0.55, rz=0.25, roll=0.35, ht=0.30, ease="out"),
        dict(t=4.10, x=1.65, rz=0.62, roll=1.00), dict(t=4.30, x=2.30, rz=0.30, roll=1.45), dict(t=4.38, x=2.42, rz=0.21, roll=1.57, lean=0.0, ht=0.0),
        dict(t=4.46, x=2.55, rz=0.38, roll=1.57, ease="out"), dict(t=4.54, x=2.66, rz=0.21, roll=1.57, ease="in"), dict(t=4.75, x=2.90, rz=0.21, roll=1.57, ease="out"),
        # 起き上がる
        dict(t=4.95, x=2.90, rz=0.21, roll=1.57), dict(t=5.25, rz=0.24, roll=1.05, hz=0.55, lean=0.20),
        dict(t=5.55, rz=0.18, roll=0.40, hz=0.48, lean=0.55), dict(t=5.85, rz=0.0, roll=0.0, hz=0.72, lean=0.30), dict(t=6.05, hz=0.80, lean=0.12, x=2.85),
        dict(t=6.15, ht=-0.15), dict(t=6.30, ht=0.0),
        # 走り込んで拳をぶつける
        dict(t=6.32, x=2.85, lean=0.12, hz=0.80), dict(t=6.40, lean=0.35, hz=0.78),
        dict(t=6.80, x=1.02, lean=0.30, hz=0.78, rst=0.0, ease="linear"), dict(t=6.86, x=0.95, lean=0.10, hz=0.77), dict(t=6.95, x=0.80, lean=0.44, rst=0.14, ease="in"),
        dict(t=7.20, x=1.30, lean=0.0, hz=0.80, rst=0.0, ease="out"),
        # 大振り → 腹 → 掌底 → 尻もち
        dict(t=7.26, x=1.30, lean=-0.10), dict(t=7.40, x=0.62, lean=0.45, ease="in"), dict(t=7.50, x=0.58, lean=0.30), dict(t=7.53, lean=0.10),
        dict(t=7.5667, x=0.58, lean=0.10, hz=0.80), dict(t=7.65, x=0.80, lean=0.50, hz=0.74, ht=-0.30, ease="out"), dict(t=7.80, lean=0.42, hz=0.75, ht=-0.20),
        dict(t=7.8667, lean=0.40), dict(t=7.95, x=1.02, lean=-0.55, ht=0.75, hz=0.82, rz=0.10, ease="out"),
        dict(t=8.10, x=1.35, lean=-0.30, hz=0.60, rz=0.0, ht=0.35), dict(t=8.30, x=1.55, hz=0.33, lean=-0.18, ht=0.10, ease="in"), dict(t=8.38, hz=0.40, lean=-0.10, ease="out"), dict(t=8.46, hz=0.33, lean=-0.16, ease="in"),
        # 目を回す
        dict(t=8.55, ht=-0.22, lean=-0.12), dict(t=8.85, ht=0.20, lean=-0.20), dict(t=9.15, ht=-0.18, lean=-0.13), dict(t=9.40, ht=0.10),
    ]
    f = [dict(t=0.00, p=(0.50, 0)), dict(t=0.98, p=(0.50, 0)), dict(t=1.12, p=(0.66, 0), lift=0.03),
         dict(t=1.34, p=(0.66, 0)), dict(t=1.50, p=(0.47, 0), lift=0.05),
         dict(t=1.95, p=(0.47, 0)), dict(t=2.30, p=(1.12, 0), lift=0.06),
         dict(t=2.80, p=(1.12, 0)), dict(t=2.84, p=(1.12, 0.12)), dict(t=2.90, p=(1.12, 0), ease="in"),
         dict(t=2.96, p=(1.12, 0)), dict(t=3.10, p=(0.32, 0), lift=0.08),
         dict(t=3.16, p=(0.24, 0.45)), dict(t=3.22, p=tgt["kick_b"], ease="in"), dict(t=3.30, p=tgt["kick_b"]),
         dict(t=3.38, p=(0.28, 0.40)), dict(t=3.46, p=(0.36, 0)),
         dict(t=3.8667, p=(0.36, 0)), dict(t=3.96, ang=(0.9, 0.4)), dict(t=4.38, ang=(0.3, 0.2)), dict(t=4.95, ang=(0.3, 0.2)),
         dict(t=5.25, ang=(1.2, 1.6)), dict(t=5.55, p=(2.50, 0)), dict(t=6.05, p=(2.60, 0)),
         dict(t=6.40, p=(2.60, 0)), dict(t=6.52, p=(1.90, 0), lift=0.10), dict(t=6.64, p=(1.80, 0)), dict(t=6.76, p=(1.05, 0), lift=0.10),
         dict(t=6.95, p=(0.55, 0), lift=0.06), dict(t=7.20, p=(1.05, 0), lift=0.0),
         dict(t=7.26, p=(1.05, 0)), dict(t=7.40, p=(0.34, 0), lift=0.06), dict(t=7.85, p=(0.34, 0)),
         dict(t=8.05, p=(0.70, 0), lift=0.05), dict(t=8.30, p=(0.93, 0), lift=0.03), dict(t=9.40, p=(0.93, 0))]
    r = [dict(t=0.00, p=(1.05, 0)), dict(t=1.52, p=(1.05, 0)), dict(t=1.70, p=(1.02, 0), lift=0.02),
         dict(t=1.95, p=(1.02, 0)), dict(t=2.10, p=(1.35, 0), lift=0.06), dict(t=2.40, p=(1.35, 0)), dict(t=2.55, p=(1.68, 0), lift=0.04),
         dict(t=2.96, p=(1.68, 0)), dict(t=3.04, p=(0.85, 0), lift=0.08), dict(t=3.46, p=(0.88, 0)),
         dict(t=3.8667, p=(0.88, 0)), dict(t=3.96, ang=(-0.4, 0.6)), dict(t=4.38, ang=(0.1, 0.2)), dict(t=4.95, ang=(0.1, 0.2)),
         dict(t=5.25, ang=(1.0, 1.8)), dict(t=5.55, p=(3.15, 0)), dict(t=6.05, p=(3.15, 0)),
         dict(t=6.40, p=(3.15, 0)), dict(t=6.46, p=(2.30, 0), lift=0.10), dict(t=6.58, p=(2.15, 0)), dict(t=6.70, p=(1.40, 0), lift=0.10),
         dict(t=6.82, p=(1.40, 0)), dict(t=6.95, p=(1.10, 0), lift=0.06), dict(t=7.20, p=(1.57, 0), lift=0.0),
         dict(t=7.26, p=(1.57, 0)), dict(t=7.44, p=(0.87, 0), lift=0.06), dict(t=7.85, p=(0.87, 0)),
         dict(t=8.10, p=(1.55, 0), lift=0.05), dict(t=8.30, p=(1.05, 0), lift=0.03), dict(t=9.40, p=(1.05, 0))]
    fh = [dict(t=0.00, ang=GUARD_F), dict(t=1.32, ang=GUARD_F), dict(t=1.52, ang=(0.6, 1.2)), dict(t=1.90, ang=(0.9, 0.6)),
          dict(t=2.10, ang=(1.5, 0.8)), dict(t=2.40, ang=GUARD_F),
          dict(t=3.10, ang=GUARD_F), dict(t=3.22, ang=(0.8, 1.4)), dict(t=3.46, ang=GUARD_F),
          dict(t=3.8667, ang=GUARD_F), dict(t=3.96, ang=(2.4, 0.4)), dict(t=4.38, ang=(2.6, 0.3)), dict(t=4.95, ang=(2.6, 0.3)),
          dict(t=5.25, ang=(0.4, 0.4)), dict(t=5.55, ang=(0.5, 0.3)), dict(t=5.85, ang=(0.6, 0.4)),
          dict(t=6.08, ang=(0.8, 2.6)), dict(t=6.22, ang=(1.1, 2.4)), dict(t=6.32, ang=GUARD_F),
          dict(t=7.26, ang=(1.3, 1.8)), dict(t=7.40, p=tgt["hook2"], ease="in"), dict(t=7.52, ang=(1.0, 0.3)),
          dict(t=7.64, ang=(0.3, 1.4)), dict(t=7.93, ang=(2.0, 0.6)), dict(t=8.30, ang=(-0.55, 0.15)), dict(t=9.40, ang=(-0.55, 0.15))]
    rh = [dict(t=0.00, ang=GUARD_R), dict(t=1.32, ang=(-0.6, 1.4)),
          dict(t=1.44, p=tgt["hook_a"], ease="in"), dict(t=1.58, p=tgt["hook_b"], ease="linear"), dict(t=1.70, ang=(0.2, 0.4), ease="out"),
          dict(t=1.90, ang=(0.6, 0.5)), dict(t=2.10, ang=(1.3, 0.7)), dict(t=2.40, ang=GUARD_R),
          dict(t=3.46, ang=GUARD_R), dict(t=3.8667, ang=GUARD_R), dict(t=3.96, ang=(2.2, 0.5)), dict(t=4.38, ang=(2.4, 0.3)), dict(t=4.95, ang=(2.4, 0.3)),
          dict(t=5.25, ang=(0.3, 0.4)), dict(t=5.85, ang=(0.5, 0.4)), dict(t=6.05, ang=GUARD_R),
          dict(t=6.80, ang=(0.2, 1.9)), dict(t=6.95, p=tgt["clash"], ease="in"), dict(t=7.05, ang=(0.8, 1.6)), dict(t=7.20, ang=GUARD_R),
          dict(t=7.40, ang=(0.3, 1.0)), dict(t=7.64, ang=(0.2, 1.6)), dict(t=7.93, ang=(1.8, 0.7)), dict(t=8.30, ang=(-0.65, 0.15)), dict(t=9.40, ang=(-0.65, 0.15))]
    return dict(body=body, f_foot=f, r_foot=r, f_hand=fh, r_hand=rh)


# ---------------- 緑(A、右向き)----------------
def tracks_a(tgt):
    body = [
        dict(t=0.00, x=-0.75, hz=0.80, lean=0.12, ht=0.0, dir=1, face="fight"),
        dict(t=0.22, hz=0.77), dict(t=0.44, hz=0.80), dict(t=0.50, x=-0.62), dict(t=0.66, hz=0.77), dict(t=0.88, hz=0.80, x=-0.62),
        # ジャブ
        dict(t=0.95, hz=0.75, lean=0.06), dict(t=1.00, hz=0.75, lean=0.05, st=0.0), dict(t=1.08, x=-0.30, hz=0.78, lean=0.42, st=0.14, ease="in"), dict(t=1.20, lean=0.30, st=0.0),
        dict(t=1.40, x=-0.42, hz=0.79, lean=0.14, ease="out"),
        # しゃがんでかわす
        dict(t=1.47, hz=0.79, lean=0.14, ht=0.0), dict(t=1.58, x=-0.55, hz=0.52, lean=0.30, ht=-0.10, ease="out"), dict(t=1.70, x=-0.55, hz=0.52, lean=0.30),
        # アッパー: 沈んで溜め → 伸び上がる
        dict(t=1.74, hz=0.47, lean=0.40), dict(t=1.80, hz=0.45, lean=0.42, rst=0.0), dict(t=1.8667, x=0.14, hz=0.86, lean=0.05, ht=0.15, rst=0.18, ease="in"), dict(t=1.98, x=0.16, hz=0.88, rz=0.10, lean=-0.08, rst=0.0, ease="out"), dict(t=2.10, rz=0.0, hz=0.80),
        dict(t=2.30, x=-0.35, hz=0.80, lean=0.12, ht=0.0, ease="out"), dict(t=2.55, hz=0.78), dict(t=2.80, hz=0.80),
        # 前蹴りを受けて滑る
        dict(t=3.10, hz=0.78, lean=0.18, x=-0.35), dict(t=3.22, x=-0.35), dict(t=3.52, x=-0.80, hz=0.77, lean=0.04, ease="out"), dict(t=3.58, hz=0.80, lean=0.12),
        # 回りながら踏み込んで後ろ回し蹴り
        dict(t=3.64, x=-0.72, hz=0.78, lean=0.10), dict(t=3.72, x=-0.38, hz=0.82, lean=0.12, dir=-1), dict(t=3.78, x=-0.30, hz=0.80, lean=0.30, rlst=0.0), dict(t=3.81, x=-0.29, hz=0.80, lean=0.32),
        dict(t=3.8667, x=-0.18, hz=0.83, lean=0.64, rlst=0.20, ease="in"), dict(t=4.02, x=-0.20, lean=0.30, rlst=0.0),
        dict(t=4.12, x=-0.26, hz=0.80, lean=0.12, dir=1), dict(t=4.32, x=-0.40), dict(t=4.55, x=-0.82, hz=0.80),
        # 待つ(構えを少し解く)
        dict(t=4.80, hz=0.84, lean=0.05), dict(t=5.80, hz=0.84, lean=0.05), dict(t=6.05, hz=0.80, lean=0.12),
        # 拳をぶつける
        dict(t=6.70, x=-0.82, hz=0.79, lean=0.15), dict(t=6.80, x=-0.86, hz=0.76, lean=0.02, rst=0.0), dict(t=6.86, x=-0.84, hz=0.76, lean=0.03), dict(t=6.95, x=-0.66, lean=0.44, rst=0.18, ease="in"), dict(t=6.99, rst=0.16),
        dict(t=7.20, x=-1.10, lean=0.0, hz=0.79, rst=0.0, ease="out"),
        # くぐる → 腹 → 掌底
        dict(t=7.28, x=-1.10, hz=0.80, lean=0.10), dict(t=7.38, x=-1.10, hz=0.55, lean=0.40, ease="out"),
        dict(t=7.44, x=-1.02, hz=0.56, lean=0.36), dict(t=7.50, x=-0.50, hz=0.58, lean=0.32, ease="in"), dict(t=7.5667, x=-0.12, hz=0.58, lean=0.30, rst=0.14, ease="in"), dict(t=7.66, rst=0.0),
        dict(t=7.72, x=-0.12, hz=0.76, lean=0.08), dict(t=7.78, x=-0.15, hz=0.74, lean=0.0, st=0.0), dict(t=7.8667, x=-0.05, hz=0.80, lean=0.20, st=0.16, ease="in"), dict(t=8.05, lean=0.12, st=0.0),
        dict(t=8.50, x=-0.20, hz=0.82, lean=0.10, ease="inout"), dict(t=9.00, hz=0.85, lean=0.03), dict(t=9.40, hz=0.85),
    ]
    f = [dict(t=0.00, p=(-0.50, 0)), dict(t=0.36, p=(-0.50, 0)), dict(t=0.50, p=(-0.37, 0), lift=0.04),
         dict(t=0.98, p=(-0.37, 0)), dict(t=1.08, p=(-0.02, 0), lift=0.05, ease="out"), dict(t=1.30, p=(-0.02, 0)), dict(t=1.40, p=(-0.17, 0), lift=0.03),
         dict(t=1.78, p=(-0.17, 0)), dict(t=1.8667, p=(0.40, 0), lift=0.03), dict(t=2.25, p=(0.25, 0)), dict(t=2.32, p=(-0.10, 0), lift=0.03),
         dict(t=3.22, p=(-0.10, 0)), dict(t=3.52, p=(-0.55, 0), lift=0.0, ease="out"),
         dict(t=6.70, p=(-0.55, 0)),                                                             # 右足は回し蹴りの間も -0.55 に置いたまま(体の向きを変えても足の位置は入れ替わらない) dict(t=6.86, p=(-0.40, 0), lift=0.05), dict(t=6.95, p=(-0.40, 0)), dict(t=7.20, p=(-0.85, 0), lift=0.0),
         dict(t=7.40, p=(-0.85, 0)), dict(t=7.52, p=(0.12, 0), lift=0.05), dict(t=7.78, p=(0.12, 0)), dict(t=7.8667, p=(0.22, 0), lift=0.03),
         dict(t=8.45, p=(0.22, 0)), dict(t=8.60, p=(0.05, 0), lift=0.03), dict(t=9.40, p=(0.05, 0))]
    r = [dict(t=0.00, p=(-1.05, 0)), dict(t=0.52, p=(-1.05, 0)), dict(t=0.66, p=(-0.92, 0), lift=0.04),
         dict(t=1.40, p=(-0.92, 0)), dict(t=1.52, p=(-0.95, 0), lift=0.03),
         dict(t=1.80, p=(-0.95, 0)), dict(t=1.92, p=(-0.20, 0), lift=0.05), dict(t=2.20, p=(-0.20, 0)), dict(t=2.36, p=(-0.62, 0), lift=0.03),
         dict(t=3.22, p=(-0.62, 0)), dict(t=3.52, p=(-1.07, 0), lift=0.0, ease="out"),
         dict(t=3.62, p=(-1.07, 0)), dict(t=3.70, p=(-0.22, 0), lift=0.08),                              # 左足が右足を越えて踏み込む(回り始め)
         dict(t=3.74, p=(-0.22, 0)), dict(t=3.80, p=(-0.02, 0.38), lift=0.0), dict(t=3.8667, p=tgt["backkick"], ease="in"),
         dict(t=3.96, p=tgt["backkick"]), dict(t=4.06, p=(0.0, 0.25)), dict(t=4.12, p=(-0.05, 0.02)),
         dict(t=4.30, p=(-0.05, 0)), dict(t=4.50, p=(-1.10, 0), lift=0.06),                              # 向き直ったら左足を大きく引いて構えへ
         dict(t=6.95, p=(-1.10, 0)), dict(t=7.20, p=(-1.40, 0), lift=0.0),
         dict(t=7.40, p=(-1.40, 0)), dict(t=7.50, p=(-0.55, 0), lift=0.06), dict(t=7.85, p=(-0.55, 0)), dict(t=7.95, p=(-0.45, 0), lift=0.03),
         dict(t=9.40, p=(-0.45, 0))]
    fh = [dict(t=0.00, ang=GUARD_F), dict(t=0.95, ang=(0.95, 2.0)), dict(t=1.08, p=tgt["jab"], ease="in"), dict(t=1.18, p=tgt["jab"]), dict(t=1.36, ang=GUARD_F, ease="out"),
          dict(t=1.58, ang=(1.35, 1.9)), dict(t=1.76, ang=(1.2, 1.8)), dict(t=1.8667, ang=(0.5, 1.2)), dict(t=2.30, ang=GUARD_F),
          dict(t=3.08, ang=GUARD_F), dict(t=3.18, ang=(1.55, 1.95)), dict(t=3.52, ang=(1.5, 1.9)), dict(t=3.62, ang=GUARD_F),
          dict(t=3.72, ang=(1.0, 1.4)), dict(t=3.86, ang=(0.4, 0.8)), dict(t=4.12, ang=GUARD_F),
          dict(t=4.80, ang=RELAX_F), dict(t=5.80, ang=RELAX_F), dict(t=6.05, ang=GUARD_F),
          dict(t=6.95, ang=(0.6, 1.4)), dict(t=7.20, ang=GUARD_F), dict(t=7.38, ang=(1.4, 1.9)), dict(t=7.5667, ang=(0.7, 1.6)),
          dict(t=7.72, ang=(0.9, 2.2)), dict(t=7.8667, p=tgt["palm"], ease="in"), dict(t=7.95, p=tgt["palm_follow"]), dict(t=8.20, ang=(1.0, 1.3)),
          dict(t=8.60, ang=GUARD_F), dict(t=9.10, ang=RELAX_F), dict(t=9.40, ang=RELAX_F)]
    rh = [dict(t=0.00, ang=GUARD_R), dict(t=1.08, ang=(0.6, 2.2)), dict(t=1.40, ang=GUARD_R),
          dict(t=1.58, ang=(1.1, 2.2)), dict(t=1.75, ang=(0.1, 1.9)), dict(t=1.8667, p=tgt["upper"], ease="in"), dict(t=1.97, p=tgt["upper_follow"]),
          dict(t=2.25, ang=GUARD_R, ease="out"),
          dict(t=3.08, ang=GUARD_R), dict(t=3.18, ang=(1.40, 1.95)), dict(t=3.52, ang=(1.35, 1.9)), dict(t=3.62, ang=GUARD_R),
          dict(t=3.86, ang=(0.9, 1.6)), dict(t=4.12, ang=GUARD_R),
          dict(t=4.80, ang=RELAX_R), dict(t=5.80, ang=RELAX_R), dict(t=6.05, ang=GUARD_R),
          dict(t=6.80, ang=(0.2, 1.9)), dict(t=6.95, p=tgt["clash"], ease="in"), dict(t=7.05, ang=(0.8, 1.6)), dict(t=7.20, ang=GUARD_R),
          dict(t=7.38, ang=(1.1, 2.2)), dict(t=7.46, ang=(0.2, 1.8)), dict(t=7.5667, p=tgt["body"], ease="in"), dict(t=7.66, ang=(0.6, 1.6)),
          dict(t=7.85, ang=(0.5, 1.9)), dict(t=8.60, ang=GUARD_R), dict(t=9.10, ang=RELAX_R), dict(t=9.40, ang=RELAX_R)]
    return dict(body=body, f_foot=f, r_foot=r, f_hand=fh, r_hand=rh)


def build_scene():
    from stickfig import skit
    base = skit.build_skit(dict(name="shot_fight01", stage="dojo", mood="battle", background=BG,
                                actors=dict(A=dict(color=[0.5, 0.85, 0.3], x=0.0), B=dict(color=[0.92, 0.32, 0.28], x=0.0)), props={}, beats=[dict(act="wait", dur=T_END)]))
    aA = dict(base["actors"]["A"], springs=False, plant=False)
    aB = dict(base["actors"]["B"], springs=False, plant=False)
    # 当たる位置: 1 回目は見積もり → 焼いた体から取り直して 2 回焼く
    tgt = dict(kick_b=(-0.05, 1.18), hook_a=(0.25, 1.62), hook_b=(-0.55, 1.50), hook2=(-0.50, 1.55), clash=(0.07, 1.32),
               jab=(0.60, 1.58), upper=(0.40, 1.50), upper_follow=(0.42, 1.80), backkick=(0.45, 1.15), body=(0.20, 0.98),
               palm=(0.00, 1.45), palm_follow=(0.25, 1.50))
    rep = []
    for it in range(3):
        kb = ks.bake(tracks_b(tgt), aB, FPS, T_END, holds=HOLDS_B)
        ka = ks.bake(tracks_a(tgt), aA, FPS, T_END, report=(rep if it == 2 else None), holds=HOLDS_A)
        sa = lambda t: skel(ka, aA, t)
        sb = lambda t: skel(kb, aB, t)
        jab_head = face(sb(1.10), -1)
        tgt["jab"] = (jab_head[0] - 0.16, jab_head[1] - 0.04)                     # 空振り: 反った顔の 0.16 手前
        tgt["upper"] = chin(sb(1.8667), -1)
        tgt["upper_follow"] = (tgt["upper"][0] + 0.03, tgt["upper"][1] + 0.28)
        fa_ = sa(3.22)["front_arm"]
        tgt["kick_b"] = (fa_[-3][0] + 0.06, fa_[-3][1])                           # 前蹴り: 緑の前の腕(前腕の中ほど)
        ha = sa(1.58)["head"]
        tgt["hook_a"], tgt["hook_b"] = (ha[0] + 0.55, ha[1] + 0.42), (ha[0] - 0.35, ha[1] + 0.38)   # 大振りは、しゃがんだ頭の 0.4 上を通る
        tgt["backkick"] = chest(sb(3.8667))
        tgt["clash"] = (round((sa(6.95)["neck"][0] + sb(6.95)["neck"][0]) / 2, 3), 1.32)
        h2 = sa(7.40)["head"]
        tgt["hook2"] = (h2[0] - 0.1, h2[1] + 0.42)
        tgt["body"] = belly(sb(7.5667))
        tgt["palm"] = face(sb(7.8667), -1)
        tgt["palm_follow"] = (tgt["palm"][0] + 0.22, tgt["palm"][1] + 0.06)
    for k in ("jab", "upper", "kick_b", "backkick", "clash", "body", "palm"):
        print(f"  当たり {k}: {tuple(round(v, 2) for v in tgt[k])}")
    base["actors"]["A"], base["actors"]["B"] = aA, aB
    base["keys"] = dict(A=ka, B=kb)
    base["tau_end"] = T_END
    base["footwork"] = None
    H = lambda tau, kind, pos, hold=0.0, by=None: dict(tau=tau, hold=hold, kind=kind, pos=[round(pos[0], 3), round(pos[1], 3)], **({"by": by} if by else {}))
    base["hits"] = [H(1.08, "miss", tgt["jab"]), H(1.55, "miss", tgt["hook_b"]),
                    H(1.8667, "hit", tgt["upper"], 0.12), H(3.22, "clash", tgt["kick_b"], 0.07),
                    H(3.8667, "kick", tgt["backkick"], 0.14), H(4.38, "land", (2.42, 0.2), 0.04), H(4.54, "land", (2.66, 0.2), 0.02),
                    H(6.95, "clash", tgt["clash"], 0.14), H(7.40, "miss", tgt["hook2"]),
                    H(7.5667, "hit", tgt["body"], 0.06), H(7.8667, "hit", tgt["palm"], 0.12), H(8.30, "land", (1.55, 0.1), 0.03)]
    base["puffs"] = [dict(tau=3.30, kind="land2", pos=[-0.3, 0.0]), dict(tau=3.50, kind="land2", pos=[-0.8, 0.0]),
                     dict(tau=4.38, kind="land2", pos=[2.42, 0.0]), dict(tau=4.54, kind="land2", pos=[2.66, 0.0]), dict(tau=4.75, kind="land2", pos=[2.9, 0.0]),
                     dict(tau=7.20, kind="land2", pos=[0.0, 0.0]), dict(tau=8.30, kind="land2", pos=[1.55, 0.0])]
    base["fx"]["flashes"] = [1.8667, 3.8667, 6.95, 7.8667]
    base["slow"] = [dict(start=1.82, end=1.95, rate=0.5), dict(start=3.82, end=3.98, rate=0.5), dict(start=7.82, end=7.95, rate=0.5)]
    base["shots"] = [dict(t=0.0, follow="mid", scale=3.4, yaw=-5.0, pitch=3.0, lens=40.0, target_z=1.0, lag=0.25),
                     dict(t=1.45, follow="mid", scale=2.6, yaw=16.0, pitch=2.0, lens=36.0, target_z=0.9, lag=0.0),
                     dict(t=1.80, follow="B", scale=2.3, yaw=-22.0, pitch=-5.0, lens=34.0, target_z=1.1, lag=0.0),       # アッパー: 下から
                     dict(t=2.45, follow="mid", scale=3.2, yaw=-4.0, pitch=3.0, lens=40.0, target_z=1.0, lag=0.2),
                     dict(t=3.12, follow="A", scale=2.5, yaw=24.0, pitch=2.0, lens=36.0, target_z=1.0, lag=0.0),         # 蹴りを受ける
                     dict(t=3.60, follow="mid", scale=4.2, yaw=-6.0, pitch=3.0, lens=40.0, target_z=0.9, lag=0.3),       # 回し蹴り〜吹き飛び: 引き
                     dict(t=4.85, follow="B", scale=2.8, yaw=-16.0, pitch=3.0, lens=36.0, target_z=0.8, lag=0.1),        # 起き上がる
                     dict(t=6.30, follow="mid", scale=3.8, yaw=-4.0, pitch=3.0, lens=40.0, target_z=1.0, lag=0.2),
                     dict(t=6.90, follow="mid", scale=2.4, yaw=8.0, pitch=1.0, lens=34.0, target_z=1.2, lag=0.0),         # 拳がぶつかる
                     dict(t=7.25, follow="mid", scale=3.0, yaw=-6.0, pitch=3.0, lens=40.0, target_z=0.9, lag=0.1),
                     dict(t=7.82, follow="B", scale=2.6, yaw=-18.0, pitch=2.0, lens=34.0, target_z=1.1, lag=0.0),        # 掌底
                     dict(t=8.25, follow="mid", scale=3.4, yaw=-5.0, pitch=4.0, lens=40.0, target_z=0.8, lag=0.3)]
    base["shots"] = ks.cut_plan(BEATS, base["shots"])
    base["fx"]["invert"] = ["kick", "clash"]
    base["fx"]["speed_lines"] = [[1.78, 1.98], [3.76, 4.40], [6.40, 6.97], [7.44, 7.60], [7.80, 8.00]]
    base["impact_cuts"] = dict(kinds=["kick", "clash"], hold=0.2,
                               angles=[dict(yaw=35, pitch=4, scale=3.0, lens=28, hue=0), dict(yaw=-40, pitch=-6, scale=2.6, lens=26, dutch=6.0, hue=1)],
                               per_kind=dict(clash=[dict(yaw=28, pitch=2, scale=2.4, lens=30, hue=3)]))
    base["anime"] = dict(base["anime"], trails=True, zoom_blur=True, roll=True)
    base["stepping"] = dict(hold=2, ones_around_hits=7, hold_camera=True)   # 当たりの前後 7 コマは 1 コマ打ち(同じ絵が続く割合を参考の 33% 以下に)
    base["name"] = "shot_fight01"
    return base, rep


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="out/shot_fight01")
    ap.add_argument("--preview", action="store_true")
    ap.add_argument("--plan-only", action="store_true")
    ap.add_argument("--check", action="store_true", help="アニメ調の点検だけ(書き出し済みの動画があれば同じ絵の割合も)")
    a = ap.parse_args()
    from stickfig import cli, plan as pm
    sc, rep = build_scene()
    print("IK の残差(0.02 超):", rep[:1], len(rep) - 1, "件", rep[1:10])
    out = Path(a.out)
    out.mkdir(parents=True, exist_ok=True)
    if a.check:
        import json as _j
        from stickfig import animecheck
        pl = pm.build_plan(sc)
        vid = out / "shot_fight01.mp4"
        print(animecheck.report(animecheck.check(sc, pl, BEATS, str(vid) if vid.exists() else None)))
        return
    if a.plan_only:
        pl = pm.build_plan(sc)
        pm.save_plan(pl, out / "plan.json")
        print(out / "plan.json")
    elif a.preview:
        from stickfig import preview
        print(preview.preview_scene(sc, out / "preview.mp4", cli.find_ffmpeg()))
    else:
        print(cli.build_scene(sc, out))


if __name__ == "__main__":
    main()

"""勝ち抜き戦 準決勝「緑 vs 紫(巨漢)」(約 10 秒、素手)。紫は体 1.25 倍(keyshot の scale)。

振り付け:
  0.00-1.00 構え合う(紫は動かず、両腕を広げて見下ろす)
  1.00-1.80 緑が踏み込んで腹に一発 → 紫はびくともしない(効かない)。緑は拳を見て下がる
  1.80-3.30 紫の溜めの長い大振り → 緑は両腕で受けるが吹き飛び、背中から落ちて滑る(ピンチ)
  3.30-5.30 紫が重い足取りで 2 歩詰め、両腕を上げて力こぶ。緑は起き上がる
  5.30-6.00 緑が顎をぬぐい、構え直す
  6.00-6.95 緑が走り込む → 紫の大振りを深くくぐる(空振り)
  6.95-7.70 懐で腹に一発(紫が体を折る)→ 伸び上がってアッパー(顎が跳ねる)
  7.70-8.60 沈んで足払い → 巨体の両足が浮き、背中から落ちる(ズシン)
  8.60-10.2 緑は払い抜けた形で止まり、立って構えを解く。紫は目を回す

使い方: python tools/shots/bout_sf.py --out out/bout_sf [--preview] [--plan-only] [--check]
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from stickfig import bout, keyshot as ks  # noqa: E402
from stickfig.bout import GUARD_F, GUARD_R, RELAX_F, RELAX_R, FPS, H  # noqa: E402

NAME = "bout_sf"
T_END = 10.2
GIANT = 1.25
BG = dict(image="assets/bg/riverside.png", x0=-8.5, x1=8.0, ground=0.80)
F = 0.65                                                             # A の止め絵のぶんの遅れ
HOLDS_A = [dict(kind="windup", t=1.30, hold=3, burst=3), dict(kind="windup", t=7.25, hold=3, burst=3), dict(kind="windup", t=7.5667, hold=4, burst=3),
           dict(kind="windup", t=7.9667, hold=5, burst=3), dict(kind="freeze", t0=8.07, t1=8.07 + F)]
HOLDS_B = [dict(kind="windup", t=2.20, hold=6, burst=4), dict(kind="windup", t=6.90, hold=4, burst=3)]
BEATS = [dict(t=1.30, by="A", to="B", limb="rst", absorb=True), dict(t=2.20, by="B", to="A", big=True, limb="rst"),
         dict(t=6.90, by="B", to="A", limb="rst", miss=True), dict(t=7.25, by="A", to="B", limb="rst"),
         dict(t=7.5667, by="A", to="B", limb="st"), dict(t=7.9667, by="A", to="B", big=True, limb="rlst")]


# ---------------- 紫(B、左向き、体 1.25 倍。hz は体の寸法での値、x と足・手の目標は世界)----------------
def tracks_b(tgt):
    body = [
        dict(t=0.00, x=0.75, hz=0.80, lean=0.12, ht=0.0, dir=-1, face="fight"),
        dict(t=0.50, hz=0.78), dict(t=1.00, hz=0.80),
        # 腹を打たれても動かない(少し見下ろすだけ)
        dict(t=1.30, x=0.75, lean=0.12, ht=0.0), dict(t=1.40, lean=0.10, ht=0.06), dict(t=1.58, lean=0.18, ht=-0.14), dict(t=1.78, lean=0.12, ht=0.0),
        # 溜めの長い大振り
        dict(t=1.86, x=0.75, hz=0.80, lean=0.0), dict(t=1.98, hz=0.78, lean=-0.14, rst=0.0), dict(t=2.20, x=0.45, hz=0.78, lean=0.45, rst=0.32, ease="in"),
        dict(t=2.32, lean=0.38, rst=0.0), dict(t=2.60, x=0.45, hz=0.80, lean=0.12),
        # 重い足取りで 2 歩
        dict(t=3.30, x=0.45, hz=0.80), dict(t=3.60, x=0.33, hz=0.76, ease="inout"), dict(t=3.75, hz=0.80), dict(t=4.10, x=0.08, hz=0.76), dict(t=4.25, hz=0.80),
        # 力こぶ
        dict(t=4.45, lean=0.12, ht=0.0), dict(t=4.70, lean=-0.10, ht=0.25), dict(t=5.05, lean=-0.10, ht=0.25), dict(t=5.30, lean=0.12, ht=0.0),
        # 走り込む緑に大振り(空振り)
        dict(t=6.45, x=0.08, hz=0.80, lean=0.12), dict(t=6.60, hz=0.78, lean=-0.05, rst=0.0), dict(t=6.90, x=0.12, hz=0.78, lean=0.42, rst=0.30, ease="in"),
        dict(t=7.02, lean=0.46, rst=0.0), dict(t=7.25, x=0.12, lean=0.40, hz=0.80),
        # 腹 → 体を折る
        dict(t=7.35, x=0.74, lean=0.72, hz=0.72, ht=-0.35, ease="out"), dict(t=7.48, x=0.72, lean=0.66, hz=0.73),
        # アッパー → 顎が跳ねる
        dict(t=7.5667, x=0.72, lean=0.66, hz=0.73, ht=-0.35), dict(t=7.65, x=0.78, hz=0.84, rz=0.06, lean=-0.35, ht=0.85, ease="out"),
        dict(t=7.82, x=0.72, hz=0.83, rz=0.0, lean=-0.20, ht=0.40),
        # 足払い → 両足が浮き、背中から落ちる
        dict(t=7.9667, x=0.70, hz=0.83, lean=-0.20, ht=0.35, rz=0.0, roll=0.0),
        dict(t=8.06, x=0.85, rz=0.40, roll=0.60, lean=-0.25, ht=0.25, ease="out"), dict(t=8.24, x=1.15, rz=0.50, roll=1.25),
        dict(t=8.40, x=1.40, rz=0.30, roll=1.57, lean=0.0, ht=0.0, ease="in"), dict(t=8.48, rz=0.42, ease="out"), dict(t=8.56, rz=0.30, ease="in"),
        # 目を回す
        dict(t=9.00, ht=-0.22), dict(t=9.40, ht=0.20), dict(t=9.80, ht=-0.15), dict(t=10.2, ht=0.10),
    ]
    f = [dict(t=0.00, p=(0.30, 0)), dict(t=2.00, p=(0.30, 0)), dict(t=2.18, p=(0.00, 0), lift=0.05),
         dict(t=3.32, p=(0.00, 0)), dict(t=3.58, p=(-0.32, 0), lift=0.07),
         dict(t=6.55, p=(-0.32, 0)), dict(t=6.86, p=(-0.35, 0), lift=0.05),
         dict(t=7.25, p=(-0.35, 0)), dict(t=7.40, p=(0.12, 0), lift=0.03), dict(t=7.9667, p=(0.12, 0)), dict(t=8.06, ang=(1.5, 0.3)), dict(t=8.24, ang=(1.2, 0.2)), dict(t=8.40, ang=(0.3, 0.2)), dict(t=10.2, ang=(0.25, 0.2))]
    r = [dict(t=0.00, p=(1.20, 0)), dict(t=2.20, p=(1.20, 0)), dict(t=2.38, p=(0.90, 0), lift=0.05),
         dict(t=3.85, p=(0.90, 0)), dict(t=4.10, p=(0.50, 0), lift=0.07),
         dict(t=6.62, p=(0.50, 0)), dict(t=7.30, p=(0.50, 0)), dict(t=7.42, p=(0.98, 0), lift=0.04),
         dict(t=7.9667, p=(0.98, 0)), dict(t=8.06, ang=(0.9, 0.4)), dict(t=8.40, ang=(0.1, 0.2)), dict(t=10.2, ang=(0.1, 0.2))]
    fh = [dict(t=0.00, ang=GUARD_F), dict(t=1.86, ang=GUARD_F), dict(t=2.20, ang=(0.5, 1.0)), dict(t=2.60, ang=GUARD_F),
          dict(t=4.45, ang=GUARD_F), dict(t=4.70, ang=(2.7, 1.7)), dict(t=5.05, ang=(2.7, 1.7)), dict(t=5.30, ang=GUARD_F),
          dict(t=6.60, ang=GUARD_F), dict(t=6.90, ang=(0.4, 1.0)), dict(t=7.10, ang=(0.5, 1.0)), dict(t=7.35, ang=(0.3, 0.5)),
          dict(t=7.5667, ang=(0.3, 0.5)), dict(t=7.65, ang=(2.2, 0.6)), dict(t=8.06, ang=(2.6, 0.4)), dict(t=8.40, ang=(2.8, 0.3)), dict(t=10.2, ang=(2.8, 0.3))]
    rh = [dict(t=0.00, ang=GUARD_R), dict(t=1.86, ang=GUARD_R), dict(t=1.98, ang=(-0.8, 1.6)), dict(t=2.20, p=tgt["swing"], ease="in"), dict(t=2.32, ang=(0.3, 0.6)), dict(t=2.60, ang=GUARD_R),
          dict(t=4.45, ang=GUARD_R), dict(t=4.70, ang=(2.7, 1.7)), dict(t=5.05, ang=(2.7, 1.7)), dict(t=5.30, ang=GUARD_R),
          dict(t=6.45, ang=GUARD_R), dict(t=6.60, ang=(-0.8, 1.6)), dict(t=6.90, p=tgt["swing2"], ease="in"), dict(t=7.05, ang=(1.6, 0.3)), dict(t=7.35, ang=(0.4, 0.5)),
          dict(t=7.5667, ang=(0.4, 0.5)), dict(t=7.65, ang=(2.0, 0.6)), dict(t=8.06, ang=(2.4, 0.4)), dict(t=8.40, ang=(2.6, 0.3)), dict(t=10.2, ang=(2.6, 0.3))]
    return dict(body=body, f_foot=f, r_foot=r, f_hand=fh, r_hand=rh)


# ---------------- 緑(A、右向き)----------------
def tracks_a(tgt):
    body = [
        dict(t=0.00, x=-0.85, hz=0.80, lean=0.12, ht=0.0, dir=1, face="fight"),
        dict(t=0.55, x=-0.85), dict(t=0.75, x=-0.70, hz=0.78), dict(t=0.95, hz=0.80),
        # 腹に一発(効かない)
        dict(t=1.10, x=-0.68, hz=0.76, lean=0.04, rst=0.0), dict(t=1.30, x=-0.12, hz=0.74, lean=0.45, rst=0.30, ease="in"), dict(t=1.42, lean=0.35, rst=0.0),
        dict(t=1.60, x=-0.22, lean=0.15, ht=-0.18), dict(t=1.82, x=-0.65, hz=0.80, lean=0.12, ht=0.0),
        # 両腕で受けて吹き飛ぶ
        dict(t=2.05, x=-0.65, hz=0.78, lean=0.15), dict(t=2.20, x=-0.65, hz=0.78, lean=0.15, rz=0.0, roll=0.0, ht=0.0),
        dict(t=2.28, x=-1.30, rz=0.30, roll=0.40, lean=-0.50, ht=0.50, ease="out"), dict(t=2.45, x=-2.20, rz=0.55, roll=1.10),
        dict(t=2.65, x=-2.90, rz=0.21, roll=1.57, lean=0.0, ht=0.0, ease="in"), dict(t=2.72, x=-3.00, rz=0.34, ease="out"), dict(t=2.80, x=-3.10, rz=0.21, ease="in"),
        dict(t=3.20, x=-3.45, rz=0.21, roll=1.57, ease="out"),
        # 起き上がる
        dict(t=4.20, x=-3.45, rz=0.21, roll=1.57), dict(t=4.50, rz=0.24, roll=1.05, hz=0.55, lean=0.20),
        dict(t=4.80, rz=0.18, roll=0.40, hz=0.48, lean=0.55), dict(t=5.10, rz=0.0, roll=0.0, hz=0.72, lean=0.30), dict(t=5.30, hz=0.80, lean=0.12, x=-3.45),
        # 顎をぬぐって構え直す
        dict(t=5.45, ht=-0.15), dict(t=5.75, ht=0.05), dict(t=5.95, ht=0.0),
        # 走り込んでくぐる
        dict(t=6.05, x=-3.45, hz=0.78, lean=0.35), dict(t=6.55, x=-1.40, hz=0.78, lean=0.35, ease="linear"),
        dict(t=6.75, x=-1.32, hz=0.49, lean=0.50, ht=-0.10, ease="out"), dict(t=6.98, hz=0.49, lean=0.50),
        # 懐で腹
        dict(t=7.08, x=-1.22, hz=0.48, lean=0.45, rst=0.0), dict(t=7.25, x=-0.90, hz=0.50, lean=0.40, rst=0.30, ease="in"), dict(t=7.35, rst=0.0),
        # アッパー
        dict(t=7.42, x=-0.92, hz=0.48, lean=0.42, st=0.0), dict(t=7.5667, x=-0.70, hz=0.86, lean=0.05, ht=0.15, st=0.32, ease="in"), dict(t=7.66, st=0.0, lean=-0.05),
        # 沈んで足払い
        dict(t=7.74, x=-0.65, hz=0.70, lean=0.10, ht=0.0), dict(t=7.85, x=-0.72, hz=0.47, lean=0.45, rlst=0.0),
        dict(t=7.9667, x=-0.78, hz=0.46, lean=0.40, rlst=0.34, ease="in"), dict(t=8.07, hz=0.53, lean=0.30, rlst=0.20),
        # (ここから止め絵の F 秒ぶん遅れて読む)立って構えを解く
        dict(t=9.10 - F, x=-0.75, hz=0.80, lean=0.12, rlst=0.0, ease="inout"), dict(t=9.65 - F, hz=0.84, lean=0.05), dict(t=10.2 - F, hz=0.84, lean=0.05),
    ]
    f = [dict(t=0.00, p=(-0.55, 0)), dict(t=0.60, p=(-0.55, 0)), dict(t=0.75, p=(-0.40, 0), lift=0.04),
         dict(t=1.12, p=(-0.40, 0)), dict(t=1.30, p=(0.12, 0), lift=0.05), dict(t=1.48, p=(0.12, 0)), dict(t=1.78, p=(-0.35, 0), lift=0.04),
         dict(t=2.20, p=(-0.35, 0)), dict(t=2.28, ang=(1.0, 0.6)), dict(t=2.65, ang=(0.3, 0.2)), dict(t=4.20, ang=(0.3, 0.2)),
         dict(t=4.50, ang=(1.2, 1.6)), dict(t=4.80, p=(-3.10, 0)), dict(t=6.05, p=(-3.10, 0)),
         dict(t=6.20, p=(-2.30, 0), lift=0.10), dict(t=6.40, p=(-2.30, 0)), dict(t=6.56, p=(-0.98, 0), lift=0.10),
         dict(t=7.10, p=(-0.98, 0)), dict(t=7.24, p=(-0.62, 0), lift=0.03),
         dict(t=7.44, p=(-0.62, 0)), dict(t=7.56, p=(-0.38, 0), lift=0.03), dict(t=7.84, p=(-0.38, 0)), dict(t=7.92, p=(-0.20, 0.06), lift=0.02), dict(t=8.80 - F, p=(-0.20, 0.06)), dict(t=9.10 - F, p=(-0.45, 0), lift=0.05), dict(t=10.2, p=(-0.45, 0))]
    r = [dict(t=0.00, p=(-1.10, 0)), dict(t=0.62, p=(-1.10, 0)), dict(t=0.78, p=(-0.95, 0), lift=0.04),
         dict(t=1.12, p=(-0.95, 0)), dict(t=1.26, p=(-0.55, 0), lift=0.04), dict(t=1.50, p=(-0.55, 0)), dict(t=1.80, p=(-0.95, 0), lift=0.04),
         dict(t=2.20, p=(-0.95, 0)), dict(t=2.28, ang=(-0.4, 0.6)), dict(t=2.65, ang=(0.1, 0.2)), dict(t=4.20, ang=(0.1, 0.2)),
         dict(t=4.50, ang=(1.0, 1.8)), dict(t=4.80, p=(-3.75, 0)), dict(t=6.10, p=(-3.75, 0)),
         dict(t=6.30, p=(-1.90, 0), lift=0.12), dict(t=6.62, p=(-1.90, 0)), dict(t=6.75, p=(-1.72, 0), lift=0.03),
         dict(t=7.42, p=(-1.72, 0)), dict(t=7.54, p=(-1.05, 0), lift=0.04),
         dict(t=7.72, p=(-1.05, 0)), dict(t=7.86, p=(-1.30, 0.10)), dict(t=7.9667, p=tgt["sweep"], ease="in"), dict(t=8.07, p=(tgt["sweep"][0] + 0.25, 0.12)),
         dict(t=8.80 - F, p=(tgt["sweep"][0] + 0.25, 0.12)), dict(t=9.10 - F, p=(-1.00, 0), lift=0.06), dict(t=10.2 - F, p=(-1.55, 0))]
    fh = [dict(t=0.00, ang=GUARD_F), dict(t=1.12, ang=GUARD_F), dict(t=1.30, ang=(1.3, 1.9)), dict(t=1.62, ang=GUARD_F),
          dict(t=2.05, ang=GUARD_F), dict(t=2.14, ang=(1.55, 1.95)), dict(t=2.20, ang=(1.55, 1.95)), dict(t=2.28, ang=(2.4, 0.4)), dict(t=2.65, ang=(2.6, 0.3)), dict(t=4.20, ang=(2.6, 0.3)),
          dict(t=4.50, ang=(0.4, 0.4)), dict(t=4.80, ang=(0.5, 0.3)), dict(t=5.10, ang=(0.6, 0.4)), dict(t=5.30, ang=GUARD_F),
          dict(t=5.45, ang=(1.6, 2.4)), dict(t=5.72, ang=(1.2, 2.6)), dict(t=5.95, ang=GUARD_F),
          dict(t=6.10, ang=(0.9, 1.4)), dict(t=6.55, ang=(1.3, 1.6)), dict(t=6.75, ang=(1.35, 1.9)), dict(t=7.25, ang=(1.3, 1.9)),
          dict(t=7.42, ang=(0.6, 1.9)), dict(t=7.5667, p=tgt["upper"], ease="in"), dict(t=7.66, p=tgt["upper_follow"]),
          dict(t=7.84, ang=(0.6, 1.0)), dict(t=7.9667, ang=(0.35, 0.3)), dict(t=8.07, ang=(0.30, 0.3)),
          dict(t=9.10 - F, ang=GUARD_F), dict(t=9.65 - F, ang=RELAX_F), dict(t=10.2 - F, ang=RELAX_F)]
    rh = [dict(t=0.00, ang=GUARD_R), dict(t=1.10, ang=(0.6, 2.2)), dict(t=1.30, p=tgt["body1"], ease="in"), dict(t=1.42, ang=(0.9, 1.9)), dict(t=1.62, ang=GUARD_R),
          dict(t=2.05, ang=GUARD_R), dict(t=2.14, ang=(1.40, 1.95)), dict(t=2.20, ang=(1.40, 1.95)), dict(t=2.28, ang=(2.2, 0.5)), dict(t=2.65, ang=(2.4, 0.3)), dict(t=4.20, ang=(2.4, 0.3)),
          dict(t=4.50, ang=(0.3, 0.4)), dict(t=5.10, ang=(0.5, 0.4)), dict(t=5.30, ang=GUARD_R),
          dict(t=6.10, ang=(-0.6, 1.4)), dict(t=6.55, ang=GUARD_R), dict(t=6.75, ang=(1.1, 2.2)),
          dict(t=7.08, ang=(0.2, 1.8)), dict(t=7.25, p=tgt["body2"], ease="in"), dict(t=7.35, ang=(0.6, 1.6)), dict(t=7.5667, ang=(-0.4, 1.8)),
          dict(t=7.84, ang=(1.2, 1.0)), dict(t=7.9667, ang=(1.7, 0.5)), dict(t=8.07, ang=(1.75, 0.5)),
          dict(t=9.10 - F, ang=GUARD_R), dict(t=9.65 - F, ang=RELAX_R), dict(t=10.2 - F, ang=RELAX_R)]
    return dict(body=body, f_foot=f, r_foot=r, f_hand=fh, r_hand=rh)


def build():
    actors = dict(A=dict(color=[0.5, 0.85, 0.3]), B=dict(color=[0.62, 0.35, 0.85], scale=GIANT))
    base = bout.new_scene(NAME, BG, T_END, actors)
    aA, aB = base["actors"]["A"], base["actors"]["B"]
    tgt = dict(body1=(0.67, 1.20), swing=(-0.50, 1.40), swing2=(-0.70, 1.65), body2=(-0.30, 1.20), upper=(-0.60, 1.75), upper_follow=(-0.57, 2.03), sweep=(-0.55, 0.08))
    rep, repb = [], []
    for it in range(3):
        kb = ks.bake(ks.widen_stance(bout.stylize(tracks_b(tgt), "giant"), scale=GIANT), aB, FPS, T_END, report=(repb if it == 2 else None), holds=HOLDS_B)
        ka = ks.bake(ks.widen_stance(bout.stylize(tracks_a(tgt), "kenpo")), aA, FPS, T_END, report=(rep if it == 2 else None), holds=HOLDS_A)
        sa = lambda t: bout.skel(ka, aA, t)
        sb = lambda t: bout.skel(kb, aB, t)
        tgt["body1"] = bout.surface(bout.belly(sb(1.30)), -1, 0.12)
        fa_ = sa(2.20)["front_arm"]
        tgt["swing"] = (fa_[-3][0] + 0.06, fa_[-3][1])                           # 受けた緑の前腕
        h = sa(6.90)["head"]
        tgt["swing2"] = (h[0] + 0.05, h[1] + 0.45)                               # くぐった頭の 0.45 上を通る
        tgt["body2"] = bout.surface(bout.belly(sb(7.25)), -1, 0.12)
        tgt["upper"] = bout.chin(sb(7.5667), -1)
        tgt["upper_follow"] = (tgt["upper"][0] + 0.03, tgt["upper"][1] + 0.28)
        ft = sb(7.9667)["front_leg"][-1]
        tgt["sweep"] = (ft[0] - 0.04, 0.08)                                     # 紫の前の足首
    print("  紫の IK の残差:", repb[:1], len(repb) - 1, "件", repb[1:8])
    for k in ("body1", "swing", "swing2", "body2", "upper", "sweep"):
        print(f"  当たり {k}: {tuple(round(v, 2) for v in tgt[k])}")
    hits = [H(1.30, "hit", tgt["body1"], 0.05), H(2.20, "kick", tgt["swing"], 0.16), H(2.65, "land", (-2.9, 0.2), 0.04),
            H(6.90, "miss", tgt["swing2"]), H(7.25, "hit", tgt["body2"], 0.06), H(7.5667, "hit", tgt["upper"], 0.08),
            H(7.9667, "kick", tgt["sweep"], 0.14), H(8.40, "land", (1.25, 0.2), 0.06)]
    puffs = [dict(tau=2.65, kind="land2", pos=[-2.9, 0.0]), dict(tau=3.20, kind="land2", pos=[-3.4, 0.0]),
             dict(tau=3.58, kind="land2", pos=[-0.32, 0.0]), dict(tau=4.10, kind="land2", pos=[0.50, 0.0]),
             dict(tau=8.40, kind="land2", pos=[1.25, 0.0]), dict(tau=8.42, kind="land2", pos=[1.9, 0.0])]
    shots = [dict(t=0.0, follow="mid", scale=3.6, yaw=-5.0, pitch=-3.0, lens=40.0, target_z=1.1, lag=0.25),
             dict(t=2.80, follow="A", scale=4.4, yaw=-5.0, pitch=3.0, lens=40.0, target_z=0.8, lag=0.3),        # 吹き飛ぶ緑
             dict(t=3.40, follow="B", scale=3.4, yaw=-10.0, pitch=-9.0, lens=36.0, target_z=1.4, lag=0.2),      # 迫る巨体を下から
             dict(t=4.45, follow="B", scale=2.7, yaw=12.0, pitch=-9.0, lens=34.0, target_z=1.6, lag=0.0),       # 力こぶ
             dict(t=5.30, follow="A", scale=2.6, yaw=16.0, pitch=2.0, lens=36.0, target_z=1.0, lag=0.1),        # 顎をぬぐう
             dict(t=6.00, follow="mid", scale=4.2, yaw=-5.0, pitch=2.0, lens=40.0, target_z=1.0, lag=0.15),
             dict(t=8.70, follow="mid", scale=3.6, yaw=-5.0, pitch=4.0, lens=40.0, target_z=0.8, lag=0.3)]
    base = bout.finish(base, dict(A=ka, B=kb), BEATS, shots, hits, puffs=puffs, flashes=[2.20, 7.9667],
                       slow=[dict(start=2.16, end=2.30, rate=0.5), dict(start=7.92, end=8.04, rate=0.5)],
                       speed_lines=[[2.10, 2.50], [6.55, 6.80], [7.85, 8.10]])
    return base, rep


if __name__ == "__main__":
    bout.run_cli(build, BEATS, NAME)

"""勝ち抜き戦 第 1 回戦「緑 vs 青(蹴り使い)」(約 7.5 秒、素手)。stickfig.bout の部品で手付け。

振り付け:
  0.00-1.00 構え合う(青は軽く弾む、緑は半歩詰める)
  1.00-1.45 青の前蹴り → 緑が上体を反らして下がる(空振り)
  1.45-2.10 青の上段回し蹴り → 緑が深くしゃがんでかわす(空振り)。青は蹴り足を前に下ろす
  2.10-2.35 青が跳んで下がり、足を入れ替える
  2.35-3.05 青の中段回し蹴り → 緑が両腕で受け、滑って下がる
  3.05-4.00 青が沈んで跳び蹴り → 緑が前へくぐり、青は緑の頭の上を越えて着地(背中を向けたまま)
  4.00-4.55 緑が振り向いて背中に掌底 → 青は前へ吹き飛び、うつ伏せに落ちて跳ね、滑って画面の外へ
  4.55-7.50 緑は振り抜いた形で止まり、構えを解いて一礼

使い方: python tools/shots/bout_r1.py --out out/bout_r1 [--preview] [--plan-only] [--check]
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from stickfig import bout, keyshot as ks  # noqa: E402
from stickfig.bout import GUARD_F, GUARD_R, RELAX_F, RELAX_R, FPS, H  # noqa: E402

NAME = "bout_r1"
T_END = 7.5
BG = dict(image="assets/bg/dojo.png", x0=-6.5, x1=6.0, ground=0.82)
HOLDS_A = [dict(kind="windup", t=4.40, hold=5, burst=3), dict(kind="freeze", t0=4.52, t1=5.12)]   # 掌底のあと 0.6 秒の止め絵(以降の A のキーは 0.6 秒遅れて読む)
HOLDS_B = [dict(kind="windup", t=1.20, hold=3, burst=3), dict(kind="windup", t=1.80, hold=4, burst=3),
           dict(kind="windup", t=2.70, hold=3, burst=3), dict(kind="windup", t=3.62, hold=4, burst=3)]
BEATS = [dict(t=1.20, by="B", to="A", limb="lst", miss=True), dict(t=1.80, by="B", to="A", limb="rlst", miss=True),
         dict(t=2.70, by="B", to="A", limb="lst"), dict(t=3.62, by="B", to="A", limb="rlst", miss=True),
         dict(t=4.40, by="A", to="B", big=True, limb="st")]
F = 0.6                                                             # A の止め絵のぶんの遅れ


# ---------------- 青(B、左向き)----------------
def tracks_b(tgt):
    body = [
        dict(t=0.00, x=0.80, hz=0.80, lean=0.12, ht=0.0, dir=-1, face="fight"),
        dict(t=0.15, hz=0.76), dict(t=0.30, hz=0.80), dict(t=0.45, hz=0.76), dict(t=0.60, hz=0.80), dict(t=0.75, hz=0.76), dict(t=0.92, hz=0.80, x=0.80),
        # 前蹴り(前の脚)
        dict(t=1.05, x=0.55, hz=0.80, lean=0.0), dict(t=1.12, x=0.50, hz=0.83, lean=-0.20, lst=0.0), dict(t=1.20, x=0.42, hz=0.80, lean=-0.38, lst=0.30, ease="in"),
        dict(t=1.30, x=0.40, lean=-0.25, lst=0.0), dict(t=1.42, x=0.30, hz=0.80, lean=0.0),
        # 上段回し蹴り(後ろの脚)→ 前に下ろす
        dict(t=1.50, x=0.28, hz=0.80, lean=0.05), dict(t=1.65, x=0.12, hz=0.83, lean=-0.35, rlst=0.0), dict(t=1.80, x=0.0, hz=0.83, lean=-0.60, rlst=0.34, ease="in"),
        dict(t=1.92, x=-0.02, lean=-0.45, rlst=0.0), dict(t=2.05, x=-0.05, hz=0.80, lean=-0.05),
        # 跳んで下がる(足を入れ替える)
        dict(t=2.12, x=0.05, hz=0.74, rz=0.0), dict(t=2.20, x=0.30, hz=0.80, rz=0.10, ease="out"), dict(t=2.30, x=0.45, hz=0.80, rz=0.0, lean=0.12, ease="in"),
        # 中段回し蹴り(後ろになった前の脚)
        dict(t=2.45, x=0.40, hz=0.80, lean=0.12), dict(t=2.58, x=0.25, hz=0.83, lean=-0.20, lst=0.0), dict(t=2.70, x=0.10, hz=0.80, lean=-0.45, lst=0.30, ease="in"),
        dict(t=2.80, x=0.22, lean=-0.30, lst=0.0, ease="out"), dict(t=3.00, x=0.55, hz=0.80, lean=0.12),
        # 沈んで跳び蹴り → 緑の上を越えて着地
        dict(t=3.25, x=0.55, hz=0.60, lean=0.30), dict(t=3.38, hz=0.58, lean=0.32),
        dict(t=3.50, x=0.25, hz=0.80, rz=0.55, lean=-0.10, ease="in"), dict(t=3.62, x=-0.30, rz=1.40, lean=-0.35, rlst=0.34, ease="linear"), dict(t=3.72, rlst=0.0),
        dict(t=3.84, x=-1.05, rz=0.85, lean=-0.10), dict(t=3.98, x=-1.65, rz=0.0, hz=0.62, lean=0.35, ease="in"),
        dict(t=4.15, hz=0.66, lean=0.25), dict(t=4.40, x=-1.65, hz=0.74, lean=0.10, ht=-0.06),
        # 背中に掌底 → 前へ吹き飛び、うつ伏せに落ちて転がる
        dict(t=4.47, x=-2.05, hz=0.80, rz=0.12, lean=-0.20, ht=-0.35, ease="out"),
        dict(t=4.60, x=-2.45, rz=0.38, roll=-0.70, lean=0.30, ht=0.0), dict(t=4.75, x=-2.95, rz=0.18, roll=-1.57, lean=0.0, ease="in"),
        dict(t=4.85, x=-3.25, rz=0.30, roll=-1.57, lean=0.0, ease="out"), dict(t=4.95, x=-3.45, rz=0.24, roll=-1.57, ease="in"),   # 1 回跳ねて
        dict(t=5.60, x=-4.70, rz=0.24, roll=-1.57, ease="out"), dict(t=6.20, x=-4.75, rz=0.24, roll=-1.57),                        # うつ伏せのまま滑って画面の外へ
    ]
    f = [dict(t=0.00, p=(0.50, 0)), dict(t=1.05, p=(0.50, 0)), dict(t=1.12, p=(0.40, 0.45)), dict(t=1.20, p=tgt["kick1"], ease="in"), dict(t=1.30, p=tgt["kick1"]),
         dict(t=1.36, p=(0.18, 0.35)), dict(t=1.42, p=(0.05, 0)),
         dict(t=2.10, p=(0.05, 0)), dict(t=2.30, p=(0.80, 0), lift=0.06),
         dict(t=2.45, p=(0.80, 0)), dict(t=2.58, p=(0.40, 0.75)), dict(t=2.70, p=tgt["kick3"], ease="in"), dict(t=2.78, p=(0.05, 0.75)), dict(t=2.95, p=(0.70, 0)),
         dict(t=3.38, p=(0.70, 0)), dict(t=3.50, ang=(1.1, 2.5)), dict(t=3.85, ang=(1.1, 2.5)), dict(t=3.98, p=(-1.40, 0)),
         dict(t=4.40, p=(-1.40, 0)), dict(t=4.47, ang=(-0.3, 0.4)), dict(t=4.75, ang=(0.2, 0.2)), dict(t=4.85, ang=(0.3, 0.5)), dict(t=4.95, ang=(0.2, 0.2))]
    r = [dict(t=0.00, p=(1.05, 0)), dict(t=0.95, p=(1.05, 0)), dict(t=1.05, p=(0.80, 0), lift=0.05),
         dict(t=1.55, p=(0.80, 0)), dict(t=1.68, p=(0.30, 0.85)), dict(t=1.80, p=tgt["kick2"], ease="in"), dict(t=1.92, p=(-0.35, 0.90)), dict(t=2.05, p=(-0.40, 0)),
         dict(t=2.10, p=(-0.40, 0)), dict(t=2.30, p=(0.15, 0), lift=0.06),
         dict(t=3.38, p=(0.15, 0)), dict(t=3.50, ang=(1.0, 0.6)), dict(t=3.62, p=tgt["jkick"], ease="in"), dict(t=3.72, ang=(0.9, 0.4)), dict(t=3.85, ang=(0.5, 0.8)), dict(t=3.98, p=(-1.95, 0)),
         dict(t=4.40, p=(-1.95, 0)), dict(t=4.47, ang=(0.4, 0.3)), dict(t=4.75, ang=(0.1, 0.2)), dict(t=4.85, ang=(0.0, 0.6)), dict(t=4.95, ang=(0.1, 0.2))]
    fh = [dict(t=0.00, ang=GUARD_F), dict(t=1.12, ang=GUARD_F), dict(t=1.20, ang=(0.4, 0.8)), dict(t=1.42, ang=GUARD_F),
          dict(t=1.65, ang=GUARD_F), dict(t=1.80, ang=(2.2, 0.5)), dict(t=2.05, ang=GUARD_F),
          dict(t=2.58, ang=GUARD_F), dict(t=2.70, ang=(2.0, 0.6)), dict(t=2.95, ang=GUARD_F),
          dict(t=3.38, ang=(0.3, 0.6)), dict(t=3.62, ang=(2.4, 0.5)), dict(t=3.98, ang=(1.2, 0.8)), dict(t=4.40, ang=GUARD_F),
          dict(t=4.47, ang=(-1.2, 0.4)), dict(t=4.75, ang=(2.9, 0.3)), dict(t=4.85, ang=(2.5, 0.6)), dict(t=4.95, ang=(3.05, 0.05))]
    rh = [dict(t=0.00, ang=GUARD_R), dict(t=1.12, ang=GUARD_R), dict(t=1.20, ang=(-0.6, 1.0)), dict(t=1.42, ang=GUARD_R),
          dict(t=1.65, ang=GUARD_R), dict(t=1.80, ang=(-0.9, 0.6)), dict(t=2.05, ang=GUARD_R),
          dict(t=2.58, ang=GUARD_R), dict(t=2.70, ang=(-0.8, 0.7)), dict(t=2.95, ang=GUARD_R),
          dict(t=3.38, ang=(-0.3, 0.6)), dict(t=3.62, ang=(-1.0, 0.6)), dict(t=3.98, ang=(0.8, 0.9)), dict(t=4.40, ang=GUARD_R),
          dict(t=4.47, ang=(-1.4, 0.3)), dict(t=4.75, ang=(2.6, 0.3)), dict(t=4.85, ang=(2.3, 0.6)), dict(t=4.95, ang=(2.95, 0.05))]
    return dict(body=body, f_foot=f, r_foot=r, f_hand=fh, r_hand=rh)


# ---------------- 緑(A、右向き → 跳び蹴りをくぐって左向き)----------------
def tracks_a(tgt):
    body = [
        dict(t=0.00, x=-0.80, hz=0.80, lean=0.12, ht=0.0, dir=1, face="fight"),
        dict(t=0.42, x=-0.80), dict(t=0.62, x=-0.72, hz=0.78), dict(t=0.80, hz=0.80),
        # 前蹴りを反らしてかわす
        dict(t=1.05, x=-0.72, lean=0.12, ht=0.0), dict(t=1.24, x=-0.98, lean=-0.15, ht=0.10, ease="out"), dict(t=1.40, lean=0.0, ht=0.05),
        # しゃがんでかわす
        dict(t=1.55, x=-0.98, hz=0.79, lean=0.10), dict(t=1.72, x=-1.00, hz=0.44, lean=0.45, ht=-0.10, ease="out"), dict(t=1.92, hz=0.44, lean=0.45),
        dict(t=2.18, x=-0.95, hz=0.80, lean=0.12, ht=0.0),
        # 中段を両腕で受け、滑って下がる
        dict(t=2.50, hz=0.79, lean=0.18), dict(t=2.70, x=-0.95, hz=0.79, lean=0.18), dict(t=2.88, x=-1.30, hz=0.77, lean=-0.10, ht=0.12, ease="out"), dict(t=3.02, hz=0.80, lean=0.12, ht=0.0),
        # 前へくぐる
        dict(t=3.30, x=-1.25, hz=0.80, lean=0.12), dict(t=3.45, x=-1.10, hz=0.58, lean=0.42), dict(t=3.66, x=-0.55, hz=0.36, lean=0.75, ht=-0.15, ease="linear"),
        dict(t=3.82, x=-0.40, hz=0.48, lean=0.45),
        # 振り向いて掌底
        dict(t=3.95, x=-0.40, hz=0.68, lean=0.20, dir=-1), dict(t=4.10, x=-0.42, hz=0.80, lean=0.12, ht=0.0),
        dict(t=4.22, x=-0.45, hz=0.76, lean=0.04, st=0.0), dict(t=4.40, x=-0.64, hz=0.78, lean=0.40, st=0.32, ease="in"), dict(t=4.52, lean=0.36, st=0.12),
        # (ここから A のキーは止め絵の 0.6 秒ぶん遅れて読む)構えを解いて一礼
        dict(t=5.30 - F, x=-0.62, hz=0.80, lean=0.12, st=0.0, ease="out"), dict(t=5.80 - F, hz=0.84, lean=0.05),
        dict(t=6.05 - F, hz=0.84, lean=0.05), dict(t=6.40 - F, hz=0.82, lean=0.85, ht=0.20), dict(t=6.75 - F, lean=0.85), dict(t=7.10 - F, hz=0.84, lean=0.05, ht=0.0),
    ]
    f = [dict(t=0.00, p=(-0.50, 0)), dict(t=0.45, p=(-0.50, 0)), dict(t=0.60, p=(-0.40, 0), lift=0.04),
         dict(t=1.05, p=(-0.40, 0)), dict(t=1.24, p=(-0.62, 0), lift=0.03),
         dict(t=2.70, p=(-0.62, 0)), dict(t=2.88, p=(-0.97, 0), lift=0.0, ease="out"),
         dict(t=3.42, p=(-0.97, 0)), dict(t=3.62, p=(-0.25, 0), lift=0.05),
         dict(t=3.95, p=(-0.25, 0)), dict(t=4.08, p=(-0.05, 0), lift=0.03),
         dict(t=4.28, p=(-0.05, 0)), dict(t=4.42, p=(-0.32, 0), lift=0.03), dict(t=7.5, p=(-0.32, 0))]
    r = [dict(t=0.00, p=(-1.05, 0)), dict(t=0.62, p=(-1.05, 0)), dict(t=0.76, p=(-0.95, 0), lift=0.04),
         dict(t=1.05, p=(-0.95, 0)), dict(t=1.24, p=(-1.20, 0), lift=0.03),
         dict(t=2.70, p=(-1.20, 0)), dict(t=2.88, p=(-1.55, 0), lift=0.0, ease="out"),
         dict(t=3.50, p=(-1.55, 0)), dict(t=3.72, p=(-0.95, 0), lift=0.05), dict(t=3.90, p=(-0.80, 0), lift=0.03),
         dict(t=4.24, p=(-0.80, 0)), dict(t=4.40, p=(-1.12, 0), lift=0.04), dict(t=7.5, p=(-1.12, 0))]
    fh = [dict(t=0.00, ang=GUARD_F), dict(t=1.24, ang=GUARD_F), dict(t=1.72, ang=(1.35, 1.9)), dict(t=1.92, ang=(1.35, 1.9)), dict(t=2.18, ang=GUARD_F),
          dict(t=2.55, ang=GUARD_F), dict(t=2.65, ang=(1.55, 1.95)), dict(t=2.88, ang=(1.5, 1.9)), dict(t=3.05, ang=GUARD_F),
          dict(t=3.50, ang=(1.2, 1.8)), dict(t=3.82, ang=(1.2, 1.8)), dict(t=4.10, ang=GUARD_F),
          dict(t=4.24, ang=(0.9, 2.2)), dict(t=4.40, p=tgt["palm"], ease="in"), dict(t=4.52, p=tgt["palm_follow"]),
          dict(t=5.35 - F, ang=GUARD_F), dict(t=5.80 - F, ang=RELAX_F), dict(t=6.40 - F, ang=(0.15, 0.25)), dict(t=6.75 - F, ang=(0.15, 0.25)), dict(t=7.10 - F, ang=RELAX_F)]
    rh = [dict(t=0.00, ang=GUARD_R), dict(t=1.24, ang=GUARD_R), dict(t=1.72, ang=(1.1, 2.2)), dict(t=1.92, ang=(1.1, 2.2)), dict(t=2.18, ang=GUARD_R),
          dict(t=2.55, ang=GUARD_R), dict(t=2.65, ang=(1.40, 1.95)), dict(t=2.88, ang=(1.35, 1.9)), dict(t=3.05, ang=GUARD_R),
          dict(t=3.50, ang=(1.0, 2.0)), dict(t=3.82, ang=(1.0, 2.0)), dict(t=4.10, ang=GUARD_R),
          dict(t=4.24, ang=GUARD_R), dict(t=4.40, ang=(-0.5, 1.8)), dict(t=4.52, ang=(-0.55, 1.8)),
          dict(t=5.35 - F, ang=GUARD_R), dict(t=5.80 - F, ang=RELAX_R), dict(t=6.40 - F, ang=(0.15, 0.25)), dict(t=6.75 - F, ang=(0.15, 0.25)), dict(t=7.10 - F, ang=RELAX_R)]
    return dict(body=body, f_foot=f, r_foot=r, f_hand=fh, r_hand=rh)


def build():
    actors = dict(A=dict(color=[0.5, 0.85, 0.3]), B=dict(color=[0.25, 0.55, 0.95]))
    base = bout.new_scene(NAME, BG, T_END, actors)
    aA, aB = base["actors"]["A"], base["actors"]["B"]
    tgt = dict(kick1=(-0.35, 1.10), kick2=(-0.55, 1.50), kick3=(-0.65, 1.20), jkick=(-1.00, 1.85), palm=(-1.40, 1.15), palm_follow=(-1.62, 1.19))
    rep = []
    for it in range(3):
        kb = ks.bake(ks.widen_stance(bout.stylize(tracks_b(tgt), "kicker")), aB, FPS, T_END, holds=HOLDS_B)
        ka = ks.bake(ks.widen_stance(bout.stylize(tracks_a(tgt), "kenpo")), aA, FPS, T_END, report=(rep if it == 2 else None), holds=HOLDS_A)
        sa = lambda t: bout.skel(ka, aA, t)
        sb = lambda t: bout.skel(kb, aB, t)
        c1 = bout.chest(sa(1.20))
        tgt["kick1"] = (c1[0] + 0.30, c1[1])                                   # 空振り: 反った胸の 0.3 手前
        h2 = sa(1.80)["head"]
        tgt["kick2"] = (h2[0] + 0.05, h2[1] + 0.38)                            # しゃがんだ頭の 0.38 上を通る
        fa_ = sa(2.70)["front_arm"]
        tgt["kick3"] = (fa_[-3][0] + 0.06, fa_[-3][1])                         # 中段: 緑の前の腕(前腕の中ほど)
        bk = bout.chest(sb(4.40))
        tgt["palm"] = (bk[0] + 0.10, bk[1])                                    # 背中(緑は右にいる)
        tgt["palm_follow"] = (tgt["palm"][0] - 0.22, tgt["palm"][1] + 0.04)
    for k in ("kick1", "kick2", "kick3", "palm"):
        print(f"  当たり {k}: {tuple(round(v, 2) for v in tgt[k])}")
    hits = [H(1.20, "miss", tgt["kick1"]), H(1.80, "miss", tgt["kick2"]), H(2.70, "clash", tgt["kick3"], 0.07),
            H(3.62, "miss", tgt["jkick"]), H(4.40, "kick", tgt["palm"], 0.14), H(4.75, "land", (-2.95, 0.2), 0.03)]
    puffs = [dict(tau=2.88, kind="land2", pos=[-1.1, 0.0]), dict(tau=3.98, kind="land2", pos=[-1.55, 0.0]),
             dict(tau=4.75, kind="land2", pos=[-3.05, 0.0]), dict(tau=4.95, kind="land2", pos=[-3.45, 0.0])]
    shots = [dict(t=0.0, follow="mid", scale=3.4, yaw=-5.0, pitch=3.0, lens=40.0, target_z=1.0, lag=0.25),
             dict(t=1.45, follow="mid", scale=2.8, yaw=16.0, pitch=2.0, lens=36.0, target_z=0.9, lag=0.0),
             dict(t=3.10, follow="mid", scale=3.8, yaw=-6.0, pitch=-4.0, lens=40.0, target_z=1.2, lag=0.1),     # 跳び蹴り: 少し下から
             dict(t=4.95, follow="A", scale=4.6, yaw=-5.0, pitch=3.0, lens=40.0, target_z=0.9, lag=0.4),       # 転がって消える青を見送る
             dict(t=5.90, follow="A", scale=3.0, yaw=14.0, pitch=3.0, lens=36.0, target_z=1.0, lag=0.3)]      # 一礼
    base = bout.finish(base, dict(A=ka, B=kb), BEATS, shots, hits, puffs=puffs, flashes=[4.40],
                       slow=[dict(start=3.52, end=3.72, rate=0.5), dict(start=4.36, end=4.50, rate=0.5)],
                       speed_lines=[[3.50, 3.80], [4.30, 4.60]])
    return base, rep


if __name__ == "__main__":
    bout.run_cli(build, BEATS, NAME)

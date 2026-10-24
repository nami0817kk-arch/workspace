"""絵コンテ「3 対 1」(2026-10-24「新しい絵コンテ作って 3 体 1 が良い」→「ストーリーはもっとアニメちっくなバトルに」「1 分以上ね」)。
勝ち抜き戦で倒した 3 人(青・巨漢・赤)が、まとめて緑に仕返しに来る。アニメの戦いの型: 降臨 → 連携技でピンチ → 合体光線 → 覚醒 → 逆転 → とどめの光線。約 72 秒。
いまの動作部品(moves.py)は 1 対 1 しか組めないので、姿勢は IK で手組みしたスケッチ。合意できたら、3 人を相手にできる組み立てを作る。

使い方: python tools/storyboard_3v1.py → out/storyboard3/*.png と panels.json(act=幕の番号)
"""
from __future__ import annotations

import json
import shutil
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import storyboard as sb  # noqa: E402
from stickfig import fk  # noqa: E402

OUT = Path("out/storyboard3")
GUARD = dict(fa=1.05, fe=2.35, ra=0.65, re=2.6)                  # 緑・赤(拳を顔の前)
KICKER = dict(fa=1.45, fe=1.1, ra=0.55, re=2.45)                 # 青(前の手を低く)
GIANT = dict(fa=0.5, fe=0.95, ra=0.3, re=1.15)                   # 巨漢(腕を斜め下に広げる)
BLOCK = dict(fa=1.55, fe=1.95, ra=1.4, re=1.95)                  # 両腕を上げて受ける
RELAX = dict(fa=0.3, fe=0.5, ra=0.25, re=0.6)
TUCK = dict(fa=0.9, fe=1.5, ra=1.0, re=1.6, fl=0.9, fk=1.6, rl=-0.2, rk=1.3)
RUN = dict(fa=-0.5, fe=0.9, ra=0.9, re=0.8, fl=-0.7, fk=0.3, rl=0.9, rk=1.2)
FLY = dict(fa=2.4, fe=0.4, ra=2.2, re=0.5, fl=0.8, fk=1.0, rl=0.2, rk=0.9)     # 吹き飛んで手足が流れる
LIE = dict(fa=2.6, fe=0.3, ra=2.4, re=0.3, fl=0.3, fk=0.2, rl=0.1, rk=0.2)
CROUCH = dict(fl=1.0, fk=1.8, rl=-0.3, rk=1.5)
CHARGE = dict(fa=-0.35, fe=1.7, ra=-0.45, re=1.8)               # 両手を腰の脇に引いて気を溜める
G = 1.25
blue, red, purple = sb.COLORS["B"], sb.COLORS["D"], sb.COLORS["C"]
AURA = (120, 255, 140)
C_BLUE, C_RED, C_PURPLE = (110, 170, 255), (255, 110, 90), (190, 120, 255)
TORII = [(-3.4, 0.28, 2.8), (3.9, 0.28, 2.8)]                    # 境内の柱(場所の手がかり)
items = []


def arc(p0, p1, p2, n=26):
    out = []
    for i in range(n + 1):
        t = i / n
        out.append(((1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t * t * p2[0], (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t * t * p2[1]))
    return out


def add(act: int, name: str, t: float, title: str, text: str, figs, **kw):
    path = OUT / f"{name}.png"
    sb.panel(figs, path, label=f"{t:.0f} 秒  {title}", **kw)
    items.append(dict(act=act, img=f"sb3/{name}.png", t=t, title=title, text=text))


def chest_of(f):
    a, b = fk.skeleton(f["pose"], f["d"], f["x"], f["sc"])["torso"]
    return ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)


def act1():
    a = sb.fig_made("A", 0.0, 1, hz=0.86, lean=0.04, ang=RELAX)
    add(1, "p01_alone", 0, "夕暮れの境内に、緑がひとり", "風だけが吹いている。緑は構えずに立っている。カメラはゆっくり寄る(ここは静かに 3 秒)。",
        [a], speed=[(-1.6, 1.6, -1.0, 1.6), (0.8, 2.0, 1.5, 2.0), (-1.2, 0.4, -0.6, 0.4)], h=360)
    a = sb.fig_made("A", 0.0, 1, hz=0.72, lean=0.25, ht=-0.1, ang=GUARD)
    d = sb.fig_made("D", -2.0, 1, hz=0.55, lean=0.45, ang=dict(GUARD, **CROUCH), color=red)
    b = sb.fig_made("B", 1.9, -1, hz=0.58, lean=0.25, ang=dict(KICKER, **CROUCH), color=blue)
    c = sb.fig_made("C", 3.2, -1, hz=0.56, lean=0.40, scale=G, ang=dict(GIANT, **CROUCH), color=purple)
    gd = sb.fig_made("D", -2.0, 1, hz=0.83, lean=0.0, rz=1.7, ang=TUCK, color=red)
    gb = sb.fig_made("B", 1.9, -1, hz=0.83, lean=0.0, rz=1.8, ang=TUCK, color=blue)
    add(1, "p02_land", 3, "3 人が降り立つ", "屋根の上から、赤・青・巨漢が順に飛び降りて三方に着地。着地ごとに土煙と地面の揺れ。巨漢の着地だけ一段重い(衝撃の輪)。",
        [a, d, b, c], ghosts=[gd, gb], fx=[("dust", -2.0, 0.0, 0.5), ("dust", 1.9, 0.0, 0.5), ("dust", 3.2, 0.0, 0.8)], rings=[(3.2, 0.02, 0.9)], h=420)
    a = sb.fig_made("A", 0.0, 1, hz=0.66, lean=0.30, ht=-0.15, f_foot=(0.40, 0), r_foot=(-0.55, 0), ang=GUARD)
    d = sb.fig_made("D", -1.8, 1, hz=0.74, lean=0.38, ht=-0.2, ang=GUARD, color=red)
    b = sb.fig_made("B", 1.6, -1, hz=0.80, lean=0.05, ang=KICKER, color=blue)
    c = sb.fig_made("C", 3.0, -1, hz=0.78, lean=0.26, scale=G, ang=GIANT, color=purple)
    add(1, "p03_standoff", 6, "にらみ合い", "4 人とも動かない。風で砂が流れる。緑が腰を落として深く構えた瞬間が合図(ここも 2 秒の間)。",
        [a, d, b, c], posts=TORII, speed=[(-1.0, 0.15, -0.3, 0.15), (0.6, 0.1, 1.2, 0.1)], h=380)
    a = sb.fig_made("A", 0.0, 1, hz=0.66, lean=0.30, ht=-0.15, f_foot=(0.40, 0), r_foot=(-0.55, 0), ang=GUARD)
    gd = sb.fig_made("D", -1.8, 1, hz=0.74, lean=0.6, ang=RUN, color=red)
    gb = sb.fig_made("B", 1.6, -1, hz=0.80, lean=0.6, ang=RUN, color=blue)
    gc = sb.fig_made("C", 3.0, -1, hz=0.78, lean=0.6, scale=G, ang=RUN, color=purple)
    add(1, "p04_vanish", 9, "3 人が同時に消える", "3 人が残像だけを残して消える。緑のまわりを、見えない速さの線がぐるりと回る。",
        [a], ghosts=[gd, gb, gc], trails=[arc((-1.6, 0.4), (0.0, 2.6), (1.6, 0.4)), arc((1.6, 0.3), (0.0, -0.1), (-1.6, 0.3))], h=380)
    a = sb.fig_made("A", 0.0, 1, hz=0.70, lean=0.10, ht=0.0, ang=BLOCK)
    d = sb.fig_made("D", -0.95, 1, hz=0.80, lean=0.48, f_hand=(-0.30, 1.45), ang=dict(ra=0.6, re=2.2), color=red)
    b = sb.fig_made("B", 1.00, -1, hz=0.83, lean=-0.45, r_foot=(0.30, 1.30), ang=dict(fa=1.8, fe=0.6, ra=1.4, re=0.8), color=blue)
    c = sb.fig_made("C", 0.35, -1, hz=0.80, lean=0.30, rz=1.15, scale=G, f_hand=(0.12, 2.05), ang=dict(ra=2.4, re=0.6, fl=0.8, fk=1.4, rl=0.3, rk=1.2), color=purple)
    add(1, "p05_parry", 10, "四方からの連撃を、全部受け流す", "左から赤の拳、右から青の蹴り、真上から巨漢の拳。緑は一歩も動かずに、腕だけで全部受ける。青い輪が 3 つ続けて出る。",
        [a, d, b, c], fx=[("guard", -0.30, 1.45, 0.18), ("guard", 0.30, 1.30, 0.18), ("guard", 0.12, 2.0, 0.2)], h=440)


def act2():
    c = sb.fig_made("C", 1.45, -1, hz=0.76, lean=0.30, scale=G, ang=GIANT, color=purple)
    a = sb.fig_made("A", 0.50, 1, hz=0.56, lean=0.42, r_hand=(1.02, 1.10), ang=dict(fa=0.9, fe=1.9))
    d = sb.fig_made("D", -1.6, 1, hz=0.78, lean=-0.4, ht=0.6, ang=dict(fa=1.5, fe=0.8, ra=1.3, re=0.7), color=red)
    add(2, "p06_counter", 13, "反撃 → 巨漢には効かない", "受け流した勢いで、赤の顔に裏拳、そのまま巨漢の腹へ右。赤はよろけるが、巨漢の腹で拳が止まる。",
        [a, c, d], fx=[("spark", -1.35, 1.65, 0.3), ("guard", 1.05, 1.10, 0.15)], h=400)
    b = sb.fig_made("B", 0.75, -1, hz=0.83, lean=-0.70, r_foot=(0.15, 1.25), ang=dict(fa=2.2, fe=0.5, ra=-0.9, re=0.6), color=blue)
    a = sb.fig_made("A", -0.05, 1, hz=0.80, lean=-0.40, rz=0.80, roll=-0.4, ht=0.8, ang=FLY)
    add(2, "p07_combo1", 16, "連携技 ①: 青が蹴り上げる", "巨漢に止められた一瞬、青が下から腹を蹴り上げる。緑が宙へ。ここから 3 人の連携技(連続 2 秒)。",
        [a, b], fx=[("spark", 0.15, 1.25, 0.4), ("smear", 0.55, 0.95, 0.75, 140)], speed=[(-0.4, 0.5, -0.4, 1.2), (0.2, 0.4, 0.2, 1.1)], h=420)
    a = sb.fig_made("A", 0.35, -1, hz=0.80, lean=-0.6, rz=1.55, roll=0.6, ang=FLY)                 # 赤の方を向いたまま、打たれて後ろ(右)へ倒れていく
    ca = chest_of(a)
    d = sb.fig_made("D", -0.30, 1, hz=0.80, lean=0.45, rz=1.30, f_hand=(ca[0] - 0.08, ca[1]), ang=dict(ra=-0.4, re=1.9, fl=0.9, fk=1.4, rl=-0.3, rk=0.9), color=red)
    add(2, "p08_combo2", 17, "連携技 ②: 赤が先回りして空中で連打", "跳び上がった赤が、宙の緑に追いつき、胸・顔・胸と 3 発。",
        [a, d], fx=[("spark", ca[0] - 0.08, ca[1], 0.38), ("spark", ca[0] + 0.05, ca[1] + 0.35, 0.25)], h=460)
    cg = sb.fig_made("C", 0.55, -1, hz=0.80, lean=0.70, rz=1.10, scale=G, f_hand=(0.05, 1.05), r_hand=(0.20, 1.10), ang=dict(fl=0.9, fk=1.5, rl=0.2, rk=1.2), color=purple)
    a = sb.fig_made("A", -0.35, 1, hz=0.78, lean=0.0, rz=0.21, roll=1.57, ang=LIE)
    add(2, "p09_combo3", 18, "連携技 ③: 巨漢が叩き落とす", "さらに上から巨漢が両拳を振り下ろし、緑が地面に叩きつけられる。地面が割れて衝撃の輪と破片。閃光 1 コマ。",
        [a, cg], rings=[(-0.3, 0.02, 1.2)], cracks=[(-0.4, 0), (0.0, 0), (-0.8, 0)], debris=[(-0.6, 0.6, 0.05), (0.1, 0.8, 0.04), (-0.2, 1.0, 0.04)], fx=[("spark", 0.1, 0.4, 0.5)], flash=0.2, h=440)
    a = sb.fig_made("A", 0.0, 1, hz=0.74, lean=-0.30, ht=0.5, f_foot=(0.78, 1.10), r_hand=(-0.55, 1.35), ang=dict(fa=1.2, fe=1.6))
    d = sb.fig_made("D", -1.45, 1, hz=0.78, lean=0.40, f_hand=(-0.62, 1.35), ang=dict(ra=0.6, re=2.2), color=red)
    b = sb.fig_made("B", 1.25, -1, hz=0.78, lean=0.30, ang=KICKER, color=blue)
    add(2, "p10_struggle", 21, "立ち上がって必死にさばく", "よろけながら立ち、前後から続く拳と蹴りをさばくが、少しずつ押されて下がる(打ち合い 4 秒。緑も何発かもらう)。",
        [a, d, b], fx=[("guard", -0.60, 1.35, 0.18), ("spark", 0.80, 1.10, 0.3)], h=380)
    a = sb.fig_made("A", -1.4, 1, hz=0.45, lean=0.55, ht=0.3, f_foot=(-1.0, 0), r_foot=(-1.75, 0.0), ang=dict(fa=-0.2, fe=0.4, ra=0.6, re=1.2))
    d = sb.fig_made("D", 0.7, -1, hz=0.70, lean=0.15, ang=CHARGE, color=red)
    b = sb.fig_made("B", 1.7, -1, hz=0.72, lean=0.10, ang=CHARGE, color=blue)
    c = sb.fig_made("C", 2.9, -1, hz=0.70, lean=0.15, scale=G, ang=CHARGE, color=purple)
    add(2, "p11_charge", 25, "3 人が並んで気を溜める", "膝をついた緑の前で、3 人が横に並び、両手を腰に引いて気を溜める。それぞれの色の光の柱が立ち、空が暗くなる(溜めは 3 秒)。",
        [a, d, b, c], back_fx=[("pillar", 0.7, 0, 0.55, C_RED), ("pillar", 1.7, 0, 0.55, C_BLUE), ("pillar", 2.9, 0, 0.7, C_PURPLE)], h=420)
    d = sb.fig_made("D", 0.7, -1, hz=0.72, lean=0.20, f_hand=(0.20, 1.30), r_hand=(0.25, 1.25), color=red)
    b = sb.fig_made("B", 1.7, -1, hz=0.74, lean=0.15, f_hand=(1.20, 1.35), r_hand=(1.25, 1.30), color=blue)
    c = sb.fig_made("C", 2.9, -1, hz=0.72, lean=0.20, scale=G, f_hand=(2.25, 1.40), r_hand=(2.30, 1.35), color=purple)
    a = sb.fig_made("A", -1.9, 1, hz=0.78, lean=-0.4, rz=0.6, roll=0.9, ang=FLY)
    add(2, "p12_triple_beam", 29, "合体光線", "3 本の光線が 1 本にまとまり、緑に直撃。緑は煙の中へ吹き飛ぶ。閃光と大きな衝撃。ここが一番のピンチ。",
        [a, d, b, c], fx=[("beam", 2.25, 1.40, 0.10, -1.1, 1.20, C_PURPLE), ("beam", 1.20, 1.35, 0.09, -1.1, 1.20, C_BLUE), ("beam", 0.20, 1.30, 0.12, -1.3, 1.20, (255, 240, 220)),
                            ("shock", -1.3, 1.2, 0.7)], flash=0.3, h=400)


def act3():
    a = sb.fig_made("A", 0.0, 1, hz=0.80, lean=0.05, ht=0.2, ang=dict(fa=0.2, fe=0.4, ra=0.15, re=0.5))
    add(3, "p13_shadow", 33, "煙の中に、立つ影", "煙が晴れると、緑が立っている。3 人が一歩下がる。",
        [a], fx=[("dust", -0.9, 0.0, 1.0), ("dust", 0.9, 0.0, 1.0), ("dust", 0.0, 0.9, 0.7)], h=380)
    a = sb.fig_made("A", 0.0, 1, hz=0.68, lean=-0.05, ht=0.3, f_foot=(0.45, 0), r_foot=(-0.50, 0), ang=dict(fa=-0.25, fe=0.5, ra=-0.3, re=0.5))
    add(3, "p14_awaken", 36, "覚醒", "緑が拳を握り、緑色の気のオーラが体から噴き上がる。足もとの地面が割れ、小石が浮く。風が逆に吹く(溜めと噴き上がりで 4 秒)。",
        [a], back_fx=[("pillar", 0.0, 0, 0.9, AURA), ("aura", 0.0, 1.05, 0.95, AURA)], rings=[(0.0, 0.02, 1.1)], cracks=[(0.3, 0), (-0.3, 0)],
        debris=[(-0.7, 0.5, 0.04), (0.8, 0.8, 0.05), (-0.5, 1.3, 0.03), (0.6, 1.6, 0.04)], h=440)
    a = sb.fig_made("A", -0.8, 1, hz=0.72, lean=0.20, f_hand=(-0.15, 1.30), ang=dict(ra=0.4, re=1.6))
    c = sb.fig_made("C", 2.6, -1, hz=0.72, lean=0.20, scale=G, f_hand=(1.95, 1.40), r_hand=(2.0, 1.35), color=purple)
    add(3, "p15_catch", 40, "光線を片手で受け止める", "3 人がもう一度撃った光線を、緑は片手の気の盾で受け止め、一歩ずつ前へ押し返す。光線が割れて左右に散る。",
        [a, c], back_fx=[("aura", -0.8, 1.05, 0.85, AURA)], fx=[("beam", 1.95, 1.40, 0.10, 0.10, 1.30, (255, 240, 220)), ("shield", 0.05, 1.30, 0.55)], h=400)


def act4():
    b = sb.fig_made("B", 0.4, -1, hz=0.80, lean=0.05, ang=KICKER, color=blue)
    ghosts = [sb.fig_made("A", x, 1, hz=0.74, lean=0.5, ang=RUN) for x in (-1.6, -0.9, -0.2)]
    a = sb.fig_made("A", 1.25, -1, hz=0.78, lean=0.40, f_hand=(0.60, 1.40), ang=dict(ra=0.6, re=2.2))
    add(4, "p16_teleport", 45, "瞬間移動 → 青の背後から一撃", "緑が消え、残像の列を残して青の背後に現れる。振り向く前に背中へ一撃。青は地面に沈む。",
        [a, b], ghosts=ghosts, back_fx=[("aura", 1.25, 1.05, 0.75, AURA)], fx=[("spark", 0.60, 1.40, 0.38)], h=380)
    d = sb.fig_made("D", 0.5, -1, hz=0.74, lean=-0.3, ht=0.6, ang=dict(fa=1.5, fe=0.8, ra=1.3, re=0.7), color=red)
    a = sb.fig_made("A", -0.35, 1, hz=0.78, lean=0.45, f_hand=(0.25, 1.40), ang=dict(ra=0.6, re=2.2))
    k1 = sb.fig_made("A", 1.35, -1, hz=0.78, lean=0.45, r_hand=(0.75, 1.30), ang=dict(fa=1.0, fe=1.6))
    k2 = sb.fig_made("A", 0.55, 1, hz=0.83, lean=0.2, rz=1.15, f_foot=(0.55, 1.95), ang=dict(fa=1.0, fe=1.4, ra=0.6, re=1.4, rl=0.2, rk=1.2))
    add(4, "p17_clones", 49, "分身乱舞", "赤のまわりに分身が 3 体。前・後ろ・上から同時に拳と蹴り。最後に本体の右で赤が吹き飛ぶ。",
        [a, d], ghosts=[k1, k2], back_fx=[("aura", -0.35, 1.05, 0.75, AURA)], fx=[("spark", 0.25, 1.40, 0.35), ("spark", 0.75, 1.30, 0.3), ("spark", 0.55, 1.95, 0.3)], h=440)
    a = sb.fig_made("A", -0.45, 1, hz=0.74, lean=0.45, f_hand=(0.30, 1.50), ang=dict(ra=0.6, re=2.2))
    c = sb.fig_made("C", 1.30, -1, hz=0.76, lean=0.45, scale=G, f_hand=(0.32, 1.50), ang=dict(ra=0.3, re=1.2), color=purple)
    add(4, "p18_fist_clash", 53, "巨漢と拳の激突", "最後の巨漢と、拳と拳が真正面からぶつかる。空気が割れて大きな衝撃の輪。押し合い 1 秒、緑が一歩踏み込んで押し勝つ。",
        [a, c], back_fx=[("aura", -0.45, 1.05, 0.85, AURA)], fx=[("shock", 0.31, 1.50, 0.9), ("spark", 0.31, 1.50, 0.55)], flash=0.25, h=400)
    cb = sb.fig_made("C", 2.15, -1, hz=0.78, lean=0.30, rz=1.15, roll=2.4, scale=G, ang=dict(fa=2.6, fe=0.3, ra=2.5, re=0.3, fl=0.4, fk=0.6, rl=0.3, rk=0.7), color=purple)
    sk = fk.skeleton(cb["pose"], -1, cb["x"], G)
    back = ((sk["torso"][0][0] + sk["torso"][1][0]) / 2, (sk["torso"][0][1] + sk["torso"][1][1]) / 2)
    g1 = sb.fig_made("A", 1.20, 1, hz=0.80, lean=0.45, rz=1.45, ang=dict(fa=1.0, fe=1.2, ra=0.4, re=1.6, fl=0.6, fk=1.4))
    a = sb.fig_made("A", back[0] - 0.50, 1, hz=0.80, lean=-0.45, rz=back[1] + 0.70 - 0.78, f_foot=(back[0] + 0.02, back[1] + 0.06), ang=dict(fa=-0.6, fe=0.9, ra=-0.9, re=0.9, rl=0.6, rk=1.2))
    add(4, "p19_air_combo", 57, "打ち上げて空中コンボ", "押し勝った勢いでアッパー、巨漢が宙へ。跳んで空中で 2 発、蹴り落としで地面へ叩きつける。",
        [a, cb], ghosts=[g1], fx=[("spark", back[0], back[1] + 0.05, 0.5), ("smear", back[0] - 0.3, back[1] + 0.8, 0.8, 60)], trails=[arc((back[0] - 0.9, back[1] + 1.9), (back[0] - 0.2, back[1] + 1.6), (back[0] + 0.05, back[1] + 0.1))], h=520)


def act5():
    a = sb.fig_made("A", -1.6, 1, hz=0.66, lean=0.25, f_foot=(-1.2, 0), r_foot=(-2.1, 0), f_hand=(-0.95, 1.15), r_hand=(-1.0, 1.10))
    d = sb.fig_made("D", 0.9, -1, hz=0.83, lean=-0.6, rz=0.55, roll=0.8, ang=FLY, color=red)
    b = sb.fig_made("B", 1.9, -1, hz=0.83, lean=-0.5, rz=0.75, roll=0.9, ang=FLY, color=blue)
    c = sb.fig_made("C", 3.1, -1, hz=0.83, lean=-0.6, rz=0.45, roll=0.7, scale=G, ang=FLY, color=purple)
    add(5, "p20_final_beam", 62, "とどめの光線", "起き上がった 3 人が最後に突っ込んでくる。緑は両手を腰に引いて溜め(2 秒)、特大の光線で 3 人まとめて空へ。画面いっぱいの光。",
        [a, d, b, c], back_fx=[("aura", -1.6, 1.0, 0.9, AURA)], fx=[("beam", -0.95, 1.12, 0.20, 4.2, 1.25, AURA)], rings=[(-1.6, 0.02, 1.0)], flash=0.2, h=420)
    d = sb.fig_made("D", -1.9, 1, hz=0.78, lean=0.0, rz=0.21, roll=1.57, ang=LIE, color=red)
    b = sb.fig_made("B", 2.9, -1, hz=0.78, lean=0.0, rz=0.21, roll=1.57, ang=LIE, color=blue)
    c = sb.fig_made("C", 0.55, -1, hz=0.78, lean=0.0, rz=0.26, roll=1.57, scale=G, ang=LIE, color=purple)
    a = sb.fig_made("A", -0.7, -1, hz=0.86, lean=0.04, ht=0.05, ang=RELAX)
    add(5, "p21_after", 68, "余韻", "光が消え、夕日が戻る。オーラがすっと消えて、緑は 3 人に背を向けて歩き出す。風の音だけ(4 秒)。",
        [a, d, b, c], posts=TORII, speed=[(-2.6, 1.7, -1.8, 1.7), (1.6, 2.1, 2.6, 2.1)], h=380)


def main():
    if OUT.exists():
        shutil.rmtree(OUT)
    OUT.mkdir(parents=True)
    act1()
    act2()
    act3()
    act4()
    act5()
    (OUT / "panels.json").write_text(json.dumps(items, ensure_ascii=False, indent=1), encoding="utf-8")
    print(len(items), "コマ")


if __name__ == "__main__":
    main()

"""絵コンテ「3 対 1」(2026-10-24「新しい絵コンテ作って 3 体 1 が良い」)。勝ち抜き戦で倒した 3 人(青・巨漢・赤)が、まとめて緑に仕返しに来る。
いまの動作部品(moves.py)は 1 対 1 しか組めないので、姿勢は IK で手組みしたスケッチ。合意できたら、3 人を相手にできる組み立てを作る。

使い方: python tools/storyboard_3v1.py → out/storyboard3/*.png と panels.json
"""
from __future__ import annotations

import json
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
TUCK = dict(fa=0.9, fe=1.5, ra=1.0, re=1.6, fl=0.9, fk=1.6, rl=-0.2, rk=1.3)
RUN = dict(fa=-0.5, fe=0.9, ra=0.9, re=0.8, fl=-0.7, fk=0.3, rl=0.9, rk=1.2)
FLY = dict(fa=2.4, fe=0.4, ra=2.2, re=0.5, fl=0.8, fk=1.0, rl=0.2, rk=0.9)     # 吹き飛んで手足が流れる
LIE = dict(fa=2.6, fe=0.3, ra=2.4, re=0.3, fl=0.3, fk=0.2, rl=0.1, rk=0.2)
G = 1.25
blue, red, purple = sb.COLORS["B"], sb.COLORS["D"], sb.COLORS["C"]
items = []


def arc(p0, p1, p2, n=26):
    out = []
    for i in range(n + 1):
        t = i / n
        out.append(((1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t * t * p2[0], (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t * t * p2[1]))
    return out


def add(name: str, t: float, title: str, text: str, figs, **kw):
    path = OUT / f"{name}.png"
    sb.panel(figs, path, label=f"{t:.1f} 秒  {title}", **kw)
    items.append(dict(img=f"sb3/{name}.png", t=t, title=title, text=text))


def face_of(f):
    sk = fk.skeleton(f["pose"], f["d"], f["x"], f["sc"])
    return sk["head"]


def main():
    # 1 囲まれる
    a = sb.fig_made("A", 0.0, 1, hz=0.72, lean=0.25, ht=-0.1, ang=GUARD)
    d = sb.fig_made("D", -1.7, 1, hz=0.74, lean=0.38, ht=-0.2, ang=GUARD, color=red)
    b = sb.fig_made("B", 1.5, -1, hz=0.80, lean=0.05, ang=KICKER, color=blue)
    c = sb.fig_made("C", 3.0, -1, hz=0.78, lean=0.26, scale=G, ang=GIANT, color=purple)
    c0 = sb.fig_made("C", 3.8, -1, hz=0.80, lean=0.15, scale=G, ang=dict(GIANT, fl=0.4, fk=0.3, rl=-0.3, rk=0.6), color=purple)
    add("p01_surround", 0.0, "3 人に囲まれる", "勝ち抜き戦で倒した 3 人が、まとめて仕返しに来る。左に赤、右に青、奥から巨漢がゆっくり歩いてくる。緑は真ん中で、左右を見比べて構える。",
        [a, d, b, c], ghosts=[c0], arrows=[((3.9, 2.2), (3.3, 2.2))], h=380)
    # 2 左右から同時に飛びかかる
    a = sb.fig_made("A", 0.0, 1, hz=0.55, lean=0.30, ang=dict(fa=-0.4, fe=1.2, ra=-0.4, re=1.2))
    d = sb.fig_made("D", -0.95, 1, hz=0.83, lean=0.50, rz=0.55, f_hand=(-0.25, 1.45), ang=dict(ra=-0.4, re=1.9, fl=0.9, fk=1.4, rl=-0.3, rk=0.9), color=red)
    b = sb.fig_made("B", 0.95, -1, hz=0.83, lean=-0.35, rz=0.65, r_foot=(0.25, 1.30), ang=dict(fa=1.1, fe=1.8, ra=1.1, re=1.8, fl=0.3, fk=2.0), color=blue)
    d0 = sb.fig_made("D", -1.7, 1, hz=0.60, lean=0.45, ang=dict(GUARD, fl=0.9, fk=1.5, rl=-0.3, rk=1.2), color=red)
    b0 = sb.fig_made("B", 1.6, -1, hz=0.62, lean=0.15, ang=dict(KICKER, fl=0.9, fk=1.5, rl=-0.3, rk=1.2), color=blue)
    add("p02_pincer", 1.5, "左右から同時に飛びかかる", "赤の跳び込みの拳と、青の跳び蹴りが、左右から同時に来る。緑は沈んで溜める(跳ぶ前の予備動作)。",
        [a, d, b], ghosts=[d0, b0], speed=[(-2.4, 1.2, -1.6, 1.2), (-2.4, 1.5, -1.7, 1.5), (2.4, 1.0, 1.6, 1.0), (2.4, 1.3, 1.7, 1.3)], h=380)
    # 3 跳んでかわす → 同士討ち
    a = sb.fig_made("A", 0.0, 1, hz=0.83, lean=0.0, rz=1.55, ang=TUCK)
    a0 = sb.fig_made("A", 0.0, 1, hz=0.75, lean=0.1, rz=0.6, ang=dict(TUCK, fl=0.5, fk=0.8))
    b = sb.fig_made("B", 0.42, -1, hz=0.83, lean=-0.55, rz=0.30, ht=0.8, r_foot=(-0.20, 0.95), ang=dict(fa=1.8, fe=0.8, ra=1.4, re=0.9), color=blue)
    bf = face_of(b)
    d = sb.fig_made("D", -0.45, 1, hz=0.83, lean=0.30, rz=0.40, f_hand=(bf[0] - 0.12, bf[1]), ang=dict(ra=-0.4, re=1.9, fl=0.9, fk=1.4, rl=-0.3, rk=0.9), color=red)
    add("p03_friendly", 2.0, "跳んでかわす → 同士討ち", "緑が真上に跳ぶ。下で赤の拳が青の顔に、青の蹴りが赤の腹に入る。2 人とも弾かれて尻もち。(参考の Becker の 3 対 1 でもよくある、笑いの一拍)",
        [a, d, b], ghosts=[a0], fx=[("spark", bf[0] - 0.12, bf[1], 0.32), ("spark", -0.20, 0.95, 0.30)], h=420)
    # 4 着地して挟み撃ち: 前の青へ前蹴り、後ろの赤の拳は腕で受ける
    a = sb.fig_made("A", 0.0, 1, hz=0.80, lean=-0.30, f_foot=(0.78, 1.15), r_hand=(-0.55, 1.35), ang=dict(fa=1.2, fe=1.6))
    d = sb.fig_made("D", -1.45, 1, hz=0.78, lean=0.40, f_hand=(-0.62, 1.35), ang=dict(ra=0.6, re=2.2), color=red)
    b = sb.fig_made("B", 1.25, -1, hz=0.78, lean=0.55, ht=-0.4, ang=dict(fa=0.4, fe=1.4, ra=0.3, re=1.6), color=blue)
    add("p04_sandwich", 3.0, "前と後ろを同時にさばく", "着地してすぐ、前の青の腹へ前蹴り、後ろから来た赤の拳は振り向かずに後ろの腕で受ける。黄色い火花(当たり)と青い輪(受け)が同時に出る。",
        [a, d, b], fx=[("guard", -0.60, 1.35, 0.18), ("spark", 0.80, 1.15, 0.32)], h=380)
    # 5 巨漢の大振りをくぐって腹 → 効かない
    c = sb.fig_made("C", 1.45, -1, hz=0.76, lean=0.45, scale=G, r_hand=(0.05, 1.55), ang=dict(fa=0.6, fe=1.0), color=purple)
    a0 = sb.fig_made("A", 0.15, 1, hz=0.50, lean=0.35, ht=-0.1, ang=dict(fa=1.35, fe=1.9, ra=1.1, re=2.2))
    a = sb.fig_made("A", 0.50, 1, hz=0.56, lean=0.42, r_hand=(1.02, 1.10), ang=dict(fa=0.9, fe=1.9))
    add("p05_giant_absorb", 4.0, "巨漢の大振りをくぐって腹 → 効かない", "巨漢の大振りが頭の上を通る。くぐって腹に右を入れるが、拳が腹で止まる。巨漢は見下ろして笑う(顔は描かないので、体を揺らして見せる)。",
        [a, c], ghosts=[a0], fx=[("smear", 0.55, 1.30, 0.8, 200), ("guard", 1.05, 1.10, 0.15)], h=420)
    # 6 巨漢の一撃で吹き飛ぶ
    c = sb.fig_made("C", 0.75, -1, hz=0.76, lean=0.55, scale=G, f_hand=(-0.35, 1.45), ang=dict(ra=0.3, re=1.2), color=purple)
    a = sb.fig_made("A", -1.95, 1, hz=0.78, lean=-0.35, rz=0.90, roll=1.05, ang=FLY)
    a0 = sb.fig_made("A", -0.95, 1, hz=0.78, lean=-0.1, rz=0.25, roll=0.25, ang=dict(fa=2.0, fe=0.5, ra=1.8, re=0.6))
    add("p06_launched", 5.0, "巨漢の一撃で吹き飛ぶ", "巨漢の拳がまともに入り、緑が地面すれすれを飛んで転がる。閃光 1 コマ・大きな火花・流線・着地の土煙。いったんピンチ。",
        [a, c], ghosts=[a0], fx=[("spark", -0.38, 1.45, 0.55), ("dust", -2.6, 0.0, 0.5)], speed=[(-0.4, 1.0, 0.3, 1.0), (-0.6, 1.3, 0.2, 1.3), (-0.5, 0.7, 0.2, 0.7)], h=380)
    # 7 衝撃波 → 赤が巻き込まれる
    c = sb.fig_made("C", 1.70, -1, hz=0.60, lean=0.65, scale=G, r_hand=(0.80, 0.05), f_hand=(1.00, 0.10), f_foot=(1.30, 0), r_foot=(2.10, 0), color=purple)
    a = sb.fig_made("A", -0.35, 1, hz=0.80, lean=-0.1, rz=0.85, ang=dict(TUCK, fa=1.2, fe=1.0))
    d = sb.fig_made("D", -1.55, 1, hz=0.83, lean=-0.50, rz=0.75, roll=0.8, ang=FLY, color=red)
    add("p07_wave", 6.2, "衝撃波 → 赤が巻き込まれる", "巨漢が地面を叩き、土の波が走る。緑は跳んで越えるが、後ろから走り込んできた赤が波に足をすくわれて打ち上がる(2 度目の同士討ち)。",
        [a, c, d], rings=[(0.8, 0.05, 1.6)], cracks=[(0.8, 0), (0.45, 0), (0.1, 0)], fx=[("dust", 0.1, 0.0, 0.6), ("spark", -1.55, 0.9, 0.35)], debris=[(0.4, 0.5, 0.05), (0.0, 0.8, 0.04)], h=420)
    # 8 青の回し蹴りをバク転でかわす
    bk = sb.fig_made("B", 0.80, -1, hz=0.83, lean=-0.65, ht=0.3, r_foot=(-0.45, 1.50), ang=dict(fa=2.2, fe=0.5, ra=-0.9, re=0.6, fl=0.2, fk=0.1), color=blue)
    a0 = sb.fig_made("A", -0.30, 1, hz=0.76, lean=0.22, ang=GUARD)
    a1 = sb.fig_made("A", -0.95, 1, hz=0.80, lean=-0.30, rz=0.65, roll=1.0, ang=TUCK)
    a2 = sb.fig_made("A", -1.55, 1, hz=0.80, lean=0.0, rz=1.45, roll=3.1, ang=dict(TUCK, fa=1.6, fe=0.6))
    a3 = sb.fig_made("A", -2.20, 1, hz=0.56, lean=0.35, f_foot=(-1.95, 0), r_foot=(-2.55, 0), ang=dict(fa=1.1, fe=1.3, ra=0.8, re=1.3))
    add("p08_backflip", 7.5, "青との速い打ち合い → バク転", "青と 1 対 1 の速い打ち合い(拳 3 発・蹴り 2 発)。最後の高い回し蹴りをバク転でかわす。着地でつぶれて、次の溜め。",
        [a3, bk], ghosts=[a0, a1, a2], trails=[arc((-0.35, 1.0), (-1.3, 3.2), (-2.15, 0.9))], fx=[("smear", 0.20, 1.20, 0.75, 170), ("dust", -2.2, 0.0, 0.45)], h=420)
    # 9 回し蹴りで青を巨漢へ吹き飛ばす
    a = sb.fig_made("A", -0.30, 1, hz=0.83, lean=-0.60, r_foot=(0.62, 1.60), ang=dict(fa=2.2, fe=0.5, ra=-0.9, re=0.6))
    b = sb.fig_made("B", 1.45, -1, hz=0.83, lean=-0.70, rz=0.75, roll=0.9, ang=FLY, color=blue)
    c = sb.fig_made("C", 2.75, -1, hz=0.80, lean=-0.45, ht=0.4, scale=G, ang=dict(fa=1.5, fe=1.6, ra=1.3, re=1.8), color=purple)
    add("p09_into_giant", 8.5, "回し蹴りで青を巨漢に飛ばす", "跳ね起きの回し蹴りが青の顔に入り、青が巨漢めがけて飛んでぶつかる。巨漢もよろける。火花 2 つ(蹴り・ぶつかり)。",
        [a, b, c], fx=[("spark", 0.65, 1.60, 0.4), ("spark", 2.15, 1.35, 0.35), ("smear", -0.10, 1.25, 0.85, -25)], speed=[(0.7, 1.9, 1.1, 1.9), (0.6, 1.5, 1.1, 1.5)], h=400)
    # 10 背後の赤に振り向かずに後ろ蹴り
    a = sb.fig_made("A", 0.30, 1, hz=0.80, lean=0.65, ht=0.2, r_foot=(-0.55, 1.00), ang=dict(fa=1.1, fe=1.4, ra=0.8, re=1.6))
    d = sb.fig_made("D", -1.00, 1, hz=0.62, lean=0.78, ht=-0.45, ang=dict(fa=0.3, fe=1.4, ra=0.2, re=1.6), color=red)
    d0 = sb.fig_made("D", -1.6, 1, hz=0.76, lean=0.5, ang=RUN, color=red)
    add("p10_back_kick", 9.5, "背後の赤に、振り向かずに後ろ蹴り", "起き上がった赤が背後から走り込む。緑は前を向いたまま、後ろへ足を突き出して腹に入れる。赤は体を折って下がる。",
        [a, d], ghosts=[d0], fx=[("spark", -0.55, 1.00, 0.32)], h=380)
    # 11 3 人が並んで構え直す(静止)
    a = sb.fig_made("A", -0.9, 1, hz=0.66, lean=0.30, ht=-0.15, f_foot=(-0.45, 0), r_foot=(-1.45, 0), ang=GUARD)
    d = sb.fig_made("D", 0.9, -1, hz=0.74, lean=0.38, ht=-0.2, ang=GUARD, color=red)
    b = sb.fig_made("B", 1.75, -1, hz=0.80, lean=0.05, ang=KICKER, color=blue)
    c = sb.fig_made("C", 2.85, -1, hz=0.78, lean=0.26, scale=G, ang=GIANT, color=purple)
    add("p11_regroup", 10.5, "3 人が並んで構え直す(0.6 秒の静止)", "ぼろぼろの 3 人が横一列に並ぶ。緑は腰を落として深く構える。ここだけ全員が止まる「嵐の前」。カメラは 4 人が入る引き。",
        [a, d, b, c], h=380)
    # 12 跳び回し蹴り(竜巻)で 2 人まとめて
    a = sb.fig_made("A", 0.95, 1, hz=0.83, lean=-0.45, rz=0.95, r_foot=(1.75, 1.60), ang=dict(fa=1.9, fe=0.5, ra=-0.6, re=0.8, fl=0.9, fk=1.5))
    a0 = sb.fig_made("A", 0.45, 1, hz=0.83, lean=0.2, rz=0.55, roll=-0.4, ang=TUCK)
    d = sb.fig_made("D", 2.05, -1, hz=0.83, lean=-0.6, rz=0.75, roll=0.9, ang=FLY, color=red)
    b = sb.fig_made("B", 2.35, -1, hz=0.83, lean=-0.5, rz=0.10, roll=0.5, ang=FLY, color=blue)
    c = sb.fig_made("C", 5.0, -1, hz=0.74, lean=0.40, scale=G, ang=dict(fa=1.6, fe=1.2, ra=1.4, re=1.4), color=purple)
    add("p12_tornado", 11.5, "跳び回し蹴り(竜巻)で 2 人まとめて", "3 人が同時に突進。緑は跳んで体ごと回り、回し蹴りで赤と青を 2 人まとめて吹き飛ばす。巨漢だけが残る。",
        [a, d, b, c], ghosts=[a0], fx=[("smear", 0.95, 1.55, 0.85, -10), ("spark", 1.75, 1.6, 0.4), ("spark", 2.1, 1.05, 0.3)], speed=[(3.0, 2.0, 3.5, 2.0), (3.2, 1.2, 3.7, 1.2)], h=420)
    # 13 巨漢に空中コンボ → 叩きつけ
    cb = sb.fig_made("C", 2.15, -1, hz=0.78, lean=0.30, rz=1.15, roll=2.4, scale=G, ang=dict(fa=2.6, fe=0.3, ra=2.5, re=0.3, fl=0.4, fk=0.6, rl=0.3, rk=0.7), color=purple)
    sk = fk.skeleton(cb["pose"], -1, cb["x"], G)
    back = ((sk["torso"][0][0] + sk["torso"][1][0]) / 2, (sk["torso"][0][1] + sk["torso"][1][1]) / 2)
    g1 = sb.fig_made("A", 1.20, 1, hz=0.80, lean=0.45, rz=1.45, ang=dict(fa=1.0, fe=1.2, ra=0.4, re=1.6, fl=0.6, fk=1.4))
    a = sb.fig_made("A", back[0] - 0.50, 1, hz=0.80, lean=-0.45, rz=back[1] + 0.70 - 0.78, f_foot=(back[0] + 0.02, back[1] + 0.06), ang=dict(fa=-0.6, fe=0.9, ra=-0.9, re=0.9, rl=0.6, rk=1.2))
    add("p13_air_combo", 12.8, "巨漢を打ち上げて空中コンボ", "最後の巨漢。アッパーで打ち上げ、跳んで空中で 2 発、蹴り落としで地面へ叩きつける。地面が割れて衝撃の輪。",
        [a, cb], ghosts=[g1], fx=[("spark", back[0], back[1] + 0.05, 0.5), ("smear", back[0] - 0.3, back[1] + 0.8, 0.8, 60)], trails=[arc((back[0] - 0.9, back[1] + 1.9), (back[0] - 0.2, back[1] + 1.6), (back[0] + 0.05, back[1] + 0.1))], flash=0.25, h=520)
    # 14 決め: 3 人が倒れて、緑が構えを解く
    d = sb.fig_made("D", -1.9, 1, hz=0.78, lean=0.0, rz=0.21, roll=1.57, ang=LIE, color=red)
    b = sb.fig_made("B", 2.9, -1, hz=0.78, lean=0.0, rz=0.21, roll=1.57, ang=LIE, color=blue)
    c = sb.fig_made("C", 0.55, -1, hz=0.78, lean=0.0, rz=0.26, roll=1.57, scale=G, ang=LIE, color=purple)
    a = sb.fig_made("A", -0.7, -1, hz=0.86, lean=0.04, ht=0.05, ang=dict(fa=0.3, fe=0.5, ra=0.25, re=0.6))
    add("p14_finish", 14.2, "決め: 3 人が倒れて、緑が背を向ける", "3 人が地面に転がる。緑は構えを解いて背を向ける(決めの止め絵 0.8 秒)。巨漢が落ちた所の土煙が晴れていく。",
        [a, d, b, c], fx=[("dust", 1.3, 0.0, 0.8)], h=380)
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "panels.json").write_text(json.dumps(items, ensure_ascii=False, indent=1), encoding="utf-8")
    print(len(items), "コマ")


if __name__ == "__main__":
    main()

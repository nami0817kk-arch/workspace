"""絵コンテの「派手な動き」のコマ(2026-10-22「動きを派手に」)。宙返り・飛び越え・スライディング・空中の蹴り・衝撃波・柱を砕く吹き飛び・駆け上がり・かかと落とし。
軌跡の残像・弧・衝撃波の輪・破片を付けた、マンガのアクションのコマ。IK で組んだ姿勢(動作はこれから作る)。

使い方: python tools/storyboard_flashy.py → out/storyboard/flashy/*.png と flashy.json
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import storyboard as sb  # noqa: E402
from stickfig import fk  # noqa: E402

OUT = Path("out/storyboard")
GUARD = dict(fa=1.05, fe=2.35, ra=0.65, re=2.6)
TUCK = dict(fa=0.9, fe=1.5, ra=1.0, re=1.6, fl=0.9, fk=1.6, rl=-0.2, rk=1.3)
RUN = dict(fa=-0.5, fe=0.9, ra=0.9, re=0.8, fl=-0.7, fk=0.3, rl=0.9, rk=1.2)
red, blue, purple = sb.COLORS["D"], sb.COLORS["B"], sb.COLORS["C"]
items = {}


def arc(p0, p1, p2, n=26):
    """3 点を通る放物線(2 次ベジェ)の点列。軌跡の点線用。"""
    out = []
    for i in range(n + 1):
        t = i / n
        out.append(((1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t * t * p2[0], (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t * t * p2[1]))
    return out


def add(round_: str, name: str, title: str, text: str, figs, **kw):
    path = OUT / "flashy" / f"{name}.png"
    sb.panel(figs, path, label=title, **kw)
    items.setdefault(round_, []).append(dict(img=f"flashy/{name}.png", title=title, text=text))


def r1():
    # 飛び越えて背後へ(前宙)
    b = sb.fig_made("B", 1.20, -1, hz=0.74, lean=0.30, ht=0.3, ang=GUARD, color=blue)
    g1 = sb.fig_made("A", -0.55, 1, hz=0.76, lean=0.50, ang=RUN)
    g2 = sb.fig_made("A", 0.40, 1, hz=0.80, lean=0.30, rz=0.80, roll=-0.9, ang=TUCK)
    g3 = sb.fig_made("A", 1.15, 1, hz=0.80, lean=0.0, rz=2.15, roll=-3.1, ang=dict(TUCK, fa=1.4, fe=0.8))
    a = sb.fig_made("A", 2.70, -1, hz=0.58, lean=0.30, f_foot=(2.45, 0), r_foot=(3.05, 0), ang=dict(fa=1.0, fe=1.4, ra=0.7, re=1.5))
    add("blue", "r1_vault", "飛び越えて背後へ", "青の頭上を前宙で飛び越え、背中側に着地して振り向く。青は目で追うだけ。距離を 2 歩ぶん一気に詰める。",
        [a, b], ghosts=[g1, g2, g3], trails=[arc((-0.45, 1.0), (1.0, 4.6), (2.6, 1.0))], speed=[(-1.4, 0.9, -0.8, 0.9), (-1.4, 1.2, -0.7, 1.2)], h=500)
    # バク転でかわす
    bk = sb.fig_made("B", 0.80, -1, hz=0.83, lean=-0.65, ht=0.3, r_foot=(-0.45, 1.50), ang=dict(fa=2.2, fe=0.5, ra=-0.9, re=0.6, fl=0.2, fk=0.1), color=blue)
    a0 = sb.fig_made("A", -0.30, 1, hz=0.76, lean=0.22, ang=GUARD)
    a1 = sb.fig_made("A", -0.95, 1, hz=0.80, lean=-0.30, rz=0.65, roll=1.0, ang=TUCK)
    a2 = sb.fig_made("A", -1.55, 1, hz=0.80, lean=0.0, rz=1.45, roll=3.1, ang=dict(TUCK, fa=1.6, fe=0.6))
    a3 = sb.fig_made("A", -2.20, 1, hz=0.56, lean=0.35, f_foot=(-1.95, 0), r_foot=(-2.55, 0), ang=dict(fa=1.1, fe=1.3, ra=0.8, re=1.3))
    add("blue", "r1_backflip", "バク転でかわす", "青の高い回し蹴りを、後ろ宙返りで避ける。蹴りが通った所に、さっきまで緑がいる。着地でつぶれて、次の飛び込みの溜めになる。",
        [a3, bk], ghosts=[a0, a1, a2], trails=[arc((-0.35, 1.0), (-1.3, 3.2), (-2.15, 0.9))], h=440)
    # スライディング
    jb = sb.fig_made("B", 0.55, -1, hz=0.83, lean=-0.35, rz=1.05, r_foot=(-0.35, 1.35), ang=dict(fa=1.5, fe=0.9, ra=1.2, re=0.9, fl=0.6, fk=1.1), color=blue)
    sl = dict(fa=-0.9, fe=0.5, ra=-1.2, re=0.4, fl=1.7, fk=0.15, rl=1.4, rk=0.25)
    s0 = sb.fig_made("A", -0.85, 1, hz=0.56, lean=-0.1, rz=0.18, roll=1.25, ang=sl)
    s1 = sb.fig_made("A", -0.40, 1, hz=0.56, lean=-0.1, rz=0.18, roll=1.25, ang=sl)
    sm = sb.fig_made("A", 0.20, 1, hz=0.56, lean=-0.1, rz=0.18, roll=1.25, ang=sl)
    add("blue", "r1_slide", "スライディングで下をくぐる", "青の跳び蹴りの下を、寝そべって滑り抜ける。砂ぼこりを引いて背後へ出て、すぐ立ち上がって足払いにつなぐ。",
        [sm, jb], ghosts=[s0, s1], speed=[(-1.9, 0.12, -0.9, 0.12), (-1.9, 0.30, -1.1, 0.30), (-1.9, 0.48, -1.3, 0.48)], debris=[(-0.7, 0.18, 0.04), (-1.0, 0.1, 0.03), (-0.5, 0.25, 0.03)], h=380)
    # 空中の蹴り 3 連
    ab = sb.fig_made("A", -0.55, 1, hz=0.60, lean=0.20, ang=dict(fa=1.55, fe=1.95, ra=1.4, re=1.95, fl=0.4, fk=0.9, rl=-0.5, rk=0.5))
    k1 = sb.fig_made("B", 1.05, -1, hz=0.83, lean=-0.60, rz=1.05, r_foot=(0.05, 1.95), ang=dict(fa=1.8, fe=0.6, ra=1.4, re=0.8, fl=0.5, fk=1.0), color=blue)
    k2 = sb.fig_made("B", 1.05, -1, hz=0.83, lean=-0.45, rz=1.05, f_foot=(0.10, 1.40), ang=dict(fa=1.8, fe=0.6, ra=1.4, re=0.8, rl=-0.2, rk=0.9), color=blue)
    k3 = sb.fig_made("B", 1.05, -1, hz=0.83, lean=-0.25, rz=1.05, r_foot=(0.10, 0.80), ang=dict(fa=1.8, fe=0.6, ra=1.4, re=0.8, fl=0.4, fk=1.0), color=blue)
    add("blue", "r1_air3", "空中で蹴り 3 連", "青が跳んだまま、頭・胸・足の順に 3 発蹴る。着地するまで 0.5 秒。緑は受けきれず、最後の 1 発で下がる。",
        [ab, k3], ghosts=[k1, k2], trails=[arc((0.05, 1.95), (0.3, 1.3), (0.10, 0.8))], hits=[(0.05, 1.95), (0.10, 1.40), (0.10, 0.80)], h=420)


def r2():
    # 拳で地面を叩く → 衝撃波
    g = sb.fig_made("C", 1.65, -1, hz=0.60, lean=0.65, scale=1.25, r_hand=(0.75, 0.05), f_hand=(0.95, 0.10), f_foot=(1.25, 0), r_foot=(2.05, 0), color=purple)
    a0 = sb.fig_made("A", -0.95, 1, hz=0.76, lean=0.22, ang=GUARD)
    a1 = sb.fig_made("A", -0.20, 1, hz=0.80, lean=-0.1, rz=0.85, ang=dict(TUCK, fa=1.2, fe=1.0))
    add("giant", "r2_slam", "拳で地面を叩く → 衝撃波", "巨漢が両拳を地面に叩きつけ、地面を割って衝撃波が走る。緑は波が来る直前に跳んで越える。",
        [a1, g], ghosts=[a0], rings=[(0.75, 0.05, 1.7)], cracks=[(0.75, 0), (0.5, 0), (0.2, 0)], debris=[(0.4, 0.5, 0.05), (0.1, 0.8, 0.04), (0.9, 0.7, 0.05), (0.6, 1.0, 0.03)],
        speed=[(-1.0, 1.5, -0.4, 1.5)], h=420, ground=0.78)
    # 一撃で吹き飛び、柱を砕く
    gh = sb.fig_made("C", 0.65, -1, hz=0.76, lean=0.55, scale=1.25, r_hand=(-0.35, 1.45), f_foot=(0.30, 0), r_foot=(1.10, 0), ang=dict(fa=0.6, fe=1.0), color=purple)
    af = sb.fig_made("A", -1.95, 1, hz=0.78, lean=-0.35, rz=0.95, roll=1.05, ang=dict(fa=2.4, fe=0.4, ra=2.2, re=0.5, fl=0.8, fk=1.0, rl=0.2, rk=0.9))
    a_ = sb.fig_made("A", -1.00, 1, hz=0.78, lean=-0.1, rz=0.2, roll=0.2, ang=dict(fa=2.0, fe=0.5, ra=1.8, re=0.6))
    add("giant", "r2_post", "一撃で吹き飛び、柱を砕く", "巨漢の右が入り、緑が弾丸のように飛んで道場の柱に激突。柱が折れ、破片が飛ぶ。緑は砕けた柱ごと床を滑る。",
        [af, gh], ghosts=[a_], posts=[(-3.05, 0.22, 2.2)], debris=[(-2.9, 1.5, 0.07), (-3.2, 1.1, 0.06), (-2.6, 1.8, 0.05), (-3.3, 1.6, 0.05), (-2.8, 0.7, 0.05)],
        hits=[(-2.55, 1.2)], speed=[(-1.0, 1.0, -0.4, 1.0), (-1.2, 1.3, -0.5, 1.3)], h=400)
    # 腕を駆け上がる
    g2 = sb.fig_made("C", 1.35, -1, hz=0.76, lean=0.35, scale=1.25, f_hand=(0.15, 1.72), r_hand=(0.35, 1.60), f_foot=(1.05, 0), r_foot=(1.80, 0), color=purple)
    r0 = sb.fig_made("A", -0.85, 1, hz=0.76, lean=0.50, ang=RUN)
    sk = fk.skeleton(g2["pose"], -1, g2["x"], 1.25)
    head = sk["head"]
    ar = sb.fig_made("A", 0.55, 1, hz=0.78, lean=0.55, rz=0.92, roll=-0.75, f_foot=(0.55, 1.70), r_hand=(head[0] - 0.22, head[1] - 0.08), ang=dict(fa=-0.3, fe=0.9, rl=1.1, rk=0.9))
    add("giant", "r2_run", "巨漢の腕を駆け上がって顔面へ", "巨漢が振り下ろした腕を足場にして、そのまま肩まで駆け上がり、顔面に一撃。体の大きい相手だからできる動き。",
        [ar, g2], ghosts=[r0], hits=[(head[0] - 0.22, head[1] - 0.08)], trails=[arc((-0.6, 0.9), (0.0, 1.6), (0.45, 1.75))], h=440)


def final():
    # かかと落とし(宙返り)
    b = sb.fig_made("D", 2.05, -1, hz=0.78, lean=0.30, rz=1.15, roll=2.6, ang=dict(fa=2.6, fe=0.3, ra=2.5, re=0.3, fl=0.4, fk=0.6, rl=0.3, rk=0.7), color=red)
    sk = fk.skeleton(b["pose"], -1, b["x"], 1.0)
    back = ((sk["torso"][0][0] + sk["torso"][1][0]) / 2, (sk["torso"][0][1] + sk["torso"][1][1]) / 2)
    g1 = sb.fig_made("A", 1.40, 1, hz=0.80, lean=-0.35, rz=1.65, roll=-0.9, ang=dict(fa=1.0, fe=1.2, ra=0.8, re=1.4, fl=2.3, fk=0.1, rl=0.2, rk=1.0))
    g2 = sb.fig_made("A", 1.65, 1, hz=0.80, lean=-0.25, rz=2.25, roll=-2.1, ang=dict(fa=1.0, fe=1.2, ra=0.8, re=1.4, fl=2.6, fk=0.1, rl=0.0, rk=0.8))
    a = sb.fig_made("A", back[0] - 0.50, 1, hz=0.80, lean=-0.45, rz=back[1] + 0.70 - 0.78, f_foot=(back[0] + 0.02, back[1] + 0.06), ang=dict(fa=-0.6, fe=0.9, ra=-0.9, re=0.9, rl=0.6, rk=1.2))
    add("red", "f_heel", "宙返りかかと落とし", "緑が空中で前宙を切って勢いをつけ、かかとを背中に振り下ろす。赤が頭から地面へ向かう。このコマで画面を 0.1 秒止める。",
        [a, b], ghosts=[g1, g2], hits=[(back[0], back[1] + 0.05)], trails=[arc((back[0] - 0.9, back[1] + 1.9), (back[0] - 0.2, back[1] + 1.6), (back[0] + 0.05, back[1] + 0.1))], speed=[(back[0] + 0.5, back[1] + 1.2, back[0] + 0.7, back[1] + 0.3), (back[0] + 0.8, back[1] + 1.3, back[0] + 1.0, back[1] + 0.4)], h=520)
    # 着地の衝撃
    b2 = sb.fig_made("D", 2.75, -1, hz=0.78, lean=0.0, rz=0.50, roll=1.57, ang=dict(fa=2.6, fe=0.3, ra=2.4, re=0.3, fl=0.3, fk=0.2, rl=0.1, rk=0.2), color=red)
    a2 = sb.fig_made("A", 1.85, 1, hz=0.52, lean=0.35, f_foot=(2.12, 0), r_foot=(1.52, 0), ang=dict(fa=1.0, fe=1.2, ra=0.8, re=1.2))
    add("red", "f_land", "叩きつけの衝撃", "赤が地面に叩きつけられて一度大きく跳ね、地面が割れて砂ぼこりと衝撃波の輪。緑は着地でつぶれたまま、決めの 0.8 秒。",
        [a2, b2], rings=[(2.35, 0.05, 1.5)], cracks=[(2.35, 0), (2.05, 0), (2.65, 0)], debris=[(2.0, 0.55, 0.05), (2.7, 0.75, 0.05), (2.5, 0.95, 0.04), (1.7, 0.4, 0.04)], hits=[(2.3, 0.2)], h=420, ground=0.76)


def main():
    r1()
    r2()
    final()
    (OUT / "flashy.json").write_text(json.dumps(items, ensure_ascii=False, indent=1), encoding="utf-8")
    print({k: len(v) for k, v in items.items()})


if __name__ == "__main__":
    main()

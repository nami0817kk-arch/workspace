"""絵コンテの「エフェクト」のコマ(2026-10-22「エフェクトもつけよう」)。技ごとに、どの効果をどこに付けるかを見せる。
姿勢は IK で組んだスケッチ。実際の見え方は書き出してから調整する。

使い方: python tools/storyboard_fx.py → out/storyboard/fx/*.png と fx.json
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import storyboard as sb  # noqa: E402

OUT = Path("out/storyboard")
GUARD = dict(fa=1.05, fe=2.35, ra=0.65, re=2.6)
BLOCK = dict(fa=1.35, fe=1.75, ra=1.2, re=1.9)
RUN = dict(fa=-0.5, fe=0.9, ra=0.9, re=0.8, fl=-0.7, fk=0.3, rl=0.9, rk=1.2)
blue, red, purple = sb.COLORS["B"], sb.COLORS["D"], sb.COLORS["C"]
items = []


def add(name: str, title: str, text: str, figs, **kw):
    path = OUT / "fx" / f"{name}.png"
    sb.panel(figs, path, label=title, **kw)
    items.append(dict(img=f"fx/{name}.png", title=title, text=text))


def main():
    # 1 命中(小): 火花
    a = sb.fig_made("A", -0.55, 1, hz=0.78, lean=0.30, f_hand=(0.55, 1.45), ang=dict(ra=0.65, re=2.6))
    b = sb.fig_made("B", 1.05, -1, hz=0.80, lean=-0.35, ht=0.5, ang=GUARD, color=blue)
    add("fx_hit", "命中(通常): 火花", "拳や足が当たった 1 コマ目に、当たった点で火花が散る。すぐ消える。当たりのコマを一目で分からせる、いちばん基本の効果。",
        [a, b], fx=[("spark", 0.62, 1.45, 0.34)], h=360)
    # 2 打つ腕の軌跡
    a = sb.fig_made("A", -0.60, 1, hz=0.76, lean=0.38, f_hand=(0.55, 1.50), ang=dict(ra=0.65, re=2.6))
    g1 = sb.fig_made("A", -0.60, 1, hz=0.78, lean=0.2, f_hand=(0.05, 1.20), ang=dict(ra=0.65, re=2.6))
    b = sb.fig_made("B", 1.05, -1, hz=0.80, lean=-0.3, ang=GUARD, color=blue)
    add("fx_smear", "振りの軌跡: 三日月の線", "速く振る腕・脚の通り道に、細い光の弧を残す(約 4 コマで消える)。速い動きが線でつながって見える。",
        [a, b], ghosts=[g1], fx=[("smear", -0.15, 1.30, 0.75, -20)], h=360)
    # 3 蹴り + 受け
    b = sb.fig_made("B", 1.00, -1, hz=0.82, lean=-0.55, ht=0.3, f_foot=(0.02, 1.55), ang=dict(fa=1.2, fe=1.3, ra=-0.5, re=0.9), color=blue)
    a = sb.fig_made("A", -0.60, 1, hz=0.74, lean=0.12, ang=BLOCK)
    add("fx_guard", "受け止め: 青い火花の輪", "蹴りを受けたら、受けた腕の所に小さな青い輪と短い線。当たりの赤い火花と色を分けて、「効いた」「防いだ」を見分ける。",
        [a, b], fx=[("guard", -0.02, 1.52, 0.2), ("smear", 0.45, 1.20, 0.8, 150)], h=360)
    # 4 走り込み・踏み込み: 土煙
    a = sb.fig_made("A", 0.20, 1, hz=0.76, lean=0.50, ang=RUN)
    g = sb.fig_made("A", -0.90, 1, hz=0.78, lean=0.40, ang=dict(RUN, fl=0.8, rl=-0.6))
    add("fx_dust", "走り込み・踏み込み: 土煙", "走り出しと踏み込みの足もとに、小さな土煙。1 歩ごとではなく、地面を強く蹴るとき(走り出し・踏み込み・着地)だけ。動きの重さが出る。",
        [a], ghosts=[g], fx=[("dust", -0.95, 0.0, 0.5)], speed=[(-1.9, 0.9, -1.1, 0.9), (-1.9, 1.3, -1.0, 1.3)], h=340)
    # 5 吹き飛び
    b = sb.fig_made("B", 1.30, -1, hz=0.9, lean=-0.8, rz=0.55, roll=0.9, ang=dict(fa=2.3, fe=0.6, ra=-0.9, re=0.7), color=blue)
    a = sb.fig_made("A", -0.70, 1, hz=0.76, lean=0.30, f_foot=(0.15, 1.20), ang=dict(fa=0.9, fe=1.4))
    add("fx_launch", "吹き飛び: 流線と地面の土煙", "強い一撃のあと、飛ぶ人の後ろに数本の流線。倒れて滑るとき、床から土煙が上がる。当たりの火花は大きくする。",
        [a, b], fx=[("spark", 0.20, 1.25, 0.52), ("dust", -0.05, 0.0, 0.55)], speed=[(0.6, 1.8, 1.4, 1.8), (0.45, 1.45, 1.4, 1.45), (0.6, 0.9, 1.4, 0.9)], h=380)
    # 6 大技: 閃光 + 衝撃の輪
    a = sb.fig_made("A", -0.50, 1, hz=0.70, lean=0.55, f_hand=(0.65, 0.95), ang=dict(ra=0.65, re=2.6))
    b = sb.fig_made("B", 1.10, -1, hz=0.9, lean=-0.7, rz=0.30, roll=0.5, ang=dict(fa=2.0, fe=0.6, ra=-0.6, re=0.7), color=blue)
    add("fx_big", "大技の決め: 閃光 1 コマ + 衝撃の輪", "決めの一撃だけ、当たりの 1 コマを白く光らせ、衝撃の輪と大きな火花を重ねる。その後 0.1 秒ほど動きを止める(ヒットストップ)。使うのは各試合 1〜2 回まで。",
        [a, b], fx=[("spark", 0.75, 1.0, 0.7), ("shock", 0.75, 1.0, 0.95)], flash=0.45, h=360)
    # 7 衝撃波
    p = sb.fig_made("C", 0.0, 1, hz=0.46, lean=0.7, f_hand=(0.85, 0.0), r_hand=(0.65, 0.0), ang=dict(fl=1.2, fk=1.5, rl=-0.3, rk=1.2), scale=1.25, color=purple)
    g = sb.fig_made("A", 2.9, -1, hz=0.9, lean=0.0, rz=0.5, ang=dict(fa=1.4, fe=0.8, ra=1.0, re=0.9, fl=0.6, fk=1.3, rl=0.4, rk=1.2))
    add("fx_wave", "衝撃波: 地面の輪 + 割れ目 + 破片", "巨漢が地面を叩く。叩いた点から輪が広がり、割れ目と破片。緑は輪が来る前に跳んでかわす(かわすと輪は足の下を通る)。",
        [p, g], rings=[(0.9, 0.0, 0.95), (2.0, 0.0, 0.55)], cracks=[(0.9, 0.0), (1.3, 0.0), (1.7, 0.0)], debris=[(1.0, 0.45, 0.05), (1.25, 0.6, 0.04), (0.7, 0.55, 0.04)],
        fx=[("dust", 0.95, 0.0, 0.7)], h=380)
    # 8 空振り: 風切りだけ
    a = sb.fig_made("A", -0.20, 1, hz=0.58, lean=0.35, f_foot=(-0.55, 0), r_foot=(0.3, 0.0), ang=dict(fa=1.1, fe=1.3, ra=0.7, re=1.4))
    b = sb.fig_made("B", 0.95, -1, hz=0.82, lean=-0.2, f_foot=(0.15, 1.45), ang=dict(fa=1.2, fe=1.3, ra=-0.4, re=1.0), color=blue)
    add("fx_miss", "かわした(空振り): 弧だけ", "かわされた蹴りには、火花を付けず弧の線だけ。「当たらなかった」ことがはっきり分かる。当たりとの差をつけるため、空振りは効果を少なくする。",
        [a, b], fx=[("smear", 0.45, 1.30, 0.85, 160)], h=360)
    # 9 空中コンボ: 光の尾
    a1 = sb.fig_made("A", 0.20, 1, hz=0.80, lean=0.40, rz=1.55, roll=-0.4, f_hand=(1.15, 1.9), ang=dict(ra=0.4, re=1.6, fl=0.9, fk=1.5, rl=0.1, rk=1.0))
    g1 = sb.fig_made("A", -0.35, 1, hz=0.76, lean=0.3, rz=0.8, ang=dict(fl=0.8, fk=1.4, fa=1.1, fe=0.9))
    b = sb.fig_made("B", 1.25, -1, hz=0.9, lean=-0.7, rz=1.75, roll=0.6, ang=dict(fa=2.2, fe=0.5, ra=-0.9, re=0.6), color=blue)
    add("fx_air", "空中の連打: 手足の光の尾", "跳んだ間だけ、手足に短い光の尾を引く。当たるたびに火花。着地の土煙で終わる。",
        [a1, b], ghosts=[g1], fx=[("spark", 1.10, 1.95, 0.4), ("smear", 0.45, 1.75, 0.7, -35), ("glint", 1.35, 2.35, 0.22)], h=420)
    (OUT / "fx.json").write_text(json.dumps(items, ensure_ascii=False, indent=1), encoding="utf-8")
    print("fx:", len(items), "コマ")


if __name__ == "__main__":
    main()

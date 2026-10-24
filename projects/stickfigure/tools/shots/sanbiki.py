"""3 対 1「倒した 3 人が、まとめて仕返しに来る」(2026-10-24 絵コンテで合意。out/storyboard3、Artifact 版 7)。約 72 秒を 5 幕に分ける。
アニメの戦いの型: 降臨 → 連携でピンチ → 覚醒 → 逆転 → 決着。音は戦闘アニメ風(stickfig/sfx_anime.py、audio.style anime)。

使い方: python tools/shots/sanbiki.py 1|2|3|4|5 --out out/sb_1 [--check|--plan-only]
エピソード: scenes/episodes/sanbiki.yaml(shot: tools/shots/sanbiki_*.py)
"""
from __future__ import annotations

import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parents[1]))
from stickfig import bout, moves  # noqa: E402

BG = dict(image="assets/bg/shrine_dusk.png", x0=-9.5, x1=9.0, ground=0.80)
GREEN, RED, BLUE, PURPLE = [0.5, 0.85, 0.3], [0.92, 0.32, 0.28], [0.25, 0.55, 0.95], [0.62, 0.35, 0.85]
C_GREEN, C_RED, C_BLUE, C_PURPLE, C_WHITE = [120, 255, 140], [255, 110, 90], [110, 170, 255], [190, 120, 255], [255, 240, 220]
G = 1.25
CAM = 4.4                     # 4 人が入る引き
VERTICAL_ZOOM = 2.8


def cast(a, d, b, c):
    """各人の (x, 向き)。"""
    return dict(A=dict(color=GREEN, style="kenpo", x=a[0], d=a[1]),
                D=dict(color=RED, style="brawler", x=d[0], d=d[1]),
                B=dict(color=BLUE, style="kicker", x=b[0], d=b[1]),
                C=dict(color=PURPLE, style="giant", x=c[0], d=c[1], scale=G))


def act1(F, T):
    """降臨(約 12 秒): ひとり → 3 人が降り立つ → にらみ合い → 3 人が消えて四方から → 全部受け流す → 反撃(巨漢には効かない)。"""
    A, B, C, D = F["A"], F["B"], F["C"], F["D"]
    A.relax(0.0, 3.4)
    T.land_in(D, 3.0)
    T.land_in(B, 3.5)
    T.land_in(C, 4.1)
    T.hits.append(bout.H(4.1, "heel", (C.x, 0.1), 0.06))                       # 巨漢の着地だけ一段重い(地面のひびと輪)
    T.teleport(D, 7.0, -0.95, 1)
    T.teleport(B, 7.1, 0.95, -1)
    T.exchange(D, A, "cross", 7.6, "block", push=0.10)                          # 四方からの連撃を、全部受け流す
    T.exchange(B, A, "front", 8.0, "block", push=0.10)
    B.dash(8.4, 8.62, 2.9)                                                      # 青が跳び退いて、巨漢が瞬間移動で入る
    T.teleport(C, 8.7, 1.25, -1)
    T.exchange(C, A, "hook", 9.15, "duck")
    T.exchange(D, A, "jab", 9.55, "block", push=0.10)
    T.exchange(A, D, "hook", 10.15, "stagger", push=0.5)                        # 反撃
    T.exchange(A, C, "belly", 10.9, "block", push=0.05, part="chest")          # 巨漢の腹で拳が止まる


def act2(F, T):
    """連携(約 20 秒): 蹴り上げ → 空中連打 → 叩き落とし → 必死にさばく → 巨漢の一撃 → 3 人で溜めて合体光線。"""
    A, B, C, D = F["A"], F["B"], F["C"], F["D"]
    T.exchange(B, A, "front", 0.8, "stagger", push=0.3)
    T.air_combo(D, A, 1.5, getup=0.6, lie=0.5)                                  # 赤のアッパーで打ち上げ → 空中 2 発 → 叩き落とし
    T.exchange(B, A, "round", 5.0, "block", push=0.35)                          # 起き上がって必死にさばく
    T.exchange(D, A, "cross", 5.55, "stagger", push=0.3)
    T.exchange(A, D, "jab", 6.05, "stagger", push=0.3)
    T.exchange(B, A, "front", 6.6, "stagger", push=0.35)
    T.exchange(A, B, "cross", 7.1, "lean")
    B.dash(7.55, 7.75, B.x + 1.6)                                               # 青が下がり、巨漢が前へ
    T.exchange(C, A, "cross", 8.3, "launch", dist=2.2, lie=0.2, getup=0.6, flash=True)    # 巨漢の一撃で吹き飛ぶ
    A.kneel(10.3, 13.9)                                                         # 膝をつく
    D.shuffle(9.6, 10.1, A.x + 2.0)                                             # 3 人が横に並ぶ
    B.shuffle(9.7, 10.2, A.x + 3.0)
    C.shuffle(9.8, 10.4, A.x + 4.2)
    for f in (D, B, C):
        if f.d != -1:
            f.turn(f.t, -1)
    T.charge([D, B, C], 10.8, 13.8, [C_RED, C_BLUE, C_PURPLE])
    for f, dt in ((D, 0.0), (B, 0.04), (C, 0.08)):                               # 合体光線(3 本がまとまって緑へ)
        T.beam(f, 13.9 + dt, 1.1, A.x + 0.2, C_WHITE, targets=[A] if f is D else None, boom=(f is D), dist=1.6, stay=True)
    T.cam.append((10.6, 16.5, 4.8, 1.1))


def act3(F, T):
    """覚醒(約 12 秒): 煙の中に立つ影 → オーラが噴き上がる → もう一度の光線を片手の盾で受け止める → 盾が弾けて 3 人がのけぞる。"""
    A, B, C, D = F["A"], F["B"], F["C"], F["D"]
    A.start_lying()
    T.puffs += [dict(tau=0.2, kind="land2", pos=[A.x - 0.6, 0.0]), dict(tau=0.5, kind="land2", pos=[A.x + 0.5, 0.0])]
    A.getup(1.4, 1.4)                                                           # 煙の中でゆっくり起き上がる
    T.charge([A], 4.0, 7.4, [C_GREEN], aura=True)                               # 覚醒: オーラが噴き上がる
    T.hits.append(bout.H(7.4, "heel", (A.x, 0.1), 0.08))                        # 足もとの地面が割れる
    T.flashes.append(7.4)
    D.charge_pose(7.6, 8.6)
    B.charge_pose(7.6, 8.6)
    C.charge_pose(7.6, 8.6)
    A.hold_arm_out(8.5, 10.4)
    T.shield(A, 8.55, 10.4, 9.0, r=0.65)
    for f, dt in ((D, 0.0), (B, 0.04), (C, 0.08)):
        T.beam(f, 8.7 + dt, 1.5, A.x + 0.45, C_WHITE, boom=False)
    T.hits.append(bout.H(10.3, "blast", (A.x + 0.5, 1.3), 0.08))               # 盾が弾けて光線を押し返す
    T.flashes.append(10.3)
    for f in (D, B, C):
        f.stagger(10.4, push=0.5)
    T.cam.append((3.8, 7.8, 3.6, 1.0))                                          # 覚醒は緑に寄る


def act4(F, T):
    """逆転(約 18 秒): 瞬間移動で青 → 分身乱舞で赤 → 巨漢と拳の激突 → 空中コンボで叩きつけ。"""
    A, B, C, D = F["A"], F["B"], F["C"], F["D"]
    T.teleport(A, 0.8, B.x + 0.85, -1)                                          # 青の背後に現れて
    T.exchange(A, B, "cross", 1.3, "launch", dist=1.8, stay=True, flash=True)
    T.exchange(D, A, "hook", 3.2, "duck")                                       # 赤が殴りかかる → くぐって分身乱舞
    t_c = 3.9
    T.clones(A, t_c, t_c + 1.3, [D.x - 0.9, D.x + 0.9], src_tau=3.6)
    T.chain(A, D, [("jab", "stagger"), ("cross", "stagger"), ("hook", "stagger"), ("upper", "stagger"), ("belly", "fold", dict(push=0.3))], t_c + 0.1, gap=0.22)
    T.exchange(A, D, "palm", 5.6, "launch", dist=2.0, stay=True, flash=True)
    T.clash(A, C, "cross", 7.6)                                                 # 巨漢と拳の激突
    T.hits.append(bout.H(7.6, "slam", (0.5 * (A.x + C.x), 1.4), 0.10))
    T.flashes.append(7.6)
    T.air_combo(A, C, 8.6)                                                      # 押し勝って打ち上げ → 空中コンボ
    A.freeze(10.3, 0.5)


def act5(F, T):
    """決着(約 12 秒): 起き上がった 3 人が突っ込む → 緑が溜めて、とどめの光線で 3 人まとめて → 光が消えて、背を向ける。"""
    A, B, C, D = F["A"], F["B"], F["C"], F["D"]
    for f, g in ((D, 0.4), (B, 0.6), (C, 0.8)):
        f.start_lying()
        f.getup(g, 0.6)
    T.charge([A], 1.2, 3.4, [C_GREEN])
    D.dash(2.4, 2.7, A.x + 1.6)
    B.dash(2.5, 2.8, A.x + 2.4)
    C.dash(2.6, 2.95, A.x + 3.4)
    T.beam(A, 3.5, 1.6, A.x + 7.5, C_GREEN, targets=[D], dist=1.9, stay=True)
    for f, dist in ((B, 2.7), (C, 3.6)):                                        # 3 人を少しずつ違う所まで飛ばす(重なって倒れないように)
        f.launch(round((3.62 + 0.03 * (dist > 3)) * 30) / 30, dist=dist, stay=True)
        f.speed.append((3.62, 4.1))
    A.turn(6.3, -1)                                                             # 光が消えて、3 人に背を向ける
    A.relax(6.5, 11.0)
    T.cam.append((3.3, 6.0, 5.4, 1.1))


ACTS = {1: (act1, 12.4, cast((0.0, 1), (-1.9, 1), (1.8, -1), (3.2, -1)), set()),
        2: (act2, 17.0, cast((0.0, 1), (-1.5, 1), (1.2, -1), (2.4, -1)), set()),
        3: (act3, 11.6, cast((-1.6, 1), (0.8, -1), (1.8, -1), (3.0, -1)), set()),
        4: (act4, 11.6, cast((-1.0, 1), (-2.4, 1), (0.8, -1), (2.6, -1)), set()),
        5: (act5, 11.6, cast((-1.8, 1), (0.6, -1), (1.6, -1), (2.9, -1)), set())}


def build(n: int):
    script, t_end, cst, _ = ACTS[n]
    sc, rep, beats = moves.build_bout(f"sanbiki_{n}", BG, t_end, cst, script, cam_scale=CAM, sound="anime")
    sc["vertical_zoom"] = VERTICAL_ZOOM
    sc["qa"] = dict(sc.get("qa") or {}, ground_tol=0.10)
    return sc, rep, beats


if __name__ == "__main__":
    n = int(sys.argv.pop(1))
    sc0, rep0, beats0 = build(n)
    bout.run_cli(lambda: (sc0, rep0), beats0, f"sanbiki_{n}")

"""3 対 1「倒した 3 人が、まとめて仕返しに来る」(2026-10-24 絵コンテで合意。out/storyboard3、Artifact 版 7)。約 72 秒を 5 幕に分ける。
アニメの戦いの型: 降臨 → 連携でピンチ → 覚醒 → 逆転 → 決着。音は戦闘アニメ風(stickfig/sfx_anime.py、audio.style anime)。

幕のつなぎ(2026-10-25「最初の位置に急に戻る」): 各幕は前の幕の終わりの立ち位置・向き・倒れているかを引き継いで始める(`build(n)` が前の幕を組んで
`_end_state` を読む)。幕の中で立ち位置を組み直したいときは regroup(瞬間移動。ほかの人を通り抜けないように)。
光線は仲間を突き抜けないように撃つ: 前の人は低く構えて低く、後ろの巨漢は高く撃つ(頭の上を通す)、または反対側から挟み撃ち。

使い方: python tools/shots/sanbiki.py 1|2|3|4|5 --out out/sb_1 [--check|--plan-only]
エピソード: scenes/episodes/sanbiki.yaml(shot: tools/shots/sanbiki_*.py)
"""
from __future__ import annotations

import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE.parents[1]))
import kachinuki as K1  # noqa: E402
from stickfig import bout, moves  # noqa: E402

BG = dict(image="assets/bg/shrine_dusk.png", x0=-9.5, x1=9.0, ground=0.80)
GREEN, RED, BLUE, PURPLE = [0.5, 0.85, 0.3], [0.92, 0.32, 0.28], [0.25, 0.55, 0.95], [0.62, 0.35, 0.85]
C_GREEN, C_RED, C_BLUE, C_PURPLE, C_WHITE = [120, 255, 140], [255, 110, 90], [110, 170, 255], [190, 120, 255], [255, 236, 240]
G = 1.25
CAM = 4.4                     # 4 人が入る引き
VERTICAL_ZOOM = 1.7          # 縦は人物を大きく(2.8 だと画面の高さの 13% しかなく小さすぎた。遠くに倒れた人は切れてよい)
STYLE = dict(A=("kenpo", GREEN, 1.0), D=("brawler", RED, 1.0), B=("kicker", BLUE, 1.0), C=("giant", PURPLE, G))


def cast_from(state: dict) -> dict:
    """{名前: dict(x, d, lying)} から build_bout の cast を作る。"""
    out = {}
    for w, (style, color, sc) in STYLE.items():
        s = state[w]
        out[w] = dict(color=color, style=style, x=s["x"], d=s["d"], lying=s.get("lying", False), **({"scale": sc} if sc != 1.0 else {}))
    return out


FIRST = dict(A=dict(x=0.0, d=1), D=dict(x=-1.9, d=1), B=dict(x=1.8, d=-1), C=dict(x=3.2, d=-1))


def regroup(F, T, t: float, layout: dict, gap: float = 0.08):
    """緑の今の位置からの相対で、ほかの人を並べ直す(瞬間移動。向きは緑の方)。もうその位置にいる人は動かさない。"""
    ax = F["A"].x
    k = 0
    for w, off in layout.items():
        f = F[w]
        tx = ax + off
        d = -1 if tx > ax else 1
        if abs(f.x - tx) > 0.3 or f.d != d:
            T.teleport(f, t + gap * k, tx, d)
            k += 1


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
    T.teleport(B, 8.45, 3.4, -1)                                                # 青が退き、巨漢が瞬間移動で入る
    T.teleport(C, 8.7, 1.25, -1)
    T.exchange(C, A, "hook", 9.15, "duck")
    T.exchange(D, A, "jab", 9.55, "block", push=0.10)
    T.exchange(A, D, "hook", 10.15, "stagger", push=0.5)                        # 反撃
    T.exchange(A, C, "belly", 10.9, "block", push=0.05, part="chest")          # 巨漢の腹で拳が止まる
    A.shuffle(11.35, 11.6, A.x - 0.45)                                          # 効かない拳に驚いて跳び退く


def act2(F, T):
    """連携(約 17 秒): 青の蹴り → 赤の空中コンボ → 必死にさばく → 巨漢の一撃 → 3 人で挟んで溜め → 合体光線。"""
    A, B, C, D = F["A"], F["B"], F["C"], F["D"]
    regroup(F, T, 0.2, dict(D=-1.5, B=1.2, C=2.6))
    T.exchange(B, A, "front", 0.9, "stagger", push=0.3)
    T.air_combo(D, A, 1.6, getup=0.6, lie=0.5)                                  # 赤のアッパーで打ち上げ → 空中 2 発 → 叩き落とし
    regroup(F, T, 4.4, dict(D=-1.3, B=1.2, C=2.8))
    T.exchange(B, A, "round", 5.1, "block", push=0.35)                          # 起き上がって必死にさばく
    T.exchange(D, A, "cross", 5.65, "stagger", push=0.3)
    T.exchange(A, D, "jab", 6.15, "stagger", push=0.3)
    T.exchange(B, A, "front", 6.7, "stagger", push=0.35)
    T.exchange(A, B, "cross", 7.2, "lean")
    T.teleport(B, 7.6, A.x + 3.6, -1)                                           # 青が退き、巨漢が前へ
    T.exchange(C, A, "cross", 8.4, "launch", dist=2.0, lie=0.2, getup=0.6, flash=True)    # 巨漢の一撃で吹き飛ぶ
    A.kneel(10.4, 13.9)                                                         # 膝をつく
    regroup(F, T, 10.0, dict(B=-2.2, D=1.8, C=3.3))                             # 青は反対側へ回り込み、挟み撃ち
    T.charge([D, B, C], 10.9, 13.8, [C_RED, C_BLUE, C_PURPLE])
    ax = A.x
    T.beam(D, 13.9, 1.1, ax + 0.25, C_WHITE, targets=[A], boom=True, width=0.62, z_end=0.95, hz=0.46, dist=0.5, stay=True)   # 赤は低く構えて低く
    T.beam(C, 13.94, 1.1, ax + 0.25, C_WHITE, boom=False, width=0.66, z_end=1.25)                                            # 巨漢は後ろから、赤の頭の上を通す
    T.beam(B, 13.98, 1.1, ax - 0.25, C_WHITE, boom=False, width=0.62, z_end=1.15)                                            # 青は反対側から
    T.cam.append((10.6, 16.0, 5.2, 1.1, round(ax + 0.6, 3)))


def act3(F, T):
    """覚醒(約 12 秒): 煙の中で起き上がる → オーラが噴き上がる → 光線を片手の盾で受け止める → 盾が弾けて 3 人がのけぞる。"""
    A, B, C, D = F["A"], F["B"], F["C"], F["D"]
    T.puffs += [dict(tau=0.2, kind="land2", pos=[A.x - 0.6, 0.0]), dict(tau=0.5, kind="land2", pos=[A.x + 0.5, 0.0])]
    regroup(F, T, 0.4, dict(D=2.0, B=3.0, C=4.2))                               # 3 人は右に並び直して様子を見る
    A.getup(1.4, 1.4)                                                           # 煙の中でゆっくり起き上がる
    T.charge([A], 4.0, 7.4, [C_GREEN], aura=True)                               # 覚醒: オーラが噴き上がる
    for f in (D, B, C):
        f.shuffle(5.2, 5.6, f.x + 0.35)                                         # 気圧されて一歩下がる
    T.hits.append(bout.H(7.4, "heel", (A.x, 0.1), 0.08))                        # 足もとの地面が割れる
    T.flashes.append(7.4)
    D.charge_pose(7.6, 8.6)
    C.charge_pose(7.6, 8.6)
    A.hold_arm_out(8.5, 10.4)
    T.shield(A, 8.55, 10.4, 9.0, r=0.70)
    T.beam(D, 8.7, 1.5, A.x + 0.55, C_WHITE, boom=False, width=0.6, z_end=1.05, hz=0.46)
    T.beam(C, 8.74, 1.5, A.x + 0.55, C_WHITE, boom=False, width=0.66, z_end=1.45)
    T.hits.append(bout.H(10.3, "blast", (A.x + 0.6, 1.3), 0.08))               # 盾が弾けて光線を押し返す
    T.flashes.append(10.3)
    for f in (D, B, C):
        f.stagger(10.4, push=0.5)
    T.cam.append((3.8, 7.8, 3.6, 1.0, round(A.x + 0.4, 3)))                     # 覚醒は緑に寄る


def act4(F, T):
    """逆転(約 12 秒): 瞬間移動で青 → 分身乱舞で赤 → 巨漢と拳の激突 → 空中コンボで叩きつけ。"""
    A, B, C, D = F["A"], F["B"], F["C"], F["D"]
    regroup(F, T, 0.15, dict(D=-1.5, B=1.6, C=4.4))
    T.teleport(A, 0.8, B.x + 0.85, -1)                                          # 青の背後に現れて
    T.exchange(A, B, "cross", 1.3, "launch", dist=1.6, stay=True, flash=True)
    T.exchange(D, A, "hook", 3.2, "duck")                                       # 赤が殴りかかる → くぐって分身乱舞
    t_c = 3.9
    T.clones(A, t_c, t_c + 1.3, [D.x - 0.9, D.x + 0.9], src_tau=3.6)
    T.chain(A, D, [("jab", "stagger", dict(push=0.3)), ("cross", "stagger", dict(push=0.3)), ("hook", "stagger", dict(push=0.3)), ("upper", "stagger", dict(push=0.3)),
                   ("belly", "fold", dict(push=0.35))], t_c + 0.1, gap=0.24)
    T.exchange(A, D, "palm", 5.8, "launch", dist=2.0, stay=True, flash=True)
    T.clash(A, C, "cross", 7.6)                                                 # 巨漢と拳の激突
    T.hits.append(bout.H(7.6, "slam", (0.5 * (A.x + C.x), 1.4), 0.10))
    T.flashes.append(7.6)
    T.air_combo(A, C, 8.6)                                                      # 押し勝って打ち上げ → 空中コンボ
    A.freeze(10.3, 0.5)


def act5(F, T):
    """決着(約 8 秒 + 歩き去る): 起き上がった 3 人が並ぶ → 緑が溜めて、とどめの光線で 3 人まとめて → 光が消えて、背を向けて歩き去る。"""
    A, B, C, D = F["A"], F["B"], F["C"], F["D"]
    for f, g in ((D, 0.3), (B, 0.45), (C, 0.6)):
        if f._lying:
            f.getup(g, 0.6)
    regroup(F, T, 1.35, dict(D=1.7, B=2.6, C=3.7))
    T.charge([A], 1.3, 3.4, [C_GREEN])
    for f in (D, B, C):
        f.dash(2.5, 2.75, f.x - 0.25)                                           # 3 人が最後に突っ込む
    ax = A.x
    T.beam(A, 3.5, 1.6, ax + 7.5, C_GREEN, targets=[D], width=0.95, dist=1.9, stay=True)
    for f, dist in ((B, 2.7), (C, 3.6)):                                        # 3 人を少しずつ違う所まで飛ばす(重なって倒れないように)
        f.launch(round(3.65 * 30) / 30, dist=dist, stay=True)
        f.speed.append((3.65, 4.1))
    A.turn(6.0, -1)                                                             # 光が消えて、3 人に背を向ける
    A.relax(6.2, 7.6)


ACTS = {1: (act1, 12.4), 2: (act2, 17.0), 3: (act3, 11.6), 4: (act4, 11.6), 5: (act5, 7.6)}
_CACHE: dict = {}


def build(n: int):
    """第 n 幕。前の幕の終わりの立ち位置から始める(前の幕は計算だけで、書き出さない)。"""
    if n in _CACHE:
        return _CACHE[n]
    script, t_end = ACTS[n]
    state = FIRST if n == 1 else build(n - 1)[0]["_end_state"]
    sc, rep, beats = moves.build_bout(f"sanbiki_{n}", BG, t_end, cast_from(state), script, cam_scale=CAM, sound="anime")
    if n == 5:
        K1.walk_out(sc, to_x=sc["_end_state"]["A"]["x"] - 5.5, dur=2.6, facing=-1)     # 背を向けて歩き去る(カメラは止めて見送る)
    sc["vertical_zoom"] = VERTICAL_ZOOM
    sc["qa"] = dict(sc.get("qa") or {}, ground_tol=0.10)
    _CACHE[n] = (sc, rep, beats)
    return _CACHE[n]


if __name__ == "__main__":
    n = int(sys.argv.pop(1))
    sc0, rep0, beats0 = build(n)
    bout.run_cli(lambda: (sc0, rep0), beats0, f"sanbiki_{n}")

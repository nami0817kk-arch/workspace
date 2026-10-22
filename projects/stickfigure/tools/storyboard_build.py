"""勝ち抜き戦 激しさ版の絵コンテを作る(2026-10-22)。3 試合の案(tools/shots/proposal_*.py)から、当たりごとのコマを out/storyboard/ に描き、captions.json を書く。

使い方: python tools/storyboard_build.py
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(Path(__file__).resolve().parent / "shots"))
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import proposal_blue  # noqa: E402
import proposal_giant  # noqa: E402
import proposal_red  # noqa: E402
import storyboard as sb  # noqa: E402
from stickfig import animecheck, fk  # noqa: E402

OUT = Path("out/storyboard")

# (時刻, 見出し, 説明)。時刻はその場面の当たりの時刻(コマはそのときの姿勢)
BLUE = [
    (0.55, "構え合い", "青は蹴り足を揺らして弾み、緑は低い半身。どちらも止まらない。"),
    (1.00, "跳び蹴りを、かがんでくぐる", "青が飛び込んで跳び蹴り。緑は深くかがんで下をくぐる(空振り)。"),
    (1.80, "蹴り 3 連 ① 前蹴り", "青の前蹴りを、緑が両腕で受けて下がる。"),
    (2.10, "蹴り 3 連 ② 高い回し蹴り", "続けて高い回し蹴り。これも受ける。0.3 秒おきに畳みかける。"),
    (2.40, "蹴り 3 連 ③ 胸に入る", "3 発目の前蹴りが緑の胸に入り、緑がのけぞる(緑も被弾する)。"),
    (3.07, "緑の 4 連打 ① 左", "のけぞりから左。ここから 0.24 秒おきに、右 → 大振り → 腹。"),
    (3.77, "緑の 4 連打 ④ 腹", "腹で青が体を折る。止まらずに次の蹴りを受ける側へ。"),
    (4.20, "回し蹴りをくぐる", "青の回し蹴りを、緑がしゃがんでかわす。"),
    (4.67, "足払い → 跳んでかわされる", "緑の足払いを、青が跳んでかわす。"),
    (5.30, "空中からの蹴りを受ける", "青の跳び蹴りを、緑が両腕で受けて押される。"),
    (6.00, "緑の 5 連打 ① アッパー", "沈んだ体を伸ばしてアッパー。右 → 左 → 腹 と 0.27 秒おきに続ける。"),
    (7.07, "5 連打 ⑤ 回し蹴りで吹き飛ぶ", "最後の回し蹴りで青が吹き飛び、背中から落ちて跳ね、すぐ起き上がろうとする。"),
    (8.53, "掌底で倒す", "起き上がりに掌底。青は倒れたまま。緑は振り抜いた形で 0.7 秒止まる。"),
]
GIANT = [
    (0.55, "構え合い", "巨漢は両腕を広げて見下ろす。緑は低く構える。体は 1.25 倍。"),
    (1.00, "大振りをくぐる", "巨漢の大振りが緑の頭の上を通る。"),
    (1.50, "緑の左は受けられる", "胸への左は腕で受けられて効かない。"),
    (1.77, "右も受けられる", "巨漢は一歩も下がらない。"),
    (2.10, "巨漢の右 → 緑が吹き飛ぶ(1 度目)", "一発が重い。緑は背中から飛び、2 回跳ねる。"),
    (3.60, "起き上がって走り込み、右", "吹き飛ばされた先から走り込み、胸に右。巨漢は少しだけ下がる。"),
    (3.90, "足払い", "足元を払うと、巨漢が初めてぐらつく。"),
    (4.30, "腹", "ぐらついた腹に一発。巨漢が体を折る。"),
    (4.87, "巨漢の左 → 2 度目の吹き飛び", "折れた巨漢が左を振り、緑がまた吹き飛ぶ。1 度目より短く、すぐ起きる。"),
    (6.80, "食らいついて 4 連打 ① アッパー", "走り込んでアッパー。右 → 左 → 腹 と 0.26 秒おきに続ける。"),
    (7.57, "4 連打 ④ 腹で崩す", "巨漢が前のめりに折れる。"),
    (7.93, "最後の大振りをくぐる", "巨漢の苦し紛れの大振りを、低くくぐる。"),
    (8.87, "跳び蹴りで倒す", "跳び蹴りが胸に入り、巨漢が仰向けに倒れる。緑は決めの止め絵。"),
]
RED_FIRST = [
    (0.50, "構え合い", "赤は両拳を顔の前に高く、背を丸めて前のめり。緑は低い半身。"),
    (0.90, "大振りをくぐる", "赤の大振りを、緑がしゃがんでくぐる。"),
    (1.43, "アッパーは受けられる", "くぐって返したアッパーを、赤が腕で受ける。"),
    (1.90, "赤の右が入る(緑も被弾)", "赤の右が緑の顔に入る。緑がのけぞる。"),
    (2.53, "拳と拳がぶつかる", "同時に右。真ん中で拳がぶつかり、火花。どちらも弾かれる。"),
    (3.20, "緑の 3 連 ① 前蹴り", "弾かれた勢いのまま前蹴り。続けて右、左を 0.28 秒おき。"),
    (3.77, "緑の 3 連 ③ 左", "赤が下がりながら受けきれない。"),
    (4.30, "赤の腹打ち(緑が折れる)", "赤が低く入って腹へ。緑が体を折る。"),
    (4.93, "折れながら返す左", "折れた体のまま左を返す。ここから空中戦。"),
]


def real_panels(mod, rows, tag):
    sc, rep, beats = mod.build()
    hits = {round(h["tau"], 3): h for h in sc["hits"]}
    out = []
    for i, (t, title, text) in enumerate(rows):
        figs = [sb.fig_from_scene(sc, "A", t), sb.fig_from_scene(sc, "B", t)]
        hs = [tuple(h["pos"]) for k, h in hits.items() if abs(k - t) < 0.04 and h["kind"] in ("hit", "kick", "clash")]
        path = OUT / tag / f"p{i + 1:02d}.png"
        sb.panel(figs, path, hits=hs, label=f"{t:.2f} 秒")
        out.append(dict(img=f"{tag}/p{i + 1:02d}.png", t=t, title=title, text=text))
    r = animecheck.intensity(sc, beats)
    return out, dict(exchanges=r.get("exchanges_per_s"), gap=r.get("max_gap_s"), moving=r.get("moving"), seconds=sc["tau_end"], hits=len(beats))


def air_panels():
    """決勝の後半: 空中コンボ(動作はこれから作る。IK で組んだ姿勢)。"""
    A, B = "A", "D"
    gd = [(0.3, 0.0, 0.2, 0.0)]
    guard = dict(fa=1.05, fe=2.35, ra=0.65, re=2.6)
    out = []

    def add(name, title, text, figs, hits=(), arrows=(), ghosts=(), h=420):
        path = OUT / "red_air" / f"{name}.png"
        sb.panel(figs, path, hits=hits, arrows=arrows, ghosts=ghosts, h=h, ppu_max=120, label=title)
        out.append(dict(img=f"red_air/{name}.png", title=title, text=text))

    # ① 沈む(溜め)
    a = sb.fig_made(A, -0.1, 1, hz=0.50, lean=0.40, r_hand=None, f_foot=(0.15, 0), r_foot=(-0.55, 0), ang=dict(fa=1.2, fe=1.8, ra=0.1, re=1.9))
    b = sb.fig_made(B, 1.05, -1, hz=0.74, lean=0.38, f_foot=(0.80, 0), r_foot=(1.35, 0), ang=guard, color=sb.COLORS["D"])
    add("a01", "① 沈む", "腹打ちで折れた緑が、そのまま深く沈む。赤は追い打ちに踏み込む。0.2 秒の溜め。", [a, b])
    # ② アッパーが顎に入る
    bpos = (1.0, 1.50)
    b2 = sb.fig_made(B, 1.10, -1, hz=0.86, lean=-0.7, ht=0.95, rz=0.30, f_foot=(0.85, 0.20), r_foot=(1.45, 0.25), ang=dict(fa=2.0, fe=0.6, ra=1.8, re=0.7), color=sb.COLORS["D"])
    chin = (b2["x"] - 0.18, b2["pose"]["hz"] + b2["pose"]["rz"] + 0.5)
    a2 = sb.fig_made(A, 0.30, 1, hz=0.86, lean=0.05, ht=0.15, r_hand=(0.82, 1.55), f_foot=(0.55, 0), r_foot=(-0.10, 0), ang=dict(fa=0.5, fe=1.2))
    add("a02", "② アッパーが顎に入る", "沈んだ体を一気に伸ばしてアッパー。赤の顎が跳ね、足が地面を離れる。", [a2, b2], hits=[(0.95, 1.55)])
    # ③ 打ち上げ
    b3 = sb.fig_made(B, 1.35, -1, hz=0.80, lean=-0.30, rz=1.15, roll=0.30, ht=0.5, ang=dict(fa=2.6, fe=0.4, ra=2.4, re=0.5, fl=0.5, fk=1.0, rl=0.1, rk=0.8), color=sb.COLORS["D"])
    a3 = sb.fig_made(A, 0.55, 1, hz=0.50, lean=0.30, f_foot=(0.80, 0), r_foot=(0.20, 0), ang=dict(fa=-0.4, fe=0.6, ra=-0.6, re=0.7))
    add("a03", "③ 打ち上げ", "赤が人の背の倍の高さまで浮く。緑は着地と同時にもう一度沈む(跳ぶ溜め)。", [a3, b3], arrows=[((1.15, 1.2), (1.35, 2.7))], h=470)
    # ④ 追って跳ぶ
    b4 = sb.fig_made(B, 1.50, -1, hz=0.80, lean=-0.20, rz=1.85, roll=0.50, ht=0.3, ang=dict(fa=2.5, fe=0.3, ra=2.3, re=0.4, fl=0.7, fk=1.2, rl=0.3, rk=1.0), color=sb.COLORS["D"])
    a4 = sb.fig_made(A, 0.95, 1, hz=0.84, lean=-0.05, rz=1.00, ang=dict(fa=0.9, fe=1.6, ra=1.0, re=1.7, fl=0.6, fk=1.5, rl=-0.2, rk=1.3))
    add("a04", "④ 追って跳ぶ", "赤が頂点で止まる一瞬、緑が真下から跳び上がる。", [a4, b4], arrows=[((0.60, 0.3), (0.95, 1.7))], ghosts=[a3], h=480)
    # ⑤ 空中 1 発目
    b5 = sb.fig_made(B, 1.65, -1, hz=0.80, lean=-0.25, rz=1.80, roll=0.45, ht=0.2, ang=dict(fa=2.4, fe=0.4, ra=2.2, re=0.5, fl=0.7, fk=1.2, rl=0.3, rk=1.0), color=sb.COLORS["D"])
    sk = fk.skeleton(b5["pose"], -1, b5["x"], 1.0)
    chest = ((sk["torso"][0][0] + sk["torso"][1][0]) / 2 + 0.10, (sk["torso"][0][1] + sk["torso"][1][1]) / 2)
    a5 = sb.fig_made(A, chest[0] - 0.82, 1, hz=0.82, lean=0.30, rz=chest[1] - 1.30, r_hand=chest, ang=dict(fa=0.5, fe=1.2, fl=0.5, fk=1.4, rl=-0.3, rk=1.2))
    add("a05", "⑤ 空中 1 発目", "空中で右を胸に。赤が押し戻されて回り始める。", [a5, b5], hits=[chest], h=480)
    # ⑥ 空中 2 発目
    b6 = sb.fig_made(B, 2.00, -1, hz=0.80, lean=-0.10, rz=1.70, roll=0.95, ht=0.2, ang=dict(fa=2.3, fe=0.5, ra=2.4, re=0.4, fl=0.6, fk=1.1, rl=0.5, rk=0.9), color=sb.COLORS["D"])
    sk6 = fk.skeleton(b6["pose"], -1, b6["x"], 1.0)
    chest6 = ((sk6["torso"][0][0] + sk6["torso"][1][0]) / 2 + 0.05, (sk6["torso"][0][1] + sk6["torso"][1][1]) / 2)
    a6 = sb.fig_made(A, chest6[0] - 0.84, 1, hz=0.82, lean=0.38, rz=chest6[1] - 1.30, f_hand=chest6, ang=dict(ra=-0.5, re=0.8, fl=0.5, fk=1.4, rl=-0.3, rk=1.2))
    add("a06", "⑥ 空中 2 発目", "続けて左。赤は回転しながらさらに遠くへ飛ぶ(0.25 秒おき)。", [a6, b6], hits=[chest6], ghosts=[b5], h=480)
    # ⑦ 叩きつけ
    b7 = sb.fig_made(B, 2.20, -1, hz=0.78, lean=0.3, rz=1.50, roll=2.7, ht=0.0, ang=dict(fa=2.6, fe=0.3, ra=2.5, re=0.3, fl=0.4, fk=0.6, rl=0.3, rk=0.7), color=sb.COLORS["D"])
    sk7 = fk.skeleton(b7["pose"], -1, b7["x"], 1.0)
    back = ((sk7["torso"][0][0] + sk7["torso"][1][0]) / 2, (sk7["torso"][0][1] + sk7["torso"][1][1]) / 2)
    a7 = sb.fig_made(A, back[0] - 0.20, 1, hz=0.80, lean=0.20, rz=back[1] + 0.05 - 1.1, f_hand=(back[0], back[1] + 0.05), r_hand=(back[0] - 0.05, back[1] + 0.10), ang=dict(fl=0.4, fk=1.2, rl=-0.3, rk=1.1))
    add("a07", "⑦ 叩きつけ(両手で振り下ろす)", "頭上から両手を組んで背中に振り下ろす。赤が頭を下にして落ち始める。", [a7, b7], hits=[back], arrows=[((back[0] + 0.45, back[1] + 0.2), (back[0] + 0.55, 0.9))], h=480)
    # ⑧ 地面で跳ねる
    b8 = sb.fig_made(B, 2.40, -1, hz=0.78, lean=0.0, rz=0.34, roll=1.57, ht=0.0, ang=dict(fa=2.6, fe=0.3, ra=2.4, re=0.3, fl=0.3, fk=0.2, rl=0.1, rk=0.2), color=sb.COLORS["D"])
    a8 = sb.fig_made(A, 1.55, 1, hz=0.56, lean=0.30, f_foot=(1.82, 0), r_foot=(1.22, 0), ang=dict(fa=1.0, fe=1.2, ra=0.8, re=1.2))
    add("a08", "⑧ 地面で跳ねる", "赤が地面に叩きつけられて一度跳ね、緑は着地でつぶれる。砂ぼこり。", [a8, b8], hits=[(2.30, 0.2)])
    # ⑨ 決め
    b9 = sb.fig_made(B, 2.75, -1, hz=0.78, lean=0.0, rz=0.21, roll=1.57, ang=dict(fa=2.6, fe=0.3, ra=2.4, re=0.3, fl=0.3, fk=0.2, rl=0.1, rk=0.2), color=sb.COLORS["D"])
    a9 = sb.fig_made(A, 1.95, 1, hz=0.77, lean=-0.12, ht=0.35, f_foot=(2.18, 0), r_foot=(1.55, 0), ang=dict(fa=2.55, fe=0.15, ra=-0.5, re=2.3))
    add("a09", "⑨ 決めの止め絵", "緑が拳を突き上げて 0.8 秒止まる。赤は倒れたまま(看板に星)。", [a9, b9])
    return out


def main():
    data = {}
    for name, mod, rows in (("blue", proposal_blue, BLUE), ("giant", proposal_giant, GIANT), ("red_first", proposal_red, RED_FIRST)):
        panels, meta = real_panels(mod, rows, name)
        data[name] = dict(panels=panels, meta=meta)
        print(name, meta, len(panels), "コマ")
    data["red_air"] = dict(panels=air_panels(), meta={})
    (OUT / "captions.json").write_text(json.dumps(data, ensure_ascii=False, indent=1), encoding="utf-8")
    print("書いた:", OUT / "captions.json")


if __name__ == "__main__":
    main()

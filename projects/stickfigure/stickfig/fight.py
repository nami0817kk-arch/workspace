"""戦いの台本を、数行の指定(spec)から自動で組む。純粋な Python。

台本(YAML)を手で書くと 200 行になり、時刻・位置・clip・カメラ・演出を全部そろえる必要がある(周1〜14で毎回そうだった)。
ここでは、見本(scenes/showpiece_anime15.yaml / brawl_a.yaml)で形になった組み立てを、部品(ビート)にして残す:

    kick      蹴り → 壁に叩きつけ → 倒れる(速い早送りで間延びを消す)
    combo     斬り/打撃の連打(回数 hits)。counter: true で、2発目の前に相手の反撃(パンチ)を挟む
    finisher  最後の一撃。launch_slash(打ち上げ → 空中で斬り下ろし → 叩きつけ) / none(まっすぐ倒れる)

使い方(scenes/*.yaml の先頭に fight: を書く。ほかのキーは上書きとして重なる):

    fight: {weapon: sword, kick: true, hits: 3, counter: true, finisher: launch_slash, palette: warm}

出力の台本は、そのまま `python -m stickfig check/build` に渡せる。リズム(カットの頻度・2コマ撮り・閃光・揺れ)は
`rhythm.REFERENCE`(参考6本の範囲)に入るよう、既定値を決めてある。
"""
from __future__ import annotations

import copy
import random
from typing import Dict, List

DEFAULTS = dict(
    weapon="sword",          # sword / dagger / staff / spear / none(素手)
    kick=True,               # 冒頭の蹴り → 壁
    hits=3,                  # 連打の回数(1〜4)
    counter=True,            # 1発目のあと、相手の反撃
    finisher="launch_slash", # launch_slash(決めの斬りで打ち上げ→空中斬り→叩きつけ) / launch_kick(決めは高い蹴りで打ち上げ) / random(seed で選ぶ) / none(まっすぐ倒れる)
    palette="warm",          # warm / cool
    colors=dict(A=[0.3, 0.68, 0.1], B=[0.8, 0.1, 0.08]),
    tempo=1.35,
    a_scale=1.0,             # こちら側(A)の大きさ。負け場面で相手(A)を大柄にするとき
    b_scale=1.0,             # 相手の大きさ(1.3 で大柄のボス)。連打の位置は固定なので 1.15〜1.35 まで
    stage="cave",            # 舞台の色の組: cave / dojo / field / night / sunset
    ally=None,               # 3人目(味方): {color, x(置く位置), y(奥行き。+で奥), facing(+1右向き/-1左向き), scale, cheer(勝ったら万歳 true/負けたらうなだれる false)}。戦わず、見守る
    block=True,              # 連打の途中を相手が防ぐ(hits が3以上): 2発目は 受け止め(clash) か かわす(miss)。seed があれば選ぶ、無ければ受け止め。hits≧4 なら3発目にもう一方
    b_combo=2,               # A の決めの1発の前に、相手(B)が打ち返す回数(A はかわし→受け止め)。0 で無し。長い武器では無し
    mix_kick=True,           # 連打の途中(防がれない1発)を蹴りにする(hits≧3、seed があれば半々)
    b_first=True,            # 蹴り無しのとき、B が先に2発仕掛ける(A がかわし→受け止め)。攻守の入れ替わり
    riposte=True,            # 受け止めた直後に、相手(B)が打ち返し、こちら(A)が受け止める(鍔迫り合いの往復)
    camera=None,             # "fixed" で検証用の固定カメラ(カット・寄り・連打カット・決めの引きを無くす)
    timing=True,             # アニメの間: clip の時間配分を「溜め→一気→振り抜き」に(plan.ClipBank.warped_u)
    exaggerate=1.25,         # 振りの誇張: 命中の clip の腕の角度を、平均からの差で 1.25 倍
    footwork=True,           # 足運び: 接地した足を滑らせず、体が動いた分だけ踏み替える(plan._footwork)
    body=1.7,                # 全身の動きの強さ(0 で切る)。命中ごとに、攻める側のひねり込み・踏み込み、受ける側ののけぞり・押される動き
    seed=None,               # 数字を入れると、連打の clip・間・溜めの色・カットの順を、その数字で変える(同じ数字なら同じ戦い)
    mood="battle",           # BGM の雰囲気: battle / tense / calm / sad / none
    captions=False,          # 字幕(lines)を出すか。既定は出さない(2026-10-19 ユーザー「字幕はいらない」)。True で lines を字幕にする
    lines=[],                # 台詞・ナレーション: [{at: opening|kick|rise|combo|counter|last|finisher|ko|end, dt: 0, dur: 1.6, kind: say|narr|shout, who: A, text: "…"}]
)

PALETTES = {
    "warm": [(150, 175, 235, .55), (170, 190, 230, .45), (255, 170, 110, .6), (255, 190, 130, .5), (140, 170, 235, .5),
             (90, 130, 220, .65), (255, 200, 150, .55), (255, 150, 110, .6), (200, 170, 230, .5), (190, 160, 220, .55)],
    "cool": [(150, 200, 255, .55), (140, 190, 255, .5), (120, 200, 255, .55), (160, 210, 255, .5), (130, 170, 240, .5),
             (90, 130, 220, .65), (170, 210, 255, .5), (140, 190, 255, .55), (190, 180, 240, .5), (190, 170, 235, .55)],
}

GUARD = dict(lean=0.1, fa=0.9, fe=1.4, ra=0.7, re=1.5, ht=0.0, face="fight")
BLOCK = dict(lean=0.18, fa=1.75, fe=0.55, ra=1.45, re=0.8, ht=-0.1, face="fight")      # 受け止め: 両腕を上げて剣(腕)を前に
GUARD_A = dict(lean=0.1, fa=0.7, fe=1.6, ra=0.5, re=1.7, ht=0.0, face="fight")
A_FACE = dict(target="A", z=1.5, yaw=12, pitch=2, scale=1.5, lens=40, hue=0)
B_FACE = dict(target="B", z=1.5, yaw=-14, pitch=3, scale=1.5, lens=40, hue=1)
A_HAND = dict(target="A", z=1.1, ox=0.5, yaw=30, pitch=-6, scale=1.2, lens=24, hue=3, dutch=7.0)
A_FOOT = dict(target="A", z=0.5, ox=0.3, yaw=35, pitch=4, scale=1.6, lens=22, hue=0, dutch=-6.0)
HERO = [dict(target="A", z=1.35, yaw=18, pitch=-6, scale=3.3, lens=24, streak=False, dutch=-4.0),
        dict(target="A", z=1.35, yaw=-25, pitch=-5, scale=3.3, lens=26, streak=False)]
# 連打に使う clip(モーションキャプチャ)。命中時に相手との間隔が合うものを、周8で選んだ
HIT_CLIPS = ["02_08_s1", "02_09_s1", "02_07_s2", "02_07_s1"]
POOL_MID = ["02_08_s1", "02_09_s1", "02_07_s1", "02_08_s2", "02_09_s2", "02_07_s2"]     # 途中の連打(位置を台本で与える)に使える clip
CHARGE_COLORS = [[120, 230, 255], [255, 170, 60], [255, 90, 200], [170, 255, 120]]
COUNTER_CLIP = "13_17_s1"
COUNTER_CLIPS = ["13_17_s1", "13_17_s2", "90_05_s2", "90_16_s1"]      # 届く手の clip(命中時の間隔 0.45〜0.75)。seed で選ぶ
# 突く・振る瞬間の、手と先端の向き(clip の strike 時の姿勢を fk で測った。2026-10-19):
#   02_xx はボクシングのパンチで、剣を持たせると刃が真下を向く。剣は 76_01_s1(水平の突き)・90_05_s2(前へ振る)・13_17(高く振り上げる)を使う
# 値は「狙う点」: 先端の高さに合う相手の部位(先端が低い clip は腰、高い clip は頭)。無い組み合わせは chest
STRIKES = {
    "76_01_s1": dict(hand="chest", tip="chest", long="chest"),
    "90_05_s2": dict(hand="chest", tip="hip", long="hip"),
    "13_17_s1": dict(hand="head", tip="head", long="head"),
    "13_17_s2": dict(hand="chest", tip="neck", long="neck"),
    "02_08_s1": dict(hand="chest"), "02_09_s1": dict(hand="chest"), "02_07_s2": dict(hand="chest"), "02_08_s2": dict(hand="chest"),
    "02_09_s2": dict(hand="hip"), "02_07_s1": dict(hand="hip"), "90_16_s1": dict(hand="hip"),
}
SWORD_POOL = ["76_01_s1", "90_05_s2", "13_17_s2", "13_17_s1"]        # 剣・短剣(先端 tip で当てる)
PUNCH_POOL = ["02_08_s1", "02_09_s1", "76_01_s1", "90_05_s2", "13_17_s2"]   # 素手(手で当てる)
LONG_POOL = ["76_01_s1", "90_05_s2"]                                  # 棍・槍(先端。長いので低めの軌道だけ)


RUN_LOOK = dict(amp=dict(fa=1.35, ra=1.35, fl=1.2, rl=1.2), add=dict(lean=0.2, hz=-0.03))   # 走りの誇張(アニメの走り: 前傾・腕を大きく振る。mocap は直立で腕が低い)


def _pt(clip_name: str, eff: str) -> str:
    key = {"tip": "tip", "hand": "hand"}.get(eff, "hand")
    return STRIKES.get(clip_name, {}).get(key, "chest")



def _r(x: float) -> float:
    return round(x, 3)


def _layout_captions(lines: List[dict], marks: Dict[str, float], end: float, tempo: float) -> List[dict]:
    """台詞の並べ方: 読む時間(1文字 0.10秒+0.5秒、最大2秒を、テンポで設計時間に直す)を確保し、
    吹き出し・叫び(しゃべる系)どうしは重ならないよう順に並べる(前の台詞が終わるまで待つ。間に合わないときは、読む時間の75%まで縮める)。
    ナレーションは別の帯なので、しゃべる系とは重なってよい。"""
    items = []
    for ln in lines:
        t0 = marks[ln.get("at", "opening")] + float(ln.get("dt", 0.0))
        need = min(2.0, 0.5 + 0.10 * len(ln["text"])) * tempo
        items.append((t0, ln, max(float(ln.get("dur", 1.0)), need), need))
    items.sort(key=lambda x: x[0])
    caps, cursor = [], {"say": -9.0, "narr": -9.0}
    for t0, ln, dur, need in items:
        k = ln.get("kind", "say")
        cls = "narr" if k == "narr" else "say"
        t0 = max(0.0, t0, cursor[cls] + 0.06)
        t1 = t0 + dur
        if t1 > end - 0.05:                                  # はみ出すときは、まず縮め(最小で読む時間の75%)、それでも足りなければ出だしを早める
            t1 = end - 0.05
            if t1 - t0 < need * 0.75:
                t0 = max(0.0, t1 - need * 0.75)
        cursor[cls] = t1
        c = dict(kind=k, text=ln["text"], t0=_r(t0), t1=_r(t1))
        for key in ("who", "color", "size", "y", "max_w", "last_words"):
            if key in ln:
                c[key] = ln[key]
        caps.append(c)
    return caps


def build_fight(spec: dict) -> dict:
    s = copy.deepcopy(DEFAULTS)
    s.update({k: v for k, v in (spec or {}).items() if k in DEFAULTS})
    rng = random.Random(s["seed"]) if s["seed"] is not None else None
    pool = PUNCH_POOL if s["weapon"] == "none" else (LONG_POOL if s["weapon"] in ("staff", "spear") else SWORD_POOL)
    mid_clips = [pool[i % len(pool)] for i in range(4)]
    last_clip = pool[0]
    cclip = COUNTER_CLIP
    if rng is not None:
        mid_clips = [rng.choice(pool) for _ in range(4)]
        last_clip = rng.choice(pool)
        cclip = rng.choice(COUNTER_CLIPS)
    sword = s["weapon"] in ("sword", "dagger", "staff", "spear")      # 武器あり(斬りの弧・剣先の接触)
    long_w = s["weapon"] in ("staff", "spear")                        # 長い武器: 途中の打ち・受け止めは手の位置で合わせる(先端は大きく振れて解けない)
    n = max(1, min(4, int(s["hits"])))
    kick = bool(s["kick"])
    if s["finisher"] == "random":
        s["finisher"] = (rng.choice(["launch_slash", "launch_kick"]) if rng is not None else "launch_slash")
    fin = s["finisher"] in ("launch_slash", "launch_kick")
    fin_kick = s["finisher"] == "launch_kick"
    bfirst = bool(s["b_first"]) and not kick and s["weapon"] not in ("staff", "spear")
    o = 0.0 if kick else (-2.4 + (0.95 if bfirst else 0.0))          # 蹴りが無いぶん、連打の開始が早まる(B が先に仕掛けるなら、その分を空ける)
    tc = 4.0 + o                       # 連打の準備(起き上がり)の終わり

    keysA: List[dict] = [dict(t=0.0, dx=0.2, hz=0.84), dict(t=0.6, dx=0.2, lean=0.12, hz=0.83)]
    keysB: List[dict] = [dict(t=0.0)]
    clipsA: List[dict] = [dict(file="09_01", start=0.6, end=1.55, loop=True, anchor_dx=0.2, **RUN_LOOK, **{"in": 0.12, "out": 0.2})]
    clipsB: List[dict] = []
    hits: List[dict] = []
    puffs: List[dict] = []
    slow: List[dict] = []
    flurry: List[dict] = []
    charge: List[dict] = []
    flashes: List[float] = []
    speed: List[list] = [[0.5, 1.3]]
    shots: List[dict] = []

    # ---- 冒頭: 対峙(2人が一歩ずつ踏み出し、見合って止まる。止めの間にカメラが寄る) ----
    shots.append(dict(t=0.0, follow="mid", scale=[[0.0, 7.4], [1.0, 6.4]], yaw=[[0.0, 12.0], [1.0, 22.0]], pitch=9.0, lens=40.0))
    keysA.insert(1, dict(t=0.42, dx=0.36, hz=0.84, lean=0.1))
    keysB.append(dict(t=0.42, dx=(0.15 if kick else -1.55)))
    hits.append(dict(tau=0.5, hold=0.12, kind="pose"))
    keysB.append(dict(t=1.0, dx=0.35))
    if kick:
        charge.append(dict(start=1.3, end=1.7, who="A", color=[255, 170, 60]))
        fa = [A_FACE, B_FACE, A_FOOT, A_FACE]
        if rng is not None:
            rng.shuffle(fa)
        flurry.append(dict(start=1.12, end=1.64, every=4, angles=fa))
        hits += [dict(tau=1.66, hold=0.13, kind="pose"),
                 dict(tau=1.9, hold=0.09, kind="kick", by="A", contact=dict(striker="A", effector="foot", target=dict(actor="B", point="hip"), tol=0.26)),
                 dict(tau=2.25, hold=0.06, kind="wall", pos=[6.0, 1.6])]
        slow += [dict(start=1.85, end=2.4, rate=0.35), dict(start=2.5, end=3.15, rate=2.2)]
        puffs.append(dict(tau=3.0, kind="land", pos=[4.6, 0.0]))
        clipsA.append(dict(file="135_07_s1", strike_at=1.9, start=1.5, end=2.7, **{"in": 0.2, "out": 0.3}))
        keysA += [dict(t=2.7, dx=3.4, hz=0.9), dict(t=3.2, dx=3.4, hz=0.9)]
        keysB += [dict(t=1.9, dx=0.35),
                  dict(t=1.95, dx=0.3, lean=0.55, hz=0.88, fa=0.9, ra=0.8, fe=0.9, re=0.9, ht=0.5, face="pain"),
                  dict(t=2.25, dx=-1.5, rz=1.45, roll=1.57, hz=0.9, fa=-0.6, ra=-0.6, fe=0.2, re=0.2, fl=0.0, fk=0.0, rl=0.0, rk=0.0, lean=-0.2, ht=-0.7, face="pain"),
                  dict(t=2.6, dx=-1.2, rz=0.9, roll=1.57, hz=0.9, lean=0.0),
                  dict(t=3.0, dx=-1.3, rz=0.21, roll=1.57, hz=0.9, fa=0.4, ra=0.4, face="ko"),
                  dict(t=3.5, dx=-1.3, rz=0.21, roll=1.57, hz=0.9, face="ko"),
                  dict(t=4.0, dx=-1.5, rz=0.0, roll=0.5, hz=0.85, lean=0.15, fa=0.9, ra=0.9, fe=1.0, re=1.0, face="fight"),
                  dict(t=4.4, dx=-1.7, rz=0.0, roll=0.0, hz=0.82, lean=0.1, fa=0.9, fe=1.4, ra=0.7, re=1.5, fl=0.45, fk=0.3, rl=-0.45, rk=0.4, face="fight")]
        shots += [
            dict(t=1.0, follow="A", scale=[[1.0, 5.2], [1.85, 4.2]], yaw=[[1.0, -28.0], [1.85, -14.0]], pitch=5.0, lens=32.0, target_z=1.0, lag=0.3),
            dict(t=1.85, follow="mid", scale=[[1.85, 3.2], [2.1, 3.6]], yaw=[[1.85, 38.0], [2.1, 46.0]], pitch=-9.0, lens=28.0, target_z=1.15, dutch=-4.0),
            dict(t=2.1, follow="B", scale=6.0, yaw=[[2.1, 62.0], [2.9, 50.0]], pitch=3.0, lens=40.0, target_z=1.2, lag=0.35),
            dict(t=2.9, follow="mid", scale=[[2.9, 8.5], [3.6, 9.5]], yaw=[[2.9, 15.0], [3.6, 25.0]], pitch=[[2.9, 30.0], [3.6, 22.0]], lens=40.0, target_z=0.7),
            dict(t=3.6, follow="A", scale=[[3.6, 5.6], [4.4, 4.4]], yaw=[[3.6, -38.0], [4.4, -20.0]], pitch=4.0, lens=30.0, target_z=1.0, lag=0.3)]
        clipsA.append(dict(file="09_01", start=3.2, end=3.52, loop=True, anchor_dx=3.4, **RUN_LOOK, **{"in": 0.15, "out": 0.2}))   # 0.32 秒 ≒ 1.2 単位(dx 3.4 → 4.6)。長いと B を追い越して戻る
        keysA.append(dict(t=3.55, dx=4.6, hz=0.9))
        speed.append([3.3, 4.1])
        a_dx0 = 3.4
    else:                                                # 蹴り無し: B は最初から構えの位置に立つ(以前は 0.6 秒で 2 単位後ろへ滑っていた)
        keysB = [dict(t=0.0, dx=-1.7), dict(t=tc, dx=-1.7, rz=0.0, roll=0.0, hz=0.82, lean=0.1, fa=0.9, fe=1.4, ra=0.7, re=1.5, fl=0.45, fk=0.3, rl=-0.45, rk=0.4, face="fight")]
        ta = tc - 0.95 if bfirst else tc                 # A が構えの位置に着く時刻
        a_dx = (4.0 if sword else 4.6) if bfirst else 3.4   # B が先に仕掛けるときは、B の拳が届く所まで寄る(剣なら、そのあと剣の間合いへ戻る分を小さく)
        clipsA[0].update(end=_r(ta))
        keysA.append(dict(t=_r(ta), dx=a_dx, hz=0.9))
        if bfirst:                                       # B が先に仕掛ける: 1発目は A が沈んでかわし(miss)、2発目は A が受け止める(clash)
            tb1, tb2 = tc - 0.78, tc - 0.40
            keysB = [dict(t=0.0, dx=-1.7), dict(t=_r(tc - 1.2), dx=-1.7, **GUARD), dict(t=_r(tb1 - 0.15), dx=-1.0, **GUARD),
                     dict(t=_r(tc - 0.18), dx=-1.4, **GUARD), keysB[-1]]
            clipsB += [dict(file=cclip, dx_scale=0.3, strike_at=_r(tb1), start=_r(tb1 - 0.2), end=_r(tb1 + 0.17), **{"in": 0.06, "out": 0.08}),
                       dict(file=cclip, dx_scale=0.3, strike_at=_r(tb2), start=_r(tb2 - 0.17), end=_r(tb2 + 0.25), **{"in": 0.06, "out": 0.1})]
            hits += [dict(tau=_r(tb1), hold=0.0, kind="miss", by="B", pos=[2.9, 1.25],
                          contact=dict(striker="B", effector="hand", target=dict(actor="A", point="head"), offset=[-0.25, 0.22], tol=1.5, max_anticipation=50)),
                     dict(tau=_r(tb2), hold=0.07, kind="clash", by="B", contact=dict(striker="B", effector="hand", target=dict(actor="A", point=_pt(cclip, "hand")), tol=0.45, max_anticipation=50, hz_range=0.5))]
            keysA += [dict(t=_r(tb2 - 0.14), dx=4.6, **BLOCK), dict(t=_r(tb2 + 0.08), dx=4.6, **BLOCK), dict(t=_r(tb2 + 0.26), dx=4.6, **GUARD_A)]
            speed.append([_r(tb1 - 0.3), _r(tb2 + 0.1)])
        shots.append(dict(t=1.0, follow="A", scale=[[1.0, 4.8], [tc + 0.4, 3.9]], yaw=[[1.0, -38.0], [tc + 0.4, -20.0]], pitch=4.0, lens=30.0, target_z=1.0, lag=0.3))
        speed.append([tc - 0.7, tc + 0.1])
        a_dx0 = 3.4

    # ---- 連打 ----
    charge.append(dict(start=tc - 0.05, end=tc + 0.3, who="A", color=(rng.choice(CHARGE_COLORS) if rng is not None else [120, 230, 255])))
    hits.append(dict(tau=_r(tc + 0.3), hold=0.11, kind="pose"))
    fb = [B_FACE, A_FACE, A_HAND]
    if rng is not None:
        rng.shuffle(fb)
    flurry.append(dict(start=_r(tc - 0.1), end=_r(tc + 0.3), every=4, angles=fb))
    kind_hit = "slash" if sword else "hit"
    eff = "tip" if sword else "hand"
    eff_mid = "hand" if (long_w or not sword) else "tip"
    h0 = tc + 0.4
    if long_w:                                           # 長い武器: 相手の拳は届かないので、反撃・受け返し・先に仕掛けるは無し。防ぐのはかわすだけ
        s["counter"] = False; s["riposte"] = False
    bc = int(s["b_combo"]) if (s["b_combo"] and n >= 2 and not long_w) else 0
    if bc and n <= 2:
        s["counter"] = False                             # 2 発しか無いときは、反撃と B の連打が重なるので反撃は無し
    gaps = [0.72, 0.46, 0.46, 0.46] if s["counter"] else [0.46, 0.46, 0.46, 0.46]      # clip の区間(前 0.16+後 0.14+混ぜ 0.12)が重ならない間隔
    if s["timing"]:
        gaps = [round(g + 0.12, 2) for g in gaps]        # 前 0.30 に延ばした分
    if rng is not None:
        gaps = [round(g + rng.uniform(-0.05, 0.07), 2) for g in gaps]
    defend = {}                                          # 何発目を、どう防ぐか: index → "clash" / "miss"
    if s["block"] and n >= 3:
        first = "miss" if long_w else (rng.choice(["clash", "miss"]) if rng is not None else "clash")
        defend[1] = first
        if n >= 4:
            defend[2] = "miss" if (first == "clash" or long_w) else "clash"
    rip_i = next((i for i, v in defend.items() if v == "clash" and i + 1 < n), None) if s["riposte"] else None
    kick_i = -1                                          # 連打の中の蹴り: 防がれず・最後でもない1発(hits≧3 では index 0 が候補。seed があれば半々)
    if s["mix_kick"] and n >= 3 and (rng is None or rng.random() < 0.5):
        kick_i = next((i for i in range(n - 1) if i not in defend), -1)
    if rip_i is not None:
        gaps[rip_i] = round(gaps[rip_i] + 0.67, 2)       # 打ち返しの分、次の1発までを空ける(受けてから次の踏み込みまで 0.3 秒は要る)
    if 0 <= kick_i < n - 1:
        gaps[kick_i] = round(gaps[kick_i] + 0.35 + (0.55 if long_w else 0.0), 2)   # 蹴りの clip は長い(命中の後 0.3 秒)。次の clip と重ならないよう空ける。長い武器は蹴りの間合い 0.9 から突きの 1.8 へ 2 単位下がる時間も要る(0.3 秒だと 1 コマ 0.95 飛ぶ)
    tb_off = 0.0
    if bc:                                               # B の連打は、A の n-1 発目のあと(受け返しがあればその後)に入れる。決めの1発までを空ける
        tb_off = 1.0 if rip_i == n - 2 else 0.5
        gaps[n - 2] = round(max(gaps[n - 2], tb_off + 0.45 * (bc - 1) + 0.6), 2)
    ts = [h0]
    for i in range(1, n):
        ts.append(ts[-1] + gaps[i - 1])
    keysA.append(dict(t=_r(h0 - 0.2), dx=4.6, hz=0.9))
    dxB = -1.7
    for i, t in enumerate(ts):
        last = i == n - 1
        pre, post = (0.4, 0.14) if i == 0 else ((0.3, 0.14) if s["timing"] else (0.16, 0.14))   # 間を作るときは 2 発目以降も振りかぶりの分を取る
        anchor = 4.3 if i == 0 else 4.3 + 0.5 * i
        cf = last_clip if last else mid_clips[i]
        clip = dict(file=cf, strike_at=_r(t), start=_r(t - pre), end=_r(t + post), **{"in": 0.12 if (i == 0 or s["timing"]) else 0.06, "out": 0.25 if last else 0.06})   # 間を作るときは入りも 4 コマ(蹴りの後の構えと拳の clip は後ろ腕が 3 rad 違う。2 コマだと飛ぶ)
        pt = _pt(cf, eff) if sword else "auto"          # 素手は伸び切りのコマで当てる(reach)ので、当て先は手の高さから自動で選ぶ
        if last and fin_kick:                            # 決めが蹴り上げ: 高い蹴りの clip(足が胸の高さに届く)で、相手の胸を蹴る
            cf = "75_16_s1"
            clip = dict(file=cf, strike_at=_r(t), start=_r(t - 0.4), end=_r(t + 0.25), **{"in": 0.12, "out": 0.25})
        if kick_i == i:
            clip = dict(file="135_07_s1", strike_at=_r(t), start=_r(t - 0.36), end=_r(t + 0.3), **{"in": 0.12, "out": 0.12})
        if not sword:
            clip["reach"] = True                         # 命中は手(足)が伸び切ったコマで(胴が重ならない間合いになる)
        if not last and kick_i != i and defend.get(i) != "miss":
            clip["anchor_dx"] = round(anchor, 2)
        clipsA.append(clip)
        if last and fin_kick:
            hits.append(dict(tau=_r(t), hold=0.08, kind="kick", by="A", contact=dict(striker="A", effector="foot", target=dict(actor="B", point="chest"), tol=round(0.32 + 0.6 * max(0.0, float(s["b_scale"]) - 1.0), 2), max_anticipation=50, hz_range=0.5)))
        elif last:
            hits.append(dict(tau=_r(t), hold=0.08, kind=kind_hit, by="A", contact=dict(striker="A", effector=eff, target=dict(actor="B", point=pt), tol=round(0.3 + 0.6 * max(0.0, float(s["b_scale"]) - 1.0), 2), max_anticipation=50, hz_range=dict(sword=0.4, dagger=0.4, staff=0.6, spear=0.9).get(s["weapon"], 0.4), surface=0.0 if sword else 0.16)))
        elif defend.get(i) == "clash":                   # 受け止め(鍔迫り合い): 命中の種類 clash、相手は腕を上げて受け、少しだけ押される。位置は接触で決める(腕で受けるので許容は広め)
            hits.append(dict(tau=_r(t), hold=0.07, kind="clash", by="A", contact=dict(striker="A", effector=eff, target=dict(actor="B", point=pt), tol=0.6, max_anticipation=50, hz_range=0.45)))
        elif defend.get(i) == "miss":                    # かわす: 空振り。位置は接触で決める(狙いは頭の少し先の上=くぐられる。plan._body_drive は pos の高さで くぐる/跳ぶ を決める)
            hits.append(dict(tau=_r(t), hold=0.0, kind="miss", by="A", pos=[_r(3.7 - 0.2 * i), 1.2 if (i % 2 == 1) else 0.8],
                             contact=dict(striker="A", effector=eff, target=dict(actor="B", point="head"), offset=[0.25, 0.22], tol=1.5, max_anticipation=50, hz_range=0.5)))
        else:
            if kick_i == i:                              # 連打の中の蹴り(足→相手の腰。接触を解く)
                hits.append(dict(tau=_r(t), hold=0.06, kind="kick", by="A", contact=dict(striker="A", effector="foot", target=dict(actor="B", point="hip"), tol=0.42, max_anticipation=50)))
            else:                                        # 途中の斬り: 位置は接触で決める(以前は pos 固定で、相手との間合いが 1.5〜1.8 あり、clip の継ぎ目で飛んでいた)
                hits.append(dict(tau=_r(t), hold=0.05, kind=kind_hit, by="A", lunge=True, contact=dict(striker="A", effector=eff, target=dict(actor="B", point=pt), tol=0.45, max_anticipation=50, hz_range=0.45 if sword else 0.25, surface=0.0 if sword else 0.16)))
        if last:                                          # 閃光は決めの1発だけ(途中の連打・受け止めでは出さない。参考は 2 秒に 1 回)
            flashes.append(_r(t))
        if defend.get(i) == "clash":
            dxB -= 0.10
            fwd = 0.0                                    # 受け止めの間合いは接触で決まる(B が踏み込むと、長い剣の A が 2 単位も下がることになる)
            keysB += [dict(t=_r(t - 0.16), dx=_r(dxB + 0.10 + fwd), **BLOCK), dict(t=_r(t + 0.08), dx=_r(dxB + fwd), **BLOCK)]
            if rip_i == i:                               # 受けて返す: B が打ち返し、A が受け止める
                tr = t + 0.42
                clipsB.append(dict(file=cclip, dx_scale=0.3, strike_at=_r(tr), start=_r(tr - 0.2), end=_r(tr + 0.26), **{"in": 0.06, "out": 0.1}))
                hits.append(dict(tau=_r(tr), hold=0.07, kind="clash", by="B", contact=dict(striker="B", effector="hand", target=dict(actor="A", point=_pt(cclip, "hand")), tol=0.45, max_anticipation=50, hz_range=0.5)))
                keysA += [dict(t=_r(tr - 0.14), **BLOCK), dict(t=_r(tr + 0.08), **BLOCK), dict(t=_r(tr + 0.26), **GUARD_A)]
                dxB += fwd                               # 受け返したあとも、その間合いのまま(下がると次の1発まで A が追いかけることになる)
                keysB += [dict(t=_r(tr + 0.3), dx=_r(dxB), **GUARD)]
            else:
                dxB += fwd * 0.5
                keysB += [dict(t=_r(t + 0.24), dx=_r(dxB), **GUARD)]
        elif defend.get(i) == "miss":
            dxB -= 0.05
            keysB += [dict(t=_r(t - 0.2), dx=_r(dxB + 0.05), **GUARD), dict(t=_r(t + 0.3), dx=_r(dxB), **GUARD)]
        else:
            dxB -= 0.25
        if not last and i not in defend:
            keysB.append(dict(t=_r(t + 0.07), dx=_r(dxB), lean=-0.3 - 0.07 * i, fa=0.4, ra=0.4, ht=-0.4 - 0.1 * i, face="pain"))
            if not (i == 0 and s["counter"] and n > 1):                       # 反撃するときは、反撃の踏み込みのキーが続く(戻りのキーと重ねない)
                keysB.append(dict(t=_r(t + 0.2), dx=_r(dxB), **GUARD))
        if bc and i == n - 2:                            # 相手の連打: 1 発目は A がくぐってかわす(miss)、2 発目以降は A が受け止める(clash)
            tb = t + tb_off
            flurry.append(dict(start=_r(tb - 0.36), end=_r(tb - 0.06), every=4, angles=[B_FACE, A_FACE]))     # 攻守交代の前に、2 人の顔の寄り
            for j in range(bc):
                tbj = tb + 0.45 * j
                keysB += [dict(t=_r(tbj - 0.14), dx=_r(dxB + 0.7), **GUARD), dict(t=_r(tbj + 0.1), dx=_r(dxB + 0.7), **GUARD)]
                clipsB.append(dict(file=cclip, dx_scale=0.3, strike_at=_r(tbj), start=_r(tbj - 0.2), end=_r(tbj + 0.2), **{"in": 0.06, "out": 0.06}))
                if j == 0 and bc >= 2:                   # かわされる1発: 位置は接触で決める(狙いは頭の少し上。A がくぐるので当たらない)
                    hits.append(dict(tau=_r(tbj), hold=0.0, kind="miss", by="B", pos=[2.9, 1.25],
                                     contact=dict(striker="B", effector="hand", target=dict(actor="A", point="head"), offset=[-0.25, 0.22], tol=1.5, max_anticipation=50)))
                else:
                    hits.append(dict(tau=_r(tbj), hold=0.07, kind="clash", by="B", contact=dict(striker="B", effector="hand", target=dict(actor="A", point=_pt(cclip, "hand")), tol=0.45, max_anticipation=50, hz_range=0.5)))
                    keysA += [dict(t=_r(tbj - 0.14), **BLOCK), dict(t=_r(tbj + 0.08), **BLOCK), dict(t=_r(tbj + 0.26), **GUARD_A)]
            keysB.append(dict(t=_r(tb + 0.45 * (bc - 1) + 0.32), dx=_r(dxB), **GUARD))
        if i == 0 and s["counter"] and n > 1:
            tcn = t + 0.40                               # A の命中のあと、B が踏み込む時間(0.3 秒前からの助走)を取ってから打つ
            keysB += [dict(t=_r(tcn - 0.12), dx=_r(dxB + 0.7), **GUARD), dict(t=_r(tcn + 0.1), dx=_r(dxB + 0.7), **GUARD)]   # 踏み込んで打つ
            if defend.get(i + 1) != "clash":                                  # 次が受け止めなら、その間合いのまま(戻らない)
                keysB.append(dict(t=_r(tcn + 0.32), dx=_r(dxB), **GUARD))
            clipsB.append(dict(file=cclip, dx_scale=0.3, strike_at=_r(tcn), start=_r(tcn - 0.2), end=_r(tcn + 0.27), **{"in": 0.06, "out": 0.1}))
            hits.append(dict(tau=_r(tcn), hold=0.05, kind="hit", by="B", contact=dict(striker="B", effector="hand", target=dict(actor="A", point=_pt(cclip, "hand")), tol=0.42, max_anticipation=50, hz_range=0.5, surface=0.16)))
            keysA += [dict(t=_r(tcn + 0.07), lean=-0.2, hz=0.9), dict(t=_r(tcn + 0.27), lean=0.15, hz=0.9)]   # 位置(dx)は書かない: 押される分は body_drive、位置は clip の継ぎ目合わせに任せる
    hl = ts[-1]
    speed.append([_r(h0), _r(hl + 0.5)])
    shots.append(dict(t=_r(h0), follow="mid", scale=[[_r(h0), 3.1], [_r(hl), 3.6]], yaw=[[_r(h0), 30.0], [_r(hl), 52.0]],
                      pitch=[[_r(h0), 2.0], [_r(hl), 10.0]], lens=30.0, target_z=1.2, dutch=3.0))
    keysA.append(dict(t=_r(hl), dx=5.0, hz=0.9))
    dxB -= 0.25

    # ---- 最後の一撃 ----
    if fin:
        keysB += [dict(t=_r(hl + 0.06), dx=_r(dxB), lean=-0.6, fa=0.3, ra=0.3, fe=0.6, re=0.6, ht=-0.8, face="pain"),
                  dict(t=_r(hl + 0.22), dx=-2.5, rz=0.9, roll=0.5, hz=0.9, lean=-0.5, fl=0.3, fk=0.2, rl=-0.2, rk=0.3, face="pain"),
                  dict(t=_r(hl + 0.55), dx=-2.9, rz=1.9, roll=1.6, hz=0.9, lean=-0.2, fa=-0.4, ra=-0.4, fe=0.3, re=0.3, face="pain"),
                  dict(t=_r(hl + 0.95), dx=-3.2, rz=0.21, roll=1.57, hz=0.9, fa=0.3, ra=0.3, fl=0.0, fk=0.0, rl=0.0, rk=0.0, face="ko")]
        keysA += [dict(t=_r(hl + 0.22), dx=5.3, hz=0.7, lean=0.3),
                  dict(t=_r(hl + 0.42), dx=5.7, rz=1.1, hz=0.9, lean=0.2, fa=2.4, fe=0.4, ra=1.4, re=1.0, fl=0.8, fk=0.9, rl=-0.6, rk=0.7),
                  dict(t=_r(hl + 0.58), dx=5.9, rz=1.0, hz=0.9, lean=0.45, fa=-0.3, fe=0.2, ra=-0.2, re=0.5, fl=0.5, fk=0.6, rl=-0.4, rk=0.5),
                  dict(t=_r(hl + 0.95), dx=6.0, rz=0.0, hz=0.78, lean=0.25), dict(t=_r(hl + 1.3), dx=6.0, hz=0.9, lean=0.1)]
        hits += [dict(tau=_r(hl + 0.55), hold=0.1, kind="slash" if sword else "hit", by="A", pos=[4.9, 1.9]), dict(tau=_r(hl + 0.95), hold=0.1, kind="heel", by="A", pos=[5.6, 0.0])]
        puffs.append(dict(tau=_r(hl + 0.98), kind="land2", pos=[5.6, 0.0]))
        slow.append(dict(start=_r(hl + 0.4), end=_r(hl + 0.65), rate=0.4))
        flashes.append(_r(hl + 0.55))
        t_end = hl + 1.3
        ko_t = hl + 0.95
    else:
        keysB += [dict(t=_r(hl + 0.1), dx=_r(dxB), lean=-0.6, fa=0.3, ra=0.3, fe=0.6, re=0.6, ht=-0.8, face="pain"),
                  dict(t=_r(hl + 0.45), dx=-2.9, rz=0.5, roll=1.2, hz=0.9, lean=-0.2, fl=0.0, fk=0.0, rl=0.0, rk=0.0, face="pain"),
                  dict(t=_r(hl + 0.8), dx=-3.0, rz=0.21, roll=1.57, hz=0.9, fa=0.3, ra=0.3, face="ko")]
        keysA.append(dict(t=_r(hl + 1.0), dx=5.4, hz=0.9, lean=0.1))
        puffs.append(dict(tau=_r(hl + 0.85), kind="land2", pos=[5.4, 0.0]))
        t_end = hl + 1.1
        ko_t = hl + 0.8
    tail = t_end + 0.3
    end = _r(tail + 0.6)
    # 台詞が収まらないときは、終わりを延ばす(最後の台詞の終わり+0.3秒)。延ばした間は、勝者が立ち・敗者が倒れたまま
    pm = dict(opening=0.3, kick=1.9, rise=tc, combo=h0, last=hl, finisher=hl + 0.55, ko=ko_t, end=end - 1.2, counter=ts[0] + 0.28)
    prov = _layout_captions(s["lines"], pm, 1e9, float(s["tempo"])) if s["captions"] else []
    if prov:
        end = max(end, _r(max(c["t1"] for c in prov) + 0.3))
    # 勝ち名乗り: 倒したあと、武器(拳)を高く掲げて止め、ゆっくり下ろす(Becker の決着のあとの「間」)。寄りのカット(HERO)はこの間に入る
    end = max(end, _r(ko_t + 1.75))
    raise_pose = dict(lean=-0.08, fa=2.75, fe=0.25, ra=0.6, re=1.4, ht=-0.15, face="win")
    keysA += [dict(t=_r(ko_t + 0.5), **raise_pose), dict(t=_r(ko_t + 1.05), **raise_pose),
              dict(t=_r(ko_t + 1.4), lean=0.05, fa=0.5, fe=1.2, ra=0.4, re=1.5, ht=0.0, face="win")]
    last_dx = next(k["dx"] for k in reversed(keysA) if "dx" in k)
    keysA.append(dict(t=end, dx=last_dx, hz=0.9, face="win"))
    keysB.append(dict(t=end, dx=keysB[-1].get("dx", -3.0), rz=0.21, roll=1.57, hz=0.9, face="ko"))
    flurry.append(dict(start=_r(ko_t + 0.4), end=_r(ko_t + 0.8), every=5, angles=HERO))
    shots.append(dict(t=_r(hl + 0.0), follow="mid", scale=[[_r(hl), 5.0], [end, 9.0]], yaw=[[_r(hl), 52.0], [end, -15.0]], pitch=[[_r(hl), 10.0], [end, 22.0]], lens=40.0, target_z=0.9))

    impact_cuts = dict(kinds=["kick", "heel", "wall", "clash"], hold=0.2, angles=[dict(yaw=35, pitch=4, scale=3.0, lens=28, hue=0), dict(yaw=-40, pitch=-6, scale=2.6, lens=26, dutch=6.0, hue=1),
                                                                      dict(yaw=5, pitch=12, scale=3.4, lens=34, hue=2)],
                       per_kind=dict(wall=[dict(yaw=-30, pitch=6, scale=5.0, lens=30), dict(yaw=10, pitch=18, scale=6.0, lens=34), dict(yaw=-55, pitch=3, scale=4.2, lens=28, dutch=-5.0)],
                                     clash=[dict(yaw=28, pitch=2, scale=2.4, lens=30, hue=3), dict(yaw=-32, pitch=-8, scale=2.0, lens=26, dutch=7.0, hue=0)]))
    invert = ["kick", "heel", "wall"]
    if s["camera"] == "fixed":                           # 検証用: カット・連打カット・反転の 1 コマも無し(動きだけを見る)
        shots = [dict(t=0.0, follow="mid", scale=3.4, yaw=0.0, pitch=0.0, lens=50.0)]
        flurry = []
        impact_cuts = None
        invert = []

    ex = float(s["exaggerate"])
    if ex and ex != 1.0:                                 # 振りの誇張: 腕の角度を平均からの差で ex 倍(clip ごと。体・脚は変えない)
        for lst in (clipsA, clipsB):
            for c in lst:
                if "strike_at" in c and not c.get("loop"):
                    c.setdefault("amp", {}).update(fa=ex, ra=min(ex, 1.15), fe=ex)

    # ---- 色・リズム ----
    pal = PALETTES.get(s["palette"], PALETTES["warm"])
    marks = [0.0, 1.2, 1.9, 2.6, tc - 0.6, tc - 0.05, tc + 0.4, hl, hl + 0.8, end] if kick else \
            [0.0, 1.0, tc - 0.8, tc - 0.3, tc - 0.05, tc + 0.1, tc + 0.4, hl, hl + 0.8, end]
    light = 0.55 if s["stage"] in ("dojo", "field") else 1.0     # 明るい舞台は、色味を弱める(白飛びする)
    color_script = [[_r(t), [c[0], c[1], c[2]], round(c[3] * light, 3)] for t, c in zip(marks, pal)]
    stepping = dict(hold=2, ones_around_hits=3, hold_camera=True)        # 2コマ撮りを全体に(命中の前後 3 コマは 1 コマごと)。参考の同じ絵の割合 17〜33% に寄せる
    actors = dict(A=dict(color=s["colors"]["A"], scale=float(s["a_scale"]), base_x=-2.0, facing=1), B=dict(color=s["colors"]["B"], scale=float(s["b_scale"]), base_x=2.4, facing=-1))
    if sword:
        actors["A"]["weapon"] = s["weapon"]
    marks = dict(opening=0.3, kick=1.9, rise=tc, combo=h0, last=hl, finisher=hl + 0.55, ko=ko_t, end=end - 1.2)
    marks["counter"] = ts[0] + 0.28
    caps = _layout_captions(s["lines"], marks, end, float(s["tempo"])) if s["captions"] else []
    keys = dict(A=sorted(keysA, key=lambda k: k["t"]), B=sorted(keysB, key=lambda k: k["t"]))
    if s["ally"]:                                       # 味方: 戦いの間は不安げに見守り、決着で万歳(か、うなだれる)。奥行き y をずらして置く
        al = s["ally"]
        actors["C"] = dict(color=al.get("color", [0.95, 0.8, 0.2]), scale=al.get("scale", 0.8), base_x=al.get("x", 4.4), y=al.get("y", 1.6), facing=al.get("facing", -1))
        worry = dict(dx=0.0, hz=0.84, lean=0.05, fa=1.4, fe=2.0, ra=1.4, re=2.0, face="pain")
        keys["C"] = [dict(t=0.0, **worry), dict(t=_r(ko_t), **worry)] + (
            [dict(t=_r(ko_t + 0.25), dx=0.0, hz=0.86, lean=-0.1, fa=2.7, fe=0.3, ra=2.7, re=0.3, face="win"), dict(t=end, dx=0.0, hz=0.86, lean=-0.1, fa=2.7, fe=0.3, ra=2.7, re=0.3, face="win")]
            if al.get("cheer", True) else
            [dict(t=_r(ko_t + 0.3), dx=0.0, hz=0.78, lean=0.3, fa=0.15, fe=0.2, ra=0.15, re=0.2, face="pain"), dict(t=end, dx=0.0, hz=0.78, lean=0.3, fa=0.15, fe=0.2, ra=0.15, re=0.2, face="pain")])
    scene = dict(
        name=spec.get("name", "fight") if isinstance(spec, dict) else "fight", fps=30, tau_end=end, actors=actors,
        stage=dict(wall_x=6.0, style="flat", theme=s["stage"]), slow=slow, hits=hits, puffs=puffs,
        camera=[[0.0, -0.4, 8.4], [_r(end), 3.2, 8.6]],
        keys=keys,
        fx=dict(trails=[], speed_lines=speed, invert=invert, flashes=sorted(set(flashes)), charge=charge, color_script=color_script, weapon_glow=bool(sword)),
        clips=dict(A=clipsA, **({"B": clipsB} if clipsB else {})),
        qa=dict(max_cross_frames=400, max_stops=3, max_anticipation_frames=14, max_jerk=1.3),
        tempo=s["tempo"], anime=dict(trails=True, sfx=True, zoom_blur=True, grade=True, roll=True, smear=True),
        shots=shots, stepping=stepping,
        impact_cuts=impact_cuts,
        flurry=flurry, body_drive=({"strength": float(s["body"])} if s["body"] else None), footwork=({} if s["footwork"] else None), style="flat2d",
        clip_timing=({"pre": 0.4, "post": 0.3} if s["timing"] else None),
        limb=dict(base=0.055, tip=0.03, tip_color=[0.08, 0.08, 0.1]), captions=caps, audio=(False if s["mood"] == "none" else dict(mood=s["mood"])), _marks={k: _r(v) for k, v in marks.items()})
    return scene


def expand(data: dict, verify: bool = False) -> dict:
    """台本の dict に fight: があれば、自動で組んだ台本を土台にして、ほかのキーで上書きする。

    verify=True で seed があるとき、点検(qa)に通らない seed は、次の seed に替えて組み直す(最大8回。clips/ が無いときは何もしない)。"""
    if "fight" not in data:
        return data
    spec = dict(data["fight"] or {})
    spec.setdefault("name", data.get("name", "fight"))
    if verify and spec.get("seed") is not None:
        spec = _first_passing_seed(spec, data)
    base = build_fight(spec)
    over = {k: v for k, v in data.items() if k != "fight"}
    for k, v in over.items():                       # fx・anime などの辞書は、上書きでなく足し合わせる(周りの演出を消さない)
        if isinstance(v, dict) and isinstance(base.get(k), dict) and k in ("fx", "anime", "stage"):
            base[k] = dict(base[k], **v)
        else:
            base[k] = v
    return base


def _first_passing_seed(spec: dict, data: dict) -> dict:
    from . import plan as planmod, qa
    for k in range(8):
        sp = dict(spec, seed=int(spec["seed"]) + k)
        sc = dict(build_fight(sp), **{x: v for x, v in data.items() if x != "fight"})
        try:
            pl = planmod.build_plan(sc)
        except Exception:                                  # clips が無い等。点検できない環境では、そのまま使う
            return spec
        if qa.run_gate(pl, sc.get("qa"))["passed"]:
            return sp
    return spec

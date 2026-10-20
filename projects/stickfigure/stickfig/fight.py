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
    finisher="launch_slash", # launch_slash(決めの斬りで打ち上げ→空中斬り→叩きつけ) / launch_kick(決めは高い蹴りで打ち上げ) / beam(気の光線: 溜め→発射→壁まで吹き飛ばす) / blast(気弾: 片手に玉を膨らませて投げる→着弾で爆発) / wave(衝撃波: 跳んで拳を地面に叩きつけ→地面を走る波で打ち上げる) / air_combo(空中コンボ: 打ち上げ→空中で 2 発追加→叩きつけ) / barrage(連打乱舞: 拳 8 発 0.1 秒間隔→大振りで壁へ) / slash_wave(飛ぶ斬撃: 振り抜くと三日月の光が飛ぶ。剣だけ) / iai(居合: 1 コマで相手の向こうへ抜け、間を置いて斬撃線が走り崩れ落ちる。剣だけ) / slam_throw(投げ: つかんで頭上を回し、背後の地面に叩きつける) / blink_combo(瞬間移動の連撃: 前に現れ拳→頭上に現れ踵落とし→離れて背を向ける) / meteor(流星落とし: 高く跳んで拳で急降下、着弾の衝撃で相手を壁へ) / beam_clash(光線の撃ち合い: 2 人が同時に撃ち、中央でぶつかり、A が押し勝つ。B の色は beam_color_b) / random(seed で選ぶ) / none(まっすぐ倒れる)
    taunt=False,             # 名乗り: 走り出す前に決めポーズで止まる(突きつけ→掲げて 0.25 秒止め、寄りと流線)。opening とは併用しない
    opening=None,            # 出だしの技: blast(走り出す前に気弾を投げ、B がかわし、壁で爆発) / teleport(走らず一瞬で相手の目の前に現れる) / fly(跳び上がって水平に飛び、急降下して着地) / counter_blast(相手が気弾を投げ、A が弾いて空中で爆発させる) / air_clash(2 人が跳び上がって空中でぶつかり、弾かれて着地) / dodge_beam(相手が光線を撃ち、A が高く跳んでかわす)。kick: true とは併用しない
    beam_color=None,         # beam の色 [r,g,b](0〜255)。既定は水色
    beam_color_b=None,       # beam_clash の B の光線の色。既定は赤
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
    cam_zoom=1.25,           # 全カットを一律に引く倍率(2026-10-20「もう少し遠くから見るように」)
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
BLOCK = dict(lean=0.18, fa=1.35, fe=1.75, ra=1.2, re=1.3, ht=-0.1, face="fight")      # 受け止め: 肘を畳んで剣(腕)を顔の前に立てる(腕を伸ばした 1.75/0.55 だと、相手の拳が手の内側を抜けて顔に届いていた)
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
    beam = s["finisher"] == "beam"                       # 必殺技: 気の光線(溜め → 発射 → 壁まで吹き飛ばす)
    blast = s["finisher"] == "blast"                     # 必殺技: 気弾(片手に玉を膨らませて投げる → 着弾で爆発 → 壁まで吹き飛ばす)
    wave = s["finisher"] == "wave"                       # 必殺技: 衝撃波(跳んで拳を地面に叩きつけ → 地面を走る波 → 相手を打ち上げる)
    bclash = s["finisher"] == "beam_clash"               # 必殺技: 光線の撃ち合い(2 人が同時に撃ち、中央でぶつかり、A が押し勝つ)
    barrage = s["finisher"] == "barrage"                 # 必殺技: 連打乱舞(拳を 8 発 0.1 秒間隔 → 最後の大振りで壁へ)
    swave = s["finisher"] == "slash_wave" and s["weapon"] in ("sword", "dagger")   # 必殺技: 飛ぶ斬撃(振り抜くと三日月の光が飛ぶ)。剣だけ
    iai = s["finisher"] == "iai" and s["weapon"] in ("sword", "dagger")           # 必殺技: 居合(1 コマで相手の向こうへ抜け、間を置いて斬撃線が走る)。剣だけ
    sthrow = s["finisher"] == "slam_throw"               # 必殺技: 投げ(つかんで頭上を回し、背後の地面に叩きつける)
    blink = s["finisher"] == "blink_combo"               # 必殺技: 瞬間移動の連撃(前に現れ拳 → 頭上に現れ踵落とし → 離れて背を向ける)
    meteor = s["finisher"] == "meteor"                   # 必殺技: 流星落とし(高く跳んで拳で急降下、着弾の衝撃で相手を壁へ)
    air = s["finisher"] == "air_combo"                   # 必殺技: 空中コンボ(打ち上げ → 空中で 2 発追加 → 叩きつけ)
    fin = s["finisher"] in ("launch_slash", "launch_kick", "air_combo")
    fin_kick = s["finisher"] == "launch_kick"
    ex = 0.5 if air else 0.0                             # 空中の追加の 2 発ぶん、叩きつけ以降を遅らせる
    bfirst = bool(s["b_first"]) and not kick and s["weapon"] not in ("staff", "spear")
    open_blast = (s["opening"] == "blast") and not kick  # 出だしの技: 走り出す前に気弾を投げ、B がかわし、壁で爆発
    open_tp = (s["opening"] == "teleport") and not kick  # 出だしの技: 走らず一瞬で相手の目の前に現れる
    open_fly = (s["opening"] == "fly") and not kick      # 出だしの技: 跳び上がって水平に飛び、急降下して相手の前に着地
    open_cb = (s["opening"] == "counter_blast") and not kick   # 出だしの技: 相手が気弾を投げ、A が弾いて空中で爆発させる
    open_ac = (s["opening"] == "air_clash") and not kick # 出だしの技: 2 人が跳び上がって空中でぶつかり、弾かれて着地
    open_db = (s["opening"] == "dodge_beam") and not kick   # 出だしの技: 相手が光線を撃ち、A が高く跳んでかわす
    taunt = bool(s["taunt"]) and not kick and not s["opening"]   # 名乗り: 走り出す前に決めポーズで止まる(字幕は使わない)
    o = 0.0 if kick else (-2.4 + (0.95 if bfirst else 0.0))          # 蹴りが無いぶん、連打の開始が早まる(B が先に仕掛けるなら、その分を空ける)
    if open_blast:
        o += 1.0                                         # 気弾のぶん、走り出しが 1.0 秒遅れる
    if open_cb:
        o += 1.0                                         # 撃ち落としのぶん、走り出しが 1.0 秒遅れる
    if open_ac:
        o += 1.2                                         # 空中戦のぶん、走り出しが 1.2 秒遅れる
    if open_db:
        o += 1.6                                         # 相手の光線のぶん、走り出しが 1.6 秒遅れる
    if taunt:
        o += 0.7                                         # 名乗りのぶん、走り出しが 0.7 秒遅れる
    if open_tp:
        o -= 0.4                                         # 瞬間移動は走らないぶん早く(立っている時間が長かった)
    tc = 4.0 + o                       # 連打の準備(起き上がり)の終わり

    keysA: List[dict] = [dict(t=0.0, dx=0.2, hz=0.84), dict(t=0.6, dx=0.2, lean=0.12, hz=0.83)]
    keysB: List[dict] = [dict(t=0.0)]
    clipsA: List[dict] = [dict(file="09_01", start=0.6, end=1.55, loop=True, anchor_dx=0.2, **RUN_LOOK, **{"in": 0.12, "out": 0.2})]
    clipsB: List[dict] = []
    hits: List[dict] = []
    puffs: List[dict] = []
    fx_beams: List[dict] = []                            # 気の光線(finisher: beam)
    fx_orbs: List[dict] = []                             # 手に付く光の玉(finisher: blast の溜め)
    fx_proj: List[dict] = []                             # 飛ぶ玉(finisher: blast)
    fx_waves: List[dict] = []                            # 地面を走る衝撃波(finisher: wave)
    fx_after: List[dict] = []                            # 瞬間移動の残像の列(opening: teleport)
    fx_cuts: List[dict] = []                             # 相手の体に走る斬撃線(finisher: iai)
    trails_ranges: List[list] = []                       # 前のコマの影を重ねる区間(カメラが止まっている場面向け。fight では使わない)
    glide_ranges: List[list] = []                        # 飛行中に手足の光の尾を出す区間 [t0, t1, who]
    snaps: List[dict] = []                               # 区間で位置(dx)を固定(瞬間移動を 1 コマにする)
    wall_lock = None                                     # beam のときは壁の位置を先に決める
    slow: List[dict] = []
    flurry: List[dict] = []
    charge: List[dict] = []
    flashes: List[float] = []
    speed: List[list] = [[0.5, 1.3]]
    shots: List[dict] = []

    # ---- 冒頭: 対峙(2人が一歩ずつ踏み出し、見合って止まる。止めの間にカメラが寄る) ----
    shots.append(dict(t=0.0, follow="mid", scale=[[0.0, 6.2], [1.0, 5.2]], yaw=[[0.0, 12.0], [1.0, 22.0]], pitch=9.0, lens=40.0))   # 冒頭は人物が画面の 1/4 だった(参考は 1/3〜1/2)。7.4/6.4 → 6.2/5.2
    keysA.insert(1, dict(t=0.42, dx=0.36, hz=0.84, lean=0.1))
    keysB.append(dict(t=0.42, dx=(0.15 if kick else -1.55)))
    hits.append(dict(tau=0.5, hold=0.12, kind="pose"))
    keysA.insert(2, dict(t=0.5, dx=0.34, hz=0.66, lean=0.26))   # 走り出しの溜め: 見合いの止め絵で沈んで前へ傾き(予備動作)、そのまま蹴り出して走りの clip へ
    keysA.insert(3, dict(t=0.6, dx=0.3, hz=0.66, lean=0.34))    # (0.56 の 1 点だけだと止め絵の間に埋もれて腰が 0.77 までしか沈まなかった)
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
        clipsA.append(dict(file="135_07_s1", strike_at=1.9, start=1.5, end=2.3, **{"in": 0.2, "out": 0.25}))   # 蹴ったら脚を戻す(2.7 まで clip を続けると、スローの間ずっと脚を上げたまま固まって見えた)
        keysA += [dict(t=2.45, dx=3.3, hz=0.76, lean=0.18), dict(t=2.7, dx=3.4, hz=0.9), dict(t=3.2, dx=3.4, hz=0.9)]   # 着地で沈んで立つ
        keysB += [dict(t=1.9, dx=0.35),
                  dict(t=1.95, dx=0.3, lean=0.55, hz=0.88, fa=0.9, ra=0.8, fe=0.9, re=0.9, ht=0.5, face="pain"),
                  # 壁(x=6.0)まで飛んで(前は dx -1.5 で壁の 2 単位手前に浮いたまま止まっていた)、壁に背中から叩きつけられ、ずり落ちて倒れる
                  dict(t=2.1, dx=-2.5, rz=1.3, roll=1.0, hz=0.9, fa=-1.1, ra=-0.9, fe=0.2, re=0.3, fl=0.9, fk=0.4, rl=0.2, rk=0.3, lean=-0.3, ht=-0.6, face="pain"),   # 飛んでいる間は体を後ろへ倒し(頭が遅れ、脚が先行)、手足を後ろへ流す(立ったまま浮いて見えていた)
                  dict(t=2.25, dx=-3.45, rz=1.35, roll=0.3, hz=0.9, fa=-0.9, ra=-0.9, fe=0.3, re=0.3, fl=0.6, fk=0.3, rl=-0.3, rk=0.4, lean=-0.35, ht=-0.7, face="pain"),
                  dict(t=2.42, dx=-3.45, rz=1.25, roll=0.35, hz=0.9, lean=-0.3, face="pain"),          # 壁に張りついて一瞬止まる
                  dict(t=2.75, dx=-3.3, rz=0.55, roll=1.2, hz=0.9, lean=0.0, fa=0.2, ra=0.2, face="pain"),   # ずり落ちる
                  dict(t=3.0, dx=-3.25, rz=0.21, roll=1.57, hz=0.9, fa=0.4, ra=0.4, fl=0.0, fk=0.0, rl=0.0, rk=0.0, face="ko"),
                  dict(t=3.5, dx=-3.25, rz=0.21, roll=1.57, hz=0.9, face="ko"),
                  dict(t=3.72, dx=-3.1, rz=0.0, roll=0.45, hz=0.55, lean=0.55, fa=1.3, fe=0.6, ra=0.9, re=0.8, fl=1.3, fk=2.1, rl=-0.2, rk=0.6, face="pain"),   # 起き上がり: 手をついて膝を抱える(板のように回って立つのをやめた)
                  dict(t=3.95, dx=-2.8, rz=0.0, roll=0.25, hz=0.56, lean=0.4, fa=0.9, fe=1.0, ra=0.6, re=1.0, fl=1.0, fk=1.6, rl=-0.5, rk=0.9, face="pain"),       # 片膝立ち
                  dict(t=4.15, dx=-2.4, rz=0.0, roll=0.0, hz=0.8, lean=0.2, fa=0.9, ra=0.9, fe=1.0, re=1.0, face="fight"),   # よろけながら前へ出て立つ
                  dict(t=4.4, dx=-1.7, rz=0.0, roll=0.0, hz=0.82, lean=0.1, fa=0.9, fe=1.4, ra=0.7, re=1.5, fl=0.45, fk=0.3, rl=-0.45, rk=0.4, face="fight")]
        shots += [
            dict(t=1.0, follow="A", scale=[[1.0, 5.2], [1.85, 4.2]], yaw=[[1.0, -28.0], [1.85, -14.0]], pitch=5.0, lens=32.0, target_z=1.0, lag=0.3),
            dict(t=1.85, follow="mid", scale=[[1.85, 3.2], [2.1, 3.6]], yaw=[[1.85, 38.0], [2.1, 46.0]], pitch=-9.0, lens=28.0, target_z=1.15, dutch=-4.0),
            dict(t=2.1, follow="B", scale=4.6, yaw=[[2.1, 62.0], [2.9, 50.0]], pitch=3.0, lens=40.0, target_z=1.2, lag=0.35),           # 吹き飛ぶ B に寄る(6.0 だと人物が 1/4)
            dict(t=2.9, follow="mid", scale=[[2.9, 5.4], [3.6, 6.0]], yaw=[[2.9, 15.0], [3.6, 25.0]], pitch=[[2.9, 30.0], [3.6, 22.0]], lens=40.0, target_z=0.7),   # 倒れた相手と A の引きの画。6.8 だと人物が 1/5
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
        if taunt:                                        # 名乗り: 0.6 武器(腕)を相手に突きつける → 0.85 高く掲げて止め(0.25 秒、寄り・流線)→ 1.2 下ろして → 1.3 走り出す
            clipsA[0].update(start=1.3, **{"in": 0.12})
            keysA = [k for k in keysA if k["t"] not in (0.6,)]
            point = dict(hz=0.86, lean=0.1, fa=1.5, fe=0.1, ra=0.3, re=1.4, ht=0.05, fl=0.7, fk=0.3, rl=-0.5, rk=0.2, face="fight")        # 突きつける
            raise_ = dict(hz=0.9, lean=-0.12, fa=2.8, fe=0.2, ra=0.5, re=1.4, ht=-0.2, fl=0.45, fk=0.3, rl=-0.5, rk=0.2, face="fight")    # 高く掲げる(反る)
            keysA += [dict(t=0.6, dx=0.2, hz=0.84, lean=0.1, fa=0.9, fe=1.4, ra=0.7, re=1.5, face="fight"),
                      dict(t=0.68, dx=0.3, **point), dict(t=0.78, dx=0.3, **point),
                      dict(t=0.85, dx=0.3, **raise_), dict(t=1.12, dx=0.3, **raise_),
                      dict(t=1.25, dx=0.3, hz=0.8, lean=0.25, fa=0.7, fe=1.4, ra=0.5, re=1.5, fl=0.8, fk=0.9, rl=-0.5, rk=0.5),   # 下ろして沈む(走り出しの予備動作)
                      dict(t=1.3, dx=0.3, hz=0.84, lean=0.3)]
            keysB += [dict(t=0.7, dx=-1.7, lean=-0.15, ht=-0.25, fa=0.6, ra=0.5, fe=1.2, re=1.3, face="fight"),   # 身構える
                      dict(t=0.95, dx=-1.55, lean=-0.1, ht=-0.1, fa=0.8, ra=0.6, fe=1.3, re=1.4, face="fight"),  # 一歩引く
                      dict(t=1.25, dx=-1.55, **GUARD)]
            hits.append(dict(tau=0.86, hold=0.1, kind="pose"))      # 止めは姿勢の保持(0.85〜1.12)で作る。hold を長くすると点検の「ヒットストップ 1〜3 コマ」に当たる
            flurry.append(dict(start=0.86, end=1.12, every=5, z=1.8, angles=[dict(target="A", yaw=-30, pitch=6, scale=5.2, lens=28, hue=0), dict(target="A", yaw=20, pitch=-4, scale=4.8, lens=26, dutch=5.0, hue=1)]))   # 狙いを高く(z 1.8)・引く(scale 5.2): 掲げた剣まで入れると高さ 2.9 要る(3.8 だと切れた)
            shots.insert(0, dict(t=0.55, follow="A", scale=[[0.55, 4.6], [0.85, 3.6]], yaw=[[0.55, -26.0], [0.85, -12.0]], pitch=5.0, lens=32.0, target_z=1.2, lag=0.2))
            shots.append(dict(t=1.4, follow="A", scale=[[1.4, 4.8], [tc + 0.4, 3.9]], yaw=[[1.4, -38.0], [tc + 0.4, -20.0]], pitch=4.0, lens=30.0, target_z=1.0, lag=0.3))
        if open_db:                                      # 相手の光線: 0.6 B が構えて溜め(1.0 秒)→ 1.6 発射 → 1.65 A が跳んでかわす → 光線は壁へ → 2.0 A 着地 → 2.2 走り出す
            col = list(s.get("beam_color_b") or [255, 110, 90])
            clipsA[0].update(start=2.2, **{"in": 0.12})
            keysA = [k for k in keysA if k["t"] not in (0.6,)]
            a_root0, b_root0 = -2.0 + 0.2, 2.4 + 1.7
            t_c0, t_fire = 0.6, 1.6
            charge_pose = dict(hz=0.74, lean=0.12, fa=-0.3, fe=2.3, ra=-0.25, re=2.3, ht=0.05, fl=0.55, fk=0.5, rl=-0.5, rk=0.35, face="fight")
            fire_pose = dict(hz=0.82, lean=0.38, fa=1.6, fe=0.05, ra=1.55, re=0.08, ht=-0.05, fl=0.9, fk=0.45, rl=-0.55, rk=0.2, face="fight")
            keysA += [dict(t=0.6, dx=0.2, hz=0.84, lean=0.1, fa=0.9, fe=1.4, ra=0.7, re=1.5, face="fight"),
                      dict(t=_r(t_fire - 0.12), dx=0.2, hz=0.62, lean=0.3, fl=1.0, fk=1.7, rl=-0.3, rk=1.3, fa=-0.5, fe=1.0, ra=-0.5, re=1.0),   # 光線を見て沈む(予備動作)
                      dict(t=_r(t_fire + 0.03), dx=0.3, rz=0.8, hz=0.95, lean=-0.1, fa=2.4, fe=0.4, ra=2.0, re=0.5, fl=0.5, fk=1.0, rl=-0.3, rk=0.8),   # 跳ぶ
                      dict(t=_r(t_fire + 0.2), dx=0.4, rz=2.3, hz=0.9, lean=0.1, fa=1.2, fe=1.0, ra=0.8, re=1.2, fl=0.9, fk=1.5, rl=-0.6, rk=1.3),    # 頂点(脚を抱える: 光線が下を通る)
                      dict(t=_r(t_fire + 0.4), dx=0.5, rz=1.2, hz=0.92, lean=0.15, fl=0.8, fk=0.6, rl=-0.5, rk=0.3),
                      dict(t=2.0, dx=0.55, rz=0.0, hz=0.66, lean=0.3, fl=1.0, fk=1.7, rl=-0.3, rk=1.3, fa=0.3, fe=1.2, ra=0.3, re=1.2),   # 着地(つぶれ)
                      dict(t=2.2, dx=0.6, hz=0.86, lean=0.15)]
            keysB = [dict(t=0.0, dx=-1.7), dict(t=0.5, dx=-1.7, **GUARD),
                     dict(t=_r(t_c0 + 0.1), dx=-1.7, **charge_pose), dict(t=_r(t_fire - 0.07), dx=-1.7, **dict(charge_pose, hz=0.70, lean=0.05)),
                     dict(t=_r(t_fire), dx=-1.5, **fire_pose), dict(t=_r(t_fire + 0.12), dx=-1.7, **dict(fire_pose, lean=0.3, hz=0.78)),
                     dict(t=_r(t_fire + 0.75), dx=-1.7, **dict(fire_pose, lean=0.25, hz=0.84)),
                     dict(t=2.1, dx=-1.7, hz=0.88, lean=0.1, fa=0.9, fe=1.4, ra=0.7, re=1.5, ht=0.0, face="fight"),
                     *([] if bfirst else [dict(t=_r(tc), dx=-1.7, **GUARD)])] + [k for k in keysB if k["t"] > 2.2]
            charge.append(dict(start=_r(t_c0 + 0.1), end=_r(t_fire), who="B", color=col))
            fx_beams.append(dict(start=_r(t_fire), end=_r(t_fire + 0.75), who="B", color=col, x_end=-7.5))       # 左の画面外まで
            hits += [dict(tau=_r(t_fire), hold=0.06, kind="beam", by="B", pos=[_r(b_root0 - 1.2), 1.3]),
                     dict(tau=_r(t_fire + 0.03), hold=0.0, kind="launch", by="A", pos=[a_root0, 0.0]),
                     dict(tau=2.0, hold=0.02, kind="land", by="A", pos=[_r(a_root0 + 0.35), 0.0])]
            flashes.append(_r(t_fire))
            slow.append(dict(start=_r(t_fire - 0.03), end=_r(t_fire + 0.25), rate=0.55))
            speed.append([_r(t_fire), _r(t_fire + 0.5)])
            shots.insert(0, dict(t=0.55, follow="B", scale=[[0.55, 4.4], [t_fire, 3.8]], yaw=[[0.55, 26.0], [t_fire, 12.0]], pitch=6.0, lens=32.0, target_z=1.0, lag=0.25))   # B の溜めに寄る
            shots.append(dict(t=_r(t_fire), follow="mid", scale=6.4, yaw=2.0, pitch=2.0, lens=44.0, target_z=1.5))   # 光線と跳ぶ A が入る引き
            shots.append(dict(t=2.3, follow="A", scale=[[2.3, 4.8], [tc + 0.4, 3.9]], yaw=[[2.3, -38.0], [tc + 0.4, -20.0]], pitch=4.0, lens=30.0, target_z=1.0, lag=0.3))
        if open_ac:                                      # 空中戦: 0.6 2 人がしゃがむ → 0.75 跳ぶ → 1.1 空中の中間でぶつかる(止め)→ 弾かれて 1.5 着地 → 1.8 A が走り出す
            clipsA[0].update(start=1.8, **{"in": 0.12})
            keysA = [k for k in keysA if k["t"] not in (0.6,)]
            a_root0, b_root0 = -2.0 + 0.2, 2.4 + 1.7
            mid = (a_root0 + b_root0) / 2
            t_j, t_c, t_l = 0.75, 1.1, 1.5
            crouch = dict(hz=0.62, lean=0.3, fl=1.0, fk=1.7, rl=-0.3, rk=1.3, fa=-0.5, fe=1.0, ra=-0.5, re=1.0, face="fight")
            atk = (dict(fa=2.4, fe=0.3, ra=1.2, re=0.8) if sword else dict(fa=1.6, fe=0.1, ra=-0.3, re=1.0))          # 剣は上段、素手は拳
            keysA += [dict(t=0.6, dx=0.2, hz=0.84, lean=0.1, fa=0.9, fe=1.4, ra=0.7, re=1.5, face="fight"),
                      dict(t=_r(t_j - 0.1), dx=0.2, **crouch),
                      dict(t=_r(t_j), dx=0.35, rz=0.5, hz=0.95, lean=-0.1, fa=2.6, fe=0.3, ra=2.2, re=0.4, fl=0.3, fk=0.2, rl=-0.3, rk=0.2),
                      dict(t=_r(t_c - 0.03), dx=_r(mid - 0.5 - a_root0 + 0.2), rz=1.9, hz=0.9, lean=0.35, fl=0.6, fk=0.4, rl=-0.5, rk=0.3, **atk),   # 中間へ、構えて
                      dict(t=_r(t_c), dx=_r(mid - 0.45 - a_root0 + 0.2), rz=1.9, hz=0.9, lean=0.4, fl=0.6, fk=0.4, rl=-0.5, rk=0.3, **atk),
                      dict(t=_r(t_c + 0.2), dx=_r(mid - 1.4 - a_root0 + 0.2), rz=1.6, hz=0.9, lean=-0.3, fa=0.8, fe=1.0, ra=0.6, re=1.0, fl=0.4, fk=0.3, rl=-0.4, rk=0.3),   # 弾かれて後ろへ
                      dict(t=_r(t_l), dx=_r(mid - 2.0 - a_root0 + 0.2), rz=0.0, hz=0.64, lean=0.3, fl=1.0, fk=1.7, rl=-0.3, rk=1.3, fa=0.3, fe=1.2, ra=0.3, re=1.2),   # 着地(つぶれ)
                      dict(t=1.8, dx=_r(mid - 2.0 - a_root0 + 0.2), hz=0.86, lean=0.15)]
            keysB = [dict(t=0.0, dx=-1.7), dict(t=0.6, dx=-1.7, **GUARD),
                     dict(t=_r(t_j - 0.1), dx=-1.7, **crouch),
                     dict(t=_r(t_j), dx=-1.55, rz=0.5, hz=0.95, lean=-0.1, fa=2.6, fe=0.3, ra=2.2, re=0.4, fl=0.3, fk=0.2, rl=-0.3, rk=0.2),
                     dict(t=_r(t_c - 0.03), dx=_r(-(mid + 0.5 - 2.4)), rz=1.9, hz=0.9, lean=0.35, fl=0.6, fk=0.4, rl=-0.5, rk=0.3, fa=1.6, fe=0.1, ra=-0.3, re=1.0),
                     dict(t=_r(t_c), dx=_r(-(mid + 0.45 - 2.4)), rz=1.9, hz=0.9, lean=0.4, fl=0.6, fk=0.4, rl=-0.5, rk=0.3, fa=1.6, fe=0.1, ra=-0.3, re=1.0),
                     dict(t=_r(t_c + 0.2), dx=_r(-(mid + 1.4 - 2.4)), rz=1.6, hz=0.9, lean=-0.3, fa=0.8, fe=1.0, ra=0.6, re=1.0, fl=0.4, fk=0.3, rl=-0.4, rk=0.3),
                     dict(t=_r(t_l), dx=_r(-(mid + 2.0 - 2.4)), rz=0.0, hz=0.64, lean=0.3, fl=1.0, fk=1.7, rl=-0.3, rk=1.3, fa=0.3, fe=1.2, ra=0.3, re=1.2),
                     dict(t=1.8, dx=-1.7, hz=0.86, lean=0.1),
                     *([] if bfirst else [dict(t=_r(tc), dx=-1.7, **GUARD)])] + [k for k in keysB if k["t"] > 1.8]
            hits += [dict(tau=_r(t_j), hold=0.0, kind="launch", by="A", pos=[a_root0, 0.0]),
                     dict(tau=_r(t_c), hold=0.1, kind="clash", pos=[_r(mid), 2.7]),
                     dict(tau=_r(t_l), hold=0.03, kind="land", pos=[_r(mid - 2.0), 0.0]),
                     dict(tau=_r(t_l + 0.02), hold=0.0, kind="land", pos=[_r(mid + 2.0), 0.0])]
            flashes.append(_r(t_c))
            slow.append(dict(start=_r(t_c - 0.04), end=_r(t_c + 0.12), rate=0.5))
            speed.append([_r(t_j), _r(t_c)])
            shots.insert(0, dict(t=0.55, follow="mid", scale=[[0.55, 5.6], [t_j, 5.2]], yaw=6.0, pitch=4.0, lens=40.0, target_z=1.2))
            shots.append(dict(t=_r(t_j + 0.05), follow="mid", scale=5.6, yaw=0.0, pitch=-4.0, lens=40.0, target_z=2.2))   # 空中の 2 人を少し下から
            shots.append(dict(t=_r(t_l + 0.1), follow="mid", scale=6.0, yaw=4.0, pitch=6.0, lens=40.0, target_z=1.0))
            shots.append(dict(t=1.9, follow="A", scale=[[1.9, 4.8], [tc + 0.4, 3.9]], yaw=[[1.9, -38.0], [tc + 0.4, -20.0]], pitch=4.0, lens=30.0, target_z=1.0, lag=0.3))
        if open_cb:                                      # 撃ち落とし: 0.6 B が片手を上げて玉を膨らませ → 1.1 投げる → 1.4 A が弾いて爆発 → 1.6 A が走り出す
            col = list(s.get("beam_color_b") or [255, 110, 90])
            clipsA[0].update(start=1.6, **{"in": 0.12})
            keysA = [k for k in keysA if k["t"] not in (0.6,)]
            a_root0 = -2.0 + 0.2
            b_root0 = 2.4 + 1.7
            swing_up = dict(hz=0.84, lean=-0.1, fa=2.6, fe=0.4, ra=0.6, re=1.3, ht=-0.1, fl=0.5, fk=0.4, rl=-0.45, rk=0.3, face="fight")   # 振りかぶる
            swing_dn = dict(hz=0.78, lean=0.4, fa=0.9, fe=0.1, ra=-0.3, re=1.0, ht=0.0, fl=1.0, fk=0.5, rl=-0.6, rk=0.2, face="fight")    # 振り下ろして弾く
            keysA += [dict(t=0.6, dx=0.2, hz=0.84, lean=0.1, fa=0.9, fe=1.4, ra=0.7, re=1.5, face="fight"),
                      dict(t=1.2, dx=0.2, **swing_up), dict(t=1.36, dx=0.2, **dict(swing_up, fa=2.9, lean=-0.2)),   # 玉が来るのを見て振りかぶる(予備動作)
                      dict(t=1.42, dx=0.35, **swing_dn), dict(t=1.56, dx=0.35, **dict(swing_dn, lean=0.3, hz=0.82)),
                      dict(t=1.6, dx=0.4, hz=0.84, lean=0.15)]
            raise_hand_b = dict(hz=0.84, lean=-0.1, fa=2.6, fe=0.3, ra=0.4, re=1.3, ht=-0.1, fl=0.5, fk=0.4, rl=-0.45, rk=0.3, face="fight")
            throw_b = dict(hz=0.8, lean=0.4, fa=1.55, fe=0.1, ra=-0.3, re=1.0, ht=0.0, fl=0.95, fk=0.5, rl=-0.6, rk=0.2, face="fight")
            keysB = [dict(t=0.0, dx=-1.7), dict(t=0.62, dx=-1.7, **raise_hand_b), dict(t=1.0, dx=-1.7, **dict(raise_hand_b, fa=2.9, lean=-0.2, hz=0.8)),
                     dict(t=1.1, dx=-1.5, **throw_b), dict(t=1.4, dx=-1.5, **dict(throw_b, lean=0.3, hz=0.84)),
                     *([] if bfirst else [dict(t=_r(tc), dx=-1.7, **GUARD)])] + [k for k in keysB if k["t"] > 1.5]
            x_hit = _r(a_root0 + 1.05)
            fx_orbs.append(dict(start=0.62, end=1.1, who="B", r0=0.14, r1=0.36, color=col))
            fx_proj.append(dict(start=1.1, end=1.42, x0=_r(b_root0 - 0.9), z0=1.5, x1=x_hit, z1=1.3, r=0.36, color=col))
            hits += [dict(tau=1.1, hold=0.0, kind="throw", by="B", pos=[_r(b_root0 - 0.9), 1.5]),
                     dict(tau=1.42, hold=0.06, kind="blast", pos=[x_hit, 1.3])]
            flashes.append(1.42)
            slow.append(dict(start=1.36, end=1.5, rate=0.5))
            shots.insert(0, dict(t=0.55, follow="B", scale=[[0.55, 4.4], [1.1, 4.0]], yaw=[[0.55, 26.0], [1.1, 14.0]], pitch=6.0, lens=32.0, target_z=1.2, lag=0.25))
            shots.append(dict(t=1.1, follow="A", scale=5.2, yaw=-6.0, pitch=3.0, lens=44.0, target_z=1.3))          # 玉が A へ飛んで来るのを A 寄りで
            shots.append(dict(t=1.7, follow="A", scale=[[1.7, 4.8], [tc + 0.4, 3.9]], yaw=[[1.7, -38.0], [tc + 0.4, -20.0]], pitch=4.0, lens=30.0, target_z=1.0, lag=0.3))
        if open_fly:                                     # 飛行: 0.6 しゃがむ → 0.75 跳び上がる → 0.9〜1.3 水平に飛ぶ → 1.45 急降下 → ta に着地(つぶれ)
            t_land = _r(ta)
            t_up = _r(t_land - 0.95)
            clipsA.pop(0)                                # 走りは使わない
            keysA = [k for k in keysA if k["t"] not in (0.6, _r(ta))]
            fly_pose = dict(lean=1.25, fa=2.95, fe=0.1, ra=-0.6, re=0.4, fl=-0.25, fk=0.08, rl=-0.45, rk=0.1, ht=-0.55, hz=0.9, face="fight")   # 体を水平に、前の腕を突き出し、脚をまっすぐ後ろへ
            keysA += [dict(t=0.6, dx=0.2, hz=0.84, lean=0.1, fa=0.9, fe=1.4, ra=0.7, re=1.5, face="fight"),
                      dict(t=_r(t_up - 0.12), dx=0.2, hz=0.62, lean=0.35, fl=1.0, fk=1.7, rl=-0.3, rk=1.3, fa=-0.5, fe=1.0, ra=-0.5, re=1.0),   # しゃがむ(予備動作)
                      dict(t=_r(t_up), dx=0.3, rz=0.6, hz=0.95, lean=-0.15, fa=2.6, fe=0.3, ra=2.2, re=0.4, fl=0.3, fk=0.2, rl=-0.3, rk=0.2),   # 伸び上がって跳ぶ(腕を上へ)
                      dict(t=_r(t_up + 0.15), dx=0.8, rz=1.9, **fly_pose),                                                                   # 高く上がり水平に
                      dict(t=_r(t_up + 0.55), dx=_r(a_dx - 1.4), rz=2.2, **fly_pose),                                                        # 飛ぶ(頂点)
                      dict(t=_r(t_land - 0.14), dx=_r(a_dx - 0.4), rz=1.0, **dict(fly_pose, lean=0.9, ht=-0.3)),                              # 急降下
                      dict(t=_r(t_land), dx=a_dx, rz=0.0, hz=0.68, lean=0.25, fl=1.0, fk=1.5, rl=-0.35, rk=1.1, fa=0.3, fe=1.2, ra=0.3, re=1.2),   # 着地のつぶれ(0.6 だと這いつくばりに見えた)
                      dict(t=_r(t_land + 0.14), dx=a_dx, hz=0.9, lean=0.1, fa=0.9, fe=1.4, ra=0.7, re=1.5)]
            hits += [dict(tau=_r(t_up), hold=0.0, kind="launch", by="A", pos=[-2.0 + 0.3, 0.0]),
                     dict(tau=_r(t_land), hold=0.03, kind="land", by="A", pos=[_r(-2.0 + a_dx), 0.0])]
            speed.append([_r(t_up), _r(t_land)])
            glide_ranges.append([_r(t_up + 0.1), _r(t_land - 0.05), "A"])   # 飛行中は手足の光の尾(前のコマの影はカメラが動くと B の立ち姿まで写った)
            keysB += [dict(t=_r(t_land - 0.2), dx=-1.7, lean=-0.15, ht=-0.45, fa=0.6, ra=0.5, fe=1.2, re=1.3, face="fight"),   # 見上げる
                      dict(t=_r(t_land + 0.15), dx=-1.7, lean=0.05, ht=0.0, fa=0.9, fe=1.4, ra=0.7, re=1.5, face="fight")]
            shots.insert(0, dict(t=0.55, follow="A", scale=[[0.55, 4.6], [t_up, 4.2]], yaw=[[0.55, -26.0], [t_up, -14.0]], pitch=6.0, lens=32.0, target_z=1.1, lag=0.25))
            shots.append(dict(t=_r(t_up + 0.05), follow="A", scale=5.0, yaw=-10.0, pitch=-6.0, lens=36.0, target_z=2.0, lag=0.15))      # 飛行は少し下から見上げる
            shots.append(dict(t=_r(t_land - 0.05), follow="B", scale=4.0, yaw=18.0, pitch=8.0, lens=32.0, target_z=1.0, lag=0.0))      # 着地は B 寄りで
        if open_tp:                                      # 瞬間移動: 1.0 まで構え → 1.05 沈む(予備動作) → 1.1 消える → 1.2 相手の目の前に現れる → 1.3 構え直して連打へ
            t_go = _r(ta - 0.1)
            clipsA.pop(0)                                # 走りは使わない(長さ 0 で残すと継ぎ目合わせが狂い、連打の途中で A が 1.9 戻った)
            keysA = [k for k in keysA if k["t"] not in (0.6, _r(ta))]
            keysA += [dict(t=0.6, dx=0.2, hz=0.84, lean=0.1, fa=0.9, fe=1.4, ra=0.7, re=1.5, face="fight"),
                      dict(t=_r(t_go - 0.06), dx=0.2, hz=0.7, lean=0.3, fl=0.8, fk=1.2, rl=-0.4, rk=0.8, fa=0.5, fe=1.2, ra=0.5, re=1.2),   # 沈む
                      dict(t=_r(t_go), dx=0.2, hz=0.7, lean=0.3, fl=0.8, fk=1.2, rl=-0.4, rk=0.8),
                      dict(t=_r(t_go + 0.034), dx=_r(a_dx - 0.3), hz=0.78, lean=0.35, fl=1.0, fk=0.6, rl=-0.6, rk=0.3, fa=1.2, fe=0.8, ra=0.4, re=1.3),   # 1 コマで目の前に
                      dict(t=_r(ta), dx=a_dx, hz=0.9, lean=0.1, fa=0.9, fe=1.4, ra=0.7, re=1.5)]
            snaps.append(dict(who="A", t0=_r(t_go - 0.12), t1=_r(t_go + 0.001), dx=0.2))             # 消えるまでは位置を固定(PCHIP の先回りとバネで 3 コマに伸びていた)
            snaps.append(dict(who="A", t0=_r(t_go + 0.001), t1=_r(t_go + 0.1), dx=_r(a_dx - 0.3)))  # 現れた直後も固定
            fx_after.append(dict(start=_r(t_go), end=_r(t_go + 0.12), who="A", x0=-2.0 + 0.2, x1=-2.0 + a_dx - 0.3, n=6))   # 0.2 秒だと現れた後も残像が残った
            hits += [dict(tau=_r(t_go), hold=0.0, kind="vanish", by="A", pos=[-2.0 + 0.2, 1.0]),
                     dict(tau=_r(t_go + 0.034), hold=0.04, kind="appear", by="A", pos=[_r(-2.0 + a_dx - 0.3), 1.0])]
            flashes.append(_r(t_go + 0.034))
            keysB += [dict(t=_r(t_go + 0.1), dx=-1.7, lean=-0.25, ht=-0.35, fa=0.6, ra=0.5, fe=1.2, re=1.3, face="fight"),   # 驚いてのけぞる
                      dict(t=_r(t_go + 0.3), dx=-1.7, lean=0.05, ht=0.0, fa=0.9, fe=1.4, ra=0.7, re=1.5, face="fight")]
            shots.insert(0, dict(t=0.55, follow="A", scale=[[0.55, 4.6], [t_go, 4.0]], yaw=[[0.55, -26.0], [t_go, -14.0]], pitch=6.0, lens=32.0, target_z=1.1, lag=0.25))
            shots.append(dict(t=_r(t_go + 0.034), follow="B", scale=3.6, yaw=20.0, pitch=4.0, lens=32.0, target_z=1.1, lag=0.0))   # 現れた瞬間は B 寄りで
        if open_blast:                                   # 走り出す前の気弾: 0.6 片手を上げて玉を膨らませ → 1.15 投げる → 1.35 B がくぐる → 1.55 壁で爆発 → 1.6 走り出す
            col = list(s.get("beam_color") or [255, 190, 70])
            clipsA[0].update(start=1.6, **{"in": 0.12})
            raise_hand = dict(hz=0.84, lean=-0.1, fa=2.6, fe=0.3, ra=0.4, re=1.3, ht=-0.1, fl=0.5, fk=0.4, rl=-0.45, rk=0.3, face="fight")
            throw_pose = dict(hz=0.8, lean=0.4, fa=1.55, fe=0.1, ra=-0.3, re=1.0, ht=0.0, fl=0.95, fk=0.5, rl=-0.6, rk=0.2, face="fight")
            keysA = [k for k in keysA if k["t"] not in (0.6,)]
            keysA += [dict(t=0.62, dx=0.2, **raise_hand), dict(t=1.05, dx=0.2, **dict(raise_hand, fa=2.9, lean=-0.2, hz=0.8)),
                      dict(t=1.15, dx=0.4, **throw_pose), dict(t=1.45, dx=0.4, **dict(throw_pose, lean=0.3, hz=0.84)),
                      dict(t=1.6, dx=0.5, hz=0.84, lean=0.15)]
            a_root0 = -2.0 + 0.4
            fx_orbs.append(dict(start=0.62, end=1.15, who="A", r0=0.14, r1=0.36, color=col))
            fx_proj.append(dict(start=1.15, end=1.55, x0=_r(a_root0 + 0.9), z0=1.5, x1=6.0, z1=1.25, r=0.36, color=col, to_wall=True))
            hits += [dict(tau=1.15, hold=0.0, kind="throw", by="A", pos=[_r(a_root0 + 0.9), 1.5]),
                     dict(tau=1.35, hold=0.0, kind="miss", by="A", pos=[_r(2.4 + 1.7), 1.3]),       # B がくぐる(pos の高さ≥0.95 で body_drive が沈ませる)
                     dict(tau=1.55, hold=0.05, kind="blast", by="A", pos=[6.0, 1.25], to_wall=True)]
            flashes.append(1.55)
            shots.insert(0, dict(t=0.55, follow="A", scale=[[0.55, 4.2], [1.15, 3.6]], yaw=[[0.55, -26.0], [1.15, -14.0]], pitch=6.0, lens=32.0, target_z=1.2, lag=0.25))
            shots.append(dict(t=1.15, follow="B", scale=5.2, yaw=4.0, pitch=3.0, lens=44.0, target_z=1.3))   # 玉が B を越えて壁で爆発するまで入れる(mid だと壁が画面外で爆発が見えなかった)
            shots.append(dict(t=1.7, follow="A", scale=[[1.7, 4.8], [tc + 0.4, 3.9]], yaw=[[1.7, -38.0], [tc + 0.4, -20.0]], pitch=4.0, lens=30.0, target_z=1.0, lag=0.3))
        if bfirst:                                       # B が先に仕掛ける: 1発目は A が沈んでかわし(miss)、2発目は A が受け止める(clash)
            tb1, tb2 = tc - 0.78, tc - 0.40
            keysB = [k for k in keysB[:-1] if k["t"] < tc - 1.3] + [dict(t=_r(tc - 1.2), dx=-1.7, **GUARD), dict(t=_r(tb1 - 0.15), dx=-1.0, **GUARD),
                     dict(t=_r(tc - 0.18), dx=-1.4, **GUARD), keysB[-1]]   # 出だしの技(撃ち落とし・空中戦)の早いキーは残す(丸ごと置き換えると B が投げも跳びもしなかった)
            clipsB += [dict(file=cclip, dx_scale=0.3, strike_at=_r(tb1), start=_r(tb1 - 0.2), end=_r(tb1 + 0.17), **{"in": 0.06, "out": 0.08}),
                       dict(file=cclip, dx_scale=0.3, strike_at=_r(tb2), start=_r(tb2 - 0.17), end=_r(tb2 + 0.25), **{"in": 0.06, "out": 0.1})]
            hits += [dict(tau=_r(tb1), hold=0.0, kind="miss", by="B", pos=[2.9, 1.25],
                          contact=dict(striker="B", effector="hand", target=dict(actor="A", point="head"), offset=[-0.25, 0.22], tol=1.5, max_anticipation=50)),
                     dict(tau=_r(tb2), hold=0.07, kind="clash", by="B", contact=dict(striker="B", effector="hand", target=dict(actor="A", point=_pt(cclip, "hand")), tol=0.45, max_anticipation=50, hz_range=0.5, surface=0.38))]
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
        gaps[n - 2] = round(max(gaps[n - 2], tb_off + 0.45 * (bc - 1) + (0.78 if s["timing"] else 0.6)), 2)   # 間を作るときは、受け止めてから決めの振りかぶりまでを長く(0.6 だとキレ 2.3)
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
        if s["timing"] and kick_i != i:
            clip["step_in"] = 0.3 if sword else 0.45     # 溜めの間は手前に立ち、振りと同時に踏み込む(素手の決めの前に 12 コマ重なって立っていた)。素手は腕が短いぶん大きく(0.3 だと根元 0.75 で頭が触れていた)
        if last and s["timing"]:                         # 決めの 1 発は間をいちばん強く: 溜めを長く(0.45 秒)、振りは最後の 12%(1 コマ)で半分進める
            clip["timing"] = dict(pre=0.45, post=0.3, pre_curve=[(0.0, 0.0), (0.12, 0.5), (0.65, 0.55), (1.0, 1.0)], antic=0.55, over=0.35)
            clip["start"] = _r(min(clip["start"], t - 0.45))
        if not last and kick_i != i and defend.get(i) != "miss":
            clip["anchor_dx"] = round(anchor, 2)
        clipsA.append(clip)
        if last and fin_kick:
            hits.append(dict(tau=_r(t), hold=0.08, kind="kick", by="A", contact=dict(striker="A", effector="foot", target=dict(actor="B", point="chest"), tol=round(0.32 + 0.6 * max(0.0, float(s["b_scale"]) - 1.0), 2), max_anticipation=50, hz_range=0.5)))
        elif last:
            hits.append(dict(tau=_r(t), hold=0.08, kind=kind_hit, by="A", contact=dict(striker="A", effector=eff, target=dict(actor="B", point=pt), tol=round(0.3 + 0.6 * max(0.0, float(s["b_scale"]) - 1.0), 2), max_anticipation=50, hz_range=dict(sword=0.4, dagger=0.4, staff=0.6, spear=0.9).get(s["weapon"], 0.4), surface=0.0 if sword else 0.16)))
        elif defend.get(i) == "clash":                   # 受け止め(鍔迫り合い): 命中の種類 clash、相手は腕を上げて受け、少しだけ押される。位置は接触で決める(腕で受けるので許容は広め)
            hits.append(dict(tau=_r(t), hold=0.07, kind="clash", by="A", contact=dict(striker="A", effector=eff, target=dict(actor="B", point=pt), tol=0.6, max_anticipation=50, hz_range=0.45, surface=0.45 if sword else 0.3)))   # 剣先(拳)は B の受けの腕で止まる(胴まで届くと受けをすり抜けて見える)
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
                hits.append(dict(tau=_r(tr), hold=0.07, kind="clash", by="B", contact=dict(striker="B", effector="hand", target=dict(actor="A", point=_pt(cclip, "hand")), tol=0.45, max_anticipation=50, hz_range=0.5, surface=0.38)))
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
                    hits.append(dict(tau=_r(tbj), hold=0.07, kind="clash", by="B", contact=dict(striker="B", effector="hand", target=dict(actor="A", point=_pt(cclip, "hand")), tol=0.45, max_anticipation=50, hz_range=0.5, surface=0.38)))
                    keysA += [dict(t=_r(tbj - 0.14), **BLOCK), dict(t=_r(tbj + 0.08), **BLOCK), dict(t=_r(tbj + 0.26), **GUARD_A)]
            dxB += 0.7                                   # 連打のあと B はその場に残る(0.7 戻していたので、A が決めの前に 2 コマで 1.0 追いかけて重なり、2 人とも壁へ流れていた)
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
        keysB += [dict(t=_r(hl + 0.06), dx=_r(dxB + 0.25), lean=-0.6, fa=0.3, ra=0.3, fe=0.6, re=0.6, ht=-0.8, face="pain"),   # 決めの直後はまだその場(0.25 下がるのは飛んでから。前は決めの溜めの間に B が 0.4 下がり、踏み込んだ A と重なっていた)
                  dict(t=_r(hl + 0.22), dx=-2.5, rz=0.9, roll=0.5, hz=0.9, lean=-0.5, fl=0.3, fk=0.2, rl=-0.2, rk=0.3, face="pain"),
                  dict(t=_r(hl + 0.55), dx=-2.9, rz=2.7, roll=1.6, hz=0.9, lean=-0.2, fa=-0.4, ra=-0.4, fe=0.3, re=0.3, face="pain"),   # 打ち上げは 1.5 身長の高さ(1.9 だと頭の高さで浮いているだけに見えた)
                  *([dict(t=_r(hl + 0.74), dx=-3.05, rz=2.75, roll=1.55, hz=0.9, lean=-0.25, fa=-0.6, ra=-0.3, fe=0.3, re=0.4, ht=-0.5, face="pain"),   # 空中 2 発目を受ける(少し浮く)
                      dict(t=_r(hl + 0.92), dx=-3.2, rz=2.8, roll=1.65, hz=0.9, lean=-0.2, fa=-0.3, ra=-0.7, fe=0.4, re=0.3, ht=-0.6, face="pain"),   # 3 発目
                      dict(t=_r(hl + 1.05), dx=-3.3, rz=2.6, roll=1.6, hz=0.9, lean=-0.2, fa=-0.4, ra=-0.4, fe=0.3, re=0.3, face="pain")] if air else []),
                  dict(t=_r(hl + 0.80 + ex), dx=-3.1, rz=1.05, roll=1.57, hz=0.9, lean=-0.1, fa=-0.2, ra=-0.2, face="pain"),   # 落ちてくる(叩きつけの前はまだ空中。前は 0.95 に着地のキーがあり、かかとが落ちる 2〜4 コマ前に床に着いていた)
                  dict(t=_r(hl + 0.95 + ex), dx=-3.2, rz=0.5, roll=1.57, hz=0.9, fa=0.1, ra=0.1, face="pain"),                     # かかとが当たる瞬間: 空中で受ける
                  dict(t=_r(hl + 1.02 + ex), dx=-3.25, rz=0.21, roll=1.57, hz=0.9, fa=0.3, ra=0.3, fl=0.0, fk=0.0, rl=0.0, rk=0.0, face="ko"),   # 叩きつけられて床へ(2 コマで落ちる)
                  dict(t=_r(hl + 1.14 + ex), dx=-3.25, rz=0.27, roll=1.57, hz=0.9, face="ko"),                                        # 床で小さく跳ね返る
                  dict(t=_r(hl + 1.26 + ex), dx=-3.25, rz=0.21, roll=1.57, hz=0.9, face="ko")]
        keysA += [dict(t=_r(hl + 0.22), dx=5.3, hz=0.7, lean=0.3),
                  dict(t=_r(hl + 0.42), dx=5.7, rz=1.9, hz=0.9, lean=0.2, fa=2.4, fe=0.4, ra=1.4, re=1.0, fl=0.8, fk=0.9, rl=-0.6, rk=0.7),   # 追って跳ぶ(相手の打ち上げに合わせて高く)
                  dict(t=_r(hl + 0.58), dx=5.9, rz=1.8, hz=0.9, lean=0.45, fa=-0.3, fe=0.2, ra=-0.2, re=0.5, fl=0.5, fk=0.6, rl=-0.4, rk=0.5),
                  *([dict(t=_r(hl + 0.66), dx=5.95, rz=1.85, hz=0.9, lean=-0.1, fa=-0.4, fe=1.6, ra=0.3, re=1.0, fl=0.4, fk=0.7, rl=-0.4, rk=0.5),   # 空中で引く(予備動作)
                      dict(t=_r(hl + 0.74), dx=6.55, rz=1.9, hz=0.9, lean=0.35, fa=1.65, fe=0.05, ra=-0.4, re=0.8, fl=0.6, fk=0.5, rl=-0.5, rk=0.4),   # 2 発目: 拳(B の根元 5.45 の 0.9 手前。6.1 だと 1.35 離れて届かなかった)
                      dict(t=_r(hl + 0.84), dx=6.5, rz=1.9, hz=0.9, lean=0.1, fa=0.6, fe=1.2, ra=-0.9, re=1.4, fl=0.5, fk=0.6, rl=-0.4, rk=0.5),    # 引く
                      dict(t=_r(hl + 0.92), dx=6.65, rz=1.95, hz=0.9, lean=0.4, fa=0.4, fe=1.0, ra=1.7, re=0.1, fl=0.6, fk=0.5, rl=-0.5, rk=0.4),    # 3 発目: 後ろの手で殴る
                      dict(t=_r(hl + 1.05), dx=6.4, rz=2.3, hz=0.9, lean=0.2, fa=2.4, fe=0.4, ra=1.4, re=1.0, fl=0.8, fk=0.9, rl=-0.6, rk=0.7)] if air else []),   # 上に抜けて叩きつけの構え
                  dict(t=_r(hl + 0.88 + ex), dx=5.98, rz=0.35, hz=0.96, lean=0.1, fl=0.9, fk=0.5, rl=-0.5, rk=0.3),   # 落ちる(伸び: 脚を下へ伸ばす)
                  dict(t=_r(hl + 0.95 + ex), dx=6.0, rz=0.0, hz=0.64, lean=0.38, fl=1.1, fk=1.9, rl=-0.3, rk=1.4),    # 着地のつぶれ(2 コマ深く沈む)
                  dict(t=_r(hl + 1.08 + ex), dx=6.0, hz=0.84, lean=0.2), dict(t=_r(hl + 1.3 + ex), dx=6.0, hz=0.9, lean=0.1)]
        hits += [dict(tau=_r(hl + 0.55), hold=0.1, kind="slash" if sword else "hit", by="A", pos=[4.9, 2.7]),
                 *([dict(tau=_r(hl + 0.74), hold=0.05, kind="hit", by="A", pos=[5.35, 2.75]), dict(tau=_r(hl + 0.92), hold=0.05, kind="hit", by="A", pos=[5.4, 2.8])] if air else []),
                 dict(tau=_r(hl + 0.95 + ex), hold=0.1, kind="heel", by="A", pos=[5.6, 0.0])]
        puffs.append(dict(tau=_r(hl + 1.02 + ex), kind="land2", pos=[5.6, 0.0]))
        slow.append(dict(start=_r(hl + 0.4), end=_r(hl + 0.65), rate=0.4))
        flashes.append(_r(hl + 0.55))
        t_end = hl + 1.3 + ex
        ko_t = hl + 0.95 + ex
    elif beam:
        # 決めの 1 発でよろけた B を、気の光線で壁まで吹き飛ばす
        b_wall = round(max(6.0, 2.4 - min(float(k["dx"]) for k in keysB if "dx" in k) + 1.3, 2.4 - (dxB - 0.45) + 1.3), 2)   # 壁の位置(あとで wall_x に使う。よろけて下がる分は含め、飛ぶキーは含めない)
        wall_lock = b_wall
        b_root = 2.4 - (dxB - 0.45)                      # よろけて下がった B の根元
        t_c0, t_fire = _r(hl + 0.35), _r(hl + 1.45)      # 構え → 1.1 秒溜めて発射
        beam_col = list(s.get("beam_color") or [120, 230, 255])
        keysB += [dict(t=_r(hl + 0.1), dx=_r(dxB + 0.25), lean=-0.6, fa=0.3, ra=0.3, fe=0.6, re=0.6, ht=-0.8, face="pain"),
                  dict(t=_r(hl + 0.5), dx=_r(dxB - 0.45), lean=-0.25, hz=0.84, fa=0.6, ra=0.5, fe=1.0, re=1.1, ht=-0.3, face="pain"),   # よろけて 0.7 下がる(光線の長さを取る)
                  dict(t=_r(t_fire - 0.04), dx=_r(dxB - 0.45), lean=-0.2, hz=0.85, fa=0.8, ra=0.6, fe=1.2, re=1.2, ht=-0.1, face="pain"),
                  dict(t=_r(t_fire + 0.05), dx=_r(dxB - 0.55), lean=-0.7, hz=0.9, fa=-0.9, ra=-0.9, fe=0.3, re=0.3, ht=-0.8, face="pain"),   # 光線を受けてのけぞる
                  dict(t=_r(t_fire + 0.2), dx=_r(2.4 - (b_wall - 1.4)), rz=1.3, roll=1.0, hz=0.9, fa=-1.1, ra=-0.9, fe=0.2, re=0.3, fl=0.9, fk=0.4, rl=0.2, rk=0.3, lean=-0.3, ht=-0.6, face="pain"),   # 吹き飛ぶ
                  dict(t=_r(t_fire + 0.34), dx=_r(2.4 - (b_wall - 0.3)), rz=1.35, roll=0.3, hz=0.9, fa=-0.9, ra=-0.9, fe=0.3, re=0.3, fl=0.6, fk=0.3, rl=-0.3, rk=0.4, lean=-0.35, ht=-0.7, face="pain"),   # 壁に張りつく
                  dict(t=_r(t_fire + 0.55), dx=_r(2.4 - (b_wall - 0.3)), rz=1.25, roll=0.35, hz=0.9, lean=-0.3, face="pain"),
                  dict(t=_r(t_fire + 0.85), dx=_r(2.4 - (b_wall - 0.45)), rz=0.55, roll=1.2, hz=0.9, lean=0.0, fa=0.2, ra=0.2, face="pain"),   # ずり落ちる
                  dict(t=_r(t_fire + 1.05), dx=_r(2.4 - (b_wall - 0.5)), rz=0.21, roll=1.57, hz=0.9, fa=0.4, ra=0.4, fl=0.0, fk=0.0, rl=0.0, rk=0.0, face="ko")]
        charge_pose = dict(hz=0.74, lean=0.12, fa=-0.3, fe=2.3, ra=-0.25, re=2.3, ht=0.05, fl=0.55, fk=0.5, rl=-0.5, rk=0.35, face="fight")   # 肘を畳んで両手を腰の脇に、腰を落とす(腕を後ろへ回すと横からは腕が見えない)
        fire_pose = dict(hz=0.82, lean=0.38, fa=1.6, fe=0.05, ra=1.55, re=0.08, ht=-0.05, fl=0.9, fk=0.45, rl=-0.55, rk=0.2, face="fight")        # 両腕をまっすぐ突き出す
        keysA += [dict(t=_r(hl + 0.12), dx=5.0, hz=0.9, lean=0.15),
                  dict(t=_r(hl + 0.24), dx=4.4, rz=0.3, hz=0.9, lean=-0.1, fl=0.6, fk=0.9, rl=-0.4, rk=0.6),   # 跳んで下がる(光線の長さを取る)
                  dict(t=_r(t_c0), dx=3.7, **charge_pose),                                                    # 着地して構える
                  dict(t=_r(t_fire - 0.07), dx=3.7, **dict(charge_pose, hz=0.70, lean=0.05)),                # 溜めの終わり: さらに沈む(予備動作)
                  dict(t=_r(t_fire), dx=3.9, **fire_pose),                                                    # 2 コマで突き出す
                  dict(t=_r(t_fire + 0.12), dx=3.75, **dict(fire_pose, lean=0.3, hz=0.78)),                   # 反動で少し押し戻される
                  dict(t=_r(t_fire + 0.75), dx=3.75, **dict(fire_pose, lean=0.25, hz=0.84)),
                  dict(t=_r(t_fire + 1.0), dx=3.75, hz=0.88, lean=0.1, fa=0.9, fe=1.4, ra=0.7, re=1.5, ht=0.0, face="fight")]   # 腕を下ろす
        charge.append(dict(start=_r(t_c0), end=_r(t_fire), who="A", color=beam_col))
        hits += [dict(tau=_r(hl + 0.5), hold=0.0, kind="pose"),
                 dict(tau=_r(t_fire), hold=0.08, kind="beam", by="A", pos=[_r(b_root - 0.15), 1.3]),
                 dict(tau=_r(t_fire + 0.34), hold=0.06, kind="wall", pos=[b_wall, 1.6])]
        fx_beams.append(dict(start=_r(t_fire), end=_r(t_fire + 0.75), who="A", color=beam_col, x_end=b_wall + 1.2))   # 光線は壁を突き抜ける長さ
        flashes.append(_r(t_fire))
        slow.append(dict(start=_r(t_fire - 0.05), end=_r(t_fire + 0.25), rate=0.55))
        shots += [dict(t=_r(t_c0 - 0.1), follow="A", scale=[[_r(t_c0 - 0.1), 4.0], [_r(t_fire), 3.2]], yaw=[[_r(t_c0 - 0.1), -30.0], [_r(t_fire), -12.0]], pitch=6.0, lens=32.0, target_z=1.0, lag=0.25),   # 溜め: A に寄っていく
                  dict(t=_r(t_fire), follow="mid", scale=5.8, yaw=4.0, pitch=3.0, lens=44.0, target_z=1.3),    # 発射: 手から壁まで入る引きの画
                  dict(t=_r(t_fire + 0.95), follow="A", scale=[[_r(t_fire + 0.95), 4.6], [_r(t_fire + 2.4), 5.6]], yaw=[[_r(t_fire + 0.95), 30.0], [_r(t_fire + 2.4), -15.0]], pitch=8.0, lens=40.0, target_z=0.9)]
        puffs.append(dict(tau=_r(t_fire + 1.08), kind="land2", pos=[_r(b_wall - 0.5), 0.0]))
        t_end = t_fire + 1.1
        ko_t = t_fire + 1.05
    elif blast:
        b_wall = round(max(6.0, 2.4 - min(float(k["dx"]) for k in keysB if "dx" in k) + 1.3, 2.4 - (dxB - 0.45) + 1.3), 2)
        wall_lock = b_wall
        b_root = 2.4 - (dxB - 0.45)
        t_c0, t_throw = _r(hl + 0.35), _r(hl + 1.0)      # 構え → 0.65 秒で玉を膨らませて投げる
        t_hit = _r(t_throw + 0.2)                        # 玉が届く
        col = list(s.get("beam_color") or [255, 190, 70])
        a_root = -2.0 + 3.9                              # A の根元(dx 3.9)
        keysB += [dict(t=_r(hl + 0.1), dx=_r(dxB + 0.25), lean=-0.6, fa=0.3, ra=0.3, fe=0.6, re=0.6, ht=-0.8, face="pain"),
                  dict(t=_r(hl + 0.5), dx=_r(dxB - 0.45), lean=-0.25, hz=0.84, fa=0.6, ra=0.5, fe=1.0, re=1.1, ht=-0.3, face="pain"),
                  dict(t=_r(t_hit - 0.04), dx=_r(dxB - 0.45), lean=-0.2, hz=0.85, fa=0.8, ra=0.6, fe=1.2, re=1.2, ht=-0.1, face="pain"),
                  dict(t=_r(t_hit + 0.05), dx=_r(dxB - 0.55), lean=-0.7, hz=0.9, fa=-0.9, ra=-0.9, fe=0.3, re=0.3, ht=-0.8, face="pain"),
                  dict(t=_r(t_hit + 0.2), dx=_r(2.4 - (b_wall - 1.4)), rz=1.3, roll=1.0, hz=0.9, fa=-1.1, ra=-0.9, fe=0.2, re=0.3, fl=0.9, fk=0.4, rl=0.2, rk=0.3, lean=-0.3, ht=-0.6, face="pain"),
                  dict(t=_r(t_hit + 0.34), dx=_r(2.4 - (b_wall - 0.3)), rz=1.35, roll=0.3, hz=0.9, fa=-0.9, ra=-0.9, fe=0.3, re=0.3, fl=0.6, fk=0.3, rl=-0.3, rk=0.4, lean=-0.35, ht=-0.7, face="pain"),
                  dict(t=_r(t_hit + 0.55), dx=_r(2.4 - (b_wall - 0.3)), rz=1.25, roll=0.35, hz=0.9, lean=-0.3, face="pain"),
                  dict(t=_r(t_hit + 0.85), dx=_r(2.4 - (b_wall - 0.45)), rz=0.55, roll=1.2, hz=0.9, lean=0.0, fa=0.2, ra=0.2, face="pain"),
                  dict(t=_r(t_hit + 1.05), dx=_r(2.4 - (b_wall - 0.5)), rz=0.21, roll=1.57, hz=0.9, fa=0.4, ra=0.4, fl=0.0, fk=0.0, rl=0.0, rk=0.0, face="ko")]
        raise_hand = dict(hz=0.84, lean=-0.1, fa=2.6, fe=0.3, ra=0.4, re=1.3, ht=-0.1, fl=0.5, fk=0.4, rl=-0.45, rk=0.3, face="fight")      # 片手を高く上げる(玉を頭上に)
        throw_pose = dict(hz=0.8, lean=0.4, fa=1.55, fe=0.1, ra=-0.3, re=1.0, ht=0.0, fl=0.95, fk=0.5, rl=-0.6, rk=0.2, face="fight")      # 腕を振り下ろして投げる
        keysA += [dict(t=_r(hl + 0.12), dx=5.0, hz=0.9, lean=0.15),
                  dict(t=_r(hl + 0.24), dx=4.4, rz=0.3, hz=0.9, lean=-0.1, fl=0.6, fk=0.9, rl=-0.4, rk=0.6),
                  dict(t=_r(t_c0), dx=3.9, **raise_hand),
                  dict(t=_r(t_throw - 0.1), dx=3.9, **dict(raise_hand, fa=2.9, lean=-0.2, hz=0.8)),          # 予備動作: さらに後ろへ引く
                  dict(t=_r(t_throw), dx=4.1, **throw_pose),                                                  # 2 コマで振り下ろす
                  dict(t=_r(t_throw + 0.3), dx=4.1, **dict(throw_pose, lean=0.3, hz=0.84)),
                  dict(t=_r(t_hit + 0.9), dx=4.1, hz=0.88, lean=0.1, fa=0.9, fe=1.4, ra=0.7, re=1.5, ht=0.0, face="fight")]
        fx_orbs.append(dict(start=_r(t_c0), end=_r(t_throw), who="A", r0=0.14, r1=0.42, color=col))
        fx_proj.append(dict(start=_r(t_throw), end=_r(t_hit), x0=_r(a_root + 0.9), z0=1.5, x1=_r(b_root - 0.15), z1=1.25, r=0.42, color=col))
        charge.append(dict(start=_r(t_c0), end=_r(t_throw), who="A", color=col))
        hits += [dict(tau=_r(hl + 0.5), hold=0.0, kind="pose"),
                 dict(tau=_r(t_throw), hold=0.0, kind="throw", by="A", pos=[_r(a_root + 0.9), 1.5]),
                 dict(tau=_r(t_hit), hold=0.1, kind="blast", by="A", pos=[_r(b_root - 0.15), 1.25]),
                 dict(tau=_r(t_hit + 0.34), hold=0.06, kind="wall", pos=[b_wall, 1.6])]
        flashes.append(_r(t_hit))
        slow.append(dict(start=_r(t_throw - 0.04), end=_r(t_hit + 0.1), rate=0.55))
        shots += [dict(t=_r(t_c0 - 0.1), follow="A", scale=[[_r(t_c0 - 0.1), 4.0], [_r(t_throw), 3.4]], yaw=[[_r(t_c0 - 0.1), -30.0], [_r(t_throw), -12.0]], pitch=6.0, lens=32.0, target_z=1.2, lag=0.25),
                  dict(t=_r(t_throw), follow="mid", scale=5.6, yaw=4.0, pitch=3.0, lens=44.0, target_z=1.3),
                  dict(t=_r(t_hit + 0.95), follow="A", scale=[[_r(t_hit + 0.95), 4.6], [_r(t_hit + 2.4), 5.6]], yaw=[[_r(t_hit + 0.95), 30.0], [_r(t_hit + 2.4), -15.0]], pitch=8.0, lens=40.0, target_z=0.9)]
        puffs.append(dict(tau=_r(t_hit + 1.08), kind="land2", pos=[_r(b_wall - 0.5), 0.0]))
        t_end = t_hit + 1.1
        ko_t = t_hit + 1.05
    elif meteor:
        b_wall = round(max(6.0, 2.4 - min(float(k["dx"]) for k in keysB if "dx" in k) + 1.3, 2.4 - (dxB - 0.45) + 1.3), 2)
        wall_lock = b_wall
        b_root = 2.4 - (dxB - 0.45)
        a_dx_m = (b_root - 1.1) + 2.0                    # 着弾する位置(B の 1.1 手前)
        t_jump, t_top, t_land = _r(hl + 0.45), _r(hl + 0.85), _r(hl + 1.1)   # 上り 0.4 秒、頂点で止め、落下 0.19 秒(0.25 だとふわりと浮いて見えた)
        col = list(s.get("beam_color") or [255, 200, 90])
        keysB += [dict(t=_r(hl + 0.1), dx=_r(dxB + 0.25), lean=-0.6, fa=0.3, ra=0.3, fe=0.6, re=0.6, ht=-0.8, face="pain"),
                  dict(t=_r(hl + 0.5), dx=_r(dxB - 0.45), lean=-0.2, hz=0.84, fa=0.6, ra=0.5, fe=1.0, re=1.1, ht=-0.3, face="pain"),
                  dict(t=_r(t_top), dx=_r(dxB - 0.45), lean=-0.25, hz=0.86, fa=0.9, ra=0.7, fe=1.2, re=1.2, ht=-0.5, face="pain"),       # 見上げる
                  dict(t=_r(t_land - 0.02), dx=_r(dxB - 0.45), lean=-0.3, hz=0.84, fa=0.6, ra=0.6, fe=1.0, re=1.0, ht=-0.4, face="pain"),
                  dict(t=_r(t_land + 0.06), dx=_r(dxB - 0.6), lean=-0.7, hz=0.9, fa=-0.9, ra=-0.9, fe=0.3, re=0.3, ht=-0.8, face="pain"),    # 衝撃でのけぞる
                  dict(t=_r(t_land + 0.2), dx=_r(2.4 - (b_wall - 1.4)), rz=1.3, roll=1.0, hz=0.9, fa=-1.1, ra=-0.9, fe=0.2, re=0.3, fl=0.9, fk=0.4, rl=0.2, rk=0.3, lean=-0.3, ht=-0.6, face="pain"),
                  dict(t=_r(t_land + 0.34), dx=_r(2.4 - (b_wall - 0.3)), rz=1.35, roll=0.3, hz=0.9, fa=-0.9, ra=-0.9, fe=0.3, re=0.3, fl=0.6, fk=0.3, rl=-0.3, rk=0.4, lean=-0.35, ht=-0.7, face="pain"),
                  dict(t=_r(t_land + 0.55), dx=_r(2.4 - (b_wall - 0.3)), rz=1.25, roll=0.35, hz=0.9, lean=-0.3, face="pain"),
                  dict(t=_r(t_land + 0.85), dx=_r(2.4 - (b_wall - 0.45)), rz=0.55, roll=1.2, hz=0.9, lean=0.0, fa=0.2, ra=0.2, face="pain"),
                  dict(t=_r(t_land + 1.05), dx=_r(2.4 - (b_wall - 0.5)), rz=0.21, roll=1.57, hz=0.9, fa=0.4, ra=0.4, fl=0.0, fk=0.0, rl=0.0, rk=0.0, face="ko")]
        keysA += [dict(t=_r(hl + 0.12), dx=5.0, hz=0.9, lean=0.15),
                  dict(t=_r(t_jump - 0.14), dx=4.6, hz=0.6, lean=0.35, fl=1.0, fk=1.8, rl=-0.3, rk=1.4, fa=-0.6, fe=1.0, ra=-0.6, re=1.0),   # 深く沈む(予備動作)
                  dict(t=_r(t_jump), dx=4.5, rz=0.8, hz=0.98, lean=-0.2, fa=2.9, fe=0.2, ra=2.6, re=0.3, fl=0.3, fk=0.2, rl=-0.3, rk=0.2),   # 伸び上がって跳ぶ
                  dict(t=_r(t_top), dx=_r(a_dx_m - 0.3), rz=3.6, hz=0.9, lean=0.0, fa=2.4, fe=0.5, ra=2.2, re=0.6, fl=0.5, fk=0.9, rl=-0.4, rk=0.8),   # 頂点(1.9 身長)で一瞬止まる
                  dict(t=_r(t_top + 0.06), dx=_r(a_dx_m - 0.2), rz=3.4, hz=0.9, lean=0.6, fa=-0.9, fe=0.3, ra=-0.7, re=0.4, fl=0.6, fk=0.4, rl=-0.5, rk=0.3),   # 拳を下に構えて頭から落ち始める
                  dict(t=_r(t_land), dx=_r(a_dx_m), rz=0.0, hz=0.5, lean=0.5, fa=-1.3, fe=0.2, ra=-1.1, re=0.3, fl=1.1, fk=2.0, rl=-0.2, rk=1.6, ht=0.1),   # 着弾(拳が地面、つぶれ)
                  dict(t=_r(t_land + 0.35), dx=_r(a_dx_m), hz=0.52, lean=0.45, fa=-1.2, fe=0.3, ra=-1.0, re=0.4),
                  dict(t=_r(t_land + 0.9), dx=_r(a_dx_m), hz=0.88, lean=0.1, fa=0.9, fe=1.4, ra=0.7, re=1.5, ht=0.0, face="fight")]
        glide_ranges.append([_r(t_top + 0.06), _r(t_land - 0.02), "A"])                                  # 落下中は手足の光の尾
        hits += [dict(tau=_r(hl + 0.5), hold=0.0, kind="pose"),
                 dict(tau=_r(t_jump), hold=0.0, kind="launch", by="A", pos=[_r(a_dx_m - 2.0 - 0.5), 0.0]),
                 dict(tau=_r(t_top), hold=0.08, kind="pose"),
                 dict(tau=_r(t_land), hold=0.1, kind="slam", by="A", pos=[_r(a_dx_m - 2.0 + 0.6), 0.05]),
                 dict(tau=_r(t_land + 0.34), hold=0.06, kind="wall", pos=[b_wall, 1.6])]
        flashes.append(_r(t_land))
        slow += [dict(start=_r(t_top - 0.03), end=_r(t_top + 0.12), rate=0.45), dict(start=_r(t_land - 0.06), end=_r(t_land + 0.05), rate=0.6)]
        shots += [dict(t=_r(hl + 0.3), follow="A", scale=[[_r(hl + 0.3), 4.6], [_r(t_jump), 4.2]], yaw=[[_r(hl + 0.3), -26.0], [_r(t_jump), -12.0]], pitch=8.0, lens=34.0, target_z=1.1, lag=0.2),
                  dict(t=_r(t_jump + 0.03), follow="A", scale=6.4, yaw=-6.0, pitch=-10.0, lens=36.0, target_z=2.6, lag=0.1),    # 跳びを下から見上げる(頂点まで入る)
                  dict(t=_r(t_land - 0.12), follow="mid", scale=5.6, yaw=6.0, pitch=10.0, lens=40.0, target_z=0.9),
                  dict(t=_r(t_land + 0.95), follow="A", scale=[[_r(t_land + 0.95), 4.6], [_r(t_land + 2.4), 5.6]], yaw=[[_r(t_land + 0.95), 30.0], [_r(t_land + 2.4), -15.0]], pitch=8.0, lens=40.0, target_z=0.9)]
        puffs.append(dict(tau=_r(t_land + 1.08), kind="land2", pos=[_r(b_wall - 0.5), 0.0]))
        t_end = t_land + 1.1
        ko_t = t_land + 1.05
    elif blink:
        b_root = 2.4 - (dxB - 0.45)
        a0 = (b_root - 2.6) + 2.0                        # 構える位置(dx)。B の 2.6 手前
        a1 = (b_root - 0.95) + 2.0                       # 1 回目: 目の前
        a2 = (b_root - 0.35) + 2.0                       # 2 回目: 頭上(少し手前)
        a3 = (b_root - 3.2) + 2.0                        # 3 回目: 離れた所
        t_c0 = _r(hl + 0.5)
        t1, t2, t3 = _r(hl + 1.0), _r(hl + 1.45), _r(hl + 1.95)       # 現れる時刻
        h1, h2 = _r(t1 + 0.12), _r(t2 + 0.14)            # 拳・踵落としの命中
        keysB += [dict(t=_r(hl + 0.1), dx=_r(dxB + 0.25), lean=-0.6, fa=0.3, ra=0.3, fe=0.6, re=0.6, ht=-0.8, face="pain"),
                  dict(t=_r(hl + 0.5), dx=_r(dxB - 0.45), lean=-0.1, hz=0.86, fa=0.8, ra=0.6, fe=1.2, re=1.2, ht=-0.1, face="fight"),
                  dict(t=_r(h1 - 0.02), dx=_r(dxB - 0.45), lean=-0.1, hz=0.86, fa=0.8, ra=0.6, fe=1.2, re=1.2, ht=-0.1, face="fight"),
                  dict(t=_r(h1 + 0.08), dx=_r(dxB - 0.5), lean=-0.55, hz=0.84, fa=-0.6, ra=-0.6, fe=0.4, re=0.4, ht=-0.7, face="pain"),      # 拳でのけぞる
                  dict(t=_r(h2 - 0.02), dx=_r(dxB - 0.5), lean=-0.3, hz=0.86, fa=0.2, ra=0.2, fe=0.8, re=0.8, ht=-0.4, face="pain"),
                  dict(t=_r(h2 + 0.06), dx=_r(dxB - 0.5), lean=0.35, hz=0.5, fl=1.0, fk=1.9, rl=-0.3, rk=1.6, fa=0.3, ra=0.3, fe=1.0, re=1.0, ht=0.3, face="pain"),   # 踵落としで膝から崩れる
                  dict(t=_r(t3 + 0.3), dx=_r(dxB - 0.5), lean=0.4, hz=0.5, fl=1.0, fk=1.9, rl=-0.3, rk=1.6, ht=0.35, face="pain"),
                  dict(t=_r(t3 + 0.5), dx=_r(dxB - 0.52), rz=0.4, roll=1.0, hz=0.9, lean=0.1, fl=0.2, fk=0.3, rl=-0.2, rk=0.3, fa=0.3, ra=0.3, face="pain"),
                  dict(t=_r(t3 + 0.66), dx=_r(dxB - 0.55), rz=0.21, roll=1.57, hz=0.9, fa=0.4, ra=0.4, fl=0.0, fk=0.0, rl=0.0, rk=0.0, face="ko")]
        crouch = dict(hz=0.7, lean=0.3, fl=0.8, fk=1.2, rl=-0.4, rk=0.8, fa=0.5, fe=1.2, ra=0.5, re=1.2, face="fight")
        punch = dict(hz=0.8, lean=0.35, fa=1.65, fe=0.05, ra=-0.3, re=1.0, fl=0.9, fk=0.5, rl=-0.6, rk=0.3, face="fight")
        axe_up = dict(hz=0.9, lean=0.1, fa=0.6, fe=1.0, ra=0.4, re=1.0, fl=2.4, fk=0.3, rl=-0.3, rk=0.4, face="fight")      # 頭上で脚を高く上げる
        axe_dn = dict(hz=0.9, lean=0.4, fa=-0.4, fe=0.8, ra=-0.4, re=0.8, fl=0.3, fk=0.1, rl=-0.3, rk=0.4, face="fight")     # 振り下ろす
        keysA += [dict(t=_r(hl + 0.12), dx=5.0, hz=0.9, lean=0.15),
                  dict(t=_r(hl + 0.3), dx=_r(a0 + 0.4), hz=0.88, lean=0.05),
                  dict(t=_r(t_c0), dx=_r(a0), **crouch),
                  dict(t=_r(t1 - 0.001), dx=_r(a0), **dict(crouch, hz=0.66)),                                   # 沈む(予備動作)→ 消える
                  dict(t=_r(t1 + 0.034), dx=_r(a1), **dict(punch, fa=0.3, fe=1.6)),                              # 目の前に現れる(拳を引いた形)
                  dict(t=_r(h1), dx=_r(a1 + 0.1), **punch),                                                      # 拳
                  dict(t=_r(t2 - 0.001), dx=_r(a1 + 0.1), **dict(punch, lean=0.25)),
                  dict(t=_r(t2 + 0.034), dx=_r(a2), rz=1.9, **axe_up),                                           # 頭上に現れる
                  dict(t=_r(h2), dx=_r(a2 + 0.05), rz=1.1, **axe_dn),                                            # 踵落とし(落ちながら)
                  dict(t=_r(h2 + 0.12), dx=_r(a2 + 0.1), rz=0.0, hz=0.62, lean=0.35, fl=1.0, fk=1.7, rl=-0.3, rk=1.3, fa=0.3, fe=1.2, ra=0.3, re=1.2),   # 着地(つぶれ)
                  dict(t=_r(t3 - 0.001), dx=_r(a2 + 0.1), hz=0.66, lean=0.3, fl=0.9, fk=1.4, rl=-0.4, rk=1.0),
                  dict(t=_r(t3 + 0.034), dx=_r(a3), hz=0.9, lean=0.05, fa=0.4, fe=1.3, ra=0.5, re=1.4, fl=0.3, fk=0.2, rl=-0.3, rk=0.2, face="win"),   # 離れた所に現れて立つ
                  dict(t=_r(t3 + 1.0), dx=_r(a3), hz=0.9, lean=0.05, fa=0.4, fe=1.3, ra=0.5, re=1.4, face="win")]
        for (ta_, xa, xb) in ((t1, a0, a1), (t2, a1 + 0.1, a2), (t3, a2 + 0.1, a3)):
            snaps += [dict(who="A", t0=_r(ta_ - 0.1), t1=_r(ta_ + 0.001), dx=_r(xa)), dict(who="A", t0=_r(ta_ + 0.001), t1=_r(ta_ + 0.08), dx=_r(xb))]
            fx_after.append(dict(start=_r(ta_), end=_r(ta_ + 0.12), who="A", x0=_r(xa - 2.0), x1=_r(xb - 2.0), n=5))
            hits += [dict(tau=_r(ta_), hold=0.0, kind="vanish", by="A", pos=[_r(xa - 2.0), 1.0]),
                     dict(tau=_r(ta_ + 0.034), hold=0.0, kind="appear", by="A", pos=[_r(xb - 2.0), 1.0])]
            flashes.append(_r(ta_ + 0.034))
        hits += [dict(tau=_r(hl + 0.5), hold=0.0, kind="pose"),
                 dict(tau=_r(h1), hold=0.06, kind="hit", pos=[_r(b_root - 0.15), 1.3]),
                 dict(tau=_r(h2), hold=0.1, kind="heel", pos=[_r(b_root - 0.1), 1.5]),
                 dict(tau=_r(t3 + 0.68), hold=0.04, kind="land2", pos=[_r(2.4 - (dxB - 0.55)), 0.0])]
        slow += [dict(start=_r(h2 - 0.04), end=_r(h2 + 0.12), rate=0.5)]
        shots += [dict(t=_r(t_c0 - 0.1), follow="mid", scale=5.2, yaw=6.0, pitch=4.0, lens=40.0, target_z=1.2),   # 2 人が入る引き(瞬間移動が分かる)
                  dict(t=_r(t2 + 0.034), follow="B", scale=5.0, yaw=10.0, pitch=-4.0, lens=38.0, target_z=1.8, lag=0.0),   # 頭上まで入る
                  dict(t=_r(t3 + 0.034), follow="mid", scale=6.0, yaw=0.0, pitch=4.0, lens=42.0, target_z=1.0),   # 離れた 2 人
                  dict(t=_r(t3 + 0.9), follow="A", scale=[[_r(t3 + 0.9), 4.6], [_r(t3 + 2.4), 5.4]], yaw=[[_r(t3 + 0.9), 20.0], [_r(t3 + 2.4), -15.0]], pitch=6.0, lens=40.0, target_z=0.9)]
        t_end = t3 + 1.0
        ko_t = t3 + 0.66
    elif sthrow:
        b_root = 2.4 - (dxB - 0.45)
        a_dx_g = (b_root - 0.95) + 2.0                   # つかむ位置(B の 0.95 手前)
        a_root_g = a_dx_g - 2.0
        t_grab, t_lift, t_top, t_slam = _r(hl + 0.55), _r(hl + 0.85), _r(hl + 1.05), _r(hl + 1.25)
        land_x = a_root_g - 1.45                         # 背後に落ちる位置
        keysB += [dict(t=_r(hl + 0.1), dx=_r(dxB + 0.25), lean=-0.6, fa=0.3, ra=0.3, fe=0.6, re=0.6, ht=-0.8, face="pain"),
                  dict(t=_r(hl + 0.5), dx=_r(dxB - 0.45), lean=-0.2, hz=0.84, fa=0.6, ra=0.5, fe=1.0, re=1.1, ht=-0.3, face="pain"),
                  dict(t=_r(t_grab + 0.04), dx=_r(dxB - 0.45), lean=-0.1, hz=0.84, fa=0.3, ra=0.3, fe=0.9, re=0.9, ht=-0.1, face="pain"),       # つかまれる
                  dict(t=_r(t_lift), dx=_r(2.4 - (b_root - 0.5)), rz=0.9, roll=-0.9, hz=0.9, lean=0.2, fa=-0.6, ra=-0.6, fe=0.4, re=0.4, fl=0.4, fk=0.5, rl=-0.4, rk=0.5, ht=-0.4, face="pain"),   # 持ち上げられる(前へ倒れ込む)
                  dict(t=_r(t_top), dx=_r(2.4 - (a_root_g - 0.1)), rz=2.4, roll=-1.9, hz=0.9, lean=0.0, fa=-0.9, ra=-0.9, fe=0.3, re=0.3, fl=0.3, fk=0.3, rl=-0.3, rk=0.3, ht=-0.6, face="pain"),   # 頭上で逆さ
                  dict(t=_r(t_slam), dx=_r(2.4 - land_x), rz=0.32, roll=-1.57, hz=0.9, lean=0.0, fa=-0.4, ra=-0.4, fe=0.3, re=0.3, fl=0.0, fk=0.0, rl=0.0, rk=0.0, face="pain"),   # 背後の地面へ(横たわる=|roll| 1.57。−3.14 は逆立ちで頭が地面に潜った。roll −1.57 は rz 0.21 だと頭が 0.1 潜るので 0.32)
                  dict(t=_r(t_slam + 0.1), dx=_r(2.4 - land_x), rz=0.42, roll=-1.57, hz=0.9, face="ko"),                            # 跳ね返る
                  dict(t=_r(t_slam + 0.24), dx=_r(2.4 - land_x), rz=0.32, roll=-1.57, hz=0.9, face="ko")]
        keysA += [dict(t=_r(hl + 0.12), dx=5.0, hz=0.9, lean=0.15),
                  dict(t=_r(hl + 0.4), dx=_r(a_dx_g - 0.3), hz=0.72, lean=0.3, fa=0.4, fe=1.6, ra=0.3, re=1.6, fl=0.9, fk=0.8, rl=-0.6, rk=0.3, face="fight"),   # 腰を落として構え(予備動作)
                  dict(t=_r(t_grab), dx=_r(a_dx_g), hz=0.74, lean=0.45, fa=1.5, fe=0.15, ra=1.3, re=0.3, fl=1.0, fk=0.6, rl=-0.6, rk=0.2, face="fight"),         # 踏み込んでつかむ(両手を前へ)
                  dict(t=_r(t_lift), dx=_r(a_dx_g), hz=0.62, lean=0.15, fa=2.2, fe=0.3, ra=2.0, re=0.4, fl=0.9, fk=1.1, rl=-0.5, rk=0.6, face="fight"),           # 沈んで持ち上げ始める
                  dict(t=_r(t_top), dx=_r(a_dx_g + 0.1), hz=0.95, lean=-0.35, fa=3.0, fe=0.2, ra=2.8, re=0.3, fl=0.3, fk=0.2, rl=-0.5, rk=0.3, face="fight"),     # 伸び上がって頭上へ(反る)
                  dict(t=_r(t_slam), dx=_r(a_dx_g + 0.1), hz=0.62, lean=-0.6, fa=-1.4, fe=0.2, ra=-1.2, re=0.3, fl=0.6, fk=1.2, rl=-0.7, rk=0.9, face="fight"),   # 後ろへ叩きつける(腕を後ろ下へ、腰を落とす)
                  dict(t=_r(t_slam + 0.35), dx=_r(a_dx_g + 0.1), hz=0.7, lean=-0.4, fa=-1.0, fe=0.4, ra=-0.9, re=0.5),
                  dict(t=_r(t_slam + 0.9), dx=_r(a_dx_g + 0.1), hz=0.88, lean=0.05, fa=0.9, fe=1.4, ra=0.7, re=1.5, ht=0.0, face="fight")]
        hits += [dict(tau=_r(hl + 0.5), hold=0.0, kind="pose"),
                 dict(tau=_r(t_grab), hold=0.0, kind="grab", by="A", pos=[_r(b_root - 0.2), 1.3]),
                 dict(tau=_r(t_slam), hold=0.1, kind="heel", by="A", pos=[_r(land_x), 0.1])]
        puffs.append(dict(tau=_r(t_slam + 0.02), kind="land2", pos=[_r(land_x), 0.0]))
        flashes.append(_r(t_slam))
        slow.append(dict(start=_r(t_top - 0.05), end=_r(t_top + 0.1), rate=0.5))
        shots += [dict(t=_r(hl + 0.35), follow="mid", scale=4.2, yaw=12.0, pitch=4.0, lens=34.0, target_z=1.2, lag=0.2),
                  dict(t=_r(t_lift), follow="A", scale=5.4, yaw=8.0, pitch=2.0, lens=40.0, target_z=1.6, lag=0.0),    # 頭上まで入る引き
                  dict(t=_r(t_slam + 0.6), follow="A", scale=[[_r(t_slam + 0.6), 4.8], [_r(t_slam + 2.2), 5.6]], yaw=[[_r(t_slam + 0.6), 30.0], [_r(t_slam + 2.2), -15.0]], pitch=10.0, lens=40.0, target_z=0.8)]
        t_end = t_slam + 1.0
        ko_t = t_slam
    elif iai:
        b_root = 2.4 - (dxB - 0.45)
        a_dx0 = (b_root - 1.6) + 2.0                     # 構える位置(B の 1.6 手前)
        a_dx1 = (b_root + 1.3) + 2.0                     # 抜けた先(B の 1.3 向こう)
        t_c0, t_dash = _r(hl + 0.5), _r(hl + 1.25)       # 構えて 0.75 秒溜め、抜ける
        t_cut = _r(t_dash + 0.6)                         # 間を置いて斬撃線
        col = list(s.get("beam_color") or [235, 245, 255])
        keysB += [dict(t=_r(hl + 0.1), dx=_r(dxB + 0.25), lean=-0.6, fa=0.3, ra=0.3, fe=0.6, re=0.6, ht=-0.8, face="pain"),
                  dict(t=_r(hl + 0.5), dx=_r(dxB - 0.45), lean=-0.1, hz=0.86, fa=0.8, ra=0.6, fe=1.2, re=1.2, ht=-0.1, face="fight"),   # 立ち直って構える
                  dict(t=_r(t_cut - 0.02), dx=_r(dxB - 0.45), lean=-0.1, hz=0.86, fa=0.8, ra=0.6, fe=1.2, re=1.2, ht=-0.1, face="fight"),   # 抜かれたあとも立っている(間)
                  dict(t=_r(t_cut + 0.08), dx=_r(dxB - 0.45), lean=-0.2, hz=0.84, fa=0.4, ra=0.4, fe=0.8, re=0.8, ht=-0.5, face="pain"),    # 斬撃線が走ってのけぞる
                  dict(t=_r(t_cut + 0.45), dx=_r(dxB - 0.5), hz=0.55, lean=0.3, fl=1.0, fk=1.9, rl=-0.3, rk=1.6, fa=0.2, ra=0.2, fe=1.0, re=1.0, ht=0.2, face="pain"),   # 膝から崩れる
                  dict(t=_r(t_cut + 0.62), dx=_r(dxB - 0.52), rz=0.4, roll=1.0, hz=0.9, lean=0.1, fl=0.2, fk=0.3, rl=-0.2, rk=0.3, fa=0.3, ra=0.3, face="pain"),   # 横に倒れていく(少し浮かせる: 回る途中で脚が地面に潜った)
                  dict(t=_r(t_cut + 0.78), dx=_r(dxB - 0.55), rz=0.21, roll=1.57, hz=0.9, fa=0.4, ra=0.4, fl=0.0, fk=0.0, rl=0.0, rk=0.0, face="ko")]   # 倒れる
        sheath = dict(hz=0.72, lean=0.2, fa=-0.4, fe=1.9, ra=1.0, re=1.6, ht=0.1, fl=0.8, fk=0.7, rl=-0.6, rk=0.3, face="fight")        # 腰を落として柄に手(前の手は後ろ腰へ)
        passed = dict(hz=0.84, lean=0.15, fa=1.3, fe=0.3, ra=-0.5, re=1.0, ht=0.0, fl=0.4, fk=0.3, rl=-0.5, rk=0.3, face="fight")      # 抜けた直後: 剣を振り抜いた形(背を向けている)
        keysA += [dict(t=_r(hl + 0.12), dx=5.0, hz=0.9, lean=0.15),
                  dict(t=_r(hl + 0.28), dx=_r(a_dx0 + 0.5), hz=0.86, lean=0.05),
                  dict(t=_r(t_c0), dx=_r(a_dx0), **sheath),
                  dict(t=_r(t_dash - 0.08), dx=_r(a_dx0), **dict(sheath, hz=0.66, lean=0.3)),              # さらに沈む(予備動作)
                  dict(t=_r(t_dash), dx=_r(a_dx0), **dict(sheath, hz=0.66, lean=0.3)),
                  dict(t=_r(t_dash + 0.034), dx=_r(a_dx1), **passed),                                       # 1 コマで向こうへ
                  dict(t=_r(t_cut + 0.3), dx=_r(a_dx1), **dict(passed, lean=0.1)),
                  dict(t=_r(t_cut + 0.7), dx=_r(a_dx1), hz=0.88, lean=0.05, fa=-0.3, fe=1.8, ra=0.9, re=1.6, ht=0.0, face="fight"),   # 納刀
                  dict(t=_r(t_cut + 1.1), dx=_r(a_dx1), hz=0.9, lean=0.05, fa=0.4, fe=1.3, ra=0.5, re=1.4, face="win")]
        snaps += [dict(who="A", t0=_r(t_dash - 0.12), t1=_r(t_dash + 0.001), dx=_r(a_dx0)), dict(who="A", t0=_r(t_dash + 0.001), t1=_r(t_dash + 0.15), dx=_r(a_dx1))]
        fx_after.append(dict(start=_r(t_dash), end=_r(t_dash + 0.12), who="A", x0=_r(a_dx0 - 2.0), x1=_r(a_dx1 - 2.0), n=5))
        charge.append(dict(start=_r(t_c0), end=_r(t_dash), who="A", color=col))
        fx_cuts.append(dict(start=_r(t_cut), end=_r(t_cut + 0.5), x=_r(b_root), z=1.3, n=3, color=col))   # 位置は台本の B の根元(体を追うと崩れ落ちで外れた)
        hits += [dict(tau=_r(hl + 0.5), hold=0.0, kind="pose"),
                 dict(tau=_r(t_dash), hold=0.0, kind="vanish", by="A", pos=[_r(a_dx0 - 2.0), 1.0]),
                 dict(tau=_r(t_dash + 0.034), hold=0.0, kind="appear", by="A", pos=[_r(a_dx1 - 2.0), 1.0]),
                 dict(tau=_r(t_cut), hold=0.12, kind="slash", pos=[_r(b_root), 1.3]),   # by は付けない: 被弾の押されは B の向き基準(−dx=右へ)で、右に抜けた A の方へ寄ってしまう。反応は上のキーで書いてある
                 dict(tau=_r(t_cut + 0.8), hold=0.04, kind="land2", pos=[_r(2.4 - (dxB - 0.55)), 0.0])]
        flashes.append(_r(t_cut))
        slow.append(dict(start=_r(t_dash - 0.03), end=_r(t_dash + 0.08), rate=0.5))
        shots += [dict(t=_r(t_c0 - 0.1), follow="A", scale=[[_r(t_c0 - 0.1), 4.4], [_r(t_dash), 3.8]], yaw=[[_r(t_c0 - 0.1), -26.0], [_r(t_dash), -10.0]], pitch=6.0, lens=32.0, target_z=1.1, lag=0.25),
                  dict(t=_r(t_dash), follow="mid", scale=5.0, yaw=4.0, pitch=3.0, lens=44.0, target_z=1.2),     # 2 人が入る引きで、間を見せる
                  dict(t=_r(t_cut + 0.9), follow="A", scale=[[_r(t_cut + 0.9), 4.4], [_r(t_cut + 2.4), 5.4]], yaw=[[_r(t_cut + 0.9), 20.0], [_r(t_cut + 2.4), -15.0]], pitch=6.0, lens=40.0, target_z=0.9)]
        t_end = t_cut + 1.1
        ko_t = t_cut + 0.78
    elif swave:
        b_wall = round(max(6.0, 2.4 - min(float(k["dx"]) for k in keysB if "dx" in k) + 1.3, 2.4 - (dxB - 0.45) + 1.3), 2)
        wall_lock = b_wall
        b_root = 2.4 - (dxB - 0.45)
        t_c0, t_swing = _r(hl + 0.5), _r(hl + 1.15)      # 振りかぶって 0.65 秒溜め、振り抜く
        t_hit = _r(t_swing + 0.22)
        col = list(s.get("beam_color") or [170, 245, 255])
        a_root = -2.0 + 3.6
        keysB += [dict(t=_r(hl + 0.1), dx=_r(dxB + 0.25), lean=-0.6, fa=0.3, ra=0.3, fe=0.6, re=0.6, ht=-0.8, face="pain"),
                  dict(t=_r(hl + 0.5), dx=_r(dxB - 0.45), lean=-0.25, hz=0.84, fa=0.6, ra=0.5, fe=1.0, re=1.1, ht=-0.3, face="pain"),
                  dict(t=_r(t_hit - 0.04), dx=_r(dxB - 0.45), lean=-0.2, hz=0.85, fa=0.8, ra=0.6, fe=1.2, re=1.2, ht=-0.1, face="pain"),
                  dict(t=_r(t_hit + 0.05), dx=_r(dxB - 0.55), lean=-0.7, hz=0.9, fa=-0.9, ra=-0.9, fe=0.3, re=0.3, ht=-0.8, face="pain"),
                  dict(t=_r(t_hit + 0.2), dx=_r(2.4 - (b_wall - 1.4)), rz=1.3, roll=1.0, hz=0.9, fa=-1.1, ra=-0.9, fe=0.2, re=0.3, fl=0.9, fk=0.4, rl=0.2, rk=0.3, lean=-0.3, ht=-0.6, face="pain"),
                  dict(t=_r(t_hit + 0.34), dx=_r(2.4 - (b_wall - 0.3)), rz=1.35, roll=0.3, hz=0.9, fa=-0.9, ra=-0.9, fe=0.3, re=0.3, fl=0.6, fk=0.3, rl=-0.3, rk=0.4, lean=-0.35, ht=-0.7, face="pain"),
                  dict(t=_r(t_hit + 0.55), dx=_r(2.4 - (b_wall - 0.3)), rz=1.25, roll=0.35, hz=0.9, lean=-0.3, face="pain"),
                  dict(t=_r(t_hit + 0.85), dx=_r(2.4 - (b_wall - 0.45)), rz=0.55, roll=1.2, hz=0.9, lean=0.0, fa=0.2, ra=0.2, face="pain"),
                  dict(t=_r(t_hit + 1.05), dx=_r(2.4 - (b_wall - 0.5)), rz=0.21, roll=1.57, hz=0.9, fa=0.4, ra=0.4, fl=0.0, fk=0.0, rl=0.0, rk=0.0, face="ko")]
        raise_sword = dict(hz=0.8, lean=-0.15, fa=2.9, fe=0.2, ra=2.6, re=0.3, ht=-0.15, fl=0.5, fk=0.4, rl=-0.5, rk=0.3, face="fight")     # 両手で剣を頭上に振りかぶる
        swing_pose = dict(hz=0.74, lean=0.5, fa=0.9, fe=0.1, ra=0.7, re=0.2, ht=0.05, fl=1.0, fk=0.6, rl=-0.6, rk=0.2, face="fight")        # 振り下ろし切った形
        keysA += [dict(t=_r(hl + 0.12), dx=5.0, hz=0.9, lean=0.15),
                  dict(t=_r(hl + 0.24), dx=4.3, rz=0.3, hz=0.9, lean=-0.1, fl=0.6, fk=0.9, rl=-0.4, rk=0.6),
                  dict(t=_r(t_c0), dx=3.6, **raise_sword),
                  dict(t=_r(t_swing - 0.08), dx=3.6, **dict(raise_sword, fa=3.1, ra=2.8, lean=-0.3, hz=0.76)),   # さらに後ろへ(予備動作)
                  dict(t=_r(t_swing), dx=3.85, **swing_pose),                                                     # 2 コマで振り抜く
                  dict(t=_r(t_swing + 0.3), dx=3.85, **dict(swing_pose, lean=0.4, hz=0.8)),
                  dict(t=_r(t_hit + 0.9), dx=3.85, hz=0.88, lean=0.1, fa=0.9, fe=1.4, ra=0.7, re=1.5, ht=0.0, face="fight")]
        charge.append(dict(start=_r(t_c0), end=_r(t_swing), who="A", color=col))
        fx_proj.append(dict(start=_r(t_swing), end=_r(t_hit), x0=_r(a_root + 1.3), z0=1.35, x1=_r(b_root - 0.15), z1=1.25, r=0.3, color=col, shape="crescent"))   # 0.55 だと画面の 1/3 で A に重なった
        hits += [dict(tau=_r(hl + 0.5), hold=0.0, kind="pose"),
                 dict(tau=_r(t_swing), hold=0.0, kind="throw", by="A", pos=[_r(a_root + 1.0), 1.4]),
                 dict(tau=_r(t_hit), hold=0.1, kind="slash", by="A", pos=[_r(b_root - 0.15), 1.25]),
                 dict(tau=_r(t_hit + 0.34), hold=0.06, kind="wall", pos=[b_wall, 1.6])]
        flashes.append(_r(t_hit))
        slow.append(dict(start=_r(t_swing - 0.04), end=_r(t_hit + 0.1), rate=0.55))
        shots += [dict(t=_r(t_c0 - 0.1), follow="A", scale=[[_r(t_c0 - 0.1), 4.2], [_r(t_swing), 3.6]], yaw=[[_r(t_c0 - 0.1), -30.0], [_r(t_swing), -12.0]], pitch=6.0, lens=32.0, target_z=1.3, lag=0.25),
                  dict(t=_r(t_swing), follow="B", scale=5.2, yaw=4.0, pitch=3.0, lens=44.0, target_z=1.3),
                  dict(t=_r(t_hit + 0.95), follow="A", scale=[[_r(t_hit + 0.95), 4.6], [_r(t_hit + 2.4), 5.6]], yaw=[[_r(t_hit + 0.95), 30.0], [_r(t_hit + 2.4), -15.0]], pitch=8.0, lens=40.0, target_z=0.9)]
        puffs.append(dict(tau=_r(t_hit + 1.08), kind="land2", pos=[_r(b_wall - 0.5), 0.0]))
        t_end = t_hit + 1.1
        ko_t = t_hit + 1.05
    elif barrage:
        b_wall = round(max(6.0, 2.4 - min(float(k["dx"]) for k in keysB if "dx" in k) + 1.3, 2.4 - (dxB - 0.45) + 1.3), 2)
        wall_lock = b_wall
        b_root = 2.4 - (dxB - 0.45)
        n_r = 8
        dt_r = 0.14                                      # 0.1 だと 2 コマ撮りに飲まれて拳が見えなかった
        t_r0 = _r(hl + 0.55)                             # 連打の 1 発目
        t_big = _r(t_r0 + dt_r * n_r + 0.25)             # 最後の大振り
        a_dx_r = (b_root - 1.15) + 2.0                   # A の根元を B の 1.15 手前に(0.9 だと 2 人が重なって見えた)
        keysB += [dict(t=_r(hl + 0.1), dx=_r(dxB + 0.25), lean=-0.6, fa=0.3, ra=0.3, fe=0.6, re=0.6, ht=-0.8, face="pain"),
                  dict(t=_r(hl + 0.45), dx=_r(dxB - 0.45), lean=-0.15, hz=0.86, fa=0.7, ra=0.6, fe=1.1, re=1.2, ht=-0.2, face="pain")]
        keysA += [dict(t=_r(hl + 0.12), dx=5.0, hz=0.9, lean=0.15),
                  dict(t=_r(hl + 0.4), dx=_r(a_dx_r), hz=0.72, lean=0.3, fl=0.9, fk=0.8, rl=-0.6, rk=0.3, fa=0.4, fe=1.6, ra=0.3, re=1.6, face="fight")]   # 腰を落として構える
        for i in range(n_r):
            ti = _r(t_r0 + dt_r * i)
            front = (i % 2 == 0)
            keysA.append(dict(t=ti, dx=_r(a_dx_r + 0.05 * (i % 2)), hz=0.72, lean=0.32 + 0.04 * (i % 2),
                              fa=(1.65 if front else 0.2), fe=(0.05 if front else 1.7), ra=(0.2 if not front else 0.2) if False else (1.6 if not front else 0.1), re=(0.05 if not front else 1.7),
                              fl=0.9, fk=0.8, rl=-0.6, rk=0.3, face="fight"))
            keysB.append(dict(t=_r(ti + 0.03), dx=_r(dxB - 0.45 - 0.02 * i), lean=-0.25 - 0.03 * (i % 2), hz=0.86 - 0.01 * i, ht=-0.35 + 0.1 * (i % 2), fa=0.5, ra=0.4, fe=1.0, re=1.0, face="pain"))
            hits.append(dict(tau=ti, hold=0.0, kind="rapid", by="A", pos=[_r(b_root - 0.15), 1.25 + 0.06 * (i % 2)]))
        keysA += [dict(t=_r(t_big - 0.18), dx=_r(a_dx_r - 0.15), hz=0.66, lean=0.05, fa=-0.9, fe=1.4, ra=0.6, re=1.3, fl=0.9, fk=0.9, rl=-0.6, rk=0.3, face="fight"),   # 大きく引く(予備動作)
                  dict(t=_r(t_big), dx=_r(a_dx_r + 0.35), hz=0.84, lean=0.5, fa=1.6, fe=0.05, ra=-0.4, re=1.0, fl=1.0, fk=0.5, rl=-0.7, rk=0.2, face="fight"),         # 大振り
                  dict(t=_r(t_big + 0.3), dx=_r(a_dx_r + 0.35), hz=0.84, lean=0.4, fa=1.5, fe=0.1),
                  dict(t=_r(t_big + 0.9), dx=_r(a_dx_r + 0.35), hz=0.88, lean=0.1, fa=0.9, fe=1.4, ra=0.7, re=1.5, ht=0.0, face="fight")]
        keysB += [dict(t=_r(t_big - 0.02), dx=_r(dxB - 0.6), lean=-0.3, hz=0.8, fa=0.5, ra=0.4, fe=1.0, re=1.0, ht=-0.3, face="pain"),
                  dict(t=_r(t_big + 0.05), dx=_r(dxB - 0.7), lean=-0.7, hz=0.9, fa=-0.9, ra=-0.9, fe=0.3, re=0.3, ht=-0.8, face="pain"),
                  dict(t=_r(t_big + 0.2), dx=_r(2.4 - (b_wall - 1.4)), rz=1.3, roll=1.0, hz=0.9, fa=-1.1, ra=-0.9, fe=0.2, re=0.3, fl=0.9, fk=0.4, rl=0.2, rk=0.3, lean=-0.3, ht=-0.6, face="pain"),
                  dict(t=_r(t_big + 0.34), dx=_r(2.4 - (b_wall - 0.3)), rz=1.35, roll=0.3, hz=0.9, fa=-0.9, ra=-0.9, fe=0.3, re=0.3, fl=0.6, fk=0.3, rl=-0.3, rk=0.4, lean=-0.35, ht=-0.7, face="pain"),
                  dict(t=_r(t_big + 0.55), dx=_r(2.4 - (b_wall - 0.3)), rz=1.25, roll=0.35, hz=0.9, lean=-0.3, face="pain"),
                  dict(t=_r(t_big + 0.85), dx=_r(2.4 - (b_wall - 0.45)), rz=0.55, roll=1.2, hz=0.9, lean=0.0, fa=0.2, ra=0.2, face="pain"),
                  dict(t=_r(t_big + 1.05), dx=_r(2.4 - (b_wall - 0.5)), rz=0.21, roll=1.57, hz=0.9, fa=0.4, ra=0.4, fl=0.0, fk=0.0, rl=0.0, rk=0.0, face="ko")]
        hits += [dict(tau=_r(t_big), hold=0.1, kind="heel", by="A", pos=[_r(b_root - 0.1), 1.3]),   # 大振り(重い音・大きな放射線は heel を借りる)
                 dict(tau=_r(t_big + 0.34), hold=0.06, kind="wall", pos=[b_wall, 1.6])]
        flashes.append(_r(t_big))
        slow.append(dict(start=_r(t_big - 0.05), end=_r(t_big + 0.2), rate=0.5))
        shots += [dict(t=_r(hl + 0.35), follow="mid", scale=3.8, yaw=14.0, pitch=4.0, lens=34.0, target_z=1.2, lag=0.2),   # 連打は少し寄って
                  dict(t=_r(t_big - 0.2), follow="mid", scale=5.2, yaw=4.0, pitch=3.0, lens=44.0, target_z=1.3),
                  dict(t=_r(t_big + 0.95), follow="A", scale=[[_r(t_big + 0.95), 4.6], [_r(t_big + 2.4), 5.6]], yaw=[[_r(t_big + 0.95), 30.0], [_r(t_big + 2.4), -15.0]], pitch=8.0, lens=40.0, target_z=0.9)]
        puffs.append(dict(tau=_r(t_big + 1.08), kind="land2", pos=[_r(b_wall - 0.5), 0.0]))
        t_end = t_big + 1.1
        ko_t = t_big + 1.05
    elif bclash:
        b_wall = round(max(6.0, 2.4 - min(float(k["dx"]) for k in keysB if "dx" in k) + 1.3, 2.4 - (dxB - 1.2) + 1.3), 2)
        wall_lock = b_wall
        t_c0, t_fire = _r(hl + 0.6), _r(hl + 1.8)        # 2 人とも構えて 1.2 秒溜める(下がるのに 0.6 秒。0.4 だと 1 コマ 0.93 飛んだ)
        t_win = _r(t_fire + 1.3)                         # 押し勝つ(B の光線が折れる)
        col_a = list(s.get("beam_color") or [120, 230, 255])
        col_b = list(s.get("beam_color_b") or [255, 110, 90])
        a_root, b_root = -2.0 + 3.3, 2.4 - (dxB - 1.2)   # A は 3.3 まで下がり、B は 1.2 下がって構える(撃ち合いの長さ)
        x_mid = (a_root + b_root) / 2
        charge_pose = dict(hz=0.74, lean=0.12, fa=-0.3, fe=2.3, ra=-0.25, re=2.3, ht=0.05, fl=0.55, fk=0.5, rl=-0.5, rk=0.35, face="fight")
        fire_pose = dict(hz=0.82, lean=0.38, fa=1.6, fe=0.05, ra=1.55, re=0.08, ht=-0.05, fl=0.9, fk=0.45, rl=-0.55, rk=0.2, face="fight")
        keysA += [dict(t=_r(hl + 0.12), dx=5.0, hz=0.9, lean=0.15),
                  dict(t=_r(hl + 0.36), dx=4.2, rz=0.35, hz=0.9, lean=-0.1, fl=0.6, fk=0.9, rl=-0.4, rk=0.6),
                  dict(t=_r(t_c0), dx=3.3, **charge_pose),
                  dict(t=_r(t_fire - 0.07), dx=3.3, **dict(charge_pose, hz=0.70, lean=0.05)),
                  dict(t=_r(t_fire), dx=3.5, **fire_pose),
                  dict(t=_r(t_fire + 0.12), dx=3.3, **dict(fire_pose, lean=0.3, hz=0.78)),
                  dict(t=_r(t_fire + 0.7), dx=3.1, **dict(fire_pose, lean=0.2, hz=0.72)),                    # 押されて少し下がる
                  dict(t=_r(t_win - 0.15), dx=3.0, **dict(fire_pose, lean=0.15, hz=0.66)),                   # 踏ん張る(沈む)
                  dict(t=_r(t_win), dx=3.4, **dict(fire_pose, lean=0.45, hz=0.84)),                          # 一歩踏み込んで押し勝つ
                  dict(t=_r(t_win + 0.6), dx=3.4, **dict(fire_pose, lean=0.3, hz=0.84)),
                  dict(t=_r(t_win + 1.0), dx=3.4, hz=0.88, lean=0.1, fa=0.9, fe=1.4, ra=0.7, re=1.5, ht=0.0, face="fight")]
        keysB += [dict(t=_r(hl + 0.1), dx=_r(dxB + 0.25), lean=-0.6, fa=0.3, ra=0.3, fe=0.6, re=0.6, ht=-0.8, face="pain"),
                  dict(t=_r(hl + 0.3), dx=_r(dxB - 0.3), rz=0.25, hz=0.9, lean=-0.1, fl=0.6, fk=0.9, rl=-0.4, rk=0.6, face="fight"),   # B も跳んで下がる
                  dict(t=_r(t_c0), dx=_r(dxB - 1.2), **charge_pose),
                  dict(t=_r(t_fire - 0.07), dx=_r(dxB - 1.2), **dict(charge_pose, hz=0.70, lean=0.05)),
                  dict(t=_r(t_fire), dx=_r(dxB - 1.0), **fire_pose),
                  dict(t=_r(t_fire + 0.12), dx=_r(dxB - 1.2), **dict(fire_pose, lean=0.3, hz=0.78)),
                  dict(t=_r(t_win - 0.1), dx=_r(dxB - 1.35), **dict(fire_pose, lean=0.1, hz=0.7)),           # 押し負けて下がる
                  dict(t=_r(t_win + 0.06), dx=_r(dxB - 1.45), lean=-0.7, hz=0.9, fa=-0.9, ra=-0.9, fe=0.3, re=0.3, ht=-0.8, face="pain"),   # 光線が折れて受ける
                  dict(t=_r(t_win + 0.22), dx=_r(2.4 - (b_wall - 1.4)), rz=1.3, roll=1.0, hz=0.9, fa=-1.1, ra=-0.9, fe=0.2, re=0.3, fl=0.9, fk=0.4, rl=0.2, rk=0.3, lean=-0.3, ht=-0.6, face="pain"),
                  dict(t=_r(t_win + 0.36), dx=_r(2.4 - (b_wall - 0.3)), rz=1.35, roll=0.3, hz=0.9, fa=-0.9, ra=-0.9, fe=0.3, re=0.3, fl=0.6, fk=0.3, rl=-0.3, rk=0.4, lean=-0.35, ht=-0.7, face="pain"),
                  dict(t=_r(t_win + 0.57), dx=_r(2.4 - (b_wall - 0.3)), rz=1.25, roll=0.35, hz=0.9, lean=-0.3, face="pain"),
                  dict(t=_r(t_win + 0.87), dx=_r(2.4 - (b_wall - 0.45)), rz=0.55, roll=1.2, hz=0.9, lean=0.0, fa=0.2, ra=0.2, face="pain"),
                  dict(t=_r(t_win + 1.07), dx=_r(2.4 - (b_wall - 0.5)), rz=0.21, roll=1.57, hz=0.9, fa=0.4, ra=0.4, fl=0.0, fk=0.0, rl=0.0, rk=0.0, face="ko")]
        charge += [dict(start=_r(t_c0), end=_r(t_fire), who="A", color=col_a), dict(start=_r(t_c0), end=_r(t_fire), who="B", color=col_b)]
        meet = [[_r(t_fire), x_mid + 0.2], [_r(t_fire + 0.5), x_mid - 0.2], [_r(t_fire + 0.9), x_mid - 0.05], [_r(t_win - 0.1), x_mid + 0.9], [_r(t_win), b_root - 0.3]]   # ぶつかる点: 初めは A が押され(0.4 だけ。0.5 以上だと A の光線が手元だけになる)、踏ん張って押し返す
        fx_beams += [dict(start=_r(t_fire), end=_r(t_win + 0.8), who="A", color=col_a, x_end=meet + [[_r(t_win + 0.02), b_wall + 1.2]]),
                     dict(start=_r(t_fire), end=_r(t_win), who="B", color=col_b, x_end=meet),
                     ]
        hits += [dict(tau=_r(hl + 0.5), hold=0.0, kind="pose"),
                 dict(tau=_r(t_fire), hold=0.08, kind="beam", by="A", pos=[_r(x_mid), 1.3]),
                 dict(tau=_r(t_fire + 0.9), hold=0.0, kind="pose"),
                 dict(tau=_r(t_win), hold=0.08, kind="beam", by="A", pos=[_r(b_root - 0.3), 1.3]),
                 dict(tau=_r(t_win + 0.36), hold=0.06, kind="wall", pos=[b_wall, 1.6])]
        fx_clash_ball = dict(start=_r(t_fire), end=_r(t_win), path=meet, color=[255, 255, 255], r=0.5)
        fx_orbs.append(dict(start=_r(t_fire), end=_r(t_win), who="A", r0=0.26, r1=0.38, color=[255, 255, 255], path=meet))   # ぶつかる点の白い玉(手でなく path の位置。0.5〜0.7 だと人物より大きかった)
        flashes += [_r(t_fire), _r(t_win)]
        slow += [dict(start=_r(t_fire - 0.05), end=_r(t_fire + 0.2), rate=0.55), dict(start=_r(t_win - 0.05), end=_r(t_win + 0.25), rate=0.5)]
        shots += [dict(t=_r(t_c0 - 0.1), follow="mid", scale=[[_r(t_c0 - 0.1), 5.0], [_r(t_fire), 4.6]], yaw=[[_r(t_c0 - 0.1), 10.0], [_r(t_fire), 4.0]], pitch=5.0, lens=40.0, target_z=1.1),   # 2 人の溜めを横から(6.0 だと人物が 1/4)
                  dict(t=_r(t_fire), follow="mid", scale=5.4, yaw=4.0, pitch=3.0, lens=44.0, target_z=1.3),
                  dict(t=_r(t_fire + 0.6), follow="A", scale=4.2, yaw=-20.0, pitch=4.0, lens=32.0, target_z=1.1, lag=0.2),   # 踏ん張る A に寄る(ぶつかる点も入る程度)
                  dict(t=_r(t_win - 0.1), follow="mid", scale=5.4, yaw=4.0, pitch=3.0, lens=44.0, target_z=1.3),
                  dict(t=_r(t_win + 0.95), follow="A", scale=[[_r(t_win + 0.95), 4.6], [_r(t_win + 2.4), 5.6]], yaw=[[_r(t_win + 0.95), 30.0], [_r(t_win + 2.4), -15.0]], pitch=8.0, lens=40.0, target_z=0.9)]
        puffs.append(dict(tau=_r(t_win + 1.1), kind="land2", pos=[_r(b_wall - 0.5), 0.0]))
        t_end = t_win + 1.15
        ko_t = t_win + 1.07
    elif wave:
        b_root = 2.4 - (dxB - 0.45)
        a_root = -2.0 + 4.0
        t_jump, t_slam = _r(hl + 0.45), _r(hl + 0.95)    # 跳ぶ → 0.5 秒で落ちて叩きつけ
        t_hit = _r(t_slam + 0.28)                        # 波が B に届く
        col = list(s.get("beam_color") or [255, 220, 120])
        keysB += [dict(t=_r(hl + 0.1), dx=_r(dxB + 0.25), lean=-0.6, fa=0.3, ra=0.3, fe=0.6, re=0.6, ht=-0.8, face="pain"),
                  dict(t=_r(hl + 0.5), dx=_r(dxB - 0.45), lean=-0.25, hz=0.84, fa=0.6, ra=0.5, fe=1.0, re=1.1, ht=-0.3, face="pain"),
                  dict(t=_r(t_hit - 0.04), dx=_r(dxB - 0.45), lean=-0.2, hz=0.85, fa=0.8, ra=0.6, fe=1.2, re=1.2, ht=-0.1, face="pain"),
                  dict(t=_r(t_hit + 0.06), dx=_r(dxB - 0.5), rz=0.5, roll=0.2, hz=0.9, lean=-0.5, fa=-0.9, ra=-0.9, fe=0.3, re=0.3, fl=0.7, fk=0.8, rl=0.3, rk=0.6, ht=-0.7, face="pain"),   # 下から突き上げられる
                  dict(t=_r(t_hit + 0.32), dx=_r(dxB - 0.7), rz=2.2, roll=1.1, hz=0.9, lean=-0.3, fa=-1.0, ra=-0.8, fe=0.2, re=0.3, fl=0.9, fk=0.3, rl=0.1, rk=0.3, ht=-0.6, face="pain"),   # 打ち上がる(頂点)
                  dict(t=_r(t_hit + 0.48), dx=_r(dxB - 0.85), rz=1.9, roll=1.4, hz=0.9, face="pain"),
                  dict(t=_r(t_hit + 0.78), dx=_r(dxB - 1.0), rz=0.55, roll=1.57, hz=0.9, lean=0.0, fa=0.0, ra=0.0, face="pain"),   # 落ちる
                  dict(t=_r(t_hit + 0.88), dx=_r(dxB - 1.0), rz=0.21, roll=1.57, hz=0.9, fa=0.4, ra=0.4, fl=0.0, fk=0.0, rl=0.0, rk=0.0, face="ko"),
                  dict(t=_r(t_hit + 0.98), dx=_r(dxB - 1.0), rz=0.3, roll=1.57, hz=0.9, face="ko"),                                   # 床で跳ねる
                  dict(t=_r(t_hit + 1.1), dx=_r(dxB - 1.0), rz=0.21, roll=1.57, hz=0.9, face="ko")]
        keysA += [dict(t=_r(hl + 0.12), dx=5.0, hz=0.9, lean=0.15),
                  dict(t=_r(hl + 0.3), dx=4.3, hz=0.66, lean=0.3, fa=-0.4, fe=1.2, ra=-0.4, re=1.2, fl=0.9, fk=1.6, rl=-0.4, rk=1.2),   # 沈んで(予備動作)
                  dict(t=_r(t_jump), dx=4.1, rz=1.25, hz=0.95, lean=-0.1, fa=2.7, fe=0.4, ra=2.4, re=0.5, fl=0.5, fk=1.2, rl=-0.3, rk=0.9),   # 跳び上がって拳を振り上げる(1.6 だと画面の上に切れた)
                  dict(t=_r(t_slam - 0.1), dx=4.05, rz=0.9, hz=0.95, lean=0.25, fa=2.9, fe=0.3, ra=2.5, re=0.4, fl=0.6, fk=1.0, rl=-0.4, rk=0.8),   # 落ちながらさらに振りかぶる
                  dict(t=_r(t_slam), dx=4.0, rz=0.0, hz=0.5, lean=0.55, fa=-1.1, fe=0.2, ra=-0.9, re=0.3, fl=1.1, fk=2.0, rl=-0.2, rk=1.6, ht=0.1),   # 拳を地面に叩きつける(つぶれ)
                  dict(t=_r(t_slam + 0.3), dx=4.0, hz=0.52, lean=0.5, fa=-1.0, fe=0.2, ra=-0.8, re=0.4),
                  dict(t=_r(t_hit + 0.9), dx=4.0, hz=0.88, lean=0.1, fa=0.9, fe=1.4, ra=0.7, re=1.5, ht=0.0, face="fight")]
        fx_waves.append(dict(start=_r(t_slam), end=_r(t_hit + 0.1), x0=_r(a_root + 0.55), x1=_r(b_root + 0.3), color=col))
        hits += [dict(tau=_r(hl + 0.5), hold=0.0, kind="pose"),
                 dict(tau=_r(t_slam), hold=0.08, kind="slam", by="A", pos=[_r(a_root + 0.55), 0.05]),
                 dict(tau=_r(t_hit), hold=0.08, kind="wave", by="A", pos=[_r(b_root - 0.1), 0.6]),
                 dict(tau=_r(t_hit + 0.88), hold=0.06, kind="land2", pos=[_r(2.4 - (dxB - 1.0)), 0.0])]
        flashes.append(_r(t_slam))
        slow.append(dict(start=_r(t_hit - 0.03), end=_r(t_hit + 0.3), rate=0.5))
        shots += [dict(t=_r(hl + 0.3), follow="A", scale=[[_r(hl + 0.3), 4.8], [_r(t_slam), 4.4]], yaw=[[_r(hl + 0.3), -28.0], [_r(t_slam), -14.0]], pitch=10.0, lens=34.0, target_z=1.5, lag=0.2),   # 跳ぶので高めを狙って少し引く
                  dict(t=_r(t_slam + 0.03), follow="mid", scale=5.4, yaw=6.0, pitch=14.0, lens=40.0, target_z=0.8),
                  dict(t=_r(t_hit + 0.9), follow="A", scale=[[_r(t_hit + 0.9), 4.6], [_r(t_hit + 2.4), 5.6]], yaw=[[_r(t_hit + 0.9), 30.0], [_r(t_hit + 2.4), -15.0]], pitch=8.0, lens=40.0, target_z=0.9)]
        t_end = t_hit + 1.15
        ko_t = t_hit + 0.88
    else:
        keysB += [dict(t=_r(hl + 0.1), dx=_r(dxB + 0.25), lean=-0.6, fa=0.3, ra=0.3, fe=0.6, re=0.6, ht=-0.8, face="pain"),
                  dict(t=_r(hl + 0.45), dx=-2.9, rz=0.5, roll=1.2, hz=0.9, lean=-0.2, fl=0.0, fk=0.0, rl=0.0, rk=0.0, face="pain"),
                  dict(t=_r(hl + 0.8), dx=-3.0, rz=0.21, roll=1.57, hz=0.9, fa=0.3, ra=0.3, face="ko")]
        keysA.append(dict(t=_r(hl + 1.0), dx=5.4, hz=0.9, lean=0.1))
        puffs.append(dict(tau=_r(hl + 0.85), kind="land2", pos=[5.4, 0.0]))
        t_end = hl + 1.1
        ko_t = hl + 0.8
    if beam or blast or wave or bclash or barrage or swave or iai or sthrow or blink or meteor:   # 技の位置は台本どおり: 位置合わせの平行移動(接触で決めた clip の終点と台本の差)を受けない(連打乱舞で A が 1.55・B が 1.05 ずれて重なり、飛ぶ斬撃では三日月が A の後ろから出た)
        for k in keysA + keysB:
            if k["t"] >= hl + 0.3 - 1e-6 and "dx" in k:   # 0.3 秒後から。それまでのキーは plan が平行移動を線形に 0 へ戻す
                k["abs"] = True
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
    keysB.append(dict(t=end, dx=keysB[-1].get("dx", -3.0), rz=(0.32 if sthrow else 0.21), roll=(-1.57 if sthrow else 1.57), hz=0.9, face="ko"))   # 投げは仰向け(−1.57)のまま
    flurry.append(dict(start=_r(ko_t + 0.4), end=_r(ko_t + 0.8), every=5, angles=HERO))
    if fin:                                              # 打ち上げ〜空中斬りの間は、2 人の高さの中ほどを狙って少し引く(高く上げたので上に切れないように)
        shots.append(dict(t=_r(hl + 0.18), follow="mid", scale=5.2, yaw=[[_r(hl + 0.18), 40.0], [_r(hl + 0.9 + ex), 30.0]], pitch=6.0, lens=40.0, target_z=1.6))
    if not beam and not blast and not wave and not bclash and not barrage and not swave and not iai and not sthrow and not blink and not meteor:
        shots.append(dict(t=_r(hl + 0.95 + ex if fin else hl), follow="mid", scale=[[_r(hl), 4.4], [_r(ko_t + 0.3), 5.6], [end, 7.5]], yaw=[[_r(hl), 52.0], [end, -15.0]], pitch=[[_r(hl), 10.0], [end, 22.0]], lens=40.0, target_z=0.9))   # 決め技の間は寄ったまま(5.0→9.0 だと叩きつけで 0.3 まで小さくなった)、倒してから引く

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
    b_far = max(2.4 - float(k["dx"]) for k in keysB if "dx" in k)              # B が最も下がる根元の位置(B は base 2.4 で左向き)
    wall_x = wall_lock if wall_lock else (6.0 if kick else round(max(6.0, b_far + 1.3), 2))
    for pj in fx_proj:                                   # 壁へ向かう玉は壁の位置で止める
        if pj.get("to_wall"):
            pj["x1"] = wall_x
    for h in hits:
        if h.get("to_wall"):
            h["pos"][0] = wall_x   # 壁は B より奥に(素手の連打で B が 6.5 まで押され、壁の向こうに立っていた)。飛び蹴りの壁は 6.0 固定、beam は飛ばす前に決めた位置
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
        stage=dict(wall_x=wall_x, style="flat", theme=s["stage"]), slow=slow, hits=hits, puffs=puffs,
        camera=[[0.0, -0.4, 8.4], [_r(end), 3.2, 8.6]],
        keys=keys,
        fx=dict(trails=trails_ranges, glide=glide_ranges, speed_lines=speed, invert=invert, flashes=sorted(set(flashes)), charge=charge, color_script=color_script, weapon_glow=bool(sword), beams=fx_beams, orbs=fx_orbs, projectiles=fx_proj, waves=fx_waves, afterimages=fx_after, cuts=fx_cuts),
        clips=dict(A=clipsA, **({"B": clipsB} if clipsB else {})),
        snaps=snaps,
        qa=dict(max_cross_frames=400, max_stops=3, max_anticipation_frames=14, max_jerk=(9.0 if (open_tp or iai or blink) else 1.3), **({"max_teleport_frames": (6 if blink else 2)} if (open_tp or iai or blink) else {})),   # 瞬間移動は 1 コマで飛ぶのが意図
        tempo=s["tempo"], anime=dict(trails=True, sfx=True, zoom_blur=True, grade=True, roll=True, smear=True),
        shots=shots, stepping=stepping,
        impact_cuts=impact_cuts,
        flurry=flurry, body_drive=({"strength": float(s["body"])} if s["body"] else None), footwork=({} if s["footwork"] else None), style="flat2d",
        clip_timing=({"pre": 0.4, "post": 0.3} if s["timing"] else None),
        cam_zoom=float(s["cam_zoom"]),
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

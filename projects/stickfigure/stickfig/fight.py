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
from typing import Dict, List

DEFAULTS = dict(
    weapon="sword",          # sword / none(素手)
    kick=True,               # 冒頭の蹴り → 壁
    hits=3,                  # 連打の回数(1〜4)
    counter=True,            # 1発目のあと、相手の反撃
    finisher="launch_slash", # launch_slash / none
    palette="warm",          # warm / cool
    colors=dict(A=[0.3, 0.68, 0.1], B=[0.8, 0.1, 0.08]),
    tempo=1.35,
    stage="cave",            # 舞台の色の組: cave / dojo / field / night / sunset
    mood="battle",           # BGM の雰囲気: battle / tense / calm / sad / none
    lines=[],                # 台詞・ナレーション: [{at: opening|kick|rise|combo|counter|last|finisher|ko|end, dt: 0, dur: 1.6, kind: say|narr|shout, who: A, text: "…"}]
)

PALETTES = {
    "warm": [(150, 175, 235, .55), (170, 190, 230, .45), (255, 170, 110, .6), (255, 190, 130, .5), (140, 170, 235, .5),
             (90, 130, 220, .65), (255, 200, 150, .55), (255, 150, 110, .6), (200, 170, 230, .5), (190, 160, 220, .55)],
    "cool": [(150, 200, 255, .55), (140, 190, 255, .5), (120, 200, 255, .55), (160, 210, 255, .5), (130, 170, 240, .5),
             (90, 130, 220, .65), (170, 210, 255, .5), (140, 190, 255, .55), (190, 180, 240, .5), (190, 170, 235, .55)],
}

GUARD = dict(lean=0.1, fa=0.9, fe=1.4, ra=0.7, re=1.5, ht=0.0, face="fight")
A_FACE = dict(target="A", z=1.5, yaw=12, pitch=2, scale=1.5, lens=40, hue=0)
B_FACE = dict(target="B", z=1.5, yaw=-14, pitch=3, scale=1.5, lens=40, hue=1)
A_HAND = dict(target="A", z=1.1, ox=0.5, yaw=30, pitch=-6, scale=1.2, lens=24, hue=3, dutch=7.0)
A_FOOT = dict(target="A", z=0.5, ox=0.3, yaw=35, pitch=4, scale=1.6, lens=22, hue=0, dutch=-6.0)
HERO = [dict(target="A", z=1.35, yaw=18, pitch=-6, scale=3.3, lens=24, streak=False, dutch=-4.0),
        dict(target="A", z=1.35, yaw=-25, pitch=-5, scale=3.3, lens=26, streak=False)]
# 連打に使う clip(モーションキャプチャ)。命中時に相手との間隔が合うものを、周8で選んだ
HIT_CLIPS = ["02_08_s1", "02_09_s1", "02_07_s2", "02_07_s1"]
COUNTER_CLIP = "13_17_s1"


def _r(x: float) -> float:
    return round(x, 3)


def build_fight(spec: dict) -> dict:
    s = copy.deepcopy(DEFAULTS)
    s.update({k: v for k, v in (spec or {}).items() if k in DEFAULTS})
    sword = s["weapon"] == "sword"
    n = max(1, min(4, int(s["hits"])))
    kick = bool(s["kick"])
    fin = s["finisher"] == "launch_slash"
    o = 0.0 if kick else -2.4          # 蹴りが無いぶん、連打の開始が早まる
    tc = 4.0 + o                       # 連打の準備(起き上がり)の終わり

    keysA: List[dict] = [dict(t=0.0, dx=0.2, hz=0.84), dict(t=0.6, dx=0.2, lean=0.12, hz=0.83)]
    keysB: List[dict] = [dict(t=0.0)]
    clipsA: List[dict] = [dict(file="09_01", start=0.6, end=1.55, loop=True, anchor_dx=0.2, **{"in": 0.12, "out": 0.2})]
    clipsB: List[dict] = []
    hits: List[dict] = []
    puffs: List[dict] = []
    slow: List[dict] = []
    flurry: List[dict] = []
    charge: List[dict] = []
    flashes: List[float] = []
    speed: List[list] = [[0.5, 1.3]]
    shots: List[dict] = []

    # ---- 冒頭 ----
    shots.append(dict(t=0.0, follow="mid", scale=[[0.0, 8.8], [1.0, 7.6]], yaw=[[0.0, 12.0], [1.0, 22.0]], pitch=9.0, lens=40.0))
    keysB.append(dict(t=1.0, dx=0.35))
    if kick:
        charge.append(dict(start=1.3, end=1.7, who="A", color=[255, 170, 60]))
        flurry.append(dict(start=1.12, end=1.64, every=4, angles=[A_FACE, B_FACE, A_FOOT, A_FACE]))
        hits += [dict(tau=1.66, hold=0.13, kind="pose"),
                 dict(tau=1.9, hold=0.09, kind="kick", contact=dict(striker="A", effector="foot", target=dict(actor="B", point="hip"), tol=0.2)),
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
        clipsA.append(dict(file="09_01", start=3.2, end=4.0, loop=True, anchor_dx=3.4, **{"in": 0.15, "out": 0.2}))
        speed.append([3.3, 4.1])
        a_dx0 = 3.4
    else:
        keysB += [dict(t=tc, dx=-1.7, rz=0.0, roll=0.0, hz=0.82, lean=0.1, fa=0.9, fe=1.4, ra=0.7, re=1.5, fl=0.45, fk=0.3, rl=-0.45, rk=0.4, face="fight")]
        clipsA[0].update(end=tc)
        keysA.append(dict(t=tc, dx=3.4, hz=0.9))
        shots.append(dict(t=1.0, follow="A", scale=[[1.0, 5.6], [tc + 0.4, 4.4]], yaw=[[1.0, -38.0], [tc + 0.4, -20.0]], pitch=4.0, lens=30.0, target_z=1.0, lag=0.3))
        speed.append([tc - 0.7, tc + 0.1])
        a_dx0 = 3.4

    # ---- 連打 ----
    charge.append(dict(start=tc - 0.05, end=tc + 0.3, who="A", color=[120, 230, 255]))
    hits.append(dict(tau=_r(tc + 0.3), hold=0.11, kind="pose"))
    flurry.append(dict(start=_r(tc - 0.1), end=_r(tc + 0.3), every=4, angles=[B_FACE, A_FACE, A_HAND]))
    kind_hit = "slash" if sword else "hit"
    eff = "tip" if sword else "hand"
    h0 = tc + 0.4
    gaps = [0.58, 0.42, 0.4, 0.4] if s["counter"] else [0.4, 0.4, 0.4, 0.4]
    ts = [h0]
    for i in range(1, n):
        ts.append(ts[-1] + gaps[i - 1])
    keysA.append(dict(t=_r(h0 - 0.2), dx=4.6, hz=0.9))
    dxB = -1.7
    for i, t in enumerate(ts):
        last = i == n - 1
        pre, post = (0.4, 0.18) if i == 0 else (0.16, 0.22)
        anchor = 4.3 if i == 0 else 4.3 + 0.5 * i
        clip = dict(file=HIT_CLIPS[i % len(HIT_CLIPS)], strike_at=_r(t), start=_r(t - pre), end=_r(t + post), **{"in": 0.12 if i == 0 else 0.08, "out": 0.25 if last else 0.08})
        if not last:
            clip["anchor_dx"] = round(anchor, 2)
        clipsA.append(clip)
        if last:
            hits.append(dict(tau=_r(t), hold=0.08, kind=kind_hit, contact=dict(striker="A", effector=eff, target=dict(actor="B", point="chest"), tol=0.3, max_anticipation=50)))
        else:
            hits.append(dict(tau=_r(t), hold=0.05, kind=kind_hit, pos=[_r(3.7 - 0.2 * i), _r(1.25 - 0.1 * i)]))
        flashes.append(_r(t))
        dxB -= 0.25
        if not last:
            keysB += [dict(t=_r(t + 0.07), dx=_r(dxB), lean=-0.3 - 0.07 * i, fa=0.4, ra=0.4, ht=-0.4 - 0.1 * i, face="pain"),
                      dict(t=_r(t + 0.2), dx=_r(dxB), **GUARD)]
        if i == 0 and s["counter"] and n > 1:
            tcn = t + 0.28
            clipsB.append(dict(file=COUNTER_CLIP, strike_at=_r(tcn), start=_r(tcn - 0.2), end=_r(tcn + 0.27), **{"in": 0.06, "out": 0.1}))
            hits.append(dict(tau=_r(tcn), hold=0.05, kind="hit", contact=dict(striker="B", effector="hand", target=dict(actor="A", point="chest"), tol=0.3, max_anticipation=50)))
            keysA += [dict(t=_r(tcn + 0.07), dx=4.45, lean=-0.2, hz=0.9), dict(t=_r(tcn + 0.27), dx=4.6, lean=0.15, hz=0.9)]
            flashes.append(_r(tcn))
    hl = ts[-1]
    speed.append([_r(h0), _r(hl + 0.5)])
    shots.append(dict(t=_r(h0), follow="mid", scale=[[_r(h0), 3.6], [_r(hl), 4.2]], yaw=[[_r(h0), 30.0], [_r(hl), 52.0]],
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
        hits += [dict(tau=_r(hl + 0.55), hold=0.1, kind="slash" if sword else "hit", pos=[4.9, 1.9]), dict(tau=_r(hl + 0.95), hold=0.1, kind="heel", pos=[5.6, 0.0])]
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
    keysA.append(dict(t=end, dx=keysA[-1]["dx"], hz=0.9, face="win"))
    keysB.append(dict(t=end, dx=keysB[-1].get("dx", -3.0), rz=0.21, roll=1.57, hz=0.9, face="ko"))
    flurry.append(dict(start=_r(ko_t + 0.4), end=_r(ko_t + 0.8), every=5, angles=HERO))
    shots.append(dict(t=_r(hl + 0.0), follow="mid", scale=[[_r(hl), 5.0], [end, 9.0]], yaw=[[_r(hl), 52.0], [end, -15.0]], pitch=[[_r(hl), 10.0], [end, 22.0]], lens=40.0, target_z=0.9))

    # ---- 色・リズム ----
    pal = PALETTES.get(s["palette"], PALETTES["warm"])
    marks = [0.0, 1.2, 1.9, 2.6, tc - 0.6, tc - 0.05, tc + 0.4, hl, hl + 0.8, end] if kick else \
            [0.0, 1.0, tc - 0.8, tc - 0.3, tc - 0.05, tc + 0.1, tc + 0.4, hl, hl + 0.8, end]
    color_script = [[_r(t), [c[0], c[1], c[2]], c[3]] for t, c in zip(marks, pal)]
    stepping = dict(hold=2, ones_around_hits=4, hold_camera=True,
                    ranges=[[0.0, 1.1, 2], [_r(tc - 0.9), _r(tc), 2], [_r(h0 + 0.5), _r(h0 + 1.1), 2], [_r(ko_t + 0.3), _r(end), 2]])
    actors = dict(A=dict(color=s["colors"]["A"], scale=1.0, base_x=-2.0, facing=1), B=dict(color=s["colors"]["B"], scale=1.0, base_x=2.4, facing=-1))
    if sword:
        actors["A"]["weapon"] = "sword"
    marks = dict(opening=0.3, kick=1.9, rise=tc, combo=h0, last=hl, finisher=hl + 0.55, ko=ko_t, end=end - 1.2)
    marks["counter"] = ts[0] + 0.28
    caps = []
    for ln in s["lines"]:
        t0 = marks[ln.get("at", "opening")] + float(ln.get("dt", 0.0))
        c = dict(kind=ln.get("kind", "say"), text=ln["text"], t0=_r(t0), t1=_r(t0 + float(ln.get("dur", 1.6))))
        for k in ("who", "color", "size", "y", "max_w"):
            if k in ln:
                c[k] = ln[k]
        caps.append(c)
    scene = dict(
        name=spec.get("name", "fight") if isinstance(spec, dict) else "fight", fps=30, tau_end=end, actors=actors,
        stage=dict(wall_x=6.0, style="cave", theme=s["stage"]), slow=slow, hits=hits, puffs=puffs,
        camera=[[0.0, -0.4, 8.4], [_r(end), 3.2, 8.6]],
        keys=dict(A=sorted(keysA, key=lambda k: k["t"]), B=sorted(keysB, key=lambda k: k["t"])),
        fx=dict(trails=[], speed_lines=speed, invert=["kick", "heel", "wall"], flashes=sorted(set(flashes)), charge=charge, color_script=color_script),
        clips=dict(A=clipsA, **({"B": clipsB} if clipsB else {})),
        qa=dict(max_cross_frames=400, max_stops=3, max_anticipation_frames=14, max_jerk=1.3),
        tempo=s["tempo"], anime=dict(trails=True, sfx=True, zoom_blur=True, grade=True, roll=True, smear=True),
        shots=shots, stepping=stepping,
        impact_cuts=dict(kinds=["kick", "heel", "wall"], hold=0.2, angles=[dict(yaw=35, pitch=4, scale=3.0, lens=28, hue=0), dict(yaw=-40, pitch=-6, scale=2.6, lens=26, dutch=6.0, hue=1),
                                                                         dict(yaw=5, pitch=12, scale=3.4, lens=34, hue=2)],
                         per_kind=dict(wall=[dict(yaw=-30, pitch=6, scale=5.0, lens=30), dict(yaw=10, pitch=18, scale=6.0, lens=34), dict(yaw=-55, pitch=3, scale=4.2, lens=28, dutch=-5.0)])),
        flurry=flurry, style="flat2d", captions=caps, audio=(False if s["mood"] == "none" else dict(mood=s["mood"])), _marks={k: _r(v) for k, v in marks.items()})
    return scene


def expand(data: dict) -> dict:
    """台本の dict に fight: があれば、自動で組んだ台本を土台にして、ほかのキーで上書きする。"""
    if "fight" not in data:
        return data
    spec = dict(data["fight"] or {})
    spec.setdefault("name", data.get("name", "fight"))
    base = build_fight(spec)
    over = {k: v for k, v in data.items() if k != "fight"}
    base.update(over)
    return base

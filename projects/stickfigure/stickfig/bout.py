"""手付けの戦い(keyshot)の共通部品。2026-10-21「勝ち抜き戦の 1 分の動画」で、1 試合ずつ手で付けるのに使い回す。

- 構えの型(STYLES)と stylize: 台本は構えを共通の値(腰 0.80・前傾 0.12・顎 0.0・構えの腕 GUARD_F/R)で書き、人ごとの型に置き換える
- 体の点(顎・顔・胸・腹・背中): 当たる位置は相手の焼いた体から取る(fight01 と同じ決まり)
- new_scene: 背景と 2 人(色・大きさ)を置いた空の場面。finish: 焼いた keys・当たり・カットを入れて仕上げる
見本: tools/shots/fight01.py(境内の一戦・決め手は掌底)、bout_r1.py(第 1 回戦)、bout_sf.py(準決勝)
"""
from __future__ import annotations

from typing import Dict, List, Optional

from . import fk, keyshot as ks

FPS = 30
GUARD_F, GUARD_R = (1.15, 1.7), (0.75, 2.3)      # 台本で書く「構えの腕」(stylize で型ごとに置き換える)
RELAX_F, RELAX_R = (0.35, 0.6), (0.25, 0.7)

# 構えの型(2026-10-21「構えとかをもっとかっこよく」)。hz_drop: 構えの腰を下げる量、lean: 前傾、ht: 顎、guard_f/r: 前/後ろの腕(肩, 肘)
STYLES = dict(
    kenpo=dict(hz_drop=0.08, lean=0.22, ht=-0.12, guard_f=(1.75, 0.35), guard_r=(-0.30, 2.20)),     # 緑: 拳法。腰を落とした半身、前の手を相手へまっすぐ、後ろの拳は腰の脇
    brawler=dict(hz_drop=0.06, lean=0.38, ht=-0.20, guard_f=(1.05, 2.35), guard_r=(0.65, 2.60)),   # 赤: 喧嘩屋。背を丸めた前のめり、両拳を顔の前に高く
    kicker=dict(hz_drop=0.02, lean=0.04, ht=-0.06, guard_f=(1.45, 1.10), guard_r=(0.55, 2.45)),     # 青: 蹴り使い。腰が高く体を立てる、前の手は低く前へ、後ろの拳は顎
    giant=dict(hz_drop=0.04, lean=0.26, ht=-0.16, guard_f=(0.50, 0.95), guard_r=(0.30, 1.15)),      # 紫: 巨漢。肩を張り、両腕を斜め下に広げて構える(前に伸ばすと相手の頭に掛かった)
)


def stylize(tr: Dict[str, List[dict]], style: str) -> Dict[str, List[dict]]:
    st = STYLES[style]
    for k in tr["body"]:
        if "hz" in k and 0.755 <= k["hz"] <= 0.815:          # 構え・踏み込み・戻りの高さ(しゃがみ・浮き・倒れは触らない。外したい瞬間は 0.83 などで書く)
            k["hz"] = round(k["hz"] - st["hz_drop"], 3)
        if k.get("lean") == 0.12:                          # 構えの値だけ
            k["lean"] = st["lean"]
        if k.get("ht") == 0.0:
            k["ht"] = st["ht"]
    for limb, g, ref in (("f_hand", "guard_f", GUARD_F), ("r_hand", "guard_r", GUARD_R)):
        for k in tr[limb]:
            if k.get("ang") == ref:
                k["ang"] = st[g]
    return tr


def skel(keys: List[dict], actor: dict, t: float) -> dict:
    k = keys[min(len(keys) - 1, int(round(t * FPS)))]
    pose = dict(ks.POSE0, **{n: v for n, v in k.items() if n in ks.POSE0})
    return fk.skeleton(pose, 1 if k["dir"] > 0 else -1, actor["base_x"] + k["dx"], actor.get("scale", 1.0))


def chest(sk):
    a, b = sk["torso"]
    return ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)


def belly(sk):
    a, b = sk["torso"]
    return (a[0] + (b[0] - a[0]) * 0.3, a[1] + (b[1] - a[1]) * 0.3)


def face(sk, toward):            # 顔の前面(toward 側へ頭の半径ぶん)
    hx, hz = sk["head"]
    return (hx + toward * sk["head_r"] * 0.8, hz - 0.03)


def chin(sk, toward):
    hx, hz = sk["head"]
    return (hx + toward * sk["head_r"] * 0.5, hz - sk["head_r"] * 0.85)


def surface(pt, toward, d=0.10):  # 体の線から toward 側へ d(拳・足が胴に潜らない当たり先)
    return (pt[0] + toward * d, pt[1])


def new_scene(name: str, bg: dict, t_end: float, actors: Dict[str, dict]) -> dict:
    """actors: {A: {color, scale}, B: {...}}。返す場面の actors は springs/plant を切ってある(keyshot の決まり)。"""
    from . import skit
    base = skit.build_skit(dict(name=name, stage="dojo", mood="battle", background=bg,
                                actors={w: dict(color=a["color"], x=0.0) for w, a in actors.items()}, props={}, beats=[dict(act="wait", dur=t_end)]))
    for w, a in actors.items():
        base["actors"][w] = dict(base["actors"][w], springs=False, plant=False, **({"scale": a["scale"]} if a.get("scale") else {}))
    base["tau_end"] = t_end
    base["footwork"] = None
    base["name"] = name
    return base


def H(tau, kind, pos, hold=0.0, by=None):
    return dict(tau=tau, hold=hold, kind=kind, pos=[round(pos[0], 3), round(pos[1], 3)], **({"by": by} if by else {}))


def finish(base: dict, keys: Dict[str, List[dict]], beats: List[dict], shots: List[dict], hits: List[dict], puffs: Optional[List[dict]] = None,
           flashes: Optional[List[float]] = None, slow: Optional[List[dict]] = None, speed_lines: Optional[List[list]] = None,
           invert=("kick", "clash")) -> dict:
    base["keys"] = keys
    base["hits"] = hits
    base["puffs"] = puffs or []
    base["fx"]["flashes"] = list(flashes or [])
    base["slow"] = list(slow or [])
    base["shots"] = ks.cut_plan(beats, shots)
    base["fx"]["invert"] = list(invert)
    base["fx"]["speed_lines"] = list(speed_lines or [])
    base["impact_cuts"] = dict(kinds=list(invert), hold=0.2,
                               angles=[dict(yaw=35, pitch=4, scale=3.0, lens=28, hue=0), dict(yaw=-40, pitch=-6, scale=2.6, lens=26, dutch=6.0, hue=1)],
                               per_kind=dict(clash=[dict(yaw=28, pitch=2, scale=2.4, lens=30, hue=3)]))
    base["anime"] = dict(base["anime"], trails=True, zoom_blur=True, roll=True)
    base["stepping"] = dict(hold=2, ones_around_hits=7, hold_camera=True)
    return base


def run_cli(build, beats, name: str):
    """各試合のスクリプトの main(--out / --preview / --plan-only / --check)。build() は (scene, rep) を返す。"""
    import argparse
    from pathlib import Path
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=f"out/{name}")
    ap.add_argument("--preview", action="store_true")
    ap.add_argument("--plan-only", action="store_true")
    ap.add_argument("--check", action="store_true")
    a = ap.parse_args()
    from . import cli, plan as pm
    sc, rep = build()
    print("IK の残差(0.02 超):", rep[:1], len(rep) - 1, "件", rep[1:12])
    out = Path(a.out)
    out.mkdir(parents=True, exist_ok=True)
    if a.check or a.plan_only:
        pl = pm.build_plan(sc)
        pm.save_plan(pl, out / "plan.json")
        if a.check:
            from . import animecheck
            vid = out / f"{name}.mp4"
            print(animecheck.report(animecheck.check(sc, pl, beats, str(vid) if vid.exists() else None)))
        print(out / "plan.json")
    elif a.preview:
        from . import preview
        print(preview.preview_scene(sc, out / "preview.mp4", cli.find_ffmpeg()))
    else:
        print(cli.build_scene(sc, out))

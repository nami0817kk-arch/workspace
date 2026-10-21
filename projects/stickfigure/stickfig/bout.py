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


# ---------------- 場面をつなぐ(2026-10-21「参考の動画のような見せ方」→ 札をやめて、歩いて入る・出るでつなぐ)----------------
def pose_of(keys: List[dict], actor: dict, i: int) -> dict:
    """焼いたコマ i の姿勢(歩きの始点・終点に使う)。足は世界の x。"""
    k = keys[i]
    pose = dict(ks.POSE0, **{n: v for n, v in k.items() if n in ks.POSE0})
    s = 1 if k["dir"] > 0 else -1
    sk = fk.skeleton(pose, s, actor["base_x"] + k["dx"], actor.get("scale", 1.0))
    return dict(x=actor["base_x"] + k["dx"], hz=k["hz"], lean=k["lean"], ht=k["ht"], dir=s,
                f=sk["front_leg"][-1][0], r=sk["rear_leg"][-1][0], fa=k["fa"], fe=k["fe"], ra=k["ra"], re=k["re"])


def walk_tracks(start: dict, end: dict, dur: float, step: float = 0.48, turn: Optional[int] = None) -> Dict[str, List[dict]]:
    """start から end まで歩くトラック(start/end は pose_of の形)。足は交互に前へ運び、腕は逆に振る。
    turn: 歩き出す前に向きを変える(+1/-1)。end の姿勢(構えなど)で終わる。"""
    d = turn if turn is not None else (1 if end["x"] >= start["x"] else -1)
    dist = abs(end["x"] - start["x"])
    n = max(2, int(round(dist / step)) + 1)
    t_go, t_stop = 0.18 if turn is not None else 0.06, dur - 0.12
    bx = lambda t: start["x"] + (end["x"] - start["x"]) * min(1.0, max(0.0, (t - t_go) / max(1e-6, t_stop - t_go)))
    body = [dict(t=0.0, x=start["x"], hz=start["hz"], lean=start["lean"], ht=start["ht"], dir=start["dir"], face="fight")]
    if turn is not None:
        body.append(dict(t=0.12, x=start["x"], hz=0.84, lean=0.05, ht=0.0, dir=d))
    ts = [t_go + (t_stop - t_go) * (i + 1) / n for i in range(n)]
    for i, t in enumerate(ts):                                       # 上下の弾み(踏み出しで沈み、通過で伸びる)
        body.append(dict(t=round(t - (ts[1] - ts[0]) * 0.5, 3), x=round(bx(t - (ts[1] - ts[0]) * 0.5), 3), hz=0.83, lean=0.07, ht=0.0, ease="linear"))
        if i < n - 1:
            body.append(dict(t=round(t, 3), x=round(bx(t), 3), hz=0.79, lean=0.07, ease="linear"))
    body.append(dict(t=round(dur, 3), x=end["x"], hz=end["hz"], lean=end["lean"], ht=end["ht"], dir=end["dir"]))
    feet = dict(f=[dict(t=0.0, p=(round(start["f"], 3), 0))], r=[dict(t=0.0, p=(round(start["r"], 3), 0))])
    cur = dict(f=start["f"], r=start["r"])
    order = ("r", "f") if (start["r"] - start["f"]) * d < 0 else ("f", "r")   # 後ろにある足から踏み出す
    for i, t in enumerate(ts):
        foot = order[i % 2]
        t0 = t - (ts[1] - ts[0]) * 0.95
        last = i >= n - 2
        tgt = end[foot] if last else bx(t) + d * 0.28
        feet[foot].append(dict(t=round(max(0.0, t0), 3), p=(round(cur[foot], 3), 0)))
        feet[foot].append(dict(t=round(t, 3), p=(round(tgt, 3), 0), lift=0.07))
        cur[foot] = tgt
    for foot in ("f", "r"):
        if abs(cur[foot] - end[foot]) > 1e-3:
            feet[foot].append(dict(t=round(dur - 0.02, 3), p=(round(end[foot], 3), 0), lift=0.04))
        feet[foot].append(dict(t=round(dur, 3), p=(round(end[foot], 3), 0)))
    fh = [dict(t=0.0, ang=(start["fa"], start["fe"]))]
    rh = [dict(t=0.0, ang=(start["ra"], start["re"]))]
    for i, t in enumerate(ts[:-1]):                                  # 腕は脚と逆に小さく振る
        sw = 0.45 if i % 2 == 0 else -0.35
        fh.append(dict(t=round(t, 3), ang=(sw, 0.35)))
        rh.append(dict(t=round(t, 3), ang=(-sw, 0.35)))
    fh.append(dict(t=round(dur, 3), ang=(end["fa"], end["fe"])))
    rh.append(dict(t=round(dur, 3), ang=(end["ra"], end["re"])))
    for tr in (feet["f"], feet["r"], fh, rh, body):
        tr.sort(key=lambda k: k["t"])
    return dict(body=body, f_foot=feet["f"], r_foot=feet["r"], f_hand=fh, r_hand=rh)


def _shift_times(sc: dict, dt: float) -> None:
    for w in sc["keys"]:
        for k in sc["keys"][w]:
            k["t"] = round(k["t"] + dt, 4)
    for h in sc.get("hits", []):
        h["tau"] = round(h["tau"] + dt, 4)
    for p in sc.get("puffs", []):
        p["tau"] = round(p["tau"] + dt, 4)
    fx = sc.get("fx", {})
    fx["flashes"] = [round(t + dt, 4) for t in fx.get("flashes", [])]
    fx["speed_lines"] = [[a + dt, b + dt] for a, b in fx.get("speed_lines", [])]
    for pr in fx.get("props", []):
        for k in pr.get("images", []):
            k[0] += dt
    for s in sc.get("slow", []):
        s["start"] += dt
        s["end"] += dt
    for s in sc.get("shots", []):
        s["t"] = round(s["t"] + dt, 4)


def prepend(sc: dict, frames: Dict[str, List[dict]], shots: Optional[List[dict]] = None) -> float:
    """場面の前に、焼いたコマ frames(人ごと。最後のコマ=場面の最初のコマ)を足す。書いていない人は最初のコマのまま待つ。
    場面の時刻はすべて後ろへずらす。足した秒数を返す(点検の beats もこの分ずらす)。"""
    n = max(len(v) for v in frames.values()) - 1
    dt = n / FPS
    _shift_times(sc, dt)
    for w, ks_ in sc["keys"].items():
        pre = frames.get(w)
        if pre is None:
            pre = [dict(ks_[0]) for _ in range(n)]
        else:
            pre = [dict(k) for k in pre[:n]]
        for i, k in enumerate(pre):
            k["t"] = round(i / FPS, 4)
        sc["keys"][w] = pre + ks_
    sc["tau_end"] = round(sc["tau_end"] + dt, 4)
    sc["shots"] = sorted((shots or []) + sc.get("shots", []), key=lambda s: s["t"])
    return dt


def append(sc: dict, frames: Dict[str, List[dict]], shots: Optional[List[dict]] = None) -> float:
    """場面の後ろに、焼いたコマ frames(最初のコマ=場面の最後のコマ)を足す。書いていない人は最後のコマのまま。"""
    n = max(len(v) for v in frames.values()) - 1
    t0 = sc["tau_end"]
    for w, ks_ in sc["keys"].items():
        add = frames.get(w)
        add = [dict(k) for k in add[1:n + 1]] if add is not None else [dict(ks_[-1]) for _ in range(n)]
        for i, k in enumerate(add):
            k["t"] = round(t0 + (i + 1) / FPS, 4)
        sc["keys"][w] = ks_ + add
    sc["tau_end"] = round(t0 + n / FPS, 4)
    sc["shots"] = sorted(sc.get("shots", []) + [dict(s, t=round(t0 + s["t"], 4)) for s in (shots or [])], key=lambda s: s["t"])
    return n / FPS


def board(x: float, images: List[list], w: float = 1.1, h: float = 1.4, z: float = 0.55) -> dict:
    """会場に立てる看板(勝ち抜きの表)。images: [[tau, 画像のパス], ...](tau 以降はその絵)。compose の props(kind board)で描く。"""
    return dict(kind="board", x=x, z=z, size=w, h=h, images=[[float(t), str(p)] for t, p in images])


def side_view(sc: dict, min_scale: float = 4.2) -> dict:
    """参考(Alan Becker の Animation vs. Minecraft)の見せ方にする(2026-10-21「参考の動画のような見せ方」)。
    カメラは真横から動かさず(角度のカットを消す)、全身が入る引きで横に追う。擬音の文字・放射線・白黒反転・角度を回す衝撃のカット・
    スピード線・ズームの寄り・スローは使わず、当たりは土煙と火花で見せる。動作(溜め・一気・止め・伸び)はそのまま。"""
    shots = [s for s in sc.get("shots", []) if "role" not in s]      # cut_plan で足した当たりごとのカットを外す
    flat = []
    for s in shots:
        s = dict(s, yaw=0.0, pitch=0.0, lens=40.0, scale=max(float(s.get("scale", min_scale)), min_scale), lag=max(float(s.get("lag", 0.0)), 0.35))
        s.pop("dutch", None)
        if flat and s["follow"] == flat[-1]["follow"] and abs(s["scale"] - flat[-1]["scale"]) < 0.3:
            continue                                                 # 同じ追い方が続くなら 1 カットのまま(長回し)
        flat.append(s)
    sc["shots"] = flat
    fx = sc.setdefault("fx", {})
    fx["invert"], fx["speed_lines"], fx["flashes"], fx["radial"] = [], [], [], False
    sc.pop("impact_cuts", None)
    sc.pop("flurry", None)
    sc["slow"] = []
    sc["anime"] = dict(sc.get("anime") or {}, trails=False, sfx=False, zoom_blur=False, roll=False, zoom_punch=False)
    sc["stepping"] = dict(hold=2, ones_around_hits=3, hold_camera=True)
    for h in sc.get("hits", []):                                     # ヒットストップは短く(参考は 1〜3 コマ)
        h["hold"] = min(float(h.get("hold", 0.0)), 0.10)
    for h in sc.get("hits", []):                                     # 当たりに土煙(放射線の代わり)
        if h.get("kind") in ("hit", "kick", "clash", "land"):
            sc.setdefault("puffs", []).append(dict(tau=h["tau"], kind="land2", pos=[h["pos"][0], max(0.0, h["pos"][1] - 0.2)]))
    return sc


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
            if beats and sc.get("fx", {}).get("radial", True) is False:        # 参考の見せ方の戦いは、激しさも測る
                print(animecheck.intensity_report(animecheck.intensity(sc, beats)))
        print(out / "plan.json")
    elif a.preview:
        from . import preview
        print(preview.preview_scene(sc, out / "preview.mp4", cli.find_ffmpeg()))
    else:
        print(cli.build_scene(sc, out))

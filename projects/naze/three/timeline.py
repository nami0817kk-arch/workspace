"""コマごとの計画(plan.json): 時間の流れ(スロー)・カメラの切り替え・効果の状態・球の位置。

Blender はこの計画を当てはめて描くだけ。計画は素の Python で作るので、描かずに点検できる。
"""
from __future__ import annotations

import json
import math
from pathlib import Path

import numpy as np

from .physics import Track


# ---------------- 時間の流れ ----------------

def rate_keys(tr: Track, tm: dict):
    th = tr.t_hit
    walls = tr.event("mat")
    tw = walls[0]["t"] if walls else tr.d["t_stop"]
    return [
        (th - 0.32, tm["pre"]), (th - 0.05, tm["hit"]), (th + tm["hit_hold"], tm["hit"]),
        (th + 0.15, tm["fly"]), (tw - 0.03, tm["fly"]), (tw, tm["wall"]),
        (tw + tm["wall_hold"], tm["wall"]), (tw + 0.45, tm["after"]),
    ]


def warp(tr: Track, tm: dict, s_start: float, fps: int):
    """動画の各コマ i に当たる物理の時刻 s と、その時の速さ(1=実時間)を返す。"""
    keys = rate_keys(tr, tm)
    ks, kr = np.array([k[0] for k in keys]), np.array([k[1] for k in keys])
    s_end = tr.d["t_stop"] + tm["tail"] * tm["after"]
    ds = 1e-4
    s = np.arange(s_start, s_end + ds, ds)
    rate = np.interp(s, ks, kr)
    v = np.concatenate([[0.0], np.cumsum(ds / rate[:-1])])
    n = int(v[-1] * fps)
    vi = np.arange(n) / fps
    return np.interp(vi, v, s), np.interp(np.interp(vi, v, s), ks, kr)


# ---------------- カメラ ----------------

def _mix(a, b, k):
    return [x * (1 - k) + y * k for x, y in zip(a, b)]


def smooth(k: float) -> float:
    k = min(max(k, 0.0), 1.0)
    return k * k * (3 - 2 * k)


def camera(shot: str, s: float, k: float, tr: Track, sc: dict) -> dict:
    """shot: A=殴る所の寄り, B=球を追う, C=当たる所の固定。k はその場面の進み(0〜1)。"""
    p, _, _ = tr.at(s)
    if shot == "A":
        b0 = np.array(tr.d["start"])
        tgt = [0.25 + 0.35 * b0[0] / 0.7, b0[1] * 0.6, 1.24]
        loc = _mix([1.85, -2.35, 1.45], [1.55, -1.95, 1.40], smooth(k))
        return dict(loc=loc, target=tgt, lens=32.0)
    if shot == "B":
        bx = float(p[0])
        return dict(loc=[bx - 1.3, -2.6, 1.25], target=[bx + 0.7, float(p[1]) * 0.5, 0.45 * float(p[2]) + 0.55], lens=30.0)
    mf = tr.d["mat_front"]
    loc = _mix([mf - 4.4, -3.0, 1.25], [mf - 3.9, -2.6, 1.15], smooth(k))
    return dict(loc=loc, target=[mf - 1.3, -0.1, 0.75], lens=30.0)


# ---------------- 効果 ----------------

def _age(s, t0, dur):
    a = s - t0
    return a / dur if 0 <= a < dur else None


def effects(s: float, tr: Track, sc: dict) -> dict:
    r = tr.r
    st = np.array(tr.d["start"])
    pc = (st - [r, 0, 0]).tolist()                 # 拳と球の当たる所
    fx = dict(rings=[], flashes=[], trail=[], lines=[], light=None, squash=0.0)
    th = tr.t_hit
    for delay, big in ((0.0, 1.0), (0.014, 0.7)):
        k = _age(s, th + delay, 0.11)
        if k is not None:
            fx["rings"].append(dict(pos=[pc[0] + 0.35 * k, pc[1], pc[2]], radius=0.10 + 1.7 * big * k ** 0.55,
                                    alpha=0.8 * (1 - k) ** 1.6, thick=0.025 * (1 - 0.6 * k), axis="x"))
    k = _age(s, th, 0.03)
    if k is not None:
        fx["flashes"].append(dict(pos=pc, scale=0.05 + 0.22 * k, alpha=0.55 * (1 - k) ** 2))
    k = _age(s, th, 0.014)
    if k is not None:
        fx["squash"] = 0.22 * math.sin(math.pi * k)
    walls = tr.event("mat")
    if walls:
        w = walls[0]
        wp = [tr.d["mat_front"] - 0.02, w["pos"][1], w["pos"][2]]
        for delay, big in ((0.0, 1.0), (0.02, 0.65)):
            k = _age(s, w["t"] + delay, 0.16)
            if k is not None:
                fx["rings"].append(dict(pos=[wp[0] - 0.25 * k, wp[1], wp[2]], radius=0.12 + 1.3 * big * k ** 0.5,
                                        alpha=0.9 * (1 - k) ** 1.4, thick=0.03 * (1 - 0.5 * k), axis="x"))
        k = _age(s, w["t"], 0.06)
        if k is not None:
            fx["flashes"].append(dict(pos=wp, scale=0.05 + 0.2 * k, alpha=0.5 * (1 - k) ** 2))
        k = _age(s, w["t"], 0.035)
        if k is not None:
            fx["squash"] = 0.28 * math.sin(math.pi * k)
    if s > th:
        p, _, v = tr.at(s)
        sp = float(np.linalg.norm(v))
        gone = s - th
        a_trail = min(1.0, max(0.0, (sp - 8.0) / 12.0)) * min(1.0, gone / 0.01)
        if a_trail > 0.01:
            # 光の筋: 球の後ろへ細くなる円すい 1 本(材質で尾の方ほど薄くする)。長さは飛んだ距離まで
            length = min(2.6, float(np.linalg.norm(p - st)))
            tail = tr.at(max(th, s - length / max(sp, 1e-3)))[0]
            fx["trail"].append(dict(a=p.tolist(), b=tail.tolist(), radius=r * 0.6, alpha=0.38 * a_trail))
        a_lines = min(1.0, max(0.0, (sp - 15.0) / 10.0)) * min(1.0, gone / 0.03)
        if a_lines > 0.01:
            d = v / max(sp, 1e-6)
            length = min(0.09 * sp, float(np.linalg.norm(p - st)))
            for i in range(6):
                ang = math.radians(15 + 60 * i)
                rad = 0.30 + 0.08 * (i % 3)
                off = np.array([0.0, math.cos(ang) * rad, math.sin(ang) * rad])
                head = p + off - d * (0.15 + 0.1 * (i % 2))
                fx["lines"].append(dict(a=head.tolist(), b=(head - d * length).tolist(), alpha=0.4 * a_lines))
    return fx


# ---------------- 計画 ----------------

def plan(tr: Track, sc: dict, fps: int, out: Path) -> dict:
    tm = sc["timing"]
    s_start = sc["punch"]["start"] - tm.get("preroll", 0.75)
    ss, rates = warp(tr, tm, s_start, fps)
    st = np.array(tr.d["start"])
    mf = tr.d["mat_front"]
    # 切り替えの時刻(物理の時刻で)
    s_ab = next(s for s in ss if s > tr.t_hit and tr.at(s)[0][0] - st[0] > sc["cut"]["follow_after"])
    s_bc = next(s for s in ss if s > s_ab and tr.at(s)[0][0] > mf - sc["cut"]["fixed_before"])
    i_ab, i_bc = int(np.searchsorted(ss, s_ab)), int(np.searchsorted(ss, s_bc))
    frames = []
    for i, (s, rt) in enumerate(zip(ss, rates)):
        shot, i0, i1 = ("A", 0, i_ab) if i < i_ab else ("B", i_ab, i_bc) if i < i_bc else ("C", i_bc, len(ss))
        k = (i - i0) / max(1, i1 - i0 - 1)
        p, q, v = tr.at(float(s))
        frames.append(dict(i=i, s=float(s), rate=float(rt), shot=shot, cam=camera(shot, float(s), k, tr, sc),
                           ball=dict(pos=p.tolist(), quat=q.tolist(), speed=float(np.linalg.norm(v))), fx=effects(float(s), tr, sc)))
    v_of = lambda s_ev: float(np.interp(s_ev, ss, np.arange(len(ss)) / fps))
    events = [dict(v=v_of(tr.t_hit), kind="hit", speed=tr.d["v0"])]
    events += [dict(v=v_of(e["t"]), kind=e["kind"], speed=e["speed"]) for e in tr.d["events"]]
    d = dict(fps=fps, n=len(frames), cuts=[i_ab, i_bc], frames=frames, events=events, t_hit=tr.t_hit,
             v_hit=v_of(tr.t_hit), v0=tr.d["v0"], ball_start=tr.d["start"], radius=tr.r, mat_front=mf, mat=tr.d["mat"])
    out.write_text(json.dumps(d), encoding="utf-8")
    return d

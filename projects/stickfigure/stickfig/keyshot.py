"""手付けのカット(keyshot): アニメーターが IK の人形で付けるように、腰・足・手を別々のトラックで付け、
コマごとに関節の角度を逆算して keys に焼き込む。2026-10-20「質が低い、参考と同じにするには」→ 1 カットずつ手で付ける方式の試作。

自動の台本(fight / skit)との違い:
  - 足は世界座標に置く(踏んでいる間は滑らない)。足の目標を横に動かすと山なり(lift)に運ぶ
  - 手は世界座標に置く(箱の側面をつかむ)か、角度で振る。角度⇄置き場所の間は世界座標で混ぜてつなぐ
  - トラックごとにキーと緩急(ease)を持つ: inout / in(溜めて一気) / out(勢いが抜ける) / linear / hold
  - 震え(shake)・物の位置も同じ時間軸で書く
  - 毎コマ焼き込むので、バネ(springs)と足の固定(plant)は使わない(actor に springs: false, plant: false)

トラック(例は tools/shots/heavy_box.py):
  body:   [{t, x, hz, lean, ht, spin, rz, roll, dir, shake, face, ease}]
  f_foot / r_foot: [{t, p: (x, z), ease, lift}]
  f_hand / r_hand: [{t, p: (x, z)} か {t, ang: (肩, 肘)}, ease]
  prop:   [{t, x, z, shake, ease}]
"""
from __future__ import annotations

import math
from typing import Dict, List, Optional, Tuple

from . import fk

Pt = Tuple[float, float]
POSE0 = dict(fa=0.4, fe=0.6, ra=0.3, re=0.6, fl=0.1, fk=0.1, rl=-0.1, rk=0.1, lean=0.0, hz=0.8, dx=0.0, rz=0.0, roll=0.0,
             ht=0.0, spin=0.0, st=0.0, lst=0.0, run=0.0, walk=0.0, hold=0.0, dir=1.0)
LIMBS = dict(f_foot=("fl", "fk", "front_leg", (-2.2, 2.2), (0.0, 2.7)),
             r_foot=("rl", "rk", "rear_leg", (-2.2, 2.2), (0.0, 2.7)),
             f_hand=("fa", "fe", "front_arm", (-3.3, 3.3), (-0.05, 2.9)),
             r_hand=("ra", "re", "rear_arm", (-3.3, 3.3), (-0.05, 2.9)))
BODY = ("x", "hz", "lean", "ht", "spin", "rz", "roll")


def ease(u: float, kind: str) -> float:
    u = max(0.0, min(1.0, u))
    if kind == "linear":
        return u
    if kind == "in":                      # ゆっくり出て速く着く(溜めから一気に)
        return u * u * u
    if kind == "out":                     # 速く出てゆっくり止まる(勢いが抜ける)
        return 1 - (1 - u) ** 3
    if kind == "hold":
        return 0.0 if u < 1.0 else 1.0
    return u * u * (3 - 2 * u)            # inout


def _end(pose: dict, s: int, x: float, chain: str) -> Pt:
    return fk.skeleton(pose, s, x, 1.0)[chain][-1]


def solve_limb(pose: dict, s: int, x: float, limb: str, target: Pt, iters: int = 30) -> float:
    """pose の limb の端が target に来るよう、2 つの角を減衰つきガウス・ニュートンで解く(pose を書き換える)。残差を返す。"""
    a_k, b_k, chain, (alo, ahi), (blo, bhi) = LIMBS[limb]
    h = 1e-4
    err = 9.9
    for _ in range(iters):
        e = _end(pose, s, x, chain)
        rx, rz = target[0] - e[0], target[1] - e[1]
        err = math.hypot(rx, rz)
        if err < 5e-4:
            break
        J = []
        for k in (a_k, b_k):
            v = pose[k]
            pose[k] = v + h
            e2 = _end(pose, s, x, chain)
            pose[k] = v
            J.append(((e2[0] - e[0]) / h, (e2[1] - e[1]) / h))
        (j11, j21), (j12, j22) = J
        lam = 1e-3 + 0.05 * err
        a11, a12, a22 = j11 * j11 + j21 * j21 + lam, j11 * j12 + j21 * j22, j12 * j12 + j22 * j22 + lam
        g1, g2 = j11 * rx + j21 * rz, j12 * rx + j22 * rz
        det = a11 * a22 - a12 * a12
        if abs(det) < 1e-12:
            break
        d1 = (a22 * g1 - a12 * g2) / det
        d2 = (-a12 * g1 + a11 * g2) / det
        step = max(1.0, math.hypot(d1, d2) / 0.4)
        pose[a_k] = max(alo, min(ahi, pose[a_k] + d1 / step))
        pose[b_k] = max(blo, min(bhi, pose[b_k] + d2 / step))
    return err


def solve_leg(pose: dict, s: int, x: float, limb: str, target: Pt) -> float:
    """脚は解析で解き、膝が前(向いている側)に出る解を選ぶ(数値解は膝が後ろに折れる解に落ちることがあった)。
    届かないときはまっすぐ伸ばして向ける。近すぎるときは数値解に任せる。"""
    a_k, b_k = LIMBS[limb][:2]
    hip = (0.0, pose["hz"])
    X, Z = target[0] - x, target[1] - pose["rz"]
    dx, dz = X - hip[0], Z - hip[1]
    r = math.hypot(dx, dz)
    L = fk.LEG_TOTAL

    def end(tt, kk):
        return fk.chain_points(hip, 0.0, -tt * s, (-tt + kk) * s, L)

    if r < L * 0.25:
        return solve_limb(pose, s, x, limb, target)
    aT = math.atan2(dx, -dz)                     # 股から目標への向き(真下 0、前 +)
    if r >= L * 0.999:                           # 届かない: 伸ばして向ける
        pose[a_k], pose[b_k] = aT * s, 0.0
        e = end(pose[a_k], 0.0)[-1]
        return math.hypot(e[0] - X, e[1] - Z)
    lo, hi = 0.0, 2.7
    for _ in range(40):
        mid = 0.5 * (lo + hi)
        e = end(0.0, mid)[-1]
        if math.hypot(e[0] - hip[0], e[1] - hip[1]) > r:
            lo = mid
        else:
            hi = mid
    k = 0.5 * (lo + hi)
    e0 = end(0.0, k)[-1]
    a0 = math.atan2(e0[0] - hip[0], -(e0[1] - hip[1]))
    best = None
    for tt in ((aT - a0) * s, (a0 - aT) * s):
        pts = end(tt, k)
        err = math.hypot(pts[-1][0] - X, pts[-1][1] - Z)
        knee = pts[len(pts) // 2]
        fwd = (knee[0] - (hip[0] + X) / 2) * s           # 膝が股と足の中点より前に出ている量
        score = (err > 0.02, -fwd)
        if best is None or score < best[0]:
            best = (score, tt, err)
    pose[a_k], pose[b_k] = best[1], k
    return best[2]


def _lerp(a, b, u):
    if isinstance(a, (tuple, list)):
        return tuple(_lerp(x, y, u) for x, y in zip(a, b))
    return a + (b - a) * u


def _seg(track: List[dict], t: float):
    if t <= track[0]["t"]:
        return track[0], track[0], 0.0
    for k0, k1 in zip(track, track[1:]):
        if k0["t"] <= t <= k1["t"]:
            return k0, k1, (t - k0["t"]) / max(1e-9, k1["t"] - k0["t"])
    return track[-1], track[-1], 1.0


def _body_at(track: List[dict], t: float) -> dict:
    """腰トラック: 各項目は、その項目を書いた前後のキーで補間(書いていないキーは飛ばす)。"""
    out: Dict[str, object] = {}
    for key in BODY + ("shake",):
        ks = [k for k in track if key in k]
        if not ks:
            continue
        k0, k1, u = _seg(ks, t)
        out[key] = _lerp(float(k0[key]), float(k1[key]), ease(u, k1.get("ease", "inout")))
    for key in ("dir", "face"):
        ks = [k for k in track if key in k]
        if ks:
            cur = ks[0][key]
            for k in ks:
                if k["t"] <= t + 1e-9:
                    cur = k[key]
            out[key] = cur
    return out


def bake(tracks: Dict[str, List[dict]], actor: dict, fps: int = 30, t_end: Optional[float] = None, report: Optional[list] = None) -> List[dict]:
    """トラックを毎コマの姿勢キーに焼き込む。actor は base_x を持つ(facing は +1 で置き、向きは body の dir)。"""
    base_x = float(actor.get("base_x", 0.0))
    t_end = t_end if t_end is not None else max(k["t"] for tr in tracks.values() for k in tr)
    pose = dict(POSE0)
    keys = []
    worst = 0.0
    for f in range(int(round(t_end * fps)) + 1):
        t = f / fps
        b = _body_at(tracks["body"], t)
        s = 1 if float(b.get("dir", 1)) >= 0 else -1
        sh = float(b.get("shake", 0.0))
        x = float(b.get("x", base_x)) + (sh * (1 if (f // 2) % 2 == 0 else -1) if sh else 0.0)   # 震え: 2 コマごとに左右・上下に小さく(力んでいる)
        for key in ("hz", "lean", "ht", "spin", "rz", "roll"):
            if key in b:
                pose[key] = float(b[key])
        if sh:
            pose["hz"] += sh * 0.5 * (1 if (f // 2) % 2 else -1)
        pose["dir"] = float(s)
        for limb in ("f_foot", "r_foot", "f_hand", "r_hand"):
            tr = tracks.get(limb)
            if not tr:
                continue
            k0, k1, u = _seg(tr, t)
            ue = ease(u, k1.get("ease", "inout"))
            a_k, b_k, chain = LIMBS[limb][:3]

            def world(k):                      # キーの手足の世界座標(角度で書いたキーは、今の体での先端)
                if "p" in k:
                    return tuple(k["p"])
                tmp = dict(pose, **{a_k: k["ang"][0], b_k: k["ang"][1]})
                return _end(tmp, s, x, chain)

            if "ang" in k0 and "ang" in k1:
                pose[a_k], pose[b_k] = _lerp(k0["ang"][0], k1["ang"][0], ue), _lerp(k0["ang"][1], k1["ang"][1], ue)
                continue
            p0, p1 = world(k0), world(k1)
            tgt = _lerp(p0, p1, ue)
            if limb.endswith("foot") and abs(p1[0] - p0[0]) > 0.04:          # 踏み替え: 山なり
                tgt = (tgt[0], tgt[1] + float(k1.get("lift", 0.10)) * math.sin(math.pi * ue))
            if u >= 1.0 and "ang" in k1:
                pose[a_k], pose[b_k] = k1["ang"]
                continue
            e = solve_leg(pose, s, x, limb, tgt) if limb.endswith("foot") else solve_limb(pose, s, x, limb, tgt)
            worst = max(worst, e)
            if report is not None and e > 0.02:
                report.append((round(t, 2), limb, round(e, 3)))
        keys.append(dict(t=round(t, 4), dx=round(x - base_x, 5), abs=True, face=b.get("face", "fight"),
                         **{kk: round(float(pose[kk]), 5) for kk in ("fa", "fe", "ra", "re", "fl", "fk", "rl", "rk", "lean", "hz", "ht", "spin", "rz", "roll", "dir")}))
    if report is not None:
        report.insert(0, ("worst", round(worst, 4)))
    return keys


def bake_prop(track: List[dict], fps: int = 30, t_end: Optional[float] = None) -> List[list]:
    """物の位置 [{t, x, z, ease, shake}] を毎コマの [t, x, z] に焼き込む。"""
    t_end = t_end if t_end is not None else track[-1]["t"]
    out = []
    for f in range(int(round(t_end * fps)) + 1):
        t = f / fps
        k0, k1, u = _seg(track, t)
        ue = ease(u, k1.get("ease", "inout"))
        x, z = _lerp(float(k0["x"]), float(k1["x"]), ue), _lerp(float(k0["z"]), float(k1["z"]), ue)
        sh = _lerp(float(k0.get("shake", 0.0)), float(k1.get("shake", 0.0)), ue)
        if sh:
            x += sh * (1 if (f // 2) % 2 == 0 else -1)
        out.append([round(t, 4), round(x, 4), round(z, 4)])
    return out

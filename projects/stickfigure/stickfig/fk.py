"""順運動学(2D)。Blender の人物と同じ形を、純粋な Python で再現する。

世界座標は (x, z)。x=右、z=上。人物の向き s は +1(右向き)か -1(左向き)。
ここで出す位置は、(1) 接触の高さ・位置を逆算して合わせる、(2) 合否の点検(めり込み・当たり)に使う。
Blender 側の鎖(腕・脚は6節)と同じ曲がりの配り方をそろえてある(blender_player.py の set_chain と同じ式)。
"""
from __future__ import annotations

import math
from typing import Dict, List, Sequence, Tuple

from .interp import smoothstep

Pt = Tuple[float, float]

TORSO = 0.66          # 腰から首まで
SHOULDER_Z = 0.60     # 腰から肩までの高さ(胴に沿って)
HEAD_OFF = 0.24       # 首から頭の中心まで
HEAD_R = 0.20
ARM_TOTAL, LEG_TOTAL, NSEG = 0.66, 0.90, 6
HAND_R = 0.034
SWORD_TIP = 0.965     # 手の節の原点から剣先まで(blender_player.py の blade の位置と長さ)
# 武器ごとの、手の節の原点から先端まで(blender_player.py の WEAPONS と同じ: 0.115 + 長さ)。姿勢 pose["wl"] が無ければ剣
WEAPON_TIP = dict(sword=0.965, dagger=0.535, staff=1.615, spear=1.795)  # 槍は軸 1.5 + 穂先(中心 +0.05・高さ 0.26 の半分 0.13)


def chain_angles(th_up: float, th_low: float, n: int = NSEG) -> List[float]:
    """鎖の各節の「親に対する絶対角」。曲がりを節に配る(肘・膝が折れずに弧を描く)。"""
    out = []
    for i in range(n):
        u = (i + 0.5) / n
        w = smoothstep(u, 0.2, 0.8)
        out.append(th_up * (1 - w) + th_low * w)
    return out


def _dir(phi: float) -> Pt:
    """Y軸まわりに phi 回した「真下向きの単位ベクトル」(x, z)。"""
    return (-math.sin(phi), -math.cos(phi))


def chain_points(origin: Pt, base_rot: float, th_up: float, th_low: float, total: float, n: int = NSEG) -> List[Pt]:
    """鎖の各節の始点と、最後の端点(n+1 個)。base_rot は親の回転(胴の傾きなど)。"""
    seg = total / n
    pts = [origin]
    x, z = origin
    for th in chain_angles(th_up, th_low, n):
        dx, dz = _dir(base_rot + th)
        x += dx * seg
        z += dz * seg
        pts.append((x, z))
    return pts


def last_dir(base_rot: float, th_up: float, th_low: float, n: int = NSEG) -> Pt:
    return _dir(base_rot + chain_angles(th_up, th_low, n)[-1])


def skeleton(pose: Dict[str, float], s: int, root_x: float, scale: float = 1.0) -> Dict[str, object]:
    """姿勢(合成後の1コマぶん)から、各部位の折れ線を世界座標で返す。

    pose: fa fe ra re fl fk rl rk lean hz rz roll ht の値を使う。root_x は根元の世界 x(dx と向きを反映済み)。
    戻り値: head(中心), head_r, torso(腰→首), front_arm / rear_arm / front_leg / rear_leg (折れ線),
            hand(前の手), tip(前の剣先), foot(前の足), hip, neck
    """
    rho = -pose["roll"] * s              # 根元の回転(Blender の root.rotation_euler.y)
    chi = pose["lean"] * s               # 胴の傾き
    cr, sr = math.cos(rho), math.sin(rho)

    def to_world(pt: Pt) -> Pt:
        x, z = pt[0] * scale, pt[1] * scale
        return (root_x + x * cr + z * sr, pose["rz"] - x * sr + z * cr)

    def up(d: float, ang: float) -> Pt:      # 腰から胴に沿って d、胴の回転 ang
        return (d * math.sin(ang), d * math.cos(ang))

    hip_l = (0.0, pose["hz"])

    def add(a: Pt, b: Pt) -> Pt:
        return (a[0] + b[0], a[1] + b[1])

    neck_l = add(hip_l, up(TORSO, chi))
    sh_l = add(hip_l, up(SHOULDER_Z, chi))
    head_l = add(neck_l, up(HEAD_OFF, chi - pose["ht"] * s))

    def arm(a: float, e: float) -> List[Pt]:
        pts = chain_points(sh_l, rho_less(chi), -a * s, -(a + e) * s, ARM_TOTAL)
        return [to_world(p) for p in pts]

    def leg(t: float, k: float) -> List[Pt]:
        pts = chain_points(hip_l, 0.0, -t * s, (-t + k) * s, LEG_TOTAL)
        return [to_world(p) for p in pts]

    def rho_less(c: float) -> float:
        return c

    fa = arm(pose["fa"], pose["fe"])
    ra = arm(pose["ra"], pose["re"])
    fl = leg(pose["fl"], pose["fk"])
    rl = leg(pose["rl"], pose["rk"])
    # 剣先(前の手の節の向きに、手の節の原点から SWORD_TIP)。世界の回転 rho を足す。
    d = last_dir(chi, -pose["fa"] * s, -(pose["fa"] + pose["fe"]) * s)
    dwx = (d[0] * cr + d[1] * sr)
    dwz = (-d[0] * sr + d[1] * cr)
    seg = ARM_TOTAL / NSEG
    j5 = fa[-2]
    wl = pose.get("wl", SWORD_TIP)
    tip = (j5[0] + dwx * wl * scale, j5[1] + dwz * wl * scale)
    return dict(
        head=to_world(head_l), head_r=HEAD_R * scale, hip=to_world(hip_l), neck=to_world(neck_l),
        torso=[to_world(hip_l), to_world(neck_l)],
        front_arm=fa, rear_arm=ra, front_leg=fl, rear_leg=rl,
        hand=fa[-1], tip=tip, foot=fl[-1], rear_foot=rl[-1], sword=[j5, tip],
    )


def seg_cross(p1: Pt, p2: Pt, q1: Pt, q2: Pt) -> bool:
    """2つの線分が、端点以外で交差するか(接するだけは交差とみなさない)。"""
    def orient(a: Pt, b: Pt, c: Pt) -> float:
        return (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0])
    d1, d2 = orient(q1, q2, p1), orient(q1, q2, p2)
    d3, d4 = orient(p1, p2, q1), orient(p1, p2, q2)
    eps = 1e-9
    return (d1 * d2 < -eps) and (d3 * d4 < -eps)


def lines_cross(a_lines: Sequence[Sequence[Pt]], b_lines: Sequence[Sequence[Pt]]) -> int:
    """2人の線(折れ線の集まり)が交差している箇所の数。"""
    n = 0
    for la in a_lines:
        for lb in b_lines:
            for p1, p2 in zip(la, la[1:]):
                for q1, q2 in zip(lb, lb[1:]):
                    if seg_cross(p1, p2, q1, q2):
                        n += 1
    return n


def dist_point_segment(p: Pt, a: Pt, b: Pt) -> float:
    ax, az = a
    bx, bz = b
    dx, dz = bx - ax, bz - az
    L2 = dx * dx + dz * dz
    if L2 < 1e-12:
        return math.hypot(p[0] - ax, p[1] - az)
    t = max(0.0, min(1.0, ((p[0] - ax) * dx + (p[1] - az) * dz) / L2))
    return math.hypot(p[0] - (ax + t * dx), p[1] - (az + t * dz))


def dist_point_polyline(p: Pt, pts: Sequence[Pt]) -> float:
    return min(dist_point_segment(p, a, b) for a, b in zip(pts, pts[1:]))


def body_lines(sk: Dict[str, object]) -> List[List[Pt]]:
    """人物の線(胴・腕・脚)。頭は別(円)。"""
    return [sk["torso"], sk["front_arm"], sk["rear_arm"], sk["front_leg"], sk["rear_leg"]]  # type: ignore[list-item]


def dist_to_body(p: Pt, sk: Dict[str, object]) -> float:
    d = min(dist_point_polyline(p, ln) for ln in body_lines(sk))
    hx, hz = sk["head"]  # type: ignore[misc]
    d = min(d, max(0.0, math.hypot(p[0] - hx, p[1] - hz) - sk["head_r"]))  # type: ignore[operator]
    return d


def target_point(sk: Dict[str, object], name: str) -> Pt:
    """当てる先の点。hip / chest(胴の真ん中) / head / neck。"""
    if name == "hip":
        return sk["hip"]  # type: ignore[return-value]
    if name == "neck":
        return sk["neck"]  # type: ignore[return-value]
    if name == "head":
        return sk["head"]  # type: ignore[return-value]
    if name == "chest":
        a, b = sk["torso"]  # type: ignore[misc]
        return ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)
    raise ValueError(f"知らない当て先: {name}")


def leg_ik(pose: Dict[str, float], s: int, root_x: float, scale: float, target: Pt, max_bend: float = 2.6):
    """脚の IK: 足先(鎖の端)が世界座標 target に来る (太ももの角 t, 膝の曲げ k) を返す。届かなければ None。

    鎖は hip から base_rot=0 で始まるので、t を変えると鎖全体が股を軸に回る(剛体回転)。
    よって k は「股から足先までの距離」だけで二分法で決まり、t は向きの差で決まる。"""
    rho = -pose["roll"] * s
    cr, sr = math.cos(rho), math.sin(rho)
    X, Z = target[0] - root_x, target[1] - pose["rz"]
    xl, zl = (X * cr - Z * sr) / scale, (X * sr + Z * cr) / scale          # 根元の座標系(scale 1)
    hip = (0.0, pose["hz"])
    dx, dz = xl - hip[0], zl - hip[1]
    r = math.hypot(dx, dz)
    if r > LEG_TOTAL * 0.995 or r < LEG_TOTAL * 0.25:
        return None

    def end(tt: float, kk: float) -> Pt:
        return chain_points(hip, 0.0, -tt * s, (-tt + kk) * s, LEG_TOTAL)[-1]

    lo, hi = 0.0, max_bend
    for _ in range(40):
        mid = 0.5 * (lo + hi)
        e = end(0.0, mid)
        if math.hypot(e[0] - hip[0], e[1] - hip[1]) > r:
            lo = mid
        else:
            hi = mid
    k = 0.5 * (lo + hi)
    e0 = end(0.0, k)
    a0 = math.atan2(e0[0] - hip[0], -(e0[1] - hip[1]))
    aT = math.atan2(dx, -dz)
    best = None
    for tt in ((aT - a0) * s, (a0 - aT) * s):
        e = end(tt, k)
        err = math.hypot(e[0] - xl, e[1] - zl)
        if best is None or err < best[0]:
            best = (err, tt)
    if best[0] > 0.02:
        return None
    return best[1], k

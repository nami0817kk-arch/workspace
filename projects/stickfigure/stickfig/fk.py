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
    tip = (j5[0] + dwx * SWORD_TIP * scale, j5[1] + dwz * SWORD_TIP * scale)
    return dict(
        head=to_world(head_l), head_r=HEAD_R * scale, hip=to_world(hip_l), neck=to_world(neck_l),
        torso=[to_world(hip_l), to_world(neck_l)],
        front_arm=fa, rear_arm=ra, front_leg=fl, rear_leg=rl,
        hand=fa[-1], tip=tip, foot=fl[-1], rear_foot=rl[-1],
    )


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

"""カメラの計算(純粋な Python)。Blender のカメラと、合成の投影(放射線・ひび・砂ぼこり・影の位置)が、同じ式を使う。

従来は、真横から見る平行投影(ortho)だった。3D感を出すため、**遠近のあるカメラを、人物の向こうへ回り込ませる**
(yaw=斜めの角度、pitch=少し上から)。舞台(床・壁・柱)は Blender に立体で置く。

座標: x=右、y=奥、z=上。人物は y=0 の面で動く。カメラは target(x, 0, z)を向き、距離 dist だけ離れる。
  カメラの位置 = target + dist·(sin(yaw)cos(pitch), -cos(yaw)cos(pitch), sin(pitch))
yaw=0・pitch=0 なら、真横から見る従来のカメラと同じ(y=0 の面では、1単位が pxu ピクセル)。
"""
from __future__ import annotations

import math
from typing import Dict, Tuple

W, H = 1280, 720
SENSOR_MM = 36.0


def f_px(lens_mm: float) -> float:
    """焦点距離(ピクセル)。センサー幅 36mm を画面幅に対応させる。"""
    return lens_mm / SENSOR_MM * W


def dist_for_scale(scale: float, lens_mm: float) -> float:
    """y=0 の面で、画面の幅が scale 単位になる距離(従来の ortho の「見える幅」と同じ意味)。"""
    return f_px(lens_mm) * scale / W


def basis(yaw_deg: float, pitch_deg: float) -> Tuple[Tuple[float, float, float], Tuple[float, float, float], Tuple[float, float, float]]:
    """カメラの(前, 右, 上)の単位ベクトル。"""
    y, p = math.radians(yaw_deg), math.radians(pitch_deg)
    f = (-math.sin(y) * math.cos(p), math.cos(y) * math.cos(p), -math.sin(p))
    r = (math.cos(y), math.sin(y), 0.0)
    u = (r[1] * f[2] - r[2] * f[1], r[2] * f[0] - r[0] * f[2], r[0] * f[1] - r[1] * f[0])
    return f, r, u


def position(cam: Dict[str, float]) -> Tuple[float, float, float]:
    y, p = math.radians(cam["yaw"]), math.radians(cam["pitch"])
    d = cam["dist"]
    return (cam["tx"] + d * math.sin(y) * math.cos(p), cam["ty"] - d * math.cos(y) * math.cos(p), cam["tz"] + d * math.sin(p))


def project(cam: Dict[str, float], x: float, y: float, z: float) -> Tuple[float, float, float]:
    """世界座標 → 画面のピクセル(px, py)と奥行き。遠近の無い cam(persp なし)は、従来の真横の平行投影。"""
    if not cam.get("persp"):
        return (W / 2 + (x - cam["x"]) * cam["pxu"], 560 - z * cam["pxu"] + cam["sz"] * cam["pxu"], 1.0)
    f, r, u = basis(cam["yaw"], cam["pitch"])
    cx, cy, cz = position(cam)
    vx, vy, vz = x - cx, y - cy, z - cz
    zc = vx * f[0] + vy * f[1] + vz * f[2]
    xc = vx * r[0] + vy * r[1] + vz * r[2]
    yc = vx * u[0] + vy * u[1] + vz * u[2]
    k = f_px(cam["lens"]) / max(zc, 1e-3)
    return (W / 2 + xc * k, H / 2 - yc * k, zc)


def px_per_unit(cam: Dict[str, float], depth: float = None) -> float:
    """y=0 の面での、1単位あたりのピクセル(効果の大きさをそろえるのに使う)。"""
    if not cam.get("persp"):
        return cam["pxu"]
    return f_px(cam["lens"]) / (depth or cam["dist"])


MIN_CAM_Z = 0.3       # カメラが床の下に潜らない高さ


def make_cam(tx: float, tz: float, scale: float, yaw_deg: float, pitch_deg: float, lens: float, sx: float = 0.0, sz: float = 0.0,
             ground_px: float = 560.0, target_z: float = None, dutch: float = 0.0) -> Dict[str, float]:
    """カメラ1コマぶん。

    target_z を省くと、従来と同じく、地面(z=0)が画面の ground_px に来るように、向ける高さを決める。
    target_z を与えると、その高さを向く(寄り・低い位置・俯瞰のカットで使う)。pitch が負(下から見上げる)でも、
    カメラの高さが MIN_CAM_Z を下回らないよう、仰角を浅くする。dutch は画面の傾き(度、合成で回す)。
    """
    dist = dist_for_scale(scale, lens)
    pxu = f_px(lens) / dist
    tz0 = (ground_px - H / 2) / pxu if target_z is None else target_z
    pitch = pitch_deg
    low = tz0 + sz + dist * math.sin(math.radians(pitch))
    if low < MIN_CAM_Z:
        s = (MIN_CAM_Z - (tz0 + sz)) / dist
        pitch = math.degrees(math.asin(max(-1.0, min(1.0, s))))
    return dict(persp=True, tx=tx + sx, ty=0.0, tz=tz0 + sz, dist=dist, yaw=yaw_deg, pitch=pitch, lens=lens,
                x=tx + sx, scale=scale, pxu=pxu, sx=sx, sz=sz, dutch=dutch)

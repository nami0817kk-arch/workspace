"""球の動きを MuJoCo で決める。2 段に分ける。

1) 拳と球の衝突(punch_launch): 拳=半径4.5cmの球(有効質量 M・前後だけ動く)が速さ V で球に当たる。
   はね返りの強さ e は接触のばねの減衰比で作る(減衰比を二分法で合わせる)。打ち出しの速さはこの計算の結果。
   作りは episodes/gon-dodge/sim/punch_mj.py と同じ(式 v=(1+e)MV/(M+m) と 0.1km/h 以内で一致を確かめ済み)。
2) 飛ぶ球(simulate): 重力・空気の抵抗(と回転による曲がり)・床とマットへのぶつかり・転がりの摩擦。
出力は track.json: 時刻ごとの位置・向き(四元数)・速さと、ぶつかった瞬間の記録(効果音・効果に使う)。
"""
from __future__ import annotations

import json
import math
from pathlib import Path

import numpy as np

XML = """
<mujoco>
  <option timestep="0.0005" gravity="0 0 -9.81" density="1.2" viscosity="1.8e-5" integrator="implicitfast"/>
  <worldbody>
    <geom name="floor" priority="1" condim="6" type="plane" size="300 300 0.1" friction="0.7 0.02 0.03" solref="0.006 0.22"/>
    <geom name="mat" priority="1" condim="6" type="box" pos="{mx} 0 {mz}" size="{sx} {sy} {sz}" friction="0.9 0.05 0.01" solref="0.02 1.0"/>
    <body name="ball" pos="{bx} {by} {bz}">
      <freejoint/>
      <geom name="ball" type="sphere" size="{r}" mass="{m}" fluidshape="ellipsoid" condim="6" friction="0.7 0.02 0.03"/>
    </body>
  </worldbody>
</mujoco>
"""


def simulate(ball_pos, t_hit: float, ball: dict, mat: dict, t_max: float = 9.0, sample_hz: int = 480) -> dict:
    import mujoco

    r, m = ball["radius"], ball["mass"]
    sx, sy, sz = (v / 2 for v in mat["size"])
    xml = XML.format(mx=mat["x"], mz=sz, sx=sx, sy=sy, sz=sz, bx=ball_pos[0], by=ball_pos[1], bz=ball_pos[2], r=r, m=m)
    model = mujoco.MjModel.from_xml_string(xml)
    data = mujoco.MjData(model)
    gid = {n: mujoco.mj_name2id(model, mujoco.mjtObj.mjOBJ_GEOM, n) for n in ("floor", "mat", "ball")}
    a = math.radians(ball["angle_deg"])
    data.qvel[:3] = [ball["v0"] * math.cos(a), 0.0, ball["v0"] * math.sin(a)]
    data.qvel[3:6] = ball.get("spin", (0, 0, 0))
    mujoco.mj_forward(model, data)

    dt = model.opt.timestep
    every = max(1, round(1.0 / (sample_hz * dt)))
    rows, events = [], []
    touching = set()
    still = 0.0
    step = 0
    while data.time < t_max:
        if step % every == 0:
            rows.append([t_hit + data.time, *data.qpos[:7].tolist(), *data.qvel[:3].tolist()])
        vel_before = data.qvel[:3].copy()
        mujoco.mj_step(model, data)
        step += 1
        now = set()
        for i in range(data.ncon):
            c = data.contact[i]
            pair = {c.geom1, c.geom2}
            if gid["ball"] in pair:
                other = (pair - {gid["ball"]}).pop()
                now.add(other)
        for other in now - touching:
            name = "mat" if other == gid["mat"] else "floor"
            n = np.array([1.0, 0, 0]) if name == "mat" else np.array([0, 0, 1.0])
            vn = abs(float(vel_before @ n))
            if vn > 0.3:
                events.append(dict(t=t_hit + data.time, kind=name, speed=vn, pos=data.qpos[:3].tolist()))
        touching = now
        sp = float(np.linalg.norm(data.qvel[:3]))
        still = still + dt if sp < 0.03 else 0.0
        if still > 0.4:
            break
    rows.append([t_hit + data.time, *data.qpos[:7].tolist(), *data.qvel[:3].tolist()])
    stop = t_hit + data.time - still
    return dict(t_hit=t_hit, start=list(ball_pos), radius=r, rows=rows, events=events, t_stop=stop,
                v0=ball["v0"], mat_front=mat["x"] - sx, mat=mat)


PUNCH_XML = """
<mujoco>
  <option timestep="{dt}" gravity="0 0 0" integrator="implicit"/>
  <worldbody>
    <body name="fist"><joint type="slide" axis="1 0 0"/><inertial pos="0 0 0" mass="{mf}" diaginertia="1 1 1"/>
      <geom name="fg" contype="0" conaffinity="0" type="sphere" size="{rf}" mass="0"/></body>
    <body name="ball" pos="{bx} 0 0"><joint type="slide" axis="1 0 0"/><inertial pos="0 0 0" mass="{mb}" diaginertia="0.002 0.002 0.002"/>
      <geom name="bg" contype="0" conaffinity="0" type="sphere" size="{rb}" mass="0"/></body>
  </worldbody>
  <contact><pair geom1="fg" geom2="bg" condim="1" solref="0.004 {dr}" solimp="0.99 0.99 0.001"/></contact>
</mujoco>"""


def _collide(V, M, m, rb, dr, rf=0.045, dt=2e-6, T=0.03):
    import mujoco
    model = mujoco.MjModel.from_xml_string(PUNCH_XML.format(dt=dt, mf=M, rf=rf, mb=m, rb=rb, bx=rf + rb + 0.002, dr=dr))
    d = mujoco.MjData(model)
    d.qvel[0] = V
    mujoco.mj_forward(model, d)
    t_in = t_out = None
    for _ in range(int(T / dt)):
        mujoco.mj_step(model, d)
        if d.ncon and t_in is None:
            t_in = d.time
        if t_in is not None and not d.ncon and t_out is None:
            t_out = d.time
            break
    return float(d.qvel[1]), float(d.qvel[0]), (t_out - t_in) if t_out else None


def punch_launch(V: float, M: float, e: float, m: float, rb: float) -> dict:
    """拳(速さ V・有効質量 M)が球(質量 m・半径 rb)に当たったあとの球の速さを MuJoCo で出す。"""
    lo, hi = 0.01, 0.6                     # 減衰比が大きいほど e は小さい。壁(拳 1000kg)に当てて e を測り、二分法で合わせる
    for _ in range(18):
        dr = (lo + hi) / 2
        vb, vf, _ = _collide(V, 1000.0, m, rb, dr)
        e_now = (vb - vf) / V
        lo, hi = (dr, hi) if e_now > e else (lo, dr)
    vb, vf, tc = _collide(V, M, m, rb, dr)
    formula = (1 + e) * M * V / (M + m)
    return dict(fist_speed=V, eff_mass=M, e=e, damping=dr, e_measured=e_now, v_ball=vb, v_fist_after=vf,
                contact_ms=(tc or 0) * 1000, v_formula=formula)


class Track:
    """track.json を時刻で引く(t_hit より前は台の上で止まっている)。"""

    def __init__(self, d: dict):
        self.d = d
        a = np.array(d["rows"])
        self.t, self.pos, self.quat, self.vel = a[:, 0], a[:, 1:4], a[:, 4:8], a[:, 8:11]
        self.t_hit, self.r = d["t_hit"], d["radius"]

    def at(self, s: float):
        if s <= self.t_hit:
            return np.array(self.d["start"]), np.array([1.0, 0, 0, 0]), np.zeros(3)
        i = int(np.clip(np.searchsorted(self.t, s) - 1, 0, len(self.t) - 2))
        k = float(np.clip((s - self.t[i]) / (self.t[i + 1] - self.t[i]), 0, 1))
        p = self.pos[i] * (1 - k) + self.pos[i + 1] * k
        q = self.quat[i] * (1 - k) + self.quat[i + 1] * k
        v = self.vel[i] * (1 - k) + self.vel[i + 1] * k
        return p, q / np.linalg.norm(q), v

    def speed(self, s: float) -> float:
        return float(np.linalg.norm(self.at(s)[2]))

    def event(self, kind: str):
        return [e for e in self.d["events"] if e["kind"] == kind]


def run(probe: dict, sc: dict, out: Path) -> dict:
    """拳の測定(probe.json)から球を置く場所と当たる時刻を決めて、物理を回す。"""
    ts = np.array(probe["t"])
    fx = np.array(probe["front"]) @ np.array(probe["facing"])     # 前への出具合
    i_max = int(np.argmax(fx))
    x0 = fx[0]
    target = x0 + (fx[i_max] - x0) * sc["punch"]["contact_frac"]
    i = int(np.argmax(fx[: i_max + 1] >= target))
    # 当たる瞬間を前後の測定の間で補間する
    if i > 0:
        k = (target - fx[i - 1]) / max(fx[i] - fx[i - 1], 1e-9)
        t_hit = float(ts[i - 1] + k * (ts[i] - ts[i - 1]))
        front = np.array(probe["front"][i - 1]) * (1 - k) + np.array(probe["front"][i]) * k
    else:
        t_hit, front = float(ts[i]), np.array(probe["front"][i])
    r = sc["ball"]["radius"]
    f = np.array(probe["facing"])
    if f @ [1, 0, 0] < 0.95:
        raise SystemExit(f"人形が +x を向いていない(向き {f.round(2).tolist()})。球は +x に飛ばす前提")
    ball_pos = (front + f * (r + 0.004)).tolist()
    ball = dict(sc["ball"])
    p = sc["punch"]
    launch = None
    if "fist_speed" in p:                   # 打ち出しの速さは拳と球の衝突の計算で決める
        launch = punch_launch(p["fist_speed"], p["eff_mass"], p["e"], ball["mass"], r)
        ball["v0"] = launch["v_ball"]
    d = simulate(ball_pos, t_hit, ball, sc["mat"])
    d["launch"] = launch
    out.write_text(json.dumps(d), encoding="utf-8")
    return d

"""MuJoCo で足とボールの衝突を動かす。足=球(半径5cm・質量5kg・並進のみ)、ボール=球(半径11cm・430g)。重力なし。"""
import sys; sys.path.insert(0, '.')
import numpy as np, mujoco
from kick_model import *

XML = """
<mujoco>
  <option timestep="{dt}" gravity="0 0 0" cone="elliptic" impratio="10" integrator="implicit"/>
  <worldbody>
    <body name="foot" pos="0 0 0">
      <joint name="fx" type="slide" axis="1 0 0"/><joint name="fy" type="slide" axis="0 1 0"/><joint name="fz" type="slide" axis="0 0 1"/>
      <inertial pos="0 0 0" mass="{mf}" diaginertia="1 1 1"/>
      <geom name="fg" contype="0" conaffinity="0" type="sphere" size="{rf}" mass="0" friction="{mu} 0 0" solref="{ts} {dr}" solimp="0.99 0.99 0.001" condim="3"/>
    </body>
    <body name="ball" pos="0 0 0">
      <freejoint/>
      <inertial pos="0 0 0" mass="{mb}" diaginertia="{I} {I} {I}"/>
      <geom name="bg" contype="0" conaffinity="0" type="sphere" size="{rb}" mass="0" friction="{mu} 0 0" solref="{ts} {dr}" solimp="0.99 0.99 0.001" condim="3"/>
    </body>
  </worldbody>
  <contact><pair geom1="fg" geom2="bg" condim="3" friction="{mu} {mu} 0.001 0.0001 0.0001" solref="{ts} {dr}" solreffriction="{tf} 1" solimp="0.99 0.99 0.001"/></contact>
</mujoco>"""

def run(V, u, s_vec, dr=0.2, ts=0.002, dt=2e-5, T=0.03, mu=MU, tf=0.0004):
    m = mujoco.MjModel.from_xml_string(XML.format(dt=dt, rf=R_FOOT, mf=M_FOOT, mu=mu, ts=ts, dr=dr, rb=R_BALL, mb=M_BALL, I=I_BALL, tf=tf))
    d = mujoco.MjData(m)
    u = unit(u); s_vec = np.asarray(s_vec, float)
    dd = np.linalg.norm(s_vec); sin_t = dd/(R_BALL+R_FOOT); cos_t = np.sqrt(1-sin_t**2)
    sh = s_vec/dd if dd > 1e-12 else np.zeros(3)
    n = u*cos_t - sh*sin_t
    # ボール中心を原点、足の中心は接触時の位置より少し手前から
    gap = 0.005
    foot0 = -(R_BALL+R_FOOT+gap)*n  # 接触の向きに沿って gap だけ離す
    # 足の通り道が s_vec だけずれるよう、u に沿って戻した位置を使う
    foot_contact = -(R_BALL+R_FOOT)*n
    foot0 = foot_contact - gap*u
    d.qpos[0:3] = foot0; d.qvel[0:3] = V*u
    d.qpos[3:6] = 0; d.qpos[6] = 1  # ball free joint: pos, quat
    mujoco.mj_forward(m, d)
    for _ in range(int(T/dt)):
        mujoco.mj_step(m, d)
    vb = d.qvel[3:6].copy(); wb = d.qvel[6:9].copy()   # free joint: 速度(ワールド)・角速度(ボール座標=初期は同じ向き)
    return vb, wb, d.qvel[0:3].copy()

if __name__ == "__main__":
    V = 20.272
    for dr in [0.1, 0.2, 0.3, 0.4]:
        vb, wb, vf = run(V, [1, 0, 0], [0, 0, 0], dr=dr)
        print("dr", dr, "head-on ball", vb[0], "foot", vf[0], "e_est", (vb[0]-vf[0])/V)

"""ゴンのドッジボール回 3章「拳で打つ」: 拳とボールの正面衝突を MuJoCo で動かし、式と比べる。
拳=球(半径4.5cm・有効質量M・前後の動きだけ)、ボール=球(半径10.5cm・330g、モルテン D3C5000-L の直径約21cm・約330g)。重力なし。
反発の強さは接触のばね(solref の減衰比 dr)で決まるので、まず dr ごとの反発係数 e を測り、同じ dr で拳の速さと質量を振る。
式: ボールの速さ v = (1+e)·M·V / (M+m)   (V=拳の速さ、m=ボールの質量)
episodes/driveshot/sim/mj_impact.py(足とボール)を拳とボールに置き換えたもの。
実行: python episodes/gon-dodge/sim/punch_mj.py
"""
import numpy as np
import mujoco

M_BALL, R_BALL = 0.33, 0.105
R_FIST = 0.045

XML = """
<mujoco>
  <option timestep="{dt}" gravity="0 0 0" integrator="implicit"/>
  <worldbody>
    <body name="fist" pos="0 0 0">
      <joint name="fx" type="slide" axis="1 0 0"/>
      <inertial pos="0 0 0" mass="{mf}" diaginertia="1 1 1"/>
      <geom name="fg" contype="0" conaffinity="0" type="sphere" size="{rf}" mass="0"/>
    </body>
    <body name="ball" pos="{bx} 0 0">
      <joint name="bx" type="slide" axis="1 0 0"/>
      <inertial pos="0 0 0" mass="{mb}" diaginertia="0.002 0.002 0.002"/>
      <geom name="bg" contype="0" conaffinity="0" type="sphere" size="{rb}" mass="0"/>
    </body>
  </worldbody>
  <contact><pair geom1="fg" geom2="bg" condim="1" solref="{ts} {dr}" solimp="0.99 0.99 0.001"/></contact>
</mujoco>"""


def run(V, M, dr, ts=0.004, dt=2e-6, T=0.03):
    gap = 0.002
    m = mujoco.MjModel.from_xml_string(XML.format(dt=dt, mf=M, rf=R_FIST, mb=M_BALL, rb=R_BALL,
                                                  bx=R_FIST + R_BALL + gap, ts=ts, dr=dr))
    d = mujoco.MjData(m)
    d.qvel[0] = V
    mujoco.mj_forward(m, d)
    t_in = t_out = None
    for i in range(int(T / dt)):
        mujoco.mj_step(m, d)
        if d.ncon and t_in is None:
            t_in = d.time
        if t_in is not None and not d.ncon and t_out is None:
            t_out = d.time
    return d.qvel[1], d.qvel[0], (t_out - t_in) if (t_in is not None and t_out is not None) else None


def theory(V, M, e):
    return (1 + e) * M * V / (M + M_BALL)


if __name__ == "__main__":
    print("== 1) 減衰比 dr と反発係数 e (拳 1000kg ≒ 壁、9.14m/s で当てて測る) ==")
    cal = {}
    for dr in [0.08, 0.15, 0.25, 0.35]:
        vb, vf, tc = run(9.14, 1000.0, dr)
        e = (vb - vf) / 9.14
        cal[dr] = e
        print(f"dr={dr:.2f}  e={e:.3f}  接触 {tc*1000:.1f} ms")
    print()
    print("== 2) 拳の速さ × 有効質量 → ボールの速さ (MuJoCo / 式) ==")
    print("V[m/s]  M[kg]  dr    e      MuJoCo[km/h]  式[km/h]")
    for V in [7.0, 9.14, 11.2, 13.3]:
        for M in [1.0, 2.9, 6.9, 1000.0]:
            for dr in [0.08, 0.25]:
                vb, vf, tc = run(V, M, dr)
                e = cal[dr]
                print(f"{V:5.2f}  {M:6.1f}  {dr:.2f}  {e:.3f}  {vb*3.6:9.1f}    {theory(V, M, e)*3.6:7.1f}")

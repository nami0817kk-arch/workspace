"""検算: (1)衝突の閉じた式を手で展開した式、(2)MuJoCo の衝突、(3)別の積分法(DOP853)、(4)MuJoCo の軌道。"""
import sys; sys.path.insert(0,'.')
import numpy as np, mujoco
from scipy.integrate import solve_ivp
from kick_model import *
import mj_impact, side
V=20.272; TF=0.0004; DR=0.2555

print("(1) 閉じた式(くっつく場合) vs impact_theory")
for d in [0.02,0.04,0.06,0.08,0.10]:
    st=d/(R_BALL+R_FOOT); ct=np.sqrt(1-st**2)
    Jn=1.5*V*ct/(1/M_FOOT+1/M_BALL); Jt=V*st/(1/M_FOOT+1/M_BALL+R_BALL**2/I_BALL)
    assert Jt<MU*Jn
    sp=np.hypot(Jn,Jt)/M_BALL; om=R_BALL*Jt/I_BALL/(2*np.pi)
    u=np.array([1,0,0.]); v,w,n,th=impact_theory(V,u,np.array([0,0,d]))
    print(f" d={d*100:4.0f}cm 手計算 speed {sp:.3f} spin {om:.3f}rps | コード {np.linalg.norm(v):.3f} {abs(w[1])/(2*np.pi):.3f}")

print("(2) MuJoCo の衝突 vs 理論 (水平の足・横のずれ、仰角15度)")
b=np.radians(15); u=np.array([np.cos(b),0,np.sin(b)]); sh=np.array([0,1.0,0])
for d in [-0.02,-0.04,-0.06,-0.076]:
    v,w,n,th=impact_theory(V,u,d*sh); vb,wb,vf=mj_impact.run(V,u,d*sh,dr=DR,tf=TF)
    print(f" d={d*100:+5.1f}cm 理論 speed {np.linalg.norm(v):.2f} spin_z {w[2]/(2*np.pi):+.2f} | MuJoCo {np.linalg.norm(vb):.2f} {wb[2]/(2*np.pi):+.2f}")

print("(3) 別の積分法 DOP853(rtol 1e-11) vs RK4(1ms)")
def dop(v0,w):
    def f(t,y): return np.concatenate([y[3:],accel(y[3:],w)])
    ev=lambda x0: (lambda t,y: y[0]-x0)
    evs=[ev(WALL_X),ev(GOAL_X)]
    for e in evs: e.terminal=False
    r=solve_ivp(f,[0,3],np.array([0,0,R_BALL,*v0]),method='DOP853',rtol=1e-11,atol=1e-12,events=evs)
    return [r.y_events[0][0][:3], r.y_events[1][0][:3]]
cases=[("d0 20°",impact_theory(V,[np.cos(np.radians(20)),0,np.sin(np.radians(20))],[0,0,0])),
       ("上6cm 36.4°",None),("横-6cm",None)]
def mk_v(beta,d):
    b=np.radians(beta); u=np.array([np.cos(b),0,np.sin(b)]); sh=np.array([-np.sin(b),0,np.cos(b)]); return impact_theory(V,u,d*sh)
def mk_s(beta,psi,d):
    b,p=np.radians(beta),np.radians(psi); u=np.array([np.cos(b)*np.cos(p),np.cos(b)*np.sin(p),np.sin(b)]); sh=np.array([-np.sin(p),np.cos(p),0.]); return impact_theory(V,u,d*sh)
tests=[("真ん中20°",mk_v(20,0)),("上6cm 36.4°",mk_v(36.4,0.06)),("上4cm 28.8°",mk_v(28.8,0.04)),("下2cm 10°",mk_v(10,-0.02)),
       ("横-4cm el12.92 az-14.97",mk_s(12.92,-14.97,-0.04)),("横-6cm el14.44 az-22.88",mk_s(14.44,-22.88,-0.06))]
for name,(v,w,n,th) in tests:
    o=fly(v,w,dt=0.001); dd=dop(v,w)
    print(f" {name:26s} RK4 壁 z {o[WALL_X][0][2]:.4f} ゴール (y,z)=({o[GOAL_X][0][1]:+.4f},{o[GOAL_X][0][2]:.4f}) | DOP853 壁 z {dd[0][2]:.4f} ゴール ({dd[1][1]:+.4f},{dd[1][2]:.4f})")

print("(4) MuJoCo の軌道 (重力は MuJoCo、空気の力は外力) vs RK4")
XML="""<mujoco><option timestep="0.001" gravity="0 0 -9.81" integrator="RK4"/><worldbody><body name="b" pos="0 0 0.11"><freejoint/>
<inertial pos="0 0 0" mass="0.43" diaginertia="{I} {I} {I}"/><geom type="sphere" size="0.11" mass="0" contype="0" conaffinity="0"/></body></worldbody></mujoco>"""
def mjfly(v0,w):
    m=mujoco.MjModel.from_xml_string(XML.format(I=I_BALL)); d=mujoco.MjData(m)
    d.qpos[:3]=[0,0,R_BALL]; d.qvel[:3]=v0; res={}; pend=[WALL_X,GOAL_X]; prev=d.qpos[:3].copy()
    while pend:
        vel=d.qvel[:3].copy(); a=accel(vel,w)+np.array([0,0,G])   # 重力は MuJoCo に任せる
        d.xfrc_applied[1,:3]=M_BALL*a
        mujoco.mj_step(m,d)
        if d.qpos[0]>=pend[0]:
            fr=(pend[0]-prev[0])/(d.qpos[0]-prev[0]); res[pend[0]]=prev+fr*(d.qpos[:3]-prev); pend.pop(0)
        prev=d.qpos[:3].copy()
        if d.qpos[2]<0: break
    return res
for name,(v,w,n,th) in tests:
    r=mjfly(v,w); o=fly(v,w,dt=0.001)
    if GOAL_X in r:
        print(f" {name:26s} MuJoCo 壁 z {r[WALL_X][2]:.4f} ゴール ({r[GOAL_X][1]:+.4f},{r[GOAL_X][2]:.4f}) | RK4 {o[WALL_X][0][2]:.4f} ({o[GOAL_X][0][1]:+.4f},{o[GOAL_X][0][2]:.4f})")
    else: print(name,"MuJoCo 地面/壁前", r)

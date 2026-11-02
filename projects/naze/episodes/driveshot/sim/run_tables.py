"""実験6の表を作る(RK4・刻み1ms)。出力 results.txt"""
import sys; sys.path.insert(0,'.')
from kick_model import *
import side
V=20.272
def vshot(beta,d,dt=0.001):
    b=np.radians(beta); u=np.array([np.cos(b),0,np.sin(b)]); sh=np.array([-np.sin(b),0,np.cos(b)])
    v,w,n,th=impact_theory(V,u,d*sh); return v,w,n,fly(v,w,dt=dt)
def fmt(tag,beta,d):
    v,w,n,o=vshot(beta,d)
    zf=0.11-(R_BALL+R_FOOT)*n[2]
    wz=o[WALL_X][0][2] if WALL_X in o else float('nan'); gz=o[GOAL_X][0][2] if GOAL_X in o else float('nan')
    return (f"{tag:10s} d={d*100:+5.1f}cm foot_el={beta:5.2f} ball_speed={np.linalg.norm(v):5.2f} launch={np.degrees(np.arctan2(v[2],v[0])):5.2f} "
            f"spin_y={w[1]/(2*np.pi):+6.2f}rps wall_z={wz:5.2f} goal_z={gz:5.2f} t={(o[GOAL_X][2] if GOAL_X in o else float('nan')):.3f} stroke={100*(zf-R_FOOT)/np.sin(np.radians(beta)):6.1f}cm")
out=[]
out.append("# 縦の面 (足の向き=仰角 foot_el、d>0 は中心より上)")
for tag,beta,d in [("d0_el20",20,0),("d0_in",14.8,0),("low_el20",20,-0.04),("low_el15",15,-0.04),("up_el20",20,0.04),("up_fix",28.8,0.04),("up6_el20",20,0.06),("up6_fix",36.4,0.06)]:
    out.append(fmt(tag,beta,d))
out.append("# d ごとの成功窓(足の仰角) (sweep.py より)")
out.append("# 横の面 (足の向き=仰角 β と方位 ψ を解いて、ゴール中央 y=0・高さ1.30m に着ける)")
for d in [0,-0.02,-0.04,-0.06,-0.073]:
    beta,psi=side.solve(d,x0=(12.0+0.5*abs(d)*100,d*370))
    v,w,n,o=side.shot(beta,psi,d,dt=0.001); p=o[GOAL_X][0]
    # 足をまっすぐ(ψ=0)にしたままの場合: 同じ仰角で
    v2,w2,n2,o2=side.shot(beta,0.0,d,dt=0.001); p2=o2[GOAL_X][0]
    out.append(f"d={d*100:+5.1f}cm foot_el={beta:5.2f} foot_az={psi:6.2f} ball_speed={np.linalg.norm(v):5.2f} spin_z={w[2]/(2*np.pi):+5.2f}rps launch_az={np.degrees(np.arctan2(v[1],v[0])):+5.2f} launch_el={np.degrees(np.arcsin(v[2]/np.linalg.norm(v))):5.2f} goal(y,z)=({p[1]:+.3f},{p[2]:.3f}) t={o[GOAL_X][2]:.3f} | foot_az=0: goal(y,z)=({p2[1]:+.2f},{p2[2]:.2f}) max_y={'-'}")
print("\n".join(out)); open('results.txt','w',encoding='utf-8').write("\n".join(out))

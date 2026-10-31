import sys; sys.path.insert(0,'.')
from mj_impact import *
V=20.272; TF=0.0004
def e_of(dr):
    vb,wb,vf=run(V,[1,0,0],[0,0,0],dr=dr,tf=TF); return (vb[0]-vf[0])/V
lo,hi=0.2,0.3
for _ in range(12):
    m=(lo+hi)/2
    if e_of(m)>0.5: lo=m
    else: hi=m
DR=(lo+hi)/2; print("dr",round(DR,4),"e",round(e_of(DR),4))
b=np.radians(30); u=np.array([np.cos(b),0,np.sin(b)]); sh=np.array([-np.sin(b),0,np.cos(b)])
print("d_cm | theory speed spin(rps) dev_deg | mujoco speed spin dev_deg")
for d in [0,0.01,0.02,0.04,0.06,0.08,0.10,-0.04]:
    v,w,n,th=impact_theory(V,u,d*sh)
    vb,wb,vf=run(V,u,d*sh,dr=DR,tf=TF)
    la=lambda x: np.degrees(np.arctan2(x[2],x[0]))-30
    print(f"{d*100:5.0f} | {np.linalg.norm(v):6.2f} {w[1]/(2*np.pi):6.2f} {la(v):6.2f} | {np.linalg.norm(vb):6.2f} {wb[1]/(2*np.pi):6.2f} {la(vb):6.2f}")

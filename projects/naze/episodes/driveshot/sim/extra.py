import sys; sys.path.insert(0,'.')
from kick_model import *
import side
V=20.272
def vshot(beta,d,dt=0.002):
    b=np.radians(beta); u=np.array([np.cos(b),0,np.sin(b)]); sh=np.array([-np.sin(b),0,np.cos(b)])
    v,w,n,th=impact_theory(V,u,d*sh); return v,w,n,fly(v,w,dt=dt)
d=-0.076
beta,psi=side.solve(d,x0=(16,-28)); v,w,n,o=side.shot(beta,psi,d,dt=0.001); p=o[GOAL_X][0]
zf=0.11-(R_BALL+R_FOOT)*n[2]
print("7.8rps",beta,psi,np.linalg.norm(v),w[2]/6.2832,np.degrees(np.arctan2(v[1],v[0])),np.degrees(np.arcsin(v[2]/np.linalg.norm(v))),p,o[GOAL_X][2],(zf-.05)/np.sin(np.radians(beta)),flush=True)
v2,w2,n2,o2=side.shot(beta,0.0,d,dt=0.001); print(" foot straight",o2[GOAL_X][0],flush=True)
beta,psi=side.solve(-0.06,x0=(14.4,-22.9))
for dp in [-1,0,1]:
    v,w,n,o=side.shot(beta,psi+dp,-0.06,dt=0.001); print("dpsi",dp,o[GOAL_X][0][1:],flush=True)
def ok(beta,d):
    v,w,n,o=vshot(beta,d)
    return WALL_X in o and GOAL_X in o and o[WALL_X][0][2]>=1.91 and 0.11<=o[GOAL_X][0][2]<=2.33
print("backspin -2cm ok angles:",[b for b in np.arange(0,50,0.5) if ok(b,-0.02)],flush=True)
v,w,n,o=vshot(20,0.06); print("up6 el20",o.keys(),flush=True)
pos=np.array([0,0,.11]);vel=v.copy();dt=2e-3
while True:
    vel=vel+dt*accel(vel,w); pos=pos+dt*vel
    if pos[2]<0.11 and pos[0]>0.5: break
print("up6 el20 lands x=",pos[0],flush=True)
for e in [35.4,36.4,37.4]:
    v,w,n,o=vshot(e,0.06); print(e,o[WALL_X][0][2],o[GOAL_X][0][2],flush=True)
print("V needed for 28 at 6cm:",V*28/26.123)

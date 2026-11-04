import sys; sys.path.insert(0,'.')
from kick_model import *
V=20.272
DT=0.002
def shot(beta,d,V=V):
    b=np.radians(beta); u=np.array([np.cos(b),0,np.sin(b)]); sh=np.array([-np.sin(b),0,np.cos(b)])
    v,w,n,th=impact_theory(V,u,d*sh)
    o=fly(v,w,dt=DT)
    return v,w,n,o
def ok(beta,d):
    v,w,n,o=shot(beta,d)
    if GOAL_X not in o or WALL_X not in o: return False
    return o[WALL_X][0][2]>=WALL_Z_MIN and 0.11<=o[GOAL_X][0][2]<=BAR_Z_MAX
def window(d):
    bs=np.arange(0,70,0.5); okk=[b for b in bs if ok(b,d)]
    if not okk: return None
    lo,hi=min(okk),max(okk)
    def edge(a,b):  # a は ok でない側、b は ok の側
        for _ in range(14):
            m=(a+b)/2
            if ok(m,d): b=m
            else: a=m
        return b
    return edge(lo-0.5,lo),edge(hi+0.5,hi)
if __name__=="__main__":
  for d in [float(x) for x in sys.argv[1:]]:
    w=window(d)
    if not w: print(d,'none'); continue
    c=(w[0]+w[1])/2
    v,wv,n,o=shot(c,d)
    zf=0.11-(R_BALL+R_FOOT)*n[2]
    print(f"d={d*100:5.0f}cm window {w[0]:.2f}-{w[1]:.2f} width {w[1]-w[0]:.2f} center {c:.2f} speed {np.linalg.norm(v):.2f} spin {wv[1]/(2*np.pi):.2f}rps wall {o[WALL_X][0][2]:.2f} goal {o[GOAL_X][0][2]:.2f} footz {zf:.3f}")

import sys; sys.path.insert(0,'.')
from kick_model import *
V=20.272; DT=0.002
def shot(beta,psi,d,V=V,dt=DT):
    b,p=np.radians(beta),np.radians(psi)
    u=np.array([np.cos(b)*np.cos(p),np.cos(b)*np.sin(p),np.sin(b)])
    sh=np.array([-np.sin(p),np.cos(p),0.0])      # 左向きの水平
    v,w,n,th=impact_theory(V,u,d*sh)               # d>0: 足の通り道が中心の左 / d<0: 右(反時計回り=左へ曲がる)
    o=fly(v,w,dt=dt); return v,w,n,o
def solve(d,tz=1.30,ty=0.0,x0=(12.0,0.0)):
    x=np.array(x0)
    for it in range(25):
        def f(x):
            v,w,n,o=shot(x[0],x[1],d)
            p=o[GOAL_X][0]; return np.array([p[2]-tz,p[1]-ty])
        F=f(x)
        if np.abs(F).max()<2e-4: break
        Jm=np.zeros((2,2))
        for j in range(2):
            dx=np.zeros(2); dx[j]=0.05; Jm[:,j]=(f(x+dx)-F)/0.05
        x=x-np.linalg.solve(Jm,F)
    return x
if __name__=="__main__":
    for d in [float(a) for a in sys.argv[1:]]:
        beta,psi=solve(d)
        v,w,n,o=shot(beta,psi,d)
        p=o[GOAL_X][0]; zf=0.11-(R_BALL+R_FOOT)*n[2]
        print(f"d={d*100:5.1f}cm beta {beta:.2f} psi {psi:.2f} speed {np.linalg.norm(v):.2f} spin {w[2]/(2*np.pi):.2f}rps(z) launch_az {np.degrees(np.arctan2(v[1],v[0])):.2f} launch_el {np.degrees(np.arcsin(v[2]/np.linalg.norm(v))):.2f} goal y {p[1]:.3f} z {p[2]:.3f} t {o[GOAL_X][2]:.3f} stroke {100*(zf-R_FOOT)/np.sin(np.radians(beta)):.1f}cm",flush=True)

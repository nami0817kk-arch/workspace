import numpy as np
c=299792458; es,einf,tau=78.36,5.2,8.27e-12
def eps(f):
    w=2*np.pi*f; e=einf+(es-einf)/(1+1j*w*tau); return e.real,-e.imag
def dp(f,e1,e2):
    l0=c/f; return l0/(2*np.pi*np.sqrt(2*e1))/np.sqrt(np.sqrt(1+(e2/e1)**2)-1)
D=dp(2.45e9,*eps(2.45e9))
def run(T,P=500.0,pulse=None,stop=100.0):
    A=0.01; N=200; z=np.linspace(0,T,N); dz=z[1]-z[0]
    rc=4.18e6; a=0.6/rc
    shape=np.exp(-z/D)+np.exp(-(T-z)/D); shape=shape/(shape.sum()*dz*A)
    Tm=np.full(N,5.0); t=0.0; dt=0.4*dz*dz/a
    while Tm.max()<stop and t<7200:
        on=1.0 if pulse is None else (1.0 if (t%pulse[1])<pulse[0] else 0.0)
        lap=np.zeros(N); lap[1:-1]=(Tm[2:]-2*Tm[1:-1]+Tm[:-2])/dz**2
        lap[0]=2*(Tm[1]-Tm[0])/dz**2; lap[-1]=2*(Tm[-2]-Tm[-1])/dz**2
        Tm=Tm+dt*(a*lap+P*shape*on/rc); t+=dt
    return t,Tm[N//2],int(np.argmax(Tm))*T/(N-1)*100
for T in [0.02,0.04,0.06,0.10]:
    t,cen,zm=run(T); print(f"{T*100:.0f}cm 重さ{T*1e5:.0f}g: 最高点が100度 {t:.0f}秒, 中心 {cen:.0f}度, 最高点の深さ {zm:.1f}cm")
for T in [0.06,0.10]:
    t,cen,zm=run(T,P=500,pulse=(10,30)); print(f"休み休み {T*100:.0f}cm: {t:.0f}秒 中心 {cen:.0f}度")

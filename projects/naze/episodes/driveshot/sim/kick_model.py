"""ドライブシュート回 実験6「蹴り方」: 剛体の衝突の理論式と空気の力つきの軌道。
座標: x=ゴールへ前、y=左、z=上。単位は SI。置いた値は research.md の「2d」に一覧。"""
import numpy as np

M_BALL, R_BALL = 0.43, 0.11
I_BALL = 2.0 / 3.0 * M_BALL * R_BALL**2        # 薄い殻と置く
RHO = 1.204
AREA = np.pi * R_BALL**2
G = 9.81
M_FOOT, R_FOOT = 5.0, 0.05                       # 仮置き: 有効質量5kg、足先を半径5cmの球と置く
E_REST, MU = 0.5, 0.5                            # 仮置き: 反発係数、摩擦係数
WALL_X, GOAL_X = 9.15, 20.0
WALL_Z_MIN, BAR_Z_MAX = 1.91, 2.33
HALF_GOAL = 3.66 - R_BALL


def unit(a):
    a = np.asarray(a, float)
    return a / np.linalg.norm(a)


def impact_theory(V, u, s_vec, M=M_FOOT, e=E_REST, mu=MU, rf=R_FOOT):
    """足(質量M・速さV・向きu・並進のみ)がボール(静止)に当たる。s_vec=足の通り道のボール中心からのずれ(uに直角)。
    返り値: ボールの速度, 角速度, 法線n, θ"""
    u = unit(u)
    s_vec = np.asarray(s_vec, float)
    d = np.linalg.norm(s_vec)
    sin_t = d / (R_BALL + rf)
    cos_t = np.sqrt(1 - sin_t**2)
    sh = s_vec / d if d > 1e-12 else np.zeros(3)
    n = u * cos_t - sh * sin_t                   # 足からボールへ押す向き
    vn = V * cos_t
    Jn = (1 + e) * vn / (1 / M + 1 / M_BALL)
    vt_vec = V * u - vn * n
    vt = np.linalg.norm(vt_vec)
    if vt < 1e-12:
        t = np.zeros(3); Jt = 0.0
    else:
        t = vt_vec / vt
        Jt = min(mu * Jn, vt / (1 / M + 1 / M_BALL + R_BALL**2 / I_BALL))
    J = Jn * n + Jt * t
    v = J / M_BALL
    rho = -R_BALL * n
    w = np.cross(rho, J) / I_BALL
    return v, w, n, np.arcsin(sin_t)


def cd_of(v):
    if v >= 16: return 0.2
    if v <= 10: return 0.4
    return 0.2 + 0.2 * (16 - v) / 6


def accel(vel, w, cd_scale_fn=cd_of):
    sp = np.linalg.norm(vel)
    a = np.array([0, 0, -G])
    a = a - 0.5 * RHO * AREA * cd_scale_fn(sp) * sp * vel / M_BALL
    vh = vel / sp
    w_perp = w - np.dot(w, vh) * vh
    wp = np.linalg.norm(w_perp)
    if wp > 1e-9:
        Sp = R_BALL * wp / sp
        CL = min(1.2 * Sp, 0.30)
        dirm = unit(np.cross(w_perp, vel))
        a = a + 0.5 * RHO * AREA * CL * sp**2 * dirm / M_BALL
    return a


def fly(v0, w, dt=1e-3, method="rk4", xs=(WALL_X, GOAL_X)):
    """x=xs を通るときの (位置, 速度, 時刻) を返す。回転は減らさない。"""
    pos = np.array([0, 0, R_BALL], float); vel = np.array(v0, float); t = 0.0
    out = {}
    pend = list(xs)
    while pend and t < 5 and pos[2] > 0 and vel[0] > 0.5:
        def f(p, v): return v, accel(v, w)
        if method == "rk4":
            k1 = f(pos, vel); k2 = f(pos + .5*dt*k1[0], vel + .5*dt*k1[1])
            k3 = f(pos + .5*dt*k2[0], vel + .5*dt*k2[1]); k4 = f(pos + dt*k3[0], vel + dt*k3[1])
            npos = pos + dt/6*(k1[0] + 2*k2[0] + 2*k3[0] + k4[0])
            nvel = vel + dt/6*(k1[1] + 2*k2[1] + 2*k3[1] + k4[1])
        else:  # 半陰的オイラー(粗い別法。刻みを細かくして比べる)
            nvel = vel + dt*accel(vel, w); npos = pos + dt*nvel
        if npos[0] >= pend[0]:
            fr = (pend[0] - pos[0]) / (npos[0] - pos[0])
            out[pend[0]] = (pos + fr*(npos - pos), vel + fr*(nvel - vel), t + fr*dt)
            pend.pop(0)
        pos, vel, t = npos, nvel, t + dt
    return out


def rpm_rps(w): return np.linalg.norm(w) / (2*np.pi)

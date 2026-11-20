"""海面の回の数字を、重力の模型 EGM2008(5分角)から自分で測る。結果は calc.txt。"""
import io, sys
from pathlib import Path
import numpy as np
sys.path.insert(0, str(Path(__file__).resolve().parents[3]))
from naze import geoid
out = io.StringIO()
def p(*a): print(*a); print(*a, file=out)
N, lats, lons = geoid.grid()
i = np.unravel_index(np.argmin(N), N.shape); j = np.unravel_index(np.argmax(N), N.shape)
p(f"いちばん低い: {N[i]:.1f} m  緯度 {lats[i[0]]:.2f} 経度 {lons[i[1]]:.2f}")
p(f"いちばん高い: {N[j]:.1f} m  緯度 {lats[j[0]]:.2f} 経度 {lons[j[1]]:.2f}")
p(f"差: {N[j]-N[i]:.1f} m")
R = 6371.0
# 傾き(縦の線の傾き = ジオイドの坂)
la = np.radians(lats)[:, None]
dy = R * np.radians(geoid.STEP) * 1000
dx = dy * np.cos(la)
gy = np.gradient(N.astype(np.float64), axis=0) / dy
gx = (np.roll(N, -1, 1) - np.roll(N, 1, 1)) / (2 * np.maximum(dx, 1))
s = np.hypot(gx, gy)
band = np.abs(lats) < 80
p(f"坂の真ん中(緯度80度まで): {np.median(s[band])*1e3:.3f} m/km  → 1m 下がるのに {1/np.median(s[band])/1000:.0f} km")
# くぼみの底から、まわりへの断面(東西・南北)
y0, x0 = i
for name, (dyi, dxi) in {"北": (-1, 0), "南": (1, 0), "東": (0, 1), "西": (0, -1)}.items():
    for k in range(1, 900):
        y, x = y0 + dyi * k, (x0 + dxi * k) % N.shape[1]
        if N[y, x] >= 0:
            d = k * geoid.STEP * 111.2 * (np.cos(np.radians(lats[y0])) if dxi else 1)
            p(f"底から{name}へ、海面が 0m に戻るまで {d:.0f} km(平均の坂: {(-N[i])/d:.3f} m/km、1m に {d/(-N[i]):.1f} km)")
            break
m = N < -50
p(f"-50m より低い広さ: {np.sum(m * (dy/1000) * (dx/1000)):.3g} km²(日本 37.8万 km² の {np.sum(m*(dy/1000)*(dx/1000))/378000:.1f} 倍)")
sm = s[200:-200, :]
p(f"いちばん急な坂: {sm.max()*1e3:.2f} m/km = 糸の傾き {np.degrees(sm.max())*3600:.0f} 秒角({np.degrees(sm.max()):.4f} 度)")
# くぼみのまわりの坂の最大
box = s[max(y0-240,0):y0+240, x0-300:x0+300]
p(f"くぼみのまわりの坂の最大: {box.max()*1e3:.3f} m/km(1m に {1/box.max()/1000:.0f} km)  糸の傾き {np.degrees(box.max())*3600:.1f} 秒角")
for nm, (a, b) in {"東京": (35.69, 139.70), "富士山頂": (35.3606, 138.7274), "父島": (27.09, 142.19), "与那国": (24.47, 123.0)}.items():
    p(f"{nm}: EGM2008 {geoid.at(a, b):.1f} m")
(Path(__file__).with_name("calc.txt")).write_text(out.getvalue(), encoding="utf-8")

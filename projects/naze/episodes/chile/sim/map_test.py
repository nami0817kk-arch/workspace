"""世界の地図の仕組み(naze/worldmap.py)の試し描き。out/chile/map_test/ に4コマ。python episodes/chile/sim/map_test.py"""
import os
import sys
import time

os.environ["NAZE_ASPECT"] = "landscape"
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
sys.path.insert(0, ROOT)
from PIL import Image  # noqa: E402

from naze import worldmap as wm  # noqa: E402

OUT = os.path.join(ROOT, "out", "chile", "map_test")
os.makedirs(OUT, exist_ok=True)
t0 = time.time()
M = wm.Map(lat0=-35, bases=[((-100, -62, -20, 16), 5), ((-82, -58, -50, -14), 6), ((-78, -57, -64, -16), 8)])
_ = M.bases
print("下地", time.time() - t0)
tests = {
 "a_wide": (dict(view=(-62, -24, 75, 0), layers=[dict(kind="fill", code="CHL", alpha=0.55)])),
 "b_tilt": (dict(step=1, view=(-68, -36, 40, 50), layers=[dict(kind="fill", code="CHL", alpha=0.5), dict(kind="border", a="CHL", b="ARG", color=(255,255,255), width=5, glow=True),
     dict(kind="pin", at_ll=(-70.65, -33.45), text="サンティアゴ")])),
 "c_close": (dict(view=(-70.5, -31.5, 9, 30), layers=[dict(kind="outline", code="CHL", color=(240,90,80), width=5), dict(kind="hlines", rows=[(-31.55, -71.6, -70.5)]),
     dict(kind="label", at_ll=(-71.0, -31.2), text="93km", color=(255,214,64), size=60)], panel=dict(kind="profile", a=(-72.5, -27.1), b=(-68.0, -27.1), title="南緯27度の断面", names=[(0.95, "アンデス")]))),
 "d_ghost": (dict(view=(-62, -36, 60, 20), layers=[dict(kind="fill", code="CHL", alpha=0.55), dict(kind="ghost", code="JPN", at_ll=(-45, -36))])),
}
for name, sc in tests.items():
    img = Image.new("RGBA", (wm.W, wm.H))
    line = dict(id="x", start=0, end=6)
    ctx = dict(lines=[line], defs={"x": dict(id="x", scene=sc)}, cur=line)
    t1 = time.time()
    M.draw(img, 3.0, ctx, steps=["1 測る", "2 東の壁", "3 西の海", "4 北", "5 南"]) if name != "a_wide" else M.draw(img, 3.0, ctx)
    print(name, round(time.time() - t1, 2))
    img.convert("RGB").save(os.path.join(OUT, name + ".jpg"), quality=88)

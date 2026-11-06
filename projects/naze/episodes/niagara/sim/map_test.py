"""ナイアガラの地図の試し描き。out/niagara/map_test/ に。python episodes/niagara/sim/map_test.py"""
import json, os, sys, time
os.environ["NAZE_ASPECT"] = "landscape"
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
sys.path.insert(0, ROOT)
from PIL import Image  # noqa: E402
from naze import worldmap as wm  # noqa: E402
OUT = os.path.join(ROOT, "out", "niagara", "map_test"); os.makedirs(OUT, exist_ok=True)
RIVER = [(b, a) for a, b in json.load(open(os.path.join(ROOT, "episodes/niagara/sim/river.json"), encoding="utf-8"))["pts"]]
t0 = time.time()
M = wm.Map(lat0=43, bases=[((-94, 39, -72, 50), 6), ((-84, 41, -76, 45.5), 8), ((-79.5, 42.7, -78.6, 43.4), 11), ((-79.15, 43.03, -79.0, 43.18), 13)])
_ = M.bases
print("下地", round(time.time() - t0, 1))
Y, W_ = (255, 214, 64), (255, 255, 255)
tests = {
 "a_lakes": dict(view=(-82, 44.5, 20, 30), layers=[dict(kind="line", pts=RIVER, color=Y, width=6, glow=True)]),
 "b_two": dict(view=(-79.3, 43.0, 3.6, 40), layers=[dict(kind="line", pts=RIVER, color=Y, width=5, glow=True),
     dict(kind="label", at_ll=(-79.8, 42.55), text="エリー湖", size=56), dict(kind="label", at_ll=(-79.0, 43.55), text="オンタリオ湖", size=56)]),
 "c_river": dict(view=(-79.0, 43.06, 0.55, 45), layers=[dict(kind="line", pts=RIVER, color=Y, width=5)]),
 "d_falls": dict(view=(-79.07, 43.10, 0.09, 50), layers=[dict(kind="pin", at_ll=(-79.0755, 43.0775), text="馬蹄滝")]),
}
for name, sc in tests.items():
    img = Image.new("RGBA", (wm.W, wm.H)); line = dict(id="x", start=0, end=6)
    t1 = time.time()
    M.draw(img, 3.0, dict(lines=[line], defs={"x": dict(id="x", scene=sc)}, cur=line))
    print(name, round(time.time() - t1, 2))
    img.convert("RGB").save(os.path.join(OUT, name + ".jpg"), quality=88)

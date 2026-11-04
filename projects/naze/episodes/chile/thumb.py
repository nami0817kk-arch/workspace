"""チリの本編のサムネイル(1280×720)。下地は本編と同じ立体の地図(チリを赤く・峰の国境を光らせる)、字は右に。
python episodes/chile/thumb.py → out/chile/thumb_long.jpg"""
import os
import sys
from pathlib import Path

os.environ["NAZE_ASPECT"] = "landscape"
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parents[1]))
sys.path.insert(0, str(HERE))
import numpy as np  # noqa: E402
from PIL import Image, ImageDraw  # noqa: E402

import scene  # noqa: E402
from naze import overlay as O  # noqa: E402
from naze.config import H, W  # noqa: E402

OUT = HERE.parents[1] / "out" / "chile"
OUT.mkdir(parents=True, exist_ok=True)
NAVY, YEL, WHITE, RED = (10, 10, 10), (255, 225, 0), (255, 255, 255), (255, 70, 60)

M = scene.MAP
sc = dict(shot="map", view=(-58, -33, 46, 50), layers=[
    dict(kind="fill", code="CHL", color=(255, 60, 50), alpha=0.75, id="c", sheen=False),
    dict(kind="border", a="CHL", b="ARG", color=(255, 255, 255), width=6, glow=True, id="b"),
    dict(kind="border", a="CHL", b="BOL", color=(255, 255, 255), width=6, glow=True, id="b2")])
line = dict(id="x", start=0, end=6, text="")
img = Image.new("RGBA", (W, H))
M.finish = False
M.draw(img, 5.0, dict(lines=[line], defs={"x": dict(id="x", scene=sc)}, cur=line))
# 右側を暗くして字を立たせる
xs = np.arange(W)[None, :]
alpha = (200 * np.clip((xs - W * 0.42) / (W * 0.3), 0, 1) * np.ones((H, 1))).astype("uint8")
sh = Image.fromarray(np.dstack([np.full((H, W), 6, "uint8"), np.full((H, W), 10, "uint8"), np.full((H, W), 24, "uint8"), alpha]), "RGBA")
img = Image.alpha_composite(img, sh)
d = ImageDraw.Draw(img)


def line_(x, y, parts, size, stroke=None):
    stroke = stroke or int(size * 0.085)
    f = O.font(size)
    for t, col in parts:
        d.text((x, y), t, font=f, fill=col, stroke_width=stroke, stroke_fill=NAVY)
        x += f.getlength(t)


x = 900
line_(x, 120, [("日本の", WHITE), ("2倍", YEL), ("の広さ", WHITE)], 96)
line_(x, 270, [("なのに幅", WHITE)], 150)
line_(x - 20, 450, [("93km", YEL)], 230)
line_(x, 760, [("なぜ", WHITE), ("細い", RED), ("？", WHITE)], 150)
line_(x + 10, 960, [("国境のデータで自分で測った", WHITE)], 52, 6)
img.convert("RGB").resize((1280, 720), Image.LANCZOS).save(OUT / "thumb_long.jpg", quality=93)
print(OUT / "thumb_long.jpg")

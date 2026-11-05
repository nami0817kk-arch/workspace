"""チリの本編のサムネイル(1280×720)。python episodes/chile/thumb.py → out/chile/thumb_long.jpg
2026-11-05 人気の地理の回 12 本を見て作り直し: 大陸の形がひと目で分かる真上の地図・字は大きく 3 行まで・主役を矢印で指す・比べる物を並べる。
比べる物は日本の形(本当の大きさ)。チリのすぐ西の海に置く。"""
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
VIEW = (-66, -33, 104, 0)                                   # 真上から南米ぜんぶ
JPN_AT = (-95, -45)                                        # 日本の形を置く所(チリの西の海)

M = scene.MAP
sc = dict(shot="map", view=VIEW, layers=[
    dict(kind="fill", code="CHL", color=(255, 50, 40), alpha=0.95, id="c", sheen=False),
    dict(kind="ghost", code="JPN", at_ll=JPN_AT, id="j")])
line = dict(id="x", start=0, end=6, text="")
img = Image.new("RGBA", (W, H))
M.finish = False
M.draw(img, 5.0, dict(lines=[line], defs={"x": dict(id="x", scene=sc)}, cur=line))
v = M.view(*VIEW)
# 右側を暗くして字を立たせる
xs = np.arange(W)[None, :]
alpha = (215 * np.clip((xs - W * 0.50) / (W * 0.12), 0, 1) * np.ones((H, 1))).astype("uint8")
sh = Image.fromarray(np.dstack([np.full((H, W), 6, "uint8"), np.full((H, W), 10, "uint8"), np.full((H, W), 24, "uint8"), alpha]), "RGBA")
img = Image.alpha_composite(img, sh)
d = ImageDraw.Draw(img)


def text(x, y, parts, size, stroke=None, anchor="ls"):
    stroke = stroke or int(size * 0.09)
    f = O.font(size)
    for t, col in parts:
        d.text((x, y), t, font=f, fill=col, stroke_width=stroke, stroke_fill=NAVY, anchor=anchor)
        x += f.getlength(t)


def arrow(p0, p1, col, w=14):
    d.line([p0, p1], fill=NAVY, width=w + 10)
    d.line([p0, p1], fill=col, width=w)
    a = np.array(p1, float) - np.array(p0, float)
    a /= np.linalg.norm(a)
    n = np.array([-a[1], a[0]])
    tip = np.array(p1, float)
    pts = [tuple(tip + a * 30), tuple(tip - a * 20 + n * 30), tuple(tip - a * 20 - n * 30)]
    d.polygon(pts, fill=col, outline=NAVY, width=5)


# 地図の上: チリを矢印で指す・日本に名前
cx, cy = v.px(-71.0, -27)
arrow((cx - 260, cy - 120), (cx - 40, cy - 10), RED)
text(cx - 270, cy - 140, [("チリ", WHITE)], 100, anchor="rs")
jx, jy = v.px(*JPN_AT)
text(jx, jy - 230, [("日本", WHITE)], 72, anchor="ms")
text(jx, jy - 170, [("同じ縮尺", (220, 226, 240))], 40, anchor="ms")

# 右の字: 3 行
x = 1000
text(x, 330, [("広さは日本の", WHITE), ("2倍", YEL)], 100)
text(x, 600, [("幅", WHITE), ("93", YEL), ("km", YEL)], 260)
text(x, 860, [("なぜ", WHITE), ("細い", RED), ("？", WHITE)], 170)
img.convert("RGB").resize((1280, 720), Image.LANCZOS).save(OUT / "thumb_long.jpg", quality=93)
print(OUT / "thumb_long.jpg")

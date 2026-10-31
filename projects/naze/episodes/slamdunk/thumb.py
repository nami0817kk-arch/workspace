"""スラムダンクの本編のサムネイル(1280×720)。作品の絵は使わない。下地は Gemini の絵(assets/thumb_gemini3.jpg: シュートを打つ選手と体育館の時計)。python episodes/slamdunk/thumb.py"""
import os
import sys
from pathlib import Path

os.environ["NAZE_ASPECT"] = "landscape"
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parents[1]))
import numpy as np  # noqa: E402
from PIL import Image, ImageDraw, ImageEnhance  # noqa: E402

from naze import overlay as O  # noqa: E402

OUT = HERE.parents[1] / "out" / "slamdunk"
OUT.mkdir(parents=True, exist_ok=True)
W, H = 2560, 1440
NAVY, YEL, WHITE = (10, 10, 10), (255, 225, 0), (255, 255, 255)
RED, CYAN = (255, 60, 60), (90, 230, 255)

src = Image.open(HERE / "assets" / "thumb_gemini3.jpg").convert("RGB")
s = max(W / src.width, H / src.height)
src = src.resize((int(src.width * s + 1), int(src.height * s + 1)), Image.LANCZOS).crop((0, 0, W, H))
src = ImageEnhance.Color(src).enhance(1.1)
img = src.convert("RGBA")
xs = np.arange(W)[None, :]
alpha = (150 * np.clip(1 - xs / 1700, 0, 1) ** 1.2 * np.ones((H, 1))).astype("uint8")
sh = Image.fromarray(np.dstack([np.zeros((H, W), "uint8"), np.full((H, W), 8, "uint8"), np.full((H, W), 30, "uint8"), alpha]), "RGBA")
ys = np.arange(H)[:, None]
vign = (170 * np.clip(1 - ys / 520, 0, 1) ** 1.5 + 190 * np.clip((ys - 820) / 620, 0, 1) ** 1.3) * np.ones((1, W))
vg = Image.fromarray(np.dstack([np.zeros((H, W), "uint8")] * 3 + [vign.astype("uint8")]), "RGBA")
img = Image.alpha_composite(img, vg)
d = ImageDraw.Draw(img)


def line(x, y, parts, size, stroke=None):
    stroke = stroke or int(size * 0.085)
    f = O.font(size)
    for t, col in parts:
        d.text((x, y), t, font=f, fill=col, stroke_width=stroke, stroke_fill=NAVY)
        x += f.getlength(t)


x = 60
line(x, 40, [("山王戦ラスト", WHITE)], 140)
line(x, 170, [("スラムダンク", YEL)], 270)
line(x, 880, [("残り1秒で", WHITE), ("間に合う？", RED)], 215)
line(x, 1140, [("計算で確かめる", CYAN)], 215)
img.convert("RGB").resize((1280, 720), Image.LANCZOS).save(OUT / "thumb_long.jpg", quality=93)
print(OUT / "thumb_long.jpg")

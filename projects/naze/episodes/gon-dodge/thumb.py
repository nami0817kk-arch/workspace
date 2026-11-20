"""ゴンのドッジボールの本編のサムネイル(1280×720)。下地は Gemini の絵(assets/thumb_gemini.jpg: 拳がドッジボールを殴る瞬間、左は暗い余白)。
人物・作品の絵は使わない。字はロケットの回と同じ形(箱なし・白＋黄＋赤・左に暗い下ざらえ)。python episodes/gon-dodge/thumb.py"""
import os
import sys
from pathlib import Path

os.environ["NAZE_ASPECT"] = "landscape"
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parents[1]))
import numpy as np  # noqa: E402
from PIL import Image, ImageDraw, ImageEnhance  # noqa: E402

from naze import overlay as O  # noqa: E402

OUT = HERE.parents[1] / "out" / "gon-dodge"
OUT.mkdir(parents=True, exist_ok=True)
W, H = 2560, 1440
NAVY, YEL, WHITE = (10, 10, 10), (255, 225, 0), (255, 255, 255)
RED, CYAN = (255, 60, 60), (90, 230, 255)

src = Image.open(HERE / "assets" / "thumb_gemini.jpg").convert("RGB")
s = max(W / src.width, H / src.height)
src = src.resize((int(src.width * s + 1), int(src.height * s + 1)), Image.LANCZOS).crop((0, 0, W, H))
src = ImageEnhance.Color(src).enhance(1.1)
img = src.convert("RGBA")
xs = np.arange(W)[None, :]
alpha = (170 * np.clip(1 - xs / 1500, 0, 1) ** 1.2 * np.ones((H, 1))).astype("uint8")
sh = Image.fromarray(np.dstack([np.zeros((H, W), "uint8"), np.full((H, W), 8, "uint8"), np.full((H, W), 30, "uint8"), alpha]), "RGBA")
img = Image.alpha_composite(img, sh)
d = ImageDraw.Draw(img)


def line(x, y, parts, size, stroke=None):
    stroke = stroke or int(size * 0.085)
    f = O.font(size)
    for t, col in parts:
        d.text((x, y), t, font=f, fill=col, stroke_width=stroke, stroke_fill=NAVY)
        x += f.getlength(t)


x = 60
line(x, 50, [("ハンターハンターのドッジボール", WHITE)], 100)
line(x, 180, [("ゴンの拳の", WHITE), ("一球", YEL)], 220)
line(x, 900, [("時速", WHITE), ("2,420km", YEL)], 230)
line(x, 1150, [("以上", RED)], 200)
line(560, 1200, [("人間の限界の", WHITE), ("16倍", YEL), ("以上", WHITE)], 90, 8)
img.convert("RGB").resize((1280, 720), Image.LANCZOS).save(OUT / "thumb_long.jpg", quality=93)
print(OUT / "thumb_long.jpg")

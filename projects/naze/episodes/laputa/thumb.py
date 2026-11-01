"""ラピュタの本編のサムネイル(1280×720)。下地は Gemini の絵(assets/thumb_gemini.jpg: 夕方の雲海、白い巨大な気球に吊られた岩の島、右寄り)。
作品の絵は使わない。字はロケットの回と同じ形(箱なし・白＋黄＋赤・左に暗い下ざらえ)。python episodes/laputa/thumb.py"""
import os
import sys
from pathlib import Path

os.environ["NAZE_ASPECT"] = "landscape"
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parents[1]))
import numpy as np  # noqa: E402
from PIL import Image, ImageDraw, ImageEnhance  # noqa: E402

from naze import overlay as O  # noqa: E402

OUT = HERE.parents[1] / "out" / "laputa"
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
alpha = (150 * np.clip(1 - xs / 1600, 0, 1) ** 1.2 * np.ones((H, 1))).astype("uint8")
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
line(x, 50, [("天空の城ラピュタを", WHITE)], 130)
line(x, 200, [("風船", YEL), ("で浮かせる", WHITE)], 220)
line(x, 900, [("ヘリウム", WHITE), ("全部", YEL), ("でも", WHITE)], 150)
line(x, 1080, [("40分の1", RED)], 250)
line(1000, 1200, [("最後の敵は", WHITE), ("意外なもの", YEL)], 90, 8)
img.convert("RGB").resize((1280, 720), Image.LANCZOS).save(OUT / "thumb_long.jpg", quality=93)
print(OUT / "thumb_long.jpg")

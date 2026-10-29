"""ロケットの本編のサムネイル(1280×720)。下地は Gemini の絵(assets/thumb_gemini.jpg: 青空から宇宙へ上昇する白いロケット、右寄り)。
形は深海魚の回と同じ(字は絵の上に直接・箱なし・白＋黄・左に暗い下ざらえ)。python episodes/rocket/thumb.py"""
import os
import sys
from pathlib import Path

os.environ["NAZE_ASPECT"] = "landscape"
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parents[1]))
import numpy as np  # noqa: E402
from PIL import Image, ImageDraw, ImageEnhance  # noqa: E402

from naze import overlay as O  # noqa: E402

OUT = HERE.parents[1] / "out" / "rocket"
OUT.mkdir(parents=True, exist_ok=True)
W, H = 2560, 1440
NAVY, YEL, WHITE = (0, 6, 24), (255, 222, 40), (255, 255, 255)

src = Image.open(HERE / "assets" / "thumb_gemini.jpg").convert("RGB")
s = max(W / src.width, H / src.height)
src = src.resize((int(src.width * s + 1), int(src.height * s + 1)), Image.LANCZOS).crop((0, 0, W, H))
src = ImageEnhance.Color(src).enhance(1.1)
img = src.convert("RGBA")
xs = np.arange(W)[None, :]
alpha = (150 * np.clip(1 - xs / 1700, 0, 1) ** 1.2 * np.ones((H, 1))).astype("uint8")
sh = Image.fromarray(np.dstack([np.zeros((H, W), "uint8"), np.full((H, W), 8, "uint8"), np.full((H, W), 30, "uint8"), alpha]), "RGBA")
img.alpha_composite(sh)
d = ImageDraw.Draw(img)


def line(x, y, parts, size, stroke=12):
    f = O.font(size)
    for t, col in parts:
        d.text((x, y), t, font=f, fill=col, stroke_width=stroke, stroke_fill=NAVY)
        x += f.getlength(t)


x = 80
line(x, 90, [("ロケットは", WHITE)], 150, 11)
line(x, 270, [("1段では", YEL)], 230, 14)
line(x, 540, [("実用的に届かない", WHITE)], 150, 11)
line(x, 760, [("なぜ？", YEL)], 170, 12)
line(x, 1000, [("必要な速さは秒速", WHITE), ("9.4km", YEL)], 110, 9)
line(x, 1140, [("新幹線の", WHITE), ("約106倍", YEL)], 110, 9)
img.convert("RGB").resize((1280, 720), Image.LANCZOS).save(OUT / "thumb_long.jpg", quality=93)
print(OUT / "thumb_long.jpg")

"""サムライドライブの本編のサムネイル(1280×720)。作品の絵は使わない。下地は Gemini の絵(assets/thumb_gemini.jpg: ネットの上端でテニスボールが2つに割れる)。
形は深海魚の回と同じ(字は絵の上に直接・箱なし・白＋黄・左に暗い下ざらえ)。python episodes/samurai/thumb.py"""
import os
import sys
from pathlib import Path

os.environ["NAZE_ASPECT"] = "landscape"
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parents[1]))
import numpy as np  # noqa: E402
from PIL import Image, ImageDraw, ImageEnhance  # noqa: E402

from naze import overlay as O  # noqa: E402

OUT = HERE.parents[1] / "out" / "samurai"
OUT.mkdir(parents=True, exist_ok=True)
W, H = 2560, 1440
NAVY, YEL, WHITE = (0, 10, 30), (255, 222, 40), (255, 255, 255)

src = Image.open(HERE / "assets" / "thumb_gemini.jpg").convert("RGB")
s = max(W / src.width, H / src.height)
src = src.resize((int(src.width * s + 1), int(src.height * s + 1)), Image.LANCZOS).crop((0, 0, W, H))
src = ImageEnhance.Color(src).enhance(1.1)
img = src.convert("RGBA")
xs = np.arange(W)[None, :]
alpha = (165 * np.clip(1 - xs / 1500, 0, 1) ** 1.2 * np.ones((H, 1))).astype("uint8")
sh = Image.fromarray(np.dstack([np.zeros((H, W), "uint8"), np.full((H, W), 10, "uint8"), np.full((H, W), 30, "uint8"), alpha]), "RGBA")
img.alpha_composite(sh)
d = ImageDraw.Draw(img)


def line(x, y, parts, size, stroke=12):
    f = O.font(size)
    for t, col in parts:
        d.text((x, y), t, font=f, fill=col, stroke_width=stroke, stroke_fill=NAVY)
        x += f.getlength(t)


x = 80
line(x, 70, [("テニスの王子様", WHITE)], 150, 11)
line(x, 250, [("ボールを", WHITE)], 190, 13)
line(x, 480, [("真っ二つ", YEL)], 260, 15)
line(x, 800, [("当てる角度の幅は", WHITE)], 110, 9)
line(x, 940, [("ボール", WHITE), ("1個分", YEL)], 190, 13)
line(x, 1200, [("再現できる？", WHITE)], 120, 9)
img.convert("RGB").resize((1280, 720), Image.LANCZOS).save(OUT / "thumb_long.jpg", quality=93)
print(OUT / "thumb_long.jpg")

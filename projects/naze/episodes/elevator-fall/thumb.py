"""落ちるエレベーターの本編のサムネイル(1280×720)。下地は scene.py で描いた、10階から落ちたかごが底に当たる瞬間(字なし)。
字はラピュタの回と同じ形(箱なし・白＋黄＋赤・左に暗い下ざらえ)。python episodes/elevator-fall/thumb.py"""
import os
import sys
from pathlib import Path

os.environ["NAZE_ASPECT"] = "landscape"
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parents[1]))
sys.path.insert(0, str(HERE))
import numpy as np  # noqa: E402
from PIL import Image, ImageDraw  # noqa: E402

import scene as SC  # noqa: E402
from naze import overlay as O  # noqa: E402
from parts import SH  # noqa: E402

OUT = HERE.parents[1] / "out" / "elevator-fall"
OUT.mkdir(parents=True, exist_ok=True)
W, H = 2560, 1440
NAVY, YEL, WHITE, RED = (10, 10, 10), (255, 225, 0), (255, 255, 255), (255, 60, 60)

base = SC.paint(SH("jump", bare=True), 0.0, SC.TI - 0.03).convert("RGB")
x0 = int(SC.W * 0.12)
base = base.crop((x0, 60, x0 + int(820 * 16 / 9), 60 + 820)).resize((W, H), Image.LANCZOS)
ImageDraw.Draw(base).ellipse([620, 1060, 1120, 1420], outline=(255, 50, 50), width=18)   # 主役: 床を離れた足と、迫る底
img = base.convert("RGBA")
xs = np.arange(W)[None, :]
alpha = (170 * np.clip((xs - 900) / 900, 0, 1) ** 1.1 * np.ones((H, 1))).astype("uint8")
sh = Image.fromarray(np.dstack([np.zeros((H, W), "uint8"), np.full((H, W), 8, "uint8"), np.full((H, W), 30, "uint8"), alpha]), "RGBA")
img = Image.alpha_composite(img, sh)
d = ImageDraw.Draw(img)


def line(x, y, parts, size, stroke=None):
    stroke = stroke or int(size * 0.085)
    f = O.font(size)
    for t, col in parts:
        d.text((x, y), t, font=f, fill=col, stroke_width=stroke, stroke_fill=NAVY)
        x += f.getlength(t)


x = 1180
line(x, 80, [("落ちるエレベーター", WHITE)], 120)
line(x, 240, [("直前に", WHITE), ("跳ぶ", YEL), ("と", WHITE)], 200)
line(x, 520, [("膝で待つより", WHITE)], 130)
line(x, 680, [("7倍", RED), ("きつい", WHITE)], 280)
line(x, 1120, [("人形を", WHITE), ("9回", YEL), ("落として計算", WHITE)], 100, 8)
img.convert("RGB").resize((1280, 720), Image.LANCZOS).save(OUT / "thumb_long.jpg", quality=93)
print(OUT / "thumb_long.jpg")

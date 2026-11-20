"""落ちるエレベーターの本編のサムネイル(1280×720)。下地は Cloudflare Workers AI の FLUX.1 schnell の絵
(assets/thumb_b1.jpg: 落ちるかごの中で跳ぶ顔のない人形、赤い非常灯、底が見える。無料枠で作った)。
字はラピュタの回と同じ形(箱なし・白＋黄＋赤・字の側に暗い下ざらえ)。python episodes/elevator-fall/thumb.py"""
import os
import sys
from pathlib import Path

os.environ["NAZE_ASPECT"] = "landscape"
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parents[1]))
import numpy as np  # noqa: E402
from PIL import Image, ImageDraw, ImageEnhance, ImageFilter  # noqa: E402

from naze import overlay as O  # noqa: E402

OUT = HERE.parents[1] / "out" / "elevator-fall"
OUT.mkdir(parents=True, exist_ok=True)
W, H = 2560, 1440
NAVY, YEL, WHITE, RED = (10, 10, 10), (255, 225, 0), (255, 255, 255), (255, 60, 60)

src = Image.open(HERE / "assets" / "thumb_b1.jpg").convert("RGB")
src = ImageEnhance.Contrast(ImageEnhance.Color(src).enhance(1.15)).enhance(1.08)
sz = 1760
src = src.resize((sz, sz), Image.LANCZOS)
canvas = Image.new("RGB", (W, H), (6, 12, 22))
# 右の空きは、絵の右の壁をぼかして伸ばす(継ぎ目を出さない)
wall = src.crop((sz - 420, 0, sz, sz)).resize((W - sz + 420, sz)).filter(ImageFilter.GaussianBlur(18))
canvas.paste(wall, (sz - 420, -300))
canvas.paste(src, (0, -300))
img = canvas.convert("RGBA")
xs = np.arange(W)[None, :]
alpha = (215 * np.clip((xs - 1150) / 650, 0, 1) ** 1.2 * np.ones((H, 1))).astype("uint8")
sh = Image.fromarray(np.dstack([np.zeros((H, W), "uint8"), np.full((H, W), 6, "uint8"), np.full((H, W), 20, "uint8"), alpha]), "RGBA")
img = Image.alpha_composite(img, sh)
d = ImageDraw.Draw(img)
d.ellipse([700, 330, 1150, 980], outline=(255, 40, 40), width=20)       # 主役: 跳んだ人形


def line(x, y, parts, size, stroke=None):
    stroke = stroke or int(size * 0.085)
    f = O.font(size)
    for t, col in parts:
        d.text((x, y), t, font=f, fill=col, stroke_width=stroke, stroke_fill=NAVY)
        x += f.getlength(t)


x = 1330
line(x, 90, [("落ちるエレベーター", WHITE)], 125)
line(x, 270, [("直前に", WHITE), ("跳べば", YEL)], 205)
line(x - 60, 575, [("助かる", RED), ("のか？", WHITE)], 205)
line(x, 1150, [("人形を", WHITE), ("9回", YEL), ("落として計算", WHITE)], 105, 9)
img.convert("RGB").resize((1280, 720), Image.LANCZOS).save(OUT / "thumb_long.jpg", quality=93)
print(OUT / "thumb_long.jpg")

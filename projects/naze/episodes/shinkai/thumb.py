"""深海魚の本編のサムネイル(1280×720)。下地は Gemini で作った絵(assets/thumb_gemini.jpg: 深い青の海の中で、つぶれたペットボトルのすぐ横を、
半透明の小さな魚が平気な顔で泳ぐ)。
形は電子レンジ・進撃の回でユーザーが決めたもの(2026-10-29): 字は絵の上に直接・箱や番号なし・大きくしすぎない・全部の要素を入れる・明るく。
字(白＋黄の2色だけ): 「つぶれたペットボトルの横を、魚は平気で泳ぐ(上いっぱい)／水深8,336mでも／深海魚はつぶれない／なぜ？／指先に約870kg」。左と上に暗い下ざらえ。「ペットボトルの空気は845分の1に縮む」は、行を減らすため外した。上いっぱいに大きい横長の一文「つぶれたペットボトルの横を、魚は平気で泳ぐ」。前の版(「なぜ？」なし)は out/shinkai/thumb_long_v1.jpg。python episodes/shinkai/thumb.py"""
import os
import sys
from pathlib import Path

os.environ["NAZE_ASPECT"] = "landscape"
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parents[1]))
from PIL import Image, ImageDraw, ImageEnhance  # noqa: E402

from naze import overlay as O  # noqa: E402

OUT = HERE.parents[1] / "out" / "shinkai"
OUT.mkdir(parents=True, exist_ok=True)
W, H = 2560, 1440
NAVY, YEL, WHITE = (0, 6, 24), (255, 222, 40), (255, 255, 255)   # 字のふちは濃い黒に近い紺

src = Image.open(HERE / "assets" / "thumb_gemini.jpg").convert("RGB")
s = max(W / src.width, H / src.height)
src = src.resize((int(src.width * s + 1), int(src.height * s + 1)), Image.LANCZOS).crop((0, 0, W, H))
src = ImageEnhance.Brightness(src).enhance(1.12)
src = ImageEnhance.Color(src).enhance(1.1)
img = src.convert("RGBA")
# 色と字がいっしょくたにならないよう、左と上に暗い下ざらえを敷く(2026-10-29 ユーザー指示)
import numpy as np  # noqa: E402

xs = np.arange(W)[None, :]
ys = np.arange(H)[:, None]
a_left = 170 * np.clip(1 - xs / 1700, 0, 1) ** 1.2
a_top = 150 * np.clip(1 - ys / 340, 0, 1) ** 1.2
alpha = np.maximum(a_left, a_top).astype("uint8")           # 重なる所は強いほうを使う(つなぎ目の線が出ない)
sh = Image.fromarray(np.dstack([np.zeros((H, W), "uint8"), np.full((H, W), 8, "uint8"), np.full((H, W), 30, "uint8"), alpha]), "RGBA")
img.alpha_composite(sh)
d = ImageDraw.Draw(img)


def line(x, y, parts, size, stroke=16):
    f = O.font(size)
    for t, col in parts:
        d.text((x, y), t, font=f, fill=col, stroke_width=stroke, stroke_fill=NAVY)
        x += f.getlength(t)


x = 80
# 上いっぱいに、大きい字の横長の一文(2026-10-29 ユーザー指示)。幅に収まるよう字の大きさを自動で決める
LONG = [("つぶれたペットボトルの横を、", WHITE), ("魚は平気で泳ぐ", YEL)]
lw = 2560 - 2 * x
sz = 140
while sum(O.font(sz).getlength(t) for t, _ in LONG) > lw and sz > 40:
    sz -= 2
line(x, 55, LONG, sz, stroke=11)
# 左の字。白と黄色の2色だけ。行を減らす
line(x, 260, [("水深", WHITE), ("8,336m", YEL), ("でも", WHITE)], 104, stroke=9)
line(x, 385, [("深海魚は", WHITE)], 140, stroke=11)
line(x, 540, [("つぶれない", YEL)], 190, stroke=13)
line(x, 770, [("なぜ？", WHITE)], 140, stroke=11)
line(x, 960, [("指先に約", WHITE), ("870kg", YEL)], 110, stroke=9)

img.convert("RGB").resize((1280, 720), Image.LANCZOS).save(OUT / "thumb_long.jpg", quality=93)
print(OUT / "thumb_long.jpg")

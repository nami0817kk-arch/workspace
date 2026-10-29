"""深海魚の本編のサムネイル(1280×720)。下地は Gemini で作った絵(assets/thumb_gemini.jpg: 深い青の海の中で、つぶれたペットボトルのすぐ横を、
半透明の小さな魚が平気な顔で泳ぐ)。
形は電子レンジ・進撃の回でユーザーが決めたもの(2026-10-29): 字は絵の上に直接・箱や番号なし・大きくしすぎない・全部の要素を入れる・明るく。
字(白＋黄): 「水深8,336mでも／深海魚はつぶれない／指先1平方cmに約870kg／ペットボトルの空気は845分の1」。python episodes/shinkai/thumb.py"""
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
NAVY, YEL, WHITE = (6, 28, 78), (255, 222, 40), (255, 255, 255)

src = Image.open(HERE / "assets" / "thumb_gemini.jpg").convert("RGB")
s = max(W / src.width, H / src.height)
src = src.resize((int(src.width * s + 1), int(src.height * s + 1)), Image.LANCZOS).crop((0, 0, W, H))
src = ImageEnhance.Brightness(src).enhance(1.12)
src = ImageEnhance.Color(src).enhance(1.1)
img = src.convert("RGBA")
d = ImageDraw.Draw(img)


def line(x, y, parts, size, stroke=16):
    f = O.font(size)
    for t, col in parts:
        d.text((x, y), t, font=f, fill=col, stroke_width=stroke, stroke_fill=NAVY)
        x += f.getlength(t)


x = 80
line(x, 90, [("水深", WHITE), ("8,336m", YEL), ("でも", WHITE)], 112)
line(x, 270, [("深海魚は", WHITE)], 150)
line(x, 450, [("つぶれない", YEL)], 190)
line(x, 740, [("指先1平方cmに", WHITE)], 96, stroke=14)
line(x, 870, [("約", WHITE), ("870kg", YEL), ("の重さ", WHITE)], 130)
line(x, 1090, [("ペットボトルの空気は", WHITE)], 80, stroke=12)
line(x, 1190, [("845分の1", YEL), ("に縮む", WHITE)], 110)

img.convert("RGB").resize((1280, 720), Image.LANCZOS).save(OUT / "thumb_long.jpg", quality=93)
print(OUT / "thumb_long.jpg")

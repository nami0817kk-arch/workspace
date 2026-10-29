"""ノックアップストリームの本編のサムネイル(1280×720)。作品の絵は使わない。下地は Gemini で作った絵(assets/thumb_gemini.jpg:
青い海から噴き上がる水の柱の上に、小さな木造帆船が乗っている。雲の海のさらに上へ)。
形は電子レンジ・進撃の回でユーザーが決めたもの(2026-10-29): 字は絵の上に直接・箱や番号なし・大きくしすぎない・全部の要素を入れる・明るく。
字: 「【ワンピース】のノックアップストリーム／船を高さ【7000m】へ／世界一の噴水も、火山も、【届かない】／届かせるには？(？も黒)」（2026-10-29 ユーザー指示「要る水の話は不要」で速さの2行は外し、「届かせるには？を入れよう」で問いを足した）。
絵の上の札: 船の横に「7000m」、柱の根元に「世界一の噴水 312m」(柱の長さの約4.5%のところ)。python episodes/knockup/thumb.py"""
import os
import sys
from pathlib import Path

os.environ["NAZE_ASPECT"] = "landscape"
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parents[1]))
from PIL import Image, ImageDraw, ImageEnhance  # noqa: E402

from naze import overlay as O  # noqa: E402

OUT = HERE.parents[1] / "out" / "knockup"
OUT.mkdir(parents=True, exist_ok=True)
W, H = 2560, 1440
INK, RED, YEL, WHITE = (20, 30, 60), (225, 30, 30), (255, 215, 0), (255, 255, 255)

src = Image.open(HERE / "assets" / "thumb_gemini.jpg").convert("RGB")
s = max(W / src.width, H / src.height)
src = src.resize((int(src.width * s + 1), int(src.height * s + 1)), Image.LANCZOS).crop((0, 0, W, H))
src = ImageEnhance.Color(src).enhance(1.12)
img = src.convert("RGBA")
k = W / 1376  # 下地の座標(1376×768)からの倍率

# 字の後ろ(左)を少し白く
sh = Image.new("RGBA", (W, H), (0, 0, 0, 0))
ds = ImageDraw.Draw(sh)
for x in range(0, 1500, 4):
    ds.rectangle([x, 0, x + 4, H], fill=(255, 255, 255, int(110 * max(0.0, 1 - x / 1500))))
img.alpha_composite(sh)
d = ImageDraw.Draw(img)


def line(x, y, parts, size, stroke=16):
    f = O.font(size)
    for t, col in parts:
        d.text((x, y), t, font=f, fill=col, stroke_width=stroke, stroke_fill=WHITE)
        x += f.getlength(t)
    return x


def tag(xy, s_, size, fg, bg, anchor="mm"):
    f = O.font(size)
    x0, y0, x1, y1 = d.textbbox(xy, s_, font=f, anchor=anchor)
    p = size * 0.22
    d.rounded_rectangle([x0 - p, y0 - p, x1 + p, y1 + p], radius=int(p), fill=bg)
    d.text(xy, s_, font=f, fill=fg, anchor=anchor)


# 絵の上の札
tag((1180 * k, 60 * k), "7000m", 78, INK, YEL)
yb = 628 * k                                    # 柱の長さの約4.5%(世界一の噴水 312m)の高さ
d.line([(1560, yb), (2090, yb)], fill=YEL, width=10)
tag((1360, yb), "世界一の噴水 312m", 70, INK, YEL)

# 字(左)
x = 80
tag((x + 215, 135), "ワンピース", 86, WHITE, (190, 30, 30))
line(x + 450, 76, [("のノックアップストリーム", INK)], 86, stroke=14)
line(x, 230, [("船を高さ", INK), ("7000m", RED), ("へ", INK)], 150)
line(x, 430, [("世界一の噴水も、", INK)], 110)
line(x, 550, [("火山も、", INK)], 110)
line(x, 670, [("届かない", RED)], 170)
line(x, 880, [("届かせるには？", INK)], 150)

img.convert("RGB").resize((1280, 720), Image.LANCZOS).save(OUT / "thumb_long.jpg", quality=93)
print(OUT / "thumb_long.jpg")

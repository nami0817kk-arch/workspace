"""太陽の本編のサムネイル(1280×720)。python episodes/sun/thumb.py → out/sun/thumb_long.jpg
右に大きな太陽、左下の地球からカプセルの道すじが太陽を外れていく。字は 3 段まで、大事な 1 語(200兆円)だけ黄色。
道すじは scene.PATHS["r10"](軌道の式で解いた、太陽へ秒速10kmで撃った道)を、太陽が大きく見えるように引き伸ばして使う。"""
import os
import sys
from pathlib import Path

os.environ["NAZE_ASPECT"] = "landscape"
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parents[1]))
sys.path.insert(0, str(HERE))
from PIL import Image, ImageDraw, ImageFilter, ImageFont  # noqa: E402

import scene  # noqa: E402

OUT = HERE.parents[1] / "out" / "sun"
OUT.mkdir(parents=True, exist_ok=True)
YEL, WHITE, INK = (255, 222, 0), (255, 255, 255), (8, 10, 18)


def font(size, weight="Black"):
    f = ImageFont.truetype("C:/Windows/Fonts/NotoSansJP-VF.ttf", size)
    f.set_variation_by_name(weight)
    return f


img = scene.stars()                                   # 1920×1080 で描いて縮める
scene.glow_disc(img, 1560, 470, 360, (255, 180, 60), 1.5)
d = ImageDraw.Draw(img)
# 地球とカプセルの道すじ(太陽の手前で横へそれる)
pts = scene.PATHS["r10"][: len(scene.PATHS["r10"]) // 2]
sp = [(220 + x * 1000, 950 - (y + 1.0) * 1100) for x, y in pts]
d.line(sp, fill=(255, 120, 90), width=10, joint="curve")
scene.glow_disc(img, sp[-1][0], sp[-1][1], 16, (255, 120, 90), 2.2)
scene.glow_disc(img, 220, 950, 34, scene.EARTHC, 2.0)
d = ImageDraw.Draw(img)
d.text((220, 1030), "地球", font=font(40, "Bold"), fill=WHITE, anchor="mb", stroke_width=5, stroke_fill=INK)
img = img.convert("RGB").resize((1280, 720), Image.LANCZOS).convert("RGBA")


def big(d, xy, s, size, col):
    f = font(size)
    sh = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(sh).text((xy[0] + 6, xy[1] + 8), s, font=f, fill=(0, 0, 0, 200), stroke_width=14, stroke_fill=(0, 0, 0, 200))
    img.alpha_composite(sh.filter(ImageFilter.GaussianBlur(6)))
    ImageDraw.Draw(img).text(xy, s, font=f, fill=col, stroke_width=12, stroke_fill=INK)


big(d, (48, 40), "核のゴミを太陽へ", 92, WHITE)
big(d, (40, 150), "200兆円", 230, YEL)
big(d, (52, 430), "日本の分だけで", 78, WHITE)
img.convert("RGB").save(OUT / "thumb_long.jpg", quality=92)
img.convert("RGB").resize((320, 180), Image.LANCZOS).save(OUT / "thumb_long_small.jpg", quality=90)
print(OUT / "thumb_long.jpg")

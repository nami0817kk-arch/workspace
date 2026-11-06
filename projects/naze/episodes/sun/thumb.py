"""太陽の本編のサムネイル(1280×720)。python episodes/sun/thumb.py → out/sun/thumb_long.jpg
下地は Gemini の絵(右に燃える太陽、真ん中に太陽へ向かうカプセル)。字は 3 段まで、大事な 1 語(200兆円)だけ黄色。
"""
import os
import sys
from pathlib import Path

os.environ["NAZE_ASPECT"] = "landscape"
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parents[1]))
sys.path.insert(0, str(HERE))
from PIL import Image, ImageDraw, ImageFilter, ImageFont  # noqa: E402


OUT = HERE.parents[1] / "out" / "sun"
OUT.mkdir(parents=True, exist_ok=True)
YEL, WHITE, INK = (255, 222, 0), (255, 255, 255), (8, 10, 18)


def font(size, weight="Black"):
    f = ImageFont.truetype("C:/Windows/Fonts/NotoSansJP-VF.ttf", size)
    f.set_variation_by_name(weight)
    return f


# 下地は Gemini で作った絵(assets/thumb_bg.jpg、2026-11-06): 右に燃える太陽、真ん中に太陽へ向かうカプセル
img = Image.open(HERE / "assets" / "thumb_bg.jpg").convert("RGB")
img = img.resize((round(img.width * 720 / img.height), 720), Image.LANCZOS).crop((0, 0, 1280, 720)).convert("RGBA")
d = ImageDraw.Draw(img)

def big(d, xy, s, size, col):
    f = font(size)
    sh = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(sh).text((xy[0] + 6, xy[1] + 8), s, font=f, fill=(0, 0, 0, 200), stroke_width=14, stroke_fill=(0, 0, 0, 200))
    img.alpha_composite(sh.filter(ImageFilter.GaussianBlur(6)))
    ImageDraw.Draw(img).text(xy, s, font=f, fill=col, stroke_width=12, stroke_fill=INK)


big(d, (48, 34), "核のゴミを太陽へ", 92, WHITE)
big(d, (52, 330), "日本の分だけで", 80, WHITE)
big(d, (34, 430), "200兆円", 216, YEL)
img.convert("RGB").save(OUT / "thumb_long.jpg", quality=92)
img.convert("RGB").resize((320, 180), Image.LANCZOS).save(OUT / "thumb_long_small.jpg", quality=90)
print(OUT / "thumb_long.jpg")

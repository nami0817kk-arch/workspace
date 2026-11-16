"""アマゾン川の回の本編のサムネイル(1280×720)。python episodes/amazon/thumb.py → out/amazon/thumb_long.jpg
下地は本編と同じ地図(NASA Blue Marble)。流域の地図にアマゾン川を描く。
字は「見たら何がわかるか」(2026-11-07 指示)。上に小さく事実、大きく問い(問いの行だけ黄色)。
主役の川に赤い丸と「橋 0本」。地図は斜めから見下ろし、色を濃く・周りを暗く(2026-11-16「サムネの質を上げて」)。"""
import os
import sys
from pathlib import Path

os.environ["NAZE_ASPECT"] = "landscape"
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parents[1]))
sys.path.insert(0, str(HERE))
from PIL import Image, ImageDraw, ImageFilter, ImageFont  # noqa: E402

import numpy as np  # noqa: E402
import scene  # noqa: E402
from parts import AMAZON  # noqa: E402
from naze.config import H, W  # noqa: E402

OUT = HERE.parents[1] / "out" / "amazon"
OUT.mkdir(parents=True, exist_ok=True)
YEL, WHITE, INK = (255, 222, 0), (255, 255, 255), (8, 10, 18)

VIEW = (-60.5, -5.0, 22.0, 38)                                      # 斜めから見下ろして奥行きを出す
sc = dict(shot="map", view=VIEW, layers=[dict(kind="line", pts=AMAZON, color=(90, 228, 255), width=20, glow=True, id="th_amz", at=0.0)])
lines = [dict(id="x", text="", start=0.0, end=3.0, scene=sc)]
img = Image.new("RGBA", (W, H), (10, 18, 40, 255))
scene.draw(img, ImageDraw.Draw(img), 2.5, dict(lines=lines, cur=lines[0], L={"x": lines[0]}, k=0.9, at=lambda i: 0.0,
                                               defs={"x": lines[0]}, cta=False))
v = scene.MAP.view(*VIEW)
FOC = [(q[0] * 1280 / W, q[1] * 720 / H) for q in (v.px(-58.44, -3.14), v.px(-55.5, -1.9))]   # 赤い丸を置く川の区間(マナウスの下流)
img = img.convert("RGB").resize((1280, 720), Image.LANCZOS)
a = np.asarray(img).astype(np.float32) / 255
g = a.mean(axis=2, keepdims=True)
a = np.clip(g + (a - g) * 1.45, 0, 1)                               # 色を濃く
a = np.clip((a - 0.5) * 1.18 + 0.5, 0, 1)                           # 締める
yy, xx = np.mgrid[0:720, 0:1280].astype(np.float32)
vig = 1 - 0.45 * np.clip(((xx - 760) / 760) ** 2 + ((yy - 380) / 520) ** 2 - 0.35, 0, 1)
a *= vig[..., None]
a *= (1 - 0.55 * np.clip((0.55 - xx / 1280) / 0.55, 0, 1))[..., None]   # 左を暗くして字を立てる
img = Image.fromarray((a * 255).astype(np.uint8)).convert("RGBA")


def font(size, weight="Black"):
    f = ImageFont.truetype("C:/Windows/Fonts/NotoSansJP-VF.ttf", size)
    f.set_variation_by_name(weight)
    return f


def big(xy, s, size, col, stroke=12, anchor="la"):
    f = font(size)
    sh = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(sh).text((xy[0] + 6, xy[1] + 9), s, font=f, fill=(0, 0, 0, 210), anchor=anchor, stroke_width=stroke + 3, stroke_fill=(0, 0, 0, 210))
    img.alpha_composite(sh.filter(ImageFilter.GaussianBlur(7)))
    ImageDraw.Draw(img).text(xy, s, font=f, fill=col, anchor=anchor, stroke_width=stroke, stroke_fill=INK)


# 主役(川)に赤い丸と「橋 0本」の札
cx, cy = (FOC[0][0] + FOC[1][0]) / 2, (FOC[0][1] + FOC[1][1]) / 2
rx, ry = max(120, abs(FOC[1][0] - FOC[0][0]) / 2 + 60), 78
ring = Image.new("RGBA", img.size, (0, 0, 0, 0))
dr = ImageDraw.Draw(ring)
dr.ellipse((cx - rx, cy - ry, cx + rx, cy + ry), outline=(0, 0, 0, 160), width=22)
img.alpha_composite(ring.filter(ImageFilter.GaussianBlur(5)))
ImageDraw.Draw(img).ellipse((cx - rx, cy - ry, cx + rx, cy + ry), outline=(235, 40, 40, 255), width=13)
# 札: 赤い丸とそろえた赤地に白い字(黄色は「橋がない理由」だけにする)。川の右下の空いた所
ft = font(100)
bx = ImageDraw.Draw(img).textbbox((1060, 430), "橋 0本", font=ft, anchor="mm")
pad = 26
shd = Image.new("RGBA", img.size, (0, 0, 0, 0))
ImageDraw.Draw(shd).rounded_rectangle((bx[0] - pad + 8, bx[1] - pad + 12, bx[2] + pad + 8, bx[3] + pad + 12), 22, fill=(0, 0, 0, 200))
img.alpha_composite(shd.filter(ImageFilter.GaussianBlur(8)))
ImageDraw.Draw(img).rounded_rectangle((bx[0] - pad, bx[1] - pad, bx[2] + pad, bx[3] + pad), 22, fill=(225, 35, 35, 255), outline=(255, 255, 255, 255), width=5)
ImageDraw.Draw(img).text((1060, 430), "橋 0本", font=ft, fill=WHITE, anchor="mm")

big((34, 34), "6,000km以上流れる世界最大の川", 50, WHITE, 10)
big((30, 300), "アマゾン川に", 128, WHITE, 16)
big((26, 470), "橋がない理由", 140, YEL, 18)
ImageDraw.Draw(img).text((1262, 706), "地図: NASA・Terrain Tiles", font=font(22, "Bold"), fill=(255, 255, 255, 200), anchor="rd", stroke_width=3, stroke_fill=INK)
img.convert("RGB").save(OUT / "thumb_long.jpg", quality=93)
print(OUT / "thumb_long.jpg")

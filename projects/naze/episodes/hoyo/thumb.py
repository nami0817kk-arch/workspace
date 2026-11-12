"""豊予海峡の回の本編のサムネイル(1280×720)。python episodes/hoyo/thumb.py → out/hoyo/thumb_long.jpg
下地は本編と同じ立体の地図(国土地理院の空中写真)。海峡が右に見えるように寄せる。
字は「見たら何がわかるか」(2026-11-07 指示)。上に小さく事実、大きく問い(問いの行だけ黄色)。"""
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
from parts import LINE, PIN, SAGA, TIP, KYU_PT, MISAKI  # noqa: E402
from naze.config import H, W  # noqa: E402

OUT = HERE.parents[1] / "out" / "hoyo"
OUT.mkdir(parents=True, exist_ok=True)
YEL, WHITE, INK = (255, 222, 0), (255, 255, 255), (8, 10, 18)

sc = dict(shot="map", view=(131.84, 33.30, 0.42, 0), layers=[LINE([KYU_PT, TIP], id="r_th", width=9), PIN(SAGA, "九州", id="p_a", size=56), PIN(TIP, "四国", id="p_b", size=56)])
lines = [dict(id="x", text="", start=0.0, end=3.0, scene=sc)]
img = Image.new("RGBA", (W, H), (10, 18, 40, 255))
scene.draw(img, ImageDraw.Draw(img), 2.5, dict(lines=lines, cur=lines[0], L={"x": lines[0]}, k=0.9, at=lambda i: 0.0,
                                               defs={"x": lines[0]}, cta=False))
img = img.convert("RGB").resize((1280, 720), Image.LANCZOS)
a = np.asarray(img).astype(np.float32)
xx = np.linspace(0, 1, 1280, dtype=np.float32)[None, :, None]
a *= 1 - 0.6 * np.clip((0.6 - xx) / 0.6, 0, 1)                      # 左を暗くして字を立てる
img = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8)).convert("RGBA")


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


big((34, 40), "いちばん近い所は、たった14km", 62, WHITE, 12)
big((34, 190), "九州と四国", 118, WHITE, 14)
big((26, 360), "橋がない", 132, YEL, 16)
big((26, 520), "本当の理由", 132, YEL, 16)
ImageDraw.Draw(img).text((1262, 706), "空中写真: 国土地理院", font=font(22, "Bold"), fill=(255, 255, 255, 200), anchor="rd", stroke_width=3, stroke_fill=INK)
img.convert("RGB").save(OUT / "thumb_long.jpg", quality=93)
print(OUT / "thumb_long.jpg")

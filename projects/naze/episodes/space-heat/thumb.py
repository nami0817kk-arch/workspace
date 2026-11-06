"""宇宙で冷えない回の本編のサムネイル(1280×720)。python episodes/space-heat/thumb.py → out/space-heat/thumb_long.jpg
下地は画面と同じ、地球の上の宇宙ステーション(scene.draw_station、放熱板を黄色の枠で示す)。字は 3 段、大事な 1 語(冷えない)だけ黄色。"""
import os
import sys
from pathlib import Path

os.environ["NAZE_ASPECT"] = "landscape"
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parents[1]))
sys.path.insert(0, str(HERE))
import numpy as np  # noqa: E402
from PIL import Image, ImageDraw, ImageFilter, ImageFont  # noqa: E402

import scene  # noqa: E402
from naze import overlay as ov  # noqa: E402
from naze.config import H, W  # noqa: E402

OUT = HERE.parents[1] / "out" / "space-heat"
OUT.mkdir(parents=True, exist_ok=True)
YEL, WHITE, INK = (255, 222, 0), (255, 255, 255), (8, 10, 18)

base = Image.new("RGBA", (W, H))
scene.shots.draw_globe(base, dict(center=(115, 30), to=(115, 30), r=0.9, dx=0.12), 0.0)
scene._station(ImageDraw.Draw(base, "RGBA"), W * 0.79, H * 0.50, 0.62, 1.6, "radiators")
ov.BOXES.clear()
img = base.convert("RGB").resize((1280, 720), Image.LANCZOS)
a = np.asarray(img).astype(np.float32)
x = np.linspace(0, 1, 1280, dtype=np.float32)[None, :, None]
a *= 0.45 + 0.55 * np.clip((x - 0.05) / 0.7, 0, 1)
img = Image.fromarray(a.astype(np.uint8)).convert("RGBA")


def font(size, weight="Black"):
    f = ImageFont.truetype("C:/Windows/Fonts/NotoSansJP-VF.ttf", size)
    f.set_variation_by_name(weight)
    return f


def big(xy, s, size, col):
    f = font(size)
    sh = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(sh).text((xy[0] + 6, xy[1] + 8), s, font=f, fill=(0, 0, 0, 200), stroke_width=14, stroke_fill=(0, 0, 0, 200))
    img.alpha_composite(sh.filter(ImageFilter.GaussianBlur(6)))
    ImageDraw.Draw(img).text(xy, s, font=f, fill=col, stroke_width=12, stroke_fill=INK)


big((48, 40), "マイナス270℃の宇宙で", 78, WHITE)
big((40, 150), "冷えない", 220, YEL)
big((52, 470), "宇宙ステーションの熱", 82, WHITE)
img.convert("RGB").save(OUT / "thumb_long.jpg", quality=92)
print(OUT / "thumb_long.jpg")

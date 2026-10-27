"""空の色の本編のサムネイル(1280×720)。Gemini で作った絵(assets/thumb_gemini.jpg、左が青空・右が夕焼け)に字を重ねる。python episodes/sky/thumb.py"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from PIL import Image, ImageDraw  # noqa: E402

from naze import overlay as O  # noqa: E402

HERE = Path(__file__).resolve().parent
OUT = HERE.parents[1] / "out" / "sky"
OUT.mkdir(parents=True, exist_ok=True)
W, H = 2560, 1440

img = Image.open(HERE / "assets" / "thumb_gemini.jpg").convert("RGB").resize((W, H), Image.LANCZOS).convert("RGBA")
d = ImageDraw.Draw(img)


def rows(lines, x, y, size, gap=1.2, anchor_right=False):
    for i, row in enumerate(lines):
        parts = O.parse(row)
        tw = sum(O.font(size).getlength(t) for t, _ in parts)
        xx = x - tw if anchor_right else x
        for t, hl in parts:
            f = O.font(size)
            d.text((xx, y + i * size * gap), t, font=f, fill=O.YEL if hl else O.WHITE, stroke_width=16, stroke_fill=O.NAVY)
            xx += f.getlength(t)


rows(["空が青いのは", "青が赤の【約6倍】", "散らばるから"], 80, 90, 150)
rows(["夕焼けは", "空気を【38倍】通る"], W - 80, 870, 130, anchor_right=True)
img.convert("RGB").resize((1280, 720), Image.LANCZOS).save(OUT / "thumb_long.jpg", quality=93)
print(OUT / "thumb_long.jpg")

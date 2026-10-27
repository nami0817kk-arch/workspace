"""空の色の本編のサムネイル(1280×720)。Gemini で作った絵(assets/thumb_gemini.jpg、左が青空・右が夕焼け)に、
空と夕焼けの 2 つの問いと「この動画でわかること」を重ねる。python episodes/sky/thumb.py"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from PIL import Image, ImageDraw  # noqa: E402

from naze import overlay as O  # noqa: E402

HERE = Path(__file__).resolve().parent
OUT = HERE.parents[1] / "out" / "sky"
OUT.mkdir(parents=True, exist_ok=True)
W, H = 2560, 1440
SKYC, SUNC = (120, 200, 255), (255, 130, 60)

img = Image.open(HERE / "assets" / "thumb_gemini.jpg").convert("RGB").resize((W, H), Image.LANCZOS).convert("RGBA")
sh = Image.new("RGBA", (W, H), (0, 0, 0, 0))
d = ImageDraw.Draw(sh)
for y in range(560):
    d.line([(0, y), (W, y)], fill=O.NAVY + (int(170 * (1 - y / 560)),))
img.alpha_composite(sh)
d = ImageDraw.Draw(img)


def q(x, y, a, b, c, col, right=False):
    """「空はなぜ」+ 色の語 + 「の？」を 1 行で。色の語だけその色にする。"""
    f = O.font(170)
    parts = [(a, O.WHITE), (b, col), (c, O.WHITE)]
    tw = sum(f.getlength(t) for t, _ in parts)
    xx = x - tw if right else x
    for t, cc in parts:
        d.text((xx, y), t, font=f, fill=cc, stroke_width=18, stroke_fill=O.NAVY)
        xx += f.getlength(t)


q(80, 60, "空はなぜ", "青い", "の？", SKYC)
q(W - 80, 520, "夕焼けはなぜ", "赤い", "の？", SUNC, right=True)

sub = O.font(80)
d.text((90, 290), "→ 青い光は赤の約6倍散らばる", font=sub, fill=O.WHITE, stroke_width=10, stroke_fill=O.NAVY)
d.text((W - 80, 750), "→ 光が空気を38倍通る", font=sub, fill=O.WHITE, anchor="ra", stroke_width=10, stroke_fill=O.NAVY)
d.text((W - 60, H - 40), "絵はAIで作成", font=O.font(38), fill=O.WHITE, anchor="rd", stroke_width=5, stroke_fill=O.NAVY)
img.convert("RGB").resize((1280, 720), Image.LANCZOS).save(OUT / "thumb_long.jpg", quality=93)
print(OUT / "thumb_long.jpg")

"""サムネの下地: 海面を 58m 上げた東アジアを、字の無い 1 コマで描く。python episodes/antarctic/thumb_bg.py [lon lat span tilt] → assets/thumb_map.png"""
import os
import sys
from pathlib import Path

os.environ["NAZE_ASPECT"] = "landscape"
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parents[1]))
sys.path.insert(0, str(HERE))
from PIL import Image, ImageDraw  # noqa: E402

import parts  # noqa: E402
import scene  # noqa: E402
from naze.config import H, W  # noqa: E402

view = tuple(float(v) for v in sys.argv[1:5]) if len(sys.argv) >= 5 else parts.EASIA
line = dict(id="x", text="", start=0.0, end=10.0, scene=parts.MAP(view, parts.FLOOD(rise_s=0.5)))
L = {"x": line}
img = Image.new("RGBA", (W, H), (10, 18, 40, 255))
ctx = dict(lines=[line], cur=line, L=L, k=0.95, at=lambda i: 0.0, defs=L, cta=False)
scene.draw(img, ImageDraw.Draw(img), 9.5, ctx)
(HERE / "assets").mkdir(exist_ok=True)
img.convert("RGB").save(HERE / "assets" / "thumb_map.png")
print(HERE / "assets" / "thumb_map.png")

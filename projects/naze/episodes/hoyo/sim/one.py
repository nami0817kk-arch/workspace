"""1 行だけを大きく描いて見る。python episodes/hoyo/sim/one.py ch2 b4,b6 [k=0.9] → out/hoyo/one.jpg(2 枚を半分の大きさで縦に)"""
import os
import sys
from pathlib import Path

name, ids = sys.argv[1], sys.argv[2].split(",")
kpos = float(sys.argv[3]) if len(sys.argv) > 3 else 0.9
os.environ["NAZE_ASPECT"] = "portrait" if name.startswith("s") else "landscape"
ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(ROOT / "episodes" / "hoyo"))
from PIL import Image, ImageDraw  # noqa: E402

import parts  # noqa: E402
import scene  # noqa: E402
from naze.config import H, W  # noqa: E402

ep = parts.ep_for(name)
t, lines = 0.0, []
for l in ep["lines"]:
    dd = max(1.5, len(l.get("say") or l["text"]) / 7.0)
    lines.append(dict(l, start=t, end=t + dd))
    t += dd + 0.3
L = {l["id"]: l for l in lines}
defs = {l["id"]: l for l in ep["lines"]}
out = []
for i in ids:
    l = L[i]
    img = Image.new("RGBA", (W, H), (10, 18, 40, 255))
    ctx = dict(lines=lines, cur=l, L=L, k=kpos, at=lambda j: L[j]["start"], defs=defs, cta=False)
    scene.draw(img, ImageDraw.Draw(img), l["start"] + kpos * (l["end"] - l["start"]), ctx)
    out.append(img.convert("RGB").resize((W // 2, H // 2), Image.LANCZOS))
sheet = Image.new("RGB", (W // 2 * (1 if W > H else len(out)), H // 2 * (len(out) if W > H else 1)))
for j, im in enumerate(out):
    sheet.paste(im, (0, j * H // 2) if W > H else (j * W // 2, 0))
p = ROOT / "out" / "hoyo" / "one.jpg"
sheet.save(p, quality=90)
print(p)

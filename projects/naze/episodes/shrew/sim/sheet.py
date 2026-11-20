"""トガリネズミの回の画面を、時間割(無ければ字数から見積もり)で行ごとに 1 コマ描いて、1 枚に並べる。
python shrew_sheet.py ch1 [k=0.85]"""
import json
import os
import sys
from pathlib import Path

name = sys.argv[1]
kpos = float(sys.argv[2]) if len(sys.argv) > 2 else 0.85
os.environ["NAZE_ASPECT"] = "portrait" if name.startswith("s") else "landscape"
ROOT = Path(r"C:\Users\なみ\dev\wt-naze\projects\naze")
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(ROOT / "episodes" / "shrew"))
from PIL import Image, ImageDraw  # noqa: E402

import parts  # noqa: E402
import scene  # noqa: E402
from naze import overlay as ov  # noqa: E402
from naze.config import H, W  # noqa: E402

ep = parts.ep_for(name)
tlp = ROOT / "out" / f"shrew_{name}" / "timeline.json"
if tlp.exists():
    lines = json.loads(tlp.read_text(encoding="utf-8"))["lines"]
else:
    t, lines = 0.0, []
    for l in ep["lines"]:
        d = max(1.5, len(l.get("say") or l["text"]) / 7.0)
        lines.append(dict(l, start=t, end=t + d))
        t += d + 0.3
defs = {l["id"]: l for l in ep["lines"]}
L = {l["id"]: l for l in lines}
ctx0 = {}
tiles = []
for l in lines:
    if l["id"] == "cta":
        continue
    t = l["start"] + kpos * (l["end"] - l["start"])
    img = Image.new("RGBA", (W, H), (10, 18, 40, 255))
    dr = ImageDraw.Draw(img)
    ctx = dict(ctx0, lines=lines, cur=l, L=L, k=kpos, at=lambda i: L[i]["start"], defs=defs, cta=False)
    scene.draw(img, dr, t, ctx)
    ctx0["_wscenes"] = ctx.get("_wscenes", [])
    dr = ImageDraw.Draw(img)
    sub = defs[l["id"]].get("sub") or ov.auto_sub(l["text"], 52 if W > H else 64, 1700 if W > H else 980)
    ov.rows(dr, ov.page_of(sub, t, l["start"], l["end"]), 975 if W > H else 1640, 52 if W > H else 64)
    dr.text((20, 20), l["id"], fill=(255, 80, 80), font=ov.font(60))
    tiles.append(img.convert("RGB").resize((W // 4, H // 4)))
cols = 4 if W > H else 6
rows = (len(tiles) + cols - 1) // cols
sheet = Image.new("RGB", (cols * W // 4, rows * H // 4), (0, 0, 0))
for i, im in enumerate(tiles):
    sheet.paste(im, ((i % cols) * W // 4, (i // cols) * H // 4))
out = ROOT / "out" / "shrew" / f"sheet_{name}.jpg"
sheet.save(out, quality=85)
print(out, len(tiles))

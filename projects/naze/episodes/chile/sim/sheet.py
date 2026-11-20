"""声を作る前に、章の全行のコマを1枚に並べる(時間は 1 秒 7 字の見積もり。声のあとは本物の時間割を使う)。
python episodes/chile/sim/sheet.py ch1 → out/chile_ch1/sheet_lines.jpg"""
import json
import os
import sys
from pathlib import Path

name = sys.argv[1]
ROOT = Path(__file__).resolve().parents[3]
os.environ["NAZE_ASPECT"] = "portrait" if name.startswith("s") else "landscape"
sys.path.insert(0, str(ROOT))
from PIL import Image, ImageDraw  # noqa: E402

from naze.__main__ import load  # noqa: E402
from naze import sim_ep, overlay as ov  # noqa: E402
from naze.config import OUT, W, H  # noqa: E402

folder = ROOT / "episodes" / "chile" / name
ep = load(folder)
out = OUT / f"chile_{name}"
out.mkdir(parents=True, exist_ok=True)
tlp = out / "timeline.json"
if not tlp.exists() or json.loads(tlp.read_text(encoding="utf-8")).get("estimate"):
    t, res = 0.0, []
    for l in ep["lines"]:
        d = max(1.5, len(l.get("say") or l["text"]) / 7.0)
        res.append(dict(id=l["id"], text=l["text"], start=t, end=t + d))
        t += d + 0.25
    tlp.write_text(json.dumps(dict(lines=res, total=t, estimate=True), ensure_ascii=False), encoding="utf-8")
tl = json.loads(tlp.read_text(encoding="utf-8"))
fr, nf = sim_ep.frame_fn(ep, out)
cols = 4
tw, th = (480, 270) if W > H else (270, 480)
lines = [l for l in tl["lines"] if l["id"] != "cta"]
rows = (len(lines) + cols - 1) // cols
sheet = Image.new("RGB", (tw * cols, (th + 34) * rows), (16, 16, 16))
d = ImageDraw.Draw(sheet)
f = ov.font(20)
for i, l in enumerate(lines):
    t = l["start"] + (l["end"] - l["start"]) * 0.7
    im = fr(int(t * 30) + 1).resize((tw, th))
    x, y = (i % cols) * tw, (i // cols) * (th + 34)
    sheet.paste(im, (x, y + 34))
    d.text((x + 6, y + 6), f"{i + 1}. {l['text'][:22]}", font=f, fill=(255, 255, 255))
    print(i + 1, flush=True)
sheet.save(out / "sheet_lines.jpg", quality=88)
print(out / "sheet_lines.jpg")

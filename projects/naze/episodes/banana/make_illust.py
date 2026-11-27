"""バナナの回の、実写の無い場面(野生の種ありバナナ・断面の黒い点・子株・枯れる農園・昔の積み出し・培養の苗)の絵を、Cloudflare Workers AI の FLUX.1 schnell(無料枠)で作る。
画面では右上に「イメージ(AI で作成)」と出す(assets/sources.json に ai=True で控える)。python episodes/banana/make_illust.py
出力は assets/stock/ai_<名前><番号>.jpg(2 枚ずつ作り、目で見て良いほうを lines.py で選ぶ)。"""
import json
import sys
import time
from pathlib import Path

sys.path.insert(0, r"C:/Users/なみ/dev/workspace/platform/ai-lab/src")
from imagegen.config import load_dotenv  # noqa: E402

load_dotenv()
from imagegen.connectors.images_cloudflare import CloudflareImages  # noqa: E402

HERE = Path(__file__).resolve().parent
OUT = HERE / "assets" / "stock"
OUT.mkdir(parents=True, exist_ok=True)
STYLE = (" Photorealistic, natural light, cinematic, documentary look, highly detailed."
         " No text, no letters, no numbers, no labels, no logo, no watermark.")
P = {
    "wild": ("A wild seeded banana Musa acuminata cut open lengthwise on a wooden board, the small green-yellow fruit packed full of many hard round black seeds "
             "the size of adzuki beans, very little white flesh between the seeds, a second whole wild banana beside it"),
    "dots": ("Extreme macro photo of a single thin cross-section slice of a ripe yellow banana on a white plate, the cream colored flesh with a tiny ring "
             "of small dark brown dots in the very center, soft daylight"),
    "sucker": ("Base of a banana plant in a plantation, thick green pseudostem at ground level with three young banana suckers, small shoots with rolled leaves "
               "growing from the base beside the mother plant, brown soil, dappled tropical light"),
    "sick": ("A row of dying banana plants in a tropical plantation, the leaves turned yellow and brown and collapsed hanging down around the trunks "
             "like a skirt, some plants toppled, healthy green banana plants far in the background, overcast light"),
    "stem": ("Close-up of a cut cross section of a banana plant trunk pseudostem, pale layered tissue with many dark reddish brown discolored strands "
             "and spots in the vascular tissue, plant disease symptom, outdoors"),
    "old": ("Old 1920s style sepia photograph, workers in hats carrying whole large bunches of green bananas on their shoulders up a wooden gangplank "
            "onto an old steamship at a tropical wooden pier, palm trees"),
    "jar": ("Rows of small glass jars on laboratory shelves, each jar holding a tiny green banana plantlet growing in clear gel, bright white light, "
            "plant tissue culture laboratory"),
}
cf = CloudflareImages()
for key, p in P.items():
    for tag in "12":
        dest = OUT / f"ai_{key}{tag}.jpg"
        if dest.exists():
            continue
        for attempt in range(3):
            try:
                img = cf.generate(p + "." + STYLE, steps=8, size="1344x768")[0]
                dest.write_bytes(img.data)
                print("ok", dest.name, flush=True)
                break
            except Exception as e:
                print("ng", dest.name, str(e)[:200], flush=True)
                time.sleep(5)
sp = HERE / "assets" / "sources.json"
s = json.loads(sp.read_text(encoding="utf-8")) if sp.exists() else {}
for f in OUT.glob("ai_*.jpg"):
    s[f.name] = dict(ai=True, by="AI", what=f.stem)
sp.write_text(json.dumps(s, ensure_ascii=False, indent=1), encoding="utf-8")

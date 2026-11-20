"""宇宙で冷えない回の場面の絵を Cloudflare Workers AI の FLUX.1 schnell(無料枠)で作る。
画面では「イメージ」と隅に出す。実在の人の顔・旗・紋章・機関の印は描かせない。python episodes/space-heat/make_illust.py
出力は episodes/space-heat/assets/illust_<名前><番号>.jpg(2 枚ずつ作り、目で見て良いほうを parts.py で選ぶ)。"""
import sys
import time
from pathlib import Path

sys.path.insert(0, r"C:/Users/なみ/dev/workspace/platform/ai-lab/src")
from imagegen.config import load_dotenv  # noqa: E402

load_dotenv()
from imagegen.connectors.images_cloudflare import CloudflareImages  # noqa: E402

OUT = Path(__file__).resolve().parent / "assets"
OUT.mkdir(exist_ok=True)
STYLE = (" Painterly realistic illustration, natural colors, cinematic wide composition, 16:9, highly detailed."
         " No text, no letters, no numbers, no logo, no watermark, no flags, no insignia, faces not visible.")
P = {
    "iss": "A large modular space station orbiting high above the blue Earth, long golden solar panel wings, "
           "big flat white radiator panels sticking out from the central truss, black space, thin blue atmosphere line on the horizon",
    "radiator": "Close view of large flat white rectangular radiator panels on a space station truss, seen edge-on against the bright sun, "
                "the blue Earth below, deep black space, sharp sunlight and shadow",
    "dark": "A space station passing from sunlight into the night side of the Earth, half of the station lit by a golden sunset glow, "
            "the other half in deep shadow, city lights on the dark Earth below",
    "suit": "An astronaut in a white spacesuit floating on a spacewalk outside a space station, holding a handrail, "
            "the blue Earth far below, bright sun glare, visor reflective gold so no face is visible",
    "thermos": "A stainless steel vacuum flask cut in half to show its double wall and the empty gap between the walls, "
               "hot steam rising from coffee inside, on a wooden table, soft warm light",
    "window": "Inside a space station module, white walls covered with equipment racks and cables, glowing screens, "
              "a round window showing the Earth, warm interior light, nobody in view",
}
cf = CloudflareImages()
for key, p in P.items():
    for tag in "12":
        dest = OUT / f"illust_{key}{tag}.jpg"
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

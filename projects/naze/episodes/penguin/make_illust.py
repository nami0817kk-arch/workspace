"""ペンギンの回の実写が無い場面(卵を足に乗せたオス・吹雪の中の群れ・晴れた冬の夜空・赤道のペンギン)の絵を、
Cloudflare Workers AI の FLUX.1 schnell(無料枠)で作る。画面では右上に「イメージ(AI で作成)」と出す。
python episodes/penguin/make_illust.py → assets/stock/ai_<名前><番号>.jpg(2 枚ずつ。目で見て良いほうを lines.py で選ぶ)"""
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
STYLE = (" Photorealistic wildlife documentary photograph, natural light, highly detailed, sharp focus."
         " No text, no letters, no numbers, no labels, no logo, no watermark, no people.")
P = {
    "egg": ("Close-up at ground level of the feet of an adult emperor penguin standing on Antarctic sea ice, "
            "a single white egg resting on top of its black feet, partly covered by a fold of feathered belly skin, "
            "blue winter twilight, blowing snow"),
    "huddle": ("Hundreds of adult emperor penguins packed tightly together in a dense huddle on flat Antarctic sea ice during a blizzard, "
               "snow blowing sideways, dim blue polar winter light, wide shot"),
    "night": ("Emperor penguin colony standing on flat Antarctic sea ice under a clear starry night sky, polar winter, "
              "faint blue twilight on the horizon, frost on the penguins' backs, wide shot"),
    "galapagos": ("A small Galapagos penguin standing on black volcanic lava rock by the sea under hot equatorial sun, "
                  "flippers held out away from its body, leaning forward, cacti in the background"),
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

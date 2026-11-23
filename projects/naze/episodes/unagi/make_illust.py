"""うなぎの回の、実写の無い場面(稚魚・海の中の子ども・川のうなぎ・かば焼き)の絵を、Cloudflare Workers AI の FLUX.1 schnell(無料枠)で作る。
画面では右上に「イメージ(AI で作成)」と出す(assets/sources.json に ai=True で控える)。python episodes/unagi/make_illust.py
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
    "kaba": ("Overhead close-up of Japanese unagi kabayaki: two flat rectangular butterflied eel fillets, skin side down, no head, no fins, no scales, "
             "grilled with a glossy dark brown sweet soy glaze and light char marks, laid on white rice in a black lacquered square box, "
             "a small dish of sansho pepper beside it, warm soft light, wooden table"),
    "kabayaki": ("Close-up of Japanese grilled eel kabayaki, glossy brown sweet soy glaze, slightly charred, laid on white rice "
                 "in a black lacquered box, steam rising, warm restaurant light, wooden table"),
    "glass": ("Macro photo of many tiny transparent glass eels, each about six centimeters long and thin as a toothpick, "
              "wriggling in a shallow white tray of water, you can see through their bodies, two small dark eyes each"),
    "palm": ("Macro photo of a few tiny transparent glass eels, thin as toothpicks, wriggling in a little water cupped in a wet human palm at night, "
             "lit by a headlamp, dark background"),
    "net": ("A fisherman wearing a headlamp standing knee deep at a dark river mouth on a moonless winter night, holding a small hand net "
            "with a long handle in the water, the only light is the headlamp beam on the black water, Japan"),
    "lepto": ("Underwater photo in the deep blue open ocean of a single eel larva, leptocephalus, a flat transparent body shaped like a willow leaf, "
              "small head with dark eyes, almost invisible, dark blue water, tiny floating particles"),
    "river": ("Underwater photo of a Japanese freshwater eel Anguilla japonica, long smooth olive-brown body, swimming between round stones "
              "on the bottom of a clear shallow river, sunlight rays through the water"),
    "farm": ("Inside a Japanese eel farm greenhouse, large rectangular concrete pond with dark water, aeration paddle wheels splashing, "
             "warm humid air, plastic roof, no people"),
    "silver": ("Underwater photo of an adult silver eel with metallic silver belly and dark back swimming downward in the dark open ocean, "
               "deep blue water, faint light from above"),
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

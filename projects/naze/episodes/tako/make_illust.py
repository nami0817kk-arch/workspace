"""タコの回の実写が無い場面(体の中・大昔・宇宙)の絵を、Cloudflare Workers AI の FLUX.1 schnell(無料枠)で作る。
画面では右上に「イメージ(AI で作成)」と出す(assets/sources.json に ai=True で控える)。python episodes/tako/make_illust.py
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
STYLE = (" Photorealistic, natural underwater light, cinematic, documentary look, highly detailed."
         " No text, no letters, no numbers, no labels, no logo, no watermark, no people.")
P = {
    "hearts": ("Scientific cutaway visualization of a living octopus seen from the side, the body is semi-transparent and glowing softly, "
               "inside are three small hearts: two small hearts at the base of the two gills and one larger heart in the middle, "
               "blue blood flowing through vessels, dark blue ocean background"),
    "comet": ("A large icy comet with a glowing tail approaching the young blue Earth in space, chunks of ice and frozen particles around it, "
              "dramatic sunlight from the side, deep space background"),
    "shell": ("Ancient ocean five hundred million years ago, a small primitive cephalopod with a long straight narrow cone-shaped shell "
              "divided into chambers, short tentacles coming out of the shell opening, swimming above a muddy seafloor, murky green water"),
    "tenarms": ("Ancient shallow sea floor three hundred million years ago, a small soft-bodied squid-like animal with ten arms covered in suckers, "
                "large eyes, resting on muddy limestone seafloor, murky water, soft light from above"),
    "coconut": ("A small veined octopus on a sandy tropical seafloor carrying two stacked halves of a brown coconut shell under its body, "
                "walking on its stiff arms like stilts, clear water, coral rubble around"),
    "skinlab": ("A small piece of octopus skin with tiny brown and orange color spots lying in a glass petri dish in a dark laboratory, "
                "lit by a soft blue light from above, macro photograph"),
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
# 出典の控え(右上に「イメージ(AI で作成)」)
sp = HERE / "assets" / "sources.json"
s = json.loads(sp.read_text(encoding="utf-8")) if sp.exists() else {}
for f in OUT.glob("ai_*.jpg"):
    s[f.name] = dict(ai=True, by="AI", what=f.stem)
sp.write_text(json.dumps(s, ensure_ascii=False, indent=1), encoding="utf-8")

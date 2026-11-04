"""チリの回の場面の絵(歴史の場面・土地の空気)を Cloudflare Workers AI の FLUX.1 schnell(無料枠)で作る。
画面では「イメージ」と隅に出す。実在の人の顔・旗・紋章は描かせない。python episodes/chile/make_illust.py
出力は episodes/chile/assets/illust_<名前><番号>.jpg(2 枚ずつ作り、目で見て良いほうを parts.py で選ぶ)。"""
import sys
import time
from pathlib import Path

sys.path.insert(0, r"C:/Users/なみ/dev/workspace/platform/ai-lab/src")
from imagegen.config import load_dotenv  # noqa: E402

load_dotenv()
from imagegen.connectors.images_cloudflare import CloudflareImages  # noqa: E402

OUT = Path(__file__).resolve().parent / "assets"
OUT.mkdir(exist_ok=True)
STYLE = (" Painterly historical illustration, rich muted colors, soft golden light, cinematic wide composition, 16:9, highly detailed."
         " No text, no letters, no numbers, no logo, no watermark, no flags, no emblems, faces small and not detailed.")
P = {
    "valley": "Sixteenth century Spanish riders with horses and pack mules entering a wide green valley at dawn, "
              "a huge wall of snow-capped Andes mountains rising behind the valley, a river crossing the plain, seen from a hill",
    "pass": "A narrow mountain pass high in the Andes in winter, deep snow drifts closing the path, a lonely stone shelter, "
            "towering icy peaks on both sides, blowing snow, cold blue light",
    "nitrate": "A nineteenth century nitrate works in a vast barren desert, white mounds of mineral, rail carts and a small steam locomotive, "
               "workers seen from far away, bare brown mountains, harsh sun, dust in the air",
    "titicaca": "A small grey patrol boat on a vast deep blue high-altitude lake, traditional reed boats near the shore, "
                "snowy mountains on the far horizon, thin clear air, bright sun",
    "araucaria": "An ancient forest of tall araucaria monkey-puzzle trees on volcanic slopes in southern Chile, a snow-capped volcano behind, "
                 "a wooden house far away, morning mist",
    "strait": "A small nineteenth century two-masted sailing schooner in a narrow cold channel, dark stormy sky, "
              "snowy jagged mountains on both shores, rough grey water, a wooden fort on a low hill",
    "vineyard": "Rows of grape vines in a dry sunny valley, irrigation channel, the massive snowy Andes wall in the background, late afternoon light",
    "araucaria_b": "A forest of Araucaria araucana trees with tall bare trunks and flat umbrella-shaped crowns of spiky branches only at the top, "
                   "on a volcanic slope in southern Chile, a snow-capped conical volcano behind, morning mist, no houses",
    "king": "A lone nineteenth century European man in a dark frock coat and top hat seen from behind, standing at the edge of a wild southern forest, "
            "looking toward distant smoke from small wooden houses, dramatic cloudy sky, faces not visible",
    "pampa": "Endless flat golden grassland of Patagonia under a huge sky, wind bending the grass, a distant line of mountains to the west",
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

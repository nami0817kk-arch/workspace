"""ナイアガラの回の場面の絵(滝・川・昔の場面)を Cloudflare Workers AI の FLUX.1 schnell(無料枠)で作る。
画面では「イメージ」と隅に出す。実在の人の顔・旗・紋章は描かせない。python episodes/niagara/make_illust.py
出力は episodes/niagara/assets/illust_<名前><番号>.jpg(2 枚ずつ作り、目で見て良いほうを parts.py で選ぶ)。"""
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
         " No text, no letters, no numbers, no logo, no watermark, no flags, no signs, people small and faces not visible.")
P = {
    "falls": "A huge horseshoe-shaped waterfall seen from above at an angle, a curved brink of falling white water, thick mist rising, "
             "a deep green river gorge below, autumn trees on the cliffs, bright daylight",
    "night": "A huge horseshoe-shaped waterfall at night under a dark blue sky, thinner streams of water falling than in daytime, "
             "faint mist, the falls softly lit by moonlight, quiet dark river gorge",
    "dry": "A tall dry rock cliff where a waterfall used to be, the riverbed above drained and exposed, wet dark rock layers, "
           "a temporary earth dam across the river upstream, a few tiny workers and drilling rigs on the rocks, 1969, overcast light",
    "ice": "A nineteenth century winter scene, a wide river suddenly almost dry, a rocky riverbed exposed with puddles, "
           "small figures of people in old coats walking and riding horses across the riverbed, ice piled on the shore, grey sky",
    "intake": "Large concrete water intake gates on the bank of a wide fast river above a waterfall, mist from the falls far downstream, "
              "a hydroelectric power station building, clear afternoon",
    "gorge": "A deep straight-sided river gorge cut into layered rock, a fast green river with white rapids at the bottom, "
             "horizontal rock layers visible on the cliff walls, the mist of a distant waterfall upstream, aerial view",
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

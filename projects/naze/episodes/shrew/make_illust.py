"""トガリネズミの回の場面の絵(動物の写真風)を Cloudflare Workers AI の FLUX.1 schnell(無料枠)で作る。
画面では「イメージ」と隅に出す。人は描かせない。python episodes/shrew/make_illust.py
出力は episodes/shrew/assets/illust_<名前><番号>.jpg(2 枚ずつ作り、目で見て良いほうを parts.py で選ぶ)。"""
import sys
import time
from pathlib import Path

sys.path.insert(0, r"C:/Users/なみ/dev/workspace/platform/ai-lab/src")
from imagegen.config import load_dotenv  # noqa: E402

load_dotenv()
from imagegen.connectors.images_cloudflare import CloudflareImages  # noqa: E402

OUT = Path(__file__).resolve().parent / "assets"
OUT.mkdir(exist_ok=True)
STYLE = (" Realistic nature documentary photograph style, sharp focus, natural colors, soft light, cinematic wide composition, 16:9, highly detailed."
         " No text, no letters, no numbers, no logo, no watermark, no people.")
P = {
    "shrew_eat": "Macro close-up of a tiny grey-brown Etruscan pygmy shrew with a long pointed snout eating a cricket on mossy forest floor, leaf litter, shallow depth of field",
    "shrew_run": "A tiny brown common shrew with a long pointed nose running quickly through dry leaves on the forest floor searching for insects, motion, low angle",
    "shrew_snow": "A tiny dark brown shrew with a pointed nose on fresh white snow in a cold winter forest, small footprints in the snow, cold blue morning light",
    "elephant": "A large African elephant slowly eating grass and branches on a wide savanna at golden hour, acacia trees, dust in the air",
    "hummingbird": "A tiny hummingbird asleep at night on a thin branch, puffed up feathers, eyes closed, dark blue night background, cold air, macro",
    "shrew_eat_b": "Macro photo of a shrew (not a mouse): very long thin pointed flexible snout, tiny black bead eyes, ears hidden in velvety grey fur, very small body, eating a cricket on moss",
    "mouse_elephant": "A tiny shrew standing on a rock in the foreground and a huge elephant far in the background on a savanna, dramatic size difference, low angle",
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

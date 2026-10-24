"""お市（想像上の人物）の感情の場面の絵と情景の絵の候補を作る（FLUX schnell・無料枠）。
    python tools/gen_story_faces.py P1 P2 --n 4   # 候補を out/story/oichi3/cand/<場面>_<連番>.jpg に（既存の連番の続き）
実在の肖像・写真の加工はしない。無料枠の消費は out/story/oichi3/count.txt に数える。
"""
from __future__ import annotations
import argparse, sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
from gen_story_art import generate  # noqa: E402

OUT = ROOT / "out/story/oichi3"
CAND = OUT / "cand"
WOMAN = ("the same imaginary Japanese noblewoman in her early thirties, oval face, calm clear eyes, slender nose, "
         "black hair tied back in one long ponytail at the nape, plain pale off-white mourning kimono with a modest collar, "
         "dignified and sorrowful, Japanese features, ")
STYLE = ("cinematic period-drama film still, Sengoku-period Japan, low warm firelight, muted dusty crimson and sumi-ink black palette, "
         "desaturated, 35mm lens, shallow depth of field, fine film grain, subject centered, vertical portrait framing, "
         "no text, no letters, no calligraphy, no signs, no signature, no watermark, no logo.")
SC = {
 "P1": WOMAN + "close-up of her face turned slightly to the side, looking straight ahead with firm quiet resolve, gently shaking her head in refusal, lips closed, dim castle interior",
 "P2": WOMAN + "close-up of her face looking down and away with regret, orange glow of distant flames reflected on her cheek, eyes lowered, remembering a burning castle",
 "P3": WOMAN + "tight close-up of her face, holding back tears, a trembling gentle smile, eyes glistening, soft light from a doorway",
 "P4": WOMAN + "serene profile view at a wooden window at night, a small distant fire glowing far away behind her, peaceful calm expression, eyes gently closed or looking far away",
 "P5": WOMAN + "close-up facing the viewer directly, looking straight into the camera with tears in her eyes, a quiet questioning gaze, dark background",
 "S1": "a Japanese castle keep at night seen from outside, warm lantern light glowing in the windows suggesting a banquet, many bonfires around the castle, tiny distant figures, dark sky",
 "S2": "view of a dark wooden castle gate in morning mist, exactly three small young girls seen strictly from behind walking out into the bright light, wearing kimono of three clearly different solid colors: red, indigo blue and green, the gate has plain bare wood with no plaque, no sign, no markings, no decoration",
 "S3": "misty battlefield at dawn, two opposing armies facing each other far away, long rows of banners on poles, tiny soldiers without visible faces, plain unmarked banners with no writing",
 "S4": "a long corridor of a large Japanese mansion, three young girls in kimono seen strictly from behind walking along the polished wooden floor, exactly three girls, sliding paper doors, soft light, no faces",
}

def one(args):
    key, i = args
    dest = CAND / f"{key}_{i:02d}.jpg"
    for _ in range(3):
        try:
            data = generate(f"{SC[key]}. {STYLE}")
            dest.write_bytes(data)
            with open(OUT / "count.txt", "a") as f:
                f.write("1\n")
            return dest.name
        except Exception as e:  # noqa: BLE001
            print("ng", key, str(e)[:120], flush=True)
    return None

def main():
    p = argparse.ArgumentParser()
    p.add_argument("keys", nargs="+")
    p.add_argument("--n", type=int, default=4)
    a = p.parse_args()
    jobs = []
    for k in a.keys:
        have = len(list(CAND.glob(f"{k}_*.jpg")))
        jobs += [(k, have + j + 1) for j in range(a.n)]
    with ThreadPoolExecutor(3) as ex:
        for r in ex.map(one, jobs):
            print("ok" if r else "fail", r, flush=True)

if __name__ == "__main__":
    main()

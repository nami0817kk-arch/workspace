"""物語完結型ショートの絵を Cloudflare Workers AI の FLUX.1 schnell（無料枠）で作る。

    python tools/gen_story_art.py scripts/story/oichi_s1.yaml [--only 03,05] [--redo]

- 絵は out/story/<名前>/NN.jpg（NN は台本の cuts の通し番号。リポジトリには入れない＝out/ は .gitignore）
- FLUX schnell は正方形（1024x1024）しか出せない（width/height を渡すと 400）。画面は縦 9:16 なので、
  描くときに中央の縦長（約 576x1024）を使う（chiso/storyshort.py が切る）。だから指示には「被写体は中央」を入れてある
- 実在人物の顔写真・肖像の加工はしない。想像上の姿として描く（指示に実名を入れない）
- 文字や落書き風のサインが混じることがある。作ったら1枚ずつ目で見て、悪いものは --only NN --redo で作り直す
- 鍵は ai-lab の .env（CLOUDFLARE_ACCOUNT_ID / CLOUDFLARE_API_TOKEN）
"""
from __future__ import annotations

import argparse
import random
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))
sys.path.insert(0, r"C:/Users/なみ/dev/workspace/platform/ai-lab/src")

STYLE = ("Historical drama still from the Japanese Sengoku period, muted calm earth tones, "
         "photorealistic painterly rendering with cinematic soft lighting, expressive readable face, "
         "vertical portrait composition with the main subject centered and large, "
         "no text, no letters, no calligraphy, no signature, no watermark, no logo.")


def prompts(doc: dict) -> list[tuple[int, str]]:
    """(通し番号 1〜, 完成した指示) の並び。"""
    out, k = [], 0
    for line in doc["lines"]:
        for cut in line["cuts"]:
            k += 1
            out.append((k, f"{cut['prompt']}. {STYLE}"))
    return out


def generate(prompt: str, seed: int | None, steps: int = 6) -> bytes:
    from imagegen.config import load_dotenv
    load_dotenv()
    from imagegen.connectors.images_cloudflare import API_BASE, CloudflareImages, _extract_image
    cf = CloudflareImages()
    url = f"{API_BASE}/{cf.account_id()}/ai/run/{cf.default_model}"
    payload = {"prompt": prompt, "steps": steps}
    # FLUX schnell（Cloudflare）は seed を受け取らない（400）。作り直せば毎回違う絵になる
    data, _mime = _extract_image(cf.request("POST", url, json=payload, timeout=180))
    return data


def main(argv=None) -> int:
    import yaml
    p = argparse.ArgumentParser()
    p.add_argument("script")
    p.add_argument("--only", default="", help="作る番号（例 03,05）。省けば全部")
    p.add_argument("--redo", action="store_true", help="あっても作り直す（前の絵は NN.old.jpg に残す）")
    p.add_argument("--seed", type=int, default=None, help="使わない（Cloudflare の FLUX は seed 不可。互換のため残す）")
    args = p.parse_args(argv)
    path = Path(args.script)
    doc = yaml.safe_load(path.read_text(encoding="utf-8"))
    out = ROOT / doc.get("art_dir", f"out/story/{path.stem.split('_')[0]}")
    out.mkdir(parents=True, exist_ok=True)
    only = {int(x) for x in args.only.split(",") if x.strip()}
    for k, prompt in prompts(doc):
        if only and k not in only:
            continue
        dest = out / f"{k:02d}.jpg"
        if dest.exists() and not args.redo:
            continue
        for attempt in range(4):
            try:
                seed = args.seed if args.seed is not None else (random.randint(1, 2**31 - 1) if args.redo else None)
                data = generate(prompt, seed)
                if dest.exists():
                    dest.replace(out / f"{k:02d}.old.jpg")
                dest.write_bytes(data)
                print("ok", dest.name, flush=True)
                break
            except Exception as e:  # noqa: BLE001
                print("ng", dest.name, str(e)[:160], flush=True)
                time.sleep(6)
    return 0


if __name__ == "__main__":
    sys.exit(main())

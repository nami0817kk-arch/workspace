"""物語完結型ショートの AI 絵を Cloudflare Workers AI の FLUX.1 schnell（無料枠）で作る。

    python tools/gen_story_art.py scripts/story/oichi_s2.yaml [--only A,D] [--redo]

- 台本の shots のうち kind: ai の絵だけ作る（実在の絵は assets のものを使う）。絵は <art_dir>/<shot>.jpg（out/ は .gitignore。リポジトリには入れない）
- FLUX schnell は正方形（1024x1024）しか出せない（width/height・seed を渡すと 400）。画面は縦 9:16 なので中央の縦長（約 576x1024）を使う
  （chiso/storyshort.py が切る）。指示は「被写体は中央」「顔を出さない（後ろ姿・手元・風景）」「人数を数える」で書く
- 第2版（10-22）：全 prompt に同じ前置き STYLE（同じ色調・レンズ・光）を付ける。実在の絵となじむよう、storyshort 側でも同じ色調補正をかける
- 実在人物の顔写真・肖像の加工はしない。想像上の姿として描く（指示に実名を入れない）。文字・落書き風のサインが混じることがあるので1枚ずつ目で見る
- 鍵は ai-lab の .env（CLOUDFLARE_ACCOUNT_ID / CLOUDFLARE_API_TOKEN）
"""
from __future__ import annotations

import argparse
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))
sys.path.insert(0, r"C:/Users/なみ/dev/workspace/platform/ai-lab/src")

# 全 AI 絵に共通の前置き（同じ色調・同じレンズ・同じ光）
STYLE = ("Low late-afternoon sunlight, muted dusty crimson and sumi-ink black palette, desaturated earth tones, "
         "35mm lens, shallow depth of field, fine film grain, painterly cinematic still of Sengoku-period Japan, "
         "vertical portrait composition with the main subject centered, "
         "no text, no letters, no calligraphy, no signs, no signature, no watermark, no logo.")


def prompts(doc: dict) -> list[tuple[str, str]]:
    """(shot の名前, 完成した指示) の並び（kind: ai の shot だけ）。"""
    return [(k, f"{s['prompt']}. {STYLE}") for k, s in doc.get("shots", {}).items() if s.get("kind", "ai") == "ai" and s.get("prompt") and not s.get("file")]


def generate(prompt: str, steps: int = 6) -> bytes:
    from imagegen.config import load_dotenv
    load_dotenv()
    from imagegen.connectors.images_cloudflare import API_BASE, CloudflareImages, _extract_image
    cf = CloudflareImages()
    url = f"{API_BASE}/{cf.account_id()}/ai/run/{cf.default_model}"
    # seed は受け取らない（400）。作り直せば毎回違う絵になる
    data, _mime = _extract_image(cf.request("POST", url, json={"prompt": prompt, "steps": steps}, timeout=180))
    return data


def main(argv=None) -> int:
    import yaml
    p = argparse.ArgumentParser()
    p.add_argument("script")
    p.add_argument("--only", default="", help="作る shot（例 A,D）。省けば全部")
    p.add_argument("--redo", action="store_true", help="あっても作り直す（前の絵は <名前>.old.jpg に残す）")
    args = p.parse_args(argv)
    path = Path(args.script)
    doc = yaml.safe_load(path.read_text(encoding="utf-8"))
    out = ROOT / doc.get("art_dir", f"out/story/{path.stem.split('_')[0]}")
    out.mkdir(parents=True, exist_ok=True)
    only = {x.strip() for x in args.only.split(",") if x.strip()}
    for key, prompt in prompts(doc):
        if only and key not in only:
            continue
        dest = out / f"{key}.jpg"
        if dest.exists() and not args.redo:
            continue
        for _ in range(4):
            try:
                data = generate(prompt)
                if dest.exists():
                    dest.replace(out / f"{key}.old.jpg")
                dest.write_bytes(data)
                print("ok", dest.name, flush=True)
                break
            except Exception as e:  # noqa: BLE001
                print("ng", dest.name, str(e)[:160], flush=True)
                time.sleep(6)
    return 0


if __name__ == "__main__":
    sys.exit(main())

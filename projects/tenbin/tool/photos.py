"""動物の写真を Pixabay から集めて切り抜き、ゲームに入れる。

このPCで順に流す（クラウドの環境からは Pixabay と rembg のモデルに届かない）:

    pip install requests rembg pillow onnxruntime
    python tool/photos.py fetch          # 候補を work/candidates/<種類>/ に集める（PIXABAY_API_KEY が要る）
    python tool/photos.py cutout         # 背景を消して work/cutout/<種類>/NN.png
    python tool/photos.py sheet          # work/sheet.html を開いて、使う写真の番号を選ぶ
    python tool/photos.py pick elephant 3 [--flip]   # 右向きにそろえて prototype/photos/ へ入れ、当たり判定を取る

work/ は git に入れない（素材を単体で公開しない。Pixabay の規約は素材そのものの再配布を禁じている）。
prototype/photos/ に入るのは、切り抜いてゲーム用に縮めた画像だけ。出典は prototype/photos/CREDITS.json。
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
WORK = ROOT / "work"
PHOTOS = ROOT / "prototype" / "photos"

# 種類: (名前, 検索語, ゲーム内の幅px)
ANIMALS = {
    "elephant": ("ぞう", "elephant side view isolated", 118),
    "giraffe": ("きりん", "giraffe side view isolated", 100),
    "rhino": ("サイ", "rhinoceros side view", 110),
    "hippo": ("カバ", "hippopotamus side view", 105),
    "polarbear": ("シロクマ", "polar bear isolated", 100),
    "panda": ("パンダ", "giant panda isolated", 95),
    "lion": ("ライオン", "lion side view isolated", 104),
    "croc": ("ワニ", "crocodile side view isolated", 128),
    "penguin": ("ペンギン", "penguin isolated white background", 36),
    "rabbit": ("うさぎ", "rabbit isolated white background", 48),
    "sheep": ("ひつじ", "sheep side view isolated", 70),
}


def fetch(per: int) -> None:
    import requests

    key = os.environ.get("PIXABAY_API_KEY")
    if not key:
        sys.exit("PIXABAY_API_KEY を環境変数に入れてください（https://pixabay.com/api/docs/）")
    credits = {}
    for kind, (_, query, _) in ANIMALS.items():
        res = requests.get("https://pixabay.com/api/", params={
            "key": key, "q": query, "image_type": "photo", "per_page": max(per, 3), "safesearch": "true"}, timeout=30)
        res.raise_for_status()
        out = WORK / "candidates" / kind
        out.mkdir(parents=True, exist_ok=True)
        for i, hit in enumerate(res.json().get("hits", [])[:per]):
            img = requests.get(hit["largeImageURL"], timeout=60)
            img.raise_for_status()
            (out / f"{i:02d}.jpg").write_bytes(img.content)
            credits[f"{kind}/{i:02d}"] = {"page": hit["pageURL"], "user": hit.get("user"), "license": "Pixabay Content License"}
        print(kind, len(list(out.glob("*.jpg"))), "枚")
    (WORK / "credits.json").write_text(json.dumps(credits, ensure_ascii=False, indent=1), encoding="utf-8")


def cutout() -> None:
    from rembg import new_session, remove

    session = new_session("isnet-general-use")
    for src in sorted((WORK / "candidates").glob("*/*.jpg")):
        dst = WORK / "cutout" / src.parent.name / (src.stem + ".png")
        if dst.exists():
            continue
        dst.parent.mkdir(parents=True, exist_ok=True)
        dst.write_bytes(remove(src.read_bytes(), session=session, alpha_matting=True))
        print(dst.relative_to(ROOT))


def sheet() -> None:
    rows = []
    for kind, (name, _, _) in ANIMALS.items():
        cells = "".join(
            f'<figure><img src="cutout/{kind}/{p.name}"><figcaption>{p.stem}</figcaption></figure>'
            for p in sorted((WORK / "cutout" / kind).glob("*.png")))
        rows.append(f"<h2>{name}（{kind}）</h2><div class=row>{cells}</div>")
    html = ("<!doctype html><meta charset=utf-8><title>写真えらび</title><style>body{font-family:sans-serif;background:#2fb6f0;color:#fff}"
            ".row{display:flex;flex-wrap:wrap;gap:8px}figure{margin:0;background:rgba(255,255,255,.15);padding:4px;border-radius:8px}"
            "img{height:120px;display:block}figcaption{text-align:center}</style>"
            "<p>右向き・横から・体が全部写っていて切れていないものを選ぶ。左向きなら pick に --flip</p>" + "".join(rows))
    (WORK / "sheet.html").write_text(html, encoding="utf-8")
    print(WORK / "sheet.html")


def pick(kind: str, idx: int, flip: bool, width: int | None) -> None:
    from PIL import Image, ImageOps

    name, _, default_w = ANIMALS[kind]
    src = WORK / "cutout" / kind / f"{idx:02d}.png"
    im = Image.open(src).convert("RGBA")
    im = im.crop(im.getchannel("A").point(lambda a: 255 if a >= 128 else 0).getbbox())
    if flip:
        im = ImageOps.mirror(im)
    # ゲームでは幅 120px 前後。画面の解像度3倍まで持てば十分なので、長い辺を 480px に
    im.thumbnail((480, 480), Image.LANCZOS)
    PHOTOS.mkdir(parents=True, exist_ok=True)
    out = PHOTOS / f"{kind}.png"
    im.save(out, optimize=True)
    subprocess.run(["node", str(ROOT / "tool" / "trace.js"), kind, str(out), name, str(width or default_w)], check=True, cwd=ROOT)
    credits_path = PHOTOS / "CREDITS.json"
    credits = json.loads(credits_path.read_text(encoding="utf-8")) if credits_path.exists() else {}
    all_credits = json.loads((WORK / "credits.json").read_text(encoding="utf-8"))
    credits[kind] = all_credits.get(f"{kind}/{idx:02d}", {})
    credits_path.write_text(json.dumps(credits, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    f = sub.add_parser("fetch")
    f.add_argument("--per", type=int, default=8, help="1種類あたりの候補数")
    sub.add_parser("cutout")
    sub.add_parser("sheet")
    p = sub.add_parser("pick")
    p.add_argument("kind", choices=ANIMALS)
    p.add_argument("idx", type=int)
    p.add_argument("--flip", action="store_true", help="左向きの写真を右向きにする")
    p.add_argument("--width", type=int, help="ゲーム内の幅px（既定は種類ごと）")
    a = ap.parse_args()
    if a.cmd == "fetch":
        fetch(a.per)
    elif a.cmd == "cutout":
        cutout()
    elif a.cmd == "sheet":
        sheet()
    else:
        pick(a.kind, a.idx, a.flip, a.width)


if __name__ == "__main__":
    main()

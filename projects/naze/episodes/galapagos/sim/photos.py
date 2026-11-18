"""ガラパゴスの生き物の写真を Wikimedia Commons から集める(許諾は CC0・PD・CC BY・CC BY-SA だけ)。
python photos.py list   → 候補を題材ごとに 6 枚ずつ、縮小して一覧 1 枚(out/galapagos/photos/sheet.jpg)と cand.json に
python photos.py get    → PICK の写真を幅 2400 で取り、photos.json に出典(作者・許諾・URL)を書く
写真は out/galapagos/photos/(git の外)。出典は photos.json(git に入れる)。"""
import json
import re
import sys
import time
from io import BytesIO
from pathlib import Path

import requests
from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
OUT = ROOT / "out" / "galapagos" / "photos"
API = "https://commons.wikimedia.org/w/api.php"
UA = {"User-Agent": "naze-video-tool/1.0 (educational video; contact via project)"}
OK = re.compile(r"^(cc0|public domain|pd|cc by(-sa)? [0-9.]+)", re.I)

TERMS = {
    "iguana": "Amblyrhynchus cristatus swimming OR feeding algae",
    "iguana2": "marine iguanas basking Galapagos",
    "dome": "Chelonoidis porteri Santa Cruz tortoise",
    "saddle": "saddleback tortoise Galapagos Espanola OR hoodensis",
    "penguin": "Spheniscus mendiculus",
    "finch": "Geospiza fortis",
    "sealion": "Zalophus wollebaeki",
    "lava": "Fernandina island Galapagos lava",
    "cactus": "Opuntia Galapagos Santa Fe OR echios",
}

PICK = {}   # 名前 → File:… (list の一覧を見て決める)


def search(q, n=6):
    r = requests.get(API, params=dict(action="query", format="json", generator="search", gsrsearch=f"filetype:bitmap {q}", gsrnamespace=6,
                                      gsrlimit=30, prop="imageinfo", iiprop="url|size|extmetadata", iiurlwidth=640), headers=UA, timeout=30).json()
    res = []
    for p in sorted(r.get("query", {}).get("pages", {}).values(), key=lambda p: p.get("index", 0)):
        ii = p["imageinfo"][0]
        md = ii.get("extmetadata", {})
        lic = md.get("LicenseShortName", {}).get("value", "")
        if not OK.match(lic) or ii["width"] < 1800 or ii["width"] < ii["height"]:
            continue
        res.append(dict(title=p["title"], thumb=ii["thumburl"], url=ii["url"], w=ii["width"], h=ii["height"], lic=lic,
                        artist=re.sub("<[^>]+>", "", md.get("Artist", {}).get("value", "")).strip(), page=ii["descriptionurl"]))
        if len(res) >= n:
            break
    return res


def cmd_list():
    OUT.mkdir(parents=True, exist_ok=True)
    cand = {k: search(q) for k, q in TERMS.items()}
    json.dump(cand, open(OUT / "cand.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    tw, th = 320, 200
    sheet = Image.new("RGB", (tw * 6, (th + 24) * len(cand)), (20, 20, 30))
    d = ImageDraw.Draw(sheet)
    f = ImageFont.truetype("C:/Windows/Fonts/meiryo.ttc", 16)
    for r, (k, lst) in enumerate(cand.items()):
        for c, it in enumerate(lst):
            try:
                im = Image.open(BytesIO(requests.get(it["thumb"], headers=UA, timeout=30).content)).convert("RGB")
            except Exception:
                continue
            im.thumbnail((tw, th))
            sheet.paste(im, (c * tw, r * (th + 24)))
            d.text((c * tw + 4, r * (th + 24) + th + 2), f"{k}{c}", font=f, fill=(255, 220, 80))
            time.sleep(0.2)
    sheet.save(OUT / "sheet.jpg", quality=88)
    print(OUT / "sheet.jpg")


def cmd_get(pick):
    cand = json.load(open(OUT / "cand.json", encoding="utf-8"))
    src = {}
    for name, key in pick.items():
        k, i = re.match(r"([a-z]+\d?)(\d)$", key).groups()
        it = cand[k][int(i)]
        r = requests.get(API, params=dict(action="query", format="json", titles=it["title"], prop="imageinfo", iiprop="url", iiurlwidth=1920), headers=UA, timeout=30).json()
        u = next(iter(r["query"]["pages"].values()))["imageinfo"][0]["thumburl"]
        if (OUT / f"{name}.jpg").exists():
            im = Image.open(OUT / f"{name}.jpg")
        else:
            for k in range(6):
                rr = requests.get(u, headers=UA, timeout=60)
                if rr.ok and rr.headers.get("content-type", "").startswith("image"):
                    break
                time.sleep(20 * (k + 1))
            im = Image.open(BytesIO(rr.content)).convert("RGB")
            if im.width > 2400:
                im = im.resize((2400, round(im.height * 2400 / im.width)), Image.LANCZOS)
        im.save(OUT / f"{name}.jpg", quality=92)
        src[name] = dict(file=it["title"], artist=it["artist"], license=it["lic"], page=it["page"])
        print(name, im.size, it["lic"], it["artist"][:40])
        time.sleep(8)
    json.dump(src, open(HERE / "photos.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)


if __name__ == "__main__":
    if sys.argv[1] == "list":
        cmd_list()
    else:
        cmd_get(dict(a.split("=") for a in sys.argv[2:]))

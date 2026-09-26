"""クラブ紹介の顔写真と場面写真を、名指しした Commons のファイルから取り込む（2026-09-26）。

ラ・リーガ20クラブ紹介で、下請けが選んだファイルを同じ形で取り込むための道具。
`plfaces.py` は Wikipedia の記事の代表画像を自動で取るが、クラブ時代の写真を選びたい・
顔を切り出したいときはこちら。**自由なライセンス（CC0/BY/BY-SA）でなければ取り込まない。**

    CLUB_LEAGUE=laliga python tools/clubfaces.py barcelona \\
        --person "legend|シャビ|Xavi Hernández 2011.jpg|Xavi|" \\
        --person "manager|ハンジ・フリック|Hansi Flick 2023.jpg|Hansi Flick|100,0,900,900" \\
        --scene episode "Camp Nou 1982.jpg"

- `--person` は `役割|日本語名|Commonsのファイル名|英語版の記事名|切り出し(x0,y0,x1,y1 or 空)`。
  役割は legend / manager / owner。書いた日本語名が `<key>_say.yaml` の `legend_rows` の1列目と
  一致していないと、名選手の節で顔が出ない
- `--scene <名前> <ファイル名>` は `assets/images/ll_<key>_<名前>/scene.jpg` に置く（逸話や歴史の節の頭に使う）
- 取り込んだあと**必ず開いて見る**（人違い・透かし・顔が小さい）
"""
from __future__ import annotations

import argparse
import hashlib
import io
import json
import sys
from pathlib import Path

import requests
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(Path(__file__).resolve().parent))
import clubleague  # noqa: E402
import plfaces  # noqa: E402

TAG = clubleague.prefix().rstrip("_")


def _fetch(name: str) -> tuple[dict, Image.Image]:
    name = name.removeprefix("File:").strip()
    row = plfaces.commons_file(name)
    if not row:
        raise SystemExit(f"■ {name}: Commons で自由なライセンスの画像として見つかりません（NC/ND・フェアユースは取り込まない）")
    data = requests.get(row["image_url"], headers=plfaces.UA, timeout=90).content
    return row, Image.open(io.BytesIO(data)).convert("RGB")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("key")
    ap.add_argument("--person", action="append", default=[])
    ap.add_argument("--scene", nargs=2, action="append", default=[], metavar=("NAME", "FILE"))
    args = ap.parse_args()

    # **クラブごとに別のフォルダと控え**（2026-09-26）。下請けが並んで動くので、
    # 同じ credits.json / faces.json に同時に書くとぶつかる
    out_dir = ROOT / "assets" / "photos" / TAG / args.key
    out_dir.mkdir(parents=True, exist_ok=True)
    ledger = out_dir / "credits.json"
    rows = json.loads(ledger.read_text(encoding="utf-8")) if ledger.exists() else []
    found = {r["file"]: r for r in rows}
    index_path = clubleague.data_dir() / f"faces_{args.key}.json"
    index = json.loads(index_path.read_text(encoding="utf-8")) if index_path.exists() else {}
    entry = index.setdefault(args.key, {})

    for spec in args.person:
        parts = (spec.split("|") + [""] * 5)[:5]
        role, name_ja, fname, page, crop = (p.strip() for p in parts)
        row, im = _fetch(fname)
        if crop:
            im = im.crop(tuple(int(v) for v in crop.split(",")))
        slug = f"{args.key}_{role}_{hashlib.md5(name_ja.encode('utf-8')).hexdigest()[:8]}.jpg"
        im.save(out_dir / slug, quality=92)
        entry[name_ja] = {"role": role, "file": f"assets/photos/{TAG}/{args.key}/{slug}", "page": page or name_ja}
        found[slug] = dict(row, page=page, file=slug, source="wikimedia", person=name_ja,
                           subject_check="未確認（取り込んだ人が目で確かめること）",
                           **({"note": f"切り出し {crop}"} if crop else {}))
        print(f"  {role:8s} {name_ja:16s} {row['license']:14s} {im.size} → assets/photos/{TAG}/{args.key}/{slug}")

    for name, fname in args.scene:
        row, im = _fetch(fname)
        scene_dir = ROOT / "assets" / "images" / f"{TAG}_{args.key}_{name}"
        scene_dir.mkdir(parents=True, exist_ok=True)
        im.save(scene_dir / "scene.jpg", quality=92)
        (scene_dir / "credits.json").write_text(json.dumps([{
            "file": "scene.jpg", "source": "wikimedia", "title": row["title"], "no_derivatives": False,
            "page_url": row["page_url"], "image_url": row["image_url"], "license": row["license"],
            "author": row["author"], "subject_check": "未確認（取り込んだ人が目で確かめること）"}],
            ensure_ascii=False, indent=2), encoding="utf-8")
        print(f"  scene    {name:16s} {row['license']:14s} {im.size} → assets/images/{TAG}_{args.key}_{name}/scene.jpg")

    index[args.key] = entry
    ledger.write_text(json.dumps(list(found.values()), ensure_ascii=False, indent=1), encoding="utf-8")
    index_path.write_text(json.dumps(index, ensure_ascii=False, indent=1), encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

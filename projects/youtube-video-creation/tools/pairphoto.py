# -*- coding: utf-8 -*-
"""縦の写真2枚を、横に並べた1枚にする（2026-09-25 指示）。

    python tools/pairphoto.py assets/images/a/01.jpg assets/images/b/01.jpg \
        --dir assets/images/20260924_pair_zidane

**なぜ要るか。**本文に敷く絵は1枚しか取らないので、縦の写真だと
`_photo_stage` が右に立てて、**左にべた塗りの面が残る**。
ユーザー指摘「左がグレーなので、二つの写真を横に並べて出して」（2026-09-25）。
サムネは `thumbnail.photos` で並べられるが、本文にはその仕組みが無かった。

出来上がりは 1920x1080。**切るのは上下ではなく左右**で、顔が真ん中寄りに残るように
それぞれを半分の枠いっぱいに敷く。出典の控え（credits.json）は両方ぶんを引き継ぐ。
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SIZE = (1920, 1080)
GAP = 6                     # 継ぎ目。0 だと2枚が1枚の絵に見える


def _fill(path: Path, box: tuple[int, int], focus: float = 0.38) -> Image.Image:
    """枠いっぱいに敷く。顔は上のほうにあるので、切るときは上を残す。"""
    with Image.open(path) as opened:
        image = opened.convert("RGB")
    w, h = image.size
    scale = max(box[0] / w, box[1] / h)
    image = image.resize((max(1, round(w * scale)), max(1, round(h * scale))), Image.LANCZOS)
    left = (image.width - box[0]) // 2
    top = min(max(0, round(image.height * focus - box[1] / 2)), image.height - box[1])
    return image.crop((left, top, left + box[0], top + box[1]))


def pair(paths: list[Path], out_dir: Path, focus: float = 0.38) -> Path:
    if len(paths) < 2:
        raise SystemExit("写真は2枚以上わたしてください")
    out_dir.mkdir(parents=True, exist_ok=True)
    n = len(paths)
    width = (SIZE[0] - GAP * (n - 1)) // n
    sheet = Image.new("RGB", SIZE, (12, 12, 12))
    for i, path in enumerate(paths):
        sheet.paste(_fill(path, (width, SIZE[1]), focus), (i * (width + GAP), 0))
    out = out_dir / "01.jpg"
    sheet.save(out, quality=92)

    # 出典は消さない。CC BY / BY-SA は表示が条件で、報道写真も出どころを残す決まり
    credits: list[dict] = []
    for path in paths:
        book = path.parent / "credits.json"
        if not book.exists():
            continue
        for row in json.loads(book.read_text(encoding="utf-8")):
            row = {**row, "file": "01.jpg", "note": "横に2枚並べた1枚に組んだ"}
            credits.append(row)
    if credits:
        (out_dir / "credits.json").write_text(
            json.dumps(credits, ensure_ascii=False, indent=1), encoding="utf-8")
    return out


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("photos", nargs="+", help="並べる写真（左から順に）")
    ap.add_argument("--dir", required=True, help="置き先のフォルダ")
    ap.add_argument("--focus", type=float, default=0.38,
                    help="縦のどこを残すか（0.0=上端 / 1.0=下端。既定 0.38）")
    args = ap.parse_args(argv)

    out = pair([ROOT / p if not Path(p).is_absolute() else Path(p) for p in args.photos],
               ROOT / args.dir if not Path(args.dir).is_absolute() else Path(args.dir),
               args.focus)
    print(f"  台本に: image: {out.relative_to(ROOT).as_posix()}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))

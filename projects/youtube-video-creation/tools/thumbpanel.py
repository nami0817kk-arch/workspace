"""サムネ用に、横長の写真の空いた所へ数字の表を描き込む（2026-10-01）。

ユーザー指示（ヤマル紹介）：「写真は全体にして、人に被らないように、ロゴと指標をのっける」
「左は通算記録の表がよい」。エンブレムはサムネを描く側（thumbnail の tags）が右に置くので、
ここで描くのは表だけ。**表を描き込んだ絵はサムネ専用**なので、隣に `<絵>.thumbonly` の印を置く。
draft はこの印を見て、本編・ショートの冒頭に敷かれないように止める（名前の札と表が重なるため）。

    python tools/thumbpanel.py <元の写真> <出力先.jpg> --title "ヤマルの通算（2026年9月末）" \
        --head 所属,試合,得点 --row バルセロナ,159,57 --row スペイン代表,35,10 --total 合計,194,67 \
        [--crop 0,100,1920,1180] [--x 24 --y 150 --w 440]

人に被っていないかは、出来た絵とサムネを**必ず目で見る**。
"""
from __future__ import annotations

import argparse
import shutil
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from src.config import load_config  # noqa: E402

THUMB_ONLY_MARK = ".thumbonly"


def draw_panel(src: Path, out: Path, title: str, head: list[str], rows: list[list[str]],
               total: list[str] | None = None, crop: tuple[int, int, int, int] | None = None,
               x0: int = 24, y0: int = 150, width: int = 440) -> Path:
    font = str(load_config().video.font_path())
    im = Image.open(src).convert("RGB")
    if crop:
        im = im.crop(crop)
    if im.size != (1920, 1080):
        im = im.resize((1920, 1080))
    d = ImageDraw.Draw(im, "RGBA")
    body = rows + ([total] if total else [])
    height = 66 + 58 + 94 * len(body) + 10
    d.rounded_rectangle((x0, y0, x0 + width, y0 + height), radius=24, fill=(11, 17, 26, 220))
    d.text((x0 + 20, y0 + 16), title, font=ImageFont.truetype(font, 28), fill=(230, 234, 240))
    hy = y0 + 66
    d.rectangle((x0 + 12, hy, x0 + width - 12, hy + 42), fill=(15, 77, 53))
    fh = ImageFont.truetype(font, 25)
    # 1列目は左揃え、2列目から右揃え（右端から 92px ずつ）
    rights = [x0 + width - 26 - 92 * (len(head) - 2 - i) for i in range(len(head) - 1)]
    d.text((x0 + 22, hy + 7), head[0], font=fh, fill=(255, 213, 74))
    for name, xr in zip(head[1:], rights):
        d.text((xr - d.textlength(name, font=fh), hy + 7), name, font=fh, fill=(255, 213, 74))
    fl, fv = ImageFont.truetype(font, 32), ImageFont.truetype(font, 46)
    y = hy + 58
    for row in body:
        hi = total is not None and row is total
        if hi:
            d.rounded_rectangle((x0 + 12, y - 6, x0 + width - 12, y + 76), radius=12, fill=(40, 48, 62))
        d.text((x0 + 22, y + 14), row[0], font=fl, fill=(255, 255, 255))
        for cell, xr in zip(row[1:], rights):
            d.text((xr - d.textlength(cell, font=fv), y + 2), cell, font=fv,
                   fill=(255, 213, 74) if hi else (255, 255, 255))
        y += 94
    out.parent.mkdir(parents=True, exist_ok=True)
    im.save(out, quality=94)
    (out.parent / (out.name + THUMB_ONLY_MARK)).write_text("サムネ専用（表を描き込んである）。本編・ショートの冒頭に敷かない\n",
                                                          encoding="utf-8")
    credits = src.parent / "credits.json"
    if credits.exists() and not (out.parent / "credits.json").exists():
        shutil.copy(credits, out.parent / "credits.json")
    return out


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("src"); ap.add_argument("out")
    ap.add_argument("--title", required=True)
    ap.add_argument("--head", required=True)
    ap.add_argument("--row", action="append", default=[])
    ap.add_argument("--total", default="")
    ap.add_argument("--crop", default="")
    ap.add_argument("--x", type=int, default=24); ap.add_argument("--y", type=int, default=150)
    ap.add_argument("--w", type=int, default=440)
    a = ap.parse_args(argv)
    crop = tuple(int(v) for v in a.crop.split(",")) if a.crop else None
    out = draw_panel(Path(a.src), Path(a.out), a.title, a.head.split(","), [r.split(",") for r in a.row],
                     a.total.split(",") if a.total else None, crop, a.x, a.y, a.w)
    print(out)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))

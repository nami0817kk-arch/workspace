"""取材メモ1本のサムネを、構図ごとに描いて並べる（2026-10-08）。

構図（thumbnail.layout）を選ぶ前に、同じ回で face・scene・versus・number・classic を
見比べるための道具。台本も書き出しも要らない（取材メモの thumbnail: だけで描く）。

    python tools/thumblayout.py research/20261007_messi_farewell.yaml --layout face
    python tools/thumblayout.py research/20261007_fifa_ranking.yaml --layout number --set "number=●●位"
    python tools/thumblayout.py research/20261007_record_kane.yaml --layout versus \\
        --set "photos=[assets/images/20261006_record_kane/02_2026ghana_w.jpg, assets/images/20261007_record_kane/10_shilton.jpg]" \\
        --set "names=[ケイン, シルトン]"

出来るもの（既定は output/thumb_samples/）:
  <取材メモ>_<構図>.png        作り込みあり（構図の既定）
  <取材メモ>_<構図>_plain.png  作り込みなし（fx: false）
  <取材メモ>_<構図>_list.png   上の2枚と classic を、一覧の大きさ（640・320・168px）で並べたもの

--set は取材メモの thumbnail: を上書きする（値は YAML として読む）。書いた値は取材メモには戻さない。
気に入ったら取材メモの thumbnail: に layout と項目を書き写す。
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import yaml
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from src.config import load_config  # noqa: E402
from src.thumbnail import (  # noqa: E402
    LAYOUTS, build_thumbnail, from_meta, layout_problems, notes_layout)

LIST_WIDTHS = (640, 320, 168)


def meta_of(thumb: dict, title: str = "") -> dict:
    """取材メモの thumbnail: を、台本の front matter と同じ鍵にする（research._compose_script と同じ対応）。"""
    meta = {
        "thumbnail_line1": str(thumb.get("line1") or title),
        "thumbnail_line2": str(thumb.get("line2") or ""),
        "thumbnail_tags": [str(t) for t in (thumb.get("tags") or [])],
        "thumbnail_points": [str(x) for x in (thumb.get("points") or [])][:3],
        "thumbnail_note_red": str(thumb.get("note_red") or ""),
        "thumbnail_band_full": bool(thumb.get("band_full", False)),
        "thumbnail_photos": [str(x) for x in (thumb.get("photos") or [])][:5],
        "thumbnail_crest_main": [str(x) for x in (thumb.get("crest_main") or [])][:3],
    }
    for src, dst in (("reaction", "thumbnail_reaction"), ("photo", "thumbnail_photo"),
                     ("board", "thumbnail_board"), ("focus", "thumbnail_focus"),
                     ("focus_x", "thumbnail_focus_x"), ("crest_link", "thumbnail_crest_link"),
                     ("face_link", "thumbnail_face_link")):
        if thumb.get(src) is not None and thumb.get(src) != "":
            meta[dst] = thumb[src]
    if "crests" in thumb:
        meta["thumbnail_crests"] = [str(x) for x in (thumb.get("crests") or [])]
    layout = notes_layout(thumb)
    if layout:
        meta["thumbnail_layout"] = layout
    return meta


def render(config, thumb: dict, out: Path, title: str = "") -> Path:
    look = from_meta(meta_of(thumb, title), title)
    return build_thumbnail(
        config, look["title"], out, subtitle=look["subtitle"],
        background=look["photo"] or config.video.background, focus=look.get("focus"),
        focus_x=look.get("focus_x"), lines=look["lines"], tags=look["tags"],
        reaction=look.get("reaction") or "", points=look.get("points") or [],
        note_red=look.get("note_red") or "", band_full=bool(look.get("band_full")),
        photos=look.get("photos") or [], crest_main=look.get("crest_main") or [],
        crests=look.get("crests"), crest_link=look.get("crest_link", "対"),
        face_link=look.get("face_link", ""), layout=look.get("layout"),
    )


def list_sheet(paths: list[Path], labels: list[str], out: Path, font_path: str) -> Path:
    """一覧の大きさ（640・320・168px）で横に並べる。行が1枚、列が大きさ。"""
    gap, head = 16, 34
    rows = []
    for path in paths:
        with Image.open(path) as image:
            image = image.convert("RGB")
            rows.append([image.resize((w, round(w * image.height / image.width)), Image.LANCZOS)
                         for w in LIST_WIDTHS])
    width = sum(LIST_WIDTHS) + gap * (len(LIST_WIDTHS) + 1)
    height = sum(head + row[0].height + gap for row in rows) + gap
    sheet = Image.new("RGB", (width, height), (24, 24, 24))
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.truetype(font_path, 24)
    y = gap
    for label, row in zip(labels, rows):
        draw.text((gap, y + 4), label, font=font, fill=(235, 235, 235))
        y += head
        x = gap
        for tile in row:
            sheet.paste(tile, (x, y))
            x += tile.width + gap
        y += row[0].height + gap
    out.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(out)
    return out


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("notes", help="取材メモ（research/<日付>_<名前>.yaml）")
    ap.add_argument("--layout", required=True, choices=[x for x in LAYOUTS if x != "classic"])
    ap.add_argument("--set", action="append", default=[], metavar="鍵=値",
                    help="thumbnail: の上書き（値は YAML。例 names=[ケイン, シルトン]）")
    ap.add_argument("--name", help="出来る絵の名前の頭（既定は取材メモの名前）")
    ap.add_argument("--out", default="output/thumb_samples")
    args = ap.parse_args(argv)

    raw = yaml.safe_load(Path(args.notes).read_text(encoding="utf-8")) or {}
    thumb = dict(raw.get("thumbnail") or {})
    title = str((raw.get("theme") or {}).get("title") or "")
    for item in args.set:
        key, _, value = item.partition("=")
        thumb[key.strip()] = yaml.safe_load(value)
    classic = {k: v for k, v in thumb.items() if k != "layout"}
    thumb["layout"] = args.layout
    problems = layout_problems(thumb)
    if problems:
        print("構図の指定に不備があります:", file=sys.stderr)
        for problem in problems:
            print(f"  - {problem}", file=sys.stderr)
        return 1

    config = load_config()
    out = Path(args.out)
    stem = args.name or Path(args.notes).stem
    made = [
        render(config, thumb, out / f"{stem}_{args.layout}.png", title),
        render(config, dict(thumb, fx=False), out / f"{stem}_{args.layout}_plain.png", title),
        render(config, classic, out / f"{stem}_classic.png", title),
    ]
    sheet = list_sheet(made, [f"{args.layout}（作り込みあり）", f"{args.layout}（fx: false）", "classic（今の形）"],
                       out / f"{stem}_{args.layout}_list.png", str(config.video.font_path()))
    for path in made:
        print(f"サムネ: {path}")
    print(f"一覧の大きさで並べたもの: {sheet}")
    print("Read で開いて、字が読めるか・顔が欠けていないか・左がぼやけて見えないかを見てください")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

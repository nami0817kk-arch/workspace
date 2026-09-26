"""昨季の最終順位表の板をつくる（2026-09-21）。

ユーザーが順位表アプリの画面を見本として提示した（「順位はこの画像を参考に」）。
**あの画像は使わない。**使うのは形（順位・紋章・クラブ名・試合数・得失点差・勝ち点を
1行に並べ、左に色の帯で欧州と降格を示す）だけで、**表はここで描く。**
数字は `research/pl_data/last_season.json`（英語版Wikipedia の Sports table）。

    python tools/plast.py assets/stats/pl_bournemouth_last.png --focus ボーンマス

**1枚を20クラブで使い回す。**違うのは `--focus` の1行だけなので、
どのクラブの回でも同じ表が出る。自分の順位が、他の19クラブの中のどこかとして見える。
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from src import crest  # noqa: E402
from src.config import load_config  # noqa: E402

SIZE = (1280, 720)
HEAD = 78
MARGIN = 28
WHITE = (255, 255, 255)
DIM = (176, 176, 182)
LINE = (255, 255, 255, 26)
# 左の色帯。原文の result1..20 に合わせた（CL / EL / カンファレンス / 降格）
BANDS = {"cl": (46, 168, 79), "el": (26, 63, 160), "ecl": (79, 168, 224),
         "rel": (206, 47, 47)}
sys.path.insert(0, str(Path(__file__).resolve().parent))
import clubleague  # noqa: E402

# リーグは CLUB_LEAGUE で切り替える（2026-09-26）
DATA = clubleague.data_dir() / "last_season.json"


def _rgb(code: str) -> tuple[int, int, int]:
    code = code.lstrip("#")
    return tuple(int(code[i:i + 2], 16) for i in (0, 2, 4))


def _fit(draw, text, path, size, width):
    while size > 10:
        font = ImageFont.truetype(path, size)
        if draw.textlength(text, font=font) <= width:
            return font
        size -= 1
    return ImageFont.truetype(path, size)


def build(out: Path, spec: dict, focus: str = "", data: Path | None = None) -> Path:
    font = str(load_config().video.font_path())
    table = json.loads((data or DATA).read_text(encoding="utf-8"))
    rows = table["table"]
    base, accent = (_rgb(c) for c in spec["colors"])

    board = Image.new("RGB", SIZE, base)
    d = ImageDraw.Draw(board)
    for y in range(SIZE[1]):
        t = y / SIZE[1]
        # **地を沈める。**クラブの色そのままだと彩度が高すぎて、20行の字が読めない
        d.line([(0, y), (SIZE[0], y)], fill=tuple(round(c * (0.52 - 0.24 * t)) for c in base))
    d.rectangle([0, HEAD - 6, SIZE[0], HEAD - 2], fill=accent)

    left = MARGIN
    if spec.get("crest") and Path(spec["crest"]).exists():
        head_crest = Image.open(spec["crest"]).convert("RGBA")
        head_crest.thumbnail((58, 58))
        board.paste(head_crest, (MARGIN, (HEAD - 6 - head_crest.height) // 2), head_crest)
        left += head_crest.width + 14
    title = f"{table['season']} {table['league']} 最終順位"
    d.text((left, 18), title, font=_fit(d, title, font, 40, SIZE[0] - left - MARGIN), fill=WHITE)

    # 列の位置。数字は右そろえ（桁がそろわないと表として読めない）
    x_rank, x_crest, x_name = 96, 116, 168
    x_played, x_gd, x_pts = 1004, 1124, 1248
    small = ImageFont.truetype(font, 21)

    top = HEAD + 6
    d.text((x_rank - d.textlength("#", font=small), top), "#", font=small, fill=DIM)
    d.text((x_name, top), "クラブ", font=small, fill=DIM)
    for label, x in (("試合", x_played), ("得失", x_gd), ("勝点", x_pts)):
        d.text((x - d.textlength(label, font=small), top), label, font=small, fill=DIM)
    top += 30
    d.line([(MARGIN, top - 4), (SIZE[0] - MARGIN, top - 4)], fill=(255, 255, 255), width=1)

    room = SIZE[1] - top - 8
    rh = room / len(rows)
    name_font = ImageFont.truetype(font, 23)
    num_font = ImageFont.truetype(font, 25)
    hit_name = ImageFont.truetype(font, 27)
    hit_num = ImageFont.truetype(font, 29)

    for i, row in enumerate(rows):
        y = top + i * rh
        mid = y + rh / 2
        on = focus and row["club"] == focus
        if on:
            # **白い帯に黒い字。**見本の順位表と同じで、1行だけ紙のように浮く
            d.rectangle([MARGIN, y + 1, SIZE[0] - MARGIN, y + rh - 1], fill=(250, 250, 252))
        elif i:
            d.line([(MARGIN, y), (SIZE[0] - MARGIN, y)], fill=(255, 255, 255, 20), width=1)
        band = BANDS.get(row["band"])
        if band:
            d.rectangle([MARGIN, y + 2, MARGIN + 6, y + rh - 2], fill=band)

        nf, xf = (hit_name, hit_num) if on else (name_font, num_font)
        ink = (18, 18, 22) if on else (232, 232, 236)
        figure = ink if on else (226, 226, 230)
        rank = str(row["rank"])
        d.text((x_rank - d.textlength(rank, font=xf), mid - xf.size / 2), rank,
               font=xf, fill=figure)
        mark = crest.find(row["club"])
        if mark:
            im = Image.open(mark).convert("RGBA")
            im.thumbnail((int(rh) - 2, int(rh) - 2))
            board.paste(im, (x_crest, int(mid - im.height / 2)), im)
        d.text((x_name, mid - nf.size / 2), row["club"], font=nf, fill=ink)
        cells = [(str(row["played"]), x_played), (f"{row['gd']:+d}", x_gd),
                 (str(row["points"]), x_pts)]
        for text, x in cells:
            d.text((x - d.textlength(text, font=xf), mid - xf.size / 2), text,
                   font=xf, fill=figure)

    out.parent.mkdir(parents=True, exist_ok=True)
    board.save(out)
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("out")
    ap.add_argument("--spec", required=True, help="クラブの板と同じ json")
    ap.add_argument("--focus", default="", help="明るく残すクラブ名")
    args = ap.parse_args()
    spec = json.loads(Path(args.spec).read_text(encoding="utf-8"))
    print(f"昨季の順位表: {build(Path(args.out), spec, args.focus)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

"""優勝回数の板（トロフィーを並べる）をつくる（2026-09-21）。

ユーザーがアーセナルの「トロフィーキャビネット」の画像を見本として提示した
（「優勝回数についての時は、以下の画像を参考にして」）。
**あの画像は使わない。**使うのは形（大会ごとに、獲った数だけトロフィーを並べる）だけで、
**トロフィーはここで描く。**数はクラブの取材メモから採る。

    python tools/trophies.py assets/stats/pl_bournemouth_cups.png --spec research/pl_data/bournemouth.json

spec は基礎DATAの板と同じファイル。`trophies` を読む:

    "trophies": [["プレミアリーグ", 13], ["FAカップ", 14], ["リーグカップ", 2], ...]

**0回の大会も出す。**空の棚は、それ自体が「まだ獲っていない」という中身になる。
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from src.config import load_config  # noqa: E402

SIZE = (1280, 720)
HEAD = 112
MARGIN = 30
WHITE = (255, 255, 255)
SILVER = (214, 216, 222)
SILVER_D = (150, 154, 164)
GHOST = (255, 255, 255, 46)


def _rgb(code: str) -> tuple[int, int, int]:
    code = code.lstrip("#")
    return tuple(int(code[i:i + 2], 16) for i in (0, 2, 4))


def _fit(draw, text, path, size, width):
    while size > 12:
        font = ImageFont.truetype(path, size)
        if draw.textlength(text, font=font) <= width:
            return font
        size -= 2
    return ImageFont.truetype(path, size)


def cup(w: int, h: int, fill, edge) -> Image.Image:
    """トロフィーを1つ描く。左右の取っ手・鉢・脚・台座だけの簡単な形。"""
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    bowl_w, bowl_h = int(w * 0.56), int(h * 0.46)
    x0 = (w - bowl_w) // 2
    y0 = int(h * 0.10)
    # 取っ手
    ear = int(w * 0.20)
    d.ellipse([x0 - ear, y0 + 2, x0 + ear // 2, y0 + bowl_h - 2], outline=edge, width=max(2, w // 22))
    d.ellipse([x0 + bowl_w - ear // 2, y0 + 2, x0 + bowl_w + ear, y0 + bowl_h - 2],
              outline=edge, width=max(2, w // 22))
    # 鉢（下がすぼまる）
    d.polygon([(x0, y0), (x0 + bowl_w, y0),
               (x0 + bowl_w - bowl_w // 5, y0 + bowl_h), (x0 + bowl_w // 5, y0 + bowl_h)], fill=fill)
    d.rectangle([x0 - 2, y0 - int(h * 0.04), x0 + bowl_w + 2, y0 + int(h * 0.03)], fill=fill)
    # 脚と台座
    stem_w = max(3, w // 9)
    d.rectangle([(w - stem_w) // 2, y0 + bowl_h, (w + stem_w) // 2, int(h * 0.78)], fill=fill)
    d.rectangle([int(w * 0.20), int(h * 0.78), int(w * 0.80), int(h * 0.88)], fill=fill)
    d.rectangle([int(w * 0.13), int(h * 0.88), int(w * 0.87), int(h * 0.97)], fill=edge)
    return im


def build(out: Path, spec: dict) -> Path:
    font = str(load_config().video.font_path())
    base, accent = (_rgb(c) for c in spec["colors"])
    board = Image.new("RGB", SIZE, base)
    d = ImageDraw.Draw(board)
    for y in range(SIZE[1]):
        t = y / SIZE[1]
        d.line([(0, y), (SIZE[0], y)], fill=tuple(round(c * (1 - 0.40 * t)) for c in base))
    d.rectangle([0, HEAD - 8, SIZE[0], HEAD - 2], fill=accent)

    crest_w = 0
    crest = None
    if spec.get("crest") and Path(spec["crest"]).exists():
        crest = Image.open(spec["crest"]).convert("RGBA")
        head_crest = crest.copy()
        head_crest.thumbnail((88, 88))
        board.paste(head_crest, (MARGIN, (HEAD - 8 - head_crest.height) // 2), head_crest)
        crest_w = head_crest.width + 18
    title = spec["title"].replace(" 基礎DATA", "") + " が獲ったもの"
    d.text((MARGIN + crest_w, 22), title,
           font=_fit(d, title, font, 54, SIZE[0] - 2 * MARGIN - crest_w), fill=WHITE)

    rows = [(name, int(n)) for name, n in spec.get("trophies", [])]
    if not rows:
        raise SystemExit("■ spec に trophies がありません")
    top = HEAD + 14
    room = SIZE[1] - top - 16
    rh = room // len(rows)
    label_font = ImageFont.truetype(font, min(30, max(18, rh // 3)))
    # **名前の欄は、いちばん長い名前に合わせる**（2026-09-22）。ヨーロッパを大会ごとにしたら
    # 「カップウィナーズカップ」「インタートトカップ」が杯の絵に重なった
    widest = max(d.textlength(name, font=label_font) for name, _ in rows)
    left = MARGIN + max(300, int(widest) + 28)
    for i, (name, n) in enumerate(rows):
        y = top + i * rh
        d.text((MARGIN, y + rh // 2 - label_font.size // 2), name, font=label_font, fill=WHITE)
        # **右に回数を書く場所を残す。**残さないとアーセナルの「14回」が切れた
        width = SIZE[0] - MARGIN - left - 130
        ch = min(rh - 10, 96)
        cw = int(ch * 0.62)
        gap = 4
        if n > 0:
            per = max(1, min(n, width // (cw + gap)))
            if n > per:                       # 入りきらないときは小さくする
                cw = max(16, width // n - gap)
                ch = min(rh - 10, int(cw / 0.62))
            for k in range(n):
                x = left + k * (cw + gap)
                if x + cw > SIZE[0] - MARGIN:
                    break
                board.paste(cup(cw, ch, SILVER, SILVER_D), (x, y + (rh - ch) // 2),
                            cup(cw, ch, SILVER, SILVER_D))
            end = min(left + n * (cw + gap), left + width)
            d.text((end + 14, y + rh // 2 - label_font.size // 2), f"{n}回",
                   font=label_font, fill=WHITE)
        else:
            ghost = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
            ghost.paste(cup(cw, ch, (255, 255, 255, 40), (255, 255, 255, 70)), (0, 0))
            board.paste(ghost, (left, y + (rh - ch) // 2), ghost)
            d.text((left + cw + 14, y + rh // 2 - label_font.size // 2), "まだ無し",
                   font=label_font, fill=(230, 226, 226))
    out.parent.mkdir(parents=True, exist_ok=True)
    board.save(out)
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("out")
    ap.add_argument("--spec", required=True)
    args = ap.parse_args()
    spec = json.loads(Path(args.spec).read_text(encoding="utf-8"))
    print(f"優勝回数の板: {build(Path(args.out), spec)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

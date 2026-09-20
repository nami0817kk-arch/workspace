"""クラブの「基礎DATA」板をつくる（2026-09-19）。

ユーザーが**サッカーキングのクラブ紹介動画**を参考として提示した
（「鈴木彩艶が所属するアストン・ヴィラってどんなクラブ？」）。
創立・本拠地・オーナー・タイトル歴・記録・愛称を、
**クラブの色の板1枚**にまとめて見せていた。

**あの板そのものは使わない。**使うのは形（1枚に要点を並べる）だけで、
中身はこちらで調べて埋める。数字は取材メモに出典ごと置く。

    python tools/clubdata.py assets/stats/pl_villa_data.png --spec data.json

spec の形:

    {"title": "アストン・ヴィラ 基礎DATA",
     "colors": ["#670E36", "#95BFE5"],     # 地の色, 差し色
     "crest": "assets/crests/アストンヴィラ.png",
     "tiles": [["クラブ創立", "1874年", "4人の青年が立ち上げた"], ...]}   # 見出し, 大きな字, 小さな字

タイルは9枚まで（3列×3段）。**大きな字は短く**（10字前後）。長い説明は小さな字へ。
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
HEAD = 118                 # 上の帯の高さ
GAP = 14
MARGIN = 28
WHITE = (255, 255, 255)
INK = (28, 22, 30)
SUB = (92, 84, 96)


def _rgb(code: str) -> tuple[int, int, int]:
    code = code.lstrip("#")
    return tuple(int(code[i:i + 2], 16) for i in (0, 2, 4))


def _fit(draw: ImageDraw.ImageDraw, text: str, path: str, size: int, width: int) -> ImageFont.FreeTypeFont:
    """幅に収まるまで字を縮める。"""
    while size > 14:
        font = ImageFont.truetype(path, size)
        if draw.textlength(text, font=font) <= width:
            return font
        size -= 2
    return ImageFont.truetype(path, size)


def build(out: Path, spec: dict, focus: int | None = None) -> Path:
    """`focus` を渡すと、その番号（0始まり）のタイル以外を暗く落とす。

    **板を1枚のまま48秒出すと、画面が止まる**（2026-09-20）。読み上げは
    9枚のタイルを順に説明しているのに、絵は1枚も変わっていなかった。
    いま話しているタイルだけを明るく残せば、**読み上げと画面が一致したまま
    1行ごとに絵が変わる**（テロップを重ねずに済む）。
    """
    font = str(load_config().video.font_path())
    base, accent = (_rgb(c) for c in spec["colors"])
    board = Image.new("RGB", SIZE, base)
    draw = ImageDraw.Draw(board)

    # 地は、地の色から少し暗くしたグラデーション
    for y in range(SIZE[1]):
        t = y / SIZE[1]
        draw.line([(0, y), (SIZE[0], y)], fill=tuple(round(c * (1 - 0.35 * t)) for c in base))
    draw.rectangle([0, HEAD - 8, SIZE[0], HEAD - 2], fill=accent)

    crest_w = 0
    if spec.get("crest") and Path(spec["crest"]).exists():
        crest = Image.open(spec["crest"]).convert("RGBA")
        crest.thumbnail((96, 96))
        board.paste(crest, (MARGIN, (HEAD - 8 - crest.height) // 2), crest)
        crest_w = crest.width + 20
    title = spec["title"]
    draw.text((MARGIN + crest_w, 22), title,
              font=_fit(draw, title, font, 60, SIZE[0] - 2 * MARGIN - crest_w), fill=WHITE)

    tiles = spec["tiles"][:9]
    cols = 3
    rows = -(-len(tiles) // cols)
    w = (SIZE[0] - 2 * MARGIN - (cols - 1) * GAP) // cols
    h = (SIZE[1] - HEAD - MARGIN - (rows - 1) * GAP) // rows
    for i, (label, big, small) in enumerate(tiles):
        c, r = i % cols, i // cols
        x = MARGIN + c * (w + GAP)
        y = HEAD + 8 + r * (h + GAP)
        draw.rounded_rectangle([x, y, x + w, y + h], radius=10, fill=WHITE)
        draw.rounded_rectangle([x, y, x + w, y + 40], radius=10, fill=accent)
        draw.rectangle([x, y + 30, x + w, y + 40], fill=accent)
        draw.text((x + 14, y + 6), label, font=ImageFont.truetype(font, 24), fill=INK)
        draw.text((x + 14, y + 50), big, font=_fit(draw, big, font, 44, w - 28), fill=base)
        if small:
            draw.text((x + 14, y + h - 40), small, font=_fit(draw, small, font, 22, w - 28), fill=SUB)

        if focus is not None and i != focus:
            shade = Image.new("RGB", (w + 1, h + 1), tuple(round(c * 0.45) for c in base))
            board.paste(Image.blend(board.crop((x, y, x + w + 1, y + h + 1)), shade, 0.72), (x, y))

    out.parent.mkdir(parents=True, exist_ok=True)
    board.save(out)
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("out")
    ap.add_argument("--spec", required=True, help="板の中身（JSON）")
    ap.add_argument("--focus", type=int, help="このタイルだけを明るく残す（0始まり）")
    args = ap.parse_args()
    spec = json.loads(Path(args.spec).read_text(encoding="utf-8"))
    if len(spec.get("tiles", [])) > 9:
        print("■ タイルは9枚まで（それ以上は字が読めない）", file=sys.stderr)
        return 1
    print(f"基礎DATA板: {build(Path(args.out), spec, args.focus)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

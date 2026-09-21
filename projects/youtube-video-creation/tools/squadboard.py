"""代表メンバーの一覧板をつくる（2026-09-17）。

ユーザーが**サッカーキングのInstagramの一覧画像**を参考として提示した。
青い地に、名前を白の太字、その下にクラブ名を小さく、初招集には印。

**あの画像そのものは使わない。**制作物の権利はあちらにある。
使うのは**情報のほう**（誰が選ばれたか）で、組み方はこちらで決める。

**31人は並べない。**サムネイルは一覧の中で小さく出るので、31人だと
どの名前も読めない。**その回で話している数人だけ**を並べる。

下の4割は蛍光イエローの帯に隠れるので、描くのは `FLOOR` まで。

    python tools/squadboard.py assets/stats/daihyo_new.png \
        --title "日本代表 初招集" --note "2026年9月17日発表" \
        --row "齋藤俊輔|ウェステルロー／ベルギー・21歳|new" \
        --row "松木玖生|サウサンプトン／イングランド・23歳|new"
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from src.config import load_config  # noqa: E402

SIZE = (1280, 720)
FLOOR = 430                      # ここから下は帯に隠れる
TOP = (10, 26, 74)               # 濃い紺
BOTTOM = (26, 76, 170)           # 明るい青
STRIPE = (255, 255, 255, 14)     # 斜めの薄い筋
BAR = (8, 18, 52)
NAME = (255, 255, 255)
CLUB = (168, 200, 245)
MARK = (222, 255, 0)             # 帯と同じ蛍光イエロー


def _ground(top=TOP, bottom=BOTTOM) -> Image.Image:
    board = Image.new("RGB", SIZE, top)
    draw = ImageDraw.Draw(board)
    for y in range(SIZE[1]):
        t = y / SIZE[1]
        draw.line([(0, y), (SIZE[0], y)],
                  fill=tuple(round(a + (b - a) * t) for a, b in zip(top, bottom)))
    layer = Image.new("RGBA", SIZE, (0, 0, 0, 0))
    pen = ImageDraw.Draw(layer)
    for x in range(-SIZE[1], SIZE[0], 78):
        pen.polygon([(x, SIZE[1]), (x + 34, SIZE[1]), (x + 34 + SIZE[1], 0), (x + SIZE[1], 0)],
                    fill=STRIPE)
    return Image.alpha_composite(board.convert("RGBA"), layer).convert("RGB")


def _fit(draw, text: str, path: str, size: int, width: float) -> ImageFont.FreeTypeFont:
    """幅に収まるまで字を縮める。長い名前（ジモ＝アロバ等）が隣の列へはみ出した。"""
    while size > 16 and draw.textlength(text, font=ImageFont.truetype(path, size)) > width:
        size -= 2
    return ImageFont.truetype(path, size)


def _hex(code: str) -> tuple[int, int, int]:
    code = code.strip().lstrip("#")
    return tuple(int(code[i:i + 2], 16) for i in (0, 2, 4))


def build(out: Path, title: str, note: str, rows: list[tuple[str, str, bool]],
          floor: int = FLOOR, colors: tuple | None = None,
          focus: list[str] | None = None) -> Path:
    """`floor` は描いてよい下端。**動画で出す板は帯に隠れないので SIZE[1] まで使う**
    （2026-09-19。サムネ用の 430 のままだと下の4割が空いた）。
    `colors` はクラブの色（地の上・地の下）。"""
    font_path = str(load_config().video.font_path())
    board = _ground(*colors) if colors else _ground()
    draw = ImageDraw.Draw(board)

    draw.rectangle([0, 0, SIZE[0], 104], fill=BAR)
    draw.rectangle([0, 104, SIZE[0], 110], fill=MARK)
    small = ImageFont.truetype(font_path, 26)
    note_w = draw.textlength(note, font=small) + 40 if note else 0
    # 見出しと注記が重なった（2026-09-19）。注記のぶんを空けて見出しを縮める
    draw.text((40, 30), title, font=_fit(draw, title, font_path, 58, SIZE[0] - 80 - note_w), fill=NAME)
    if note:
        draw.text((SIZE[0] - 40 - draw.textlength(note, font=small), 58), note,
                  font=small, fill=CLUB)

    # **帯に隠れない高さは 320px しかない。**1列に4人並べると、名前と
    # クラブ名が重なった（2026-09-17 に書き出して発見）。段の高さを先に出し、
    # そこから字の大きさを決める。3人以上は2列にする
    columns = 1 if len(rows) <= 2 else 2
    per = -(-len(rows) // columns)
    band = (floor - 132) // max(1, per)
    name_size = max(30, min(60, round(band * 0.42)))
    club_size = max(18, min(30, round(band * 0.20)))
    name_font = ImageFont.truetype(font_path, name_size)
    club_font = ImageFont.truetype(font_path, club_size)

    # **いま話している選手の行だけ明るくする**（2026-09-21 ユーザー選択）。
    # 10人ぶんの名前を出したまま「アダム・スミスは」と読んでも、
    # 見ている人はどれがその人か探せない。**基礎DATAの板と同じ仕掛け**
    lit = set(focus or [])
    if lit:
        layer = Image.new("RGBA", SIZE, (0, 0, 0, 0))
        pen = ImageDraw.Draw(layer)
        for index, (name, _club, _new) in enumerate(rows):
            if name not in lit:
                continue
            col, row = divmod(index, per)
            x = 46 + col * (SIZE[0] - 92) // columns
            y = 132 + row * band
            wide = (SIZE[0] - 92) // columns - 30
            pen.rectangle([x - 16, y - 10, x + wide, y + band - 16], fill=(255, 255, 255, 38))
            pen.rectangle([x - 16, y - 10, x - 10, y + band - 16], fill=MARK + (255,))
        board = Image.alpha_composite(board.convert("RGBA"), layer).convert("RGB")
        draw = ImageDraw.Draw(board)

    for index, (name, club, is_new) in enumerate(rows):
        col, row = divmod(index, per)
        x = 46 + col * (SIZE[0] - 92) // columns
        y = 132 + row * band
        cell = (SIZE[0] - 92) // columns - 60
        on = not lit or name in lit
        font = _fit(draw, name, font_path, name_size, cell)
        draw.text((x, y), name, font=font, fill=NAME if on else (172, 166, 168))
        width = draw.textlength(name, font=font)
        if is_new:
            draw.text((x + width + 16, y + name_size * 0.18), "★",
                      font=ImageFont.truetype(font_path, round(name_size * 0.62)), fill=MARK)
        if club:
            draw.text((x + 4, y + name_size + 4), club, font=club_font,
                      fill=CLUB if on else (132, 126, 128))

    out.parent.mkdir(parents=True, exist_ok=True)
    board.save(out)
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("out")
    ap.add_argument("--title", required=True)
    ap.add_argument("--note", default="")
    ap.add_argument("--full", action="store_true",
                    help="動画で出す板。帯に隠れないので下まで使う")
    ap.add_argument("--colors", default="",
                    help="地の色を2つ（例 #670E36,#2A0616）。クラブの色にするとき")
    ap.add_argument("--focus", action="append", default=[],
                    help="明るく残す名前。指定した行以外は沈める（何度でも指定できる）")
    ap.add_argument("--row", action="append", default=[],
                    help="名前|所属など|new（new を付けると印が出る）")
    args = ap.parse_args()
    rows = []
    for raw in args.row:
        parts = (raw.split("|") + ["", ""])[:3]
        rows.append((parts[0].strip(), parts[1].strip(), parts[2].strip() == "new"))
    if not rows:
        print("--row が1つもありません", file=sys.stderr)
        return 1
    if len(rows) > (12 if args.full else 8):
        print("■ 8人を超えると、一覧では読めません", file=sys.stderr)
        return 1
    colors = tuple(_hex(c) for c in args.colors.split(",")) if args.colors else None
    where = build(Path(args.out), args.title, args.note, rows,
                  floor=SIZE[1] - 30 if args.full else FLOOR, colors=colors,
                  focus=args.focus)
    missing = [n for n in args.focus if n not in [r[0] for r in rows]]
    if missing:
        # **黙って全部沈む。**名前が1つも当たらないと、板は読めるが誰も光らない
        print(f"■ --focus の名前が板にありません: {'、'.join(missing)}", file=sys.stderr)
    print(f"一覧板: {where}  （{len(rows)}人）")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

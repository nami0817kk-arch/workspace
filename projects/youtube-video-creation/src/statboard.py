"""数字の図を1枚の画像にする。**試合映像の代わりに使う下地。**

参考チャンネルの最高再生（64万回）は、動画の中身が試合映像ではなく
**走行距離のスタッツ画面**だった（2026-09-07 に文字起こしと画面で確認）。
選手のアイコンと 12.3km・10.3km が並んだ図で、あれは映像ではなく数字の絵。

放送映像は使えない（2026-09-05 の方針）。**数字の図なら自分で作れて、
権利の問題がまったく無く、一覧では「試合の画面」に見える。**

    python -m src.cli statboard out.png --title 走行距離 --unit km \\
        --row ヴィルツ=12.3 --row ソボスライ=11.6 --row マカリスター=10.4

できた PNG は台本の `thumbnail_photo:` にも `bg:` にも指定できる。
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw

from . import cards
from .config import ProjectConfig, _resolve
from .render import _cover
from .thumbnail import SIZE

# 図を置く幅。左右に余白を残して、下地の芝が見えるようにする
CARD_WIDTH = 1080


class StatboardError(Exception):
    pass


def build(
    rows: list[tuple[str, float]],
    out_path: Path,
    config: ProjectConfig,
    title: str = "",
    unit: str = "",
    background: str = "",
    note: str = "",
) -> Path:
    """数字を横棒の図にして、芝の下地に重ねた1枚を書き出す。"""
    if not rows:
        raise StatboardError("数字がありません。--row 名前=値 を1つ以上ください")

    out_path = Path(out_path)
    canvas = _base(background)

    spec = {
        "type": "bars",
        "title": title,
        "unit": unit,
        "items": [{"label": label, "value": value} for label, value in rows],
    }
    if note:
        spec["source"] = note

    work = out_path.parent / f"{out_path.stem}_card.png"
    work.parent.mkdir(parents=True, exist_ok=True)
    card = cards.render(spec, CARD_WIDTH, str(config.video.font_path()), work,
                        latin_font_path=str(config.video.latin_font_path()))
    with Image.open(card) as image:
        plate = image.convert("RGBA")
    # 図が縦に伸びたら、はみ出さないところまで縮める。
    # **下の半分はサムネの帯と反応の小窓が乗る**ので、そこは使わない
    # （2026-09-07、実際にサムネを作って最後の行が隠れているのを見つけた）
    room = int(SIZE[1] * 0.50) - 24
    if plate.height > room:
        scale = room / plate.height
        plate = plate.resize((int(plate.width * scale), room), Image.LANCZOS)

    top = max(20, (int(SIZE[1] * 0.50) - plate.height) // 2)
    canvas.alpha_composite(plate, ((SIZE[0] - plate.width) // 2, top))
    canvas.convert("RGB").save(out_path, quality=95)
    work.unlink(missing_ok=True)

    # **これは自分で作った図だという印。**顔写真ではないので、review の
    # 「サムネの顔」がこの印を見て通す。数字の出どころもここに残す
    lines = [f"title: {title}", f"unit: {unit}"]
    lines += [f"{label}={value}" for label, value in rows]
    if note:
        lines.append(f"source: {note}")
    _mark(out_path).write_text(chr(10).join(lines), encoding="utf-8")
    return out_path


def _mark(out_path: Path) -> Path:
    return out_path.with_suffix(out_path.suffix + ".statboard.txt")


def is_statboard(path: Path) -> bool:
    """自分で作った数字の図か。"""
    return _mark(Path(path)).exists()


def _base(background: str) -> Image.Image:
    """下地。**既定は自分で描いた明るい芝。**

    手持ちの `pitch.png` は夜のスタジアムで暗く、一覧に並んだとき何の絵か
    分からなかった（2026-09-07 に書き出して確認）。放送の図は明るい。
    """
    if background:
        source = _resolve(background)
        if source.exists() and source.suffix.lower() in (".png", ".jpg", ".jpeg"):
            with Image.open(source) as image:
                canvas = _cover(image.convert("RGBA"), *SIZE)
            canvas.alpha_composite(Image.new("RGBA", SIZE, (6, 14, 10, 110)))
            return canvas
    return _pitch_image()


def _pitch_image() -> Image.Image:
    canvas = Image.new("RGBA", SIZE, (26, 104, 56, 255))
    draw = ImageDraw.Draw(canvas)
    stripe = SIZE[0] // 14
    for index in range(0, SIZE[0], stripe * 2):
        draw.rectangle([index, 0, index + stripe, SIZE[1]], fill=(31, 118, 64, 255))
    line = (240, 248, 244, 210)
    draw.rectangle([16, 16, SIZE[0] - 16, SIZE[1] - 16], outline=line, width=5)
    draw.line([(SIZE[0] // 2, 16), (SIZE[0] // 2, SIZE[1] - 16)], fill=line, width=5)
    draw.ellipse([SIZE[0] // 2 - 110, SIZE[1] // 2 - 110,
                  SIZE[0] // 2 + 110, SIZE[1] // 2 + 110], outline=line, width=5)
    return canvas


def parse_rows(values: list[str]) -> list[tuple[str, float]]:
    """`名前=12.3` の並びを読む。**読めない値は落とさずに止める。**

    黙って捨てると、図に出ていない選手がいることに気づけない。
    """
    rows: list[tuple[str, float]] = []
    for item in values:
        label, sep, number = str(item).partition("=")
        if not sep or not label.strip():
            raise StatboardError(f"名前=値 の形で書いてください: {item}")
        try:
            rows.append((label.strip(), float(number.strip())))
        except ValueError as error:
            raise StatboardError(f"数字として読めません: {item}") from error
    return rows


def draw_pitch(out_path: Path, size: tuple[int, int] = SIZE) -> Path:
    """芝の絵が無いときの下地を作る。**用意できないなら自分で描く。**"""
    canvas = Image.new("RGB", size, (18, 78, 42))
    draw = ImageDraw.Draw(canvas)
    stripe = size[0] // 12
    for index in range(0, size[0], stripe * 2):
        draw.rectangle([index, 0, index + stripe, size[1]], fill=(22, 88, 48))
    draw.rectangle([12, 12, size[0] - 12, size[1] - 12], outline=(235, 245, 240), width=4)
    draw.line([(size[0] // 2, 12), (size[0] // 2, size[1] - 12)],
              fill=(235, 245, 240), width=4)
    draw.ellipse([size[0] // 2 - 90, size[1] // 2 - 90,
                  size[0] // 2 + 90, size[1] // 2 + 90],
                 outline=(235, 245, 240), width=4)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(out_path)
    return out_path

"""フォントの選定と、文字を枠に収めるための計算。

日本語が「□□□」に化けるのは、Pillow の既定フォントに日本語が入っていないため。
使えるフォントを探す処理と、折り返し・自動縮小をここにまとめて、
画像を作るところ（プレースホルダ生成・サムネイル合成）から共通で使う。
"""

from __future__ import annotations

from pathlib import Path

#: よくある CJK フォントを順に探す。見つかった最初のものを使う
FONT_CANDIDATES = [
    "C:/Windows/Fonts/meiryo.ttc",
    "C:/Windows/Fonts/YuGothM.ttc",
    "C:/Windows/Fonts/YuGothB.ttc",
    "C:/Windows/Fonts/msgothic.ttc",
    "/System/Library/Fonts/ヒラギノ角ゴシック W4.ttc",
    "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc",
    "/usr/share/fonts/truetype/fonts-japanese-gothic.ttf",
    "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
]


def pick_font(size: int, path: str | Path = ""):
    """使えるフォントを1つ返す（指定 > 候補 > Pillow 標準）。"""
    from PIL import ImageFont

    candidates = [str(path)] if path else []
    candidates += FONT_CANDIDATES
    for candidate in candidates:
        if candidate and Path(candidate).is_file():
            try:
                return ImageFont.truetype(candidate, size)
            except OSError:
                continue
    try:
        return ImageFont.load_default(size=size)
    except TypeError:  # pragma: no cover - Pillow < 10.1
        return ImageFont.load_default()


def measure(text: str, font, draw=None) -> tuple[int, int]:
    """1行の描画サイズ（幅, 高さ）。"""
    from PIL import Image, ImageDraw

    if draw is None:
        draw = ImageDraw.Draw(Image.new("RGB", (1, 1)))
    left, top, right, bottom = draw.textbbox((0, 0), text or " ", font=font)
    return right - left, bottom - top


def wrap_text(text: str, font, max_width: int, draw=None) -> list[str]:
    """描画幅に収まるように折り返す。

    日本語は単語の区切りが無いので1文字ずつ詰めていく。
    元の改行は残す（書いた人が意図した改行を勝手に消さない）。
    """
    from PIL import Image, ImageDraw

    if draw is None:
        draw = ImageDraw.Draw(Image.new("RGB", (1, 1)))

    lines: list[str] = []
    for paragraph in (text or "").split("\n"):
        current = ""
        for char in paragraph:
            trial = current + char
            if draw.textlength(trial, font=font) > max_width and current:
                lines.append(current)
                current = char
            else:
                current = trial
        lines.append(current)
    return lines


def fit(
    text: str,
    *,
    max_width: int,
    max_height: int,
    start_size: int,
    min_size: int = 12,
    max_lines: int = 3,
    line_spacing: float = 1.25,
    path: str | Path = "",
):
    """枠に収まる最大の文字サイズを探す。

    大きい方から縮めていくのは、**見出しはできるだけ大きいほうがよい**ため。
    行数と高さの両方で判定する（横に収まっても行が増えれば縦に溢れるので）。
    戻り値は (フォント, 行, 1行の高さ)。
    """
    size = max(min_size, int(start_size))
    while True:
        font = pick_font(size, path)
        lines = wrap_text(text, font, max_width)
        line_height = int(measure("あＭ", font)[1] * line_spacing)
        if size <= min_size:
            return font, lines[:max_lines], line_height
        if len(lines) <= max_lines and line_height * len(lines) <= max_height:
            return font, lines, line_height
        size = max(min_size, int(size * 0.92))

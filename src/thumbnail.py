"""サムネイル(1280x720)の生成。

一覧で見たときに何の動画か一瞬で分かることを優先する。写真素材が無くても
成立するよう、文字の大きさとコントラストで見せる構成にしている。
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

from . import ffmpeg
from .config import ProjectConfig, _resolve
from .ffmpeg import is_video
from .render import _cover, _hex, _layer, wrap_text

SIZE = (1280, 720)
MARGIN = 64
BADGE_HEIGHT = 62
SUBTITLE_HEIGHT = 70
DATE_HEIGHT = 40
TITLE_GAP = 18
TITLE_SIZES = (116, 104, 94, 84, 76, 68, 60)


def build_thumbnail(
    config: ProjectConfig,
    title: str,
    out_path: Path,
    subtitle: str = "",
    background: str | None = None,
    badge: str = "",
    date: str = "",
) -> Path:
    font_path = str(config.video.font_path())
    accent = _hex(config.video.accent)

    canvas = _base(config, background, out_path)
    _scrim(canvas, accent)

    layer, draw = _layer(SIZE)

    # 先に上下の固定要素の高さを確保し、残りをタイトルに割り当てる
    badge_height = (BADGE_HEIGHT + 26) if badge else 0
    subtitle_height = (SUBTITLE_HEIGHT + 18) if subtitle else 0
    date_height = (DATE_HEIGHT + 10) if date else 0
    available = SIZE[1] - MARGIN * 2 - badge_height - subtitle_height - date_height

    font, lines = _fit_title(draw, title, font_path, available)
    block = (font.size + TITLE_GAP) * len(lines)

    y = MARGIN + 8
    if badge:
        y = _draw_badge(draw, badge, y, accent, font_path)
    # タイトルは確保した領域の中で上寄せにする
    for chunk in lines:
        draw.text(
            (MARGIN, y), chunk, font=font, fill=(255, 255, 255, 255),
            stroke_width=max(6, font.size // 9), stroke_fill=(8, 10, 16, 255),
        )
        y += font.size + TITLE_GAP

    bottom = SIZE[1] - MARGIN
    if date:
        _draw_date(draw, date, font_path, bottom - DATE_HEIGHT)
        bottom -= date_height
    if subtitle:
        _draw_subtitle(draw, subtitle, bottom - SUBTITLE_HEIGHT, font_path, accent)

    canvas.alpha_composite(layer)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    canvas.convert("RGB").save(out_path, quality=95)
    return out_path


# ------------------------------------------------------------------ パーツ


def _base(config: ProjectConfig, background: str | None, out_path: Path) -> Image.Image:
    source = _resolve(background or config.video.background)
    if source.exists() and is_video(source.name):
        # 背景が動画なら1フレーム抜いて下地にする
        still = out_path.parent / "thumbnail_bg.png"
        still.parent.mkdir(parents=True, exist_ok=True)
        source = ffmpeg.grab_frame(source, still)
    if source.exists():
        return _cover(Image.open(source).convert("RGBA"), *SIZE)
    return Image.new("RGBA", SIZE, (14, 20, 32, 255))


def _scrim(canvas: Image.Image, accent: tuple[int, int, int]) -> None:
    """左を濃く、右をうっすら。文字を置く側だけ確実に沈める。"""
    scrim, draw = _layer(SIZE)
    for x in range(SIZE[0]):
        ratio = x / SIZE[0]
        alpha = int(232 - 150 * min(1.0, ratio * 1.35))
        draw.line([(x, 0), (x, SIZE[1])], fill=(6, 10, 18, alpha))
    canvas.alpha_composite(scrim)

    # 右下から差し込むアクセントの帯
    band, band_draw = _layer(SIZE)
    band_draw.polygon(
        [(SIZE[0] - 210, SIZE[1]), (SIZE[0], SIZE[1] - 260), (SIZE[0], SIZE[1])],
        fill=accent + (52,),
    )
    canvas.alpha_composite(band)


def _draw_badge(
    draw: ImageDraw.ImageDraw, badge: str, y: int, accent, font_path: str
) -> int:
    font = ImageFont.truetype(font_path, 40)
    width = draw.textlength(badge, font=font)
    draw.rounded_rectangle(
        [MARGIN, y, MARGIN + width + 52, y + 62], radius=10, fill=accent + (255,)
    )
    draw.text((MARGIN + 26, y + 8), badge, font=font, fill=(10, 14, 22, 255))
    return y + 62 + 26


def _fit_title(
    draw: ImageDraw.ImageDraw, title: str, font_path: str, available: int
) -> tuple[ImageFont.FreeTypeFont, list[str]]:
    """入る中でいちばん大きい字を選ぶ。

    3行以内かつ確保した高さに収まること。最後の行が1〜2文字だけになる
    （泣き別れ）ときは、1段階小さくして行の頭を揃える。
    """
    text = title.replace("\\n", "\n")
    width = SIZE[0] - MARGIN * 2 - 150

    fallback = None
    for size in TITLE_SIZES:
        font = ImageFont.truetype(font_path, size)
        lines = wrap_text(draw, text, font, width)
        if len(lines) > 3 or (font.size + TITLE_GAP) * len(lines) > available:
            continue
        if fallback is None:
            fallback = (font, lines)
        if len(lines) == 1 or len(lines[-1]) > 2:
            return font, lines
    if fallback:
        return fallback
    font = ImageFont.truetype(font_path, TITLE_SIZES[-1])
    return font, wrap_text(draw, text, font, width)[:3]


def _draw_subtitle(
    draw: ImageDraw.ImageDraw, subtitle: str, y: int, font_path: str, accent
) -> None:
    font = ImageFont.truetype(font_path, 44)
    width = draw.textlength(subtitle, font=font)
    draw.rounded_rectangle(
        [MARGIN, y, MARGIN + width + 56, y + SUBTITLE_HEIGHT], radius=12, fill=accent + (255,)
    )
    draw.text((MARGIN + 28, y + 10), subtitle, font=font, fill=(12, 16, 24, 255))


def _draw_date(draw: ImageDraw.ImageDraw, date: str, font_path: str, y: int) -> None:
    font = ImageFont.truetype(font_path, 32)
    draw.text(
        (MARGIN, y), date, font=font, fill=(214, 222, 234, 255),
        stroke_width=4, stroke_fill=(0, 0, 0, 210),
    )

"""サムネイル(1280x720 PNG)の生成。"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

from .config import ProjectConfig, _resolve
from . import ffmpeg
from .ffmpeg import is_video
from .render import wrap_text, _cover, _hex, _layer

SIZE = (1280, 720)


def build_thumbnail(
    config: ProjectConfig,
    title: str,
    out_path: Path,
    subtitle: str = "",
    background: str | None = None,
) -> Path:
    font_path = str(config.video.font_path())
    font_title = ImageFont.truetype(font_path, 96)
    font_sub = ImageFont.truetype(font_path, 44)

    source = _resolve(background or config.video.background)
    if source.exists() and is_video(source.name):
        # 動画背景のときは、そこから1枚抜いてサムネの下地にする
        still = out_path.parent / "thumbnail_bg.png"
        still.parent.mkdir(parents=True, exist_ok=True)
        source = ffmpeg.grab_frame(source, still)
    if source.exists():
        canvas = _cover(Image.open(source).convert("RGBA"), *SIZE)
    else:
        canvas = Image.new("RGBA", SIZE, (18, 24, 38, 255))

    # 文字を読みやすくする暗幕。立ち絵より先に敷く
    scrim, scrim_draw = _layer(SIZE)
    scrim_draw.rectangle([0, 0, SIZE[0], SIZE[1]], fill=(0, 0, 0, 90))
    canvas.alpha_composite(scrim)

    # 立ち絵を右下に大きく置いて“顔”を作る
    speakers = [m for m in config.cast.values() if m.position in ("left", "right")]
    for offset, member in enumerate(speakers[:2]):
        sprite_path = member.sprite_dir() / "smile_close.png"
        if not sprite_path.exists():
            continue
        sprite = Image.open(sprite_path).convert("RGBA")
        scale = (SIZE[1] * 0.62) / sprite.height
        sprite = sprite.resize((int(sprite.width * scale), int(sprite.height * scale)), Image.LANCZOS)
        x = SIZE[0] - sprite.width * (offset + 1) + offset * 40
        canvas.alpha_composite(sprite, (max(0, x), SIZE[1] - sprite.height))

    layer, draw = _layer(SIZE)

    # frontmatter に書いた \n を改行として扱う
    lines = wrap_text(draw, title.replace("\\n", "\n"), font_title, SIZE[0] - 120)[:3]
    y = 90 if not subtitle else 60
    for chunk in lines:
        draw.text(
            (60, y), chunk, font=font_title, fill=(255, 255, 255, 255),
            stroke_width=10, stroke_fill=(10, 10, 16, 255),
        )
        y += 118

    if subtitle:
        accent = _hex(speakers[0].color) if speakers else (255, 200, 60)
        draw.rounded_rectangle([56, y + 12, 56 + draw.textlength(subtitle, font=font_sub) + 56, y + 92],
                               radius=16, fill=accent + (255,))
        draw.text((84, y + 26), subtitle, font=font_sub, fill=(16, 16, 20, 255))

    canvas.alpha_composite(layer)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    canvas.convert("RGB").save(out_path, quality=95)
    return out_path

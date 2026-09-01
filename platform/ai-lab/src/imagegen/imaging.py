"""生成・取得した画像の後処理（縮小と形式変換）。

生成APIの出力はそのままだと重い。バナーやOGP画像として使うときは
横幅を揃えて webp/jpg にすると扱いやすいので、その変換をここに置く。
"""

from __future__ import annotations

import io

from .core.errors import ConfigError
from .core.types import GeneratedImage

FORMATS = {
    "png": ("PNG", "image/png"),
    "jpg": ("JPEG", "image/jpeg"),
    "jpeg": ("JPEG", "image/jpeg"),
    "webp": ("WEBP", "image/webp"),
}


def convert(
    image: GeneratedImage,
    *,
    fmt: str | None = None,
    max_width: int | None = None,
    quality: int = 85,
) -> GeneratedImage:
    """必要なら縮小・形式変換した画像を返す（不要ならそのまま返す）。"""
    if not fmt and not max_width:
        return image

    if fmt and fmt.lower() not in FORMATS:
        raise ConfigError(f"対応していない形式です: {fmt}（{', '.join(sorted(FORMATS))}）")

    try:
        from PIL import Image
    except ImportError as exc:  # pragma: no cover - 環境依存
        raise ConfigError("画像の変換には Pillow が必要です: pip install Pillow") from exc

    try:
        source = Image.open(io.BytesIO(image.data))
    except Exception as exc:  # SVG など Pillow が開けない形式
        raise ConfigError(f"この画像は変換できません（{type(exc).__name__}）") from exc

    changed = False
    if max_width and source.width > max_width:
        height = max(1, round(source.height * max_width / source.width))
        source = source.resize((max_width, height), Image.LANCZOS)
        changed = True

    pillow_format, mime = FORMATS[(fmt or "").lower()] if fmt else (source.format or "PNG", image.mime)
    if fmt and mime != image.mime:
        changed = True
    if not changed:
        return image

    if pillow_format == "JPEG" and source.mode in ("RGBA", "P", "LA"):
        # JPEG は透過を持てないので白で埋める
        background = Image.new("RGB", source.size, (255, 255, 255))
        background.paste(source.convert("RGBA"), mask=source.convert("RGBA").split()[-1])
        source = background

    buffer = io.BytesIO()
    options = {"quality": quality} if pillow_format in ("JPEG", "WEBP") else {}
    source.save(buffer, format=pillow_format, **options)

    return GeneratedImage(
        data=buffer.getvalue(),
        mime=mime,
        provider=image.provider,
        model=image.model,
        prompt=image.prompt,
        meta={**image.meta, "converted": True},
    )

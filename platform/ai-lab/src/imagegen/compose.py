"""文字入り画像の合成（サムネイル・OGP・共有画像）。

生成AIも素材サイトも「絵」までしか用意してくれない。実際に要るのは
**その絵に見出しを載せた1枚**なので、載せて組む工程をここに置く。

- 依存は Pillow だけ（imagegen の他のコマンドと同じ `[image]` extras）
- 同じ指定からは常に同じ画像が出る（乱数を使わない）
- 文字は枠に収まるまで折り返し、それでも入らなければ縮める
"""

from __future__ import annotations

import io
from pathlib import Path

from .core.errors import ConfigError
from .core.types import GeneratedImage
from .fonts import fit, measure, pick_font
from .imaging import FORMATS
from .utils import parse_size

#: よく使う仕上がりサイズ
PRESETS: dict[str, str] = {
    "youtube": "1280x720",
    "ogp": "1200x630",
    "shorts": "1080x1920",
    "square": "1080x1080",
    "wide": "1920x1080",
}

POSITIONS = ("top", "center", "bottom")
ALIGNS = ("left", "center", "right")
CORNERS = ("top_left", "top_right", "bottom_left", "bottom_right")

#: 文字が占めてよい高さの割合（これを超えるなら縮める）
TEXT_AREA = 0.55


def resolve_size(size: str | None = None, preset: str = "youtube") -> tuple[int, int]:
    """仕上がりサイズを決める。size の指定が preset より優先される。"""
    if size:
        return parse_size(size)
    if preset not in PRESETS:
        raise ConfigError(f"未知のプリセットです: {preset}（{', '.join(PRESETS)}）")
    return parse_size(PRESETS[preset])


def parse_color(value: str, default: str = "#000000"):
    """色の指定を RGB にする（#rrggbb や 'white' など）。"""
    from PIL import ImageColor

    try:
        return ImageColor.getrgb(value or default)
    except ValueError as exc:
        raise ConfigError(f"色の指定が不正です: {value!r}（例: #1a2b3c, white）") from exc


def _require_pillow():
    try:
        from PIL import Image, ImageDraw, ImageFilter

        return Image, ImageDraw, ImageFilter
    except ImportError as exc:  # pragma: no cover - 環境依存
        raise ConfigError("画像の合成には Pillow が必要です: pip install Pillow") from exc


def _load_background(source, size: tuple[int, int], color: str):
    """背景を作る。画像があれば全面に敷き（はみ出しは中央で切る）、無ければベタ塗り。"""
    Image, _draw, _filter = _require_pillow()
    width, height = size
    if source is None:
        return Image.new("RGB", size, parse_color(color, "#101828"))

    try:
        if isinstance(source, (bytes, bytearray)):
            base = Image.open(io.BytesIO(bytes(source)))
        else:
            path = Path(source)
            if not path.is_file():
                raise ConfigError(f"背景の画像がありません: {path}")
            base = Image.open(path)
        base = base.convert("RGB")
    except ConfigError:
        raise
    except Exception as exc:
        raise ConfigError(f"背景の画像を開けませんでした（{type(exc).__name__}）") from exc

    scale = max(width / base.width, height / base.height)
    resized = base.resize((max(1, round(base.width * scale)), max(1, round(base.height * scale))))
    left = (resized.width - width) // 2
    top = (resized.height - height) // 2
    return resized.crop((left, top, left + width, top + height))


def _apply_treatment(base, *, blur: float, dim: float):
    """背景を落ち着かせる（ぼかし・暗く）。文字を読ませるための処理。"""
    Image, _draw, ImageFilter = _require_pillow()
    if blur > 0:
        base = base.filter(ImageFilter.GaussianBlur(blur))
    if dim > 0:
        overlay = Image.new("RGB", base.size, (0, 0, 0))
        base = Image.blend(base, overlay, min(1.0, dim))
    return base


def _paste_logo(base, logo, *, scale: float, corner: str, margin: int):
    """ロゴを四隅のどこかに重ねる。"""
    Image, _draw, _filter = _require_pillow()
    path = Path(logo)
    if not path.is_file():
        raise ConfigError(f"ロゴの画像がありません: {path}")
    if corner not in CORNERS:
        raise ConfigError(f"ロゴの位置は {', '.join(CORNERS)} から選びます: {corner!r}")

    mark = Image.open(path).convert("RGBA")
    target_width = max(1, int(base.width * scale))
    ratio = target_width / mark.width
    mark = mark.resize((target_width, max(1, round(mark.height * ratio))))

    x = margin if corner.endswith("left") else base.width - mark.width - margin
    y = margin if corner.startswith("top") else base.height - mark.height - margin
    base.paste(mark, (x, y), mark)
    return base


def compose(
    *,
    title: str = "",
    subtitle: str = "",
    background=None,
    color: str = "#101828",
    size: str | None = None,
    preset: str = "youtube",
    font: str = "",
    title_scale: float = 0.12,
    subtitle_scale: float = 0.055,
    title_color: str = "#ffffff",
    subtitle_color: str = "#e6e6e6",
    stroke: int = 0,
    stroke_color: str = "#000000",
    band: bool = False,
    band_color: str = "#000000",
    band_alpha: int = 150,
    position: str = "bottom",
    align: str = "center",
    margin: float = 0.06,
    blur: float = 0.0,
    dim: float = 0.0,
    logo=None,
    logo_scale: float = 0.12,
    logo_position: str = "bottom_right",
    fmt: str = "png",
) -> GeneratedImage:
    """背景に見出しを載せた1枚を作る。"""
    Image, ImageDraw, _filter = _require_pillow()

    if position not in POSITIONS:
        raise ConfigError(f"position は {', '.join(POSITIONS)} から選びます: {position!r}")
    if align not in ALIGNS:
        raise ConfigError(f"align は {', '.join(ALIGNS)} から選びます: {align!r}")
    if (fmt or "png").lower() not in FORMATS:
        raise ConfigError(f"対応していない形式です: {fmt}（{', '.join(sorted(FORMATS))}）")

    width, height = resolve_size(size, preset)
    base = _apply_treatment(
        _load_background(background, (width, height), color), blur=blur, dim=dim
    )

    margin_px = max(8, int(width * margin))
    box_width = width - margin_px * 2
    blocks = []  # (行, フォント, 行の高さ, 色)

    if title.strip():
        title_font, title_lines, title_line_height = fit(
            title.strip(),
            max_width=box_width,
            max_height=int(height * TEXT_AREA),
            start_size=int(height * title_scale),
            path=font,
        )
        blocks.append(
            (title_lines, title_font, title_line_height, parse_color(title_color, "#ffffff"))
        )
    if subtitle.strip():
        subtitle_font, subtitle_lines, subtitle_line_height = fit(
            subtitle.strip(),
            max_width=box_width,
            max_height=int(height * 0.25),
            start_size=int(height * subtitle_scale),
            max_lines=2,
            path=font,
        )
        blocks.append(
            (
                subtitle_lines,
                subtitle_font,
                subtitle_line_height,
                parse_color(subtitle_color, "#e6e6e6"),
            )
        )

    def finish(image):
        """仕上げ（ロゴは文字の有無に関係なく必ず載せる）。"""
        if logo:
            return _paste_logo(
                image, logo, scale=logo_scale, corner=logo_position, margin=margin_px
            )
        return image

    if not blocks:  # 文字が無いなら背景の加工だけで仕上げる
        return _to_image(finish(base), fmt, title)

    gap = int(height * 0.02)
    block_height = sum(line_height * len(lines) for lines, _font, line_height, _color in blocks)
    block_height += gap * (len(blocks) - 1)

    if position == "top":
        cursor = margin_px
    elif position == "center":
        cursor = (height - block_height) // 2
    else:
        cursor = height - block_height - margin_px

    overlay = Image.new("RGBA", base.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)

    if band:
        # 端に寄せた文字の帯は、画面の端まで伸ばす。中途半端に切ると
        # 帯の外側に背景が細く残って「ずれている」ように見える。
        padding = int(height * 0.035)
        top_edge = 0 if position == "top" else max(0, cursor - padding)
        bottom_edge = (
            height if position == "bottom" else min(height, cursor + block_height + padding)
        )
        draw.rectangle(
            [(0, top_edge), (width, bottom_edge)],
            fill=(*parse_color(band_color, "#000000"), max(0, min(255, int(band_alpha)))),
        )

    stroke_rgb = parse_color(stroke_color, "#000000")
    for lines, block_font, line_height, text_color in blocks:
        for line in lines:
            line_width = measure(line, block_font, draw)[0]
            if align == "left":
                x = margin_px
            elif align == "right":
                x = width - margin_px - line_width
            else:
                x = (width - line_width) // 2
            draw.text(
                (x, cursor),
                line,
                font=block_font,
                fill=(*text_color, 255),
                stroke_width=max(0, int(stroke)),
                stroke_fill=(*stroke_rgb, 255),
            )
            cursor += line_height
        cursor += gap

    base = Image.alpha_composite(base.convert("RGBA"), overlay).convert("RGB")
    return _to_image(finish(base), fmt, title or subtitle)


def _to_image(base, fmt: str, label: str) -> GeneratedImage:
    """Pillow の画像を、保存や後処理に回せる形にする。"""
    pillow_format, mime = FORMATS[(fmt or "png").lower()]
    buffer = io.BytesIO()
    options = {"quality": 90} if pillow_format in ("JPEG", "WEBP") else {}
    base.save(buffer, format=pillow_format, **options)
    return GeneratedImage(
        data=buffer.getvalue(),
        mime=mime,
        provider="compose",
        model="compose-v1",
        prompt=label,
        meta={"composed": True, "size": f"{base.width}x{base.height}"},
    )


__all__ = ["PRESETS", "compose", "parse_color", "pick_font", "resolve_size"]

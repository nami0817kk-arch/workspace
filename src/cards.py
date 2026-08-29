"""画面に差し込むカードの描画。

ニュース番組が引用元の記事を画面に出すのと同じ役割。海外紙の見出しを
原文と訳で並べて出せるので、どこからの情報なのかが視聴者に伝わる。

カードは台本の frontmatter で定義し、行から `card:` で呼び出す。
"""

from __future__ import annotations

import hashlib
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

CARD_TYPES = ("quote", "transfer", "points")

PANEL = (16, 22, 34, 232)
BORDER = (255, 255, 255, 46)
TEXT = (245, 247, 250, 255)
SUB = (168, 178, 194, 255)
DEFAULT_ACCENT = "#3ea6ff"

PAD = 44
RADIUS = 22


class CardError(ValueError):
    pass


def card_key(spec: dict, width: int) -> str:
    parts = [str(width)] + [f"{k}={spec[k]}" for k in sorted(spec)]
    return hashlib.sha1("|".join(parts).encode("utf-8")).hexdigest()[:16]


def render(spec: dict, width: int, font_path: str, out_path: Path,
           latin_font_path: str | None = None) -> Path:
    """カード1枚を透過PNGで書き出す。高さは中身に合わせて決まる。"""
    kind = str(spec.get("type", "quote")).lower()
    if kind not in CARD_TYPES:
        raise CardError(f"カードの type は {CARD_TYPES} のいずれか: {kind}")

    builder = {"quote": _quote, "transfer": _transfer, "points": _points}[kind]
    blocks = builder(spec, width, font_path, latin_font_path or font_path)

    height = PAD * 2 + sum(block["height"] for block in blocks)
    canvas = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)

    accent = _hex(str(spec.get("color") or DEFAULT_ACCENT))
    draw.rounded_rectangle([0, 0, width - 1, height - 1], radius=RADIUS, fill=PANEL)
    draw.rounded_rectangle([0, 0, width - 1, height - 1], radius=RADIUS, outline=BORDER, width=2)
    # 左端のアクセント帯
    draw.rounded_rectangle([0, RADIUS, 8, height - RADIUS], radius=4, fill=accent + (255,))

    y = PAD
    for block in blocks:
        block["draw"](draw, y)
        y += block["height"]

    out_path.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(out_path)
    return out_path


# ------------------------------------------------------------------ 種類ごと


def _quote(spec: dict, width: int, font_path: str, latin_path: str) -> list[dict]:
    """引用カード。海外紙の見出しを原文で出し、下に訳を添える。"""
    inner = width - PAD * 2 - 12
    label_font = ImageFont.truetype(latin_path, 30)
    text_font = ImageFont.truetype(_font_for(str(spec.get("text") or ""), font_path, latin_path), 46)
    sub_font = ImageFont.truetype(font_path, 34)

    blocks: list[dict] = []
    source = str(spec.get("source") or "").strip()
    if source:
        accent = _hex(str(spec.get("color") or DEFAULT_ACCENT))

        def draw_label(draw, y, source=source, accent=accent):
            text_w = draw.textlength(source, font=label_font)
            draw.rounded_rectangle(
                [PAD + 12, y, PAD + 12 + text_w + 34, y + 46], radius=14, fill=accent + (255,)
            )
            draw.text((PAD + 29, y + 6), source, font=label_font, fill=(12, 16, 24, 255))

        blocks.append({"height": 46 + 22, "draw": draw_label})

    text = str(spec.get("text") or "").strip()
    if not text:
        raise CardError("quote カードには text が必要です")
    blocks.append(_text_block(text, text_font, inner, TEXT, 14))

    translation = str(spec.get("translation") or "").strip()
    if translation:
        blocks.append({"height": 16, "draw": lambda draw, y: None})
        blocks.append(_text_block(translation, sub_font, inner, SUB, 10))
    return blocks


def _transfer(spec: dict, width: int, font_path: str, latin_path: str) -> list[dict]:
    """移籍カード。誰がどこからどこへ、いくらで。"""
    name_font = ImageFont.truetype(font_path, 52)
    club_font = ImageFont.truetype(font_path, 42)
    small_font = ImageFont.truetype(font_path, 32)

    player = str(spec.get("player") or "").strip()
    origin = str(spec.get("from") or "").strip()
    destination = str(spec.get("to") or "").strip()
    fee = str(spec.get("fee") or "").strip()
    if not (player and origin and destination):
        raise CardError("transfer カードには player / from / to が必要です")

    blocks = [
        {
            "height": 68,
            "draw": lambda draw, y: draw.text(
                (PAD + 12, y), player, font=name_font, fill=TEXT
            ),
        }
    ]

    def draw_move(draw, y):
        x = PAD + 12
        draw.text((x, y), origin, font=club_font, fill=SUB)
        x += draw.textlength(origin, font=club_font) + 26
        draw.text((x, y - 2), "→", font=club_font, fill=_hex(DEFAULT_ACCENT) + (255,))
        x += draw.textlength("→", font=club_font) + 26
        draw.text((x, y), destination, font=club_font, fill=TEXT)

    blocks.append({"height": 62, "draw": draw_move})

    if fee:
        blocks.append(
            {
                "height": 46,
                "draw": lambda draw, y: draw.text(
                    (PAD + 12, y), fee, font=small_font, fill=SUB
                ),
            }
        )
    return blocks


def _points(spec: dict, width: int, font_path: str, latin_path: str) -> list[dict]:
    """箇条書きカード。整理して見せたいときに。"""
    inner = width - PAD * 2 - 60
    title_font = ImageFont.truetype(font_path, 44)
    item_font = ImageFont.truetype(font_path, 40)

    blocks = []
    title = str(spec.get("title") or "").strip()
    if title:
        blocks.append(
            {
                "height": 66,
                "draw": lambda draw, y: draw.text(
                    (PAD + 12, y), title, font=title_font, fill=TEXT
                ),
            }
        )

    items = list(spec.get("items") or [])
    if not items:
        raise CardError("points カードには items が必要です")
    accent = _hex(str(spec.get("color") or DEFAULT_ACCENT))

    for item in items[:5]:
        lines = _wrap(str(item), item_font, inner)

        def draw_item(draw, y, lines=lines, accent=accent):
            draw.ellipse([PAD + 16, y + 16, PAD + 32, y + 32], fill=accent + (255,))
            for offset, chunk in enumerate(lines):
                draw.text((PAD + 58, y + offset * 52), chunk, font=item_font, fill=TEXT)

        blocks.append({"height": 52 * len(lines) + 12, "draw": draw_item})
    return blocks


# ------------------------------------------------------------------ 補助


def _font_for(text: str, font_path: str, latin_path: str) -> str:
    """英数字だけの文章は欧文フォントで組む。"""
    return latin_path if text.isascii() else font_path


def _text_block(text: str, font: ImageFont.FreeTypeFont, inner: int, color, gap: int) -> dict:
    lines = _wrap(text, font, inner)
    line_height = font.size + gap

    def draw_text(draw, y, lines=lines):
        for offset, chunk in enumerate(lines):
            draw.text((PAD + 12, y + offset * line_height), chunk, font=font, fill=color)

    return {"height": line_height * len(lines), "draw": draw_text}


def _wrap(text: str, font: ImageFont.FreeTypeFont, max_width: int) -> list[str]:
    """英文は単語、日本語は文字で折り返す。"""
    measure = ImageDraw.Draw(Image.new("RGB", (1, 1)))
    if " " in text and text.isascii():
        lines, current = [], ""
        for word in text.split():
            candidate = f"{current} {word}".strip()
            if measure.textlength(candidate, font=font) > max_width and current:
                lines.append(current)
                current = word
            else:
                current = candidate
        if current:
            lines.append(current)
        return lines

    lines, current = [], ""
    for char in text:
        if measure.textlength(current + char, font=font) > max_width and current:
            lines.append(current)
            current = char
        else:
            current += char
    if current:
        lines.append(current)
    return lines


def _hex(value: str) -> tuple[int, int, int]:
    value = value.lstrip("#")
    if len(value) != 6:
        return (62, 166, 255)
    return tuple(int(value[i : i + 2], 16) for i in (0, 2, 4))

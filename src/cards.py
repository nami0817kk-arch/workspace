"""画面に差し込むカードの描画。

ニュース番組が引用元の記事を画面に出すのと同じ役割。海外紙の見出しを
原文と訳で並べて出せるので、どこからの情報なのかが視聴者に伝わる。

カードは台本の frontmatter で定義し、行から `card:` で呼び出す。
"""

from __future__ import annotations

import hashlib
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

CARD_TYPES = ("quote", "transfer", "points", "bars", "table", "reactions")

# 棒グラフは「同じ指標を並べて比べる」用途なので、色は1色で通し、
# 注目させたい1本だけ同じ色相の明るい段を使う（カテゴリ配色にはしない）。
BAR_BASE = (47, 106, 176)        # 下地の青。カード面に対して 3.3:1
BAR_HIGHLIGHT = (89, 176, 255)   # 注目させる1本。7.8:1
# カード面の上に直接描くので、半透明ではなく塗り込んだ色を使う
# （RGBA で半透明を描くと下地を置き換えてしまい、帯が白く抜ける）
GRID = (62, 72, 90, 255)
ZEBRA = (32, 41, 58, 255)
BUBBLE = (30, 38, 54, 255)      # 反応カードの吹き出し

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

    builder = {
        "quote": _quote,
        "transfer": _transfer,
        "points": _points,
        "bars": _bars,
        "table": _table,
        "reactions": _reactions,
    }[kind]
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
    # 出典は概要欄に書く運用なので、label を明示したときだけチップを出す
    source = str(spec.get("label") or "").strip()
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


def _bars(spec: dict, width: int, font_path: str, latin_path: str) -> list[dict]:
    """横棒で数量を比べるカード。

    同じ指標どうしの比較なので棒は1色で通し、注目させたい1本だけ明るくする。
    数値は棒の右端に直接置く（動画なのでホバーで見せられない）。
    """
    title_font = ImageFont.truetype(font_path, 42)
    label_font = ImageFont.truetype(font_path, 34)
    value_font = ImageFont.truetype(font_path, 34)

    items = [dict(item) for item in (spec.get("items") or [])]
    if not items:
        raise CardError("bars カードには items が必要です")
    for item in items:
        if "label" not in item or "value" not in item:
            raise CardError("bars の items には label と value が必要です")

    unit = str(spec.get("unit") or "")
    top = max(float(item["value"]) for item in items) or 1.0
    measure = ImageDraw.Draw(Image.new("RGB", (1, 1)))
    label_width = max(measure.textlength(str(i["label"]), font=label_font) for i in items)
    label_width = min(label_width, width * 0.34)
    value_width = max(
        measure.textlength(f"{_number(i['value'])}{unit}", font=value_font) for i in items
    )

    blocks: list[dict] = []
    title = str(spec.get("title") or "").strip()
    if title:
        blocks.append(
            {
                "height": 62,
                "draw": lambda draw, y: draw.text(
                    (PAD + 12, y), title, font=title_font, fill=TEXT
                ),
            }
        )

    bar_left = PAD + 12 + label_width + 24
    bar_span = width - PAD - bar_left - value_width - 34
    row_height = 54

    for item in items[:6]:
        ratio = max(0.0, float(item["value"])) / top
        color = BAR_HIGHLIGHT if item.get("highlight") else BAR_BASE

        def draw_row(draw, y, item=item, ratio=ratio, color=color):
            draw.text((PAD + 12, y + 6), str(item["label"]), font=label_font, fill=SUB)
            length = max(6, int(bar_span * ratio))
            # 端を少し丸めた細い棒。土台（左端）は角を立てて基準線に合わせる
            draw.rounded_rectangle(
                [bar_left, y + 8, bar_left + length, y + 42], radius=4, fill=color + (255,)
            )
            draw.rectangle([bar_left, y + 8, bar_left + 6, y + 42], fill=color + (255,))
            draw.text(
                (bar_left + length + 16, y + 6),
                f"{_number(item['value'])}{unit}",
                font=value_font,
                fill=TEXT,
            )

        blocks.append({"height": row_height, "draw": draw_row})

    note = str(spec.get("note") or "").strip()
    if note:
        note_font = ImageFont.truetype(font_path, 28)
        blocks.append({"height": 14, "draw": lambda draw, y: None})
        blocks.append(_text_block(note, note_font, width - PAD * 2 - 12, SUB, 6))
    return blocks


def _table(spec: dict, width: int, font_path: str, latin_path: str) -> list[dict]:
    """順位表のような表。1行だけ強調できる。"""
    title_font = ImageFont.truetype(font_path, 42)
    head_font = ImageFont.truetype(font_path, 30)
    cell_font = ImageFont.truetype(font_path, 34)

    columns = [str(c) for c in (spec.get("columns") or [])]
    rows = [[str(cell) for cell in row] for row in (spec.get("rows") or [])]
    if not columns or not rows:
        raise CardError("table カードには columns と rows が必要です")
    if any(len(row) != len(columns) for row in rows):
        raise CardError("table の各行は columns と同じ数にしてください")

    highlight = spec.get("highlight_row")
    inner = width - PAD * 2 - 12
    # 1列目は狭く、2列目を広く取る（順位＋名前の並びが多いため）
    weights = [0.14] + [0.5] + [0.36 / max(1, len(columns) - 2)] * max(0, len(columns) - 2)
    weights = weights[: len(columns)]
    total = sum(weights)
    widths = [inner * w / total for w in weights]

    blocks: list[dict] = []
    title = str(spec.get("title") or "").strip()
    if title:
        blocks.append(
            {
                "height": 62,
                "draw": lambda draw, y: draw.text(
                    (PAD + 12, y), title, font=title_font, fill=TEXT
                ),
            }
        )

    def draw_head(draw, y):
        x = PAD + 12
        for index, name in enumerate(columns):
            draw.text((x, y), name, font=head_font, fill=SUB)
            x += widths[index]
        draw.line([(PAD + 12, y + 42), (width - PAD, y + 42)], fill=GRID, width=2)

    blocks.append({"height": 56, "draw": draw_head})

    for number, row in enumerate(rows[:6]):
        def draw_row(draw, y, row=row, number=number):
            if number == highlight:
                draw.rounded_rectangle(
                    [PAD + 4, y - 4, width - PAD + 4, y + 44], radius=8, fill=ZEBRA
                )
            x = PAD + 12
            for index, cell in enumerate(row):
                color = TEXT if index != 0 else SUB
                draw.text((x, y), cell, font=cell_font, fill=color)
                x += widths[index]

        blocks.append({"height": 52, "draw": draw_row})
    return blocks


def _reactions(spec: dict, width: int, font_path: str, latin_path: str) -> list[dict]:
    """短い反応を並べて見せるカード。

    1件ずつ吹き出しに入れ、どこの発言かを右端に小さく出す。
    引用である以上、出どころの分からない発言は載せない前提。
    """
    title_font = ImageFont.truetype(font_path, 40)
    text_font = ImageFont.truetype(font_path, 36)
    label_font = ImageFont.truetype(font_path, 26)

    items = [dict(i) if isinstance(i, dict) else {"text": str(i)} for i in (spec.get("items") or [])]
    if not items:
        raise CardError("reactions カードには items が必要です")
    for item in items:
        if not str(item.get("text", "")).strip():
            raise CardError("reactions の items には text が必要です")

    blocks: list[dict] = []
    title = str(spec.get("title") or "").strip()
    if title:
        blocks.append(
            {
                "height": 58,
                "draw": lambda draw, y: draw.text(
                    (PAD + 12, y), title, font=title_font, fill=TEXT
                ),
            }
        )

    inner = width - PAD * 2 - 60
    for item in items[:5]:
        text = str(item["text"]).strip()
        label = str(item.get("label") or "").strip()
        lines = _wrap(text, text_font, inner)
        height = 34 + 46 * len(lines)

        def draw_bubble(draw, y, lines=lines, label=label, height=height):
            draw.rounded_rectangle(
                [PAD + 12, y, width - PAD, y + height - 14], radius=16, fill=BUBBLE
            )
            for offset, chunk in enumerate(lines):
                draw.text((PAD + 36, y + 14 + offset * 46), chunk, font=text_font, fill=TEXT)
            if label:
                label_w = draw.textlength(label, font=label_font)
                draw.text(
                    (width - PAD - label_w - 22, y + height - 44),
                    label, font=label_font, fill=SUB,
                )

        blocks.append({"height": height, "draw": draw_bubble})

    note = str(spec.get("note") or "").strip()
    if note:
        note_font = ImageFont.truetype(font_path, 26)
        blocks.append({"height": 10, "draw": lambda draw, y: None})
        blocks.append(_text_block(note, note_font, width - PAD * 2 - 12, SUB, 6))
    return blocks


def _number(value) -> str:
    number = float(value)
    return str(int(number)) if number.is_integer() else f"{number:g}"


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

"""画面に差し込むカードの描画。

ニュース番組が引用元の記事を画面に出すのと同じ役割。海外紙の見出しを
原文と訳で並べて出せるので、どこからの情報なのかが視聴者に伝わる。

カードは台本の frontmatter で定義し、行から `card:` で呼び出す。
"""

from __future__ import annotations

import hashlib
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

TEAM_SIZES = (46, 42, 38, 34, 30, 26, 22)

CARD_TYPES = ("quote", "transfer", "score", "points", "bars", "table", "reactions", "kit")

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
        "kit": _kit,
        "transfer": _transfer,
        "score": _score,
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
    # 名前は欧文とは限らない。**日本語だと豆腐になる**（2026-09-05 実測。
    # 「ヒュルツェラー監督」が □□□□ と出た）。中身を見てフォントを選ぶ
    label_font = ImageFont.truetype(
        _font_for(str(spec.get("label") or ""), font_path, latin_path), 30
    )
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


def _score(spec: dict, width: int, font_path: str, latin_path: str) -> list[dict]:
    """スコアカード。どちらが何点で、誰が決めたか。

    スコアを大きく置き、得点者を左右に分けて並べる。試合結果の動画では
    これが画面の主役になるので、数字は欧文フォントで大きく組む。
    """
    comp_font = ImageFont.truetype(font_path, 32)
    score_font = ImageFont.truetype(latin_path, 84)
    scorer_font = ImageFont.truetype(font_path, 30)

    home = str(spec.get("home") or "").strip()
    away = str(spec.get("away") or "").strip()
    score = str(spec.get("score") or "").strip()
    if not (home and away and score):
        raise CardError("score カードには home / away / score が必要です")

    # チーム名は長さの幅が大きい（「浦和」から「ボルシア・メンヒェングラートバッハ」まで）。
    # スコアの左右に収まる大きさを選ぶ。決め打ちにするとはみ出す
    ruler = ImageDraw.Draw(Image.new("RGBA", (width, 10)))
    score_width = ruler.textlength(score, font=score_font)
    side = (width - PAD * 2 - 24 - score_width) / 2 - 28
    team_font = ImageFont.truetype(font_path, TEAM_SIZES[-1])
    for size in TEAM_SIZES:
        candidate = ImageFont.truetype(font_path, size)
        if max(ruler.textlength(home, font=candidate),
               ruler.textlength(away, font=candidate)) <= side:
            team_font = candidate
            break
    else:
        # いちばん小さい字でも入らない長さがある（ボルシア・メンヒェングラートバッハ）。
        # はみ出させるくらいなら縮める
        home = _shorten(ruler, home, team_font, side)
        away = _shorten(ruler, away, team_font, side)

    competition = str(spec.get("competition") or "").strip()
    home_scorers = [str(x).strip() for x in (spec.get("home_scorers") or []) if str(x).strip()]
    away_scorers = [str(x).strip() for x in (spec.get("away_scorers") or []) if str(x).strip()]
    # スコアはこのカードの主役。クラブカラーが暗くても読めるようにする
    accent = readable(_hex(str(spec.get("color") or DEFAULT_ACCENT))) + (255,)

    blocks: list[dict] = []
    if competition:
        blocks.append(
            {
                "height": 44,
                "draw": lambda draw, y: draw.text(
                    (PAD + 12, y), competition, font=comp_font, fill=SUB
                ),
            }
        )

    left = PAD + 12
    right = width - PAD - 12

    def draw_line(draw, y):
        # スコアを中央に置き、チーム名を内側に寄せて左右に配置する
        score_w = draw.textlength(score, font=score_font)
        center = width // 2
        draw.text((center - score_w / 2, y), score, font=score_font, fill=accent)

        # 内側に寄せる。ただし枠の外には出さない
        home_w = draw.textlength(home, font=team_font)
        away_w = draw.textlength(away, font=team_font)
        home_x = max(left, min(left, center - score_w / 2 - home_w - 28))
        away_x = min(right - away_w, max(center + score_w / 2 + 28, right - away_w))
        draw.text((home_x, y + 24), home, font=team_font, fill=TEXT)
        draw.text((away_x, y + 24), away, font=team_font, fill=TEXT)

    blocks.append({"height": 108, "draw": draw_line})

    if home_scorers or away_scorers:
        rows = max(len(home_scorers), len(away_scorers))

        def draw_scorers(draw, y):
            draw.line([(left, y - 8), (right, y - 8)], fill=GRID, width=2)
            for index in range(rows):
                line_y = y + 8 + index * 36
                if index < len(home_scorers):
                    draw.text((left, line_y), home_scorers[index], font=scorer_font, fill=SUB)
                if index < len(away_scorers):
                    text = away_scorers[index]
                    draw.text((right - draw.textlength(text, font=scorer_font), line_y),
                              text, font=scorer_font, fill=SUB)

        blocks.append({"height": 22 + rows * 36, "draw": draw_scorers})

    note = str(spec.get("note") or "").strip()
    if note:
        blocks.append(
            {
                "height": 42,
                "draw": lambda draw, y: draw.text(
                    (PAD + 12, y), note, font=scorer_font, fill=SUB
                ),
            }
        )
    return blocks


def _shorten(ruler, text: str, font, limit: float) -> str:
    """収まる長さまで削って末尾に … を付ける。"""
    if ruler.textlength(text, font=font) <= limit:
        return text
    for cut in range(len(text) - 1, 0, -1):
        candidate = text[:cut] + "…"
        if ruler.textlength(candidate, font=font) <= limit:
            return candidate
    return "…"


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


def _kit(spec: dict, width: int, font_path: str, latin_path: str) -> list[dict]:
    """ユニフォーム風の図。誰が入って誰が外れたかを、背番号で並べる。

    **試合中の写真は自由ライセンスでは手に入らない。**スタジアム内の撮影が
    主催者の許可制で、撮れるのは契約した通信社だけだから（2026-09-04 に
    Commons と Flickr を当たって確認）。クラブカラーと背番号なら自分で
    描けるので、権利の問題が起きない。

    ```yaml
    type: kit
    title: リバプールのCL登録
    items:
      - {player: 遠藤 航, number: 3, colors: ["#C8102E"], mark: "×"}
      - {player: エキティケ, number: 22, colors: ["#C8102E"], mark: "○"}
    ```
    """
    items = [i for i in (spec.get("items") or []) if isinstance(i, dict)][:4]
    if not items:
        raise CardError("kit カードには items が必要です")

    title_font = ImageFont.truetype(font_path, 44)
    number_font = ImageFont.truetype(latin_path, 68)
    name_font = ImageFont.truetype(font_path, 34)
    mark_font = ImageFont.truetype(latin_path, 52)
    mark_small = ImageFont.truetype(latin_path, 30)
    back_font = ImageFont.truetype(latin_path, 34)

    blocks: list[dict] = []
    title = str(spec.get("title") or "").strip()
    if title:
        blocks.append({
            "height": 66,
            "draw": lambda draw, y: draw.text((PAD + 12, y), title, font=title_font, fill=TEXT),
        })

    inner = width - PAD * 2
    cell = inner // len(items)
    shirt_w = min(int(cell * 0.72), 190)
    shirt_h = int(shirt_w * 1.12)

    def draw_row(draw, y, items=items, cell=cell, shirt_w=shirt_w, shirt_h=shirt_h,
                 mark_font=mark_font, mark_small=mark_small,
                 number_font=number_font, back_font=back_font,
                 latin_path=latin_path):
        for index, item in enumerate(items):
            left = PAD + index * cell + (cell - shirt_w) // 2
            colors = [c for c in (item.get("colors") or []) if c] or ["#C8102E"]
            body = _hex(str(colors[0])) + (255,)
            _shirt(draw, left, y, shirt_w, shirt_h, body,
                   _hex(str(colors[1])) + (255,) if len(colors) > 1 else None)

            # 背番号は調べがついたときだけ。**確かめていない数字は出さない。**
            # 無ければ背中の名前として short を入れる（無ければ何も置かない）。
            number = str(item.get("number") or "").strip()
            face, font = (number, number_font) if number else (
                str(item.get("short") or "").strip(), back_font)
            if face:
                # シャツの幅に収める。はみ出すと胴からはみ出て読みにくい
                # 胴の幅は袖を除いた 0.58 ぶんしかない。全体幅で測ると
                # 収まった判定になり、袖にはみ出す（実測 2026-09-04）
                while font.size > 16 and draw.textlength(face, font=font) > shirt_w * 0.54:
                    font = ImageFont.truetype(
                        latin_path if not number else latin_path, font.size - 2
                    )
                w = draw.textlength(face, font=font)
                top = y + shirt_h * (0.34 if number else 0.40)
                draw.text((left + (shirt_w - w) / 2, top), face, font=font,
                          fill=(255, 255, 255, 255), stroke_width=3,
                          stroke_fill=(0, 0, 0, 120))

            name = str(item.get("player") or "").strip()
            if name:
                w = draw.textlength(name, font=name_font)
                draw.text((left + (shirt_w - w) / 2, y + shirt_h + 14),
                          name, font=name_font, fill=TEXT)

            mark = str(item.get("mark") or "").strip()
            if mark:
                # 印は判定そのものなので、丸地を敷いて確実に読めるようにする
                ok = mark in "○◯"
                color = (74, 200, 128, 255) if ok else (226, 80, 80, 255)
                r = 30
                cx, cy = left + shirt_w - 12, y + 4
                draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=color)
                glyph = "OK" if ok else "×"
                font = mark_small if ok else mark_font
                w = draw.textlength(glyph, font=font)
                top = cy - (30 if ok else 34)
                draw.text((cx - w / 2, top), glyph, font=font, fill=(255, 255, 255, 255))

    blocks.append({"height": shirt_h + 62, "draw": draw_row})
    return blocks


def _shirt(draw, x: int, y: int, w: int, h: int, body, stripe=None) -> None:
    """シャツの形。袖・肩・襟を多角形1つで描く。"""
    def point(px, py):
        return (x + w * px, y + h * py)

    shape = [point(*p) for p in (
        (0.30, 0.02), (0.42, 0.09), (0.58, 0.09), (0.70, 0.02),
        (0.98, 0.22), (0.86, 0.44), (0.76, 0.38), (0.79, 1.00),
        (0.21, 1.00), (0.24, 0.38), (0.14, 0.44), (0.02, 0.22),
    )]
    draw.polygon(shape, fill=body)
    if stripe:  # 2色目があれば縦縞にする
        for i in range(1, 4):
            px = 0.21 + 0.145 * i
            draw.polygon([point(px, 0.10), point(px + 0.06, 0.10),
                          point(px + 0.06, 1.00), point(px, 1.00)], fill=stripe)
    draw.polygon([point(0.42, 0.09), point(0.50, 0.19), point(0.58, 0.09)],
                 fill=(245, 245, 245, 235))


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
    ruler = ImageDraw.Draw(Image.new("RGB", (10, 10)))
    for item in items[:5]:
        text = str(item["text"]).strip()
        label = str(item.get("label") or "").strip()
        # ラベルは吹き出しの右下に置く。本文をそのままの幅で折り返すと、
        # 最終行がラベルの下に潜り込んで重なる（実際に重なっていた）
        label_w = ruler.textlength(label, font=label_font) if label else 0
        lines = _wrap(text, text_font, inner)
        if label and len(lines) > 1:
            lines = _wrap(text, text_font, int(inner - label_w - 30))
        elif label:
            # 1行に収まっていても、ラベルと横に並ぶので幅を分け合う
            if ruler.textlength(text, font=text_font) > inner - label_w - 30:
                lines = _wrap(text, text_font, int(inner - label_w - 30))
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

    # 日本語は render 側の折り返しに任せる。ここは文字幅だけで切っていたので、
    # 禁則も熟語の判定も効いていなかった。実測（2026-09-04）で、カードを
    # 細くしたとたん「必／要」と割れた。**同じ規則を2か所に持たない。**
    from .render import balanced_wrap  # 循環importを避けるため関数の中で読む

    return balanced_wrap(measure, text, font, max_width)


def _wrap_by_char(text: str, font: ImageFont.FreeTypeFont, max_width: int) -> list[str]:
    """文字幅だけで折り返す。折り返しの規則を通さない用途向け。"""
    measure = ImageDraw.Draw(Image.new("RGB", (1, 1)))
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


# パネルの明るさ。文字色がこれに対して十分明るいかを見る
_PANEL_LUMA = 0.2126 * PANEL[0] + 0.7152 * PANEL[1] + 0.0722 * PANEL[2]
MIN_CONTRAST = 3.0


def _luma(color: tuple[int, int, int]) -> float:
    channels = []
    for value in color[:3]:
        ratio = value / 255
        channels.append(ratio / 12.92 if ratio <= 0.03928 else ((ratio + 0.055) / 1.055) ** 2.4)
    return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2]


def _contrast(color: tuple[int, int, int], against: tuple[int, int, int]) -> float:
    first, second = _luma(color) + 0.05, _luma(against) + 0.05
    return max(first, second) / min(first, second)


def readable(color: tuple[int, int, int]) -> tuple[int, int, int]:
    """パネルの上で読める色にする。

    クラブカラーをアクセントに使うと、トッテナムの濃紺のように暗すぎて
    文字が沈むことがある。線や帯なら沈んでもよいが、数字は読めないと困る。
    """
    if _contrast(color, PANEL[:3]) >= MIN_CONTRAST:
        return color
    return _hex(DEFAULT_ACCENT)


def _hex(value: str) -> tuple[int, int, int]:
    value = value.lstrip("#")
    if len(value) != 6:
        return (62, 166, 255)
    return tuple(int(value[i : i + 2], 16) for i in (0, 2, 4))

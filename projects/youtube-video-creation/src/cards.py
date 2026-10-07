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

CARD_TYPES = ("quote", "transfer", "score", "points", "bars", "table", "reactions", "kit",
              "stats", "verdict", "calc", "versus", "scatter", "convert")
# **画面いっぱいの絵になる型**（2026-10-07）。板（カード）ではなく、写真の下地の代わりに敷く。
# render.py は板と同じ扱い（上に節の名前・見出し・ほかのカードを重ねない）で描く
FULL_SCREEN_TYPES = ("versus",)

# 棒グラフは「同じ指標を並べて比べる」用途なので、色は1色で通し、
# 注目させたい1本だけ同じ色相の明るい段を使う（カテゴリ配色にはしない）。
BAR_BASE = (47, 106, 176)        # 下地の青。カード面に対して 3.3:1
BAR_HIGHLIGHT = (89, 176, 255)   # 注目させる1本。7.8:1
# カード面の上に直接描くので、半透明ではなく塗り込んだ色を使う
# （RGBA で半透明を描くと下地を置き換えてしまい、帯が白く抜ける）
GRID = (62, 72, 90, 255)
ZEBRA = (22, 28, 38, 255)
BUBBLE = (30, 38, 54, 255)      # 反応カードの吹き出し

# **見た目の作り直し**（2026-09-28 ユーザー「全体的に画面描画の質を上げたい」「もう少し見やすく」）。
# 板は写真を透けさせない（ほぼ不透明）。色はチャンネルの2色（深い緑＋黄）で通す
PANEL = (12, 18, 28, 248)
BORDER = (255, 255, 255, 50)
TEXT = (245, 247, 250, 255)
SUB = (168, 178, 194, 255)
BRAND_GREEN = (11, 61, 46, 255)     # 表の見出し行・節のピル
BRAND_GOLD = (255, 213, 74, 255)    # 見出しの字・話している行の印・数字
HILITE = (44, 50, 60, 255)          # 話している行
DEFAULT_ACCENT = "#ffd54a"   # 板の左の縦帯もチャンネルの黄に（2026-09-28）

PAD = 44
RADIUS = 22


class CardError(ValueError):
    pass


def card_key(spec: dict, width: int, reveal: int | None = None) -> str:
    parts = [str(width)] + [f"{k}={spec[k]}" for k in sorted(spec)]
    if reveal is not None:
        parts.append(f"reveal={reveal}")
    return hashlib.sha1("|".join(parts).encode("utf-8")).hexdigest()[:16]


def row_count(spec: dict) -> int:
    """表と棒グラフの行数（出現アニメの段数）。ほかの型は 0。"""
    kind = str(spec.get("type", "quote")).lower()
    if kind == "table":
        return min(6, len(spec.get("rows") or []))
    if kind == "bars":
        return min(6, len(spec.get("items") or []))
    # 2026-10-07 に足した3つも1項目ずつ出す（数字・式の項・判定の行）
    if kind == "stats":
        return min(3, len(spec.get("items") or []))
    if kind == "calc":
        return len(spec.get("terms") or [])
    if kind == "verdict":
        return min(6, len(spec.get("rows") or []))
    # 2026-10-07 夜。散らばり図は点を1つずつ、換算は 元 → 矢印 → 換算 の順に
    if kind == "scatter":
        return min(SCATTER_MAX, len(spec.get("points") or []))
    if kind == "convert":
        return max(0, len(convert_values(spec)) * 2 - 1)
    return 0


def is_full_screen(spec: dict | None) -> bool:
    """画面いっぱいの絵になるカードか（versus）。"""
    return bool(spec) and str(spec.get("type", "")).lower() in FULL_SCREEN_TYPES


# 話している行・点を光らせる鍵。これだけが違うカードは「同じ表」（表は highlight_row、散らばり図は highlight）
HIGHLIGHT_KEYS = ("highlight_row", "highlight")


def same_table(a: dict | None, b: dict | None) -> bool:
    """光らせる行（highlight_row・散らばり図の highlight）だけが違う、同じ表か（render.same_table・書き込みの引き継ぎ）。"""
    if not a or not b:
        return False
    strip = lambda spec: {k: v for k, v in spec.items() if k not in HIGHLIGHT_KEYS}
    return strip(a) == strip(b)


# **書き込み（赤ペン）を足せる型**（2026-10-07、src/marks.py）。項目の番号・列で指す
MARKABLE_TYPES = ("table", "verdict", "bars", "stats", "calc", "points", "scatter", "convert")


def mark_units(spec: dict | None) -> int:
    """書き込みで指せる項目の数（表・判定表・棒は行、数字の板・式・箇条書きは項目）。描けない型は 0。"""
    if not spec:
        return 0
    kind = str(spec.get("type", "")).lower()
    if kind in ("table", "verdict"):
        return len([r for r in (spec.get("rows") or []) if isinstance(r, (list, tuple))])
    if kind == "bars":
        return min(6, len(spec.get("items") or []))
    if kind == "stats":
        return len(spec.get("items") or [])
    if kind == "calc":
        return len(spec.get("terms") or [])
    if kind == "points":
        return min(5, len(spec.get("items") or []))
    if kind == "scatter":
        return min(SCATTER_MAX, len(spec.get("points") or []))
    if kind == "convert":
        return len(convert_values(spec))
    return 0


def mark_columns(spec: dict | None) -> list[str]:
    """`col:` で指せる列の名前。列の無い型は空（番号も名前も使えない）。"""
    kind = str((spec or {}).get("type", "")).lower()
    if kind == "table":
        return [str(c) for c in (spec.get("columns") or [])]
    if kind == "verdict":
        rows = verdict_rows(spec)
        width = len(rows[0]) if rows else 3
        named = [str(c) for c in (spec.get("columns") or [])]
        return named if len(named) == width else ["項目", "判定", "一言"][:width]
    if kind == "bars":
        return ["名前", "棒", "値"]
    if kind in ("stats", "calc", "convert"):
        return ["数字", "注記"]
    if kind == "scatter":
        return ["点", "名前"]
    return []


def layout(spec: dict, width: int, font_path: str, latin_font_path: str | None = None) -> dict:
    """カードの中の項目の位置（`render` と同じ寸法で、描かずに測る）。書き込みの的に使う。

    返すのは ``{"size": (幅, 高さ), "units": [{"box": 行の枠, "cells": [列ごとの字の枠 or None], "text": 字の枠}]}``。
    座標はカードの左上が原点（px）。
    """
    kind = str(spec.get("type", "quote")).lower()
    builder = {"bars": _bars, "table": _table, "stats": _stats, "verdict": _verdict,
               "calc": _calc, "points": _points, "scatter": _scatter, "convert": _convert}.get(kind)
    if builder is None:
        raise CardError(f"{kind} カードには書き込みを足せません（{'・'.join(MARKABLE_TYPES)}）")
    blocks = builder(spec, width, font_path, latin_font_path or font_path)
    source = str(spec.get("source") or "").strip()
    height = PAD * 2 + sum(block["height"] for block in blocks) + (18 if source else 0)
    units = []
    y = PAD
    for block in blocks:
        if block.get("unit"):
            unit = block["unit"](y)
            texts = [c for c in unit["cells"] if c]
            unit["text"] = _union(texts) if texts else unit["box"]
            units.append(unit)
        y += block["height"]
    return {"size": (width, height), "units": units}


_RULER = None


def _ruler():
    global _RULER
    if _RULER is None:
        _RULER = ImageDraw.Draw(Image.new("RGB", (4, 4)))
    return _RULER


def _text_box(x: float, y: float, text: str, font, anchor: str = "la"):
    """描いた字の枠（x0, y0, x1, y1）。空なら None。"""
    if not str(text).strip():
        return None
    return tuple(float(v) for v in _ruler().textbbox((x, y), str(text), font=font, anchor=anchor))


def _union(boxes):
    boxes = [b for b in boxes if b]
    if not boxes:
        return None
    return (min(b[0] for b in boxes), min(b[1] for b in boxes),
            max(b[2] for b in boxes), max(b[3] for b in boxes))


def _number_box(x: float, baseline: float, text: str, size: int, font_path: str):
    """put_number で描いた数字の枠。"""
    boxes = []
    for chunk, ratio in _segments(text):
        font = _font(font_path, size * ratio)
        boxes.append(_text_box(x, baseline, chunk, font, "ls"))
        x += _ruler().textlength(chunk, font=font)
    return _union(boxes)


def render(spec: dict, width: int, font_path: str, out_path: Path,
           latin_font_path: str | None = None, reveal: int | None = None) -> Path:
    """カード1枚を透過PNGで書き出す。高さは中身に合わせて決まる。

    reveal を渡すと、表・棒グラフの行を**その数だけ**描く（残りの行は空けておく）。
    行が1本ずつ現れる出現アニメの1コマ（2026-09-28 動きの段2）。
    """
    kind = str(spec.get("type", "quote")).lower()
    if kind not in CARD_TYPES:
        raise CardError(f"カードの type は {CARD_TYPES} のいずれか: {kind}")
    if kind in FULL_SCREEN_TYPES:
        raise CardError(f"{kind} は板ではなく画面いっぱいの絵です。render_versus で描いてください")

    builder = {
        "quote": _quote,
        "kit": _kit,
        "transfer": _transfer,
        "score": _score,
        "points": _points,
        "bars": _bars,
        "table": _table,
        "reactions": _reactions,
        "stats": _stats,
        "verdict": _verdict,
        "calc": _calc,
        "scatter": _scatter,
        "convert": _convert,
    }[kind]
    blocks = builder(spec, width, font_path, latin_font_path or font_path)

    source = str(spec.get("source") or "").strip()
    height = PAD * 2 + sum(block["height"] for block in blocks) + (18 if source else 0)
    canvas = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)

    accent = _hex(str(spec.get("color") or DEFAULT_ACCENT))
    draw.rounded_rectangle([0, 0, width - 1, height - 1], radius=RADIUS, fill=PANEL)
    draw.rounded_rectangle([0, 0, width - 1, height - 1], radius=RADIUS, outline=BORDER, width=2)
    # 左端のアクセント帯
    draw.rounded_rectangle([0, RADIUS, 8, height - RADIUS], radius=4, fill=accent + (255,))

    if source:
        # 出典を右下に小さく（品質100回の65）。自作の図だと分かり、数字の出どころが画面に残る
        src_font = ImageFont.truetype(font_path, 22)
        sw = draw.textlength(source, font=src_font)
        draw.text((width - PAD - sw, height - PAD - 4), source, font=src_font, fill=(120, 130, 146, 255))
    y = PAD
    shown_rows = 0
    for block in blocks:
        if block.get("row"):
            shown_rows += 1
            if reveal is not None and shown_rows > reveal:
                y += block["height"]
                continue
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

    translation = str(spec.get("translation") or "").strip()
    if translation:
        # **訳を主役にする**（2026-09-07）。日本語話者に向けた動画なのに、
        # 画面のいちばん大きい文字が英語の長文になっていた（実測で画面の6割）。
        # 原文は消さない。事実の扱いとして原文は残す決まりなので、小さく添える。
        primary_font = ImageFont.truetype(
            _font_for(translation, font_path, latin_path), 46
        )
        blocks.append(_text_block(translation, primary_font, inner, TEXT, 14))
        blocks.append({"height": 16, "draw": lambda draw, y: None})
        original_font = ImageFont.truetype(_font_for(text, font_path, latin_path), 32)
        blocks.append(_text_block(text, original_font, inner, SUB, 10))
        return blocks

    blocks.append(_text_block(text, text_font, inner, TEXT, 14))
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

        def unit_item(y, lines=lines):
            text = _union([_text_box(PAD + 58, y + k * 52, chunk, item_font) for k, chunk in enumerate(lines)])
            return {"box": (PAD + 8, y, width - PAD, y + 52 * len(lines) + 4), "cells": [text]}

        blocks.append({"height": 52 * len(lines) + 12, "draw": draw_item, "unit": unit_item})
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
    # **図の質を上げる**（2026-09-28 ユーザー「図や表のクオリティを上げて」）。
    # 棒は太く（44px）、注目の1本は黄、ほかは緑のグラデ。薄い目盛りと、値の右揃え
    title_font = ImageFont.truetype(font_path, 44)
    label_font = ImageFont.truetype(font_path, 36)
    value_font = ImageFont.truetype(font_path, 40)

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

    bar_left = PAD + 12 + label_width + 28
    value_col = width - PAD - 12
    bar_span = value_col - bar_left - value_width - 36
    row_height = 70

    def draw_scale(draw, y):
        # 薄い目盛り（最大値の 1/4 ごと）。値の見当が付く
        for k in range(1, 5):
            x = bar_left + int(bar_span * k / 4)
            draw.line([(x, y), (x, y + row_height * min(6, len(items)) + 8)], fill=(255, 255, 255, 22), width=1)

    blocks.append({"height": 8, "draw": draw_scale})

    for item in items[:6]:
        ratio = max(0.0, float(item["value"])) / top
        strong = bool(item.get("highlight"))

        def draw_row(draw, y, item=item, ratio=ratio, strong=strong):
            draw.text((PAD + 12, y + 12), str(item["label"]), font=label_font, fill=TEXT)
            length = max(8, int(bar_span * ratio))
            top_y, bottom_y = y + 10, y + 54
            # 土台の溝（薄い帯）に、色の棒を重ねる。棒は左から右へ明るくなるグラデ
            draw.rounded_rectangle([bar_left, top_y, bar_left + bar_span, bottom_y], radius=10, fill=(255, 255, 255, 16))
            start, end = ((196, 150, 20), (255, 213, 74)) if strong else ((11, 61, 46), (46, 140, 96))
            for i in range(length):
                t = i / max(1, length - 1)
                color = tuple(int(start[c] + (end[c] - start[c]) * t) for c in range(3))
                draw.line([(bar_left + i, top_y), (bar_left + i, bottom_y)], fill=color + (255,))
            # 右端を丸める（半円を重ねる）
            r = (bottom_y - top_y) // 2
            draw.pieslice([bar_left + length - r, top_y, bar_left + length + r, bottom_y], start=270, end=90, fill=end + (255,))
            text = f"{_number(item['value'])}{unit}"
            tw = draw.textlength(text, font=value_font)
            draw.text((value_col - tw, y + 8), text, font=value_font, fill=BRAND_GOLD if strong else TEXT)

        def unit_row(y, item=item, ratio=ratio):
            length = max(8, int(bar_span * ratio))
            text = f"{_number(item['value'])}{unit}"
            tw = _ruler().textlength(text, font=value_font)
            return {"box": (PAD + 4, y + 2, width - PAD - 4, y + row_height - 6),
                    "cells": [_text_box(PAD + 12, y + 12, str(item["label"]), label_font),
                              (bar_left, y + 10, bar_left + length, y + 54),
                              _text_box(value_col - tw, y + 8, text, value_font)]}

        blocks.append({"height": row_height, "draw": draw_row, "row": True, "unit": unit_row})

    note = str(spec.get("note") or "").strip()
    if note:
        note_font = ImageFont.truetype(font_path, 28)
        blocks.append({"height": 14, "draw": lambda draw, y: None})
        blocks.append(_text_block(note, note_font, width - PAD * 2 - 12, SUB, 6))
    return blocks


import re as _re

NUMERIC_CELL = _re.compile(r"^[+\-−]?[\d,.]+(?:[%点本人回分秒位歳億万勝敗分試合GAkm]|G \d+A|試合（先発\d+）)?$|^[\d,.]+G [\d,.]+A$|^―$|^→$|^[↑↓]\d+$|^new$")
RATING_CELL = _re.compile(r"^\d\.\d$")


def _looks_numeric(text: str) -> bool:
    return bool(NUMERIC_CELL.match(str(text).strip()))


def _looks_rating(text: str) -> bool:
    return bool(RATING_CELL.match(str(text).strip()))


def _fit_cell(draw, text: str, font, room: float) -> str:
    """列に収まるところまで。収まらなければ末尾を … にする（2026-09-14）。"""
    text = str(text)
    if room <= 0 or draw.textlength(text, font=font) <= room:
        return text
    cut = text
    while cut and draw.textlength(cut + "…", font=font) > room:
        cut = cut[:-1]
    return (cut + "…") if cut else ""


TABLE_ROWS_FULL = 6   # この行数までは行の高さ72・字40のまま。超えたら詰めて全部出す


def _table(spec: dict, width: int, font_path: str, latin_path: str) -> list[dict]:
    """順位表のような表。1行だけ強調できる。"""
    # 字を一回り大きく（2026-09-28「もう少し見やすく」）。34 → 40。入らなければ縮む
    title_font = ImageFont.truetype(font_path, 44)
    head_font = ImageFont.truetype(font_path, 30)
    cell_font = ImageFont.truetype(font_path, 40)

    columns = [str(c) for c in (spec.get("columns") or [])]
    rows = [[str(cell) for cell in row] for row in (spec.get("rows") or [])]
    if not columns or not rows:
        raise CardError("table カードには columns と rows が必要です")
    if any(len(row) != len(columns) for row in rows):
        raise CardError("table の各行は columns と同じ数にしてください")

    highlight = spec.get("highlight_row")
    inner = width - PAD * 2 - 12
    # **行は全部出す**（2026-09-30）。7行目から先を黙って捨てていて、ソシエダの回で
    # 「7試合を終えて」と読みながら表には6試合しか無かった。6行を超えたら、
    # 表の高さが6行ぶんに収まるよう行と字を詰める
    many = len(rows) > TABLE_ROWS_FULL
    row_h = 72 if not many else max(44, int(72 * TABLE_ROWS_FULL / len(rows)))
    if many:
        cell_font = ImageFont.truetype(font_path, max(22, min(40, row_h - 22)))
    # **中身の長さで列幅を決める**（2026-09-14 指摘「サッカー部門CEOが被ってる」）。
    # 1列目を14%の決め打ちにしていたので、「ロン・ゴーレイ」のような長い名前が
    # はみ出して2列目の字に重なっていた。実際に測って、足りない列を広げる
    ruler = ImageDraw.Draw(Image.new("RGB", (10, 10)))
    GAP = 34

    def _natural(font):
        out = []
        for index in range(len(columns)):
            cells = [columns[index]] + [row[index] for row in rows]
            out.append(max(ruler.textlength(str(c), font=font) for c in cells) + GAP)
        return out

    # **入らなければ字を縮める。**切って「…」にすると中身が消える
    # （2026-09-14 に「ハーランドはオンサイドと…」で実際に消えた）
    size = cell_font.size
    natural = _natural(cell_font)
    while sum(natural) > inner and size > 22:
        size -= 2
        cell_font = ImageFont.truetype(font_path, size)
        natural = _natural(cell_font)
    total = sum(natural)
    if total <= inner:
        # 余ったぶんは最後の列に足す。表が左に寄って見えないように
        widths = list(natural)
        widths[-1] += inner - total
    else:
        # 入りきらないときは、**広い列から削る**。狭い列を削ると名前が潰れる
        widths = list(natural)
        over = total - inner
        while over > 1:
            big = max(range(len(widths)), key=lambda i: widths[i])
            take = min(over, widths[big] * 0.25)
            widths[big] -= take
            over -= take

    blocks: list[dict] = []
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

    # 列の中身が数字（単位つきを含む）なら右揃えにする
    numeric = [all(_looks_numeric(row[index]) for row in rows) for index in range(len(columns))]

    # 見出し行は緑の帯に黄色の字（罫線1本より目が行く）
    def draw_head(draw, y):
        draw.rectangle([PAD - 8, y - 6, width - PAD + 8, y + 44], fill=BRAND_GREEN)
        x = PAD + 12
        for index, name in enumerate(columns):
            if numeric[index] and index > 0:
                tw = draw.textlength(name, font=head_font)
                draw.text((x + widths[index] - 16 - tw, y + 2), name, font=head_font, fill=BRAND_GOLD)
            else:
                draw.text((x, y + 2), name, font=head_font, fill=BRAND_GOLD)
            x += widths[index]

    blocks.append({"height": 58, "draw": draw_head})

    text_dy = 10 if not many else max(4, (row_h - 8 - cell_font.size) // 2 - 2)
    for number, row in enumerate(rows):
        def draw_row(draw, y, row=row, number=number):
            if number == highlight:
                # 話している行：明るい地＋左に黄色の印。数字も黄色
                draw.rounded_rectangle(
                    [PAD - 8, y - 4, width - PAD + 8, y + row_h - 8], radius=10, fill=HILITE
                )
                draw.rectangle([PAD - 8, y + 4, PAD - 2, y + row_h - 16], fill=BRAND_GOLD)
            elif number % 2 == 0:
                draw.rectangle([PAD - 8, y - 4, width - PAD + 8, y + row_h - 8], fill=ZEBRA)
            x = PAD + 12
            for index, cell in enumerate(row):
                last = index == len(row) - 1
                color = BRAND_GOLD if (number == highlight and last) else (TEXT if index != 0 else SUB)
                # 評点（7.9 のような小数1桁）は 8.0 以上を黄で目立たせる
                if _looks_rating(cell) and float(cell) >= 8.0:
                    color = BRAND_GOLD
                # **列からはみ出させない。**はみ出すと隣の字に重なる
                shown = _fit_cell(draw, cell, cell_font, widths[index] - 16)
                # **数字の列は右揃え**（2026-09-28「図や表のクオリティ」）。左揃えだと桁が揃わない
                if numeric[index] and index > 0:
                    tw = draw.textlength(shown, font=cell_font)
                    draw.text((x + widths[index] - 16 - tw, y + text_dy), shown, font=cell_font, fill=color)
                else:
                    draw.text((x, y + text_dy), shown, font=cell_font, fill=color)
                x += widths[index]

        def unit_row(y, row=row):
            cells = []
            x = PAD + 12
            for index, cell in enumerate(row):
                shown = _fit_cell(ruler, cell, cell_font, widths[index] - 16)
                tw = ruler.textlength(shown, font=cell_font)
                x0 = x + widths[index] - 16 - tw if (numeric[index] and index > 0) else x
                cells.append(_text_box(x0, y + text_dy, shown, cell_font))
                x += widths[index]
            return {"box": (PAD - 8, y - 4, width - PAD + 8, y + row_h - 8), "cells": cells}

        blocks.append({"height": row_h, "draw": draw_row, "row": True, "unit": unit_row})
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


# ------------------------------------------------------------------ 数字の板（2026-10-07）
#
# 歴史の地層（chiso/numbers.py の stats・calc・versus）と世の中の断面図（charts5 の verdict・
# charts4 の checklist）から移した。向こうは古紙色の板に t=0→1 で描き進める作り／1枚の静止画を
# 返す作りなので、こちらの「縦に積むブロック＋reveal で行を出す」作りに書き直した。
# **数字は太く大きく、単位は半分の大きさ**（figures.put_number と同じ組み方）。注目の1つだけ黄。

UNIT_RATIO = 0.5          # 単位（数字でない字）の大きさ。数字に対する割合
WORD_RATIO = 0.66         # 数字を含まない値（「W杯」）の大きさ

# 判定の印の色。不透明の色で塗る（半透明を RGBA の板に直接描くと白く抜ける）
MARK_COLORS = {
    "◎": (255, 213, 74, 255),    # 黄（いちばん良い）
    "○": (74, 200, 128, 255),    # 緑
    "△": (235, 165, 40, 255),    # 橙
    "×": (226, 80, 80, 255),     # 赤
    "✓": (74, 200, 128, 255),
    "✗": (226, 80, 80, 255),
}
# 書き方の揺れを1つに寄せる
MARK_ALIASES = {"◎": "◎", "○": "○", "〇": "○", "◯": "○", "△": "△", "▲": "△",
                "×": "×", "✕": "×", "x": "×", "X": "×", "✖": "×",
                "✓": "✓", "✔": "✓", "レ": "✓", "✗": "✗", "✘": "✗"}
VERDICT_MARKS = tuple(MARK_COLORS)
_DIGIT_CHARS = "0123456789０１２３４５６７８９"


def verdict_mark(text) -> str:
    """判定の字を ◎○△×✓✗ のどれかに寄せる。知らない字なら空。"""
    return MARK_ALIASES.get(str(text or "").strip(), "")


def _segments(text: str) -> list[tuple[str, float]]:
    """数字は大きく（1.0）、単位は小さく（0.5）。数字を1つも含まなければ全体を 0.66 で。"""
    text = str(text)
    if not _re.search(r"[0-9０-９]", text):
        return [(text, WORD_RATIO)] if text else []
    out = []
    for m in _re.finditer(r"[0-9０-９][0-9０-９,.，．]*|[^0-9０-９]+", text):
        chunk = m.group(0)
        out.append((chunk, 1.0 if chunk[0] in _DIGIT_CHARS else UNIT_RATIO))
    return out


def _font(path: str, size: float) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(path, max(8, int(size)))


def number_width(text: str, size: int, font_path: str) -> float:
    ruler = ImageDraw.Draw(Image.new("RGB", (4, 4)))
    return sum(ruler.textlength(chunk, font=_font(font_path, size * ratio))
               for chunk, ratio in _segments(text))


def fit_number(text: str, size: int, room: float, font_path: str, floor: int = 40) -> int:
    """room に収まるまで縮めた大きさ。"""
    while size > floor and number_width(text, size, font_path) > room:
        size -= 4
    return size


def put_number(draw, x: float, baseline: float, text: str, size: int, fill, font_path: str,
               stroke: int = 0, stroke_fill=(0, 0, 0, 255)) -> float:
    """数字を大きく、単位を半分の大きさで、下の線をそろえて描く。右端の x を返す。"""
    for chunk, ratio in _segments(text):
        font = _font(font_path, size * ratio)
        draw.text((x, baseline), chunk, font=font, fill=fill, anchor="ls",
                  stroke_width=stroke if ratio == 1.0 else max(0, stroke * 2 // 3),
                  stroke_fill=stroke_fill)
        x += draw.textlength(chunk, font=font)
    return x


def _title_block(spec: dict, font_path: str) -> list[dict]:
    title = str(spec.get("title") or "").strip()
    if not title:
        return []
    font = ImageFont.truetype(font_path, 44)
    return [{"height": 66, "draw": lambda draw, y: draw.text((PAD + 12, y), title, font=font, fill=TEXT)}]


def _note_blocks(spec: dict, width: int, font_path: str) -> list[dict]:
    note = str(spec.get("note") or "").strip()
    if not note:
        return []
    note_font = ImageFont.truetype(font_path, 28)
    return [{"height": 14, "draw": lambda draw, y: None},
            _text_block(note, note_font, width - PAD * 2 - 12, SUB, 6)]


def stat_items(spec: dict) -> list[dict]:
    """stats の items を {number, unit, note} の並びに。`[数字, 単位, 注記]` か辞書。"""
    out = []
    for item in spec.get("items") or []:
        if isinstance(item, dict):
            out.append({"number": str(item.get("number", "")).strip(),
                        "unit": str(item.get("unit", "") or "").strip(),
                        "note": str(item.get("note", "") or "").strip()})
        elif isinstance(item, (list, tuple)):
            cells = [str(c if c is not None else "").strip() for c in item]
            cells += [""] * (3 - len(cells))
            out.append({"number": cells[0], "unit": cells[1], "note": cells[2]})
        else:
            out.append({"number": str(item).strip(), "unit": "", "note": ""})
    return out


def focus_index(spec: dict, count: int) -> int:
    """注目の1つ。`focus` は 0 始まりの番号か、数字・注記の字。無ければ最後。"""
    focus = spec.get("focus")
    if focus is None or focus == "":
        return count - 1
    if isinstance(focus, int) and not isinstance(focus, bool):
        return focus if 0 <= focus < count else count - 1
    for index, item in enumerate(stat_items(spec)):
        if str(focus).strip() in (item["number"], item["note"], item["number"] + item["unit"]):
            return index
    return count - 1


def _stats(spec: dict, width: int, font_path: str, latin_path: str) -> list[dict]:
    """数字3つの大きな板（2026-10-07）。シリーズの冒頭の「いちばん強い一点」に。

    ```yaml
    card: {type: stats, title: メッシの代表, items: [[208, 試合, 歴代最多], [126, 点], [W杯, 優勝, 2022年]]}
    ```
    数字は太く大きく、単位は半分。注目の1つ（`focus`、無ければ最後）だけ黄、ほかは白。
    """
    items = stat_items(spec)
    if not items or not all(item["number"] for item in items):
        raise CardError("stats カードには items（[数字, 単位, 注記] を1〜3つ）が必要です")
    if len(items) > 3:
        raise CardError("stats の items は3つまでです")
    n = len(items)
    hot = focus_index(spec, n)
    left, right = PAD + 12, width - PAD
    col = (right - left) / n
    room = col - 40
    # 大きさ：注目は 150、ほかは 118 から。ほかの数字は同じ大きさにそろえる（ばらつくと注目が立たない）
    base = 150 if n > 1 else 190
    hot_size = fit_number(items[hot]["number"] + items[hot]["unit"], base, room, font_path)
    rest = [fit_number(it["number"] + it["unit"], int(base * 0.79), room, font_path)
            for i, it in enumerate(items) if i != hot]
    other = min(min(rest) if rest else hot_size, hot_size)
    sizes = [hot_size if i == hot else other for i in range(n)]
    note_font = ImageFont.truetype(font_path, 30)
    notes = [_wrap(it["note"], note_font, int(col - 28))[:2] if it["note"] else [] for it in items]
    note_h = max((len(x) for x in notes), default=0) * 40
    num_h = int(hot_size * 1.02) + 18
    height = num_h + note_h + 20

    blocks = _title_block(spec, font_path)
    for index, item in enumerate(items):
        def draw_item(draw, y, index=index, item=item):
            x0 = left + index * col
            cx = x0 + col / 2
            if index:
                draw.line([(x0, y + 10), (x0, y + height - 16)], fill=GRID, width=2)
            text = item["number"] + item["unit"]
            size = sizes[index]
            w = number_width(text, size, font_path)
            baseline = y + num_h - 14
            put_number(draw, cx - w / 2, baseline, text, size,
                       BRAND_GOLD if index == hot else TEXT, font_path)
            for k, chunk in enumerate(notes[index]):
                tw = draw.textlength(chunk, font=note_font)
                draw.text((cx - tw / 2, y + num_h + 6 + k * 40), chunk, font=note_font, fill=SUB)

        def unit_item(y, index=index, item=item):
            x0 = left + index * col
            cx = x0 + col / 2
            text = item["number"] + item["unit"]
            w = number_width(text, sizes[index], font_path)
            number = _number_box(cx - w / 2, y + num_h - 14, text, sizes[index], font_path)
            note = _union([_text_box(cx - _ruler().textlength(chunk, font=note_font) / 2, y + num_h + 6 + k * 40,
                                     chunk, note_font) for k, chunk in enumerate(notes[index])])
            return {"box": (x0 + 6, y, x0 + col - 6, y + height - 10), "cells": [number, note]}

        # 横に並ぶので、高さは最後の1つだけが持つ（reveal で出ていない項目も場所は空けておく）
        blocks.append({"height": height if index == n - 1 else 0, "draw": draw_item, "row": True,
                       "unit": unit_item})
    return blocks + _note_blocks(spec, width, font_path)


def calc_terms(spec: dict) -> list[dict]:
    out = []
    for term in spec.get("terms") or []:
        if isinstance(term, dict):
            out.append({"value": str(term.get("value", "")).strip(),
                        "note": str(term.get("note", "") or "").strip()})
        elif isinstance(term, (list, tuple)):
            cells = [str(c if c is not None else "").strip() for c in term] + ["", ""]
            out.append({"value": cells[0], "note": cells[1]})
        else:
            out.append({"value": str(term).strip(), "note": ""})
    return out


CALC_OPS = ("÷", "×", "＋", "+", "－", "-", "−", "＝", "=", "≒", "→")


def calc_ops(spec: dict, count: int) -> list[str]:
    ops = spec.get("ops")
    if ops is None:
        return ["×"] * max(0, count - 2) + ["＝"]
    return [str(op).strip() for op in ops]


def _calc(spec: dict, width: int, font_path: str, latin_path: str) -> list[dict]:
    """計算の式（2026-10-07）。見立ての「この回だけの数字」に。

    ```yaml
    card: {type: calc, title: ケインの代表, terms: [[125試合, 代表の出場], [11年, 2015〜2026], [年10.8試合, 1年あたり]], ops: [÷, ＝]}
    ```
    項が左から順に出て（reveal）、最後の項（答え）だけ大きく黄、下に黄の線。
    """
    terms = calc_terms(spec)
    if len(terms) < 2 or not all(t["value"] for t in terms):
        raise CardError("calc カードには terms（[値, 注記] を2つ以上）が必要です")
    n = len(terms)
    ops = calc_ops(spec, n)
    if len(ops) != n - 1:
        raise CardError(f"calc の ops は項の数より1つ少なく（{n - 1}個）書いてください")
    inner = width - PAD * 2 - 24
    note_font = ImageFont.truetype(font_path, 28)
    ruler = ImageDraw.Draw(Image.new("RGB", (4, 4)))
    scale = 1.0
    while True:
        sizes = [int((134 if k == n - 1 else 104) * scale) for k in range(n)]
        op_font = _font(font_path, 70 * scale)
        gap = 26 * scale
        term_w = [number_width(t["value"], s, font_path) for t, s in zip(terms, sizes)]
        note_w = [ruler.textlength(t["note"], font=note_font) if t["note"] else 0 for t in terms]
        slots = [max(a, b) for a, b in zip(term_w, note_w)]
        op_w = [ruler.textlength(op, font=op_font) + gap * 2 for op in ops]
        total = sum(slots) + sum(op_w)
        if total <= inner or scale <= 0.45:
            break
        scale -= 0.05
    x = PAD + 12 + max(0.0, (inner - total) / 2)
    starts = []
    for k in range(n):
        if k:
            x += op_w[k - 1]
        starts.append(x)
        x += slots[k]
    num_h = int(sizes[-1] * 1.02) + 10
    height = num_h + (44 if any(t["note"] for t in terms) else 12) + 14

    blocks = _title_block(spec, font_path)
    for k, term in enumerate(terms):
        def draw_term(draw, y, k=k, term=term):
            baseline = y + num_h - 10
            hot = k == n - 1
            if k:
                # 記号は、そのあとに出る項と一緒に出る
                op = ops[k - 1]
                ox = starts[k] - op_w[k - 1] + gap
                draw.text((ox, baseline - sizes[0] * 0.30), op, font=op_font, fill=SUB, anchor="lm")
            cx = starts[k] + slots[k] / 2
            tx = cx - term_w[k] / 2
            put_number(draw, tx, baseline, term["value"], sizes[k], BRAND_GOLD if hot else TEXT, font_path)
            if hot:
                draw.rectangle([tx - 4, baseline + 10, tx + term_w[k] + 4, baseline + 16], fill=BRAND_GOLD)
            if term["note"]:
                nw = ruler.textlength(term["note"], font=note_font)
                draw.text((cx - nw / 2, baseline + 24), term["note"], font=note_font, fill=SUB)

        def unit_term(y, k=k, term=term):
            baseline = y + num_h - 10
            cx = starts[k] + slots[k] / 2
            value = _number_box(cx - term_w[k] / 2, baseline, term["value"], sizes[k], font_path)
            note = (_text_box(cx - note_w[k] / 2, baseline + 24, term["note"], note_font)
                    if term["note"] else None)
            return {"box": (starts[k] - 10, y, starts[k] + slots[k] + 10, y + height - 10),
                    "cells": [value, note]}

        blocks.append({"height": height if k == n - 1 else 0, "draw": draw_term, "row": True,
                       "unit": unit_term})
    return blocks + _note_blocks(spec, width, font_path)


def verdict_rows(spec: dict) -> list[list[str]]:
    return [[str(c if c is not None else "").strip() for c in row] for row in (spec.get("rows") or [])
            if isinstance(row, (list, tuple))]


def _draw_mark(draw, cx: float, cy: float, mark: str, r: int = 26) -> None:
    """判定の印。字ではなく図形で描く（フォントに ✓ が無い環境がある・大きさがそろう）。"""
    color = MARK_COLORS.get(mark, TEXT)
    if mark in ("✓", "✗"):
        # 塗った丸に白い印（断面図の checklist と同じ。輪郭だけだと小さい画面で見えない）
        draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=color)
        if mark == "✓":
            draw.line([(cx - r * 0.5, cy + 1), (cx - r * 0.12, cy + r * 0.42), (cx + r * 0.55, cy - r * 0.42)],
                      fill=(255, 255, 255, 255), width=7, joint="curve")
        else:
            k = r * 0.42
            draw.line([(cx - k, cy - k), (cx + k, cy + k)], fill=(255, 255, 255, 255), width=7)
            draw.line([(cx + k, cy - k), (cx - k, cy + k)], fill=(255, 255, 255, 255), width=7)
        return
    if mark == "◎":
        draw.ellipse([cx - r, cy - r, cx + r, cy + r], outline=color, width=7)
        q = r * 0.48
        draw.ellipse([cx - q, cy - q, cx + q, cy + q], outline=color, width=6)
    elif mark == "○":
        draw.ellipse([cx - r, cy - r, cx + r, cy + r], outline=color, width=8)
    elif mark == "△":
        draw.line([(cx, cy - r), (cx + r * 1.05, cy + r * 0.8), (cx - r * 1.05, cy + r * 0.8), (cx, cy - r)],
                  fill=color, width=8, joint="curve")
    elif mark == "×":
        k = r * 0.82
        draw.line([(cx - k, cy - k), (cx + k, cy + k)], fill=color, width=10)
        draw.line([(cx + k, cy - k), (cx - k, cy + k)], fill=color, width=10)


def _verdict(spec: dict, width: int, font_path: str, latin_path: str) -> list[dict]:
    """判定表（2026-10-07）。◎○△×（checklist 形は ✓✗）を色つきの印で。

    ```yaml
    card: {type: verdict, title: 夏の補強の答え合わせ, rows: [[イサク, ◎, 8試合6点], [ヴィルツ, △, 1点だけ]]}
    ```
    行は `[項目, 判定, 一言]`（一言は省いてよい）。表と同じく `reveal` で1行ずつ出て、
    `highlight_row` の行が光る（行ごとにカードを分けても `same_table` で開き直さない）。
    """
    rows = verdict_rows(spec)
    if not rows:
        raise CardError("verdict カードには rows（[項目, 判定, 一言]）が必要です")
    lengths = {len(row) for row in rows}
    if len(lengths) != 1 or next(iter(lengths)) not in (2, 3):
        raise CardError("verdict の各行は [項目, 判定] か [項目, 判定, 一言] でそろえてください")
    for row in rows:
        if not verdict_mark(row[1]):
            raise CardError(f"verdict の判定は {'・'.join(VERDICT_MARKS)} のどれか: {row[1]}")
    three = len(rows[0]) == 3
    columns = [str(c) for c in (spec.get("columns") or [])]
    if columns and len(columns) != len(rows[0]):
        raise CardError("verdict の columns は行と同じ数にしてください")
    highlight = spec.get("highlight_row")

    many = len(rows) > TABLE_ROWS_FULL
    item_font = ImageFont.truetype(font_path, 40 if not many else max(28, int(40 * TABLE_ROWS_FULL / len(rows))))
    head_font = ImageFont.truetype(font_path, 30)
    ruler = ImageDraw.Draw(Image.new("RGB", (4, 4)))
    left, right = PAD + 12, width - PAD
    inner = right - left
    mark_w = 120 if columns else 104
    # 項目の列は中身の長さで（3列なら幅の 40% まで。入らなければ字を縮める）
    want = max(ruler.textlength(row[0], font=item_font) for row in rows) + 30
    item_w = min(want, inner * (0.40 if three else 0.70))
    while item_font.size > 26 and max(ruler.textlength(r[0], font=item_font) for r in rows) > item_w - 20:
        item_font = ImageFont.truetype(font_path, item_font.size - 2)
    comment_w = inner - item_w - mark_w
    comment_font = ImageFont.truetype(font_path, max(26, item_font.size - 4))
    comments = [_wrap(row[2], comment_font, int(comment_w - 16))[:2] if three and row[2] else [] for row in rows]
    lines = max((len(c) for c in comments), default=1) or 1
    base_h = 72 if not many else max(48, int(72 * TABLE_ROWS_FULL / len(rows)))
    row_h = max(base_h, 26 + lines * (comment_font.size + 10))
    r = max(14, min(26, (base_h - 22) // 2))
    line_h = comment_font.size + 10

    blocks = _title_block(spec, font_path)

    if columns:
        def draw_head(draw, y):
            draw.rectangle([PAD - 8, y - 6, width - PAD + 8, y + 44], fill=BRAND_GREEN)
            xs = (left, left + item_w, left + item_w + mark_w + 16)
            for index, name in enumerate(columns):
                if index == 1:
                    tw = draw.textlength(name, font=head_font)
                    draw.text((xs[1] + (mark_w - tw) / 2, y + 2), name, font=head_font, fill=BRAND_GOLD)
                else:
                    draw.text((xs[index], y + 2), name, font=head_font, fill=BRAND_GOLD)

        blocks.append({"height": 58, "draw": draw_head})

    for number, row in enumerate(rows):
        def draw_row(draw, y, row=row, number=number):
            if number == highlight:
                draw.rounded_rectangle([PAD - 8, y - 4, width - PAD + 8, y + row_h - 8], radius=10, fill=HILITE)
                draw.rectangle([PAD - 8, y + 4, PAD - 2, y + row_h - 16], fill=BRAND_GOLD)
            elif number % 2 == 0:
                draw.rectangle([PAD - 8, y - 4, width - PAD + 8, y + row_h - 8], fill=ZEBRA)
            mid = y + (row_h - 12) / 2
            item = _fit_cell(draw, row[0], item_font, item_w - 16)
            draw.text((left, mid), item, font=item_font, anchor="lm",
                      fill=BRAND_GOLD if number == highlight else TEXT)
            _draw_mark(draw, left + item_w + mark_w / 2, mid, verdict_mark(row[1]), r)
            chunks = comments[number]
            first = mid - (len(chunks) - 1) * line_h / 2
            for k, chunk in enumerate(chunks):
                draw.text((left + item_w + mark_w + 16, first + k * line_h), chunk,
                          font=comment_font, anchor="lm", fill=TEXT if number == highlight else SUB)

        def unit_row(y, row=row, number=number):
            mid = y + (row_h - 12) / 2
            item = _fit_cell(ruler, row[0], item_font, item_w - 16)
            cx = left + item_w + mark_w / 2
            chunks = comments[number]
            first = mid - (len(chunks) - 1) * line_h / 2
            comment = _union([_text_box(left + item_w + mark_w + 16, first + k * line_h, chunk,
                                        comment_font, "lm") for k, chunk in enumerate(chunks)])
            cells = [_text_box(left, mid, item, item_font, "lm"), (cx - r, mid - r, cx + r, mid + r)]
            if three:
                cells.append(comment)
            return {"box": (PAD - 8, y - 4, width - PAD + 8, y + row_h - 8), "cells": cells}

        blocks.append({"height": row_h, "draw": draw_row, "row": True, "unit": unit_row})
    return blocks + _note_blocks(spec, width, font_path)


# ------------------------------------------------------------------ 2軸の散らばり図・換算の板（2026-10-07 夜）
#
# ユーザーが「3.5」を選んだ（③2軸の散らばり図・⑤換算の板）。世の中の断面図の charts5.matrix
# （2軸に印を打ち、札が重ならないように逃がす）と figures.convert（「1回ぶん」を「1年ぶん」に直す
# 箱と矢印）を、こちらの「縦に積むブロック＋reveal で1つずつ出す」作りに書き直した。

SCATTER_MAX = 10          # 点は10まで。それより多いと札が逃げきれず、目で追えない
SCATTER_KEYS = frozenset({"type", "title", "x", "y", "points", "focus", "highlight", "diagonal",
                          "note", "source", "color"})
AXIS_KEYS = frozenset({"label", "unit"})
CONVERT_KEYS = frozenset({"type", "title", "from", "to", "steps", "via", "note", "source", "color"})
CONVERT_MAX = 3           # 週給→年俸→円 の3段まで
DOT = (74, 200, 128, 255)          # ふつうの点（判定の○と同じ緑）
DOT_DIM = (40, 112, 76, 255)       # 話している人がいるとき、ほかの点は沈める
DOT_RING = (12, 18, 28, 255)       # 点の縁（板の地の色。重なった点を分ける）
LABEL = (214, 220, 230, 255)
LEADER = (112, 122, 138, 255)      # 離した札と点を結ぶ細い線
DIAGONAL = (150, 160, 176, 255)
BOX = (24, 31, 42, 255)            # 換算の途中の箱
ARROW = (200, 208, 220, 255)

_FULLWIDTH = str.maketrans("０１２３４５６７８９．，－＋", "0123456789.,-+")
_KANJI_UNITS = {"千": 1e3, "万": 1e4, "億": 1e8, "兆": 1e12}


def to_number(value) -> float | None:
    """点の座標に使う数。数字そのもの（`9.8`・`"1,240"`）だけを数に。字が混じれば None。"""
    if isinstance(value, bool) or value is None:
        return None
    if isinstance(value, (int, float)):
        return float(value)
    text = str(value).strip().translate(_FULLWIDTH).replace(",", "").replace("−", "-")
    if not _re.fullmatch(r"[-+]?\d+(?:\.\d+)?", text):
        return None
    return float(text)


def amount(text) -> float | None:
    """金額などの量。「約30億」「1560万」「1億2000万」「300,000」を数に。数字で始まらなければ None。"""
    text = str(text or "").translate(_FULLWIDTH).replace(",", "")
    text = _re.sub(r"^\s*(?:約|およそ|ほぼ)\s*", "", text)
    piece = _re.compile(r"(\d+(?:\.\d+)?)((?:[千万億兆])*)")
    total, found, pos = 0.0, False, 0
    while True:
        m = piece.match(text, pos)
        if not m:
            break
        value = float(m.group(1))
        for unit in m.group(2):
            value *= _KANJI_UNITS[unit]
        total += value
        found, pos = True, m.end()
        if not m.group(2):          # 「1億2000万」の続きだけ足す。「30ポンド」はここで終わり
            break
    return total if found else None


# ---- 散らばり図


def _axis(spec: dict, key: str) -> dict:
    axis = spec.get(key)
    if isinstance(axis, str):
        return {"label": axis.strip(), "unit": ""}
    if isinstance(axis, dict):
        return {"label": str(axis.get("label") or "").strip(), "unit": str(axis.get("unit") or "").strip()}
    return {"label": "", "unit": ""}


def scatter_points(spec: dict) -> list[dict]:
    """points を {name, x, y} の並びに。数でない座標は None のまま（check_scatter が止める）。"""
    out = []
    for point in spec.get("points") or []:
        if isinstance(point, dict):
            name, x, y = point.get("name"), point.get("x"), point.get("y")
        elif isinstance(point, (list, tuple)) and len(point) == 3:
            name, x, y = point
        else:
            out.append({"name": "", "x": None, "y": None, "raw": point})
            continue
        out.append({"name": str(name if name is not None else "").strip(),
                    "x": to_number(x), "y": to_number(y), "raw": point})
    return out


def scatter_pick(spec: dict, key: str, count: int) -> int | None:
    """focus・highlight を点の番号に。名前か 0 始まりの番号。無ければ None、合わなければ -1。"""
    value = spec.get(key)
    if value is None or value == "":
        return None
    if isinstance(value, int) and not isinstance(value, bool):
        return value if 0 <= value < count else -1
    names = [p["name"] for p in scatter_points(spec)]
    return names.index(str(value).strip()) if str(value).strip() in names else -1


def check_scatter(spec: dict) -> list[str]:
    """散らばり図の形の誤り（描く前に止める。research の draft も同じものを見る）。"""
    problems = []
    unknown = sorted(str(k) for k in spec if k not in SCATTER_KEYS)
    if unknown:
        problems.append(f"scatter カードに知らない鍵があります（{unknown[0]}）。"
                        f"使えるのは {'・'.join(sorted(SCATTER_KEYS))}")
    for key in ("x", "y"):
        axis = spec.get(key)
        if isinstance(axis, dict):
            extra = sorted(str(k) for k in axis if k not in AXIS_KEYS)
            if extra:
                problems.append(f"scatter の {key} に知らない鍵があります（{extra[0]}）。使えるのは label・unit")
        if not _axis(spec, key)["label"]:
            problems.append(f"scatter には {key}: {{label: …, unit: …}}（軸の名前）が必要です")
    points = scatter_points(spec)
    if len(points) < 2:
        problems.append("scatter の points は [名前, x, y] を2つ以上書いてください")
    elif len(points) > SCATTER_MAX:
        problems.append(f"scatter の points は{SCATTER_MAX}までです（{len(points)}）。札が重なって読めません")
    for point in points:
        if point["x"] is None or point["y"] is None or not point["name"]:
            problems.append(f"scatter の点は [名前, x, y]（x・y は数だけ）で書いてください（{str(point['raw'])[:30]}）")
            break
    names = [p["name"] for p in points if p["name"]]
    if len(set(names)) != len(names):
        problems.append("scatter の点の名前が重なっています（focus・highlight・書き込みで指せません）")
    for key in ("focus", "highlight"):
        if points and scatter_pick(spec, key, len(points)) == -1:
            problems.append(f"scatter の {key}『{spec.get(key)}』は点の名前か 0〜{len(points) - 1} の番号で書いてください")
    diagonal = spec.get("diagonal")
    if diagonal is not None and not isinstance(diagonal, (bool, str)):
        problems.append("scatter の diagonal は true か、線の名前（字）で書いてください")
    return problems


def nice_ticks(lo: float, hi: float, target: int = 5) -> list[float]:
    """切りのよい目盛り（1・2・2.5・5 の10のべき倍）。lo〜hi を覆う。"""
    import math

    if hi <= lo:
        hi = lo + 1.0
    raw = (hi - lo) / target
    mag = 10 ** math.floor(math.log10(raw))
    step = mag * 10
    for m in (1, 2, 2.5, 5, 10):
        if (hi - lo) / (m * mag) <= target:
            step = m * mag
            break
    start = math.floor(lo / step + 1e-9) * step
    end = math.ceil(hi / step - 1e-9) * step
    count = int(round((end - start) / step))
    return [round(start + i * step, 10) for i in range(count + 1)]


def _scatter_range(values: list[float]) -> tuple[float, float]:
    lo, hi = min(values), max(values)
    span = (hi - lo) or max(abs(hi), 1.0)
    # 0 からの軸にする（得点・期待値・出場時間は 0 から見たほうが差の大きさが正しく見える）
    if lo >= 0 and lo <= hi * 0.5:
        lo = 0.0
    else:
        lo -= span * 0.06
    hi += span * 0.08          # 端の点の札が外へ出ないように少し空ける
    return lo, hi


def _tick_text(value: float) -> str:
    return f"{value:g}" if abs(value) < 1e6 else f"{value:.3g}"


def _scatter(spec: dict, width: int, font_path: str, latin_path: str) -> list[dict]:
    """2軸の散らばり図（2026-10-07 夜）。比較の回・若手の数字・得点王レース（得点×期待値）に。

    ```yaml
    card: {type: scatter, title: 得点と期待値（xG）, x: {label: 期待値, unit: xG}, y: {label: 得点, unit: 点},
           points: [[ハーランド, 9.8, 14], [サラー, 6.1, 5], …], focus: ハーランド, diagonal: 期待値どおり}
    ```
    点が1つずつ出て（reveal）、`highlight`（名前か番号）の点が光る。行ごとにカードを分けて
    highlight だけ替えても開き直さない（same_table）。注目（focus）だけ黄で大きく、ほかは緑。
    名前の札は点・ほかの札・枠にかからない場所へ逃がし、離れたら細い線で結ぶ。
    """
    problems = check_scatter(spec)
    if problems:
        raise CardError(problems[0])
    points = scatter_points(spec)
    n = len(points)
    focus = scatter_pick(spec, "focus", n)
    highlight = scatter_pick(spec, "highlight", n)
    x_axis, y_axis = _axis(spec, "x"), _axis(spec, "y")
    diagonal = spec.get("diagonal")
    wide = width >= 1050
    ruler = _ruler()

    tick_font = _font(font_path, 28 if wide else 27)
    axis_font = _font(font_path, 30 if wide else 29)
    label_size = 34 if wide else 33
    fonts = [_font(font_path, label_size + (2 if k == focus else 0)) for k in range(n)]

    xs = [p["x"] for p in points]
    ys = [p["y"] for p in points]
    if diagonal:
        # 斜めの線（y＝x）を角から角へ通すため、2つの軸の幅をそろえる
        lo, hi = _scatter_range(xs + ys)
        x_ticks = y_ticks = nice_ticks(lo, hi)
    else:
        x_ticks = nice_ticks(*_scatter_range(xs))
        y_ticks = nice_ticks(*_scatter_range(ys))
    x_lo, x_hi, y_lo, y_hi = x_ticks[0], x_ticks[-1], y_ticks[0], y_ticks[-1]

    left = PAD + 12
    y_tick_w = max(ruler.textlength(_tick_text(t), font=tick_font) for t in y_ticks)
    plot_left = left + y_tick_w + 16
    plot_right = width - PAD - 14
    head = 56                       # 縦軸の名前の段（上の目盛りの字とぶつけない）
    # 縦（ショート）は 0.50。0.60 だと板が画面の半分を超え、上に寄せた顔（_v.jpg）の目元までかかった
    plot_h = min(380, int(width * 0.34)) if wide else int(width * 0.50)
    plot_top, plot_bottom = head, head + plot_h
    tail = 76                       # 横軸の目盛り＋名前の段
    height = plot_bottom + tail

    def px(value: float) -> float:
        return plot_left + (value - x_lo) / (x_hi - x_lo) * (plot_right - plot_left)

    def py(value: float) -> float:
        return plot_bottom - (value - y_lo) / (y_hi - y_lo) * (plot_bottom - plot_top)

    radius = [19 if k == focus else 13 for k in range(n)]
    dots = [(px(p["x"]), py(p["y"])) for p in points]
    dot_boxes = [(cx - r - 5, cy - r - 5, cx + r + 5, cy + r + 5) for (cx, cy), r in zip(dots, radius)]

    # 斜めの線の名前は凡例として縦軸の名前の段の右に置く（線の上に字を載せると点の札とぶつかる）
    legend = str(diagonal).strip() if isinstance(diagonal, str) else ""

    # ---- 札の置き場（reveal・highlight で動かないよう、全部の点で先に決める）
    pad_x, pad_y = 10, 5
    # 札は縦軸の目盛りの列まで使ってよい（目盛りの字は避ける）。枠の内に限ると、左端の点の札を
    # 押し戻した先が自分の点に重なった（10/7 の見本のペドロ、ショートの幅）
    area = (left - 2, plot_top + 2, plot_right - 2, plot_bottom - 4)
    tick_boxes = []
    for t in y_ticks:
        tw = ruler.textlength(_tick_text(t), font=tick_font)
        tick_boxes.append((plot_left - 12 - tw - 2, py(t) - 16, plot_left - 8, py(t) + 16))
    # 札の長いものから置く（長い札ほど置き場が少ない。キャルバート＝ルーウィンを後に回すと、
    # 空いているのが隣の点の上だけになった）。注目の点はいつも先
    sizes = {k: ruler.textbbox((0, 0), points[k]["name"], font=fonts[k], anchor="ls") for k in range(n)}
    order = sorted(range(n), key=lambda k: (k != focus, -(sizes[k][2] - sizes[k][0]), k))
    taken: list[tuple] = []
    places: dict[int, tuple] = {}
    for k in order:
        cx, cy = dots[k]
        r = radius[k]
        bbox = sizes[k]
        tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
        bw, bh = tw + pad_x * 2, th + pad_y * 2 + 4
        spots = []          # (左上 x, 左上 y, 離した量, 置き場の順)
        for reach in (0, 34, 70, 110, 160):
            gap = r + 8 + reach
            for rank, (bx, by) in enumerate([
                    (cx + gap, cy - bh / 2), (cx - gap - bw, cy - bh / 2),
                    (cx - bw / 2, cy - gap - bh), (cx - bw / 2, cy + gap),
                    (cx + gap * 0.75, cy - gap * 0.75 - bh), (cx + gap * 0.75, cy + gap * 0.75),
                    (cx - gap * 0.75 - bw, cy - gap * 0.75 - bh), (cx - gap * 0.75 - bw, cy + gap * 0.75)]):
                spots.append((bx, by, reach, SPOT_COST[rank]))
        # 横に置いたまま1段・2段・3段ずらす（混んだところでは、札を縦に積んで線で結ぶ）
        for step in (1, -1, 2, -2, 3, -3):
            dy = step * (bh + 6)
            for side, cost in ((cx + r + 30, 30), (cx - r - 30 - bw, 31)):
                spots.append((side, cy - bh / 2 + dy, 24 + abs(step) * 26, cost))
        best = None
        for bx, by, reach, cost in spots:
            # はみ出しは枠の内側へ押し戻してから当たりを見る（押し戻した先で自分の点に重なった。
            # 10/7 の見本のペドロ）。押し戻した量は点から離れた分として数える
            dx = max(0, area[0] - bx) - max(0, bx + bw - area[2])
            dy = max(0, area[1] - by) - max(0, by + bh - area[3])
            rect = (bx + dx, by + dy, bx + dx + bw, by + dy + bh)
            outside = abs(dx) + abs(dy)
            hit_labels = sum(1 for t in taken if _overlap(rect, t, 4))
            hit_dots = sum(1 for d in dot_boxes if _overlap(rect, d, 2))
            hit_ticks = sum(1 for d in tick_boxes if _overlap(rect, d, 2))
            # 離した札を結ぶ線が、ほかの札・点を横切らないか（横切るとどの点の札か読み違える）
            crossing = 0
            if reach > 0 or outside > 8:
                ex, ey = min(max(cx, rect[0]), rect[2]), min(max(cy, rect[1]), rect[3])
                # 札は少し広げて見る（札と点のすき間を線が通っても、どちらの線か読み違えた）
                others = ([(t[0] - 12, t[1] - 8, t[2] + 12, t[3] + 8) for t in taken]
                          + [d for j, d in enumerate(dot_boxes) if j != k])
                crossing = sum(1 for box in others if _segment_hits((cx, cy), (ex, ey), box))
            # 横（右・左）を先に、上下、斜めは後に。真下に置いた長い札は隣の点の札に見えた（10/7 の見本のペドロ）。
            # 少しの押し戻しは軽く、大きな押し戻しは重く（点から離れる）。目盛りの字にかかるのは点より軽い
            score = ((outside if outside <= 14 else 400 + outside * 40)
                     + hit_labels * 5000 + hit_dots * 3000 + hit_ticks * 1500 + crossing * 2000
                     + reach * 6 + cost)
            if best is None or score < best[0]:
                best = (score, rect, reach, outside)
        _, rect, reach, moved = best
        taken.append(rect)
        places[k] = (rect, reach > 0 or moved > 8, -bbox[0], -bbox[1] + pad_y + 2)

    def draw_axes(draw, y):
        ylabel = y_axis["label"] + (f"（{y_axis['unit']}）" if y_axis["unit"] else "")
        draw.text((left, y + 4), ylabel, font=axis_font, fill=SUB)
        if legend:
            lw = ruler.textlength(legend, font=tick_font)
            lx = plot_right - lw
            _dashed(draw, (lx - 66, y + 22), (lx - 14, y + 22), DIAGONAL, 3)
            draw.text((lx, y + 8), legend, font=tick_font, fill=SUB)
        for t in y_ticks:
            yy = y + py(t)
            draw.line([(plot_left, yy), (plot_right, yy)], fill=GRID, width=1 if t != y_lo else 2)
            label = _tick_text(t)
            draw.text((plot_left - 12, yy), label, font=tick_font, fill=SUB, anchor="rm")
        for t in x_ticks:
            xx = px(t)
            draw.line([(xx, y + plot_top), (xx, y + plot_bottom)], fill=GRID, width=1 if t != x_lo else 2)
            draw.text((xx, y + plot_bottom + 8), _tick_text(t), font=tick_font, fill=SUB, anchor="ma")
        xlabel = x_axis["label"] + (f"（{x_axis['unit']}）" if x_axis["unit"] else "")
        draw.text((plot_right, y + plot_bottom + 42), xlabel, font=axis_font, fill=SUB, anchor="ra")
        if diagonal:
            lo, hi = max(x_lo, y_lo), min(x_hi, y_hi)
            _dashed(draw, (px(lo), y + py(lo)), (px(hi), y + py(hi)), DIAGONAL, 3)

    blocks = _title_block(spec, font_path)
    blocks.append({"height": 0, "draw": draw_axes})
    for k, point in enumerate(points):
        def draw_point(draw, y, k=k, point=point):
            cx, cy = dots[k]
            cy += y
            r = radius[k]
            hot = k == focus
            lit = k == highlight
            rect, linked, ox, oy = places[k]
            rx0, ry0, rx1, ry1 = rect[0], rect[1] + y, rect[2], rect[3] + y
            if linked:
                # 離した札は、どの点のものか分かるように細い線で結ぶ
                ex = min(max(cx, rx0), rx1)
                ey = min(max(cy, ry0), ry1)
                draw.line([(cx, cy), (ex, ey)], fill=LEADER, width=2)
            if lit:
                draw.ellipse([cx - r - 11, cy - r - 11, cx + r + 11, cy + r + 11], outline=BRAND_GOLD, width=5)
            color = BRAND_GOLD if hot else (DOT if (highlight is None or lit) else DOT_DIM)
            draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=color, outline=DOT_RING, width=3)
            # 札の下は板の地の色で塗る（斜めの線・目盛りの線が字を横切らない）。光らせる点は緑の札
            if lit:
                draw.rounded_rectangle([rx0, ry0, rx1, ry1], radius=10, fill=BRAND_GREEN, outline=BRAND_GOLD, width=2)
            else:
                draw.rounded_rectangle([rx0, ry0, rx1, ry1], radius=10, fill=PANEL[:3] + (255,))
            fill = BRAND_GOLD if (hot or lit) else (LABEL if highlight is None else SUB)
            draw.text((rx0 + pad_x + ox, ry0 + oy), point["name"], font=fonts[k], fill=fill, anchor="ls")

        def unit_point(y, k=k):
            cx, cy = dots[k]
            r = radius[k]
            rect = places[k][0]
            dot = (cx - r - 12, y + cy - r - 12, cx + r + 12, y + cy + r + 12)
            label = (rect[0], y + rect[1], rect[2], y + rect[3])
            return {"box": _union([dot, label]), "cells": [dot, label]}

        blocks.append({"height": 0, "draw": draw_point, "row": True, "unit": unit_point})
    blocks.append({"height": height, "draw": lambda draw, y: None})
    return blocks + _note_blocks(spec, width, font_path)


SPOT_COST = (0, 1, 24, 26, 60, 61, 62, 63)    # 札の置き場の順（右・左・上・下・右上・右下・左上・左下）


def _segment_hits(a, b, box, samples: int = 24) -> bool:
    """線分 a→b が枠 box（少し内側）を通るか。"""
    x0, y0, x1, y1 = box[0] + 2, box[1] + 2, box[2] - 2, box[3] - 2
    for i in range(1, samples):
        t = i / samples
        x, y = a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t
        if x0 < x < x1 and y0 < y < y1:
            return True
    return False


def _overlap(a, b, pad: float = 0.0) -> bool:
    return a[0] < b[2] + pad and b[0] < a[2] + pad and a[1] < b[3] + pad and b[1] < a[3] + pad


def _dashed(draw, start, end, fill, width: int, dash: float = 14.0, gap: float = 9.0) -> None:
    import math

    (x0, y0), (x1, y1) = start, end
    length = math.hypot(x1 - x0, y1 - y0)
    if length <= 0:
        return
    ux, uy = (x1 - x0) / length, (y1 - y0) / length
    t = 0.0
    while t < length:
        u = min(length, t + dash)
        draw.line([(x0 + ux * t, y0 + uy * t), (x0 + ux * u, y0 + uy * u)], fill=fill, width=width)
        t = u + gap


# ---- 換算の板


def _convert_value(value) -> dict:
    if isinstance(value, dict):
        cells = [value.get("number", ""), value.get("unit", ""), value.get("note", "")]
    elif isinstance(value, (list, tuple)):
        cells = list(value)[:3]
    else:
        cells = [value]
    cells = [str(c if c is not None else "").strip() for c in cells] + ["", "", ""]
    return {"number": cells[0], "unit": cells[1], "note": cells[2]}


def convert_values(spec: dict) -> list[dict]:
    """換算の段を {number, unit, note} の並びに（from・to か steps）。"""
    if spec.get("steps") is not None:
        return [_convert_value(v) for v in (spec.get("steps") or [])]
    return [_convert_value(spec[k]) for k in ("from", "to") if spec.get(k) is not None]


def convert_vias(spec: dict, count: int) -> list[str]:
    """段のあいだの式。1つの字なら最初のあいだ、並びなら順に。"""
    via = spec.get("via")
    if via is None or via == "":
        return [""] * max(0, count - 1)
    if isinstance(via, (list, tuple)):
        return [str(v if v is not None else "").strip() for v in via]
    return [str(via).strip()] + [""] * max(0, count - 2)


def check_convert(spec: dict) -> list[str]:
    problems = []
    unknown = sorted(str(k) for k in spec if k not in CONVERT_KEYS)
    if unknown:
        problems.append(f"convert カードに知らない鍵があります（{unknown[0]}）。"
                        f"使えるのは {'・'.join(sorted(CONVERT_KEYS))}")
    has_steps = spec.get("steps") is not None
    if has_steps and (spec.get("from") is not None or spec.get("to") is not None):
        problems.append("convert は from・to か steps のどちらか一方で書いてください")
    elif not has_steps and (spec.get("from") is None or spec.get("to") is None):
        problems.append("convert には from: [数字, 単位, 注記] と to: [数字, 単位, 注記] が必要です"
                        "（3段なら steps: [[…], […], […]]）")
    values = convert_values(spec)
    if has_steps and not 2 <= len(values) <= CONVERT_MAX:
        problems.append(f"convert の steps は2〜{CONVERT_MAX}段です（{len(values)}段）")
    for value in values:
        if not _re.search(r"[0-9０-９]", value["number"]):
            problems.append(f"convert の数字『{value['number'] or '（空）'}』に数字がありません。"
                            "[数字, 単位, 注記] の1つ目は数で書いてください")
            break
    via = spec.get("via")
    if isinstance(via, (list, tuple)):
        if len(via) != max(0, len(values) - 1):
            problems.append(f"convert の via は段のあいだの数（{max(0, len(values) - 1)}つ）にしてください（いまは{len(via)}つ）")
    elif via not in (None, "") and len(values) > 2:
        problems.append(f"convert が{len(values)}段なら via は [1段目→2段目, 2段目→3段目] の並びで書いてください")
    return problems


def via_factor(via: str) -> float | None:
    """via に書いた倍率（「×52週」「1ポンド＝195円」「÷12」）を掛け合わせた数。数が無ければ None。"""
    text = str(via or "").translate(_FULLWIDTH).replace(",", "").replace("約", "")
    factor, found = 1.0, False
    # 「1ポンド＝195円」のような為替・単位の換算
    rate = _re.compile(r"(?<![\d.])1\s*[^\d\s=＝≒・、/]+?\s*[=＝≒]\s*(\d+(?:\.\d+)?)\s*((?:[千万億兆])*)")
    for m in rate.finditer(text):
        value = float(m.group(1))
        for unit in m.group(2):
            value *= _KANJI_UNITS[unit]
        factor *= value
        found = True
    rest = rate.sub(" ", text)
    for m in _re.finditer(r"([×*＊÷])\s*(\d+(?:\.\d+)?)\s*((?:[千万億兆])*)", rest):
        value = float(m.group(2))
        for unit in m.group(3):
            value *= _KANJI_UNITS[unit]
        if value == 0:
            continue
        factor = factor / value if m.group(1) == "÷" else factor * value
        found = True
    return factor if found else None


CONVERT_TOLERANCE = 0.10    # via の倍率で計算した値と、書いた値のずれ（これより大きければ知らせる）


def convert_mismatches(spec: dict) -> list[str]:
    """via に倍率が数で書いてあれば、from × 倍率 と to を比べる（止めない。draft が知らせる）。"""
    values = convert_values(spec)
    vias = convert_vias(spec, len(values))
    out = []
    for k, via in enumerate(vias[:len(values) - 1]):
        factor = via_factor(via)
        a = amount(values[k]["number"] + values[k]["unit"])
        b = amount(values[k + 1]["number"] + values[k + 1]["unit"])
        if factor is None or a is None or not b:
            continue
        expect = a * factor
        if abs(expect - b) / abs(b) > CONVERT_TOLERANCE:
            out.append(f"{values[k]['number']}{values[k]['unit']} {via} → 計算では {_round_amount(expect)}、"
                       f"書いた値は {values[k + 1]['number']}{values[k + 1]['unit']}")
    return out


def _round_amount(value: float) -> str:
    for unit, size in (("兆", 1e12), ("億", 1e8), ("万", 1e4)):
        if abs(value) >= size:
            return f"{value / size:.3g}{unit}"
    return f"{value:.4g}"


def _convert(spec: dict, width: int, font_path: str, latin_path: str) -> list[dict]:
    """換算の板（2026-10-07 夜）。クラブの財政・移籍金・年俸を、ポンド・ユーロから円へ、週給から年俸へ。

    ```yaml
    card: {type: convert, title: 週給を円に直すと, steps: [[30万, ポンド, 週給], [1560万, ポンド, 年俸],
           [約30, 億円, 1ポンド＝約195円]], via: [×52週, ×195円]}
    ```
    左（縦の画面では上）に元の数字、右（下）に換算した数字を黄で大きく、あいだに矢印と式（via）。
    `reveal` で 元 → 矢印 → 換算 の順に出る。**換算の値は書いた人が計算する**（via に倍率が数で
    あれば draft がずれを知らせるが、止めない）。
    """
    problems = check_convert(spec)
    if problems:
        raise CardError(problems[0])
    values = convert_values(spec)
    vias = convert_vias(spec, len(values))
    n = len(values)
    wide = width >= 1050
    ruler = _ruler()
    inner = width - PAD * 2 - 24
    left = PAD + 12
    via_font = _font(font_path, 30)
    note_font = _font(font_path, 28)
    texts = [v["number"] + v["unit"] for v in values]
    blocks = _title_block(spec, font_path)

    if wide and n == 2:
        # 横に並べる（本編の2段）。矢印の幅は式の長さで（2行まで）、残りを2つの箱で等分。
        # **3段は横に並べない**：本編で写真の上に置くと板は幅900まで縮み、「1560万ポンド」が40px を切った
        lines = _wrap(vias[0], via_font, int(inner * 0.26))[:2] if vias[0] else []
        arrow_w = max(130, max((ruler.textlength(c, font=via_font) for c in lines), default=0) + 36)
        box_w = (inner - arrow_w) / 2
        room = box_w - 44
        last = fit_number(texts[1], 118, room, font_path)
        first = min(fit_number(texts[0], 92, room, font_path), last)
        sizes = [first, last]
        notes = [_wrap(v["note"], note_font, int(box_w - 32))[:2] if v["note"] else [] for v in values]
        note_h = max(len(x) for x in notes) * 38
        num_h = last + 20
        box_h = 26 + num_h + note_h + (18 if note_h else 6)
        xs = [left, left + box_w + arrow_w]

        def value_parts(k, y):
            w = number_width(texts[k], sizes[k], font_path)
            baseline = y + 26 + num_h - 22
            return xs[k] + box_w / 2 - w / 2, baseline

        for k in range(2):
            def draw_value(draw, y, k=k):
                hot = k == 1
                x0 = xs[k]
                draw.rounded_rectangle([x0, y, x0 + box_w, y + box_h], radius=16,
                                       fill=BRAND_GREEN if hot else BOX,
                                       outline=BRAND_GOLD if hot else GRID, width=4 if hot else 2)
                nx, baseline = value_parts(k, y)
                put_number(draw, nx, baseline, texts[k], sizes[k], BRAND_GOLD if hot else TEXT, font_path)
                for j, chunk in enumerate(notes[k]):
                    tw = draw.textlength(chunk, font=note_font)
                    draw.text((x0 + box_w / 2 - tw / 2, y + 26 + num_h + 4 + j * 38), chunk,
                              font=note_font, fill=TEXT if hot else SUB)

            def unit_value(y, k=k):
                nx, baseline = value_parts(k, y)
                number = _number_box(nx, baseline, texts[k], sizes[k], font_path)
                note = _union([_text_box(xs[k] + box_w / 2 - ruler.textlength(c, font=note_font) / 2,
                                         y + 26 + num_h + 4 + j * 38, c, note_font)
                               for j, c in enumerate(notes[k])])
                return {"box": (xs[k], y, xs[k] + box_w, y + box_h), "cells": [number, note]}

            # 横に並ぶので、高さは最後の箱だけが持つ（出ていない段も場所は空けておく）
            blocks.append({"height": box_h + 14 if k == 1 else 0, "draw": draw_value, "row": True,
                           "unit": unit_value})
            if k == 0:
                def draw_arrow(draw, y):
                    a0, a1 = xs[0] + box_w + 14, xs[1] - 14
                    mid = y + box_h / 2
                    draw.line([(a0, mid), (a1 - 22, mid)], fill=ARROW, width=7)
                    draw.polygon([(a1 - 28, mid - 18), (a1 - 28, mid + 18), (a1, mid)], fill=ARROW)
                    for j, chunk in enumerate(reversed(lines)):
                        tw = draw.textlength(chunk, font=via_font)
                        draw.text(((a0 + a1) / 2 - tw / 2, mid - 18 - (j + 1) * 40), chunk,
                                  font=via_font, fill=TEXT)

                blocks.append({"height": 0, "draw": draw_arrow, "row": True})
        return blocks + _note_blocks(spec, width, font_path)

    # 縦に積む（ショートと、本編の3段）。数字は左、注記は右。あいだに下向きの矢印、式は矢印の右
    room = inner - 40
    # 3段で板が画面の半分を超えないよう、縦の数字は本編の横並びより一回り小さく（ショートで顔の目元が残る高さ）
    last = fit_number(texts[-1], 112, room, font_path)
    rest = min([fit_number(t, 86, room, font_path) for t in texts[:-1]] + [last])
    sizes = [rest] * (n - 1) + [last]
    blocks_out = []
    for k in range(n):
        hot = k == n - 1
        size = sizes[k]
        num_w = number_width(texts[k], size, font_path)
        side = inner - 48 - num_w - 36
        note = values[k]["note"]
        beside = bool(note) and side >= 170
        lines = (_wrap(note, note_font, int(side))[:2] if beside else
                 (_wrap(note, note_font, int(inner - 48))[:2] if note else []))
        num_h = int(size * 1.0) + 26
        box_h = num_h + (0 if beside or not lines else len(lines) * 38 + 6) + 14

        def draw_value(draw, y, k=k, hot=hot, size=size, num_w=num_w, beside=beside, lines=lines,
                       num_h=num_h, box_h=box_h):
            draw.rounded_rectangle([left, y, left + inner, y + box_h], radius=16,
                                   fill=BRAND_GREEN if hot else BOX,
                                   outline=BRAND_GOLD if hot else GRID, width=4 if hot else 2)
            baseline = y + num_h - 14
            x0 = left + 24 if lines else left + inner / 2 - num_w / 2
            put_number(draw, x0, baseline, texts[k], size, BRAND_GOLD if hot else TEXT, font_path)
            if beside:
                top = y + (box_h - len(lines) * 38) / 2 - 2
                for j, chunk in enumerate(lines):
                    tw = draw.textlength(chunk, font=note_font)
                    draw.text((left + inner - 24 - tw, top + j * 38), chunk, font=note_font,
                              fill=TEXT if hot else SUB)
            else:
                for j, chunk in enumerate(lines):
                    draw.text((left + 24, y + num_h + j * 38), chunk, font=note_font,
                              fill=TEXT if hot else SUB)

        def unit_value(y, k=k, size=size, num_w=num_w, beside=beside, lines=lines, num_h=num_h, box_h=box_h):
            baseline = y + num_h - 14
            x0 = left + 24 if lines else left + inner / 2 - num_w / 2
            number = _number_box(x0, baseline, texts[k], size, font_path)
            if beside:
                top = y + (box_h - len(lines) * 38) / 2 - 2
                note = _union([_text_box(left + inner - 24 - ruler.textlength(c, font=note_font), top + j * 38,
                                         c, note_font) for j, c in enumerate(lines)])
            else:
                note = _union([_text_box(left + 24, y + num_h + j * 38, c, note_font) for j, c in enumerate(lines)])
            return {"box": (left, y, left + inner, y + box_h), "cells": [number, note]}

        blocks_out.append({"height": box_h + 8, "draw": draw_value, "row": True, "unit": unit_value})
        if k < n - 1:
            via = vias[k]
            cx = left + 96
            via_lines = _wrap(via, via_font, int(left + inner - (cx + 44))) if via else []
            via_lines = via_lines[:2]
            arrow_h = max(72, len(via_lines) * 40 + 24)

            def draw_arrow(draw, y, via_lines=via_lines, arrow_h=arrow_h, cx=cx):
                top, bottom = y + 4, y + arrow_h - 6
                draw.line([(cx, top), (cx, bottom - 22)], fill=ARROW, width=8)
                draw.polygon([(cx - 19, bottom - 26), (cx + 19, bottom - 26), (cx, bottom)], fill=ARROW)
                first = y + arrow_h / 2 - len(via_lines) * 40 / 2
                for j, chunk in enumerate(via_lines):
                    draw.text((cx + 44, first + j * 40), chunk, font=via_font, fill=TEXT)

            blocks_out.append({"height": arrow_h, "draw": draw_arrow, "row": True})
    return blocks + blocks_out + _note_blocks(spec, width, font_path)


# ------------------------------------------------------------------ 左右の全画面比べ（2026-10-07）

VERSUS_SIDE_KEYS = frozenset({"image", "name", "number", "note", "center", "top"})
VERSUS_BRIGHT = (88.0, 128.0)
TITLE_BAND = 86                 # 題の札の高さ（字46＋上下40）   # 2枚の明るさ（灰色の平均）をそろえる先の下限と上限


def _versus_tile(side: dict, w: int, h: int, third: float) -> Image.Image:
    """写真を w×h に切る。顔が取れれば顔を残す位置で（faces.crop_box）、取れなければ上寄り。

    `center`（顔の左右の位置、0〜1）・`top`（切り出しの上端、0〜1）を書けば顔の位置より優先する。
    """
    from . import faces
    from .config import _resolve

    path = _resolve(str(side.get("image") or ""))
    if not path.exists():
        raise CardError(f"versus の写真がありません: {side.get('image')}")
    with Image.open(path) as opened:
        photo = opened.convert("RGB")
    face = faces.main_face(photo) if faces.available() else None
    kw = {}
    if side.get("center") not in (None, ""):
        kw["center"] = float(side["center"])
    if side.get("top") not in (None, ""):
        kw["top"] = float(side["top"])
    box = faces.crop_box(photo.size, w / h, face, third=third, **kw)
    return photo.crop(box).resize((w, h), Image.LANCZOS)


def _even_brightness(tiles: list[Image.Image]) -> list[Image.Image]:
    """2枚の明るさをそろえる。片方だけ暗い・明るいと、暗いほうが負けて見える。"""
    from PIL import ImageEnhance, ImageStat

    means = [ImageStat.Stat(t.convert("L").resize((48, 48))).mean[0] for t in tiles]
    target = min(VERSUS_BRIGHT[1], max(VERSUS_BRIGHT[0], sum(means) / len(means)))
    out = []
    for tile, mean in zip(tiles, means):
        factor = max(0.55, min(1.7, target / max(mean, 1.0)))
        out.append(ImageEnhance.Color(ImageEnhance.Brightness(tile).enhance(factor)).enhance(0.92))
    return out


def _shade(tile: Image.Image, start: float, end: float, strength: int = 215,
           from_top: bool = False) -> Image.Image:
    """字を置く側を暗く落とす。**不透明の絵に合成するので白く抜けない。**"""
    w, h = tile.size
    mask = Image.new("L", (w, h), 0)
    draw = ImageDraw.Draw(mask)
    a, b = int(h * start), int(h * end)
    for y in range(h):
        t = (y - a) / max(1, b - a) if not from_top else (b - y) / max(1, b - a)
        t = max(0.0, min(1.0, t))
        draw.line([(0, y), (w, y)], fill=int(strength * t ** 1.2))
    dark = Image.new("RGB", (w, h), (6, 12, 10))
    return Image.composite(dark, tile, mask)


def render_versus(spec: dict, size: tuple[int, int], font_path: str, out_path: Path,
                  latin_font_path: str | None = None) -> Path:
    """左右の全画面比べ（2026-10-07）。画面いっぱいの不透明な絵を書き出す。

    ```yaml
    card: {type: versus, title: 代表の出場数, left: {image: …, name: ケイン, number: 112試合, note: 2015〜},
           right: {image: …, name: シルトン, number: 125試合, note: 1970〜1990}, credit: "写真: …"}
    ```
    横（本編）は左右に割り、真ん中に黄の縦線。縦（ショート）は上下に割り、真ん中に黄の横線。
    写真は顔を残す位置で切り（faces.crop_box）、2枚の明るさを自動でそろえる。
    名前と大きな数字は、横では各半分の下、縦では真ん中の線をはさんだ側（上の人は線の上、
    下の人は線の下）に置く。**縦の下端はショートの画面の題名・ボタンに隠れる**ので使わない。
    """
    width, height = size
    portrait = height > width
    sides = [spec.get("left") or {}, spec.get("right") or {}]
    for side in sides:
        if not isinstance(side, dict) or not side.get("image") or not str(side.get("name") or "").strip():
            raise CardError("versus の left・right には image と name が必要です")
    if portrait:
        tw, th = width, height // 2
        tiles = [_versus_tile(sides[0], tw, th, third=0.36), _versus_tile(sides[1], tw, th, third=0.60)]
    else:
        tw, th = width // 2, height
        tiles = [_versus_tile(s, tw, th, third=0.30) for s in sides]
    tiles = _even_brightness(tiles)
    if portrait:
        tiles = [_shade(tiles[0], 0.52, 1.0), _shade(tiles[1], 0.0, 0.46, from_top=True)]
    else:
        tiles = [_shade(t, 0.50, 0.96) for t in tiles]

    canvas = Image.new("RGBA", (width, height), (0, 0, 0, 255))
    for index, tile in enumerate(tiles):
        canvas.paste(tile.convert("RGBA"), (0, index * th) if portrait else (index * tw, 0))
    draw = ImageDraw.Draw(canvas)
    line = 10
    if portrait:
        draw.rectangle([0, th - line // 2, width, th + line // 2], fill=BRAND_GOLD)
    else:
        draw.rectangle([tw - line // 2, 0, tw + line // 2, height], fill=BRAND_GOLD)

    stroke = (6, 12, 10, 255)
    name_size = 64 if not portrait else 66
    for index, side in enumerate(sides):
        name = str(side.get("name") or "").strip()
        number = str(side.get("number") or "").strip()
        note = str(side.get("note") or "").strip()
        room = (tw if not portrait else width) - 120
        num_size = fit_number(number, 170 if not portrait else 160, room, font_path) if number else 0
        name_font = _font(font_path, name_size)
        while name_font.size > 34 and draw.textlength(name, font=name_font) > room:
            name_font = _font(font_path, name_font.size - 4)
        note_font = _font(font_path, 36)
        note = _fit_cell(draw, note, note_font, room) if note else ""
        # 字のかたまりの高さ（名前・数字・注記）
        block = name_size + 18 + (int(num_size * 0.98) if number else 0) + (54 if note else 0)
        cx = (tw / 2 + index * tw) if not portrait else width / 2
        if portrait:
            # 題の札が真ん中の線に乗るので、その上下を空ける
            gap = (TITLE_BAND // 2 + 26) if spec.get("title") else 44
            top = (th - gap - block) if index == 0 else (th + gap)
        else:
            top = height - 70 - block
        y = top
        nw = draw.textlength(name, font=name_font)
        draw.text((cx - nw / 2, y), name, font=name_font, fill=TEXT, stroke_width=5, stroke_fill=stroke)
        y += name_size + 18
        if number:
            w = number_width(number, num_size, font_path)
            put_number(draw, cx - w / 2, y + num_size * 0.86, number, num_size, BRAND_GOLD, font_path,
                       stroke=6, stroke_fill=stroke)
            y += int(num_size * 0.98)
        if note:
            tw_note = draw.textlength(note, font=note_font)
            draw.text((cx - tw_note / 2, y + 8), note, font=note_font, fill=(225, 230, 236, 255),
                      stroke_width=3, stroke_fill=stroke)

    title = str(spec.get("title") or "").strip()
    if title:
        title_font = _font(font_path, 46)
        tw_title = draw.textlength(title, font=title_font)
        while title_font.size > 28 and tw_title + 80 > width - 80:
            title_font = _font(font_path, title_font.size - 2)
            tw_title = draw.textlength(title, font=title_font)
        # 横は上の真ん中（2人の顔のあいだ）。**縦は真ん中の線の上**（上端に置くと上の人の顔にかかった。
        # 10/7 の見本でケインの額に乗った。ショートの上端は画面の操作ボタンにも隠れる）
        band = title_font.size + 40
        top = 44 if not portrait else th - band // 2
        box = [width / 2 - tw_title / 2 - 40, top, width / 2 + tw_title / 2 + 40, top + band]
        draw.rounded_rectangle(box, radius=16, fill=BRAND_GREEN, outline=BRAND_GOLD, width=3)
        draw.text((width / 2, (box[1] + box[3]) / 2), title, font=title_font, fill=BRAND_GOLD, anchor="mm")
    credit = str(spec.get("credit") or "").strip()
    if credit:
        credit_font = _font(font_path, 22)
        cw = draw.textlength(credit, font=credit_font)
        # 右下に小さく（写真の表示は概要欄にも出す。ショートでは下の操作の帯に隠れてよい）
        y = height - 34
        draw.text((width - 24 - cw, y), credit, font=credit_font, fill=(200, 206, 214, 255),
                  stroke_width=2, stroke_fill=stroke)

    out_path.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(out_path)
    return out_path


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

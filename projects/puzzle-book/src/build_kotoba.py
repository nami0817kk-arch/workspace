"""ことば探しの本（KDP ペーパーバック）の本文PDFと表紙PDFを組む。

盤面の生成と検証は `libs/puzzle-generator` の `build_wordsearch`。ここは紙面だけ。
判型・余白・フォント・ページ送りは迷路本（build_book.py）と共通のものを使う。

設計書は `books/kotoba-*.json`。テーマごとに語の一覧・難易度・文字の種類を持つ。
`ink` が "premium" なら本文をカラーで組む（A4 は KDP の標準カラーが使えず、プレミアムカラーのみ）。
色はすべて CMYK で指定する。透明度は使わない（KDP は透過の結合を求める）。
"""

from __future__ import annotations

import argparse
import io
import json
import zlib
from dataclasses import dataclass
from pathlib import Path

from puzzle_generator import DIRS, build_wordsearch, validate_record
from reportlab.lib.units import inch
from reportlab.lib.colors import CMYKColor
from reportlab.lib.utils import ImageReader
from reportlab.pdfgen import canvas

import kdp_spec
from build_book import DIFFICULTY_LABEL_JA, DIFFICULTY_STARS, FONT_BOLD, FONT_REGULAR, _Pager
from build_cover import CREAM, NAVY, ORANGE, WHITE
from art import FONT_ROUNDED, ICON_CREDIT, draw_icon, outlined_text

ANSWERS_PER_PAGE = 4
# 矢印の字形（↘など）は同梱フォントに無いものがあるので、向きは言葉で書く
DIR_WORDS = {"E": "よこ（左から右へ）", "S": "たて（上から下へ）", "SE": "ななめ（左上から右下へ）"}
_COVER_SEED_OFFSET = 9_000_000  # 表紙の見本は本文と別の盤面にする（問題1の答えを表紙で見せない）

CMYK = tuple[float, float, float, float]
BLACK: CMYK = (0, 0, 0, 1)


@dataclass(frozen=True)
class Palette:
    """紙面の色。白黒の本では同じ役割の灰色に置き換わる。"""

    main: dict[str, CMYK]  # 難易度ごとの濃い色（帯・見出し・外枠）
    tint: dict[str, CMYK]  # 難易度ごとの淡い色（盤面の地）
    answers: list[CMYK]  # 答えの帯。語ごとに色を変える
    line: CMYK  # 盤面の罫線
    accent: CMYK  # 表題・遊び方の見出し


COLOR = Palette(
    main={"easy": (0.70, 0.0, 0.80, 0.10), "medium": (0.0, 0.60, 0.95, 0.0), "hard": (0.90, 0.55, 0.0, 0.10)},
    tint={"easy": (0.10, 0.0, 0.14, 0.0), "medium": (0.0, 0.08, 0.16, 0.0), "hard": (0.12, 0.05, 0.0, 0.0)},
    answers=[
        (0.0, 0.05, 0.55, 0.0),  # 黄
        (0.0, 0.35, 0.05, 0.0),  # 桃
        (0.35, 0.0, 0.05, 0.0),  # 水
        (0.30, 0.0, 0.45, 0.0),  # 若草
        (0.22, 0.25, 0.0, 0.0),  # 藤
        (0.0, 0.25, 0.40, 0.0),  # 杏
        (0.0, 0.18, 0.12, 0.0),  # 薄紅
        (0.30, 0.0, 0.22, 0.0),  # 青磁
        (0.10, 0.32, 0.0, 0.0),  # 薄紫
        (0.22, 0.08, 0.0, 0.0),  # 空
    ],
    line=(0.0, 0.0, 0.0, 0.0),  # 色つきの地に白い罫線
    accent=NAVY,
)
GRAY = Palette(
    main={d: (0, 0, 0, 0.85) for d in ("easy", "medium", "hard")},
    tint={d: (0, 0, 0, 0.0) for d in ("easy", "medium", "hard")},
    answers=[(0, 0, 0, 0.28)],
    line=(0, 0, 0, 0.25),
    accent=BLACK,
)


@dataclass
class KotobaSpec:
    title: str
    subtitle: str
    themes: list[dict]
    seed_start: int
    trim: str = "a4"
    publisher: str = "つるはし社"
    edition_date: str = ""
    ink: str = "black"  # "black" か "premium"（プレミアムカラー）
    cover_theme: str = ""  # 表紙の見本に使うテーマ（省略時は最初のテーマ）
    preview_themes: tuple[str, ...] = ()  # 裏表紙の見本ページ（2つ）

    def theme_index(self, name: str, default: int = 0) -> int:
        for i, t in enumerate(self.themes):
            if t["theme"] == name:
                return i
        return default

    @classmethod
    def load(cls, path: str | Path) -> "KotobaSpec":
        return cls(**json.loads(Path(path).read_text(encoding="utf-8")))

    @property
    def puzzle_count(self) -> int:
        return len(self.themes)

    @property
    def palette(self) -> Palette:
        return COLOR if self.ink == "premium" else GRAY


def generate_puzzles(spec: KotobaSpec) -> list[dict]:
    order = {"easy": 0, "medium": 1, "hard": 2}
    ranks = [order[t["difficulty"]] for t in spec.themes]
    if ranks != sorted(ranks):
        raise ValueError("テーマはやさしい順に並べること")
    return [
        build_wordsearch(t["words"], t["difficulty"], theme_seed(spec, t), theme=t["theme"], script=t["script"])
        for t in spec.themes
    ]


def theme_seed(spec: KotobaSpec, theme: dict) -> int:
    """テーマ名から決まる乱数の種。並べ替えても同じテーマは同じ盤面になる。"""
    return spec.seed_start + zlib.crc32(theme["theme"].encode("utf-8")) % 100_000


def difficulty_score(record: dict) -> float:
    """同じ難易度の中での解きにくさの目安。語の文字数の合計と、ななめの語の数で見る。"""
    placements = record["solution"]["placements"]
    return sum(len(p["answer"]) for p in placements) + 3 * sum(p["dir"] == "SE" for p in placements)


def page_count(spec: KotobaSpec) -> int:
    front = 3  # 表題・遊び方・もくじ
    back = 2  # できたこと記録・奥付
    total = front + spec.puzzle_count + -(-spec.puzzle_count // ANSWERS_PER_PAGE) + back
    return total + (total % 2)


# --- 盤面の描画 -------------------------------------------------------------


def draw_grid(
    c: canvas.Canvas,
    record: dict,
    *,
    x: float,
    y: float,
    w: float,
    show_answer: bool,
    palette: Palette,
    bold: bool = True,
) -> float:
    """(x, y) を左上とする幅 w の正方形に盤面を描き、盤面の高さを返す。"""
    board = record["board"]
    size = board["size"]
    cell = w / size
    top = y
    d = record["difficulty"]

    c.saveState()
    # 地の色
    c.setFillColorCMYK(*palette.tint[d])
    c.rect(x, top - size * cell, size * cell, size * cell, stroke=0, fill=1)

    if show_answer:
        # 答えの語を太い帯で囲む。語ごとに色を変え、重なっても見分けられるようにする
        c.setLineCap(1)
        c.setLineWidth(cell * 0.78)
        for k, p in enumerate(record["solution"]["placements"]):
            c.setStrokeColorCMYK(*palette.answers[k % len(palette.answers)])
            dx, dy = DIRS[p["dir"]]
            sx, sy = p["start"]
            n = len(p["answer"]) - 1
            x1, y1 = x + (sx + 0.5) * cell, top - (sy + 0.5) * cell
            x2, y2 = x + (sx + dx * n + 0.5) * cell, top - (sy + dy * n + 0.5) * cell
            c.line(x1, y1, x2, y2)

    c.setStrokeColorCMYK(*palette.line)
    c.setLineWidth(max(kdp_spec.MIN_LINE_PT, cell * 0.03))
    for i in range(1, size):
        c.line(x + i * cell, top, x + i * cell, top - size * cell)
        c.line(x, top - i * cell, x + size * cell, top - i * cell)
    c.setStrokeColorCMYK(*palette.main[d])
    c.setLineWidth(max(kdp_spec.MIN_LINE_PT, cell * 0.05))
    c.rect(x, top - size * cell, size * cell, size * cell, stroke=1, fill=0)

    c.setFillColorCMYK(*BLACK)
    fs = cell * 0.62
    c.setFont(FONT_BOLD if bold else FONT_REGULAR, fs)
    for gy, row in enumerate(board["grid"]):
        for gx, ch in enumerate(row):
            c.drawCentredString(x + (gx + 0.5) * cell, top - (gy + 0.5) * cell - fs * 0.36, ch)
    c.restoreState()
    return size * cell


def _header_band(
    c: canvas.Canvas, left: float, right: float, top: float, color: CMYK, left_text: str, right_text: str
) -> float:
    """ページ上端の色帯。帯の下端の y を返す。"""
    h = 34
    c.saveState()
    c.setFillColorCMYK(*color)
    c.roundRect(left, top - h, right - left, h, 8, stroke=0, fill=1)
    c.setFillColorCMYK(*WHITE)
    c.setFont(FONT_BOLD, 20)
    c.drawString(left + 14, top - h + 10, left_text)
    c.setFont(FONT_REGULAR, 15)
    c.drawRightString(right - 14, top - h + 11, right_text)
    c.restoreState()
    return top - h


def _draw_label(c: canvas.Canvas, label: str, x: float, y: float, room: float, fs: float) -> None:
    """語の一覧の1語。読み（かな）は大きいまま、かっこの漢字だけを小さくして幅に収める。"""
    reading, sep, rest = label.partition("（")
    note = sep + rest
    w_read = c.stringWidth(reading, FONT_REGULAR, fs)
    note_fs = fs
    if note:
        note_fs = min(fs, max(10, fs * (room - w_read) / max(1, c.stringWidth(note, FONT_REGULAR, fs))))
    total = w_read + (c.stringWidth(note, FONT_REGULAR, note_fs) if note else 0)
    scale = min(1.0, room / total) if total else 1.0  # それでも入らなければ全体を縮める
    c.setFont(FONT_REGULAR, fs * scale)
    c.drawString(x, y, reading)
    if note:
        c.setFont(FONT_REGULAR, note_fs * scale)
        c.drawString(x + w_read * scale, y, note)


def draw_problem_page(
    c: canvas.Canvas,
    record: dict,
    number: int,
    icon: str | None,
    *,
    left: float,
    right: float,
    top: float,
    bottom: float,
    palette: Palette,
    talk: str = "",
) -> None:
    """問題1ページ分。本文と、裏表紙の見本の両方で使う。

    talk は「思い出トーク」（解いたあとの会話のきっかけ）。介護の現場の回想の問いかけとして使える。
    """
    pal = palette
    d = record["difficulty"]
    mid = (left + right) / 2
    band_bottom = _header_band(c, left, right, top, pal.main[d], f"問題 {number}", f"{DIFFICULTY_STARS[d]} {DIFFICULTY_LABEL_JA[d]}")
    title = f"テーマ　{record['board']['theme']}"
    c.setFillColorCMYK(*pal.main[d])
    c.setFont(FONT_BOLD, 26)
    tw_ = c.stringWidth(title, FONT_BOLD, 26)
    icon_size = 34 if icon else 0
    tx = mid - (tw_ + icon_size + (8 if icon else 0)) / 2
    if icon:
        draw_icon(c, icon, tx, band_bottom - 46, icon_size)
    c.drawString(tx + icon_size + (8 if icon else 0), band_bottom - 38, title)

    labels = [w["label"] for w in record["board"]["words"]]
    cols = _word_columns(labels)
    rows = -(-len(labels) // cols)
    word_fs = 19
    list_h = rows * word_fs * 1.75 + 10
    talk_h = 50 if talk else 0
    grid_top = band_bottom - 60
    avail_h = grid_top - (bottom + 30 + list_h + talk_h + 20)
    gw = min(right - left, avail_h)
    gx = mid - gw / 2
    gh = draw_grid(c, record, x=gx, y=grid_top, w=gw, show_answer=False, palette=pal)

    ly = grid_top - gh - 30
    # 語の一覧は盤面の幅ではなくページの幅を使う（長い語が隣の列にはみ出さないように）
    list_w = max(gw, min(right - left, gw + 120))
    list_x = mid - list_w / 2
    col_w = list_w / cols
    c.setLineWidth(1.4)
    for k, label in enumerate(labels):
        col, row = k // rows, k % rows
        lx = list_x + col * col_w
        yy = ly - row * word_fs * 1.75
        c.setStrokeColorCMYK(*pal.main[d])
        c.setFillColorCMYK(*WHITE)
        c.roundRect(lx, yy - 2, word_fs * 0.8, word_fs * 0.8, 2, stroke=1, fill=1)
        c.setFillColorCMYK(*BLACK)
        _draw_label(c, label, lx + word_fs * 1.2, yy, col_w - word_fs * 1.2 - 10, word_fs)
    if talk:
        # 思い出トーク: 淡い地の吹き出し
        ty = ly - rows * word_fs * 1.75 - 18
        bh = 38
        c.setFillColorCMYK(*(pal.tint[d] if pal is COLOR else (0, 0, 0, 0.06)))
        c.roundRect(list_x, ty - bh + 14, list_w, bh, 10, stroke=0, fill=1)
        draw_icon(c, "1f4ac", list_x + 10, ty - bh + 21, 24)
        c.setFillColorCMYK(*pal.main[d])
        c.setFont(FONT_ROUNDED, 14)
        c.drawString(list_x + 42, ty - 6, "思い出トーク")
        c.setFillColorCMYK(*BLACK)
        room = list_w - 142 - 12
        c.setFont(FONT_REGULAR, min(16, 16 * room / c.stringWidth(talk, FONT_REGULAR, 16)))
        c.drawString(list_x + 142, ty - 7, talk)
    c.setFont(FONT_REGULAR, 12)
    c.drawString(left, bottom + 6, f"見つけた数　　　／{len(labels)}語")
    c.drawRightString(right - 62, bottom + 6, "できた日　　月　　日　　かかった時間　　　分")
    # はなまる用の丸（ぜんぶ見つけたら、ここに花丸を）
    c.setStrokeColorCMYK(*pal.main[d])
    c.setLineWidth(1.2)
    c.setDash(3, 3)
    c.circle(right - 24, bottom + 14, 22, stroke=1, fill=0)
    c.setDash()
    c.setFillColorCMYK(*pal.main[d])
    c.setFont(FONT_REGULAR, 7)
    c.drawCentredString(right - 24, bottom + 11, "はなまる")


def _word_columns(labels: list[str]) -> int:
    return 2 if len(labels) > 5 else 1


def _draw_howto_example(c: canvas.Canvas, left: float, top: float, width: float, pal: Palette) -> None:
    """遊び方の見本。小さな盤面で「さくら」を囲んだところを見せる。"""
    grid = [list("かさくらね"), list("もりのみた"), list("すなはしい"), list("めぬきとる"), list("そおあけに")]
    rec = {
        "difficulty": "easy",
        "board": {"size": 5, "grid": grid},
        "solution": {"placements": [{"answer": "さくら", "start": [1, 0], "dir": "E"}]},
    }
    size = 150
    c.setFillColorCMYK(*pal.accent)
    c.setFont(FONT_BOLD, 17)
    c.drawString(left, top, "れい")
    draw_grid(c, rec, x=left, y=top - 12, w=size, show_answer=True, palette=pal)
    c.setFillColorCMYK(*BLACK)
    c.setFont(FONT_REGULAR, 16)
    tx = left + size + 30
    c.drawString(tx, top - 50, "「さくら」は、いちばん上の行に")
    c.drawString(tx, top - 76, "左から右へならんでいます。")
    c.drawString(tx, top - 102, "見つけたら、このように丸でかこみます。")
    c.setStrokeColorCMYK(*pal.main["easy"])
    c.setLineWidth(1.4)
    c.roundRect(tx, top - 136, 16, 16, 2, stroke=1, fill=0)
    c.line(tx + 3, top - 128, tx + 7, top - 133)
    c.line(tx + 7, top - 133, tx + 14, top - 122)
    c.drawString(tx + 24, top - 134, "さくら　← 一覧にもしるしを")


def _draw_record_sheet(c: canvas.Canvas, pg: _Pager, spec: KotobaSpec, puzzles: list[dict], pal: Palette) -> None:
    """できたこと記録。60問を3列に並べ、できた日を書きこめるようにする。"""
    top = pg.page_h - pg.top
    c.setFillColorCMYK(*pal.accent)
    c.setFont(FONT_ROUNDED, 26)
    c.drawString(pg.left, top - 30, "できたこと記録")
    c.setStrokeColorCMYK(*pal.accent)
    c.setLineWidth(2)
    c.line(pg.left, top - 42, pg.right, top - 42)
    c.setFillColorCMYK(*BLACK)
    c.setFont(FONT_REGULAR, 12)
    c.drawString(pg.left, top - 64, "できた日を書きこみましょう。ぜんぶうまったら、ご自分に花丸を。")
    cols = 3
    per_col = -(-len(puzzles) // cols)
    col_w = pg.content_w / cols
    row_h = min(28, (top - 90 - pg.bottom - 10) / per_col)
    for i, record in enumerate(puzzles):
        col, row = i // per_col, i % per_col
        x0 = pg.left + col * col_w
        yy = top - 96 - row * row_h
        d = record["difficulty"]
        c.setFillColorCMYK(*pal.tint[d] if spec.ink == "premium" else (0, 0, 0, 0.06))
        c.roundRect(x0 + 2, yy - 7, col_w - 8, row_h - 4, 4, stroke=0, fill=1)
        c.setFillColorCMYK(*pal.main[d])
        c.setFont(FONT_BOLD, 11)
        c.drawString(x0 + 8, yy, f"{i + 1}")
        c.setFillColorCMYK(*BLACK)
        theme = record["board"]["theme"]
        room = col_w - 28 - 70  # 「月　日」の欄を残す
        c.setFont(FONT_REGULAR, min(10, 10 * room / c.stringWidth(theme, FONT_REGULAR, 10)))
        c.drawString(x0 + 28, yy, theme)
        c.setFont(FONT_REGULAR, 10)
        c.drawRightString(x0 + col_w - 12, yy, "月　　日")


def build_pdf(puzzles: list[dict], output_path: str, spec: KotobaSpec) -> int:
    for r in puzzles:
        validate_record(r)
    if len(puzzles) != spec.puzzle_count:
        raise ValueError("問題数が設計書と違う")
    trim = kdp_spec.TRIMS[spec.trim]
    total = page_count(spec)
    if total < kdp_spec.MIN_PAGES:
        raise ValueError(f"KDP の最小ページ数 {kdp_spec.MIN_PAGES} に足りない: {total}")
    pal = spec.palette

    c = canvas.Canvas(output_path, pagesize=(trim.width_in * inch, trim.height_in * inch))
    c.setTitle(spec.title)
    c.setAuthor(spec.publisher)
    c.setCreator(spec.publisher)
    pg = _Pager(c, trim, total)
    mid = lambda: (pg.left + pg.right) / 2  # noqa: E731

    # 1. 表題
    # 表紙と同じ題字（丸ゴシック）。白黒の本では色を黒に置き換える
    title_main, _, count = spec.title.rpartition(" ")
    lead, _, main_word = (title_main or spec.title).partition(" ")
    if not main_word:
        lead, main_word = "", title_main or spec.title
    c.setFillColorCMYK(*(ORANGE if spec.ink == "premium" else BLACK))
    if lead:
        c.setFont(FONT_ROUNDED, 44)
        c.drawCentredString(mid(), pg.page_h * 0.66, lead)
    c.setFillColorCMYK(*pal.accent)
    c.setFont(FONT_ROUNDED, min(84, pg.content_w / max(1, len(main_word))))
    c.drawCentredString(mid(), pg.page_h * 0.66 - 96, main_word)
    c.setFont(FONT_BOLD, 18)
    c.drawCentredString(mid(), pg.page_h * 0.66 - 140, f"全{count}　{spec.subtitle}" if count else spec.subtitle)
    if any(t.get("icon") for t in spec.themes):
        row = ["1f338", "1f33b", "1f341", "26c4", "1f361"]
        size = 46
        x0 = mid() - (len(row) * size + (len(row) - 1) * 20) / 2
        for k, code in enumerate(row):
            draw_icon(c, code, x0 + k * (size + 20), pg.page_h * 0.66 - 230, size)
    c.setFillColorCMYK(*BLACK)
    c.setFont(FONT_REGULAR, 14)
    c.drawCentredString(mid(), pg.page_h * 0.18, spec.publisher)
    pg.next(folio=False)

    # 2. 遊び方
    top = pg.page_h - pg.top
    c.setFillColorCMYK(*pal.accent)
    c.setFont(FONT_BOLD, 28)
    c.drawString(pg.left, top - 30, "遊び方")
    c.setStrokeColorCMYK(*pal.accent)
    c.setLineWidth(2)
    c.line(pg.left, top - 42, pg.right, top - 42)
    c.setFillColorCMYK(*BLACK)
    lines = [
        "ます目の中から、下にならんだ言葉をさがして",
        "えんぴつで丸でかこんでください。",
        "見つけた言葉は、□にしるしをつけましょう。",
        "",
        "言葉がならぶ向きは、次のとおりです。",
    ]
    y = top - 90
    c.setFont(FONT_REGULAR, 19)
    for line in lines:
        c.drawString(pg.left, y, line)
        y -= 31
    used: list[str] = []
    for t in spec.themes:
        if t["difficulty"] not in used:
            used.append(t["difficulty"])
    for d in used:
        dirs = {"easy": ["E", "S"], "medium": ["E", "S"], "hard": ["E", "S", "SE"]}[d]
        c.setFillColorCMYK(*pal.main[d])
        c.setFont(FONT_BOLD, 19)
        c.drawString(pg.left + 20, y, f"{DIFFICULTY_STARS[d]} {DIFFICULTY_LABEL_JA[d]}")
        c.setFillColorCMYK(*BLACK)
        c.setFont(FONT_REGULAR, 19)
        y -= 27
        c.drawString(pg.left + 60, y, "・".join(DIR_WORDS[x] for x in dirs[:2]))
        y -= 27
        if len(dirs) > 2:
            c.drawString(pg.left + 60, y, "・" + "・".join(DIR_WORDS[x] for x in dirs[2:]))
            y -= 27
    y -= 10
    c.drawString(pg.left, y, "逆向き（右から左・下から上）には、ならんでいません。")
    y -= 31
    c.drawString(pg.left, y, "答えは本のうしろにまとめてあります。")
    if any(t.get("talk") for t in spec.themes):
        y -= 31
        c.drawString(pg.left, y, "ページの下の「思い出トーク」は、")
        y -= 27
        c.drawString(pg.left, y, "解いたあとの会話のきっかけにどうぞ。")
    y -= 34
    _draw_howto_example(c, pg.left, y, pg.content_w, pal)
    pg.next()

    # 2b. もくじ（テーマで選んで解けるように）
    first_page = pg.number + 1
    top = pg.page_h - pg.top
    c.setFillColorCMYK(*pal.accent)
    c.setFont(FONT_BOLD, 28)
    c.drawString(pg.left, top - 30, "もくじ")
    c.setStrokeColorCMYK(*pal.accent)
    c.setLineWidth(2)
    c.line(pg.left, top - 42, pg.right, top - 42)
    per_col = -(-len(puzzles) // 2)
    col_w = pg.content_w / 2
    row_h = min(24, (top - 70 - pg.bottom - 10) / per_col)
    for i, record in enumerate(puzzles):
        col, row = i // per_col, i % per_col
        x0 = pg.left + col * col_w
        yy = top - 70 - row * row_h
        d = record["difficulty"]
        c.setFillColorCMYK(*pal.main[d])
        c.circle(x0 + 5, yy + 4.5, 4.5, stroke=0, fill=1)
        c.setFillColorCMYK(*BLACK)
        c.setFont(FONT_REGULAR, 13)
        c.drawString(x0 + 16, yy, f"{i + 1:>2}")
        if spec.themes[i].get("icon"):
            draw_icon(c, spec.themes[i]["icon"], x0 + 38, yy - 3, 15)
        c.drawString(x0 + 58, yy, record["board"]["theme"])
        c.drawRightString(x0 + col_w - 40, yy, str(first_page + i))
        c.setStrokeColorCMYK(*pal.main[d])
        c.setLineWidth(1)
        c.roundRect(x0 + col_w - 32, yy - 2, 12, 12, 2, stroke=1, fill=0)
    c.setFillColorCMYK(*BLACK)
    c.setFont(FONT_REGULAR, 11)
    c.drawRightString(pg.right, top - 30, "できた問題は□にしるしを")
    legend_y = pg.bottom + 4
    lx = pg.left
    for d in ("easy", "medium", "hard"):
        c.setFillColorCMYK(*pal.main[d])
        c.circle(lx + 5, legend_y + 4, 4.5, stroke=0, fill=1)
        c.setFillColorCMYK(*BLACK)
        label = DIFFICULTY_LABEL_JA[d]
        c.drawString(lx + 14, legend_y, label)
        lx += 30 + len(label) * 12
    pg.next()

    # 3. 問題（1ページ1問）
    for i, record in enumerate(puzzles, start=1):
        draw_problem_page(
            c, record, i, spec.themes[i - 1].get("icon"),
            left=pg.left, right=pg.right, top=pg.page_h - pg.top, bottom=pg.bottom, palette=pal,
            talk=spec.themes[i - 1].get("talk", ""),
        )
        pg.next()

    # 4. 答え（1ページ4問）
    gap = 0.35 * inch
    for start in range(0, len(puzzles), ANSWERS_PER_PAGE):
        chunk = puzzles[start : start + ANSWERS_PER_PAGE]
        band_bottom = _header_band(
            c, pg.left, pg.right, pg.page_h - pg.top, pal.accent, "答え", f"問題 {start + 1}〜{start + len(chunk)}"
        )
        cw = (pg.content_w - gap) / 2
        area_top = band_bottom - 16
        ch = (area_top - (pg.bottom + 20) - gap) / 2
        for k, record in enumerate(chunk):
            col, row = k % 2, k // 2
            bx = pg.left + col * (cw + gap)
            by_top = area_top - row * (ch + gap)
            c.setFillColorCMYK(*pal.main[record["difficulty"]])
            c.setFont(FONT_BOLD, 12)
            icon = spec.themes[start + k].get("icon")
            if icon:
                draw_icon(c, icon, bx, by_top - 15, 15)
            c.drawString(bx + (19 if icon else 0), by_top - 12, f"問題 {start + k + 1}　{record['board']['theme']}")
            side = min(cw, ch - 24)
            draw_grid(
                c, record, x=bx + (cw - side) / 2, y=by_top - 20, w=side, show_answer=True, palette=pal, bold=True
            )
        pg.next()

    # 5. できたこと記録（全問の一覧に、できた日を書きこむ）。白ページで偶数にそろえ、奥付
    _draw_record_sheet(c, pg, spec, puzzles, pal)
    pg.next()
    while pg.number < total:
        pg.next(folio=False)
    c.setFillColorCMYK(*BLACK)
    y = pg.bottom + 190
    c.setFont(FONT_BOLD, 16)
    c.drawString(pg.left, y, spec.title)
    c.setFont(FONT_REGULAR, 11)
    y -= 26
    if spec.edition_date:
        c.drawString(pg.left, y, f"{spec.edition_date}　初版発行")
        y -= 20
    c.drawString(pg.left, y, f"発行　{spec.publisher}")
    y -= 20
    year = spec.edition_date[:4] if spec.edition_date[:4].isdigit() else ""
    c.drawString(pg.left, y, " ".join(t for t in ("Copyright", year, spec.publisher) if t))
    if any(t.get("icon") for t in spec.themes):
        y -= 20
        c.setFont(FONT_REGULAR, 9)
        c.drawString(pg.left, y, ICON_CREDIT)
    pg.next(folio=False)
    c.save()
    return total


# --- 表紙 ------------------------------------------------------------------


def _page_preview(spec: KotobaSpec, puzzles: list[dict], idx: int, width_pt: float, dpi: int = 300) -> ImageReader:
    """問題ページ1枚を、表紙に貼る CMYK の画像にする（印刷で dpi になる解像度）。"""
    import pypdfium2

    trim = kdp_spec.TRIMS[spec.trim]
    page_w, page_h = trim.width_in * inch, trim.height_in * inch
    buf = io.BytesIO()
    pc = canvas.Canvas(buf, pagesize=(page_w, page_h))
    m = 0.6 * inch
    draw_problem_page(pc, puzzles[idx], idx + 1, spec.themes[idx].get("icon"),
                      left=m, right=page_w - m, top=page_h - m, bottom=m, palette=spec.palette,
                      talk=spec.themes[idx].get("talk", ""))
    pc.save()
    pdf = pypdfium2.PdfDocument(buf.getvalue())
    scale = dpi / 72 * (width_pt / page_w)
    img = pdf[0].render(scale=scale).to_pil().convert("CMYK")
    out = io.BytesIO()
    img.save(out, "JPEG", quality=95)
    out.seek(0)
    return ImageReader(out)


def _seal(c: canvas.Canvas, cx: float, cy: float, r: float, color: CMYK, lines: list[str]) -> None:
    """丸い札（表紙の売り文句）。白い縁で囲む。"""
    c.setFillColorCMYK(*WHITE)
    c.circle(cx, cy, r + 4, stroke=0, fill=1)
    c.setFillColorCMYK(*color)
    c.circle(cx, cy, r, stroke=0, fill=1)
    c.setFillColorCMYK(*WHITE)
    fs = r * 0.42 if len(lines) > 1 else r * 0.5
    c.setFont(FONT_ROUNDED, fs)
    y0 = cy + (len(lines) - 1) * fs * 0.6 - fs * 0.36
    for k, line in enumerate(lines):
        c.drawCentredString(cx, y0 - k * fs * 1.2, line)


def build_cover(spec: KotobaSpec, puzzles: list[dict], output_path: str, *, paper: str = "white") -> tuple[float, float]:
    """表紙（裏表紙・背・表表紙を1枚）。

    Amazon の検索結果では表紙が小さく出るので、題字を大きく、売りは丸い札で。
    絵は Noto Emoji の図版（art.py）。見本の盤面は本文と別の盤面にする。
    """
    pages = page_count(spec)
    trim = kdp_spec.TRIMS[spec.trim]
    spine = kdp_spec.spine_width_in(pages, paper, spec.ink)
    bleed = kdp_spec.COVER_BLEED_IN
    total_w, total_h = bleed * 2 + trim.width_in * 2 + spine, bleed * 2 + trim.height_in
    W, H = total_w * inch, total_h * inch
    tw, th, sp, b = trim.width_in * inch, trim.height_in * inch, spine * inch, bleed * inch
    safe = kdp_spec.COVER_SAFE_IN * inch
    warm: CMYK = (0.0, 0.05, 0.20, 0.0)
    red: CMYK = (0.0, 0.85, 0.75, 0.0)
    green: CMYK = (0.70, 0.0, 0.80, 0.10)
    blue: CMYK = (0.90, 0.55, 0.0, 0.10)
    shadow: CMYK = (0.0, 0.10, 0.25, 0.12)  # 影は濃い地色で描く（透明度は使わない）

    c = canvas.Canvas(output_path, pagesize=(W, H))
    c.setTitle(f"{spec.title}（表紙）")
    c.setAuthor(spec.publisher)
    c.setFillColorCMYK(*warm)
    c.rect(0, 0, W, H, stroke=0, fill=1)
    spine_x0, fx = b + tw, b + tw + sp
    cx = fx + tw / 2
    top = b + th

    # --- 背 ---
    c.setFillColorCMYK(*NAVY)
    c.rect(spine_x0, 0, sp, H, stroke=0, fill=1)
    usable = sp - 2 * kdp_spec.SPINE_TEXT_SIDE_MARGIN_IN * inch
    spine_font = min(usable * 0.8, 14)
    if pages >= kdp_spec.SPINE_TEXT_MIN_PAGES and spine_font >= 9:
        c.saveState()
        c.setFillColorCMYK(*WHITE)
        c.translate(spine_x0 + sp / 2, b + th / 2)
        c.rotate(-90)
        c.setFont(FONT_BOLD, spine_font)
        c.drawCentredString(0, -spine_font / 3, f"{spec.title}　{spec.publisher}")
        c.restoreState()

    # --- 表表紙 ---
    # 飾りの淡い円（地に奥行きを出す）
    c.setFillColorCMYK(0.0, 0.10, 0.32, 0.0)
    c.circle(fx + tw * 0.92, top - th * 0.06, tw * 0.28, stroke=0, fill=1)
    c.circle(fx + tw * 0.05, b + th * 0.30, tw * 0.22, stroke=0, fill=1)

    title_main, _, count = spec.title.rpartition(" ")
    title_main = title_main or spec.title
    lead, _, main_word = title_main.partition(" ")
    if not main_word:
        lead, main_word = "", title_main

    cap = "なつかしい言葉で、会話がはずむ"
    cap_y = top - 0.80 * inch
    c.setFillColorCMYK(*NAVY)
    c.setFont(FONT_BOLD, 20)
    c.drawCentredString(cx, cap_y, cap)
    cap_w = c.stringWidth(cap, FONT_BOLD, 20)
    c.setStrokeColorCMYK(*NAVY)
    c.setLineWidth(2)
    c.line(cx - cap_w / 2 - 40, cap_y + 7, cx - cap_w / 2 - 12, cap_y + 7)
    c.line(cx + cap_w / 2 + 12, cap_y + 7, cx + cap_w / 2 + 40, cap_y + 7)

    white = CMYKColor(0, 0, 0, 0)
    if lead:
        outlined_text(c, lead, cx, top - 1.85 * inch, font=FONT_ROUNDED, size=62,
                      fill=CMYKColor(*ORANGE), outline=white, outline_width=10)
    main_size = min(108, (tw - 2 * safe - 30) / max(1, len(main_word)))
    outlined_text(c, main_word, cx, top - 3.30 * inch, font=FONT_ROUNDED, size=main_size,
                  fill=CMYKColor(*NAVY), outline=white, outline_width=14)

    # 副題のリボン
    rib_w, rib_h = tw * 0.78, 42
    rib_y = top - 4.05 * inch
    c.setFillColorCMYK(*ORANGE)
    c.roundRect(cx - rib_w / 2, rib_y, rib_w, rib_h, rib_h / 2, stroke=0, fill=1)
    c.setFillColorCMYK(*WHITE)
    c.setFont(FONT_BOLD, 21)
    c.drawCentredString(cx, rib_y + 13, spec.subtitle)

    # 見本の盤面（少し傾けたカード）と虫めがね
    card = 4.3 * inch
    ccy = top - 6.75 * inch
    t0 = spec.themes[spec.theme_index(spec.cover_theme)]
    sample = build_wordsearch(
        t0["words"], t0["difficulty"], spec.seed_start + _COVER_SEED_OFFSET, theme=t0["theme"], script=t0["script"]
    )
    c.saveState()
    c.translate(cx, ccy)
    c.rotate(-3)
    c.setFillColorCMYK(*shadow)
    c.roundRect(-card / 2 + 8, -card / 2 - 10, card, card, 18, stroke=0, fill=1)
    c.setFillColorCMYK(*WHITE)
    c.roundRect(-card / 2, -card / 2, card, card, 18, stroke=0, fill=1)
    pad = 26
    draw_grid(c, sample, x=-card / 2 + pad, y=card / 2 - pad, w=card - 2 * pad, show_answer=True, palette=COLOR)
    c.restoreState()
    draw_icon(c, "1f50d", cx + card * 0.20, ccy - card * 0.62, 1.7 * inch)

    # 季節の絵
    ico = 0.95 * inch
    # 題字（ことば探し）はほぼ全幅なので、花と紅葉は上の「ゆったり」の段の左右に置く
    draw_icon(c, "1f338", fx + safe + 30, top - 1.95 * inch, ico * 0.9, rotate=-12)
    draw_icon(c, "1f341", fx + tw - safe - ico * 0.9 - 30, top - 1.95 * inch, ico * 0.9, rotate=15)
    draw_icon(c, "1f33b", fx + safe - 4, ccy + 0.2 * inch, ico)
    draw_icon(c, "1f361", fx + tw - safe - ico + 4, ccy + 0.55 * inch, ico, rotate=10)
    draw_icon(c, "26c4", fx + safe - 2, ccy - 1.55 * inch, ico)
    draw_icon(c, "1f375", fx + tw - safe - ico, ccy - 0.75 * inch, ico * 0.85)

    # 売りの丸い札
    seals = [
        (red, [f"全{count}" if count else "ことば探し"]),
        (green, ["大きな", "文字"]),
        (blue, ["答え", "つき"]),
    ]
    if spec.ink == "premium":
        seals.insert(2, (ORANGE, ["オール", "カラー"]))
    if any(t.get("talk") for t in spec.themes):
        seals.insert(1, ((0.0, 0.55, 0.0, 0.0), ["思い出", "トーク"]))
    r = (0.56 if len(seals) <= 4 else 0.50) * inch
    gap = (tw - 2 * safe - 2 * r * len(seals)) / (len(seals) + 1)
    sy = b + 1.45 * inch
    for k, (col, lines) in enumerate(seals):
        _seal(c, fx + safe + gap * (k + 1) + r * (2 * k + 1), sy, r, col, lines)

    c.setFillColorCMYK(*NAVY)
    c.setFont(FONT_BOLD, 16)
    c.drawCentredString(cx, b + 0.50 * inch, spec.publisher)

    # --- 裏表紙 ---
    bx0 = b + safe + 24
    c.setFillColorCMYK(*NAVY)
    c.setFont(FONT_ROUNDED, 30)
    c.drawString(bx0, top - safe - 50, title_main)
    c.setFont(FONT_BOLD, 15)
    c.drawString(bx0, top - safe - 80, f"全{count}　{spec.subtitle}" if count else spec.subtitle)
    n_words = sum(len(t["words"]) for t in spec.themes)
    lines = [
        "A4の大きな紙面に、1ページ1問。",
        "ます目の中から言葉をさがして、丸でかこむだけ。",
        f"季節の花、昭和のくらし、ふるさとの味……探す言葉は全部で{n_words}語。",
        "各問に「思い出トーク」つき。解いたあとは、なつかしい話に花を。",
    ]
    c.setFont(FONT_REGULAR, 13)
    y = top - safe - 120
    for line in lines:
        c.drawString(bx0, y, line)
        y -= 24

    # 中のページの見本（2ページ）
    page_w, page_h = trim.width_in * inch, trim.height_in * inch
    scale = 0.36
    mini_w, mini_h = page_w * scale, page_h * scale
    mgap = 22
    mx0 = b + (tw - 2 * mini_w - mgap) / 2
    my0 = y - 20 - mini_h
    previews = [spec.theme_index(n, d) for n, d in zip(spec.preview_themes or ("", ""), (0, len(puzzles) - 1))]
    for k, idx in enumerate(previews):
        px = mx0 + k * (mini_w + mgap)
        c.setFillColorCMYK(*shadow)
        c.rect(px + 5, my0 - 5, mini_w, mini_h, stroke=0, fill=1)
        # KDP は表紙の文字を 7pt 以上と定めている。縮小した見本の文字はそれを下回るので、画像にして貼る
        c.drawImage(_page_preview(spec, puzzles, idx, mini_w), px, my0, mini_w, mini_h)

    # 難易度の内訳
    counts: dict[str, int] = {}
    for t in spec.themes:
        counts[t["difficulty"]] = counts.get(t["difficulty"], 0) + 1
    y = my0 - 34
    c.setFont(FONT_BOLD, 14)
    for d, n in counts.items():
        c.setFillColorCMYK(*spec.palette.main[d])
        c.drawString(bx0, y, f"{DIFFICULTY_STARS[d]} {DIFFICULTY_LABEL_JA[d]}　{n}問")
        y -= 22
    c.setFillColorCMYK(*NAVY)
    c.setFont(FONT_REGULAR, 12)
    c.drawString(bx0, y - 6, "答えは巻末に、言葉ごとに色を分けてまとめてあります。")

    # こんな方に（買う人の多くは家族や介護の現場の人）。答えの一文の下、左の列に置く
    boxx, boxw = bx0 - 10, 290
    box_top = y - 30
    rows_ = [("1f3e0", "ご自宅での、ひとりの時間に"), ("1f46a", "ご家族との会話のきっかけに"), ("1f375", "デイサービスのレクリエーションに")]
    box_h = 34 + len(rows_) * 28
    c.setFillColorCMYK(*WHITE)
    c.roundRect(boxx, box_top - box_h, boxw, box_h, 12, stroke=0, fill=1)
    c.setFillColorCMYK(*ORANGE)
    c.setFont(FONT_ROUNDED, 15)
    c.drawString(boxx + 14, box_top - 24, "こんな方に")
    c.setFillColorCMYK(*NAVY)
    c.setFont(FONT_REGULAR, 12)
    for k, (code, text) in enumerate(rows_):
        yy = box_top - 50 - k * 28
        draw_icon(c, code, boxx + 14, yy - 5, 20)
        c.drawString(boxx + 42, yy, text)

    bw, bh = (v * inch for v in kdp_spec.BARCODE_BOX_IN)
    c.setFillColorCMYK(*WHITE)
    c.rect(spine_x0 - safe - bw, b + safe, bw, bh, stroke=0, fill=1)
    c.save()
    return total_w, total_h


def main() -> None:
    parser = argparse.ArgumentParser(description="ことば探しの本の本文・表紙PDFを作る")
    parser.add_argument("spec", help="books/kotoba-*.json")
    parser.add_argument("--paper", choices=["white", "cream"], default="white")
    args = parser.parse_args()
    spec = KotobaSpec.load(args.spec)
    stem = Path(args.spec).stem
    Path("output").mkdir(exist_ok=True)
    puzzles = generate_puzzles(spec)
    total = build_pdf(puzzles, f"output/{stem}-interior.pdf", spec)
    w, h = build_cover(spec, puzzles, f"output/{stem}-cover.pdf", paper=args.paper)
    cost = kdp_spec.print_cost_jpy(total, spec.ink)
    print(f"{spec.puzzle_count}問・{total}ページ（{spec.ink}、印刷代 {cost}円）-> output/{stem}-interior.pdf")
    print(f"表紙 {w:.4f} x {h:.4f} in -> output/{stem}-cover.pdf")


if __name__ == "__main__":
    main()

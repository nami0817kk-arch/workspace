"""ことば探しの本（KDP ペーパーバック）の本文PDFと表紙PDFを組む。

盤面の生成と検証は `libs/puzzle-generator` の `build_wordsearch`。ここは紙面だけ。
判型・余白・フォント・ページ送りは迷路本（build_book.py）と共通のものを使う。

設計書は `books/kotoba-*.json`。テーマごとに語の一覧・難易度・文字の種類を持つ。
"""

from __future__ import annotations

import argparse
import json
from dataclasses import dataclass
from pathlib import Path

from puzzle_generator import DIRS, build_wordsearch, validate_record
from reportlab.lib.units import inch
from reportlab.pdfgen import canvas

import kdp_spec
from build_book import DIFFICULTY_LABEL_JA, DIFFICULTY_STARS, FONT_BOLD, FONT_REGULAR, _Pager
from build_cover import CREAM, NAVY, ORANGE, WHITE

ANSWERS_PER_PAGE = 4
# 矢印の字形（↘など）は同梱フォントに無いものがあるので、向きは言葉で書く
DIR_WORDS = {"E": "よこ（左から右へ）", "S": "たて（上から下へ）", "SE": "ななめ（左上から右下へ）"}
_COVER_SEED_OFFSET = 9_000_000  # 表紙の見本は本文と別の盤面にする（問題1の答えを表紙で見せない）


@dataclass
class KotobaSpec:
    title: str
    subtitle: str
    themes: list[dict]
    seed_start: int
    trim: str = "a4"
    publisher: str = "つるはし社"
    edition_date: str = ""

    @classmethod
    def load(cls, path: str | Path) -> "KotobaSpec":
        return cls(**json.loads(Path(path).read_text(encoding="utf-8")))

    @property
    def puzzle_count(self) -> int:
        return len(self.themes)


def generate_puzzles(spec: KotobaSpec) -> list[dict]:
    order = {"easy": 0, "medium": 1, "hard": 2}
    ranks = [order[t["difficulty"]] for t in spec.themes]
    if ranks != sorted(ranks):
        raise ValueError("テーマはやさしい順に並べること")
    return [
        build_wordsearch(t["words"], t["difficulty"], spec.seed_start + i, theme=t["theme"], script=t["script"])
        for i, t in enumerate(spec.themes)
    ]


def page_count(spec: KotobaSpec) -> int:
    total = 2 + spec.puzzle_count + -(-spec.puzzle_count // ANSWERS_PER_PAGE) + 1
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
    bold: bool = True,
) -> float:
    """(x, y) を左上とする幅 w の正方形に盤面を描き、盤面の高さを返す。"""
    board = record["board"]
    size = board["size"]
    cell = w / size
    top = y

    c.saveState()
    if show_answer:
        # 答えの語を、灰色の太い帯で囲む（白黒印刷で読めるように、文字の下に敷く）
        c.setStrokeGray(0.72)
        c.setLineCap(1)
        c.setLineWidth(cell * 0.78)
        for p in record["solution"]["placements"]:
            dx, dy = DIRS[p["dir"]]
            sx, sy = p["start"]
            n = len(p["answer"]) - 1
            x1, y1 = x + (sx + 0.5) * cell, top - (sy + 0.5) * cell
            x2, y2 = x + (sx + dx * n + 0.5) * cell, top - (sy + dy * n + 0.5) * cell
            c.line(x1, y1, x2, y2)

    # 罫線は薄く、外枠だけ濃く
    c.setStrokeGray(0.75)
    c.setLineWidth(max(kdp_spec.MIN_LINE_PT, cell * 0.02))
    for i in range(1, size):
        c.line(x + i * cell, top, x + i * cell, top - size * cell)
        c.line(x, top - i * cell, x + size * cell, top - i * cell)
    c.setStrokeGray(0)
    c.setLineWidth(max(kdp_spec.MIN_LINE_PT, cell * 0.04))
    c.rect(x, top - size * cell, size * cell, size * cell, stroke=1, fill=0)

    c.setFillGray(0)
    font = FONT_BOLD if bold else FONT_REGULAR
    fs = cell * 0.62
    c.setFont(font, fs)
    for gy, row in enumerate(board["grid"]):
        for gx, ch in enumerate(row):
            cx = x + (gx + 0.5) * cell
            cy = top - (gy + 0.5) * cell - fs * 0.36
            c.drawCentredString(cx, cy, ch)
    c.restoreState()
    return size * cell


def _word_columns(labels: list[str]) -> int:
    return 2 if len(labels) > 5 else 1


def build_pdf(puzzles: list[dict], output_path: str, spec: KotobaSpec) -> int:
    for r in puzzles:
        validate_record(r)
    if len(puzzles) != spec.puzzle_count:
        raise ValueError("問題数が設計書と違う")
    trim = kdp_spec.TRIMS[spec.trim]
    total = page_count(spec)
    if total < kdp_spec.MIN_PAGES:
        raise ValueError(f"KDP の最小ページ数 {kdp_spec.MIN_PAGES} に足りない: {total}")

    c = canvas.Canvas(output_path, pagesize=(trim.width_in * inch, trim.height_in * inch))
    c.setTitle(spec.title)
    c.setAuthor(spec.publisher)
    c.setCreator(spec.publisher)
    pg = _Pager(c, trim, total)
    mid = lambda: (pg.left + pg.right) / 2  # noqa: E731

    # 1. 表題
    c.setFont(FONT_BOLD, 38)
    c.drawCentredString(mid(), pg.page_h * 0.62, spec.title)
    c.setFont(FONT_REGULAR, 18)
    c.drawCentredString(mid(), pg.page_h * 0.62 - 48, spec.subtitle)
    c.setFont(FONT_REGULAR, 14)
    c.drawCentredString(mid(), pg.page_h * 0.18, spec.publisher)
    pg.next(folio=False)

    # 2. 遊び方
    top = pg.page_h - pg.top
    c.setFont(FONT_BOLD, 28)
    c.drawString(pg.left, top - 30, "遊び方")
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
        y -= 36
    used = []
    for t in spec.themes:
        if t["difficulty"] not in used:
            used.append(t["difficulty"])
    for d in used:
        dirs = {"easy": ["E", "S"], "medium": ["E", "S"], "hard": ["E", "S", "SE"]}[d]
        c.drawString(pg.left + 20, y, f"{DIFFICULTY_STARS[d]} {DIFFICULTY_LABEL_JA[d]}")
        y -= 32
        c.drawString(pg.left + 60, y, "・".join(DIR_WORDS[x] for x in dirs[:2]))
        y -= 32
        if len(dirs) > 2:
            c.drawString(pg.left + 60, y, "・" + "・".join(DIR_WORDS[x] for x in dirs[2:]))
            y -= 32
    y -= 10
    c.drawString(pg.left, y, "逆向き（右から左・下から上）には、ならんでいません。")
    y -= 36
    c.drawString(pg.left, y, "答えは本のうしろにまとめてあります。")
    pg.next()

    # 3. 問題（1ページ1問）
    for i, record in enumerate(puzzles, start=1):
        top = pg.page_h - pg.top
        c.setFont(FONT_BOLD, 22)
        c.drawString(pg.left, top - 22, f"問題 {i}")
        c.setFont(FONT_REGULAR, 14)
        d = record["difficulty"]
        c.drawRightString(pg.right, top - 20, f"{DIFFICULTY_STARS[d]} {DIFFICULTY_LABEL_JA[d]}")
        c.setFont(FONT_BOLD, 26)
        c.drawCentredString(mid(), top - 64, f"テーマ　{record['board']['theme']}")

        labels = [w["label"] for w in record["board"]["words"]]
        cols = _word_columns(labels)
        rows = -(-len(labels) // cols)
        word_fs = 19
        list_h = rows * word_fs * 1.75 + 10
        footer = 30
        avail_h = (top - 90) - (pg.bottom + footer + list_h + 20)
        gw = min(pg.content_w, avail_h)
        gx = mid() - gw / 2
        gh = draw_grid(c, record, x=gx, y=top - 90, w=gw, show_answer=False)

        ly = top - 90 - gh - 30
        col_w = gw / cols
        c.setFont(FONT_REGULAR, word_fs)
        for k, label in enumerate(labels):
            col, row = k // rows, k % rows
            lx = gx + col * col_w
            yy = ly - row * word_fs * 1.75
            c.rect(lx, yy - 2, word_fs * 0.8, word_fs * 0.8, stroke=1, fill=0)
            c.drawString(lx + word_fs * 1.2, yy, label)
        c.setFont(FONT_REGULAR, 12)
        c.drawRightString(pg.right, pg.bottom + 6, "できた日　　月　　日")
        pg.next()

    # 4. 解答（1ページ4問）
    gap = 0.35 * inch
    for start in range(0, len(puzzles), ANSWERS_PER_PAGE):
        chunk = puzzles[start : start + ANSWERS_PER_PAGE]
        top = pg.page_h - pg.top
        c.setFont(FONT_BOLD, 20)
        c.drawString(pg.left, top - 20, "答え")
        cw = (pg.content_w - gap) / 2
        area_top = top - 44
        ch = (area_top - (pg.bottom + 20) - gap) / 2
        for k, record in enumerate(chunk):
            col, row = k % 2, k // 2
            bx = pg.left + col * (cw + gap)
            by_top = area_top - row * (ch + gap)
            c.setFont(FONT_BOLD, 12)
            c.drawString(bx, by_top - 12, f"問題 {start + k + 1}　{record['board']['theme']}")
            side = min(cw, ch - 24)
            draw_grid(c, record, x=bx + (cw - side) / 2, y=by_top - 20, w=side, show_answer=True, bold=False)
        pg.next()

    # 5. 白ページで偶数にそろえ、奥付
    while pg.number < total:
        pg.next(folio=False)
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
    pg.next(folio=False)
    c.save()
    return total


# --- 表紙 ------------------------------------------------------------------


def build_cover(spec: KotobaSpec, puzzles: list[dict], output_path: str, *, paper: str = "white") -> tuple[float, float]:
    pages = page_count(spec)
    trim = kdp_spec.TRIMS[spec.trim]
    spine = kdp_spec.spine_width_in(pages, paper)
    bleed = kdp_spec.COVER_BLEED_IN
    total_w, total_h = bleed * 2 + trim.width_in * 2 + spine, bleed * 2 + trim.height_in
    W, H = total_w * inch, total_h * inch
    tw, th, sp, b = trim.width_in * inch, trim.height_in * inch, spine * inch, bleed * inch
    safe = kdp_spec.COVER_SAFE_IN * inch

    c = canvas.Canvas(output_path, pagesize=(W, H))
    c.setTitle(f"{spec.title}（表紙）")
    c.setAuthor(spec.publisher)
    c.setFillColorCMYK(*CREAM)
    c.rect(0, 0, W, H, stroke=0, fill=1)
    spine_x0, front_x0 = b + tw, b + tw + sp
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

    # 表表紙: 上に題名の帯、中央に見本の盤面
    band_h = th * 0.30
    c.setFillColorCMYK(*NAVY)
    c.rect(front_x0, b + th - band_h, tw + b, band_h + b, stroke=0, fill=1)
    cx = front_x0 + tw / 2
    title_main, _, count = spec.title.rpartition(" ")
    c.setFillColorCMYK(*WHITE)
    c.setFont(FONT_BOLD, 52)
    c.drawCentredString(cx, b + th - band_h * 0.48, title_main or spec.title)
    c.setFont(FONT_REGULAR, 20)
    c.drawCentredString(cx, b + th - band_h * 0.80, spec.subtitle)
    if count:
        bx, by, r = front_x0 + tw - safe - 58, b + th - band_h - 20, 54
        c.setFillColorCMYK(*ORANGE)
        c.circle(bx, by, r, stroke=0, fill=1)
        c.setFillColorCMYK(*WHITE)
        c.setFont(FONT_BOLD, 34)
        c.drawCentredString(bx, by - 12, count)

    panel = min(tw - 2 * safe - 80, th - band_h - 2.6 * inch)
    px, py_top = front_x0 + (tw - panel) / 2, b + th - band_h - 1.0 * inch
    c.setFillColorCMYK(*WHITE)
    c.roundRect(px - 24, py_top - panel - 24, panel + 48, panel + 48, 14, stroke=0, fill=1)
    t0 = spec.themes[0]
    sample = build_wordsearch(
        t0["words"], t0["difficulty"], spec.seed_start + _COVER_SEED_OFFSET, theme=t0["theme"], script=t0["script"]
    )
    draw_grid(c, sample, x=px, y=py_top, w=panel, show_answer=True)
    c.setFillColorCMYK(*NAVY)
    c.setFont(FONT_BOLD, 18)
    c.drawCentredString(cx, b + 0.62 * inch, spec.publisher)

    # 裏表紙
    lines = [
        "A4の大きな紙面に、1ページ1問。",
        "大きな文字で、目にやさしいことば探しです。",
        "",
    ]
    counts: dict[str, int] = {}
    for t in spec.themes:
        counts[t["difficulty"]] = counts.get(t["difficulty"], 0) + 1
    for d, n in counts.items():
        lines.append(f"{DIFFICULTY_STARS[d]} {DIFFICULTY_LABEL_JA[d]}　{n}問")
    lines += ["", "季節の花、昭和のくらし、ふるさとの味。", "なつかしい言葉をさがしながら、", "おしゃべりも弾みます。", "", "答えは巻末にまとめてあります。"]
    c.setFillColorCMYK(*NAVY)
    c.setFont(FONT_BOLD, 20)
    y = b + th - safe - 60
    c.drawString(b + safe + 20, y, spec.title)
    c.setFont(FONT_REGULAR, 14)
    y -= 44
    for line in lines:
        c.drawString(b + safe + 20, y, line)
        y -= 28
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
    print(f"{spec.puzzle_count}問・{total}ページ -> output/{stem}-interior.pdf")
    print(f"表紙 {w:.4f} x {h:.4f} in -> output/{stem}-cover.pdf")


if __name__ == "__main__":
    main()

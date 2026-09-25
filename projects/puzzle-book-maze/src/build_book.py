"""迷路パズル本（KDPペーパーバック向け）の原稿PDFを組む。

パズルの生成そのものは `libs/puzzle-generator` の責務。ここでは
1) 生成器から検証済みの迷路を受け取り
2) 1ページ1問のレイアウトで問題面を並べ
3) 巻末に解答ページをまとめる
だけを行う。

**紙面の実サイズ（トリムサイズ）・綴じ側の余白（gutter、ページ数に応じて
KDPが要求する値が変わる）は未確認。** ここでは仮の値を置いてあるだけなので、
実際に入稿する前に KDP の最新のペーパーバック版下テンプレート（KDPの
アカウントで取得する）と必ず照合すること（`docs/session-briefs/method5.md`）。
"""

from __future__ import annotations

import argparse
from pathlib import Path

from puzzle_generator import generate_batch, validate_record
from reportlab.lib.units import inch
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.pdfgen import canvas

# --- 紙面設定（暫定値。KDP入稿前に要確認） --------------------------------
PAGE_WIDTH = 8.5 * inch
PAGE_HEIGHT = 11 * inch
MARGIN = 0.75 * inch  # KDPの最小外側マージンより広めに取った暫定値
GUTTER_EXTRA = 0.125 * inch  # 綴じ側の追加余白（ページ数依存。暫定値）

_WALL_N, _WALL_E, _WALL_S, _WALL_W = 1, 2, 4, 8

# reportlab 標準の Helvetica 等は日本語グリフを持たないため、そのまま
# 使うと文字が四角(tofu)に潰れる。狙いは日本の高齢者向けなので、
# OFL(SIL Open Font License)の Noto Sans JP をこのPJT内に同梱して埋め込む
# (soccer-manager / soccer-career と同じ書体・同じライセンス表記)。
_FONTS_DIR = Path(__file__).resolve().parent.parent / "assets" / "fonts"
FONT_REGULAR = "NotoSansJP"
FONT_BOLD = "NotoSansJP-Bold"
pdfmetrics.registerFont(TTFont(FONT_REGULAR, str(_FONTS_DIR / "NotoSansJP-Regular.ttf")))
pdfmetrics.registerFont(TTFont(FONT_BOLD, str(_FONTS_DIR / "NotoSansJP-Bold.ttf")))

DIFFICULTY_LABEL_JA = {"easy": "やさしい", "medium": "ふつう", "hard": "むずかしい"}


def _draw_maze(
    c: canvas.Canvas,
    record: dict,
    *,
    x: float,
    y: float,
    w: float,
    h: float,
    show_solution: bool,
) -> None:
    """(x, y) を左下とする幅w・高さhの箱の中に、縦横比を保って迷路を描く。"""
    board = record["board"]
    width, height = board["width"], board["height"]
    walls = board["cell_walls"]

    cell = min(w / width, h / height)
    draw_w, draw_h = width * cell, height * cell
    ox = x + (w - draw_w) / 2
    oy = y + (h - draw_h) / 2

    def cell_box(gx: int, gy: int) -> tuple[float, float]:
        # JSON側は y が下向きに増える。PDF座標は下が原点なので上下を反転する。
        return ox + gx * cell, oy + (height - 1 - gy) * cell

    c.saveState()
    c.setLineWidth(max(cell * 0.06, 0.8))
    for gy in range(height):
        for gx in range(width):
            wall = walls[gy][gx]
            cx, cy = cell_box(gx, gy)
            if wall & _WALL_N:
                c.line(cx, cy + cell, cx + cell, cy + cell)
            if wall & _WALL_W:
                c.line(cx, cy, cx, cy + cell)
            if wall & _WALL_E:
                c.line(cx + cell, cy, cx + cell, cy + cell)
            if wall & _WALL_S:
                c.line(cx, cy, cx + cell, cy)

    if show_solution:
        path = record["solution"]["path"]
        points = []
        for px, py in path:
            cx, cy = cell_box(px, py)
            points.append((cx + cell / 2, cy + cell / 2))
        c.setStrokeColorRGB(0.2, 0.4, 0.8)
        c.setLineWidth(max(cell * 0.25, 1.2))
        p = c.beginPath()
        p.moveTo(*points[0])
        for pt in points[1:]:
            p.lineTo(*pt)
        c.drawPath(p, stroke=1, fill=0)

    c.restoreState()


def build_pdf(puzzles: list[dict], output_path: str, *, title: str) -> None:
    for record in puzzles:
        validate_record(record)

    c = canvas.Canvas(output_path, pagesize=(PAGE_WIDTH, PAGE_HEIGHT))

    # 表題ページ（最小限）。表紙そのものは KDP の表紙作成ツール側で別に作る。
    c.setFont(FONT_BOLD, 24)
    c.drawCentredString(PAGE_WIDTH / 2, PAGE_HEIGHT / 2, title)
    c.setFont(FONT_REGULAR, 12)
    c.drawCentredString(PAGE_WIDTH / 2, PAGE_HEIGHT / 2 - 30, "つるはし社")
    c.showPage()

    board_area = min(PAGE_WIDTH, PAGE_HEIGHT) - 2 * (MARGIN + GUTTER_EXTRA)
    board_x = (PAGE_WIDTH - board_area) / 2
    board_y = MARGIN + 0.5 * inch  # 下に問題番号を置く余地を残す

    for i, record in enumerate(puzzles, start=1):
        c.setFont(FONT_REGULAR, 14)
        c.drawString(MARGIN, PAGE_HEIGHT - MARGIN, f"問題 {i}")
        difficulty_ja = DIFFICULTY_LABEL_JA.get(record["difficulty"], record["difficulty"])
        c.drawRightString(PAGE_WIDTH - MARGIN, PAGE_HEIGHT - MARGIN, difficulty_ja)
        _draw_maze(c, record, x=board_x, y=board_y, w=board_area, h=board_area, show_solution=False)
        c.setFont(FONT_REGULAR, 9)
        c.drawCentredString(PAGE_WIDTH / 2, MARGIN / 2, str(i + 1))  # +1 = 表題ページの次
        c.showPage()

    # 解答ページ（1ページ4問、見開きレイアウト）
    per_page = 4
    gap = 0.4 * inch
    ans_size = (min(PAGE_WIDTH, PAGE_HEIGHT) - 2 * MARGIN - gap) / 2
    positions = [
        (MARGIN, PAGE_HEIGHT - MARGIN - ans_size),
        (PAGE_WIDTH - MARGIN - ans_size, PAGE_HEIGHT - MARGIN - ans_size),
        (MARGIN, MARGIN),
        (PAGE_WIDTH - MARGIN - ans_size, MARGIN),
    ]
    for start in range(0, len(puzzles), per_page):
        chunk = puzzles[start : start + per_page]
        c.setFont(FONT_BOLD, 14)
        c.drawString(MARGIN, PAGE_HEIGHT - MARGIN / 2, "解答")
        for offset, record in enumerate(chunk):
            px, py = positions[offset]
            c.setFont(FONT_REGULAR, 9)
            c.drawString(px, py + ans_size + 4, f"問題 {start + offset + 1}")
            _draw_maze(c, record, x=px, y=py, w=ans_size, h=ans_size, show_solution=True)
        c.showPage()

    c.save()


def main() -> None:
    parser = argparse.ArgumentParser(description="迷路パズル本のKDP入稿用PDF原稿を作る")
    parser.add_argument("--count", type=int, default=60)
    parser.add_argument("--difficulty", choices=["easy", "medium", "hard"], default="medium")
    parser.add_argument("--seed-start", type=int, default=0)
    parser.add_argument("--title", default=None, help="省略時は難易度と問題数から自動で組む")
    parser.add_argument("--out", default="output/interior.pdf")
    args = parser.parse_args()

    title = args.title or f"{DIFFICULTY_LABEL_JA[args.difficulty]}迷路パズル {args.count}問"
    puzzles = generate_batch(args.count, args.difficulty, start_seed=args.seed_start)
    Path(args.out).parent.mkdir(parents=True, exist_ok=True)
    build_pdf(puzzles, args.out, title=title)
    print(f"{len(puzzles)}問 -> {args.out}")


if __name__ == "__main__":
    main()

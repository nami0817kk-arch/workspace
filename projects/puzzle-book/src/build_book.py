"""迷路パズル本（KDPペーパーバック）の本文PDFを組む。

パズルの生成そのものは `libs/puzzle-generator` の責務。ここでは
1) 本の設計書（`books/*.json`）を読み
2) 生成器から検証済みの迷路を受け取り
3) 表題 → 遊び方 → 問題（1ページ1問、やさしい順）→ 解答 → 奥付 の順に組む
だけを行う。表紙は `build_cover.py`。

紙面の寸法は `kdp_spec.py` に集めてある（出典もそこに書いてある）。
"""

from __future__ import annotations

import argparse
import json
from dataclasses import dataclass, field
from pathlib import Path

from puzzle_generator import generate_batch, validate_record
from reportlab.lib.units import inch
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.pdfgen import canvas

import kdp_spec

_WALL_N, _WALL_E, _WALL_S, _WALL_W = 1, 2, 4, 8

# reportlab 標準の Helvetica 等は日本語グリフを持たないため、そのまま
# 使うと文字が四角(tofu)に潰れる。OFL の Noto Sans JP をこのPJT内に同梱して埋め込む
# (soccer-manager / soccer-career と同じ書体・同じライセンス表記)。
_PROJECT_DIR = Path(__file__).resolve().parent.parent
_FONTS_DIR = _PROJECT_DIR / "assets" / "fonts"
FONT_REGULAR = "NotoSansJP"
FONT_BOLD = "NotoSansJP-Bold"
pdfmetrics.registerFont(TTFont(FONT_REGULAR, str(_FONTS_DIR / "NotoSansJP-Regular.ttf")))
pdfmetrics.registerFont(TTFont(FONT_BOLD, str(_FONTS_DIR / "NotoSansJP-Bold.ttf")))

DIFFICULTY_LABEL_JA = {"easy": "やさしい", "medium": "ふつう", "hard": "むずかしい"}
DIFFICULTY_STARS = {"easy": "★☆☆", "medium": "★★☆", "hard": "★★★"}

# 本文は白黒印刷。解答の線は灰色にして、黒い壁の下に敷く（壁が読めなくならないように）。
SOLUTION_GRAY = 0.6

ANSWERS_PER_PAGE = 4


@dataclass
class BookSpec:
    """1冊分の設計。`books/<slug>.json` に置く。"""

    title: str
    subtitle: str
    sections: list[tuple[str, int]]  # (difficulty, 問題数) をやさしい順に
    seed_start: int
    trim: str = "a4"
    publisher: str = "つるはし社"
    edition_date: str = ""  # 奥付に出す初版の日付（例: "2026年10月1日"）
    how_to_play: list[str] = field(default_factory=list)

    @classmethod
    def load(cls, path: str | Path) -> "BookSpec":
        data = json.loads(Path(path).read_text(encoding="utf-8"))
        data["sections"] = [tuple(s) for s in data["sections"]]
        return cls(**data)

    @property
    def puzzle_count(self) -> int:
        return sum(n for _, n in self.sections)


def generate_puzzles(spec: BookSpec) -> list[dict]:
    """設計書どおりに、やさしい順で問題を並べる。

    難易度ごとに seed の帯を分ける（`seed_start + 10000*i` から）。
    同じ設計書からは毎回同じ本ができ、巻ごとに `seed_start` をずらせば
    別の巻と問題が重ならない。
    """
    puzzles: list[dict] = []
    for i, (difficulty, count) in enumerate(spec.sections):
        puzzles += generate_batch(count, difficulty, start_seed=spec.seed_start + 10000 * i)
    ids = [p["id"] for p in puzzles]
    if len(set(ids)) != len(ids):
        raise ValueError("同じ問題が2回入っている")
    return puzzles


# --- 迷路1枚の描画 ------------------------------------------------------------


def _opening_side(cell: list[int], width: int, height: int) -> int:
    """スタート・ゴールのマスで、外周のどの辺を開けるか。"""
    x, y = cell
    if y == 0:
        return _WALL_N
    if y == height - 1:
        return _WALL_S
    if x == 0:
        return _WALL_W
    if x == width - 1:
        return _WALL_E
    raise ValueError(f"スタート・ゴールが外周に無い: {cell}")


def maze_geometry(record: dict, *, x: float, y: float, w: float, h: float) -> tuple[float, float, float]:
    """箱 (x, y, w, h) の中に縦横比を保って収めたときの (左下x, 左下y, マス幅)。"""
    board = record["board"]
    cell = min(w / board["width"], h / board["height"])
    ox = x + (w - board["width"] * cell) / 2
    oy = y + (h - board["height"] * cell) / 2
    return ox, oy, cell


def draw_maze(
    c: canvas.Canvas,
    record: dict,
    *,
    x: float,
    y: float,
    w: float,
    h: float,
    show_solution: bool,
    line_width: float | None = None,
    solution_width: float = 0.35,
) -> None:
    """(x, y) を左下とする幅w・高さhの箱の中に迷路を描く。

    スタートとゴールのマスは外周の壁を1辺ずつ開けておく。開けないと
    どこから入ってどこへ抜けるのか紙面から読めない（2026-09-26 に
    骨組みの PDF で実際にそうなっていた）。
    """
    board = record["board"]
    width, height = board["width"], board["height"]
    walls = board["cell_walls"]
    ox, oy, cell = maze_geometry(record, x=x, y=y, w=w, h=h)

    def cell_box(gx: int, gy: int) -> tuple[float, float]:
        # JSON側は y が下向きに増える。PDF座標は下が原点なので上下を反転する。
        return ox + gx * cell, oy + (height - 1 - gy) * cell

    def center(gx: int, gy: int) -> tuple[float, float]:
        bx, by = cell_box(gx, gy)
        return bx + cell / 2, by + cell / 2

    openings = {
        tuple(board["start"]): _opening_side(board["start"], width, height),
        tuple(board["goal"]): _opening_side(board["goal"], width, height),
    }
    outward = {_WALL_N: (0, 1), _WALL_S: (0, -1), _WALL_W: (-1, 0), _WALL_E: (1, 0)}

    c.saveState()
    c.setLineCap(1)  # 丸い端（角のつなぎ目に隙間が出ない）

    if show_solution:
        path = record["solution"]["path"]
        pts = [center(px, py) for px, py in path]
        # 入口と出口の外側まで線を伸ばす（開けた辺を通って外へ出ることが分かるように）
        for end, idx in ((board["start"], 0), (board["goal"], -1)):
            dx, dy = outward[openings[tuple(end)]]
            ex, ey = pts[idx]
            outside = (ex + dx * cell, ey + dy * cell)
            if idx == 0:
                pts.insert(0, outside)
            else:
                pts.append(outside)
        c.setStrokeGray(SOLUTION_GRAY)
        c.setLineWidth(cell * solution_width)
        c.setLineJoin(1)
        p = c.beginPath()
        p.moveTo(*pts[0])
        for pt in pts[1:]:
            p.lineTo(*pt)
        c.drawPath(p, stroke=1, fill=0)

    c.setStrokeGray(0)
    c.setLineWidth(line_width if line_width is not None else max(cell * 0.08, 0.9))
    for gy in range(height):
        for gx in range(width):
            wall = walls[gy][gx]
            opened = openings.get((gx, gy), 0)
            cx, cy = cell_box(gx, gy)
            # 内側の壁は隣のマスと共有しているので、N と W だけ描けば二重にならない。
            # 外周の E（右端）と S（下端）だけ追加で描く。
            if wall & _WALL_N and opened != _WALL_N:
                c.line(cx, cy + cell, cx + cell, cy + cell)
            if wall & _WALL_W and opened != _WALL_W:
                c.line(cx, cy, cx, cy + cell)
            if gx == width - 1 and wall & _WALL_E and opened != _WALL_E:
                c.line(cx + cell, cy, cx + cell, cy + cell)
            if gy == height - 1 and wall & _WALL_S and opened != _WALL_S:
                c.line(cx, cy, cx + cell, cy)
    c.restoreState()


def _draw_arrow_label(
    c: canvas.Canvas, record: dict, *, x: float, y: float, w: float, h: float, font_size: float
) -> None:
    """スタート・ゴールの開口部の外に、文字と矢印を置く。"""
    board = record["board"]
    width, height = board["width"], board["height"]
    ox, oy, cell = maze_geometry(record, x=x, y=y, w=w, h=h)
    c.saveState()
    c.setFillGray(0)
    c.setStrokeGray(0)
    for key, label in (("start", "スタート"), ("goal", "ゴール")):
        gx, gy = board[key]
        side = _opening_side(board[key], width, height)
        mx = ox + gx * cell + cell / 2
        top = oy + height * cell
        c.setFont(FONT_BOLD, font_size)
        if side == _WALL_N:
            c.drawCentredString(mx, top + font_size * 1.6, label)
            _arrow(c, mx, top + font_size * 1.4, mx, top + 2, font_size * 0.6)
        elif side == _WALL_S:
            c.drawCentredString(mx, oy - font_size * 2.4, label)
            _arrow(c, mx, oy - 2, mx, oy - font_size * 1.2, font_size * 0.6)
        else:
            # 左右の辺に開けるのは今の生成器では起きない（start=(0,0), goal=右下）。
            # 起きたら紙面の余白設計を見直すこと。
            raise NotImplementedError("左右の辺の入口は未対応")
    c.restoreState()


def _arrow(c: canvas.Canvas, x1: float, y1: float, x2: float, y2: float, head: float) -> None:
    c.setLineWidth(head * 0.35)
    c.line(x1, y1, x2, y2 + (head if y2 < y1 else -head) * 0.5)
    direction = -1 if y2 < y1 else 1
    p = c.beginPath()
    p.moveTo(x2, y2)
    p.lineTo(x2 - head * 0.6, y2 - direction * head)
    p.lineTo(x2 + head * 0.6, y2 - direction * head)
    p.close()
    c.drawPath(p, stroke=0, fill=1)


# --- ページ組み -----------------------------------------------------------------


class _Pager:
    """見開きを意識してページを出す。本文は左綴じ（横書き）なので、
    奇数ページ（右ページ）はノドが左、偶数ページ（左ページ）はノドが右。"""

    def __init__(self, c: canvas.Canvas, trim: kdp_spec.Trim, total_pages: int):
        self.c = c
        self.page_w = trim.width_in * inch
        self.page_h = trim.height_in * inch
        self.inside = kdp_spec.inside_margin_in(total_pages) * inch + kdp_spec.GUTTER_EXTRA_IN * inch
        self.outside = kdp_spec.OUTSIDE_MARGIN_IN * inch
        self.top = kdp_spec.TOP_MARGIN_IN * inch
        self.bottom = kdp_spec.BOTTOM_MARGIN_IN * inch
        self.number = 1

    @property
    def left(self) -> float:
        return self.inside if self.number % 2 == 1 else self.outside

    @property
    def right(self) -> float:
        return self.page_w - (self.outside if self.number % 2 == 1 else self.inside)

    @property
    def content_w(self) -> float:
        return self.right - self.left

    def next(self, *, folio: bool = True) -> None:
        if folio:
            self.c.setFont(FONT_REGULAR, 10)
            self.c.setFillGray(0)
            self.c.drawCentredString((self.left + self.right) / 2, self.bottom * 0.55, str(self.number))
        self.c.showPage()
        self.number += 1


def page_count(spec: BookSpec) -> int:
    """組む前に総ページ数を出す（ノドの余白がページ数で決まるため、先に要る）。"""
    front = 2  # 表題・遊び方
    answers = -(-spec.puzzle_count // ANSWERS_PER_PAGE)
    back = 1  # 奥付
    total = front + spec.puzzle_count + answers + back
    return total + (total % 2)  # 偶数にそろえる（奥付の前に白ページを1枚入れる）


def build_pdf(puzzles: list[dict], output_path: str, spec: BookSpec) -> int:
    """本文PDFを書き出し、総ページ数を返す。"""
    for record in puzzles:
        validate_record(record)
    if len(puzzles) != spec.puzzle_count:
        raise ValueError(f"問題数が設計書と違う: {len(puzzles)} != {spec.puzzle_count}")

    trim = kdp_spec.TRIMS[spec.trim]
    total = page_count(spec)
    if total < kdp_spec.MIN_PAGES:
        raise ValueError(f"KDP の最小ページ数 {kdp_spec.MIN_PAGES} に足りない: {total}")

    c = canvas.Canvas(output_path, pagesize=(trim.width_in * inch, trim.height_in * inch))
    c.setTitle(spec.title)
    c.setAuthor(spec.publisher)
    c.setCreator(spec.publisher)
    pg = _Pager(c, trim, total)
    mid_x = lambda: (pg.left + pg.right) / 2  # noqa: E731

    # 1. 表題（右ページ）
    c.setFont(FONT_BOLD, 34)
    c.drawCentredString(mid_x(), pg.page_h * 0.62, spec.title)
    c.setFont(FONT_REGULAR, 16)
    c.drawCentredString(mid_x(), pg.page_h * 0.62 - 44, spec.subtitle)
    c.setFont(FONT_REGULAR, 14)
    c.drawCentredString(mid_x(), pg.page_h * 0.18, spec.publisher)
    pg.next(folio=False)

    # 2. 遊び方（左ページ）
    c.setFont(FONT_BOLD, 26)
    c.drawString(pg.left, pg.page_h - pg.top - 30, "遊び方")
    c.setFont(FONT_REGULAR, 17)
    line_y = pg.page_h - pg.top - 90
    for line in spec.how_to_play:
        c.drawString(pg.left, line_y, line)
        line_y -= 34
    c.setFont(FONT_REGULAR, 14)
    line_y -= 20
    for difficulty, count in spec.sections:
        c.drawString(
            pg.left, line_y, f"{DIFFICULTY_STARS[difficulty]}  {DIFFICULTY_LABEL_JA[difficulty]}　{count}問"
        )
        line_y -= 26
    pg.next()

    # 3. 問題（1ページ1問）
    label_font = 16
    band = label_font * 3.0  # 迷路の上下に「スタート」「ゴール」を置く帯
    header_h = 60
    footer_h = 40
    for i, record in enumerate(puzzles, start=1):
        top_y = pg.page_h - pg.top
        c.setFont(FONT_BOLD, 22)
        c.drawString(pg.left, top_y - 22, f"問題 {i}")
        c.setFont(FONT_REGULAR, 14)
        c.drawRightString(
            pg.right,
            top_y - 20,
            f"{DIFFICULTY_STARS[record['difficulty']]} {DIFFICULTY_LABEL_JA[record['difficulty']]}",
        )
        box_x = pg.left
        box_y = pg.bottom + footer_h + band
        box_w = pg.content_w
        box_h = top_y - header_h - band - box_y
        draw_maze(c, record, x=box_x, y=box_y, w=box_w, h=box_h, show_solution=False)
        _draw_arrow_label(c, record, x=box_x, y=box_y, w=box_w, h=box_h, font_size=label_font)
        c.setFont(FONT_REGULAR, 12)
        c.drawRightString(pg.right, pg.bottom + 6, "できた日　　月　　日")
        pg.next()

    # 4. 解答（1ページ4問）
    gap = 0.35 * inch
    for start in range(0, len(puzzles), ANSWERS_PER_PAGE):
        chunk = puzzles[start : start + ANSWERS_PER_PAGE]
        top_y = pg.page_h - pg.top
        c.setFont(FONT_BOLD, 20)
        c.drawString(pg.left, top_y - 20, "解答")
        cell_w = (pg.content_w - gap) / 2
        area_top = top_y - 40
        cell_h = (area_top - (pg.bottom + 20) - gap) / 2
        for k, record in enumerate(chunk):
            col, row = k % 2, k // 2
            bx = pg.left + col * (cell_w + gap)
            by = area_top - (row + 1) * cell_h - row * gap
            c.setFont(FONT_BOLD, 12)
            c.drawString(bx, by + cell_h - 12, f"問題 {start + k + 1}")
            draw_maze(
                c, record, x=bx, y=by, w=cell_w, h=cell_h - 20, show_solution=True, line_width=0.8,
                solution_width=0.3 if record["difficulty"] == "hard" else 0.35,
            )
        pg.next()

    # 5. 偶数にそろえるための白ページ → 奥付（最後の左ページ）
    while pg.number < total:
        pg.next(folio=False)
    c.setFont(FONT_BOLD, 16)
    y = pg.bottom + 190
    c.drawString(pg.left, y, spec.title)
    c.setFont(FONT_REGULAR, 11)
    y -= 26
    if spec.edition_date:
        c.drawString(pg.left, y, f"{spec.edition_date}　初版発行")
        y -= 20
    c.drawString(pg.left, y, f"発行　{spec.publisher}")
    y -= 30
    c.setFont(FONT_REGULAR, 10)
    c.drawString(pg.left, y, "本書の迷路はすべてプログラムで作成し、正解の道が1本だけであることを機械で確かめています。")
    y -= 18
    # 同梱の Noto Sans JP には © の字形が無く、四角に化ける（2026-09-26 に紙面で確認）。
    year = spec.edition_date[:4] if spec.edition_date[:4].isdigit() else ""
    c.drawString(pg.left, y, " ".join(t for t in ("Copyright", year, spec.publisher) if t))
    pg.next(folio=False)

    c.save()
    return total


def main() -> None:
    parser = argparse.ArgumentParser(description="迷路パズル本のKDP入稿用 本文PDFを作る")
    parser.add_argument("spec", help="本の設計書（books/*.json）")
    parser.add_argument("--out", default=None, help="省略時は output/<設計書名>-interior.pdf")
    args = parser.parse_args()

    spec = BookSpec.load(args.spec)
    out = Path(args.out or f"output/{Path(args.spec).stem}-interior.pdf")
    out.parent.mkdir(parents=True, exist_ok=True)
    total = build_pdf(generate_puzzles(spec), str(out), spec)
    print(f"{spec.puzzle_count}問・{total}ページ -> {out}")


if __name__ == "__main__":
    main()

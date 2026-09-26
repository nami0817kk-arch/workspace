from pathlib import Path

import pytest
from fontTools.ttLib import TTFont
from pypdf import PdfReader
from puzzle_generator import generate_batch
from reportlab.pdfgen import canvas

import kdp_spec
from build_book import (
    BookSpec,
    build_pdf,
    draw_maze,
    generate_puzzles,
    page_count,
)

_ROOT = Path(__file__).resolve().parent.parent


def _small_spec(**over) -> BookSpec:
    base = dict(
        title="テスト用迷路本",
        subtitle="テスト",
        sections=[("easy", 10), ("medium", 6), ("hard", 5)],
        seed_start=0,
        how_to_play=["スタートからゴールまで進んでください。"],
        edition_date="2026年10月1日",
    )
    base.update(over)
    return BookSpec(**base)


def test_page_count_matches_pdf_and_is_even(tmp_path):
    spec = _small_spec()
    out = tmp_path / "interior.pdf"
    total = build_pdf(generate_puzzles(spec), str(out), spec)

    reader = PdfReader(str(out))
    assert len(reader.pages) == total == page_count(spec)
    assert total % 2 == 0
    assert total >= kdp_spec.MIN_PAGES


def test_page_size_equals_trim(tmp_path):
    spec = _small_spec()
    out = tmp_path / "interior.pdf"
    build_pdf(generate_puzzles(spec), str(out), spec)
    trim = kdp_spec.TRIMS[spec.trim]
    for page in PdfReader(str(out)).pages:
        assert float(page.mediabox.width) == pytest.approx(trim.width_in * 72, abs=0.01)
        assert float(page.mediabox.height) == pytest.approx(trim.height_in * 72, abs=0.01)


def test_rejects_unverified_puzzle(tmp_path):
    spec = _small_spec()
    puzzles = generate_puzzles(spec)
    puzzles[0]["verified"] = False
    with pytest.raises(ValueError):
        build_pdf(puzzles, str(tmp_path / "x.pdf"), spec)


def test_rejects_too_few_pages(tmp_path):
    spec = _small_spec(sections=[("easy", 3)])
    with pytest.raises(ValueError):
        build_pdf(generate_puzzles(spec), str(tmp_path / "x.pdf"), spec)


def test_puzzles_are_ordered_easy_to_hard_and_unique():
    spec = _small_spec()
    puzzles = generate_puzzles(spec)
    order = {"easy": 0, "medium": 1, "hard": 2}
    ranks = [order[p["difficulty"]] for p in puzzles]
    assert ranks == sorted(ranks)
    assert len({p["id"] for p in puzzles}) == len(puzzles)


class _LineRecorder(canvas.Canvas):
    def __init__(self, *a, **kw):
        super().__init__(*a, **kw)
        self.lines = []

    def line(self, x1, y1, x2, y2):
        self.lines.append((round(x1, 3), round(y1, 3), round(x2, 3), round(y2, 3)))
        super().line(x1, y1, x2, y2)


def test_start_and_goal_are_open_on_outer_wall(tmp_path):
    """スタートの上辺とゴールの下辺だけ外周が開いている（入口と出口が紙面で読める）。"""
    record = generate_batch(1, "easy", start_seed=0)[0]
    w, h = record["board"]["width"], record["board"]["height"]
    c = _LineRecorder(str(tmp_path / "x.pdf"), pagesize=(w * 10, h * 10))
    draw_maze(c, record, x=0, y=0, w=w * 10, h=h * 10, show_solution=False)

    top = {ln for ln in c.lines if ln[1] == ln[3] == h * 10}
    bottom = {ln for ln in c.lines if ln[1] == ln[3] == 0}
    assert (0, h * 10, 10, h * 10) not in top  # スタート (0,0) の上辺
    assert len(top) == w - 1
    assert ((w - 1) * 10, 0, w * 10, 0) not in bottom  # ゴールの下辺
    assert len(bottom) == w - 1


def test_every_character_has_a_glyph(tmp_path):
    """同梱フォントに無い字は四角に化ける（© で実際に起きた）。紙面の全文字を字形の有無で確かめる。"""
    spec = BookSpec.load(_ROOT / "books" / "vol1.json")
    spec.edition_date = "2026年10月1日"
    out = tmp_path / "interior.pdf"
    build_pdf(generate_puzzles(spec), str(out), spec)

    cmaps = [
        TTFont(str(_ROOT / "assets" / "fonts" / name)).getBestCmap()
        for name in ("NotoSansJP-Regular.ttf", "NotoSansJP-Bold.ttf")
    ]
    text = "".join(page.extract_text() for page in PdfReader(str(out)).pages)
    missing = {ch for ch in text if not ch.isspace() and not all(ord(ch) in cm for cm in cmaps)}
    assert not missing, f"字形が無い文字: {sorted(missing)}"


def test_vol1_stays_in_flat_print_cost():
    """vol1 は印刷コストが固定費だけで済む 108 ページ以下に収める（ページを足すと1冊あたりの印税が減る）。"""
    spec = BookSpec.load(_ROOT / "books" / "vol1.json")
    assert page_count(spec) <= kdp_spec.LARGE_FLAT_MAX_PAGES

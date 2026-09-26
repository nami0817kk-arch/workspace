from pathlib import Path

import pytest
from fontTools.ttLib import TTFont
from pypdf import PdfReader
from puzzle_generator import find_all, verify_wordsearch

import kdp_spec
from build_kotoba import KotobaSpec, build_cover, build_pdf, generate_puzzles, page_count

_ROOT = Path(__file__).resolve().parent.parent
_SPEC = _ROOT / "books" / "kotoba-vol1.json"


@pytest.fixture(scope="module")
def built(tmp_path_factory):
    spec = KotobaSpec.load(_SPEC)
    spec.edition_date = "2026年10月1日"
    puzzles = generate_puzzles(spec)
    d = tmp_path_factory.mktemp("kotoba")
    interior, cover = d / "interior.pdf", d / "cover.pdf"
    total = build_pdf(puzzles, str(interior), spec)
    build_cover(spec, puzzles, str(cover))
    return spec, puzzles, interior, cover, total


def test_every_puzzle_verified_and_words_once(built):
    _, puzzles, *_ = built
    assert len(puzzles) == 60
    for rec in puzzles:
        assert verify_wordsearch(rec)
        for w in rec["board"]["words"]:
            assert len(find_all(rec["board"]["grid"], w["answer"])) == 1


def test_page_count_and_size(built):
    spec, _, interior, _, total = built
    reader = PdfReader(str(interior))
    assert len(reader.pages) == total == page_count(spec)
    assert total % 2 == 0
    assert kdp_spec.MIN_PAGES <= total <= kdp_spec.LARGE_FLAT_MAX_PAGES
    trim = kdp_spec.TRIMS[spec.trim]
    box = reader.pages[0].mediabox
    assert float(box.width) == pytest.approx(trim.width_in * 72, abs=0.01)


def test_cover_size_follows_kdp_formula(built):
    spec, _, _, cover, total = built
    trim = kdp_spec.TRIMS[spec.trim]
    box = PdfReader(str(cover)).pages[0].mediabox
    spine_per_page = 0.002347 if spec.ink == "premium" else 0.002252  # プレミアムカラーは背が厚い
    assert float(box.width) == pytest.approx((0.25 + trim.width_in * 2 + total * spine_per_page) * 72, abs=0.05)
    assert float(box.height) == pytest.approx((0.25 + trim.height_in) * 72, abs=0.05)


def test_every_character_has_a_glyph(built):
    """同梱フォントに無い字（↘ や ©）は四角に化ける。本文と表紙の全文字を確かめる。"""
    _, _, interior, cover, _ = built
    cmaps = [
        TTFont(str(_ROOT / "assets" / "fonts" / n)).getBestCmap()
        for n in ("NotoSansJP-Regular.ttf", "NotoSansJP-Bold.ttf")
    ]
    text = "".join(p.extract_text() for f in (interior, cover) for p in PdfReader(str(f)).pages)
    missing = {ch for ch in text if not ch.isspace() and not all(ord(ch) in cm for cm in cmaps)}
    assert not missing, f"字形が無い文字: {sorted(missing)}"


def test_themes_must_be_in_order(tmp_path):
    spec = KotobaSpec.load(_SPEC)
    spec.themes = [spec.themes[-1], spec.themes[0]]
    with pytest.raises(ValueError):
        generate_puzzles(spec)


def test_premium_color_cost_table():
    """A4 のカラーはプレミアムカラーのみ。42ページ以上は 206円 + 5円/ページ（topic/G201834340）。"""
    assert kdp_spec.print_cost_jpy(78, "premium") == 596
    assert kdp_spec.print_cost_jpy(40, "premium") == 475
    assert kdp_spec.royalty_jpy(1200, 78, "premium") == pytest.approx(124)
    assert kdp_spec.print_cost_jpy(78) == 530


def test_no_word_repeats_across_the_book():
    """同じ言葉が別の問題にまた出ると、買った人には手抜きに見える（最初の版で24語が重複していた）。"""
    spec = KotobaSpec.load(_SPEC)
    answers = [w["answer"] for t in spec.themes for w in t["words"]]
    dup = sorted({a for a in answers if answers.count(a) > 1})
    assert not dup, dup
    themes = [t["theme"] for t in spec.themes]
    assert len(set(themes)) == len(themes)

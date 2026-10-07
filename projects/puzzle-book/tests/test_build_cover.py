from pathlib import Path

import pytest
from pypdf import PdfReader

import kdp_spec
from build_book import BookSpec, page_count
from build_cover import build_cover, cover_size_in, spec_blurb

_ROOT = Path(__file__).resolve().parent.parent


def test_cover_size_follows_kdp_formula(tmp_path):
    """幅 = 裁ち落とし + 裏 + 背 + 表 + 裁ち落とし、高さ = 裁ち落とし + 高さ + 裁ち落とし。"""
    spec = BookSpec.load(_ROOT / "books" / "vol1.json")
    pages = page_count(spec)
    out = tmp_path / "cover.pdf"
    build_cover(spec, str(out), blurb=spec_blurb(spec))

    trim = kdp_spec.TRIMS[spec.trim]
    expected_w = 0.125 * 2 + trim.width_in * 2 + pages * 0.002252
    expected_h = 0.125 * 2 + trim.height_in
    box = PdfReader(str(out)).pages[0].mediabox
    assert float(box.width) == pytest.approx(expected_w * 72, abs=0.05)
    assert float(box.height) == pytest.approx(expected_h * 72, abs=0.05)
    assert cover_size_in(spec, pages)[0] == pytest.approx(expected_w)


def test_cream_paper_makes_thicker_spine():
    spec = BookSpec.load(_ROOT / "books" / "vol1.json")
    pages = page_count(spec)
    assert cover_size_in(spec, pages, "cream")[2] > cover_size_in(spec, pages, "white")[2]

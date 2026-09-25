import math

from pypdf import PdfReader
from puzzle_generator import generate_batch

from build_book import build_pdf


def test_build_pdf_has_expected_page_count(tmp_path):
    count = 5
    puzzles = generate_batch(count, "easy", start_seed=0)
    out = tmp_path / "interior.pdf"

    build_pdf(puzzles, str(out), title="テスト用迷路本")

    reader = PdfReader(str(out))
    answer_pages = math.ceil(count / 4)
    expected = 1 + count + answer_pages  # 表題 + 問題 + 解答
    assert len(reader.pages) == expected


def test_build_pdf_rejects_unverified_puzzle(tmp_path):
    puzzles = generate_batch(2, "easy", start_seed=0)
    puzzles[0]["verified"] = False
    out = tmp_path / "interior.pdf"

    try:
        build_pdf(puzzles, str(out), title="テスト用迷路本")
    except ValueError:
        pass
    else:
        raise AssertionError("verified=False のレコードを弾かなかった")

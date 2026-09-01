"""docparse の中身（データ型・検索・表の整形）。PDF ライブラリには触らない。"""

from __future__ import annotations

import pytest

from docparse import search, tables
from docparse.document import Document, Page, parse_pages

DOCUMENT = Document(
    path="決算短信.pdf",
    pages=[
        Page(number=1, text="表紙\n2026年3月期 決算短信"),
        Page(number=2, text="営業利益 1,234\n経常利益 △567\n売上高 12,345,678"),
    ],
)


# --- ページ範囲 -------------------------------------------------------
def test_parse_pages_handles_ranges_and_lists():
    assert parse_pages("1-3,5") == [1, 2, 3, 5]


def test_parse_pages_sorts_and_dedupes():
    assert parse_pages("5,1,2-3,5") == [1, 2, 3, 5]


def test_parse_pages_none_means_all():
    assert parse_pages(None) is None
    assert parse_pages("  ") is None


def test_parse_pages_rejects_garbage():
    with pytest.raises(ValueError, match="ページの指定"):
        parse_pages("さいしょ")


def test_parse_pages_rejects_zero():
    with pytest.raises(ValueError, match="1から"):
        parse_pages("0-2")


def test_parse_pages_rejects_a_reversed_range():
    with pytest.raises(ValueError, match="逆"):
        parse_pages("5-2")


# --- データ型 ---------------------------------------------------------
def test_lines_drop_blanks():
    assert Page(number=1, text="あ\n\n  \nい").lines == ["あ", "い"]


def test_text_marks_where_pages_break():
    """引用するときにページ番号が要るので、連結しても切れ目を残す。"""
    assert "--- p.2 ---" in DOCUMENT.text


def test_page_lookup():
    assert DOCUMENT.page(2).lines[0] == "営業利益 1,234"
    assert DOCUMENT.page(99) is None


def test_has_text_layer_is_false_for_a_scan():
    scanned = Document(pages=[Page(number=1, text="   "), Page(number=2, text="")])
    assert not scanned.has_text_layer
    assert DOCUMENT.has_text_layer


def test_tables_come_with_their_page_number():
    document = Document(pages=[Page(number=3, tables=[[["a", "b"]]])])
    assert document.tables() == [(3, [["a", "b"]])]


# --- 検索 -------------------------------------------------------------
def test_find_returns_the_page_number():
    hits = search.find(DOCUMENT, "営業利益")
    assert len(hits) == 1
    assert hits[0].page == 2
    assert hits[0].describe().startswith("p.2")


def test_find_is_case_insensitive():
    document = Document(pages=[Page(number=1, text="Operating Income 100")])
    assert search.find(document, "operating income")[0].page == 1


def test_find_respects_the_limit():
    document = Document(pages=[Page(number=1, text="利益\n利益\n利益")])
    assert len(search.find(document, "利益", limit=2)) == 2


def test_find_needs_a_word():
    with pytest.raises(ValueError, match="探す語"):
        search.find(DOCUMENT, "  ")


def test_numbers_are_returned_as_written():
    hits = search.find(DOCUMENT, "経常利益")
    assert hits[0].numbers == ["△567"]  # 原文の表記を保つ


def test_triangle_means_negative():
    """決算資料の負数は △ や ▲ で書かれる。素直に読むと符号が消える。"""
    assert search.to_float("△567") == -567.0
    assert search.to_float("▲1,234") == -1234.0
    assert search.to_float("−89") == -89.0  # 全角マイナス


def test_thousands_separators_are_removed():
    assert search.to_float("12,345,678") == 12345678.0
    assert search.to_float("1.5") == 1.5


def test_unreadable_numbers_are_none_not_zero():
    """0 と「読めなかった」は違う。取り違えると集計が狂う。"""
    assert search.to_float("－") is None
    assert search.to_float("") is None
    assert search.to_float("なし") is None


def test_numbers_in_picks_every_figure():
    assert search.numbers_in("売上 1,000 営業利益 △50") == ["1,000", "△50"]


# --- 表 ---------------------------------------------------------------
def test_normalize_fills_short_rows():
    """結合セルで行ごとの列数がずれる。短い行を捨てると数字が落ちる。"""
    assert tables.normalize([["a", "b", "c"], ["d"]]) == [["a", "b", "c"], ["d", "", ""]]


def test_normalize_replaces_none_and_squeezes_newlines():
    assert tables.normalize([[None, "営業\n利益"]]) == [["", "営業 利益"]]


def test_normalize_ignores_broken_rows():
    assert tables.normalize(["文字列", None, ["a"]]) == [["a"]]


def test_csv_output():
    assert tables.to_csv([["科目", "金額"], ["営業利益", "1,234"]]) == (
        '科目,金額\n営業利益,"1,234"\n'
    )


def test_markdown_output():
    text = tables.to_markdown([["科目", "金額"], ["営業利益", "1,234"]])
    assert text.splitlines()[0] == "| 科目 | 金額 |"
    assert text.splitlines()[1] == "|---|---|"


def test_markdown_escapes_pipes():
    assert "a\\|b" in tables.to_markdown([["a|b"], ["c"]])


def test_empty_tables_are_detected():
    """罫線だけを拾った表が並ぶと、中身のある表が埋もれる。"""
    assert tables.is_empty([["", ""], [None, "  "]])
    assert not tables.is_empty([["", "1"]])

"""control.py に足した PDF 保存とリンク一覧（Chrome を起動せずに確かめられる部分）。"""

from __future__ import annotations

import base64
from pathlib import Path

import pytest

from browser import control


# --- PDF --------------------------------------------------------------
def test_decode_pdf_returns_bytes():
    payload = base64.b64encode(b"%PDF-1.4 dummy").decode()
    assert control.decode_pdf({"data": payload}) == b"%PDF-1.4 dummy"


def test_decode_pdf_reports_an_empty_result():
    """読み込み途中だと data が空で返ることがある。黙って0バイトを書かない。"""
    with pytest.raises(ValueError, match="PDF が返ってこなかった"):
        control.decode_pdf({})


def test_paper_sizes_are_inches():
    """CDP の printToPDF はインチで受ける（mm を渡すと巨大な紙になる）。"""
    width, height = control.PAPER_SIZES["a4"]
    assert 8 < width < 9 and 11 < height < 12


def test_pdf_needs_an_output_path():
    with pytest.raises(SystemExit):
        control.build_parser().parse_args(["pdf"])


def test_pdf_defaults_to_a4_portrait_with_background():
    args = control.build_parser().parse_args(["pdf", "out.pdf"])
    assert args.paper == "a4"
    assert args.landscape is False
    assert args.no_background is False  # 既定では見た目どおりに残す
    assert args.path == Path("out.pdf")


# --- リンク一覧 -------------------------------------------------------
def test_collect_links_accepts_both_shapes():
    raw = [{"text": " 決算短信 ", "href": "https://x.jp/a.pdf"}, ["補足", "https://x.jp/b.pdf"]]
    assert control.collect_links(raw) == [
        ("決算短信", "https://x.jp/a.pdf"),
        ("補足", "https://x.jp/b.pdf"),
    ]


def test_collect_links_squeezes_whitespace():
    raw = [{"text": "決算\n  短信", "href": "https://x.jp/a.pdf"}]
    assert control.collect_links(raw)[0][0] == "決算 短信"


def test_collect_links_drops_javascript_and_empty_hrefs():
    raw = [
        {"text": "開く", "href": "javascript:void(0)"},
        {"text": "空", "href": ""},
        {"text": "本物", "href": "https://x.jp/a.pdf"},
    ]
    assert [url for _text, url in control.collect_links(raw)] == ["https://x.jp/a.pdf"]


def test_collect_links_ignores_broken_entries():
    assert control.collect_links([None, "文字列だけ", 42]) == []


def test_filter_links_matches_url_or_text():
    links = [("決算短信", "https://x.jp/a.pdf"), ("会社概要", "https://x.jp/about.html")]
    assert control.filter_links(links, ".pdf") == [("決算短信", "https://x.jp/a.pdf")]
    assert control.filter_links(links, "会社") == [("会社概要", "https://x.jp/about.html")]


def test_filter_links_is_case_insensitive():
    links = [("Report", "https://x.jp/A.PDF")]
    assert control.filter_links(links, ".pdf") == links


def test_filter_links_removes_duplicate_urls():
    """同じ PDF への導線が何本も並ぶので、落とさないと一覧が読めない。"""
    links = [
        ("決算短信", "https://x.jp/a.pdf"),
        ("こちら", "https://x.jp/a.pdf"),
        ("補足資料", "https://x.jp/b.pdf"),
    ]
    assert control.filter_links(links, None) == [
        ("決算短信", "https://x.jp/a.pdf"),
        ("補足資料", "https://x.jp/b.pdf"),
    ]


def test_filter_links_without_a_needle_keeps_everything():
    links = [("A", "https://x.jp/a"), ("B", "https://x.jp/b")]
    assert control.filter_links(links, "") == links


def test_links_command_defaults():
    args = control.build_parser().parse_args(["links"])
    assert args.filter is None
    assert args.limit == 50


# --- 登録 -------------------------------------------------------------
def test_new_commands_are_registered():
    assert {"pdf", "links"} <= set(control.COMMANDS)

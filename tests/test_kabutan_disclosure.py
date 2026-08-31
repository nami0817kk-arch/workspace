"""開示一覧HTMLの解析まわりのテスト。

取得先の構造が変わると、例外ではなく「0件」という形で静かに壊れるので、
想定している形をネットワークに出ずに固定しておく。
"""
from src.data.kabutan_disclosure import extract_pdf_links_from_html


def _page(links: list[str]) -> str:
    body = "".join(f'<a href="{u}">開示資料{i}</a>' for i, u in enumerate(links))
    return f"<html><body>{body}</body></html>"


def test_extracts_only_tdnet_pdf_links():
    html = _page([
        "https://tdnet-pdf.kabutan.jp/20260901/140120260901000001.pdf",
        "https://example.com/other.pdf",
    ])
    items = extract_pdf_links_from_html(html)
    assert len(items) == 1
    assert items[0]["pdf_url"].startswith("https://tdnet-pdf.kabutan.jp/")
    assert items[0]["title"] == "開示資料0"


def test_deduplicates_same_link():
    url = "https://tdnet-pdf.kabutan.jp/20260901/140120260901000001.pdf"
    items = extract_pdf_links_from_html(_page([url, url]))
    assert len(items) == 1


def test_no_links_returns_empty_list_instead_of_raising():
    assert extract_pdf_links_from_html("<html><body>メンテナンス中</body></html>") == []

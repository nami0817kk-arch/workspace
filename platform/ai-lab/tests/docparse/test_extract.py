"""読み取り（extract）と CLI。

読み取り部分は差し替えで確かめたうえで、**本物の PDF を1枚組み立てて**
実際に pdfplumber で読めるところまで確かめる。
"""

from __future__ import annotations

import json

import pytest

from docparse import cli, extract
from docparse.errors import DependencyMissing, DocparseError

RAW = [
    {
        "number": 1,
        "text": "表紙\n2026年3月期 決算短信",
        "tables": [],
        "total": 2,
        "metadata": {"Title": "決算短信"},
    },
    {
        "number": 2,
        "text": "営業利益 1,234",
        "tables": [[["科目", "金額"], ["営業利益", "1,234"]], [["", ""], [None, " "]]],
        "total": 2,
        "metadata": {"Title": "決算短信"},
    },
]


# --- 読み取り ---------------------------------------------------------
def test_load_builds_pages_and_meta(fake_extractor):
    document = extract.load("x.pdf", extractor=fake_extractor(RAW))
    assert document.page_count == 2
    assert document.meta["page_count"] == 2
    assert document.meta["Title"] == "決算短信"


def test_load_drops_tables_that_are_only_ruled_lines(fake_extractor):
    document = extract.load("x.pdf", extractor=fake_extractor(RAW))
    assert len(document.tables()) == 1  # 空の表は落とす
    assert document.tables()[0][0] == 2  # ページ番号つき


def test_load_normalizes_tables(fake_extractor):
    raw = [{"number": 1, "text": "t", "tables": [[["a", "b"], [None]]], "total": 1}]
    assert extract.load("x.pdf", extractor=fake_extractor(raw)).tables()[0][1] == [
        ["a", "b"],
        ["", ""],
    ]


def test_load_can_limit_the_pages(fake_extractor):
    document = extract.load("x.pdf", pages=[2], extractor=fake_extractor(RAW))
    assert [page.number for page in document.pages] == [2]


def test_load_reports_a_missing_file(tmp_path):
    with pytest.raises(DocparseError, match="ファイルがありません"):
        extract.load(tmp_path / "nope.pdf")


def test_missing_dependency_explains_how_to_install(monkeypatch):
    import builtins

    real_import = builtins.__import__

    def refuse(name, *args, **kwargs):
        if name == "pdfplumber":
            raise ImportError("no module")
        return real_import(name, *args, **kwargs)

    monkeypatch.setattr(builtins, "__import__", refuse)
    with pytest.raises(DependencyMissing, match="docs"):
        extract.require_pdfplumber()


# --- 本物の PDF -------------------------------------------------------
def test_reads_a_real_pdf(sample_pdf):
    """PDF を読む道具なので、PDF を1度も読まないテストで終わらせない。"""
    pytest.importorskip("pdfplumber")
    document = extract.load(sample_pdf)

    assert document.page_count == 1
    assert document.has_text_layer
    assert "Operating income 1,234" in document.text


def test_rejects_a_page_that_does_not_exist(sample_pdf):
    pytest.importorskip("pdfplumber")
    with pytest.raises(DocparseError, match="ページ目はありません"):
        extract.load(sample_pdf, pages=[5])


# --- CLI --------------------------------------------------------------
def test_info_reports_the_shape(sample_pdf, capsys):
    pytest.importorskip("pdfplumber")
    assert cli.main(["info", str(sample_pdf)]) == 0
    out = capsys.readouterr().out
    assert "ページ数 : 1" in out
    assert "文字     : あり" in out


def test_info_json(sample_pdf, capsys):
    pytest.importorskip("pdfplumber")
    assert cli.main(["info", str(sample_pdf), "--json"]) == 0
    payload = json.loads(capsys.readouterr().out)
    assert payload["pages"] == 1 and payload["has_text_layer"] is True


def test_text_writes_a_file(sample_pdf, tmp_path, capsys):
    pytest.importorskip("pdfplumber")
    out = tmp_path / "text.txt"
    assert cli.main(["text", str(sample_pdf), "-o", str(out)]) == 0
    assert "Operating income" in out.read_text(encoding="utf-8")


def test_find_reports_the_page_and_the_values(sample_pdf, capsys):
    pytest.importorskip("pdfplumber")
    assert cli.main(["find", str(sample_pdf), "Operating"]) == 0
    out = capsys.readouterr().out
    assert "p.1" in out
    assert "1,234=1234.0" in out  # 原文の表記と数値の両方を出す


def test_find_returns_1_when_nothing_matches(sample_pdf, capsys):
    pytest.importorskip("pdfplumber")
    assert cli.main(["find", str(sample_pdf), "存在しない語"]) == 1


def test_tables_says_so_when_there_are_none(sample_pdf, capsys):
    pytest.importorskip("pdfplumber")
    assert cli.main(["tables", str(sample_pdf)]) == 1
    assert "表が見つかりません" in capsys.readouterr().out


def test_scanned_pdf_is_refused(monkeypatch, tmp_path, capsys):
    """文字の無い PDF に黙って空を返すと、読み落としに気づけない。"""
    from docparse.document import Document, Page

    monkeypatch.setattr(
        cli.extract, "load", lambda *args, **kwargs: Document(pages=[Page(number=1, text="")])
    )
    assert cli.main(["text", str(tmp_path / "scan.pdf")]) == 1
    assert "OCR" in capsys.readouterr().err


def test_bad_page_spec_is_reported(sample_pdf, capsys):
    assert cli.main(["text", str(sample_pdf), "--pages", "さいしょ"]) == 1
    assert "ページの指定" in capsys.readouterr().err

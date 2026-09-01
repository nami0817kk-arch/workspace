"""CLI の出力（表の書き出し・標準出力・JSON）。読み取りは差し替えて確かめる。"""

from __future__ import annotations

import json

import pytest

from docparse import cli
from docparse.document import Document, Page

TABLE = [["科目", "金額"], ["営業利益", "1,234"]]


@pytest.fixture
def document(monkeypatch):
    """表と本文を持つ PDF の代わり。"""
    loaded = Document(
        path="決算短信.pdf",
        pages=[
            Page(number=1, text="表紙"),
            Page(number=2, text="営業利益 1,234", tables=[TABLE]),
        ],
        meta={"page_count": 2},
    )
    monkeypatch.setattr(cli.extract, "load", lambda *args, **kwargs: loaded)
    return loaded


def test_text_goes_to_stdout(document, capsys):
    assert cli.main(["text", "決算短信.pdf"]) == 0
    out = capsys.readouterr().out
    assert "--- p.2 ---" in out  # 連結してもページの切れ目を残す


def test_tables_print_as_csv(document, capsys):
    assert cli.main(["tables", "決算短信.pdf"]) == 0
    out = capsys.readouterr().out
    assert "--- p.2 ---" in out
    assert '営業利益,"1,234"' in out


def test_tables_print_as_markdown(document, capsys):
    assert cli.main(["tables", "決算短信.pdf", "--format", "markdown"]) == 0
    assert "| 科目 | 金額 |" in capsys.readouterr().out


def test_tables_write_one_file_each(document, tmp_path, capsys):
    assert cli.main(["tables", "決算短信.pdf", "-d", str(tmp_path)]) == 0
    files = sorted(path.name for path in tmp_path.glob("*.csv"))
    assert files == ["決算短信_p2_1.csv"]  # ファイル名にページ番号を残す
    assert "1,234" in (tmp_path / files[0]).read_text(encoding="utf-8")


def test_tables_write_markdown_files(document, tmp_path):
    assert cli.main(["tables", "決算短信.pdf", "-d", str(tmp_path), "--format", "markdown"]) == 0
    assert [path.suffix for path in tmp_path.iterdir()] == [".md"]


def test_find_json_output(document, capsys):
    assert cli.main(["find", "決算短信.pdf", "営業利益", "--json"]) == 0
    payload = json.loads(capsys.readouterr().out)
    assert payload[0]["page"] == 2
    assert payload[0]["numbers"] == ["1,234"]


def test_find_json_returns_1_when_empty(document, capsys):
    assert cli.main(["find", "決算短信.pdf", "存在しない語", "--json"]) == 1
    assert json.loads(capsys.readouterr().out) == []


def test_info_reports_a_scanned_pdf(monkeypatch, capsys):
    """文字の無い PDF は info でも失敗として返す（見落とさないため）。"""
    scanned = Document(path="scan.pdf", pages=[Page(number=1, text="")])
    monkeypatch.setattr(cli.extract, "load", lambda *args, **kwargs: scanned)
    assert cli.main(["info", "scan.pdf"]) == 1
    assert "OCR" in capsys.readouterr().out

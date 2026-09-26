import json
import zipfile
from xml.etree import ElementTree

import pytest

from build_epub import build_epub, char_count, load_book, parse_chapter, ruby


def _book_dir(tmp_path):
    d = tmp_path / "sample"
    d.mkdir()
    (d / "book.json").write_text(
        json.dumps({"title": "見本の物語", "author": "見本 著者", "series": "見本シリーズ"}, ensure_ascii=False),
        encoding="utf-8",
    )
    (d / "01-hajimari.txt").write_text(
        "# 第一話　はじまり\n\n|公爵令嬢《こうしゃくれいじょう》は顔を上げた。\n\n「婚約を破棄する」\n\n* * *\n\n翌朝、屋敷は空だった。\n",
        encoding="utf-8",
    )
    (d / "02-tsuzuki.txt").write_text("# 第二話　つづき\n\n辺境《へんきょう》の朝は早い。<b>は字のまま</b>\n", encoding="utf-8")
    return d


def test_ruby_both_styles_and_escape():
    assert ruby("|公爵令嬢《こうしゃくれいじょう》") == "<ruby>公爵令嬢<rt>こうしゃくれいじょう</rt></ruby>"
    assert ruby("辺境《へんきょう》の朝") == "<ruby>辺境<rt>へんきょう</rt></ruby>の朝"
    assert ruby("a<b>&") == "a&lt;b&gt;&amp;"


def test_chapter_needs_title_line():
    with pytest.raises(ValueError):
        parse_chapter("本文だけ")


def test_epub_structure(tmp_path):
    book = load_book(_book_dir(tmp_path))
    out = build_epub(book, tmp_path / "out.epub")
    with zipfile.ZipFile(out) as z:
        infos = z.infolist()
        assert infos[0].filename == "mimetype"
        assert infos[0].compress_type == zipfile.ZIP_STORED
        assert z.read("mimetype") == b"application/epub+zip"
        # すべての XHTML・OPF が整形式の XML であること
        for name in z.namelist():
            if name.endswith((".xhtml", ".opf", ".xml")):
                ElementTree.fromstring(z.read(name))
        opf = z.read("OEBPS/content.opf").decode()
        assert 'page-progression-direction="rtl"' in opf
        assert "<dc:language>ja</dc:language>" in opf
        assert "見本シリーズ" in opf
        ch1 = z.read("OEBPS/ch01.xhtml").decode()
        assert "<ruby>公爵令嬢<rt>こうしゃくれいじょう</rt></ruby>" in ch1
        assert '<p class="break">' in ch1
        assert "vertical-rl" in z.read("OEBPS/style.css").decode()


def test_char_count_ignores_ruby_reading(tmp_path):
    book = load_book(_book_dir(tmp_path))
    assert char_count(book) < 70
    assert char_count(book) > 30

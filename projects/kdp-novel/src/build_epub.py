"""原稿（テキスト）から、Kindle 用の縦書き EPUB3 を組む。

原稿の書き方（`books/<slug>/` に置く）:
- `book.json`: 題名・著者名・シリーズ名など
- `NN-*.txt`: 章ごとの本文。1行目を `# 章題` にする。段落は空行で区切る
- ルビは小説投稿サイトと同じ書き方: `|漢字《かんじ》`。漢字だけの語なら `漢字《かんじ》` でもよい
- 場面転換は `* * *` だけの行

外部ライブラリは使わない（標準ライブラリの zipfile で組む）。
"""

from __future__ import annotations

import argparse
import datetime as dt
import html
import json
import re
import uuid
import zipfile
from dataclasses import dataclass, field
from pathlib import Path

_RUBY_EXPLICIT = re.compile(r"[|｜]([^|｜《》\n]+?)《([^《》\n]+?)》")
_RUBY_KANJI = re.compile(r"([々〆ヵヶ一-鿿]+)《([^《》\n]+?)》")


@dataclass
class Chapter:
    title: str
    paragraphs: list[str]


@dataclass
class Book:
    title: str
    author: str
    publisher: str = "つるはし社"
    language: str = "ja"
    series: str = ""
    description: str = ""
    identifier: str = ""
    chapters: list[Chapter] = field(default_factory=list)


def ruby(text: str) -> str:
    """エスケープしてからルビを <ruby> に変える。"""
    text = html.escape(text, quote=False)
    text = _RUBY_EXPLICIT.sub(r"<ruby>\1<rt>\2</rt></ruby>", text)
    text = _RUBY_KANJI.sub(r"<ruby>\1<rt>\2</rt></ruby>", text)
    return text


def parse_chapter(src: str) -> Chapter:
    lines = src.replace("\r\n", "\n").strip("\n").split("\n")
    if not lines or not lines[0].startswith("# "):
        raise ValueError("章の1行目は「# 章題」にすること")
    title = lines[0][2:].strip()
    body = "\n".join(lines[1:]).strip("\n")
    paragraphs = [p.strip("\n") for p in re.split(r"\n\s*\n", body) if p.strip()]
    return Chapter(title=title, paragraphs=paragraphs)


def load_book(book_dir: str | Path) -> Book:
    book_dir = Path(book_dir)
    meta = json.loads((book_dir / "book.json").read_text(encoding="utf-8"))
    chapters = [parse_chapter(p.read_text(encoding="utf-8")) for p in sorted(book_dir.glob("[0-9][0-9]-*.txt"))]
    if not chapters:
        raise ValueError(f"章のファイル（NN-*.txt）が無い: {book_dir}")
    return Book(chapters=chapters, **meta)


def char_count(book: Book) -> int:
    """本文の文字数（ルビの読みと空白を除く）。長さの目安に使う。"""
    total = 0
    for ch in book.chapters:
        for p in ch.paragraphs:
            plain = _RUBY_EXPLICIT.sub(r"\1", p)
            plain = _RUBY_KANJI.sub(r"\1", plain)
            total += len(re.sub(r"\s", "", plain))
    return total


_CSS = """@charset "UTF-8";
html { -epub-writing-mode: vertical-rl; writing-mode: vertical-rl; -webkit-writing-mode: vertical-rl; }
body { font-family: serif; line-height: 1.75; }
h1 { font-size: 1.3em; margin: 0 0 0 2em; }
p { margin: 0; text-indent: 1em; }
p.dialog { text-indent: 0; }
p.break { text-indent: 0; margin: 0 1em; text-align: center; }
rt { font-size: 0.5em; }
"""


def _xhtml(title: str, body: str) -> str:
    return (
        '<?xml version="1.0" encoding="UTF-8"?>\n<!DOCTYPE html>\n'
        '<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops" '
        'xml:lang="ja" lang="ja" class="vrtl">\n'
        f'<head><meta charset="UTF-8"/><title>{html.escape(title)}</title>'
        '<link rel="stylesheet" type="text/css" href="style.css"/></head>\n'
        f"<body>\n{body}\n</body>\n</html>\n"
    )


def chapter_xhtml(ch: Chapter) -> str:
    out = [f"<h1>{ruby(ch.title)}</h1>"]
    for p in ch.paragraphs:
        if p.strip() in ("* * *", "＊＊＊", "◇"):
            out.append('<p class="break">＊</p>')
            continue
        for line in p.split("\n"):
            cls = ' class="dialog"' if line.startswith(("「", "『", "（")) else ""
            out.append(f"<p{cls}>{ruby(line)}</p>")
    return _xhtml(ch.title, "\n".join(out))


def build_epub(book: Book, out_path: str | Path) -> Path:
    out_path = Path(out_path)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    ident = book.identifier or f"urn:uuid:{uuid.uuid5(uuid.NAMESPACE_URL, book.title + book.author)}"
    modified = dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

    files = {f"ch{i:02d}.xhtml": chapter_xhtml(ch) for i, ch in enumerate(book.chapters, start=1)}
    title_page = _xhtml(
        book.title,
        f'<h1>{ruby(book.title)}</h1>\n<p class="dialog">{html.escape(book.author)}</p>',
    )
    nav_items = "\n".join(
        f'<li><a href="ch{i:02d}.xhtml">{html.escape(ch.title)}</a></li>' for i, ch in enumerate(book.chapters, start=1)
    )
    nav = _xhtml("目次", f'<nav epub:type="toc" id="toc"><h1>目次</h1><ol>\n{nav_items}\n</ol></nav>')

    manifest = [
        '<item id="css" href="style.css" media-type="text/css"/>',
        '<item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>',
        '<item id="title" href="title.xhtml" media-type="application/xhtml+xml"/>',
    ] + [f'<item id="{n[:-6]}" href="{n}" media-type="application/xhtml+xml"/>' for n in files]
    spine = ['<itemref idref="title"/>', '<itemref idref="nav"/>'] + [
        f'<itemref idref="{n[:-6]}"/>' for n in files
    ]
    series_meta = (
        f'<meta property="belongs-to-collection" id="series">{html.escape(book.series)}</meta>\n'
        '<meta refines="#series" property="collection-type">series</meta>\n'
        if book.series
        else ""
    )
    opf = f"""<?xml version="1.0" encoding="UTF-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="bookid" xml:lang="ja">
<metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
<dc:identifier id="bookid">{html.escape(ident)}</dc:identifier>
<dc:title>{html.escape(book.title)}</dc:title>
<dc:creator>{html.escape(book.author)}</dc:creator>
<dc:publisher>{html.escape(book.publisher)}</dc:publisher>
<dc:language>{book.language}</dc:language>
<meta property="dcterms:modified">{modified}</meta>
{series_meta}</metadata>
<manifest>
{chr(10).join(manifest)}
</manifest>
<spine page-progression-direction="rtl">
{chr(10).join(spine)}
</spine>
</package>
"""
    container = """<?xml version="1.0" encoding="UTF-8"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
<rootfiles><rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/></rootfiles>
</container>
"""
    with zipfile.ZipFile(out_path, "w") as z:
        # mimetype は先頭・無圧縮（EPUB の決まり）
        z.writestr(zipfile.ZipInfo("mimetype"), "application/epub+zip", compress_type=zipfile.ZIP_STORED)
        z.writestr("META-INF/container.xml", container, compress_type=zipfile.ZIP_DEFLATED)
        z.writestr("OEBPS/content.opf", opf, compress_type=zipfile.ZIP_DEFLATED)
        z.writestr("OEBPS/style.css", _CSS, compress_type=zipfile.ZIP_DEFLATED)
        z.writestr("OEBPS/title.xhtml", title_page, compress_type=zipfile.ZIP_DEFLATED)
        z.writestr("OEBPS/nav.xhtml", nav, compress_type=zipfile.ZIP_DEFLATED)
        for name, body in files.items():
            z.writestr(f"OEBPS/{name}", body, compress_type=zipfile.ZIP_DEFLATED)
    return out_path


def main() -> None:
    parser = argparse.ArgumentParser(description="原稿から Kindle 用の縦書き EPUB を組む")
    parser.add_argument("book_dir", help="books/<slug>")
    parser.add_argument("--out", default=None)
    args = parser.parse_args()
    book = load_book(args.book_dir)
    out = build_epub(book, args.out or f"output/{Path(args.book_dir).name}.epub")
    print(f"{len(book.chapters)}章・{char_count(book):,}字 -> {out}")


if __name__ == "__main__":
    main()

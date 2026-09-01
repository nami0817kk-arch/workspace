"""docparse コマンドラインインターフェース。

    docparse info 資料.pdf              ページ数・文字の有無・表の数を見る
    docparse text 資料.pdf --pages 1-3  本文を出す（ページの切れ目つき）
    docparse tables 資料.pdf -d out/    表を CSV に書き出す
    docparse find 資料.pdf 営業利益     語を含む行をページ番号つきで探す
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from . import __version__, extract, search
from . import tables as tables_module
from .document import parse_pages
from .errors import DocparseError, NoTextLayer


def ensure_utf8_streams() -> None:
    """Windows のコンソールでも日本語を出せるようにする。"""
    for stream in (sys.stdout, sys.stderr):
        reconfigure = getattr(stream, "reconfigure", None)
        if reconfigure is None:
            continue
        try:
            reconfigure(encoding="utf-8", errors="replace")
        except (ValueError, OSError):  # 付け替えられない環境では諦める
            pass


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="docparse",
        description="PDF から本文と表を、ページ番号つきで抜き出す",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    parser.add_argument("--version", action="version", version=f"docparse {__version__}")
    sub = parser.add_subparsers(dest="command", required=True)

    info = sub.add_parser("info", help="ページ数と中身の様子を見る")
    info.add_argument("file")
    info.add_argument("--json", action="store_true", help="JSON で出力する")

    text = sub.add_parser("text", help="本文を出す")
    text.add_argument("file")
    text.add_argument("--pages", default=None, help="読むページ 例: 1-3,5")
    text.add_argument("-o", "--out", default=None, help="ファイルに書き出す")

    table = sub.add_parser("tables", help="表を書き出す")
    table.add_argument("file")
    table.add_argument("--pages", default=None, help="読むページ 例: 1-3,5")
    table.add_argument(
        "--format", dest="fmt", default="csv", choices=["csv", "markdown"], help="出力形式"
    )
    table.add_argument("-d", "--dir", default=None, help="1表1ファイルで書き出す先")

    find = sub.add_parser("find", help="語を含む行をページ番号つきで探す")
    find.add_argument("file")
    find.add_argument("word", help="探す語（例: 営業利益）")
    find.add_argument("--pages", default=None, help="探すページ 例: 1-3,5")
    find.add_argument("-l", "--limit", type=int, default=20, help="最大件数（0 で無制限）")
    find.add_argument("--json", action="store_true", help="JSON で出力する")

    return parser


def _load(args: argparse.Namespace):
    document = extract.load(args.file, pages=parse_pages(getattr(args, "pages", None)))
    if not document.has_text_layer:
        raise NoTextLayer(
            f"{args.file} には文字が入っていません（紙をスキャンした画像の可能性）。"
            "この道具では読めないので、OCR にかけるか、文字入りの版を探してください。"
        )
    return document


def cmd_info(args: argparse.Namespace) -> int:
    document = extract.load(args.file, pages=None)
    table_count = len(document.tables())
    empty_pages = [page.number for page in document.pages if not page.has_text]

    if args.json:
        print(
            json.dumps(
                {
                    "path": document.path,
                    "pages": document.page_count,
                    "has_text_layer": document.has_text_layer,
                    "tables": table_count,
                    "pages_without_text": empty_pages,
                    "meta": document.meta,
                },
                ensure_ascii=False,
                indent=2,
            )
        )
        return 0

    print(f"ファイル : {document.path}")
    print(f"ページ数 : {document.page_count}")
    print(f"表の数   : {table_count}")
    if not document.has_text_layer:
        print("文字     : 入っていません（スキャン画像の可能性。OCR が要ります）")
        return 1
    print(f"文字     : あり（文字の無いページ: {empty_pages or 'なし'}）")
    return 0


def cmd_text(args: argparse.Namespace) -> int:
    document = _load(args)
    if args.out:
        path = Path(args.out)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(document.text, encoding="utf-8")
        print(f"書き出しました: {path}")
        return 0
    print(document.text)
    return 0


def cmd_tables(args: argparse.Namespace) -> int:
    document = _load(args)
    found = document.tables()
    if not found:
        print("表が見つかりませんでした")
        return 1

    render = tables_module.to_csv if args.fmt == "csv" else tables_module.to_markdown
    suffix = ".csv" if args.fmt == "csv" else ".md"

    if not args.dir:
        for page_number, rows in found:
            print(f"--- p.{page_number} ---")
            print(render(rows))
        return 0

    directory = Path(args.dir)
    directory.mkdir(parents=True, exist_ok=True)
    stem = Path(args.file).stem
    for index, (page_number, rows) in enumerate(found, 1):
        path = directory / f"{stem}_p{page_number}_{index}{suffix}"
        path.write_text(render(rows), encoding="utf-8")
        print(f"書き出しました: {path}")
    return 0


def cmd_find(args: argparse.Namespace) -> int:
    document = _load(args)
    hits = search.find(document, args.word, limit=args.limit)

    if args.json:
        print(json.dumps([hit.to_dict() for hit in hits], ensure_ascii=False, indent=2))
        return 0 if hits else 1
    if not hits:
        print(f"「{args.word}」を含む行は見つかりませんでした")
        return 1
    for hit in hits:
        print(hit.describe())
        values = [f"{token}={search.to_float(token)}" for token in hit.numbers]
        if values:
            print(f"       数値: {', '.join(values)}")
    return 0


def main(argv: list[str] | None = None) -> int:
    ensure_utf8_streams()
    args = build_parser().parse_args(argv)
    handlers = {"info": cmd_info, "text": cmd_text, "tables": cmd_tables, "find": cmd_find}
    try:
        return handlers[args.command](args)
    except DocparseError as exc:
        print(f"エラー: {exc}", file=sys.stderr)
        return 1
    except (ValueError, OSError) as exc:
        print(f"エラー: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())

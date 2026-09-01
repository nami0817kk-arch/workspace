"""PDF を読むところ。**外部ライブラリに触るのはこのファイルだけ。**

ここを1枚に閉じておくと、他のモジュール（検索・整形・CLI）は
pdfplumber が入っていない環境でもテストできる。読み取り部分は
差し替え（extractor 引数）でテストする。
"""

from __future__ import annotations

from collections.abc import Callable, Iterable
from pathlib import Path

from .document import Document, Page
from .errors import DependencyMissing, DocparseError
from .tables import is_empty, normalize

#: 1ページぶんの生データ（読み取り部分の戻り値）
RawPage = dict


def require_pdfplumber():
    """pdfplumber を読み込む。入っていなければ入れ方を案内する。"""
    try:
        import pdfplumber
    except ImportError as exc:
        raise DependencyMissing(
            "PDF を読むには pdfplumber が要ります: pip install -e \".[docs]\""
        ) from exc
    return pdfplumber


def pdfplumber_pages(path: str | Path, pages: list[int] | None = None) -> Iterable[RawPage]:
    """pdfplumber で1ページずつ読む。"""
    pdfplumber = require_pdfplumber()

    with pdfplumber.open(str(path)) as pdf:
        total = len(pdf.pages)
        wanted = pages or range(1, total + 1)
        for number in wanted:
            if not 1 <= number <= total:
                raise DocparseError(f"{number}ページ目はありません（全{total}ページ）")
            page = pdf.pages[number - 1]
            yield {
                "number": number,
                "text": page.extract_text() or "",
                "tables": page.extract_tables() or [],
                "total": total,
                "metadata": pdf.metadata or {},
            }


def load(
    path: str | Path,
    *,
    pages: list[int] | None = None,
    extractor: Callable[..., Iterable[RawPage]] | None = None,
) -> Document:
    """PDF を読み込んで Document にする。

    表は読み取った時点で均し、罫線だけを拾った空の表は落とす
    （空の表が並ぶと、本当に中身のある表が埋もれる）。
    """
    target = Path(path)
    if extractor is None and not target.is_file():
        raise DocparseError(f"ファイルがありません: {target}")

    read = extractor or pdfplumber_pages
    collected: list[Page] = []
    meta: dict = {}

    for raw in read(target, pages):
        tables = [normalize(table) for table in raw.get("tables") or []]
        collected.append(
            Page(
                number=int(raw.get("number", len(collected) + 1)),
                text=raw.get("text") or "",
                tables=[table for table in tables if not is_empty(table)],
            )
        )
        if not meta:
            meta = {
                "page_count": raw.get("total", 0),
                **{key: str(value) for key, value in (raw.get("metadata") or {}).items()},
            }

    meta.setdefault("page_count", len(collected))
    return Document(path=str(target), pages=collected, meta=meta)

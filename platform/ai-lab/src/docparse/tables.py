"""抜き出した表の整形（純粋な処理）。

PDF から取れる表は穴だらけで、セルが None だったり、行ごとに列数が違ったり、
セルの中に改行が入っていたりする。そのままでは CSV にも Markdown にもできないので、
均すところをここに集める。
"""

from __future__ import annotations

import csv
import io

Rows = list[list[str]]


def normalize(rows) -> Rows:
    """セルを文字列に均し、列数を最大に揃える。

    PDF の表は結合セルのせいで行ごとの列数がずれる。短い行を捨てると
    数字が落ちるので、**足りないぶんは空欄で埋めて残す**。
    """
    cleaned: Rows = []
    for row in rows or []:
        if not isinstance(row, (list, tuple)):
            continue
        cleaned.append([" ".join(str(cell).split()) if cell is not None else "" for cell in row])

    if not cleaned:
        return []
    width = max(len(row) for row in cleaned)
    return [row + [""] * (width - len(row)) for row in cleaned]


def to_csv(rows) -> str:
    """CSV にする（Excel で開く前提なので改行は CRLF ではなく LF に統一）。"""
    buffer = io.StringIO()
    writer = csv.writer(buffer, lineterminator="\n")
    writer.writerows(normalize(rows))
    return buffer.getvalue()


def to_markdown(rows) -> str:
    """Markdown の表にする（1行目を見出しとして扱う）。"""
    normalized = normalize(rows)
    if not normalized:
        return ""

    header, *body = normalized
    lines = [
        "| " + " | ".join(_escape(cell) for cell in header) + " |",
        "|" + "|".join("---" for _ in header) + "|",
    ]
    lines += ["| " + " | ".join(_escape(cell) for cell in row) + " |" for row in body]
    return "\n".join(lines)


def _escape(cell: str) -> str:
    """表の区切りと衝突する縦棒だけ逃がす。"""
    return (cell or "").replace("|", "\\|")


def is_empty(rows) -> bool:
    """中身が空欄だけの表か（PDF の罫線だけを拾ってしまうことがある）。"""
    return not any(cell.strip() for row in normalize(rows) for cell in row)

"""Markdownの必要十分なサブセットを描画する。

外部依存を増やさないための自前実装。対応するのは
見出し / 段落 / 箇条書き / 番号付き / 表 / 引用 / コードブロック /
インライン(リンク・強調・コード) のみ。未対応記法は素通しせず必ずエスケープする。
"""

from __future__ import annotations

import html
import re

_LINK = re.compile(r"\[([^\]]+)\]\(([^)\s]+)\)")
_BOLD = re.compile(r"\*\*([^*]+)\*\*")
_CODE = re.compile(r"`([^`]+)`")
_PLACEHOLDER = re.compile(r"\x00(\d+)\x00")


def render_inline(text: str) -> str:
    """インライン記法を描画する。コードスパンの中身は記法解釈しない。"""
    spans: list[str] = []

    def stash(match: re.Match) -> str:
        spans.append(f"<code>{html.escape(match.group(1))}</code>")
        return f"\x00{len(spans) - 1}\x00"

    text = _CODE.sub(stash, text)
    text = html.escape(text, quote=False)
    text = _BOLD.sub(lambda m: f"<strong>{m.group(1)}</strong>", text)
    text = _LINK.sub(_render_link, text)
    return _PLACEHOLDER.sub(lambda m: spans[int(m.group(1))], text)


def _render_link(match: re.Match) -> str:
    label, href = match.group(1), match.group(2)
    external = href.startswith(("http://", "https://"))
    attrs = ' target="_blank" rel="noopener nofollow"' if external else ""
    return f'<a href="{html.escape(href, quote=True)}"{attrs}>{label}</a>'


def _render_table(rows: list[str]) -> str:
    def cells(line: str) -> list[str]:
        return [c.strip() for c in line.strip().strip("|").split("|")]

    head = cells(rows[0])
    body = [cells(r) for r in rows[2:]]  # rows[1] は区切り行
    out = ["<table><thead><tr>"]
    out += [f"<th>{render_inline(c)}</th>" for c in head]
    out.append("</tr></thead><tbody>")
    for row in body:
        out.append("<tr>" + "".join(f"<td>{render_inline(c)}</td>" for c in row) + "</tr>")
    out.append("</tbody></table>")
    return "".join(out)


def render(md: str) -> str:
    """Markdown文字列をHTMLに変換する。"""
    return "\n".join(render_blocks(md))


def render_blocks(md: str) -> list[str]:
    """トップレベルのブロック単位でHTMLを返す。

    広告はブロックの隙間にしか挿入しないので、段落単位を保ったまま返す必要がある。
    """
    lines = md.replace("\r\n", "\n").split("\n")
    out: list[str] = []
    buf: list[str] = []
    i = 0

    def flush_paragraph() -> None:
        if buf:
            out.append(f"<p>{render_inline(' '.join(buf))}</p>")
            buf.clear()

    while i < len(lines):
        line = lines[i]
        stripped = line.strip()

        if not stripped:
            flush_paragraph()
            i += 1
            continue

        if stripped.startswith("```"):
            flush_paragraph()
            lang = stripped[3:].strip()
            i += 1
            code: list[str] = []
            while i < len(lines) and not lines[i].strip().startswith("```"):
                code.append(lines[i])
                i += 1
            i += 1
            cls = f' class="lang-{html.escape(lang, quote=True)}"' if lang else ""
            out.append(f"<pre{cls}><code>{html.escape(chr(10).join(code))}</code></pre>")
            continue

        heading = re.match(r"^(#{2,4})\s+(.*)$", stripped)
        if heading:
            flush_paragraph()
            level = len(heading.group(1))
            text = heading.group(2)
            anchor = slugify(text)
            out.append(f'<h{level} id="{anchor}">{render_inline(text)}</h{level}>')
            i += 1
            continue

        if stripped.startswith("|") and i + 1 < len(lines) and set(lines[i + 1].strip()) <= set("|-: "):
            flush_paragraph()
            table = []
            while i < len(lines) and lines[i].strip().startswith("|"):
                table.append(lines[i])
                i += 1
            out.append(_render_table(table))
            continue

        if stripped.startswith(("- ", "* ")):
            flush_paragraph()
            items = []
            while i < len(lines) and lines[i].strip().startswith(("- ", "* ")):
                items.append(lines[i].strip()[2:])
                i += 1
            out.append("<ul>" + "".join(f"<li>{render_inline(t)}</li>" for t in items) + "</ul>")
            continue

        if re.match(r"^\d+\.\s", stripped):
            flush_paragraph()
            items = []
            while i < len(lines) and re.match(r"^\d+\.\s", lines[i].strip()):
                items.append(re.sub(r"^\d+\.\s+", "", lines[i].strip()))
                i += 1
            out.append("<ol>" + "".join(f"<li>{render_inline(t)}</li>" for t in items) + "</ol>")
            continue

        if stripped.startswith("> "):
            flush_paragraph()
            quote = []
            while i < len(lines) and lines[i].strip().startswith("> "):
                quote.append(lines[i].strip()[2:])
                i += 1
            out.append(f"<blockquote><p>{render_inline(' '.join(quote))}</p></blockquote>")
            continue

        buf.append(stripped)
        i += 1

    flush_paragraph()
    return out


def slugify(text: str) -> str:
    """見出しアンカー用のID。日本語はそのまま残す(URLエンコードで通る)。"""
    text = re.sub(r"[<>\"'&\s]+", "-", text.strip().lower())
    return re.sub(r"-+", "-", text).strip("-") or "section"


def word_count(md: str) -> int:
    """広告掲載可否の判定に使う本文量。日本語は文字数、英語は語数で数える。"""
    text = re.sub(r"```.*?```", "", md, flags=re.S)
    text = re.sub(r"[#>*|\-`\[\]()]", " ", text)
    japanese = len(re.findall(r"[぀-ヿ一-鿿]", text))
    latin = len(re.findall(r"[A-Za-z0-9]+", text))
    return japanese + latin

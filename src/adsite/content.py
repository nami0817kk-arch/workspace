"""コンテンツファイルの読み込み。

`---` で囲んだ簡易フロントマター + Markdown本文。YAML依存を避けるため
`key: value` の1階層のみを解釈する（リストはカンマ区切り）。
"""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import date
from pathlib import Path

from .markdown import word_count

_TRUE = {"true", "yes", "1", "on"}
_FALSE = {"false", "no", "0", "off"}


@dataclass
class Page:
    slug: str
    title: str
    description: str
    body_md: str
    source: Path | None = None
    keywords: tuple[str, ...] = ()
    tool: str = ""
    updated: date | None = None
    noindex: bool = False
    ads: bool = True
    priority: float = 0.5

    @property
    def url_path(self) -> str:
        """出力先URL。index はディレクトリのルートに置く。"""
        return "/" if self.slug == "index" else f"/{self.slug}/"

    @property
    def output_path(self) -> str:
        return "index.html" if self.slug == "index" else f"{self.slug}/index.html"

    @property
    def word_count(self) -> int:
        return word_count(self.body_md)

    @property
    def is_tool(self) -> bool:
        return bool(self.tool)


def parse_front_matter(text: str) -> tuple[dict[str, str], str]:
    """フロントマターと本文に分ける。区切りがなければ全体を本文とみなす。"""
    lines = text.replace("\r\n", "\n").split("\n")
    if not lines or lines[0].strip() != "---":
        return {}, text

    meta: dict[str, str] = {}
    for i, line in enumerate(lines[1:], start=1):
        if line.strip() == "---":
            return meta, "\n".join(lines[i + 1 :]).strip("\n")
        if ":" in line:
            key, _, value = line.partition(":")
            meta[key.strip()] = value.strip()
    # 閉じ区切りがない場合は壊れたファイルとして扱い、本文なしで返す。
    return meta, ""


def _bool(value: str, default: bool) -> bool:
    v = value.strip().lower()
    if v in _TRUE:
        return True
    if v in _FALSE:
        return False
    return default


def load_page(path: Path, root: Path) -> Page:
    meta, body = parse_front_matter(path.read_text(encoding="utf-8"))
    rel = path.relative_to(root).with_suffix("")
    slug = meta.get("slug") or "/".join(rel.parts)
    updated = meta.get("updated", "").strip()
    return Page(
        slug=slug,
        title=meta.get("title", slug),
        description=meta.get("description", ""),
        body_md=body,
        source=path,
        keywords=tuple(k.strip() for k in meta.get("keywords", "").split(",") if k.strip()),
        tool=meta.get("tool", "").strip(),
        updated=date.fromisoformat(updated) if updated else None,
        noindex=_bool(meta.get("noindex", ""), False),
        ads=_bool(meta.get("ads", ""), True),
        priority=float(meta.get("priority", 0.5)),
    )


def load_pages(root: str | Path) -> list[Page]:
    """content配下の .md を再帰的に読み込む。index を先頭に、あとはslug順。"""
    root = Path(root)
    if not root.exists():
        return []
    pages = [load_page(p, root) for p in sorted(root.rglob("*.md"))]
    pages.sort(key=lambda p: (p.slug != "index", p.slug))
    return pages

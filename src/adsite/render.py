"""HTMLの組み立て。テンプレートエンジンを入れずに済む規模なので自前で持つ。"""

from __future__ import annotations

import html

from . import ads as ads_mod
from . import seo
from .config import SiteConfig
from .content import Page
from .markdown import render_blocks

TOOL_MARKER = "<p>[[tool]]</p>"


def tool_mount(tool: str) -> str:
    """ツールのマウント先。JSはこの要素を探して描画する。"""
    safe = html.escape(tool, quote=True)
    return f'<div class="tool" data-tool="{safe}"><noscript>この計算ツールの利用にはJavaScriptが必要です。</noscript></div>'


def body_blocks(page: Page) -> list[str]:
    blocks = render_blocks(page.body_md)
    if not page.tool:
        return blocks
    mount = tool_mount(page.tool)
    if TOOL_MARKER in blocks:
        return [mount if b == TOOL_MARKER else b for b in blocks]
    # マーカーがなければ最初の見出しの手前（導入文の直後）に置く。
    return [*blocks[:1], mount, *blocks[1:]]


def nav_html(pages: list[Page], current: Page) -> str:
    links = ['<a href="/">ホーム</a>']
    for page in pages:
        if not page.is_tool or page.noindex:
            continue
        current_attr = ' aria-current="page"' if page.slug == current.slug else ""
        links.append(f'<a href="{page.url_path}"{current_attr}>{html.escape(page.title)}</a>')
    return "<nav>" + "".join(links) + "</nav>"


def footer_html(site: SiteConfig, pages: list[Page]) -> str:
    """AdSenseは連絡先とプライバシーポリシーの掲示を求めるため、常に出す。"""
    links = []
    slugs = {p.slug for p in pages}
    if "privacy" in slugs:
        links.append('<a href="/privacy/">プライバシーポリシー</a>')
    if "about" in slugs:
        links.append('<a href="/about/">運営者情報</a>')
    if site.contact_url:
        links.append(f'<a href="{html.escape(site.contact_url, quote=True)}">お問い合わせ</a>')
    return (
        "<footer><div>"
        + "".join(links)
        + f"</div><p class=\"copy\">&copy; {html.escape(site.author or site.site_name)}</p></footer>"
    )


def render_page(page: Page, site: SiteConfig, pages: list[Page]) -> str:
    blocks = ads_mod.place_ads(body_blocks(page), page, site.ads)
    # 共通ヘルパーを先に読む。どちらも defer なので記述順で実行順が決まる。
    tool_script = (
        '<script src="/assets/tools/_common.js" defer></script>\n'
        f'<script src="/assets/tools/{html.escape(page.tool, quote=True)}.js" defer></script>'
        if page.tool
        else ""
    )
    updated = (
        f'<p class="updated">最終更新: <time datetime="{page.updated.isoformat()}">'
        f"{page.updated.isoformat()}</time></p>"
        if page.updated
        else ""
    )
    return f"""<!doctype html>
<html lang="{html.escape(site.locale, quote=True)}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>{html.escape(page.title)} | {html.escape(site.site_name)}</title>
{seo.meta_tags(page, site)}
<link rel="stylesheet" href="/assets/style.css">
<link rel="icon" href="data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 32 32'%3E%3Crect width='32' height='32' rx='7' fill='%231f5fd4'/%3E%3Ctext x='16' y='23' font-size='19' font-family='sans-serif' font-weight='700' text-anchor='middle' fill='white'%3E%C2%A5%3C/text%3E%3C/svg%3E">
{seo.json_ld(page, site)}
{ads_mod.head_scripts(site.ads)}
{site.analytics_snippet}
</head>
<body>
<header>
<a class="brand" href="/">{html.escape(site.site_name)}</a>
{nav_html(pages, page)}
</header>
<main>
<h1>{html.escape(page.title)}</h1>
{updated}
{chr(10).join(blocks)}
</main>
{footer_html(site, pages)}
{tool_script}
</body>
</html>
"""

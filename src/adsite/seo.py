"""検索流入のための出力物。広告収益はPVに比例するので、ここが売上の入口になる。"""

from __future__ import annotations

import html
import json
from datetime import date

from .config import SiteConfig
from .content import Page


def meta_tags(page: Page, site: SiteConfig) -> str:
    url = site.url(page.url_path)
    esc = lambda s: html.escape(s, quote=True)  # noqa: E731
    tags = [
        f'<meta name="description" content="{esc(page.description)}">',
        f'<link rel="canonical" href="{esc(url)}">',
        f'<meta property="og:type" content="{"website" if page.slug == "index" else "article"}">',
        f'<meta property="og:title" content="{esc(page.title)}">',
        f'<meta property="og:description" content="{esc(page.description)}">',
        f'<meta property="og:url" content="{esc(url)}">',
        f'<meta property="og:site_name" content="{esc(site.site_name)}">',
        f'<meta property="og:locale" content="{esc(site.locale)}">',
        '<meta name="twitter:card" content="summary_large_image">',
    ]
    if page.keywords:
        tags.append(f'<meta name="keywords" content="{esc(", ".join(page.keywords))}">')
    if page.noindex:
        tags.append('<meta name="robots" content="noindex,follow">')
    return "\n".join(tags)


def json_ld(page: Page, site: SiteConfig) -> str:
    """構造化データ。ツールページは SoftwareApplication として申告する。"""
    if page.is_tool:
        data = {
            "@context": "https://schema.org",
            "@type": "SoftwareApplication",
            "name": page.title,
            "description": page.description,
            "url": site.url(page.url_path),
            "applicationCategory": "UtilitiesApplication",
            "operatingSystem": "Any",
            "offers": {"@type": "Offer", "price": "0", "priceCurrency": "JPY"},
        }
    else:
        data = {
            "@context": "https://schema.org",
            "@type": "WebPage",
            "name": page.title,
            "description": page.description,
            "url": site.url(page.url_path),
        }
    if page.updated:
        data["dateModified"] = page.updated.isoformat()
    if site.author:
        data["author"] = {"@type": "Person", "name": site.author}
    return f'<script type="application/ld+json">{json.dumps(data, ensure_ascii=False)}</script>'


def sitemap(pages: list[Page], site: SiteConfig, today: date | None = None) -> str:
    today = today or date.today()
    rows = ['<?xml version="1.0" encoding="UTF-8"?>',
            '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">']
    for page in pages:
        if page.noindex:
            continue
        lastmod = (page.updated or today).isoformat()
        rows += [
            "<url>",
            f"<loc>{html.escape(site.url(page.url_path), quote=True)}</loc>",
            f"<lastmod>{lastmod}</lastmod>",
            f"<priority>{page.priority:.1f}</priority>",
            "</url>",
        ]
    rows.append("</urlset>")
    return "\n".join(rows)


def robots_txt(site: SiteConfig) -> str:
    return "\n".join(
        [
            "User-agent: *",
            "Allow: /",
            "",
            f"Sitemap: {site.url('/sitemap.xml')}",
            "",
        ]
    )

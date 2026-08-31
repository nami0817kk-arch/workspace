"""静的サイトのビルド。出力はそのままGitHub Pages等に置ける。"""

from __future__ import annotations

import json
import re
import shutil
from dataclasses import dataclass, field
from datetime import date
from pathlib import Path

from . import seo
from .ads import ads_allowed
from .config import SiteConfig
from .content import Page, load_pages
from .render import render_page


@dataclass
class BuildReport:
    pages: int = 0
    tools: int = 0
    ad_pages: int = 0
    warnings: list[str] = field(default_factory=list)

    def to_dict(self) -> dict[str, object]:
        return {
            "pages": self.pages,
            "tools": self.tools,
            "ad_pages": self.ad_pages,
            "warnings": self.warnings,
        }


_INTERNAL_LINK = re.compile(r"\]\((/[^)\s]*)\)")


def check_links(pages: list[Page], report: BuildReport) -> None:
    """内部リンク切れと、どこからも辿れないページを検出する。

    リンク切れは訪問者を失うだけでなく、クロールの評価にも効く。
    孤立ページは検索エンジンに見つけてもらえず、PVにならない。
    """
    known = {p.url_path for p in pages}
    inbound: dict[str, int] = {p.url_path: 0 for p in pages}

    for page in pages:
        for href in _INTERNAL_LINK.findall(page.body_md):
            target = href.split("#")[0]
            if target in known:
                inbound[target] += 1
            elif not target.startswith("/assets/"):
                report.warnings.append(f"{page.slug}: リンク切れ {href}")

    # フッターから常に辿れるページは孤立扱いしない。
    always_linked = {"/", "/privacy/", "/about/"}
    for page in pages:
        if page.url_path in always_linked or page.noindex:
            continue
        if inbound[page.url_path] == 0:
            report.warnings.append(f"{page.slug}: どのページからもリンクされていない（検索に拾われにくい）")


def _check(page: Page, site: SiteConfig, report: BuildReport) -> None:
    """公開前に落としておきたい品質問題を警告する。"""
    if not page.description:
        report.warnings.append(f"{page.slug}: description が空（検索結果のスニペットが自動生成になる）")
    elif len(page.description) > 160:
        report.warnings.append(f"{page.slug}: description が長すぎる（{len(page.description)}字、160字以内推奨）")
    if len(page.title) > 60:
        report.warnings.append(f"{page.slug}: title が長すぎる（{len(page.title)}字、60字以内推奨）")
    allowed, reason = ads_allowed(page, site.ads)
    if site.ads.enabled and not allowed and not page.noindex and page.ads:
        report.warnings.append(f"{page.slug}: 広告非掲載（{reason}）")


def price_table_json() -> str:
    """ツールが使うモデル料金表。adsite.pricing を単一の情報源にする。"""
    from .pricing import MODEL_PRICES_USD_PER_MTOK

    return json.dumps(
        {model: {"input": rates[0], "output": rates[1]} for model, rates in MODEL_PRICES_USD_PER_MTOK.items()},
        ensure_ascii=False,
        indent=2,
    )


def build(site: SiteConfig, today: date | None = None) -> BuildReport:
    pages = load_pages(site.content_dir)
    if not pages:
        raise FileNotFoundError(f"コンテンツが1件もありません: {site.content_dir}")

    out = Path(site.output_dir)
    if out.exists():
        shutil.rmtree(out)
    out.mkdir(parents=True, exist_ok=True)

    report = BuildReport()
    check_links(pages, report)
    for page in pages:
        _check(page, site, report)
        target = out / page.output_path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(render_page(page, site, pages), encoding="utf-8")
        report.pages += 1
        if page.is_tool:
            report.tools += 1
        if ads_allowed(page, site.ads)[0]:
            report.ad_pages += 1

    if Path(site.assets_dir).exists():
        shutil.copytree(site.assets_dir, out / "assets", dirs_exist_ok=True)

    (out / "assets" / "data").mkdir(parents=True, exist_ok=True)
    (out / "assets" / "data" / "model-prices.json").write_text(price_table_json(), encoding="utf-8")

    (out / "sitemap.xml").write_text(seo.sitemap(pages, site, today), encoding="utf-8")
    (out / "robots.txt").write_text(seo.robots_txt(site), encoding="utf-8")
    # GitHub Pages がディレクトリを Jekyll 処理しないようにする。
    (out / ".nojekyll").write_text("", encoding="utf-8")
    if site.ads.enabled:
        # AdSense のサイト所有確認に使われるファイル。
        client = site.ads.client.replace("ca-pub-", "pub-")
        (out / "ads.txt").write_text(f"google.com, {client}, DIRECT, f08c47fec0942fa0\n", encoding="utf-8")

    return report

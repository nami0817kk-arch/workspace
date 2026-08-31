from datetime import date
from pathlib import Path

import pytest

from adsite.build import build
from adsite.config import AdsConfig, SiteConfig, parse_site_config
from adsite.content import Page
from adsite.seo import json_ld, meta_tags, robots_txt, sitemap

SITE = SiteConfig(base_url="https://t.example/", site_name="サイト", author="運営者")


def _page(**kw) -> Page:
    defaults = dict(slug="tools/calc", title="計算", description="せつめい", body_md="あ" * 500)
    defaults.update(kw)
    return Page(**defaults)


def _write_site(tmp_path, *, ads: dict | None = None) -> SiteConfig:
    content = tmp_path / "content"
    (content / "tools").mkdir(parents=True, exist_ok=True)
    (content / "index.md").write_text(
        "---\ntitle: トップ\ndescription: せつめい\n---\n" + "本文。" * 200, encoding="utf-8"
    )
    (content / "tools" / "calc.md").write_text(
        "---\ntitle: 計算\ndescription: せつめい\ntool: calc\n---\n導入。\n\n[[tool]]\n\n"
        + "## 節\n\n本文。" * 40,
        encoding="utf-8",
    )
    (content / "privacy.md").write_text(
        "---\ntitle: プライバシー\ndescription: せつめい\nads: false\n---\n短い本文。", encoding="utf-8"
    )
    assets = tmp_path / "assets"
    assets.mkdir(exist_ok=True)
    (assets / "style.css").write_text("body{}", encoding="utf-8")
    return parse_site_config(
        {
            "base_url": "https://t.example",
            "site_name": "サイト",
            "content_dir": str(content),
            "assets_dir": str(assets),
            "output_dir": str(tmp_path / "out"),
            "ads": ads or {},
        }
    )


def test_build_writes_pages_assets_and_seo_files(tmp_path):
    site = _write_site(tmp_path)
    report = build(site)
    out = tmp_path / "out"

    assert report.pages == 3 and report.tools == 1
    assert (out / "index.html").exists()
    assert (out / "tools" / "calc" / "index.html").exists()
    assert (out / "assets" / "style.css").exists()
    assert (out / "assets" / "data" / "model-prices.json").exists()
    assert (out / "sitemap.xml").exists() and (out / "robots.txt").exists()
    assert (out / ".nojekyll").exists()


def test_ads_txt_only_written_when_adsense_configured(tmp_path):
    site = _write_site(tmp_path)
    build(site)
    assert not (tmp_path / "out" / "ads.txt").exists()

    site = _write_site(tmp_path, ads={"client": "ca-pub-999"})
    build(site)
    assert "pub-999" in (tmp_path / "out" / "ads.txt").read_text(encoding="utf-8")


def test_tool_marker_is_replaced_by_mount_point(tmp_path):
    site = _write_site(tmp_path)
    build(site)
    html = (tmp_path / "out" / "tools" / "calc" / "index.html").read_text(encoding="utf-8")
    assert '<div class="tool" data-tool="calc">' in html
    assert "[[tool]]" not in html
    assert '/assets/tools/_common.js' in html and "/assets/tools/calc.js" in html


def test_build_warns_about_missing_description(tmp_path):
    site = _write_site(tmp_path)
    (site.content_dir / "bare.md").write_text("---\ntitle: 説明なし\n---\n本文", encoding="utf-8")
    report = build(site)
    assert any("description が空" in w for w in report.warnings)


def test_build_is_repeatable(tmp_path):
    site = _write_site(tmp_path)
    build(site)
    stale = tmp_path / "out" / "stale.html"
    stale.write_text("old", encoding="utf-8")
    build(site)
    assert not stale.exists()  # 出力先は毎回作り直す


def test_build_fails_loudly_on_empty_content(tmp_path):
    site = parse_site_config({"content_dir": str(tmp_path / "nothing"), "output_dir": str(tmp_path / "out")})
    with pytest.raises(FileNotFoundError):
        build(site)


def test_sitemap_excludes_noindex_pages():
    pages = [_page(), _page(slug="hidden", noindex=True)]
    xml = sitemap(pages, SITE, today=date(2026, 8, 31))
    assert "https://t.example/tools/calc/" in xml
    assert "hidden" not in xml


def test_meta_tags_include_canonical_and_og():
    tags = meta_tags(_page(), SITE)
    assert '<link rel="canonical" href="https://t.example/tools/calc/">' in tags
    assert 'property="og:title" content="計算"' in tags


def test_noindex_page_emits_robots_meta():
    assert 'name="robots" content="noindex,follow"' in meta_tags(_page(noindex=True), SITE)


def test_json_ld_marks_tool_pages_as_software():
    assert '"@type": "SoftwareApplication"' in json_ld(_page(tool="calc"), SITE)
    assert '"@type": "WebPage"' in json_ld(_page(), SITE)


def test_robots_points_at_sitemap():
    assert "Sitemap: https://t.example/sitemap.xml" in robots_txt(SITE)


def test_html_is_escaped_in_meta(tmp_path):
    page = _page(title='悪意"><script>', description="d")
    assert "<script>" not in meta_tags(page, SITE)


def test_broken_internal_links_are_reported(tmp_path):
    site = _write_site(tmp_path)
    (site.content_dir / "linky.md").write_text(
        "---\ntitle: リンク\ndescription: せつめい\n---\n[こわれ](/nope/) と [正常](/tools/calc/)",
        encoding="utf-8",
    )
    report = build(site)
    assert any("リンク切れ /nope/" in w for w in report.warnings)
    assert not any("リンク切れ /tools/calc/" in w for w in report.warnings)


def test_orphan_pages_are_reported(tmp_path):
    site = _write_site(tmp_path)
    (site.content_dir / "lonely.md").write_text(
        "---\ntitle: 孤立\ndescription: せつめい\n---\n本文", encoding="utf-8"
    )
    report = build(site)
    assert any("lonely" in w and "リンクされていない" in w for w in report.warnings)


def test_policy_pages_are_not_treated_as_orphans(tmp_path):
    """privacy と about はフッターから常に辿れるので孤立ではない。"""
    site = _write_site(tmp_path)
    report = build(site)
    assert not any("privacy" in w and "リンクされていない" in w for w in report.warnings)


def test_paths_in_config_are_parsed_as_paths():
    """db_path を取りこぼすと収支データが既定のファイルに書かれてしまう。"""
    site = parse_site_config(
        {"db_path": "/tmp/x/custom.db", "output_dir": "out", "content_dir": "c", "assets_dir": "a"}
    )
    assert site.db_path == Path("/tmp/x/custom.db")
    assert (site.output_dir, site.content_dir, site.assets_dir) == (Path("out"), Path("c"), Path("a"))
    assert parse_site_config({}).db_path == Path("output/adsite.db")


def test_unknown_config_keys_are_ignored():
    site = parse_site_config({"site_name": "S", "future_option": True, "ads": {"client": "c", "unknown": 1}})
    assert site.site_name == "S" and site.ads.client == "c"

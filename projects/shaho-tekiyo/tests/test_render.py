"""生成されたページの中身のテスト。kabu-agari-ranking/tests/test_site_pages.py と同じ観点。"""
import json
import re
from pathlib import Path

import pytest

import eligibility
import premium
import render
import site_config


@pytest.fixture
def site(tmp_path, monkeypatch):
    out_dir = tmp_path / "output"
    monkeypatch.setattr(render, "_OUTPUT_DIR", out_dir)
    render.build_all()
    return out_dir


def test_計算機ページが生成される(site):
    html = (site / "index.html").read_text(encoding="utf-8")
    assert "加入判定チェッカー" in html
    assert 'id="calc-form"' in html


def test_今日時点はビルド時刻を埋め込まずクライアント側で解決する(site):
    """ビルド時刻を埋め込むと、次にビルドし直すまで「今日」が過去の日付に
    固定されたままになる（2026年10月を過ぎても判定が9月のままになりうる）。
    "today" という固定文字列を埋め込み、実際の日付は JS の todayIso() で
    閲覧時に解決する形にしてある。
    """
    html = (site / "index.html").read_text(encoding="utf-8")
    assert '<option value="today"' in html
    assert "function todayIso()" in html
    assert "new Date()" in html


def test_計算機に埋め込まれたスケジュールがeligibilityと一致する(site):
    """JSと Python の判定ロジックが同じ表を見ているかどうかを、埋め込みJSONで固定する。
    2箇所に別々の表を持つと必ずずれる（kabu-agari-ranking の price_limit.py と同じ考え方）。
    """
    html = (site / "index.html").read_text(encoding="utf-8")
    m = re.search(
        r'<script id="schedule-data" type="application/json">(.*?)</script>',
        html, re.S,
    )
    assert m, "schedule-data が見つからない"
    embedded = json.loads(m.group(1))
    expected = [
        {
            "effective_from": r.effective_from.isoformat(),
            "company_size_threshold": r.company_size_threshold,
            "wage_requirement_yen": r.wage_requirement_yen,
            "label": r.label,
        }
        for r in eligibility.SCHEDULE
    ]
    assert embedded == expected


def test_5つの年次ページが生成される(site):
    for regime in eligibility.MILESTONES:
        slug = f"{regime.effective_from.year}-{regime.effective_from.month:02d}"
        path = site / "year" / f"{slug}.html"
        assert path.exists(), slug
        html = path.read_text(encoding="utf-8")
        assert str(regime.effective_from.year) in html


def test_年次ページに前後のナビがある(site):
    html = (site / "year" / "2027-10.html").read_text(encoding="utf-8")
    assert "2026" in html  # 前へ
    assert "2029" in html  # 次へ


def test_固定ページが生成される(site):
    for name in ("faq.html", "about.html", "operator.html", "privacy.html", "contact.html", "404.html"):
        assert (site / name).exists(), name


def test_運営者情報と問い合わせに屋号と連絡先が出る(site):
    operator = (site / "operator.html").read_text(encoding="utf-8")
    contact = (site / "contact.html").read_text(encoding="utf-8")

    assert site_config.OWNER and site_config.OWNER in operator
    shown = site_config.CONTACT_EMAIL.replace("@", "[at]")
    assert shown in contact
    assert "mailto:" not in contact
    assert 'href="contact.html"' in operator
    assert 'href="operator.html"' in contact


def test_どのページからも運営者情報と問い合わせへ行ける(site):
    for name in ("index.html", "faq.html", "about.html", "privacy.html"):
        html = (site / name).read_text(encoding="utf-8")
        assert "operator.html" in html, name
        assert "contact.html" in html, name


def test_公開ページに個人名を出さない(site):
    """名義は屋号だけ。個人名・ユーザー名の混入を防ぐ（kabu-agari-ranking と同じ検査）。"""
    for path in site.rglob("*.html"):
        text = path.read_text(encoding="utf-8")
        for leak in ("なみ", "nami", "0817"):
            assert leak not in text, f"{path.name} に {leak} が出ている"


def test_sitemapに主要ページが載る(site):
    xml = (site / "sitemap.xml").read_text(encoding="utf-8")
    assert f"<loc>{site_config.SITE_URL}/</loc>" in xml
    assert f"<loc>{site_config.SITE_URL}/faq</loc>" in xml
    assert f"<loc>{site_config.SITE_URL}/operator</loc>" in xml
    for regime in eligibility.MILESTONES:
        slug = f"{regime.effective_from.year}-{regime.effective_from.month:02d}"
        assert f"<loc>{site_config.SITE_URL}/year/{slug}</loc>" in xml


def test_robotsがsitemapを指す(site):
    robots = (site / "robots.txt").read_text(encoding="utf-8")
    assert f"Sitemap: {site_config.SITE_URL}/sitemap.xml" in robots


def test_adsense未設定なら広告枠もads_txtも出さない(site):
    assert not (site / "ads.txt").exists()
    html = (site / "index.html").read_text(encoding="utf-8")
    assert "adsbygoogle" not in html


def test_審査に必要な3枚が個別相談ではないと断っている(site):
    for name in ("about.html", "operator.html", "contact.html"):
        html = (site / name).read_text(encoding="utf-8")
        assert "個別" in html, name


def test_canonical_urlはhtml拡張子とindexを落とす():
    assert render.canonical_url("index.html") == f"{site_config.SITE_URL}/"
    assert render.canonical_url("faq.html") == f"{site_config.SITE_URL}/faq"
    assert render.canonical_url("year/index.html") == f"{site_config.SITE_URL}/year/"
    assert render.canonical_url("year/2027-10.html") == f"{site_config.SITE_URL}/year/2027-10"


def test_計算機に埋め込まれた料率がdataと一致する(site):
    html = (site / "index.html").read_text(encoding="utf-8")
    m = re.search(r'<script id="rates-data" type="application/json">(.*?)</script>', html, re.S)
    assert m, "rates-data が見つからない"
    embedded = json.loads(m.group(1))
    assert [t["fiscal_year"] for t in embedded] == [t.fiscal_year for t in premium.TABLES]
    assert embedded[-1]["prefectures"] == premium.TABLES[-1].prefectures


def test_計算部分のjsが配信物に入る(site):
    assert (site / "static" / "calc.js").exists()
    html = (site / "index.html").read_text(encoding="utf-8")
    assert 'src="static/calc.js"' in html


def test_都道府県は47すべて選べる(site):
    html = (site / "index.html").read_text(encoding="utf-8")
    for pref in premium.PREFECTURES:
        assert f'<option value="{pref}"' in html, pref

"""dailyquarry.com の生成物のテスト。AdSense の審査が見るところを固定する。"""
import re
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))

import build  # noqa: E402
import site_config  # noqa: E402


@pytest.fixture
def out(tmp_path):
    build.build(tmp_path)
    return tmp_path


def _all_html(out: Path) -> dict[str, str]:
    return {p.name: p.read_text(encoding="utf-8") for p in out.glob("*.html")}


def test_審査に要る3枚と入口がある(out):
    for name in ["index.html", "operator.html", "privacy.html", "contact.html"]:
        assert (out / name).exists()


def test_公開ページに個人名を出さない(out):
    for name, html in _all_html(out).items():
        for bad in ["nami", "0817", "なみ"]:
            assert bad not in html.lower(), f"{name} に {bad}"


def test_mailtoを使わない(out):
    for name, html in _all_html(out).items():
        assert "mailto:" not in html, name
    assert "info[at]dailyquarry.com" in (out / "contact.html").read_text(encoding="utf-8")


def test_pubIDが空のあいだは広告もadstxtも出さない(out):
    assert not (out / "ads.txt").exists()
    for html in _all_html(out).values():
        assert "adsbygoogle" not in html
        assert "<ins" not in html


def test_pubIDを入れるとスクリプトとadstxtが出る(tmp_path, monkeypatch):
    monkeypatch.setattr(site_config, "ADSENSE_CLIENT", "ca-pub-1234567890123456")
    build.build(tmp_path)
    assert (tmp_path / "ads.txt").read_text() == (
        "google.com, pub-1234567890123456, DIRECT, f08c47fec0942fa0\n"
    )
    index = (tmp_path / "index.html").read_text(encoding="utf-8")
    assert "client=ca-pub-1234567890123456" in index
    assert "<ins" not in index  # 枠は置かない（自動広告に任せる）
    assert "利用しています" in (tmp_path / "privacy.html").read_text(encoding="utf-8")


def test_サイト一覧のリンクはすべて独自ドメイン(out):
    index = (out / "index.html").read_text(encoding="utf-8")
    for s in site_config.SITES:
        assert f'href="{s["url"]}"' in index
        assert re.match(r"https://[a-z0-9-]+\.dailyquarry\.com/$", s["url"])
    assert "pages.dev" not in index


def test_楽天APIを使うサイトはAdSenseの対象にしない():
    kakaku = [s for s in site_config.SITES if "kakaku." in s["url"]]
    assert kakaku and not kakaku[0]["ads"]


def test_sitemapとrobots(out):
    sm = (out / "sitemap.xml").read_text(encoding="utf-8")
    assert "<loc>https://dailyquarry.com/</loc>" in sm
    assert "404" not in sm
    assert "Sitemap: https://dailyquarry.com/sitemap.xml" in (out / "robots.txt").read_text()

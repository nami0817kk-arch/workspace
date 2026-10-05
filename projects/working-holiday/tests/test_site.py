"""サイトの生成と、データの決まり（推測で埋めない・出典を付ける）の検査。"""
import json
import re
from pathlib import Path

import pytest

import render
import site_config

DATA = Path(__file__).resolve().parents[1] / "data"
FIELD_KEYS = [k for k, _ in render.FIELDS]

# 根拠にしない業者・まとめサイト（各国の公式ページだけを出典にする）。
# 「確認できず」「推定」「検索結果」など、確かめていないことを示す書き方。
MEMO = re.compile(r"確認でき|未確認|見当たら|記載(が)?な|不明|要確認|推定|見込み|検索結果")

NOT_OFFICIAL = ("wikipedia.org", "jawhm.or.jp", "ryugaku", "abroad", "blog", "note.com", "ameblo")


@pytest.fixture(scope="module")
def site(tmp_path_factory):
    out = tmp_path_factory.mktemp("output")
    render.build(out)
    return out


def country_files():
    return sorted((DATA / "countries").glob("*.json"))


def test_外務省の一覧は32か国でidが重ならない():
    mofa = json.loads((DATA / "mofa.json").read_text(encoding="utf-8"))
    ids = [c["id"] for c in mofa["countries"]]
    assert len(ids) == 32
    assert len(set(ids)) == 32
    assert all(c["region"] in render.REGIONS for c in mofa["countries"])


@pytest.mark.parametrize("path", country_files(), ids=lambda p: p.stem)
def test_各国のデータは外務省の一覧にある国で出典が付いている(path):
    mofa_ids = {c["id"] for c in json.loads((DATA / "mofa.json").read_text(encoding="utf-8"))["countries"]}
    d = json.loads(path.read_text(encoding="utf-8"))
    assert d["id"] == path.stem
    assert d["id"] in mofa_ids
    filled = [k for k in FIELD_KEYS if (d.get(k) or "").strip()]
    if filled:
        assert d.get("sources"), "値があるのに出典が無い"
    for s in d.get("sources", []):
        assert s["url"].startswith("https://") or s["url"].startswith("http://")
        assert not any(bad in s["url"] for bad in NOT_OFFICIAL), f"公式でない出典: {s['url']}"
    # 値の中に「確かめられなかった」という調査メモを書かない（その項目は空にして unverified へ）
    for k in FIELD_KEYS:
        assert not MEMO.search(d.get(k) or ""), f"{k} に調査メモが入っている: {d.get(k)}"
    for p in d.get("points", []):
        assert not MEMO.search(p), f"points に調査メモが入っている: {p}"
    # 確かめられなかった項目に値が入っていない（推測で埋めない）
    for k in d.get("unverified", []):
        if k in FIELD_KEYS:
            assert not (d.get(k) or "").strip(), f"{k} は unverified なのに値がある"


def test_全ページが作られる(site):
    assert (site / "index.html").exists()
    assert len(list((site / "country").glob("*.html"))) == 33  # 32か国＋一覧
    for name in ("junbi", "mochimono", "about", "operator", "privacy", "contact", "404"):
        assert (site / f"{name}.html").exists()


def test_比較表に32か国が並ぶ(site):
    html = (site / "index.html").read_text(encoding="utf-8")
    assert html.count('<tr data-region=') == 32


def test_確かめていない項目は公式サイトで確認と出す(site):
    _, countries = render.load_data()
    blank = next((c for c in countries if not c["age"]), None)
    if blank is None:
        pytest.skip("全ての国で年齢が埋まっている")
    html = (site / "country" / f"{blank['id']}.html").read_text(encoding="utf-8")
    assert "公式サイトで確認" in html


def test_公開ページに個人名を出さない(site):
    for path in site.rglob("*.html"):
        text = path.read_text(encoding="utf-8")
        for leak in ("なみ", "nami", "0817"):
            assert leak not in text, f"{path.name} に {leak} が出ている"


def test_mailtoを使わない(site):
    for path in site.rglob("*.html"):
        assert "mailto:" not in path.read_text(encoding="utf-8")


def test_アソシエイトのタグが空ならAmazonのリンクも表記も出さない(site, monkeypatch):
    if site_config.AMAZON_TAG:
        pytest.skip("タグが設定済み")
    for path in site.rglob("*.html"):
        text = path.read_text(encoding="utf-8")
        assert "amazon.co.jp" not in text
        assert "アソシエイト" not in text


def test_タグがあればAmazonのリンクと広告の表記が出る(tmp_path, monkeypatch):
    monkeypatch.setattr(site_config, "AMAZON_TAG", "test-22")
    render.build(tmp_path)
    html = (tmp_path / "mochimono.html").read_text(encoding="utf-8")
    assert "tag=test-22" in html
    assert 'rel="sponsored noopener"' in html
    assert "広告" in html
    assert "Amazonのアソシエイトとして" in html


def test_sitemapに404を載せない(site):
    xml = (site / "sitemap.xml").read_text(encoding="utf-8")
    assert f"<loc>{site_config.SITE_URL}/</loc>" in xml
    assert f"<loc>{site_config.SITE_URL}/country/australia</loc>" in xml
    assert "404" not in xml

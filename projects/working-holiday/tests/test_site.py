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
MEMO = re.compile(r"確認でき(ず|なかった|ない)|未確認|見当たら|記載(が)?な|が不明|は不明|要確認|推定|見込み|検索結果")

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


# 個人を指す文字列。nami は単語として出たときだけ止める（スペイン語の Empadronamiento などに含まれるため）。
LEAK = re.compile(r"なみ|0817|(?<![a-z])nami(?![a-z])", re.I)
# 第三者の固有名詞で、たまたま当たるもの（英国の日本人歯科医院の名前）。
LEAK_OK = ("Nami Dental Clinic",)


def test_公開ページに個人名を出さない(site):
    for path in site.rglob("*.html"):
        text = path.read_text(encoding="utf-8")
        for ok in LEAK_OK:
            text = text.replace(ok, "")
        m = LEAK.search(text)
        assert not m, f"{path.name} に {m.group(0) if m else ''} が出ている"


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


def test_比較表の短い形():
    assert render.short("初回12か月。3か月の特定の就労で2年目") == "初回12か月"
    assert render.short("初回 AUD840.00／2年目 AUD1,000.00") == "初回 AUD840.00"
    assert render.short("申請時18歳以上30歳以下（日本国籍者）") == "申請時18歳以上30歳以下"
    assert render.short("あ" * 60).endswith("…")


def arrival_files():
    return sorted((DATA / "arrival").glob("*.json"))


@pytest.mark.parametrize("path", arrival_files(), ids=lambda p: p.stem)
def test_現地情報は公式の出典だけで調査メモを含まない(path):
    d = json.loads(path.read_text(encoding="utf-8"))
    assert d["id"] == path.stem
    texts = [s.get("title", "") + s.get("body", "") for s in d.get("steps", [])]
    med = d.get("medical") or {}
    texts += [med.get("summary", ""), med.get("emergency", "")]
    texts += [h.get("japanese", "") + h.get("name", "") for h in med.get("hospitals", [])]
    jobs = d.get("jobs") or {}
    texts += [jobs.get("min_wage", "")] + jobs.get("rules", []) + [c.get("note", "") for c in jobs.get("channels", [])]
    for t in texts:
        assert not MEMO.search(t), f"調査メモが入っている: {t}"
    urls = [s.get("url", "") for s in d.get("steps", [])] + [h.get("url", "") for h in med.get("hospitals", [])]
    urls += [c.get("url", "") for c in jobs.get("channels", [])] + [jobs.get("min_wage_url", "")]
    urls += [s["url"] for s in d.get("sources", [])]
    for u in filter(None, urls):
        assert u.startswith("http"), u
        assert not any(bad in u for bad in NOT_OFFICIAL), f"公式でない出典: {u}"
    if jobs.get("min_wage"):
        assert jobs.get("min_wage_url"), "最低賃金に出典が無い"
    # 「日本語が通じる医療機関」の表に出すので、日本語での対応が書いていないものは載せない
    for h in med.get("hospitals", []):
        assert h.get("japanese", "").strip(), f"日本語の対応が書いていない: {h.get('name')}"


def test_現地情報のある国はページに病院と仕事の欄が出る(site):
    html = (site / "country" / "australia.html").read_text(encoding="utf-8")
    assert 'id="iryou"' in html and 'id="shigoto"' in html
    assert "法定の最低賃金" in html


def test_国のページに検索エンジン向けのパンくずが入る(site):
    html = (site / "country" / "canada.html").read_text(encoding="utf-8")
    m = re.search(r'<script type="application/ld\+json">(.*?)</script>', html, re.S)
    assert m
    data = json.loads(m.group(1))
    assert [i["name"] for i in data["itemListElement"]] == ["トップ", "国から探す", "カナダ"]
    assert data["itemListElement"][-1]["item"] == f"{site_config.SITE_URL}/country/canada"


def test_共有用の画像がある(site):
    assert (site / "static" / "og.png").exists()
    assert 'property="og:image"' in (site / "index.html").read_text(encoding="utf-8")


def test_緊急番号の一覧表は番号を全部残す():
    assert render.numbers_only("15（SAMU・救急医療）/ 17（警察）/ 18（消防）/ 112（EU共通緊急通報）") == "15 / 17 / 18 / 112"
    assert render.numbers_only("999 または 112（消防・警察・救急共通）") == "999 / 112"
    assert render.numbers_only("000（警察・消防・救急共通）") == "000"

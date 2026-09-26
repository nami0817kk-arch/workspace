import pytest

import climate
import render
import site_config
from stations import BY_SLUG, STATIONS


def test_平年値が気象庁の表と一致する_高山11月():
    # 気象庁「平年値（年・月ごとの値）」高山 11月: 平均気温7.1℃・日最高13.1℃・日最低2.9℃
    c = climate.month_climate("47617", 11)
    assert (c.temp, c.tmax, c.tmin) == (7.1, 13.1, 2.9)


def test_全地点_全月の気温がそろっている():
    for st in STATIONS:
        for m in range(1, 13):
            c = climate.month_climate(st.code, m)
            assert c.tmin <= c.temp <= c.tmax, (st.name, m)
            assert len(c.dekads) == 3


def test_slugは重複しない():
    assert len(BY_SLUG) == len(STATIONS)


@pytest.mark.parametrize(
    "celsius, expected",
    [(31, "半袖。日差し"), (30, "半袖。日差し"), (29.9, "半袖"), (16, "長袖に薄手"), (2.9, "ダウン"), (-10, "ダウン")],
)
def test_服装の区切り(celsius, expected):
    assert climate.clothing_for(celsius).startswith(expected)


def test_比べる文_高い低い_ほぼ同じ():
    naha = climate.comparisons("47936", 8)
    assert climate.comparison_sentence(naha) == "最高気温は東京より0.5℃高く、大阪より1.9℃低い水準です。"
    tokyo = climate.comparisons("47662", 1)
    assert climate.comparison_sentence(tokyo) == "最高気温は大阪とほぼ同じ水準です。"


@pytest.fixture(scope="module")
def site(tmp_path_factory):
    out = tmp_path_factory.mktemp("site") / "output"
    original = render._OUTPUT_DIR
    render._OUTPUT_DIR = out
    try:
        render.build_all()
    finally:
        render._OUTPUT_DIR = original
    return out


def test_地点x月のページがすべてできる(site):
    for st in STATIONS:
        for m in range(1, 13):
            assert (site / st.slug / f"{m}.html").exists(), (st.slug, m)
        assert (site / st.slug / "index.html").exists()


def test_どの月のページにも出典と予報でない旨がある(site):
    for path in site.glob("*/*.html"):
        if path.name == "index.html":
            continue
        html = path.read_text(encoding="utf-8")
        assert "気象庁" in html and "加工" in html, path
        assert "予報ではありません" in html, path


def test_審査用の3枚と運営者情報(site):
    for name in ("operator.html", "privacy.html", "contact.html", "about.html"):
        assert (site / name).exists()
    contact = (site / "contact.html").read_text(encoding="utf-8")
    assert site_config.CONTACT_EMAIL.replace("@", "[at]") in contact
    assert "mailto:" not in contact


def test_公開ページに個人名を出さない(site):
    for path in site.rglob("*.html"):
        text = path.read_text(encoding="utf-8")
        for leak in ("なみ", "nami", "0817"):
            assert leak not in text, f"{path} に {leak}"


def test_ほかのサイトの文言が混ざっていない(site):
    for path in site.rglob("*.html"):
        text = path.read_text(encoding="utf-8")
        for leak in ("社会保険", "加入判定", "年金"):
            assert leak not in text, f"{path} に {leak}"


def test_sitemapに全ページ(site):
    xml = (site / "sitemap.xml").read_text(encoding="utf-8")
    assert xml.count("<loc>") == 5 + len(STATIONS) * 13
    assert f"<loc>{site_config.SITE_URL}/takayama/11</loc>" in xml


def test_adsense未設定なら広告を出さない(site):
    assert "adsbygoogle" not in (site / "index.html").read_text(encoding="utf-8")


def test_東京でいえば何月_は最高気温のいちばん近い月():
    # 高山11月下旬の最高 10.9℃ は東京2月の最高（10.9℃）にいちばん近い
    assert climate.tokyo_like_month(10.9) == 2


def test_20時の気温は旬ごとに36個():
    for st in STATIONS:
        assert len(climate.NORMALS[st.code]["dekad"]["evening"]) == 36


def test_手書きの案内があるページは厚いページになり_写真の出典とライセンスが出る(site):
    html = (site / "takayama" / "11.html").read_text(encoding="utf-8")
    g = climate.guide("takayama", 11)
    assert g["headline"] in html
    for p in g["photos"]:
        assert p["author"] in html and p["license"] in html and p["source_url"].split("/")[-1][:20] in html
        assert (site / "static" / "photos" / p["file"]).exists()
    for h in g["highlights"]:
        assert h["source_url"] in html
    assert "予報ではありません" in html
    assert '<svg viewBox' in html


def test_案内ファイルの形():
    import json
    from pathlib import Path
    for p in (Path(climate.__file__).resolve().parent.parent / "data" / "guides").rglob("*.json"):
        g = json.loads(p.read_text(encoding="utf-8"))
        assert len(g["dekads"]) == 3, p
        assert g["checked"] and g["photos"], p
        for h in g["highlights"]:
            assert h["source_url"].startswith("https://"), p
            assert h["dekad"] in (None, 0, 1, 2), p

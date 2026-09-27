"""生成されたページの中身のテスト。kabu-agari-ranking/tests/test_site_pages.py と同じ観点。"""
import json
import re
from pathlib import Path

import pytest

import eligibility
import extras
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
    assert "パートの社会保険 計算機" in html
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


def test_月収別のページが8万から25万まで(site):
    for m in render.AMOUNTS_MAN:
        assert (site / "getsushu" / f"{m}man.html").exists(), m
    assert (site / "getsushu" / "index.html").exists()
    xml = (site / "sitemap.xml").read_text(encoding="utf-8")
    assert f"<loc>{site_config.SITE_URL}/getsushu/10man</loc>" in xml


def test_月収10万円_東京の保険料が円単位で出る(site):
    # 令和8年度・東京: 標準報酬 98,000円 → 健保 4,826（4,826.5 の50銭は切り捨て）+ 支援金 113 + 厚年 8,967
    html = (site / "getsushu" / "10man.html").read_text(encoding="utf-8")
    assert "東京なら月 13,906円 引かれて、残りは 86,094円" in html
    for pref in premium.PREFECTURES:
        assert f"<th>{extras.pref_full(pref)}</th>" in html, pref
    assert "<strong>85,594円" in html  # 雇用保険料 500円（5/1,000）も引いた手取りの目安
    assert "年約6,445円増えます" in html
    assert "月8,953円安く" in html  # 国民年金 17,920円 − 厚生年金 8,967円


def test_どのページからも月収別の一覧へ行ける(site):
    for name in ("index.html", "faq.html"):
        assert "getsushu/index.html" in (site / name).read_text(encoding="utf-8")


def test_計算方法と更新履歴のページ(site):
    html = (site / "keisan.html").read_text(encoding="utf-8")
    for src in ("kyoukaikenpo.or.jp", "mhlw.go.jp/content/001692566.pdf", "nenkin.go.jp", "nta.go.jp"):
        assert src in html, src
    assert "更新履歴" in html
    assert "keisan.html" in (site / "index.html").read_text(encoding="utf-8")


def test_計算機に時給の入力と正式な都道府県名(site):
    html = (site / "index.html").read_text(encoding="utf-8")
    assert 'id="hourly"' in html
    assert '<option value="東京" selected>東京都</option>' in html
    assert 'id="extras-data"' in html


def test_月収20万円のページに所得税と手取り(site):
    html = (site / "getsushu" / "20man.html").read_text(encoding="utf-8")
    assert "</span></th><td>3,290円" in html  # 所得税
    assert "<strong>167,330円</strong>" in html  # 200,000 − 28,380 − 1,000 − 3,290


def test_計算機に通勤手当と扶養の人数(site):
    html = (site / "index.html").read_text(encoding="utf-8")
    assert 'id="commute"' in html and 'id="dependents"' in html


def test_週20時間の壁のページ(site):
    for h in render.KABE_HOURLY:
        assert (site / "kabe" / f"{h}yen.html").exists(), h
    html = (site / "kabe" / "1100yen.html").read_text(encoding="utf-8")
    assert "週20時間にすると手取りは月 9,617円 減る。週22.5時間で元に戻る" in html
    xml = (site / "sitemap.xml").read_text(encoding="utf-8")
    assert f"<loc>{site_config.SITE_URL}/kabe/1100yen</loc>" in xml


def test_共有画像とパンくずの構造化データ(site):
    assert (site / "static" / "og.png").exists()
    html = (site / "getsushu" / "10man.html").read_text(encoding="utf-8")
    assert f'<meta property="og:image" content="{site_config.SITE_URL}/static/og.png">' in html
    m = re.search(r'<script type="application/ld\+json">(\{"@context": "https://schema.org", "@type": "BreadcrumbList".*?)</script>', html)
    assert m, "BreadcrumbList が無い"
    items = json.loads(m.group(1))["itemListElement"]
    assert [i["name"] for i in items] == ["計算機", "月収別の保険料", "月収10万円"]
    assert items[-1]["item"] == f"{site_config.SITE_URL}/getsushu/10man"
    assert items[1]["item"] == f"{site_config.SITE_URL}/getsushu/"


def test_図が入っている(site):
    amount = (site / "getsushu" / "10man.html").read_text(encoding="utf-8")
    assert 'class="bar100"' in amount and "手取り <strong>85,594円</strong>" in amount  # 月収の行き先
    assert 'class="hbars"' in amount and "国民年金（自分で払う）" in amount  # 国民年金と厚生年金
    wall = (site / "kabe" / "1100yen.html").read_text(encoding="utf-8")
    assert wall.count('class="fill-s2"') + wall.count('class="fill-s1"') + wall.count('class="fill-base"') >= 8
    assert "週20時間: 手取り 80,950円（週19時間より−9,617円）" in wall  # 棒にマウスを乗せたときの値
    for name in ("index.html", "year/2029-10.html"):
        assert 'class="timeline"' in (site / name).read_text(encoding="utf-8"), name
    assert (site / "static" / "charts.js").exists()
    assert 'src="static/charts.js"' in (site / "index.html").read_text(encoding="utf-8")


def test_図の色はライトとダークの両方で決めてある(site):
    html = (site / "index.html").read_text(encoding="utf-8")
    assert html.count("--s1:") == 2  # ライトとダーク


def test_トップに早見表と週20時間の壁とよくある質問(site):
    html = (site / "index.html").read_text(encoding="utf-8")
    assert "<title>パートの社会保険 計算" in html
    assert 'href="getsushu/10man.html">10万円</a><span class="sub">年収120万円</span>' in html
    assert "月9,617円減り" in html and "週22.5時間" in html
    faq = (site / "faq.html").read_text(encoding="utf-8")
    for anchor in ("q-106", "q-130", "q-student", "q-small", "q-takehome", "q-oct", "q-20h", "q-low"):
        assert f'id="{anchor}"' in faq, anchor
    for anchor in re.findall(r'faq\.html#([\w-]+)', html):
        assert f'id="{anchor}"' in faq, anchor  # トップからのリンク先が faq にある


def test_最終更新日とsitemapのlastmod(site):
    assert f"最終更新 {render._env.globals['updated']}" in (site / "getsushu" / "10man.html").read_text(encoding="utf-8")
    xml = (site / "sitemap.xml").read_text(encoding="utf-8")
    assert xml.count("<lastmod>") == xml.count("<loc>")
    assert f"<lastmod>{render.UPDATED}</lastmod>" in xml


def test_月収別と週20時間の壁が互いにリンクする(site):
    amount = (site / "getsushu" / "10man.html").read_text(encoding="utf-8")
    assert "年収120万円" in amount and 'kabe/index.html' in amount
    wall = (site / "kabe" / "1100yen.html").read_text(encoding="utf-8")
    assert 'getsushu/10man.html">月収10万円の保険料の内訳' in wall


def test_説明文とタイトルの長さ(site):
    # 検索で呼び込むページだけ見る（404・問い合わせ・運営者・プライバシーは対象外）
    skip = {"404.html", "contact.html", "operator.html", "privacy.html"}
    for path in site.rglob("*.html"):
        if path.name in skip:
            continue
        html = path.read_text(encoding="utf-8")
        m = re.search(r'<meta name="description" content="([^"]*)"', html)
        assert m and 40 <= len(m.group(1)) <= 160, (path, len(m.group(1)) if m else None)
        t = re.search(r"<title>(.*?)</title>", html, re.S).group(1)
        assert len(t) <= 70, (path, len(t))


def test_計算機の新しいレイアウト(site):
    html = (site / "index.html").read_text(encoding="utf-8")
    assert 'class="hero-band"' in html and 'class="calc-layout"' in html
    assert 'id="summary"' in html and 'id="mobile-bar"' in html
    assert '<details class="more">' in html  # 詳しい入力はたたむ
    for page in ("index.html", "getsushu/10man.html", "kabe/1100yen.html"):
        assert html.count('class="card-link"') == 6 if page == "index.html" else True
        assert 'class="card-link"' in (site / page).read_text(encoding="utf-8"), page


def test_indexnowのキーファイルがサイト直下にある(site):
    key = site_config.INDEXNOW_KEY
    assert re.fullmatch(r"[0-9a-f]{32}", key)
    assert (site / f"{key}.txt").read_text(encoding="utf-8") == key


def test_年収別の手取り早見表(site):
    html = (site / "nenshu.html").read_text(encoding="utf-8")
    assert "<title>パートの年収別 手取り早見表" in html
    rows = render._nenshu_rows(premium.TABLES[-1].valid_from)
    by = {r["man"]: r for r in rows}
    # 入る場合は保険料の分だけ手取りが少ない。130万円以上は扶養内の列を出さない
    assert by[120]["net_in"] < by[120]["net_out"] <= 1_200_000
    assert by[130]["net_out"] is None and by[200]["net_out"] is None
    assert f'{by[120]["net_in"]:,}円' in html
    assert "108,334円" in html  # 130万円の壁の月額
    assert f"<loc>{site_config.SITE_URL}/nenshu</loc>" in (site / "sitemap.xml").read_text(encoding="utf-8")
    assert 'href="nenshu.html"' in (site / "index.html").read_text(encoding="utf-8")


def test_加入条件と等級表のページ(site):
    html = (site / "jyoken.html").read_text(encoding="utf-8")
    assert "<h1>パートの社会保険の加入条件</h1>" in html
    for m in eligibility.MILESTONES:
        assert f"{m.effective_from.year}年{m.effective_from.month}月" in html
    g = (site / "hyoujun.html").read_text(encoding="utf-8")
    # 4等級（標準 88,000円）: 月収9万円の計算機の既定値と同じ 12,487円
    assert "<th>4（1）</th><td>88,000円</td>" in g and "12,487円" in g
    xml = (site / "sitemap.xml").read_text(encoding="utf-8")
    for p in ("jyoken", "hyoujun"):
        assert f"<loc>{site_config.SITE_URL}/{p}</loc>" in xml


def test_手取りからの逆算は届く最小の月収(site):
    as_of = premium.TABLES[-1].valid_from
    for r in render._reverse_rows(as_of):
        target = r["net_man"] * 10_000
        assert render._net_monthly(as_of, r["pay"]) >= target
        assert render._net_monthly(as_of, r["pay"] - 100) < target
    assert "手取り◯万円にするには月収いくら" in (site / "getsushu" / "index.html").read_text(encoding="utf-8")


def test_faqの構造化データは見出しと同じ数(site):
    html = (site / "faq.html").read_text(encoding="utf-8")
    n = len(re.findall(r'<h2 id="q-', html))
    blocks = [json.loads(b) for b in re.findall(r'<script type="application/ld\+json">(.*?)</script>', html, re.S)]
    faq = [b for b in blocks if b.get("@type") == "FAQPage"][0]
    assert len(faq["mainEntity"]) == n >= 14
    assert all(q["acceptedAnswer"]["text"] for q in faq["mainEntity"])
    assert '"@type":"WebApplication"' in (site / "index.html").read_text(encoding="utf-8")


def test_計算機の入力例と共有とページからの直リンク(site):
    html = (site / "index.html").read_text(encoding="utf-8")
    assert html.count("data-preset=") == 4 and 'id="copy-link"' in html
    assert 'href="../index.html?w=100000"' in (site / "getsushu" / "10man.html").read_text(encoding="utf-8")
    assert 'href="../index.html?h=20&amp;hr=1100"' in (site / "kabe" / "1100yen.html").read_text(encoding="utf-8")
    assert "入る・40〜64歳" in (site / "nenshu.html").read_text(encoding="utf-8")

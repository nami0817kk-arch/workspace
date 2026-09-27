"""出したページが、検索側に知らせられているか。

sitemap は手で並べているので、**章を足したときに書き忘れる**。
実際に market.html（相場の振り返り）が抜けたまま公開されていた
（2026-09-27 に気づいた）。抜けても画面上は何も起きないので、
出来上がった output を突き合わせて止める。
"""
import json
import re
from pathlib import Path

import pytest

import render


@pytest.fixture(scope="module")
def site(tmp_path_factory):
    tmp_path = tmp_path_factory.mktemp("site")
    data_dir = tmp_path / "data"
    data_dir.mkdir()
    orig = (render._DATA_DIR, render._OUTPUT_DIR, render._ROOT)
    render._DATA_DIR, render._OUTPUT_DIR, render._ROOT = data_dir, tmp_path / "output", tmp_path
    try:
        for d in ("2026-09-16", "2026-09-17", "2026-09-18"):
            (data_dir / f"{d}.json").write_text(json.dumps({
                "rec_date": d,
                "gainers": [{"rank": 1, "code": "5131", "name": "リンカーズ", "close": 163.0,
                             "change_pct": 44.25, "metric_value": 100}],
                "losers": [{"rank": 1, "code": "4599", "name": "ステムリム", "close": 239.0,
                            "change_pct": -25.08, "metric_value": 100}],
                "active": [{"rank": 1, "code": "7203", "name": "トヨタ", "close": 2500.0,
                            "change_pct": 1.5, "metric_value": 9999}],
            }, ensure_ascii=False), encoding="utf-8")
        render.build_all()
        yield render._OUTPUT_DIR
    finally:
        render._DATA_DIR, render._OUTPUT_DIR, render._ROOT = orig


def _canonical(html: str) -> str | None:
    m = re.search(r'<link rel="canonical" href="(.*?)"', html)
    return m.group(1) if m else None


def test_canonicalを持つページは全部sitemapに載る(site):
    locs = set(re.findall(r"<loc>(.*?)</loc>",
                          (site / "sitemap.xml").read_text(encoding="utf-8")))
    missing = []
    for path in sorted(site.rglob("*.html")):
        url = _canonical(path.read_text(encoding="utf-8"))
        if url and url not in locs:
            missing.append(path.relative_to(site).as_posix())
    assert not missing, f"sitemap に載っていないページ: {missing}"


def test_sitemapのURLは全部実在する(site):
    """消した章の URL が残っていると、検索側に 404 を出し続ける。"""
    locs = set(re.findall(r"<loc>(.*?)</loc>",
                          (site / "sitemap.xml").read_text(encoding="utf-8")))
    canons = {
        _canonical(p.read_text(encoding="utf-8"))
        for p in site.rglob("*.html")
    }
    assert not (locs - canons), f"実体が無い URL: {sorted(locs - canons)[:5]}"


def test_canonicalは重複しない(site):
    """2ページが同じ canonical を指すと、片方は検索結果から消える。"""
    seen = {}
    for path in sorted(site.rglob("*.html")):
        url = _canonical(path.read_text(encoding="utf-8"))
        if not url:
            continue
        rel = path.relative_to(site).as_posix()
        assert url not in seen, f"{rel} と {seen[url]} が同じ canonical: {url}"
        seen[url] = rel


def test_公開するページには必ず説明文がある(site):
    """検索結果に出る一行。無いと本文の断片が勝手に使われる。"""
    missing = []
    for path in sorted(site.rglob("*.html")):
        html = path.read_text(encoding="utf-8")
        if "noindex" in html:
            continue
        if not re.search(r'<meta name="description" content=".{10,}?"', html, re.S):
            missing.append(path.relative_to(site).as_posix())
    assert not missing, f"説明文が無いページ: {missing}"


def test_画面のパンくずと構造化データが食い違わない(site):
    """どちらか片方だけがあると、検索側に見せている階層と
    読み手に見せている階層が違うことになる。
    一覧ページ4枚（アーカイブ3種と月まとめ）で実際に食い違っていた。"""
    mismatched = []
    for path in sorted(site.rglob("*.html")):
        html = path.read_text(encoding="utf-8")
        visual = 'class="crumbs"' in html
        structured = "BreadcrumbList" in html
        if visual != structured:
            mismatched.append(
                f"{path.relative_to(site).as_posix()} 画面={visual} 構造化={structured}")
    assert not mismatched, "パンくずの食い違い:\n" + "\n".join(mismatched)


def test_一覧ページにはパンくずがある(site):
    """ホーム直下でない index は、どこにいるのかを示す。"""
    for rel in ("archive/gainers/index.html", "monthly/index.html",
                "weekly/index.html", "stock/index.html",
                "stop-high/index.html", "stop-low/index.html"):
        html = (site / rel).read_text(encoding="utf-8")
        assert 'class="crumbs"' in html, f"{rel} に画面のパンくずが無い"
        assert "BreadcrumbList" in html, f"{rel} に構造化データが無い"


def test_検索が張る銘柄リンクは必ず実在する(site):
    """検索の結果は JS が組み立てるので、リンク検査では歩けない。
    ページが無い銘柄へ張ると、押した先が 404 になる。"""
    index = json.loads((site / "search-index.json").read_text(encoding="utf-8"))
    import aggregate
    threshold = aggregate.STOCK_PAGE_MIN_APPEARANCES
    # JS 側の閾値が Python 側とずれていないこと（ずれると 404 を張る）
    search_html = (site / "search.html").read_text(encoding="utf-8")
    assert f"total >= {threshold}" in search_html

    missing = []
    for s in index["stocks"]:
        total = sum(len(s.get(k) or []) for k in ("g", "l", "a"))
        if total >= threshold and not (site / "stock" / s["c"] / "index.html").exists():
            missing.append(s["c"])
    assert not missing, f"ページが無いのにリンクする銘柄: {missing}"


def test_検索が張るアーカイブリンクは必ず実在する(site):
    index = json.loads((site / "search-index.json").read_text(encoding="utf-8"))
    dead = []
    for s in index["stocks"]:
        for key, dirname in (("g", "gainers"), ("l", "losers"), ("a", "active")):
            for rec_date in s.get(key) or []:
                if not (site / "archive" / dirname / f"{rec_date}.html").exists():
                    dead.append(f"{s['c']} {dirname}/{rec_date}")
    assert not dead, f"存在しないアーカイブへのリンク: {dead[:5]}"


def test_見た目はページに埋め込まず1枚にまとめる(site):
    """16.6KB の CSS が 200 ページ全部に複製されていた（2026-09-27 に外へ出した）。
    ページを移るたびに同じものを送り直していたことになる。"""
    embedded = [p.relative_to(site).as_posix()
                for p in site.rglob("*.html") if "<style>" in p.read_text(encoding="utf-8")]
    assert not embedded, f"CSS を埋め込んでいるページ: {embedded[:5]}"

    sheets = list(site.glob("site.*.css"))
    assert len(sheets) == 1, f"見た目のファイルが {len(sheets)} 個ある"
    # 名前に中身のハッシュが入っていること（固定名だと直しても古いものが残る）
    assert re.fullmatch(r"site\.[0-9a-f]{8}\.css", sheets[0].name), sheets[0].name


def test_全ページが同じ見た目のファイルを指す(site):
    sheet = next(site.glob("site.*.css")).name
    for path in sorted(site.rglob("*.html")):
        html = path.read_text(encoding="utf-8")
        m = re.search(r'<link rel="stylesheet" href="([^"]+)"', html)
        assert m, f"{path.relative_to(site).as_posix()} に見た目のファイルが無い"
        assert m.group(1).endswith(sheet), f"{path.relative_to(site).as_posix()} -> {m.group(1)}"
        # 深い階層からも辿れること。404 だけは任意の階層で表示されるので、
        # 相対ではなくルートからの絶対パスで指すのが正しい。
        base = site if m.group(1).startswith("/") else path.parent
        assert (base / m.group(1).lstrip("/")).resolve().exists()

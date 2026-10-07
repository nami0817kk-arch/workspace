"""読み上げや拡大で読む人のための、機械で見られる範囲の確認。

見た目の確認は実機でやるしかないが、**見出しの飛び・表の説明・
リンクの文字**は出来上がった HTML から機械的に見られる。
"""
import json
import re

import pytest

import render


@pytest.fixture(scope="module")
def site(tmp_path_factory):
    tmp_path = tmp_path_factory.mktemp("a11y")
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


def _main(path):
    html = path.read_text(encoding="utf-8")
    return html.split("<main", 1)[1].split("</main>", 1)[0] if "<main" in html else html


def test_見出しは1ページに1つのh1から始まる(site):
    bad = []
    for path in sorted(site.rglob("*.html")):
        levels = [int(m) for m in re.findall(r"<h([1-6])[ >]", _main(path))]
        if levels.count(1) != 1:
            bad.append(f"{path.relative_to(site).as_posix()}: h1 が {levels.count(1)} 個")
    assert not bad, "\n".join(bad)


def test_見出しの階層が飛ばない(site):
    """h2 の次に h4 が来ると、読み上げで章の入れ子が分からなくなる。"""
    bad = []
    for path in sorted(site.rglob("*.html")):
        prev = 0
        for level in [int(m) for m in re.findall(r"<h([1-6])[ >]", _main(path))]:
            if prev and level > prev + 1:
                bad.append(f"{path.relative_to(site).as_posix()}: h{prev} → h{level}")
                break
            prev = level
    assert not bad, "\n".join(bad)


def test_表には必ず説明がある(site):
    """表だけを拾って読むとき、何の表か分からないと意味がない。"""
    bad = []
    for path in sorted(site.rglob("*.html")):
        for table in re.findall(r"<table[^>]*>(.*?)</table>", _main(path), re.S):
            if "<caption" not in table:
                bad.append(path.relative_to(site).as_posix())
                break
    assert not bad, f"説明の無い表: {bad}"


def test_グラフには説明がある(site):
    """SVG は読み上げでは中身が伝わらない。何のグラフかを名乗らせる。"""
    bad = []
    for path in sorted(site.rglob("*.html")):
        for svg in re.findall(r"<svg[^>]*>", _main(path)):
            if "aria-label" not in svg and "role=" not in svg:
                bad.append(path.relative_to(site).as_posix())
                break
    assert not bad, f"説明の無いグラフ: {bad}"


def test_リンクの文字だけで行き先が分かる(site):
    """「こちら」はリンクだけを拾って読む人には意味を成さない。
    銘柄ページ129枚に「読み方はこちら」が入っていた（2026-09-27 に直した）。"""
    vague = {"こちら", "ここ", "詳細", "もっと見る", "リンク", "クリック"}
    bad = []
    for path in sorted(site.rglob("*.html")):
        for text in re.findall(r"<a [^>]*>([^<]{1,8})</a>", _main(path)):
            if text.strip() in vague:
                bad.append(f"{path.relative_to(site).as_posix()}: {text.strip()}")
    assert not bad, "\n".join(bad[:10])


def test_カレンダーの升目は日付を名乗る(site):
    """升目の文字は「24」だけ。リンクだけを拾って読む人には、
    どの月の24日か分からない（title は読まれないことがある）。"""
    html = (site / "index.html").read_text(encoding="utf-8")
    links = re.findall(r'<a [^>]*href="[^"]*archive/[^"]*"[^>]*>\d+</a>', html)
    assert links, "カレンダーの升目が見つからない"
    for link in links:
        assert "aria-label=" in link, link
        assert re.search(r'aria-label="\d{4}年\d+月\d+日', link), link

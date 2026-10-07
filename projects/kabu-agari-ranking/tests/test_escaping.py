"""取得元から来た文字列が、そのまま HTML に流れていないか。

銘柄名は kabutan のページから取っている。**`&` を含む社名は実在する**
（A&D ホロン ホールディングスなど）。自動エスケープを切っていると、
そのまま実体参照として不正な HTML になり、`<` が混ざればその先の
マークアップごと壊れる（2026-09-28 に有効化した）。
"""
import json
import re
import xml.etree.ElementTree as ET

import pytest

import render

HOSTILE = 'A&D <script>alert(1)</script> "ホロン"'


@pytest.fixture(scope="module")
def site(tmp_path_factory):
    tmp_path = tmp_path_factory.mktemp("esc")
    data_dir = tmp_path / "data"
    data_dir.mkdir()
    orig = (render._DATA_DIR, render._OUTPUT_DIR, render._ROOT)
    render._DATA_DIR, render._OUTPUT_DIR, render._ROOT = data_dir, tmp_path / "output", tmp_path
    try:
        for d in ("2026-09-16", "2026-09-17", "2026-09-18"):
            (data_dir / f"{d}.json").write_text(json.dumps({
                "rec_date": d,
                "gainers": [{"rank": 1, "code": "7745", "name": HOSTILE, "close": 163.0,
                             "change_pct": 44.25, "metric_value": 100}],
                "losers": [{"rank": 1, "code": "4599", "name": HOSTILE, "close": 239.0,
                            "change_pct": -25.08, "metric_value": 100}],
                "active": [],
            }, ensure_ascii=False), encoding="utf-8")
        render.build_all()
        yield render._OUTPUT_DIR
    finally:
        render._DATA_DIR, render._OUTPUT_DIR, render._ROOT = orig


def test_自動エスケープが有効():
    """個々のテンプレートで付け忘れると、その画面だけ素通しになる。"""
    assert render._env.autoescape is True


def test_銘柄名のタグがそのまま出ない(site):
    for path in sorted(site.rglob("*.html")):
        html = path.read_text(encoding="utf-8")
        assert "<script>alert(1)</script>" not in html, path.relative_to(site).as_posix()


def test_アンパサンドは実体参照にする(site):
    """`A&D` のままだと HTML として不正で、XML に流れると壊れる。"""
    html = (site / "index.html").read_text(encoding="utf-8")
    body = re.search(r"<tbody>(.*?)</tbody>", html, re.S).group(1)
    assert "A&amp;D" in body
    assert re.search(r"A&(?!amp;)", body) is None


def test_グラフはエスケープしない(site):
    """SVG はこちらが組み立てたもの。エスケープすると図が消える。"""
    assert "<svg" in (site / "index.html").read_text(encoding="utf-8")


def test_構造化データが壊れない(site):
    for path in sorted(site.rglob("*.html")):
        html = path.read_text(encoding="utf-8")
        for block in re.findall(r'<script type="application/ld\+json">(.*?)</script>', html, re.S):
            json.loads(block)          # 壊れていれば例外


def test_カレンダーのJSが壊れない(site):
    """日付の配列はこちらが json.dumps したもの。エスケープすると JS が止まる。"""
    html = (site / "index.html").read_text(encoding="utf-8")
    dates = re.search(r"var dates = (\[.*?\]);", html).group(1)
    assert json.loads(dates)


def test_feedとsitemapがXMLとして妥当(site):
    for name in ("feed.xml", "sitemap.xml"):
        ET.fromstring((site / name).read_text(encoding="utf-8"))


def test_検索インデックスが読める(site):
    index = json.loads((site / "search-index.json").read_text(encoding="utf-8"))
    assert index["stocks"][0]["n"] == HOSTILE

"""生成されたページの中身のテスト。

表だけのページを量産すると、広告審査でも検索でも「中身が無い」と見なされる。
各日ページに固有の説明文が入ること、前後にたどれること、審査前に空の広告枠を
出さないことを固定する。
"""
import json
import re

import pytest

import render


@pytest.fixture
def site(tmp_path, monkeypatch):
    data_dir = tmp_path / "data"
    out_dir = tmp_path / "output"
    data_dir.mkdir()
    monkeypatch.setattr(render, "_DATA_DIR", data_dir)
    monkeypatch.setattr(render, "_OUTPUT_DIR", out_dir)
    monkeypatch.setattr(render, "_ROOT", tmp_path)
    return data_dir, out_dir


def _row(rank, close=2500.0, change=12.5):
    return {
        "rank": rank,
        "code": f"{7200 + rank}",
        "name": f"銘柄{rank}",
        "close": close,
        "change_pct": change,
        "metric_value": 1000 * rank,
    }


def _write_day(data_dir, rec_date, rows=3):
    payload = {
        "rec_date": rec_date,
        "gainers": [_row(i + 1) for i in range(rows)],
        "losers": [],
        "active": [],
    }
    (data_dir / f"{rec_date}.json").write_text(
        json.dumps(payload, ensure_ascii=False), encoding="utf-8"
    )


# --- 表示の部品 -----------------------------------------------------------

def test_日付は和暦風の表記と曜日を出す():
    assert render.format_date_ja("2026-09-18") == "2026年9月18日（金）"


def test_次回更新予定は次の営業日():
    assert "2026年9月18日（金）" in render.next_update_note("2026-09-17")
    # 連休を挟まないので、余計な但し書きは付けない
    assert "休場" not in render.next_update_note("2026-09-17")


def test_連休前は休場だと言う():
    note = render.next_update_note("2026-09-18")
    assert "2026年9月24日（木）" in note
    assert "休場" in note


def test_祝日表の範囲外なら黙る():
    # 嘘の更新予定を出すくらいなら何も言わない
    assert render.next_update_note("2030-05-07") == ""


def test_要約は首位と件数を数字で言う():
    rows = [_row(1, change=27.9), _row(2, close=800.0, change=11.0), _row(3, change=4.0)]
    s = render.day_summary(rows, "gainers")
    assert "銘柄1（7201）" in s and "27.90%上昇" in s
    assert "2銘柄が10%以上上昇" in s  # 27.9% と 11.0%
    assert "低位株が1銘柄" in s  # 終値800円


def test_要約は活況ランキングでは約定回数を言う():
    s = render.day_summary([_row(1)], "active")
    assert "約定回数" in s and "1,000回" in s


def test_要約は空データで空文字():
    assert render.day_summary([], "gainers") == ""


def test_アーカイブ一覧は年月でまとまる():
    months = render.group_by_month(["2026-09-01", "2026-08-31", "2026-08-28"])
    assert [m["label"] for m in months] == ["2026年9月", "2026年8月"]
    assert len(months[1]["dates"]) == 2
    assert months[0]["dates"][0]["day"] == "9月1日（火）"


# --- 生成物 ---------------------------------------------------------------

def test_審査前は空の広告枠を出さない(site):
    data_dir, out_dir = site
    _write_day(data_dir, "2026-09-18")
    render.build_all()

    for page in out_dir.rglob("*.html"):
        html = page.read_text(encoding="utf-8")
        assert "adsbygoogle" not in html, page
        assert "ca-pub-XXXX" not in html, page


def test_各日ページに固有の説明文と前後ナビが入る(site):
    data_dir, out_dir = site
    for d in ("2026-09-16", "2026-09-17", "2026-09-18"):
        _write_day(data_dir, d)
    render.build_all()

    mid = (out_dir / "archive" / "gainers" / "2026-09-17.html").read_text(encoding="utf-8")
    assert "首位は" in mid
    assert 'href="2026-09-16.html"' in mid  # 前の営業日
    assert 'href="2026-09-18.html"' in mid  # 次の営業日

    oldest = (out_dir / "archive" / "gainers" / "2026-09-16.html").read_text(encoding="utf-8")
    assert 'class="prev"' not in oldest  # これより古い日は無い


def test_構造化データが妥当なJSONで入る(site):
    data_dir, out_dir = site
    _write_day(data_dir, "2026-09-18")
    render.build_all()

    html = (out_dir / "index.html").read_text(encoding="utf-8")
    blocks = re.findall(r'<script type="application/ld\+json">(.*?)</script>', html, re.S)
    types = [json.loads(b)["@type"] for b in blocks]
    assert "WebSite" in types and "ItemList" in types


def test_404は作られるが検索には出さない(site):
    data_dir, out_dir = site
    _write_day(data_dir, "2026-09-18")
    render.build_all()

    html = (out_dir / "404.html").read_text(encoding="utf-8")
    assert 'name="robots" content="noindex"' in html
    assert "<link rel=\"canonical\"" not in html
    # sitemap に載せない（404 を検索結果に出す意味は無い）
    assert "404" not in (out_dir / "sitemap.xml").read_text(encoding="utf-8")


def test_表は見出しセルを持つ(site):
    data_dir, out_dir = site
    _write_day(data_dir, "2026-09-18")
    render.build_all()

    html = (out_dir / "index.html").read_text(encoding="utf-8")
    assert "<caption>" in html
    assert 'scope="col"' in html and 'scope="row"' in html

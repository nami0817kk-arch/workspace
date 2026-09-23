"""生成されたページの中身のテスト。

表だけのページを量産すると、広告審査でも検索でも「中身が無い」と見なされる。
各日ページに固有の説明文が入ること、前後にたどれること、審査前に空の広告枠を
出さないことを固定する。
"""
import json
import re
from pathlib import Path

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


def test_欠測した営業日を数える():
    days = [
        {"rec_date": "2026-09-18"}, {"rec_date": "2026-09-17"},
        # 9/16（水）が抜けている
        {"rec_date": "2026-09-15"}, {"rec_date": "2026-09-14"},
    ]
    assert render.missing_business_days(days) == ["2026-09-16"]


def test_休場日は欠測に数えない():
    # 9/18(金) → 9/24(木) の間は土日とシルバーウィークで休場
    days = [{"rec_date": "2026-09-24"}, {"rec_date": "2026-09-18"}]
    assert render.missing_business_days(days) == []


def test_欠測を隠さずに書く(site):
    data_dir, out_dir = site
    for d in ("2026-09-14", "2026-09-16"):  # 9/15（火）が抜けている
        _write_day(data_dir, d)
    render.build_all()
    assert "2026-09-15" in (out_dir / "about.html").read_text(encoding="utf-8")


def test_前回からの入れ替わりを数える():
    prev = [_row(1), _row(2), _row(3)]          # コード 7201..7203
    now = [_row(1), _row(2), _row(9)]           # 7201, 7202 が継続、7209 が新顔
    note = render.turnover_note(now, prev)
    assert "2銘柄" in note and "1銘柄" in note


def test_総入れ替えならそう書く():
    note = render.turnover_note([_row(8), _row(9)], [_row(1), _row(2)])
    assert "総入れ替え" in note


def test_比較対象が無ければ何も書かない():
    assert render.turnover_note([_row(1)], None) == ""
    assert render.turnover_note([], [_row(1)]) == ""


def test_文章だけのページに嘘の更新日を書かない(site):
    data_dir, out_dir = site
    _write_day(data_dir, "2026-09-18")
    render.build_all()

    sitemap = (out_dir / "sitemap.xml").read_text(encoding="utf-8")
    for line in sitemap.splitlines():
        if "/privacy" in line or "/guide" in line or "/glossary" in line:
            assert "lastmod" not in line, line
    # データと一緒に変わるページには入れる
    assert any("/about" in l and "2026-09-18" in l for l in sitemap.splitlines())


def test_暗い地の色が定義されている(site):
    data_dir, out_dir = site
    _write_day(data_dir, "2026-09-18")
    render.build_all()

    css = (out_dir / "index.html").read_text(encoding="utf-8")
    assert "prefers-color-scheme: dark" in css
    # グラフの2色は明暗それぞれで定義する（片方だけだと暗い地で沈む）
    assert css.count("--chart-gain:") == 2 and css.count("--chart-loss:") == 2
    assert 'name="color-scheme"' in css


def test_審査前はadsテキストを置かない(site):
    data_dir, out_dir = site
    _write_day(data_dir, "2026-09-18")
    render.build_all()
    # 中身がコメントだけの ads.txt は「有効なレコードが無い」と報告される
    assert not (out_dir / "ads.txt").exists()


def test_pubIDを入れたら有効なレコードを書く(monkeypatch):
    monkeypatch.setattr(render, "ADSENSE_CLIENT", "ca-pub-1234567890123456")
    assert render._ads_txt() == "google.com, pub-1234567890123456, DIRECT, f08c47fec0942fa0\n"


def test_同じ日の他のランキングへ行ける(site):
    data_dir, out_dir = site
    (data_dir / "2026-09-18.json").write_text(json.dumps({
        "rec_date": "2026-09-18",
        "gainers": [_row(1)],
        "losers": [_row(2)],
        "active": [],          # 無い種別はリンクしない
    }, ensure_ascii=False), encoding="utf-8")
    render.build_all()

    html = (out_dir / "archive" / "gainers" / "2026-09-18.html").read_text(encoding="utf-8")
    assert "archive/losers/2026-09-18.html" in html
    assert "archive/active/2026-09-18.html" not in html


def test_パンくずが画面にも出る(site):
    data_dir, out_dir = site
    for d in ("2026-09-17", "2026-09-18"):
        _write_day(data_dir, d)
    render.build_all()

    day = (out_dir / "archive" / "gainers" / "2026-09-18.html").read_text(encoding="utf-8")
    # 構造化データだけ出して画面に無い、という状態にしない
    assert 'aria-label="現在位置"' in day
    assert "BreadcrumbList" in day
    assert 'aria-current="page"' in day


def test_並べ替えはJSが無くても困らない形で入る(site):
    data_dir, out_dir = site
    _write_day(data_dir, "2026-09-18")
    render.build_all()

    html = (out_dir / "index.html").read_text(encoding="utf-8")
    # 値はすべて HTML に書いてあり、並べ替えは上乗せ（列見出しに印だけ付ける）
    assert '<table class="ranking" data-sortable>' in html
    assert "aria-sort" in html
    # 値幅制限の表のような「並べ替えても意味が無い表」には付けない
    # （並べ替えの処理は全ページ共通なので、印が付いた表があるかで見る）
    glossary = (out_dir / "glossary.html").read_text(encoding="utf-8")
    assert '<table class="ranking" data-sortable>' not in glossary


def test_相場の振り返りは日ごとの数字を持つ():
    days = [{
        "rec_date": "2026-09-18",
        "gainers": [
            {"rank": 1, "code": "5131", "name": "リンカーズ", "close": 163.0,
             "change_pct": 44.25, "metric_value": 1},        # ストップ高
            {"rank": 2, "code": "7203", "name": "トヨタ", "close": 2500.0,
             "change_pct": 3.0, "metric_value": 1},
        ],
        "losers": [
            {"rank": 1, "code": "4599", "name": "ステムリム", "close": 239.0,
             "change_pct": -25.08, "metric_value": 1},       # ストップ安
        ],
        "active": [],
    }]
    row = render.market_rows(days)[0]
    assert row == {"rec_date": "2026-09-18", "big": 1, "stop_high": 1,
                   "stop_low": 1, "top_pct": 44.25}


def test_相場の振り返りの一文は最も荒れた日を指す():
    rows = [
        {"rec_date": "2026-09-18", "big": 5, "stop_high": 2, "stop_low": 0, "top_pct": 10.0},
        {"rec_date": "2026-09-17", "big": 12, "stop_high": 3, "stop_low": 1, "top_pct": 20.0},
    ]
    s = render.market_summary(rows)
    # 文章の中の日付は日本語表記に揃える（表や URL は ISO のまま）
    assert "9月17日（木）" in s and "12銘柄" in s
    assert "のべ5銘柄" in s


def test_配信ヘッダが成果物に入る(site):
    data_dir, out_dir = site
    _write_day(data_dir, "2026-09-18")
    # static/ は _ROOT を差し替えると空になるので、本物の静的ファイルを見る
    render.build_all()
    real_headers = Path(__file__).resolve().parents[1] / "static" / "_headers"
    assert real_headers.exists()
    text = real_headers.read_text(encoding="utf-8")
    for header in ("X-Content-Type-Options", "X-Frame-Options", "Referrer-Policy"):
        assert header in text


def test_日付の書き方の決まり():
    # 文章の中は日本語表記、表や URL は ISO。混ざると読みづらく、
    # 直すたびにどちらかへ揺れるので決めておく。
    assert render.format_date_ja("2026-09-18") == "2026年9月18日（金）"
    assert render.format_date_short_ja("2026-09-18") == "9月18日（金）"


def test_週の比較は1営業日あたりで見る():
    # 連休で3日しかない週と5日の週を、そのまま比べると誤解する
    week = {"day_count": 3, "big_moves": 30}      # 1日あたり10
    previous = {"day_count": 5, "big_moves": 50}  # 1日あたり10
    assert "同じくらい" in render.week_comparison(week, previous)

    assert "荒い動きが増え" in render.week_comparison(
        {"day_count": 5, "big_moves": 75}, previous)
    assert "落ち着き" in render.week_comparison(
        {"day_count": 5, "big_moves": 20}, previous)


def test_比べる週が無ければ何も書かない():
    assert render.week_comparison({"day_count": 5, "big_moves": 10}, None) == ""
    assert render.week_comparison({"day_count": 5, "big_moves": 10},
                                  {"day_count": 5, "big_moves": 0}) == ""

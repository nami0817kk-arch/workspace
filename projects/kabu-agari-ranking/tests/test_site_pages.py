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
import site_config


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

def test_pubIDが空のあいだは広告を出さない(site, monkeypatch):
    monkeypatch.setattr(render, "ADSENSE_CLIENT", "")
    monkeypatch.setitem(render._env.globals, "ADSENSE_CLIENT", "")
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
    # 画面には日本語表記で出す（文章の中なので）
    assert "2026年9月15日（火）" in (out_dir / "about.html").read_text(encoding="utf-8")


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


def test_pubIDが空のあいだはadsテキストを置かない(site, monkeypatch):
    monkeypatch.setattr(render, "ADSENSE_CLIENT", "")
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
                   "stop_low": 1, "stop_source": "estimated", "top_pct": 44.25}


def test_相場の振り返りは記録がある日は全件を数える():
    """ストップ高のページと同じ数え方を使う。別々に数えると、同じ日の件数が
    ページによって違うという、直しようのない食い違いになる。"""
    days = [{
        "rec_date": "2026-09-28",
        # 値上がり上位30銘柄には1件しか出ていないが、
        "gainers": [
            {"rank": 1, "code": "5131", "name": "リンカーズ", "close": 163.0,
             "change_pct": 44.25, "metric_value": 1},
        ],
        "losers": [],
        "active": [],
        # 取得元の一覧には3件あった（うち引けまで保ったのは2件）
        "stop_high": [
            {"rank": 1, "code": "5131", "name": "リンカーズ", "close": 163.0,
             "change_pct": 44.25, "at_limit": True},
            {"rank": 2, "code": "9999", "name": "上位外", "close": 500.0,
             "change_pct": 20.0, "at_limit": True},
            {"rank": 3, "code": "8888", "name": "場中だけ", "close": 700.0,
             "change_pct": 15.0, "at_limit": False},
        ],
        "stop_low": [
            {"rank": 1, "code": "4599", "name": "ステムリム", "close": 239.0,
             "change_pct": -25.08, "at_limit": True},
        ],
    }]
    row = render.market_rows(days)[0]
    assert row["stop_high"] == 2
    assert row["stop_low"] == 1
    assert row["stop_source"] == "recorded"


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


def test_壊れたデータ1件でサイト全体を落とさない(site, capsys):
    data_dir, out_dir = site
    _write_day(data_dir, "2026-09-18")
    _write_day(data_dir, "2026-09-17")
    (data_dir / "2026-09-16.json").write_text("{壊れている", encoding="utf-8")

    render.build_all()   # 例外にしない

    assert (out_dir / "index.html").exists()
    assert "[WARN]" in capsys.readouterr().out
    # 読めた2日はちゃんと出る
    assert (out_dir / "archive" / "gainers" / "2026-09-18.html").exists()


def test_データが1件も読めなければ止める(site):
    data_dir, _ = site
    (data_dir / "2026-09-18.json").write_text("{壊れている", encoding="utf-8")
    with pytest.raises(RuntimeError):
        render.build_all()


def test_日付を確定した4日分は公開する():
    # 株探の日足と突き合わせて実際の相場日を確定させた（tools/verify_rec_date.py）。
    # 確定できなかったものを入れる仕組み自体は残す。
    assert render.UNRELIABLE_DATES == frozenset()
    assert render.DATE_CORRECTIONS == {
        "2026-08-31": "2026-09-01",
        "2026-09-01": "2026-09-02",
    }


def test_読み込み時に日付を読み替える(site):
    data_dir, out_dir = site
    _write_day(data_dir, "2026-08-31")   # 中身の rec_date も 2026-08-31
    _write_day(data_dir, "2026-09-04")
    render.build_all()

    # 実際の相場日（2026-09-01）として公開される
    assert (out_dir / "archive" / "gainers" / "2026-09-01.html").exists()
    assert not (out_dir / "archive" / "gainers" / "2026-08-31.html").exists()


def test_同じ相場日のファイルが2つあれば片方を捨てて警告する(site, capsys):
    data_dir, out_dir = site
    # 2026-09-01 は 2026-09-02 に読み替えられるので、09-02 のファイルと重なる。
    # （08-31 は 09-01 に読み替えられるため、09-01 とは重ならない＝読み替えは連鎖する）
    _write_day(data_dir, "2026-09-01")
    _write_day(data_dir, "2026-09-02")
    _write_day(data_dir, "2026-09-04")
    render.build_all()

    out = capsys.readouterr().out
    assert "二重登録" in out
    # 二重に数えていないこと（3ファイルだが相場日は 09-01 と 09-04 の2日）
    assert "（2日分）" in out


def test_ドメインを持つのは1箇所だけ():
    """ドメインの直書きを増やさない。

    canonical・sitemap・RSS・OGP・X の投稿文が別々にドメインを持つと、
    移したときに直し漏れて「canonical は旧、sitemap は新」という
    矛盾した指示を検索エンジンに出すことになる。
    """
    src = Path(__file__).resolve().parents[1] / "src"
    offenders = []
    for path in src.glob("*.py"):
        if path.name == "site_config.py":
            continue
        if "pages.dev" in path.read_text(encoding="utf-8"):
            offenders.append(path.name)
    assert not offenders, f"ドメインを直書きしている: {offenders}"


def test_環境変数でドメインを差し替えられる(monkeypatch):
    # 本番と手元で別のドメインを見たいときのため
    monkeypatch.setenv("KABU_SITE_URL", "https://example.test/")
    import importlib

    import site_config
    importlib.reload(site_config)
    assert site_config.SITE_URL == "https://example.test"   # 末尾のスラッシュは落とす
    monkeypatch.delenv("KABU_SITE_URL")
    importlib.reload(site_config)


def test_スマホで一番見たい列が横スクロールの外に出ない(site):
    """騰落率が横スクロールの向こう側にあると、来た人の目的が果たせない。

    狭い画面では出来高（優先度がいちばん低い列）を落とすので、
    表の最後の列が出来高であることを固定しておく。
    """
    data_dir, out_dir = site
    _write_day(data_dir, "2026-09-18")
    render.build_all()

    html = (out_dir / "index.html").read_text(encoding="utf-8")
    headers = re.findall(r'<th scope="col">([^<]*)</th>', html)
    assert headers[:5] == ["順位", "銘柄名", "コード", "終値", "騰落率"]
    assert headers[5] == "出来高", "最後の列（狭い画面で落とす列）が出来高でなくなっている"
    assert "max-width: 600px" in html


def test_銘柄ページがある銘柄だけ名前をリンクにする(site):
    data_dir, out_dir = site
    # 同じ銘柄が3日出れば銘柄ページができる（_write_day は同じ銘柄を並べる）
    for d in ("2026-09-16", "2026-09-17", "2026-09-18"):
        _write_day(data_dir, d)
    render.build_all()

    html = (out_dir / "index.html").read_text(encoding="utf-8")
    assert 'href="stock/7201/">銘柄1</a>' in html


def test_運営者情報と問い合わせが名義と連絡先を出す(site):
    """AdSense は「誰が運営し、どこへ連絡できるか」が読めることを求める。

    どちらかが空のまま審査に出すと落ちるので、中身が入っていることを固定する。
    """
    data_dir, out_dir = site
    _write_day(data_dir, "2026-09-18")
    render.build_all()

    operator = (out_dir / "operator.html").read_text(encoding="utf-8")
    contact = (out_dir / "contact.html").read_text(encoding="utf-8")

    assert site_config.OWNER and site_config.OWNER in operator
    # mailto: では書かない。Cloudflare の Email Address Obfuscation が
    # 「[email protected]」に差し替えてしまい、JS が動かない相手には読めなくなる。
    shown = site_config.CONTACT_EMAIL.replace("@", "[at]")
    assert site_config.CONTACT_EMAIL
    assert shown in contact
    assert "mailto:" not in contact
    # 行き止まりにしない（審査は「たどり着けるか」も見る）
    assert 'href="contact.html"' in operator
    assert 'href="operator.html"' in contact


def test_どのページからも運営者情報と問い合わせへ行ける(site):
    data_dir, out_dir = site
    _write_day(data_dir, "2026-09-18")
    render.build_all()

    for name in ("index.html", "privacy.html", "about.html"):
        html = (out_dir / name).read_text(encoding="utf-8")
        assert 'href="operator.html"' in html, name
        assert 'href="contact.html"' in html, name


def test_公開ページに個人名を出さない(site):
    """名義は屋号だけ。Windows のユーザー名がパスごと混ざるのも防ぐ。"""
    data_dir, out_dir = site
    _write_day(data_dir, "2026-09-18")
    render.build_all()

    for path in out_dir.rglob("*.html"):
        text = path.read_text(encoding="utf-8")
        for leak in ("なみ", "nami", "0817"):
            assert leak not in text, f"{path.name} に {leak} が出ている"


def test_運営者情報と問い合わせがsitemapに載る(site):
    data_dir, out_dir = site
    _write_day(data_dir, "2026-09-18")
    render.build_all()

    xml = (out_dir / "sitemap.xml").read_text(encoding="utf-8")
    # 配信される形（.html なし）で載る。canonical_url がそこを揃えている。
    assert f"<loc>{site_config.SITE_URL}/operator</loc>" in xml
    assert f"<loc>{site_config.SITE_URL}/contact</loc>" in xml


def test_トップと当日アーカイブのタイトルが別物(site):
    """同じ中身が2つのURLにある日は、タイトルまで同じだと重複が強く出る。

    トップは「今日のランキングを探している人」の入口、アーカイブは
    「その日付の記録」。狙う言葉が違うので、書き分ける。
    """
    data_dir, out_dir = site
    _write_day(data_dir, "2026-09-18")
    render.build_all()

    def title(path):
        return re.search(r"<title>(.*?)</title>",
                         (out_dir / path).read_text(encoding="utf-8")).group(1)

    top = title("index.html")
    archive = title("archive/gainers/2026-09-18.html")
    assert top != archive
    assert top.startswith("本日の")          # 日付を先頭に置かない
    assert "2026-09-18" in archive           # 日付で引ける


def test_タイトルが長すぎない(site):
    """検索結果で切られると、何のページか読めなくなる。"""
    data_dir, out_dir = site
    for d in ("2026-09-16", "2026-09-17", "2026-09-18"):
        _write_day(data_dir, d)
    render.build_all()

    too_long = []
    for page in out_dir.rglob("*.html"):
        t = re.search(r"<title>(.*?)</title>", page.read_text(encoding="utf-8")).group(1)
        if len(t) > 40:
            too_long.append(f"{page.relative_to(out_dir)} ({len(t)}字) {t}")
    assert not too_long, "タイトルが長すぎる:\n" + "\n".join(too_long)


def test_pubIDを入れると審査に必要なスクリプトだけが出る(site, monkeypatch):
    """審査に要るのは head のスクリプト。枠は自動広告が置く。

    枠ID が無いまま <ins data-ad-slot="0000000000"> のような作り物を置くと、
    審査でも配信でも通らない。
    """
    data_dir, out_dir = site
    _write_day(data_dir, "2026-09-18")
    monkeypatch.setitem(render._env.globals, "ADSENSE_CLIENT", "ca-pub-1234567890123456")
    monkeypatch.setitem(render._env.globals, "ADSENSE_SLOT", "")
    render.build_all()

    html = (out_dir / "index.html").read_text(encoding="utf-8")
    assert "adsbygoogle.js?client=ca-pub-1234567890123456" in html   # head のスクリプト
    assert "<ins" not in html                                        # 枠は出さない


def test_枠IDを入れたときだけ枠を出す(site, monkeypatch):
    data_dir, out_dir = site
    _write_day(data_dir, "2026-09-18")
    monkeypatch.setitem(render._env.globals, "ADSENSE_CLIENT", "ca-pub-1234567890123456")
    monkeypatch.setitem(render._env.globals, "ADSENSE_SLOT", "9876543210")
    render.build_all()

    html = (out_dir / "index.html").read_text(encoding="utf-8")
    assert 'data-ad-slot="9876543210"' in html
    assert "0000000000" not in html


def test_広告を本文の先頭に置かない(site, monkeypatch):
    """ここに広告が入ると、見に来たランキングが1画面ぶん下へ押し出される。"""
    data_dir, out_dir = site
    _write_day(data_dir, "2026-09-18")
    monkeypatch.setitem(render._env.globals, "ADSENSE_CLIENT", "ca-pub-1234567890123456")
    monkeypatch.setitem(render._env.globals, "ADSENSE_SLOT", "9876543210")
    render.build_all()

    html = (out_dir / "index.html").read_text(encoding="utf-8")
    body = html[html.index("<main"):]
    assert body.index("<table") < body.index("<ins"), "表より先に広告が出ている"


def test_案内は本文の後ろに置く(site):
    """横の案内（rail）が本文より先に来ると、スマホでランキングの前に
    リンクの列が挟まる。HTML の順序で本文を先にしておく。"""
    data_dir, out_dir = site
    _write_day(data_dir, "2026-09-18")
    render.build_all()

    html = (out_dir / "index.html").read_text(encoding="utf-8")
    assert html.index("<main") < html.index('class="rail"')
    assert html.index("<table") < html.index('class="rail"')


def test_アイコンを配る(site):
    data_dir, out_dir = site
    _write_day(data_dir, "2026-09-18")
    render.build_all()

    html = (out_dir / "index.html").read_text(encoding="utf-8")
    assert 'rel="icon"' in html
    assert (Path(__file__).resolve().parents[1] / "static" / "favicon.svg").exists()


def test_列幅の指定は広い画面だけに当てる(site):
    """狭い画面に当てると銘柄名の幅が足りず、毎行2行に折り返す。"""
    data_dir, out_dir = site
    _write_day(data_dir, "2026-09-18")
    render.build_all()

    css = (out_dir / "index.html").read_text(encoding="utf-8")
    block = css[css.index("余った幅は銘柄名に回し"):]
    assert "@media (min-width: 601px)" in block[:400]


def test_トップのカレンダーは表より後ろ(site):
    """カレンダーが表より上に来ると、見に来たランキングが押し出される。"""
    data_dir, out_dir = site
    for d in ("2026-09-17", "2026-09-18"):
        _write_day(data_dir, d)
    render.build_all()

    html = (out_dir / "index.html").read_text(encoding="utf-8")
    assert html.index("<table") < html.index('class="calendar"')
    # トップは直近1か月だけ（全期間はアーカイブ一覧）
    assert html.count('class="cal-month"') == 1


def test_姉妹サイトへ戻る線がある(site):
    """入口からは3サイトへリンクされているのに、こちらから戻る線が無かった。

    読み手が他のものを見つけられないうえ、検索側から見ても一群のサイトとして
    繋がっていない状態になる。
    """
    data_dir, out_dir = site
    _write_day(data_dir, "2026-09-18")
    render.build_all()

    html = (out_dir / "index.html").read_text(encoding="utf-8")
    assert 'href="https://dailyquarry.com/"' in html
    # 自分自身は姉妹サイトに並べない
    assert html.count('href="https://kabu.dailyquarry.com/"') <= 1

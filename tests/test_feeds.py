from datetime import datetime, timezone

import pytest

from src.feeds import FeedError, Item, _when, age_text, parse, recent

NOW = datetime(2026, 8, 31, 12, 0, tzinfo=timezone.utc)

RSS = """<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0"><channel>
  <title>Sky Sports News</title>
  <item>
    <title><![CDATA[Deadline day: Alvarez decision due]]></title>
    <link>https://www.skysports.com/football/news/11095/13579500/alvarez</link>
    <pubDate>Mon, 31 Aug 2026 09:00:00 GMT</pubDate>
  </item>
  <item>
    <title>Older story</title>
    <link>https://www.skysports.com/football/news/11095/13579000/older</link>
    <pubDate>Sun, 30 Aug 2026 09:00:00 GMT</pubDate>
  </item>
  <item>
    <title>リンクの無い壊れた項目</title>
  </item>
</channel></rss>"""

ATOM = """<?xml version="1.0" encoding="utf-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <title>Some Blog</title>
  <entry>
    <title>Chelsea complete &lt;b&gt;signing&lt;/b&gt;</title>
    <link rel="alternate" href="https://example.com/chelsea-signing"/>
    <published>2026-08-31T10:30:00Z</published>
  </entry>
</feed>"""


def test_rss_items_come_back_newest_first_with_times():
    items = parse(RSS)
    assert [i.title for i in items] == ["Deadline day: Alvarez decision due", "Older story"]
    assert items[0].published == datetime(2026, 8, 31, 9, 0, tzinfo=timezone.utc)
    assert items[0].hours_ago(NOW) == 3.0


def test_broken_items_are_skipped_not_fatal():
    assert len(parse(RSS)) == 2          # リンクの無い項目は落とす


def test_atom_entries_are_read_and_tags_stripped():
    (item,) = parse(ATOM)
    assert item.title == "Chelsea complete signing"
    assert item.url == "https://example.com/chelsea-signing"
    assert item.hours_ago(NOW) == 1.5


def test_garbage_raises_a_readable_error():
    with pytest.raises(FeedError, match="読めません"):
        parse("これはXMLではない")


def test_the_line_format_feeds_straight_into_collect():
    from src.collect import parse as collect_parse

    items = parse(RSS)
    text = "\n".join(item.line() for item in items)

    class _Now:
        pass

    # fetch の出力を collect が読み、経過時間が候補に乗る
    hits = collect_parse(text)
    assert hits[0].url.endswith("/alvarez")
    assert hits[0].hours_ago >= 0        # 3列目が読めている


def test_items_without_a_time_still_line_up():
    item = Item(title="時刻なし", url="https://example.com/a")
    assert item.line() == "時刻なし\thttps://example.com/a"
    assert item.hours_ago(NOW) is None


def test_recent_keeps_the_window_and_the_undated():
    items = [
        Item("新しい", "https://a.example/1", datetime(2026, 8, 31, 10, 0, tzinfo=timezone.utc)),
        Item("古い", "https://a.example/2", datetime(2026, 8, 28, 10, 0, tzinfo=timezone.utc)),
        Item("時刻なし", "https://a.example/3"),
    ]
    kept = recent(items, hours=24, now=NOW)
    # 判断できないもの（時刻なし）は落とさない
    assert [i.title for i in kept] == ["新しい", "時刻なし"]


def test_a_naive_pubdate_is_treated_as_utc():
    text = RSS.replace("Mon, 31 Aug 2026 09:00:00 GMT", "2026-08-31T09:00:00")
    items = parse(text)
    assert items[0].published.tzinfo is not None


# ---------------------------------------------------------------- 探す
# フィードのURLを当て推量で探すと外す。実測で Sky の全スポーツ版を掴んで、
# クリケットも競馬もゴルフも候補に混ざった。ページ自身に聞けば外さない。

PAGE = """<html><head>
<link rel="alternate" type="application/rss+xml" title="Football News &amp; Transfers" href="/rss/11661">
<link rel="stylesheet" href="/style.css">
<link rel='alternate' type='application/atom+xml' title='All Sport' href='https://other.example/atom'>
<link rel="alternate" type="application/rss+xml" href="/rss/11661">
</head></html>"""


def _page(monkeypatch, html):
    from src import feeds

    monkeypatch.setattr(feeds, "_get", lambda url, timeout=15: html)


def test_ページが宣言しているフィードを拾う(monkeypatch):
    from src import feeds

    _page(monkeypatch, PAGE)
    found = feeds.discover("https://www.skysports.com/football")
    assert ("Football News & Transfers", "https://www.skysports.com/rss/11661") in found


def test_相対URLは絶対に直す(monkeypatch):
    from src import feeds

    _page(monkeypatch, PAGE)
    assert all(url.startswith("http") for _, url in feeds.discover("https://www.skysports.com/football"))


def test_フィード以外のlinkは拾わない(monkeypatch):
    from src import feeds

    _page(monkeypatch, PAGE)
    assert not any("style.css" in url for _, url in feeds.discover("https://x.example/"))


def test_同じURLは1つにする(monkeypatch):
    from src import feeds

    _page(monkeypatch, PAGE)
    urls = [url for _, url in feeds.discover("https://www.skysports.com/football")]
    assert len(urls) == len(set(urls))


def test_名前が無くても捨てない(monkeypatch):
    from src import feeds

    _page(monkeypatch, '<link rel="alternate" type="application/rss+xml" href="https://x.example/f">')
    assert feeds.discover("https://x.example/") == [("（名前なし）", "https://x.example/f")]


def test_宣言が無ければ空(monkeypatch):
    from src import feeds

    _page(monkeypatch, "<html><head><title>なにもない</title></head></html>")
    assert feeds.discover("https://x.example/") == []


# フィード側の時計が進んでいることがある（Sky は実測で40分ほど先）。
# そのまま引き算すると「最新 -0.7時間前」になって読めない。


def test_進んだ時刻は先であることが分かるように言う():
    assert "40分先" in age_text(-0.67)
    assert "時計が進んでいる" in age_text(-0.67)


def test_ふつうの経過時間はそのまま言う():
    assert age_text(1.26) == "最新 1.3時間前"
    assert age_text(0.0) == "最新 0.0時間前"


def test_時刻が無いフィードもある():
    assert age_text(None) == "時刻なし"


# RFC822 は BST や CEST という名前を知らない。読めないと「時間帯なし」になり、
# こちらが UTC とみなして、夏時間のぶんだけ見出しが新しい方へずれていた。
# Sky は BST と書いてくるので、全部の見出しが1時間新しくなっていた。


def test_BSTは英国夏時間として読む():
    when = _when("Mon, 31 Aug 2026 15:50:10 BST")
    assert when.utcoffset().total_seconds() == 3600
    assert when.astimezone(timezone.utc).hour == 14


def test_CESTは中欧夏時間として読む():
    when = _when("Mon, 31 Aug 2026 15:50:10 CEST")
    assert when.utcoffset().total_seconds() == 7200


def test_GMTと数字の時差はそのまま():
    assert _when("Mon, 31 Aug 2026 15:50:10 GMT").utcoffset().total_seconds() == 0
    assert _when("Mon, 31 Aug 2026 15:50:10 +0900").utcoffset().total_seconds() == 32400


def test_知らない名前は当てずにUTCのままにする():
    """IST はアイルランドとインドで割れる。当てられないものを当てたことにしない。"""
    assert _when("Mon, 31 Aug 2026 15:50:10 IST").utcoffset().total_seconds() == 0
    assert _when("Mon, 31 Aug 2026 15:50:10 XYZ").utcoffset().total_seconds() == 0


def test_Skyの見出しが未来のものにならない():
    now = datetime(2026, 8, 31, 14, 55, tzinfo=timezone.utc)
    sky = """<?xml version="1.0"?>
    <rss version="2.0"><channel>
      <item><title>Newcastle closing in on deal</title>
        <link>https://www.skysports.com/football/news/1</link>
        <pubDate>Mon, 31 Aug 2026 15:50:10 BST</pubDate></item>
    </channel></rss>"""
    age = parse(sky)[0].hours_ago(now)
    assert age > 0, "BSTをUTC扱いすると未来の投稿になる"
    assert age == pytest.approx(0.08, abs=0.02)

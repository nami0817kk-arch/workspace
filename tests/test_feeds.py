from datetime import datetime, timezone

import pytest

from src.feeds import FeedError, Item, parse, recent

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

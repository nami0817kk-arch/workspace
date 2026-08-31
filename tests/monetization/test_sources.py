from datetime import datetime, timezone

from moneyloop.models import content_hash
from moneyloop.sources import collect, parse_datetime, parse_feed, strip_html


def test_parse_rss_extracts_items():
    xml = """<rss version="2.0"><channel>
      <item><title>Hello &amp; World</title><link>https://a.test/x</link>
            <description>&lt;p&gt;body&lt;/p&gt;</description>
            <pubDate>Fri, 28 Aug 2026 10:00:00 GMT</pubDate></item>
    </channel></rss>"""
    items = parse_feed(xml, "n", "src")
    assert len(items) == 1
    assert items[0].title == "Hello & World"
    assert items[0].summary == "body"
    assert items[0].published_at == datetime(2026, 8, 28, 10, tzinfo=timezone.utc)


def test_parse_atom_uses_link_href():
    xml = """<feed xmlns="http://www.w3.org/2005/Atom">
      <entry><title>Atom</title><link href="https://b.test/y"/><summary>s</summary>
             <updated>2026-08-28T10:00:00Z</updated></entry></feed>"""
    items = parse_feed(xml, "n", "src")
    assert items[0].url == "https://b.test/y"


def test_parse_feed_survives_broken_xml():
    assert parse_feed("<rss><channel><item>", "n", "s") == []


def test_items_without_valid_link_are_dropped():
    xml = """<rss version="2.0"><channel>
      <item><title>no link</title><description>d</description></item>
      <item><title>relative</title><link>/relative</link></item>
    </channel></rss>"""
    assert parse_feed(xml, "n", "s") == []


def test_hash_ignores_tracking_params_and_trailing_slash():
    assert content_hash("A", "https://x.test/a/?utm_source=1") == content_hash("a", "https://X.test/a")


def test_collect_reports_failing_source_without_raising(config):
    def boom(url, timeout=20.0):
        raise OSError("dns failure")

    items, errors = collect(config.niches[0], fetcher=boom)
    assert items == []
    assert "取得失敗" in errors[0]


def test_collect_keeps_items_with_unknown_date(config, fetcher):
    items, errors = collect(config.niches[0], lookback_hours=1, fetcher=fetcher)
    assert len(items) == 3 and errors == []


def test_strip_html_and_bad_date():
    assert strip_html("<b> a  b </b>") == "a b"
    assert parse_datetime("not a date") is None

"""情報収集コネクタ（RSS / Qiita）。"""

import pytest
from fakes import FakeResponse, FakeSession

from imagegen.connectors.feed_qiita import QiitaFeed
from imagegen.connectors.feed_rss import RssFeed, parse_feed
from imagegen.core.errors import ConfigError, ConnectorError

RSS_XML = """<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:dc="http://purl.org/dc/elements/1.1/">
  <channel>
    <title>例のブログ</title>
    <item>
      <title>1件目の記事</title>
      <link>https://example.com/1</link>
      <pubDate>Mon, 03 Aug 2026 09:00:00 +0900</pubDate>
      <description>&lt;p&gt;本文の要約&lt;/p&gt;</description>
      <dc:creator>Taro</dc:creator>
      <category>AI</category>
      <category>Python</category>
    </item>
  </channel>
</rss>
"""

ATOM_XML = """<?xml version="1.0" encoding="utf-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <title>例のフィード</title>
  <entry>
    <title>Atomの記事</title>
    <link rel="alternate" href="https://example.com/atom-1"/>
    <published>2026-08-02T12:00:00Z</published>
    <summary>要約テキスト</summary>
    <author><name>Hanako</name></author>
    <category term="release"/>
  </entry>
</feed>
"""


def test_rss_parses_items():
    item = parse_feed(RSS_XML, "https://example.com/feed")[0]
    assert item.title == "1件目の記事"
    assert item.url == "https://example.com/1"
    assert item.author == "Taro"
    assert item.summary == "本文の要約"  # HTMLタグは落とす
    assert item.tags == ["AI", "Python"]
    assert item.meta["feed"] == "https://example.com/feed"


def test_atom_parses_entries():
    item = parse_feed(ATOM_XML)[0]
    assert item.title == "Atomの記事"
    assert item.url == "https://example.com/atom-1"
    assert item.author == "Hanako"
    assert item.published.startswith("2026-08-02")
    assert item.tags == ["release"]


def test_broken_xml_is_reported():
    with pytest.raises(ConnectorError, match="解析できませんでした"):
        parse_feed("<rss><item>閉じていない")


def test_rss_fetches_and_limits(monkeypatch):
    sess = FakeSession([FakeResponse(content=RSS_XML.encode("utf-8"))])
    items = RssFeed(session=sess).fetch_items("https://example.com/feed", limit=1)
    assert len(items) == 1
    assert sess.calls[0][1] == "https://example.com/feed"


def test_rss_requires_a_url():
    with pytest.raises(ConfigError, match="フィードのURL"):
        RssFeed().fetch_items("キーワード")


def test_rss_check_is_marked_as_unverified():
    result = RssFeed().check()
    assert result.skipped and result.ok


def test_qiita_maps_items():
    body = [
        {
            "title": "Claude Code の使い方",
            "url": "https://qiita.com/items/abc",
            "created_at": "2026-08-10T00:00:00+09:00",
            "body": "本文",
            "user": {"id": "taro"},
            "tags": [{"name": "AI"}],
            "likes_count": 5,
        }
    ]
    sess = FakeSession([FakeResponse(json_data=body)])

    item = QiitaFeed(session=sess).fetch_items("claude", limit=1)[0]

    assert (item.source, item.title, item.author) == ("qiita", "Claude Code の使い方", "taro")
    assert item.tags == ["AI"]
    assert item.meta["likes"] == 5
    assert sess.last_params()["query"] == "claude"


def test_qiita_works_without_token():
    connector = QiitaFeed()
    assert connector.is_available()  # トークンは任意
    assert connector.unavailable_reason() == ""
    assert connector.default_headers() == {}


def test_qiita_sends_token_when_present(monkeypatch):
    monkeypatch.setenv("QIITA_TOKEN", "q-test")
    assert QiitaFeed().default_headers()["Authorization"] == "Bearer q-test"

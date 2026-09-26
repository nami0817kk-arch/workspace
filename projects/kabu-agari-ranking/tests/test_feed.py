"""RSSフィードのテスト。

フィードは機械が読むもので、少しでも壊れていると黙って読まれなくなる。
XMLとして妥当であること、必要な要素が揃っていることを見る。
"""
import xml.etree.ElementTree as ET

import feed


def _days(n=3):
    return [
        {
            "rec_date": f"2026-09-{18 - i:02d}",
            "gainers": [{"rank": 1, "code": "7203", "name": "銘柄&<test>",
                         "close": 100.0, "change_pct": 5.0, "metric_value": 1}],
        }
        for i in range(n)
    ]


def _build(days):
    return feed.build(
        days,
        site_url="https://example.test",
        url_for=lambda rec: f"https://example.test/archive/gainers/{rec}",
        summarize=lambda rows: f"{rows[0]['name']} が首位",
    )


def test_妥当なXMLで必要な要素が揃う():
    root = ET.fromstring(_build(_days()))
    channel = root.find("channel")
    assert channel.find("title").text
    assert channel.find("language").text == "ja"
    items = channel.findall("item")
    assert len(items) == 3
    for item in items:
        for tag in ("title", "link", "guid", "pubDate", "description"):
            assert item.find(tag) is not None and item.find(tag).text


def test_新しい日が先頭に来る():
    root = ET.fromstring(_build(_days()))
    titles = [i.find("title").text for i in root.findall(".//item")]
    assert titles == sorted(titles, reverse=True)


def test_発行時刻はRFC822でJST():
    root = ET.fromstring(_build(_days(1)))
    assert root.find(".//item/pubDate").text == "Fri, 18 Sep 2026 16:10:00 +0900"


def test_銘柄名の記号でXMLが壊れない():
    root = ET.fromstring(_build(_days(1)))
    assert "銘柄&<test>" in root.find(".//item/description").text


def test_件数の上限を守る():
    days = [{"rec_date": f"2026-09-{i:02d}",
             "gainers": [{"rank": 1, "code": "1", "name": "x",
                          "close": 1.0, "change_pct": 1.0, "metric_value": 1}]}
            for i in range(28, 0, -1)]
    assert len(ET.fromstring(_build(days)).findall(".//item")) == feed.FEED_ITEMS


def test_データが空でも壊れたXMLにしない():
    root = ET.fromstring(_build([]))
    assert root.findall(".//item") == []

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
        # 本文と同じ文にするため、行だけでなくその日のデータを受け取る
        summarize=lambda day: f"{day['gainers'][0]['name']} が首位",
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


def test_説明文はページの本文と同じ数え方(tmp_path, monkeypatch):
    """記録がある日に「上位30銘柄のうち N 銘柄はストップ高です」という
    別の数え方が RSS にだけ残っていた（2026-09-28 に揃えた）。"""
    import render
    day = {
        "rec_date": "2026-09-28",
        "gainers": [{"rank": i, "code": f"{1000 + i}", "name": f"銘柄{i}", "close": 163.0,
                     "change_pct": 44.25, "metric_value": 1} for i in range(1, 31)],
        "losers": [], "active": [],
        # 31件目は上位30銘柄の外
        "stop_high": [{"rank": i, "code": f"{1000 + i}", "name": f"銘柄{i}", "close": 163.0,
                       "change_pct": 44.25, "at_limit": True} for i in range(1, 32)],
    }
    text = render._feed_summary(day)
    assert "この日ストップ高になったのは31銘柄です（うち1銘柄は上位30銘柄の外）。" in text
    assert "うち30銘柄はストップ高です" not in text, "上位30銘柄の中の数をそのまま出している"


def test_記録が無い日は従来どおり():
    import render
    day = {
        "rec_date": "2026-09-18",
        "gainers": [{"rank": 1, "code": "5131", "name": "リンカーズ", "close": 163.0,
                     "change_pct": 44.25, "metric_value": 1}],
        "losers": [], "active": [],
    }
    text = render._feed_summary(day)
    assert "ストップ高です" in text
    assert "この日ストップ高になったのは" not in text

"""更新を受け取るための RSS フィード。

サイトの更新を知る手段が何も無かった。フィードなら費用も運用の手間もかからず、
こちらから何も送らずに済む（購読は読む側の操作だけで完結する）。
"""
from __future__ import annotations

from datetime import date, datetime, time, timedelta, timezone
from email.utils import format_datetime
from xml.sax.saxutils import escape

JST = timezone(timedelta(hours=9))

# 載せる日数。古い日を延々と配っても読む人はいない。
FEED_ITEMS = 20

# 取得は毎営業日16:10。相場日のその時刻を発行時刻として扱う。
PUBLISHED_AT = time(16, 10)


def build(days: list[dict], *, site_url: str, url_for, summarize) -> str:
    """RSS 2.0 の XML を組み立てて返す。

    url_for(rec_date) … その日のページの URL
    summarize(rows) … その日の一言（本文に出しているものと同じ）
    """
    items = []
    for day in days[:FEED_ITEMS]:
        rows = day.get("gainers") or []
        if not rows:
            continue
        url = url_for(day["rec_date"])
        published = datetime.combine(
            date.fromisoformat(day["rec_date"]), PUBLISHED_AT, tzinfo=JST
        )
        items.append(
            "    <item>\n"
            f"      <title>{escape(day['rec_date'])} 値上がりランキング TOP{len(rows)}</title>\n"
            f"      <link>{escape(url)}</link>\n"
            f'      <guid isPermaLink="true">{escape(url)}</guid>\n'
            f"      <pubDate>{format_datetime(published)}</pubDate>\n"
            f"      <description>{escape(summarize(rows))}</description>\n"
            "    </item>"
        )

    head = (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom">\n'
        "  <channel>\n"
        "    <title>値上がり株ランキング</title>\n"
        f"    <link>{site_url}/</link>\n"
        "    <description>日本株の値上がり・値下がり・活況ランキングを、"
        "東証の営業日ごとに更新しています。</description>\n"
        "    <language>ja</language>\n"
        f'    <atom:link href="{site_url}/feed.xml" rel="self" type="application/rss+xml"/>\n'
    )
    body = "\n".join(items)
    return head + (body + "\n" if body else "") + "  </channel>\n</rss>\n"

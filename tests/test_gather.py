"""収集を一息で行う。

フィード取得 → collect → 重複除去 → 候補ファイル を手で繋ぐと、
どれかを飛ばす。飛ばしても何も言われない。
"""

from datetime import date, datetime, timedelta, timezone

import pytest

from src import gather
from src.collect import parse
from src.coverage import Entry
from src.feeds import Item
from src.plan import build_plan

RAW = {
    "tiers": {"報道": {}},
    "domains": {"english": ["skysports.com"], "blocked": ["bbc.com"]},
    "leagues": {"england": {"name": "プレミアリーグ"}},
    "feeds": [
        {"name": "生きている", "url": "https://feed.example/a", "verified": True},
        {"name": "未確認", "url": "https://feed.example/b", "verified": False},
    ],
    "routines": {"morning": {"name": "朝", "steps": [{"id": "a", "what": "a", "tier": "報道", "queries": []}]}},
}


@pytest.fixture
def plan():
    return build_plan(RAW)


def test_未確認のフィードは黙って飛ばさない(plan, monkeypatch):
    monkeypatch.setattr(gather.feeds_mod, "fetch", lambda url, **kw: [])
    items, notes = gather.from_feeds(plan, 24)
    assert items == []
    assert any("未確認のフィードを1本" in note for note in notes)


def test_取れないフィードはそう言う(plan, monkeypatch):
    def boom(url, **kw):
        raise gather.feeds_mod.FeedError("開けません")

    monkeypatch.setattr(gather.feeds_mod, "fetch", boom)
    _, notes = gather.from_feeds(plan, 24)
    assert any("取得できません" in note for note in notes)


def test_確認済みのフィードだけ取る(plan, monkeypatch):
    calls = []

    def fake(url, **kw):
        calls.append(url)
        return [Item(title="見出し", url="https://www.skysports.com/1",
                     published=datetime.now(timezone.utc))]

    monkeypatch.setattr(gather.feeds_mod, "fetch", fake)
    items, _ = gather.from_feeds(plan, 24)
    assert calls == ["https://feed.example/a"]
    assert len(items) == 1


def test_すでに使った出典は候補にしない():
    entries = [
        Entry(key="a", headline="h", slot="morning", at=datetime.now(),
              sources=["https://www.skysports.com/old"])
    ]
    hits = parse(
        "古い\thttps://www.skysports.com/old\n新しい\thttps://www.skysports.com/new"
    )
    kept, dropped = gather.drop_seen(hits, gather.used_urls(entries))
    assert [h.url for h in kept] == ["https://www.skysports.com/new"]
    assert len(dropped) == 1


def test_同じURLは1件にする():
    hits = parse("A\thttps://x.example/1\nB\thttps://x.example/1")
    kept, _ = gather.drop_seen(hits, set())
    assert len(kept) == 1


def test_貼り付けだけでも動く(plan, tmp_path, monkeypatch):
    monkeypatch.setattr(gather.newsites, "LEDGER", str(tmp_path / "n.yaml"))
    haul = gather.run(
        plan, hours=24,
        pasted="Spurs agree deal\thttps://www.skysports.com/football/news/11661/13000001/x",
        use_feeds=False, today=date(2026, 8, 31),
    )
    assert len(haul.hits) == 1
    assert "取れたもの 1件" in gather.summary(haul)[0]


def test_フィードも貼り付けも空なら知らせる(plan, monkeypatch):
    monkeypatch.setattr(gather.feeds_mod, "fetch", lambda url, **kw: [])
    haul = gather.run(plan, hours=24, today=date(2026, 8, 31))
    assert haul.hits == []
    assert any("何も取れませんでした" in note for note in haul.notes)


def test_網の外のサイトを控える(plan, tmp_path, monkeypatch):
    monkeypatch.setattr(gather.newsites, "LEDGER", str(tmp_path / "n.yaml"))
    monkeypatch.setattr(
        gather.newsites, "record",
        lambda urls, plan_, today=None, path=None: ["thesun.co.uk"],
    )
    haul = gather.run(
        plan, hours=24, pasted="A\thttps://www.thesun.co.uk/1",
        use_feeds=False, today=date(2026, 8, 31),
    )
    assert haul.fresh_sites == ["thesun.co.uk"]
    assert any("網に無いサイト" in line for line in gather.summary(haul))


def test_フィードがあるなら今日の一手はgather(tmp_path):
    from src import today as today_mod

    candidates = tmp_path / "none.yaml"
    assert today_mod.next_step(candidates, [], "20260831", "python -m src.cli gather") \
        == "python -m src.cli gather"

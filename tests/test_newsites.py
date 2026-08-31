"""網の外から返ってくるサイトの控え。

検索は網の外も返す。今までは捨てていたが、何度も出るサイトは
たいてい足すべきサイト。1回きりのものを足すと網が薄まる。
"""

import pytest

from src import newsites
from src.plan import build_plan

RAW = {
    "tiers": {"報道": {}},
    "domains": {"english": ["skysports.com"], "blocked": ["bbc.com"]},
    "routines": {"morning": {"name": "朝", "steps": [{"id": "a", "what": "a", "tier": "報道", "queries": []}]}},
}


@pytest.fixture
def plan():
    return build_plan(RAW)


@pytest.fixture
def ledger(tmp_path):
    return tmp_path / "newsites.yaml"


def test_ホストはwwwを落として数える():
    assert newsites.host_of("https://www.example.com/a?x=1") == "example.com"
    assert newsites.host_of("http://example.com") == "example.com"
    assert newsites.host_of("") == ""


def test_網にあるサイトも塞がれたサイトも控えない(plan):
    urls = [
        "https://www.skysports.com/1",   # 網にある
        "https://www.bbc.com/2",         # 塞がれている
        "https://www.thesun.co.uk/3",    # 網の外
    ]
    assert newsites.unknown(urls, plan) == ["thesun.co.uk"]


def test_同じホストは1回として数える(plan):
    urls = ["https://www.thesun.co.uk/1", "https://www.thesun.co.uk/2"]
    assert newsites.unknown(urls, plan) == ["thesun.co.uk"]


def test_控えが貯まる(plan, ledger):
    from datetime import date

    newsites.record(["https://www.thesun.co.uk/1"], plan, date(2026, 8, 30), ledger)
    newsites.record(["https://www.thesun.co.uk/2"], plan, date(2026, 8, 31), ledger)
    sites = newsites.load(ledger)
    assert len(sites) == 1
    assert sites[0].seen == 2
    assert sites[0].days == ["2026-08-30", "2026-08-31"]
    assert len(sites[0].examples) == 2


def test_1日に何度出ても足す理由にはならない(plan, ledger):
    from datetime import date

    for n in range(5):
        newsites.record([f"https://www.thesun.co.uk/{n}"], plan, date(2026, 8, 30), ledger)
    sites = newsites.load(ledger)
    assert sites[0].seen == 5
    # 別々の日に出ていないので候補にしない
    assert newsites.propose(sites) == []


def test_別々の日に出たものを挙げる(plan, ledger):
    from datetime import date

    newsites.record(["https://www.thesun.co.uk/1"], plan, date(2026, 8, 30), ledger)
    newsites.record(["https://www.thesun.co.uk/2"], plan, date(2026, 8, 31), ledger)
    newsites.record(["https://a.example/1"], plan, date(2026, 8, 31), ledger)
    picks = newsites.propose(newsites.load(ledger))
    assert [site.host for site in picks] == ["thesun.co.uk"]


def test_例のURLは数を絞る(plan, ledger):
    from datetime import date

    for n in range(6):
        newsites.record([f"https://www.thesun.co.uk/{n}"], plan, date(2026, 8, 30 if n < 3 else 31), ledger)
    assert len(newsites.load(ledger)[0].examples) == newsites.KEEP_EXAMPLES


def test_控えが無ければ空(ledger):
    assert newsites.load(ledger) == []

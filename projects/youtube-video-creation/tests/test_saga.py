"""続報の差分。

移籍も監督人事も1本では終わらない。記録には「扱った」としか残らないので、
前回どこまで話したか・今日の候補のうち何が新しいかが分からない。
"""

from datetime import datetime, timedelta

import pytest

from src import saga
from src.candidates import Candidate
from src.coverage import Entry

NOW = datetime(2026, 8, 31, 6, 0)


def _entry(key, headline, days, sources=(), topic=""):
    return Entry(
        key=key, headline=headline, slot="morning", at=NOW - timedelta(days=days),
        topic=topic, sources=list(sources),
    )


def test_扱っていない話題は新しい():
    items = [Candidate(id="a", title="バイエルンが新監督を発表", topic="バイエルン")]
    found = saga.follow(items, [], NOW)
    assert found[0].is_new
    assert "新" in found[0].line(NOW)


def test_同じidなら続報():
    items = [Candidate(id="alvarez", title="アルバレス移籍が再燃")]
    past = [_entry("alvarez", "アトレティコが公式声明", 2)]
    found = saga.follow(items, past, NOW)
    assert not found[0].is_new
    assert found[0].hours_since(NOW) == pytest.approx(48.0)


def test_idが違ってもクラブが同じなら続報():
    # 日ごとに id を付け直しても、話題は続いている
    items = [Candidate(id="atletico_0831", title="アトレティコのアルバレスが再燃",
                       topic="アトレティコ・マドリード")]
    past = [_entry("alvarez_0830", "アトレティコが公式声明「バルサとは交渉しない」", 1)]
    assert not saga.follow(items, past, NOW)[0].is_new


def test_別のクラブの話は続報にしない():
    items = [Candidate(id="a", title="バイエルンが新監督を発表", topic="バイエルン")]
    past = [_entry("b", "アトレティコが公式声明", 1)]
    assert saga.follow(items, past, NOW)[0].is_new


def test_古すぎる記録は別件として扱う():
    items = [Candidate(id="alvarez", title="アルバレス移籍が再燃")]
    past = [_entry("alvarez", "アトレティコが公式声明", saga.MAX_AGE_DAYS + 1)]
    assert saga.follow(items, past, NOW)[0].is_new


def test_前回に無い出典だけを新しいものとして出す():
    items = [Candidate(id="a", title="アルバレス移籍が再燃",
                       url="https://sky.example/new",
                       sources=["https://sky.example/new", "https://sky.example/old"])]
    past = [_entry("a", "アトレティコが公式声明", 1, sources=["https://sky.example/old"])]
    found = saga.follow(items, past, NOW)
    assert found[0].fresh == ["https://sky.example/new"]


def test_新しい出典が無ければ知らせる():
    items = [Candidate(id="a", title="アルバレス移籍が再燃",
                       sources=["https://sky.example/old"])]
    past = [_entry("a", "アトレティコが公式声明", 1, sources=["https://sky.example/old"])]
    notes = saga.advise(saga.follow(items, past, NOW), NOW)
    assert any("同じ材料で二度目" in note for note in notes)


def test_何本も続いていたら見直しを促す():
    items = [Candidate(id="a", title="アルバレス移籍が再燃", url="https://sky.example/new")]
    past = [_entry("a", "アトレティコの声明", n) for n in (1, 2, 3)]
    notes = saga.advise(saga.follow(items, past, NOW), NOW)
    assert any("4本目" in note for note in notes)


def test_新しい話題には何も言わない():
    items = [Candidate(id="a", title="バイエルンが新監督を発表")]
    assert saga.advise(saga.follow(items, [], NOW), NOW) == []


def test_続報の行に前回の見出しと間隔が出る():
    items = [Candidate(id="a", title="アルバレス移籍が再燃")]
    past = [_entry("a", "アトレティコが公式声明", 2)]
    line = saga.follow(items, past, NOW)[0].line(NOW)
    assert "2日前" in line and "アトレティコが公式声明" in line


def test_記録に出典と話題を残す(tmp_path):
    from src import coverage

    path = tmp_path / "covered.yaml"
    coverage.record(path, "morning", [("a", "見出し")],
                    now=NOW, topic="バイエルン", sources=["https://x.example/1"])
    entry = coverage.load(path)[0]
    assert entry.topic == "バイエルン"
    assert entry.sources == ["https://x.example/1"]

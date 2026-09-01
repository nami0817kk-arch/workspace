"""候補ファイルの点検。

候補ファイルは手で書く。綴りを外した項目は既定値に落ちるだけで
黙って通るので、「なぜか検索が出ない」として後から効いてくる。
"""

import pytest

from src.candidates import Candidate
from src.lint import inspect, summarise
from src.plan import build_plan

RAW = {
    "tiers": {"確定": {}, "報道": {}, "未確認": {}, "背景": {}},
    "leagues": {"england": {"name": "プレミアリーグ"}, "germany": {"name": "ブンデスリーガ"}},
    "domains": {
        "official": ["realmadrid.com"],
        "english": ["skysports.com"],
        "rumour": ["caughtoffside.com"],
        "blocked": ["bbc.com"],
    },
    "domain_tiers": {"official": "確定", "english": "報道", "rumour": "未確認"},
    "routines": {"morning": {"name": "朝", "steps": [{"id": "a", "what": "a", "tier": "確定", "queries": []}]}},
}


@pytest.fixture
def plan():
    return build_plan(RAW)


def _levels(issues, level):
    return [i for i in issues if i.level == level]


def test_綴り違いは止める(plan):
    items = [Candidate(id="a", title="x", league="englnad", en="x", topic="t")]
    issues = _levels(inspect(items, plan, book=[]), "×")
    assert any("league" in i.message for i in issues)


def test_定義に無い種別と確度も止める(plan):
    items = [Candidate(id="a", title="x", kind="transfar", tier="確報", en="x", topic="t")]
    issues = _levels(inspect(items, plan, book=[]), "×")
    assert any("kind" in i.message for i in issues)
    assert any("tier" in i.message for i in issues)


def test_試合はリーグが要る(plan):
    items = [Candidate(id="a", title="x", kind="match", league="", en="x", topic="t")]
    issues = _levels(inspect(items, plan, book=[]), "×")
    assert any("match" in i.message for i in issues)


def test_取得できないサイトは出典にできない(plan):
    items = [Candidate(id="a", title="x", url="https://www.bbc.com/sport/x", en="x", topic="t")]
    issues = _levels(inspect(items, plan, book=[]), "×")
    assert any("取得できない" in i.message for i in issues)


def test_噂まとめだけで確定にはできない(plan):
    items = [Candidate(id="a", title="x", tier="確定", en="x", topic="t",
                       sources=["https://www.caughtoffside.com/x"])]
    issues = _levels(inspect(items, plan, book=[]), "×")
    assert any("未確認" in i.message for i in issues)


def test_公式まで辿っていれば確定でよい(plan):
    items = [Candidate(id="a", title="x", tier="確定", en="x", topic="t",
                       sources=["https://www.realmadrid.com/en/news/x"])]
    assert _levels(inspect(items, plan, book=[]), "×") == []


def test_確度が上限より低いのは構わない(plan):
    items = [Candidate(id="a", title="x", tier="報道", en="x", topic="t",
                       sources=["https://www.realmadrid.com/en/news/x"])]
    assert _levels(inspect(items, plan, book=[]), "×") == []


def test_idの重複は止める(plan):
    items = [
        Candidate(id="a", title="x", en="x", topic="t"),
        Candidate(id="a", title="y", en="y", topic="t"),
    ]
    assert any("id" in i.message for i in _levels(inspect(items, plan, book=[]), "×"))


def test_同じURLはまとめ漏れとして知らせる(plan):
    items = [
        Candidate(id="a", title="x", url="https://www.skysports.com/1", en="x", topic="t"),
        Candidate(id="b", title="y", url="https://www.skysports.com/1", en="y", topic="t"),
    ]
    assert any("まとめ漏れ" in i.message for i in _levels(inspect(items, plan, book=[]), "!"))


def test_網に無いサイトは知らせるが止めない(plan):
    items = [Candidate(id="a", title="x", url="https://example.com/1", en="x", topic="t")]
    issues = inspect(items, plan, book=[])
    assert _levels(issues, "×") == []
    assert any("網に無い" in i.message for i in _levels(issues, "!"))


def test_空欄には辞書からの当たりを出す(plan):
    from src import clubs

    items = [Candidate(id="a", title="Spurs agree deal", en="x")]
    issues = _levels(inspect(items, plan, clubs.load()), "・")
    assert any("トッテナム" in i.message for i in issues)
    assert any("england" in i.message for i in issues)


def test_hours_agoを省いても文句を言わない(plan):
    # 省くのは普通のこと。url から割り出す
    items = [Candidate(id="a", title="x", en="x", topic="t", hours_ago=-1.0)]
    assert not [i for i in inspect(items, plan, book=[]) if "hours_ago" in i.message]


def test_問題が無ければそう言う(plan):
    items = [Candidate(id="a", title="x", league="england", en="x", topic="t",
                       url="https://www.skysports.com/1", tier="報道")]
    issues = inspect(items, plan, book=[])
    assert issues == []
    assert summarise(issues) == "書式の問題はありません"


def test_数え上げる(plan):
    items = [Candidate(id="a", title="x", league="englnad", en="x", topic="t")]
    assert "直すところ 1件" in summarise(inspect(items, plan, book=[]))

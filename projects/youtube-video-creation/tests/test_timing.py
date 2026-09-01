"""リーグごとの「情報が出る時間帯」。

欧州の発表は日本の深夜から早朝に出る。日本時間の昼にプレミアを探しても
新しいものは無いし、朝5時半にJリーグを探してもまだ何も動いていない。
"""

from datetime import date, datetime, time

import pytest

from src import timing
from src.plan import build_plan

RAW = {
    "tiers": {"報道": {}},
    "clocks": {"summer_until": "2026-10-25"},
    "leagues": {
        "england": {"name": "プレミアリーグ", "utc_offset": 1, "active_local": "09:00-23:30"},
        "germany": {"name": "ブンデスリーガ", "utc_offset": 2, "active_local": "09:00-23:30"},
        "japan": {"name": "Jリーグ", "utc_offset": 9, "active_local": "08:00-23:00"},
        "brazil": {"name": "ブラジル"},   # 帯を書いていないリーグ
    },
    "routines": {"morning": {"name": "朝", "steps": [{"id": "a", "what": "a", "tier": "報道", "queries": []}]}},
}


@pytest.fixture
def plan():
    return build_plan(RAW)


def test_現地の帯を日本時間に直す(plan):
    spans = {w.league: w for w in timing.windows(plan)}
    # 英国09:00は日本の17:00（差8時間）
    assert spans["england"].start == time(17, 0)
    assert spans["england"].end == time(7, 30)
    assert spans["england"].wraps
    # Jリーグは日付をまたがない
    assert not spans["japan"].wraps


def test_帯を書いていないリーグは出さない(plan):
    assert "brazil" not in {w.league for w in timing.windows(plan)}


def test_日付をまたぐ帯も正しく判定する(plan):
    spans = {w.league: w for w in timing.windows(plan)}
    england = spans["england"]
    assert england.covers(time(2, 0))     # 未明は英国の夕方
    assert england.covers(time(18, 0))
    assert not england.covers(time(12, 0))


def test_朝のスキャン時刻には欧州が動いていてJリーグは静か(plan):
    live = {w.league for w in timing.open_now(plan, datetime(2026, 8, 31, 5, 30))}
    assert "england" in live and "germany" in live
    assert "japan" not in live


def test_日本時間の昼は逆になる(plan):
    live = {w.league for w in timing.open_now(plan, datetime(2026, 8, 31, 12, 30))}
    assert live == {"japan"}


def test_先に閉じるリーグから並べる(plan):
    # 05:30 時点でドイツは06:30に閉じ、イングランドは07:30まで開いている
    order = timing.order(plan, ["england", "germany", "japan"], datetime(2026, 8, 31, 5, 30))
    assert order[:2] == ["germany", "england"]
    assert order[-1] == "japan"


def test_帯を書いていないリーグは間に置く(plan):
    order = timing.order(plan, ["japan", "brazil", "england"], datetime(2026, 8, 31, 5, 30))
    assert order == ["england", "brazil", "japan"]


def test_閉じるまでの時間(plan):
    spans = {w.league: w for w in timing.windows(plan)}
    assert spans["germany"].hours_left(time(5, 30)) == pytest.approx(1.0)
    assert spans["germany"].hours_until(time(5, 30)) == 0.0
    assert spans["japan"].hours_until(time(5, 30)) == pytest.approx(2.5)


def test_静かな時間帯なら次に開く時刻を言う(plan):
    lines = timing.advice(plan, datetime(2026, 8, 31, 7, 45))
    assert "静か" in lines[0]
    assert "Jリーグ" in lines[1]


def test_動いているリーグを言う(plan):
    lines = timing.advice(plan, datetime(2026, 8, 31, 12, 30))
    assert "Jリーグ" in lines[0]


def test_夏時間の期限を過ぎたら知らせる(plan):
    assert not timing.summer_over(plan, date(2026, 10, 1))
    assert timing.summer_over(plan, date(2026, 11, 1))


def test_期限を書いていなければ黙る():
    raw = dict(RAW)
    raw["clocks"] = {}
    assert not timing.summer_over(build_plan(raw), date(2030, 1, 1))


# 「次に開くのは Jリーグ（あと0時間）」と出ていた。0時間では、いま動くべきか
# 読めない。1時間を切ったら分で言い、10分を切ったら「まもなく」と言う。


def test_残り時間は1時間を切ったら分で言う():
    from src.timing import _left

    assert _left(0.5) == "あと30分"
    assert _left(0.05) == "まもなく"
    assert _left(2.0) == "あと2時間"

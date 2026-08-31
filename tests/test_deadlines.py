"""移籍期限の告知。

期限日は1日で決着がつく。前日に気づいても遅い、当日に気づかなければ間に合わない。
「あと何時間か」を毎回言えているかを確かめる。
"""

from datetime import datetime

import pytest

from src import deadlines
from src.plan import build_plan

RAW = {
    "tiers": {"確定": {}, "報道": {}, "未確認": {}},
    "leagues": {
        "england": {"name": "プレミアリーグ"},
        "spain": {"name": "ラ・リーガ"},
        "germany": {"name": "ブンデスリーガ"},
    },
    "calendar": {
        "notice_days": 5,
        "after_hours": 36,
        "deadlines": [
            {"league": "england", "at": "2026-09-02 07:00",
             "local": "現地 9/1 23:00 BST", "confirmed": True},
            {"league": "spain", "at": "2026-09-02 07:00", "confirmed": True},
            {"league": "germany", "at": "2026-09-02 05:00", "confirmed": False},
        ],
    },
    "routines": {
        "morning": {
            "name": "朝",
            "steps": [{"id": "a", "what": "a", "tier": "確定", "queries": []}],
        }
    },
}


@pytest.fixture
def plan():
    return build_plan(RAW)


def test_近い順に読む(plan):
    items = deadlines.load(plan)
    assert [item.league for item in items] == ["germany", "england", "spain"]
    assert items[0].name == "ブンデスリーガ"


def test_日付が読めない行は捨てる(plan):
    raw = dict(RAW)
    raw["calendar"] = {"deadlines": [{"league": "england", "at": "いつか"}]}
    assert deadlines.load(build_plan(raw)) == []


def test_遠い期限は告知しない(plan):
    lines = deadlines.notices(deadlines.load(plan), datetime(2026, 8, 1, 6, 0))
    assert lines == []


def test_同じ時刻のリーグは1行にまとめる(plan):
    lines = deadlines.notices(deadlines.load(plan), datetime(2026, 8, 30, 6, 0))
    assert len(lines) == 2
    together = [line for line in lines if "プレミアリーグ" in line][0]
    assert "ラ・リーガ" in together


def test_現地時刻はリーグごとに違うのでまとめた行では出さない(plan):
    # プレミアとラ・リーガを1行にまとめるとき、
    # 英国の23時をラ・リーガの現地時刻として見せてはいけない
    lines = deadlines.notices(deadlines.load(plan), datetime(2026, 8, 30, 6, 0))
    together = [line for line in lines if "プレミアリーグ" in line][0]
    assert "BST" not in together


def test_当日は時間で言う(plan):
    lines = deadlines.notices(deadlines.load(plan), datetime(2026, 9, 1, 12, 0))
    premier = [line for line in lines if "プレミアリーグ" in line][0]
    assert "残り19時間" in premier
    assert "⚠" in premier


def test_過ぎた直後は総括を促す(plan):
    lines = deadlines.notices(deadlines.load(plan), datetime(2026, 9, 2, 12, 0))
    premier = [line for line in lines if "プレミアリーグ" in line][0]
    assert "締まった" in premier and "総括" in premier


def test_締まって丸2日経てば黙る(plan):
    lines = deadlines.notices(deadlines.load(plan), datetime(2026, 9, 4, 12, 0))
    assert lines == []


def test_未確認の日付はそう書く(plan):
    lines = deadlines.notices(deadlines.load(plan), datetime(2026, 9, 1, 12, 0))
    german = [line for line in lines if "ブンデスリーガ" in line][0]
    assert "未確認" in german
    premier = [line for line in lines if "プレミアリーグ" in line][0]
    assert "未確認" not in premier


def test_特別編を出すのは当日と直後だけ(plan):
    items = deadlines.load(plan)
    assert deadlines.active(items, datetime(2026, 8, 30, 6, 0)) == []
    assert deadlines.active(items, datetime(2026, 9, 1, 12, 0))
    assert deadlines.active(items, datetime(2026, 9, 2, 12, 0))
    assert deadlines.active(items, datetime(2026, 9, 5, 12, 0)) == []


def test_間近で日付が未確認のものを拾う(plan):
    items = deadlines.load(plan)
    assert [d.league for d in deadlines.unconfirmed(items, datetime(2026, 9, 1, 12, 0))] == ["germany"]
    assert deadlines.unconfirmed(items, datetime(2026, 7, 1, 12, 0)) == []


def test_期限日ルーティンには節の型がある():
    from src.plan import load_plan

    routine = load_plan().routine("deadline_day")
    assert [s["id"] for s in routine.structure][:2] == ["what", "collapsed"]
    # 公式に辿る手と、現地語の手が要る
    ids = {step.id for step in routine.steps}
    assert {"done_deals", "collapsed", "local", "spend"} <= ids


# `today` は朝6:00で固定して数えていた。23時に打つと「残り21時間」と出る一方、
# 実時刻を見ている `doctor` は同じ期限を「残り3時間」と言っていた。
# 期限日は1日で決着がつくので、この食い違いはそのまま見落としになる。


def test_今日ぶんの残り時間は実時刻で数える():
    from datetime import date

    from src import cli

    assert abs((cli._deadline_clock(date.today()) - datetime.now()).total_seconds()) < 5


def test_別の日は枠が始まる前を基準にする():
    from datetime import date, time, timedelta

    from src import cli

    day = date.today() + timedelta(days=1)
    assert cli._deadline_clock(day).date() == day
    assert cli._deadline_clock(day).time() == time(6, 0)


def test_日時をそのまま渡したら触らない():
    from src import cli

    when = datetime(2026, 8, 31, 23, 13)
    assert cli._deadline_clock(when) == when


def test_todayとdoctorが同じ残り時間を言う(plan):
    from datetime import date

    from src import cli

    body = plan.calendar or {}
    assert cli._deadline_notices(plan, date.today()) == deadlines.notices(
        deadlines.load(plan),
        datetime.now(),
        notice_days=float(body.get("notice_days", deadlines.NOTICE_DAYS)),
        after_hours=float(body.get("after_hours", deadlines.AFTER_HOURS)),
    )

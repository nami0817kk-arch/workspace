"""営業日カレンダーと鮮度判定のテスト。

実際に誤検知した日（2026-09-21〜23 のシルバーウィーク）を必ず含める。
"""
from datetime import date, datetime, timedelta, timezone

import pytest

from check_freshness import check, expected_rec_date
from market_calendar import (
    CalendarOutOfRange,
    business_days_between,
    is_business_day,
    previous_business_day,
)

JST = timezone(timedelta(hours=9))


@pytest.mark.parametrize(
    "day",
    ["2026-09-18", "2026-09-24", "2026-09-25", "2026-12-30"],
)
def test_営業日(day):
    assert is_business_day(date.fromisoformat(day))


@pytest.mark.parametrize(
    "day",
    [
        "2026-09-19",  # 土
        "2026-09-20",  # 日
        "2026-09-21",  # 敬老の日
        "2026-09-22",  # 国民の休日
        "2026-09-23",  # 秋分の日
        "2026-12-31",  # 年末休場
        "2027-01-01",  # 元日
    ],
)
def test_休場日(day):
    assert not is_business_day(date.fromisoformat(day))


def test_年始休場は1月3日まで():
    assert not is_business_day(date(2027, 1, 2))
    assert not is_business_day(date(2027, 1, 3))
    # 1/4（月）は大発会。ここまで休みにすると、年明け最初の営業日を取り逃す。
    assert is_business_day(date(2027, 1, 4))


def test_表の範囲外は黙って通さない():
    with pytest.raises(CalendarOutOfRange):
        is_business_day(date(2030, 5, 7))


def test_連休を挟むと直近営業日は連休前():
    # 9/24(木) から見た直近営業日は 9/18(金)
    assert previous_business_day(date(2026, 9, 24)) == date(2026, 9, 18)


def test_連休のあいだは遅れ0():
    # シルバーウィーク中、最新が 9/18 でも遅れていない
    assert business_days_between(date(2026, 9, 18), date(2026, 9, 23)) == 0


def test_営業日を跨げば数える():
    # 9/18 → 9/25 のあいだの営業日は 9/24, 9/25 の2日
    assert business_days_between(date(2026, 9, 18), date(2026, 9, 25)) == 2


def test_祝日に鳴らさない():
    # 2026-09-22（国民の休日）17:00、最新は 9/18 — これで3日続けて誤検知していた
    behind, _ = check(date(2026, 9, 18), datetime(2026, 9, 22, 17, 0, tzinfo=JST))
    assert behind == 0


def test_取り逃したら鳴らす():
    # 9/24(木) の17:00 に最新が 9/18 のまま = 1営業日ぶん欠測
    behind, _ = check(date(2026, 9, 18), datetime(2026, 9, 24, 17, 0, tzinfo=JST))
    assert behind == 1


def test_取得前の朝は前営業日が正しい():
    # 平日の朝に src/ を触って push しても鳴らさない（当日分はまだ取っていない）
    behind, _ = check(date(2026, 9, 24), datetime(2026, 9, 25, 10, 0, tzinfo=JST))
    assert behind == 0
    assert expected_rec_date(datetime(2026, 9, 25, 10, 0, tzinfo=JST)) == date(2026, 9, 24)


def test_取得直後は時刻によらず当日分を期待する():
    # run-daily.ps1 は16:10開始。取得できていなければその場で鳴らす
    behind, _ = check(
        date(2026, 9, 24), datetime(2026, 9, 25, 16, 12, tzinfo=JST), after_fetch=True
    )
    assert behind == 1
    behind, _ = check(
        date(2026, 9, 25), datetime(2026, 9, 25, 16, 12, tzinfo=JST), after_fetch=True
    )
    assert behind == 0


def test_取得直後でも休場日なら鳴らさない():
    # 祝日にタスクが回っても、前営業日のままで正常
    behind, _ = check(
        date(2026, 9, 18), datetime(2026, 9, 23, 16, 12, tzinfo=JST), after_fetch=True
    )
    assert behind == 0


def test_祝日表の範囲外では判定できないと分かる():
    """表は2027年までしか無い。範囲外は黙って平日扱いにせず例外にする。"""
    import check_freshness

    with pytest.raises(CalendarOutOfRange):
        check_freshness.check(date(2028, 1, 4), datetime(2028, 1, 5, 17, 0, tzinfo=JST))


def test_祝日表が切れたら何をすべきか言う(monkeypatch, tmp_path, capsys):
    """例外の生ログだけ出しても「データが古い」と読めてしまい、伝わらない。"""
    import check_freshness

    data = tmp_path / "data"
    data.mkdir()
    (data / "latest.json").write_text('{"rec_date": "2026-09-18"}', encoding="utf-8")
    monkeypatch.setattr(check_freshness, "_DATA_DIR", data)
    monkeypatch.setattr(check_freshness.sys, "argv", ["check_freshness.py"])

    def _raise(*_args, **_kwargs):
        raise CalendarOutOfRange("2028-01-05 は祝日表の範囲外です。")

    monkeypatch.setattr(check_freshness, "check", _raise)

    assert check_freshness.main() == 1
    out = capsys.readouterr().out
    assert "祝日表" in out and "内閣府" in out

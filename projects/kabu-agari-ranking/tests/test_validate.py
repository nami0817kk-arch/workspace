"""保存前の検査のテスト。

2026-09-07 の事故（月曜のデータに金曜の日付が付き、金曜のファイルを潰した）を
そのまま再現したケースを必ず含める。data/ は取り直しがきかないので、
ここが緩むと静かに資産が壊れる。
"""
from datetime import datetime, timedelta, timezone

import pytest

import validate
from validate import InvalidPayload

JST = timezone(timedelta(hours=9))


def _payload(rec_date="2026-09-18", n=30, pct=10.0):
    return {
        "rec_date": rec_date,
        "gainers": [
            {"rank": i + 1, "code": f"{7200 + i}", "name": f"銘柄{i}",
             "close": 1000.0, "change_pct": pct - i * 0.1, "metric_value": 100}
            for i in range(n)
        ],
        "losers": [],
        "active": [],
    }


def test_大引け後の当日分は通る():
    validate.check(_payload("2026-09-18"), datetime(2026, 9, 18, 16, 12, tzinfo=JST))


def test_場中は前営業日の分でも通る():
    # 15:30 前は前日の終値ランキングが出ている
    validate.check(_payload("2026-09-17"), datetime(2026, 9, 18, 10, 0, tzinfo=JST))


def test_休場日は直近営業日の分が通る():
    validate.check(_payload("2026-09-18"), datetime(2026, 9, 23, 16, 12, tzinfo=JST))


def test_月曜に金曜の日付が付いたら弾く():
    # 2026-09-07（月）16時。日付の読み取りが壊れて 09-04（金）になっていた事故。
    with pytest.raises(InvalidPayload, match="一致しません"):
        validate.check(_payload("2026-09-04"), datetime(2026, 9, 7, 16, 12, tzinfo=JST))


def test_未来の日付は弾く():
    with pytest.raises(InvalidPayload, match="未来"):
        validate.check(_payload("2026-09-25"), datetime(2026, 9, 18, 16, 12, tzinfo=JST))


def test_件数が少なすぎたら弾く():
    with pytest.raises(InvalidPayload, match="件数"):
        validate.check(_payload(n=5), datetime(2026, 9, 18, 16, 12, tzinfo=JST))


def test_騰落率が全て0なら弾く():
    p = _payload()
    for row in p["gainers"]:
        row["change_pct"] = 0.0
    with pytest.raises(InvalidPayload, match="全て0"):
        validate.check(p, datetime(2026, 9, 18, 16, 12, tzinfo=JST))


def test_値上がりの首位が下落なら弾く():
    p = _payload()
    p["gainers"][0]["change_pct"] = -3.0
    with pytest.raises(InvalidPayload, match="首位が下落"):
        validate.check(p, datetime(2026, 9, 18, 16, 12, tzinfo=JST))


def test_コードが空の行があれば弾く():
    p = _payload()
    p["gainers"][3]["code"] = ""
    with pytest.raises(InvalidPayload, match="コード"):
        validate.check(p, datetime(2026, 9, 18, 16, 12, tzinfo=JST))


def test_騰落率が欠けていたら弾く():
    p = _payload()
    p["gainers"][3]["change_pct"] = None
    with pytest.raises(InvalidPayload, match="騰落率"):
        validate.check(p, datetime(2026, 9, 18, 16, 12, tzinfo=JST))


def test_祝日表の範囲外では日付を判定しない():
    # 表を更新し忘れたときに、取得そのものを止めてしまわないようにする
    assert validate.expected_rec_dates(datetime(2030, 5, 7, 16, 0, tzinfo=JST)) == set()
    validate.check(_payload("2030-05-07"), datetime(2030, 5, 7, 16, 12, tzinfo=JST))

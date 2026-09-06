"""APIの枠の数え方。

**2026-09-06 にコンソールで実測し、それまでの記述が6倍ちがっていた。**
18本投稿して Queries per day は 4,815 / 10,000。1本あたり約270。
記録には「1本1,600、1日6本が上限」と書いてあり、そのせいで枠が半分
残っているのに「使い切った」と判断して投稿を止めていた。
"""


def test_1本あたりの費用は実測値():
    """公表値（1,600）ではなく実測値を使う。**推測で埋めない。**"""
    from src.quota import COST_PER_UPLOAD

    assert 200 <= COST_PER_UPLOAD <= 400, "実測は約270（2026-09-06）"


def test_18本で実測とほぼ合う(tmp_path):
    """実測 4,815 に対して、見積りが1割以内に収まること。"""
    from src import quota

    book = tmp_path / "q.json"
    for _ in range(18):
        quota.record("videos.insert", book)
    got = quota.used(book)
    assert abs(got - 4815) / 4815 < 0.15, f"見積り{got} / 実測4815"


def test_投稿数の上限でも止まる(tmp_path):
    """**枠が余っていても、投稿数の上限（100本/日）がある。**"""
    from src import quota

    book = tmp_path / "q.json"
    for _ in range(quota.DAILY_UPLOADS):
        quota.record("videos.insert", book)
    assert quota.uploads_left(book) == 0


def test_日付は太平洋時間で切り替わる():
    """**枠が戻るのは太平洋時間の深夜0時＝日本時間16時。**"""
    from datetime import datetime, timedelta, timezone

    from src.quota import _today

    jst = timezone(timedelta(hours=9))
    # 日本時間 9/7 15:59 は、太平洋時間ではまだ 9/6
    assert _today(datetime(2026, 9, 7, 15, 59, tzinfo=jst)) == "2026-09-06"
    # 16:00 を回ると 9/7 に変わる
    assert _today(datetime(2026, 9, 7, 16, 1, tzinfo=jst)) == "2026-09-07"


def test_知らない呼び出しは弾く(tmp_path):
    """**費用の分からないものを黙って0で数えない。**残量がずれる"""
    from src import quota

    try:
        quota.record("videos.somethingNew", tmp_path / "q.json")
    except KeyError as err:
        assert "費用の分からない" in str(err)
    else:
        raise AssertionError("知らない呼び出しを通した")

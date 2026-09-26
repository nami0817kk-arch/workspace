"""日付から探すカレンダーのテスト。

升目の意味を取り違えると、事実と違うことを画面で言うことになる。
特に「取得に失敗した日」は、掲載している期間の中でしか言えない
（掲載を始める前の日や、これから来る日を欠測と呼ぶのは嘘になる）。
"""
import render


def _states(months):
    """{日付: 状態} に潰して見やすくする。"""
    out = {}
    for m in months:
        for week in m["weeks"]:
            for cell in week:
                if cell["state"] != render.CAL_BLANK:
                    out[cell["iso"]] = cell["state"]
    return out


def test_掲載がある日は押せる():
    months = render.calendar_months(["2026-09-24", "2026-09-25"], "gainers")
    states = _states(months)
    assert states["2026-09-24"] == render.CAL_DATA
    cell = next(c for w in months[0]["weeks"] for c in w if c.get("iso") == "2026-09-24")
    assert cell["href"] == "archive/gainers/2026-09-24.html"


def test_期間の中の営業日で掲載が無ければ欠測():
    # 9/24(木) と 9/25(金) を掲載。間に営業日は無いが、9/18〜9/25 なら 9/24 以外に営業日がある
    states = _states(render.calendar_months(["2026-09-18", "2026-09-25"], "gainers"))
    assert states["2026-09-24"] == render.CAL_MISSING   # 営業日なのに掲載が無い


def test_休場日は欠測にしない():
    states = _states(render.calendar_months(["2026-09-18", "2026-09-25"], "gainers"))
    for holiday in ("2026-09-21", "2026-09-22", "2026-09-23"):   # シルバーウィーク
        assert states[holiday] == render.CAL_CLOSED
    assert states["2026-09-19"] == render.CAL_CLOSED             # 土曜


def test_掲載を始める前とこれから来る日は欠測にしない():
    """ここを欠測と見せると、取り逃していない日まで失敗に見える。"""
    months = render.calendar_months(["2026-09-24", "2026-09-25"], "gainers")
    states = _states(months)
    assert states["2026-09-01"] == render.CAL_OUTSIDE   # 掲載を始める前（営業日）
    assert states["2026-09-28"] == render.CAL_OUTSIDE   # これから来る日（営業日）


def test_新しい月が先に来る():
    months = render.calendar_months(["2026-08-28", "2026-09-25"], "gainers")
    assert [m["label"] for m in months] == ["2026年9月", "2026年8月"]
    assert months[0]["count"] == 1 and months[1]["count"] == 1


def test_ランキングの種別ごとに行き先が変わる():
    months = render.calendar_months(["2026-09-25"], "losers")
    cell = next(c for w in months[0]["weeks"] for c in w if c.get("iso") == "2026-09-25")
    assert cell["href"] == "archive/losers/2026-09-25.html"


def test_掲載が無ければ何も作らない():
    assert render.calendar_months([], "gainers") == []

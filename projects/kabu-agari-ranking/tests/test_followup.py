"""ストップ高・ストップ安になった銘柄が、翌営業日どこにいたか。

**前の日の記録を持っていないと数えられない**ので、当日のランキングを
出しているだけの場所には作れない章。だからこそ、数え方を間違えると
このサイトの持ち札そのものが崩れる。
"""
from datetime import date, timedelta

import aggregate
import render


def _day(rec_date, *, high=None, gainers=(), losers=()):
    day = {
        "rec_date": rec_date,
        "gainers": [{"rank": i + 1, "code": c, "name": f"銘柄{c}", "close": 163.0,
                     "change_pct": 5.0, "metric_value": 1} for i, c in enumerate(gainers)],
        "losers": [{"rank": i + 1, "code": c, "name": f"銘柄{c}", "close": 239.0,
                    "change_pct": -5.0, "metric_value": 1} for i, c in enumerate(losers)],
        "active": [],
    }
    if high is not None:
        day["stop_high"] = [{"rank": i + 1, "code": c, "name": f"銘柄{c}", "close": 163.0,
                             "change_pct": 44.25, "at_limit": True}
                            for i, c in enumerate(high)]
    return day


def _next_day(d):
    return d + timedelta(days=1)


def test_翌営業日の居場所を数える():
    days = [
        _day("2026-09-28", high=["1001", "1002", "1003"]),
        _day("2026-09-29", gainers=["1001"], losers=["1002"]),
    ]
    out = aggregate.limit_followup(days, "gainers", next_business_day=_next_day)
    assert out["total"] == {"count": 3, "same_side": 1, "other_side": 1,
                            "absent": 1, "days": 1}


def test_推定しか無い日は数えない():
    """出どころが違うものを混ぜると、数の意味が日によって変わる。"""
    days = [
        _day("2026-09-28", gainers=["1001"]),      # stop_high キーが無い
        _day("2026-09-29", gainers=["1001"]),
    ]
    assert aggregate.limit_followup(days, "gainers", next_business_day=_next_day)["total"] is None


def test_掲載が飛んでいる日は数えない():
    """間が抜けていると「翌営業日」とは言えない。"""
    days = [
        _day("2026-09-28", high=["1001"]),
        _day("2026-09-30", gainers=["1001"]),      # 29日が抜けている
    ]
    assert aggregate.limit_followup(days, "gainers", next_business_day=_next_day)["total"] is None


def test_最後の日は数えない():
    """翌営業日がまだ来ていない。"""
    days = [_day("2026-09-28", high=["1001"])]
    assert aggregate.limit_followup(days, "gainers", next_business_day=_next_day)["total"] is None


def test_0件の日は数に入れない():
    days = [_day("2026-09-28", high=[]), _day("2026-09-29", gainers=["1001"])]
    assert aggregate.limit_followup(days, "gainers", next_business_day=_next_day)["total"] is None


def test_ストップ安は逆側を見る():
    days = [
        _day("2026-09-28", gainers=[], losers=["2001", "2002"]),
        _day("2026-09-29", gainers=["2001"], losers=["2002"]),
    ]
    days[0]["stop_low"] = [{"rank": 1, "code": "2002", "name": "銘柄2002", "close": 239.0,
                            "change_pct": -25.08, "at_limit": True}]
    out = aggregate.limit_followup(days, "losers", next_business_day=_next_day)
    assert out["total"]["same_side"] == 1      # 翌日も値下がりに入った
    assert out["total"]["other_side"] == 0


def test_休場日をまたいでも翌営業日として数える():
    """金曜の次は月曜。カレンダーの連日で見ると数えられなくなる。"""
    from market_calendar import next_business_day
    days = [
        _day("2026-09-25", high=["1001"]),          # 金
        _day("2026-09-28", gainers=["1001"]),       # 月
    ]
    out = aggregate.limit_followup(days, "gainers", next_business_day=next_business_day)
    assert out["total"]["count"] == 1
    assert out["total"]["same_side"] == 1


def test_章に数字が出る(tmp_path, monkeypatch):
    import json
    data = tmp_path / "data"
    data.mkdir()
    monkeypatch.setattr(render, "_DATA_DIR", data)
    monkeypatch.setattr(render, "_OUTPUT_DIR", tmp_path / "output")
    monkeypatch.setattr(render, "_ROOT", tmp_path)
    for day in (_day("2026-09-25", high=["1001", "1002"], gainers=["1001", "1002"]),
                _day("2026-09-28", gainers=["1001"], losers=["1002"])):
        (data / f"{day['rec_date']}.json").write_text(
            json.dumps(day, ensure_ascii=False), encoding="utf-8")
    render.build_all()
    html = (tmp_path / "output" / "stop-high" / "index.html").read_text(encoding="utf-8")
    assert "翌営業日はどうだったか" in html
    assert "どちらにも入らなかった" in html, "上位30銘柄の外という断りが要る"
    assert "次にどうなるかは分かりません" in html, "見通しを書かないと明言する"


# --- 同じ業種の銘柄 -------------------------------------------------------------

def test_同じ業種の銘柄を出す():
    """業種は貯めてあるのに、出すだけで使っていなかった。"""
    stocks = [
        {"code": "1001", "name": "A", "rows": [1, 2, 3]},
        {"code": "1002", "name": "B", "rows": [1, 2]},
        {"code": "1003", "name": "C", "rows": [1]},
    ]
    profiles = {
        "1001": {"industry": "情報・通信業"},
        "1002": {"industry": "情報・通信業"},
        "1003": {"industry": "建設業"},
    }
    out = render.same_industry("1001", stocks, profiles)
    assert [s["code"] for s in out] == ["1002"], "自分と、別の業種は出さない"


def test_登場の多い順に並べる():
    stocks = [
        {"code": "1001", "name": "A", "rows": [1]},
        {"code": "1002", "name": "B", "rows": [1, 2]},
        {"code": "1003", "name": "C", "rows": [1, 2, 3]},
    ]
    profiles = {c: {"industry": "情報・通信業"} for c in ("1001", "1002", "1003")}
    assert [s["code"] for s in render.same_industry("1001", stocks, profiles)] == ["1003", "1002"]


def test_業種が分からなければ出さない():
    stocks = [{"code": "1002", "name": "B", "rows": [1]}]
    assert render.same_industry("1001", stocks, {"1002": {"industry": "建設業"}}) == []


def test_出す数に上限がある():
    stocks = [{"code": f"{1000+i}", "name": f"銘柄{i}", "rows": [1]} for i in range(20)]
    profiles = {s["code"]: {"industry": "情報・通信業"} for s in stocks}
    assert len(render.same_industry("1000", stocks, profiles)) == 8


# --- 期間のまとめ ---------------------------------------------------------------

def test_月まとめに上限まで動いた銘柄の顔ぶれを出す():
    """件数だけだと、記録のページまで行かないと何が動いたか分からない。"""
    import aggregate
    days = []
    for d in ("2026-09-28", "2026-09-29"):
        day = _day(d, high=["1001"], gainers=["1001"])
        days.append(day)
    month = aggregate.monthly_summaries(days)[0]
    assert [s["code"] for s in month["stop_high_stocks"]] == ["1001"]
    assert month["stop_high_stocks"][0]["count"] == 2
    assert "stop_low_stocks" in month


def test_相場の振り返りは上下ともグラフを出す(tmp_path, monkeypatch):
    """表には両方あるのに、グラフは上向きだけだった（2026-09-28）。"""
    import json
    data = tmp_path / "data"
    data.mkdir()
    monkeypatch.setattr(render, "_DATA_DIR", data)
    monkeypatch.setattr(render, "_OUTPUT_DIR", tmp_path / "output")
    monkeypatch.setattr(render, "_ROOT", tmp_path)
    for d in ("2026-09-25", "2026-09-28"):
        day = _day(d, gainers=["1001"], losers=["2001"])
        (data / f"{d}.json").write_text(json.dumps(day, ensure_ascii=False), encoding="utf-8")
    render.build_all()
    html = (tmp_path / "output" / "market.html").read_text(encoding="utf-8")
    assert "<h2>ストップ高の数</h2>" in html
    assert "<h2>ストップ安の数</h2>" in html
    assert html.count("chart-figure") >= 4


def test_日別ページから月まとめへ行ける():
    """週まとめへは行けるのに、月まとめへは行けなかった。
    長い目で見たい人がそこで止まる。"""
    assert render.month_href_for("2026-09-28") == "monthly/2026-09.html"
    assert render.month_href_for("2027-01-05") == "monthly/2027-01.html"

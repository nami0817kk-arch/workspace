"""横断集計のテスト。

「何日ランクインしたか」は毎日ためているこのサイトにしか出せない数字なので、
数え間違いはそのまま信頼を失う。境界（2回未満は出さない・連続の数え方）を固定する。
"""
import aggregate


def _row(code, name, pct=10.0, rank=1):
    return {"rank": rank, "code": code, "name": name, "close": 1500.0,
            "change_pct": pct, "metric_value": 100}


def _day(rec_date, rows):
    return {"rec_date": rec_date, "gainers": rows, "losers": [], "active": []}


# days は新しい順で渡される（render._load_all_days と同じ並び）
DAYS = [
    _day("2026-09-18", [_row("1001", "アルファ", 12.0), _row("1002", "ベータ", 8.0)]),
    _day("2026-09-17", [_row("1001", "アルファ", 25.0)]),
    _day("2026-09-16", [_row("1003", "ガンマ", 5.0)]),
    _day("2026-09-15", [_row("1001", "アルファ", 7.0), _row("1002", "ベータ", 30.0)]),
]


def test_複数回のものだけを回数順に返す():
    out = aggregate.frequent(DAYS)
    assert [e["code"] for e in out] == ["1001", "1002"]
    assert out[0]["count"] == 3
    assert out[1]["count"] == 2
    # 1回だけのガンマは出さない
    assert all(e["code"] != "1003" for e in out)


def test_最大騰落率は絶対値で選ぶ():
    out = {e["code"]: e for e in aggregate.frequent(DAYS)}
    assert out["1001"]["best_pct"] == 25.0
    assert out["1002"]["best_pct"] == 30.0


def test_連続は掲載日の並びで数える():
    out = {e["code"]: e for e in aggregate.frequent(DAYS)}
    # アルファは 9/15・9/17・9/18。9/17→9/18 が連続で2日
    assert out["1001"]["streak"] == 2
    # ベータは 9/15 と 9/18 で飛んでいる
    assert out["1002"]["streak"] == 1


def test_直近の登場日を持つ():
    out = {e["code"]: e for e in aggregate.frequent(DAYS)}
    assert out["1001"]["latest"] == "2026-09-18"


def test_社名は新しいほうを残す():
    days = [
        _day("2026-09-18", [_row("1001", "新社名", 3.0)]),
        _day("2026-09-17", [_row("1001", "旧社名", 4.0)]),
    ]
    assert aggregate.frequent(days)[0]["name"] == "新社名"


def test_件数の上限を守る():
    days = [
        _day("2026-09-18", [_row(f"{2000 + i}", f"銘柄{i}") for i in range(30)]),
        _day("2026-09-17", [_row(f"{2000 + i}", f"銘柄{i}") for i in range(30)]),
    ]
    assert len(aggregate.frequent(days, top_n=5)) == 5


def test_データが空でも落ちない():
    assert aggregate.frequent([]) == []
    assert aggregate.frequent([_day("2026-09-18", [])]) == []

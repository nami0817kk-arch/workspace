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


# --- 検索用インデックス -----------------------------------------------------

def test_索引は銘柄ごとに種別と日付を持つ():
    idx = aggregate.search_index(DAYS)
    by_code = {s["c"]: s for s in idx["stocks"]}
    assert idx["to"] == "2026-09-18" and idx["from"] == "2026-09-15"
    assert by_code["1001"]["g"] == ["2026-09-15", "2026-09-17", "2026-09-18"]
    assert by_code["1001"]["l"] == [] and by_code["1001"]["a"] == []


def test_索引は直近の期間だけに絞る():
    # 上限より多い日数を新しい順に並べる
    days = [_day(f"2026-{m:02d}-{d:02d}", [_row("1001", "アルファ")])
            for m in (9, 8, 7) for d in range(28, 0, -1)]
    assert len(days) > aggregate.SEARCH_WINDOW_DAYS
    idx = aggregate.search_index(days)
    assert idx["to"] == days[0]["rec_date"]
    assert idx["from"] == days[aggregate.SEARCH_WINDOW_DAYS - 1]["rec_date"]


def test_索引のキーは短いまま():
    # そのままブラウザに配る JSON なので、キー名を長くすると読み込みが重くなる
    assert set(aggregate.search_index(DAYS)["stocks"][0]) == {"c", "n", "g", "l", "a"}


def test_索引はデータが無くても形を保つ():
    assert aggregate.search_index([]) == {"from": "", "to": "", "stocks": []}


# --- 週まとめ ---------------------------------------------------------------

def test_週はISO週で区切る():
    days = [
        _day("2026-09-21", [_row("1001", "アルファ", 5.0)]),   # W39（月）
        _day("2026-09-18", [_row("1002", "ベータ", 9.0)]),     # W38（金）
        _day("2026-09-14", [_row("1003", "ガンマ", 7.0)]),     # W38（月）
    ]
    weeks = aggregate.weekly_summaries(days)
    assert [w["slug"] for w in weeks] == ["2026-W39", "2026-W38"]
    assert weeks[1]["from"] == "2026-09-14" and weeks[1]["to"] == "2026-09-18"
    assert weeks[1]["day_count"] == 2


def test_週の上位は日をまたいで上昇率順():
    weeks = aggregate.weekly_summaries(DAYS)
    movers = weeks[0]["top_movers"]
    assert [m["change_pct"] for m in movers] == sorted(
        (m["change_pct"] for m in movers), reverse=True
    )
    assert movers[0]["rec_date"]  # どの日の数字かを持っている


def test_週ごとの首位が日別に出る():
    weeks = aggregate.weekly_summaries(DAYS)
    days_out = weeks[0]["days"]
    assert days_out[0]["rec_date"] == "2026-09-18"
    assert days_out[0]["top"]["rank"] == 1

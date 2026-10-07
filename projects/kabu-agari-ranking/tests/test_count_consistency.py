"""同じ日の件数が、ページによって違わないこと。

ストップ高・ストップ安は「値上がり／値下がり上位30銘柄からの推定」と
「取得元の一覧をそのまま記録したもの」の2つの出どころがある。
**数え方を各所で書き直すと、記録を使い始めた日から食い違いが生まれる。**
押した先の数と見出しの数が違っても、読み手にはどちらが正しいか確かめようがない。

2026-09-27 に、相場の振り返り・トップのハイライト・週まとめ・月まとめ・
X の投稿文がそれぞれ別に数え直していたのを、1本の道に揃えた。
"""
import aggregate
import post_to_x
import render


def _day_with_31_stop_highs(rec_date="2026-09-28"):
    """ストップ高が31件あり、値上がり上位30銘柄には収まりきらない日。

    上位30銘柄から数えると30件、記録から数えると31件になる。
    """
    recorded = [
        {"rank": i, "code": f"{1000 + i}", "name": f"銘柄{i}",
         "close": 163.0, "change_pct": 44.25, "at_limit": True}
        for i in range(1, 32)
    ]
    return {
        "rec_date": rec_date,
        # 値上がりランキングは常に上位30銘柄まで
        "gainers": [{**r, "metric_value": 1} for r in recorded[:30]],
        "losers": [],
        "active": [],
        "stop_high": recorded,
        "stop_low": [],
    }


def test_ストップ高の件数はどこで数えても同じ():
    day = _day_with_31_stop_highs()
    days = [day]

    from_page = len(aggregate.stop_high_rows(day)[0])
    from_market = render.market_rows(days)[0]["stop_high"]
    from_month = aggregate.monthly_summaries(days)[0]["stop_highs"]
    from_week = aggregate.weekly_summaries(days)[0]["stop_highs"]
    highlight = next(h for h in render.highlights(days, set()) if h["label"] == "ストップ高")

    assert from_page == 31, "記録があるなら全件を数える（上位30銘柄に限らない）"
    assert from_market == 31
    assert from_month == 31
    assert from_week == 31
    assert highlight["value"] == "31銘柄"


def test_ハイライトの数は押した先のページと合う():
    """違う数を出すと、読み手にはどちらが正しいか確かめようがない。"""
    days = [_day_with_31_stop_highs()]
    highlight = next(h for h in render.highlights(days, set()) if h["label"] == "ストップ高")
    assert highlight["href"] == "stop-high/index.html"
    assert highlight["value"] == f"{len(aggregate.stop_high_rows(days[0])[0])}銘柄"


def test_Xの投稿も同じ数を使う():
    payload = _day_with_31_stop_highs()
    tweet = post_to_x._build_tweet(payload)
    assert "この日のストップ高は31銘柄" in tweet
    # 記録がある日に「上位30銘柄のうち」と断ると、数が合わないうえに嘘になる
    assert "上位30銘柄のうち" not in tweet


def test_記録が無い日は上位30銘柄からの推定だと断る():
    payload = _day_with_31_stop_highs()
    del payload["stop_high"]
    tweet = post_to_x._build_tweet(payload)
    assert "上位30銘柄のうちストップ高は30銘柄" in tweet


def test_推定の日が混じる期間はそう断る():
    """記録を使い始めた日をまたぐと件数が急に増える。理由を書かないと
    相場が荒れたように見える。"""
    days = [_day_with_31_stop_highs("2026-09-28")]
    assert aggregate.monthly_summaries(days)[0]["stops_estimated"] is False

    estimated = _day_with_31_stop_highs("2026-09-25")
    del estimated["stop_high"]
    del estimated["stop_low"]
    mixed = aggregate.monthly_summaries(days + [estimated])[0]
    assert mixed["stops_estimated"] is True
    assert mixed["stop_highs"] == 61          # 31（記録）＋ 30（推定）


def test_ストップ安も同じ道を通る():
    day = _day_with_31_stop_highs()
    day["stop_low"] = [
        {"rank": 1, "code": "4599", "name": "ステムリム", "close": 239.0,
         "change_pct": -25.08, "at_limit": True}
    ]
    days = [day]
    assert aggregate.stop_low_rows(day)[0] and len(aggregate.stop_low_rows(day)[0]) == 1
    assert render.market_rows(days)[0]["stop_low"] == 1
    assert aggregate.monthly_summaries(days)[0]["stop_lows"] == 1
    # ストップ安のハイライトは**値下がりのページ**に出る
    highlight = next(
        h for h in render.highlights(days, set(), "losers") if h["label"] == "ストップ安")
    assert highlight["value"] == "1銘柄"


def test_値上がりのページにストップ安を出さない():
    """値上がりランキングを見に来た人に「ストップ安 3銘柄」を見せても、
    そのページの話ではない。逆も同じ。"""
    day = _day_with_31_stop_highs()
    day["stop_low"] = [
        {"rank": 1, "code": "4599", "name": "ステムリム", "close": 239.0,
         "change_pct": -25.08, "at_limit": True}
    ]
    labels = [h["label"] for h in render.highlights([day], set(), "gainers")]
    assert "ストップ高" in labels
    assert "ストップ安" not in labels

    labels = [h["label"] for h in render.highlights([day], set(), "losers")]
    assert "ストップ安" in labels
    assert "ストップ高" not in labels


def test_活況のページにはハイライトを出さない():
    """ストップ高もストップ安も、約定回数の話ではない。"""
    assert render.highlights([_day_with_31_stop_highs()], set(), "active") == []


# --- 取れなかったことに気づけるか -------------------------------------------

def test_ストップ高の一覧が欠けていたら知らせる():
    """ランキングは取れているので鮮度の判定には引っかからない。
    黙って推定にフォールバックすると、当日中に取り直す機会を逃す。"""
    import check_freshness
    payload = {"rec_date": "2026-09-28", "gainers": [], "stop_low": []}
    assert check_freshness.missing_stop_records(payload) == ["stop_high"]


def test_0件の日は欠けていない():
    """相場が穏やかな日は本当に0件。空リストが入っているのが正しい。"""
    import check_freshness
    payload = {"rec_date": "2026-09-28", "stop_high": [], "stop_low": []}
    assert check_freshness.missing_stop_records(payload) == []


def test_記録を始める前の日は欠落として数えない():
    import check_freshness
    payload = {"rec_date": "2026-09-18", "gainers": []}
    assert check_freshness.missing_stop_records(payload) == []


# --- 数えたのに出していない ---------------------------------------------------

def test_週まとめもストップ高とストップ安を出す():
    """週は「その週に何が起きたか」を見る場所。数えてあるのに
    どこにも出していなかった（月まとめだけ出していた）。"""
    week = {
        "day_count": 1, "stop_highs": 31, "stop_lows": 2, "stops_estimated": False,
        "from": "2026-09-28", "to": "2026-09-28",
        "top_movers": [{"rec_date": "2026-09-28", "name": "銘柄1", "code": "1001",
                        "change_pct": 44.25}],
        "frequent": [],
    }
    text = render.week_summary(week)
    assert "ストップ高はのべ31銘柄" in text
    assert "ストップ安はのべ2銘柄" in text


def test_週まとめも推定が混じればそう断る():
    week = {
        "day_count": 1, "stop_highs": 5, "stop_lows": 0, "stops_estimated": True,
        "from": "2026-09-18", "to": "2026-09-18",
        "top_movers": [{"rec_date": "2026-09-18", "name": "銘柄1", "code": "1001",
                        "change_pct": 44.25}],
        "frequent": [],
    }
    assert "推定" in render.week_summary(week)


# --- 日別ページから記録へ ------------------------------------------------------

def test_日別ページはその日の全件を言う():
    """日別の表は上位30銘柄まで。記録があるなら、その日の全件が何件だったかは
    このページで言える。言わないと、ためている意味がいちばん人の来るページに届かない。"""
    day = _day_with_31_stop_highs()
    note = render.day_stop_note(day, "gainers")
    assert note["count"] == 31
    assert note["outside"] == 1        # 表の外にいた1銘柄
    assert note["href"] == "stop-high/index.html"


def test_推定しか無い日は件数を言わない():
    """上位30銘柄の中の数を「その日の件数」として書かない。"""
    day = _day_with_31_stop_highs()
    del day["stop_high"]
    assert render.day_stop_note(day, "gainers") is None


def test_活況のページには出さない():
    assert render.day_stop_note(_day_with_31_stop_highs(), "active") is None


def test_値下がりの日別ページにはストップ安を出す():
    day = _day_with_31_stop_highs()
    day["stop_low"] = [{"rank": 1, "code": "4599", "name": "ステムリム",
                        "close": 239.0, "change_pct": -25.08, "at_limit": True}]
    note = render.day_stop_note(day, "losers")
    assert note["term"] == "ストップ安"
    assert note["href"] == "stop-low/index.html"


def test_この週のまとめはその週へ行く():
    """「この週のまとめを見る」と書きながら週の一覧へ飛ばしていた。"""
    assert render.week_href_for("2026-09-25") == "weekly/2026-W39.html"
    assert render.week_href_for("2026-09-28") == "weekly/2026-W40.html"


# --- 銘柄ページ ---------------------------------------------------------------

def _stock_day(rec_date, *, gainer=True):
    """ストップ高（163円 / +44.25%）の日。"""
    row = {"rank": 1, "code": "5131", "name": "リンカーズ", "close": 163.0,
           "change_pct": 44.25, "metric_value": 100}
    low = {"rank": 1, "code": "5131", "name": "リンカーズ", "close": 239.0,
           "change_pct": -25.08, "metric_value": 100}
    return {"rec_date": rec_date,
            "gainers": [row] if gainer else [],
            "losers": [] if gainer else [low],
            "active": []}


def test_銘柄ページは上限と下限を分けて数える():
    """合計だけだと、上がって止まったのか下がって止まったのかが分からない。"""
    import aggregate
    days = [_stock_day("2026-09-18"), _stock_day("2026-09-17"),
            _stock_day("2026-09-16", gainer=False)]
    stock = next(s for s in aggregate.stock_histories(days) if s["code"] == "5131")
    assert stock["stop_highs"] == 2
    assert stock["stop_lows"] == 1
    assert stock["stops"] == 3


def test_銘柄ページの一文は回数を二度書かない():
    """すぐ下の行で「ストップ高 N 回」と出すので、要約では言わない。"""
    import aggregate
    days = [_stock_day("2026-09-18"), _stock_day("2026-09-17"), _stock_day("2026-09-16")]
    stock = next(s for s in aggregate.stock_histories(days) if s["code"] == "5131")
    text = render.stock_summary(stock, len(days))
    assert "制限値幅いっぱい" not in text
    assert "3回登場" in text


# --- 表記の揺れ ---------------------------------------------------------------

def test_一覧の日付は年が変わるところだけ年を出す():
    """毎行に年を繰り返すと読みにくく、全部落とすと年をまたいだとき
    どの年か分からない。アーカイブ一覧とストップ高の記録で
    年の有無が食い違っていた（2026-09-27 に揃えた）。"""
    labels = render.date_list_labels(
        ["2027-01-05", "2026-12-30", "2026-12-29"])
    assert labels["2027-01-05"] == "2027年1月5日（火）"
    assert labels["2026-12-30"] == "2026年12月30日（水）"   # 年が変わった行
    assert labels["2026-12-29"] == "12月29日（火）"          # 同じ年は短く


def test_同じ年だけの一覧は先頭にだけ年が出る():
    labels = render.date_list_labels(["2026-09-25", "2026-09-24"])
    assert labels["2026-09-25"].startswith("2026年")
    assert not labels["2026-09-24"].startswith("2026年")


def test_日別ページに同じ数を二度書かない():
    """記録がある日は、要約の「うち N 銘柄はストップ高です」（上位30銘柄の中の数）と
    案内の「この日ストップ高になったのは N 銘柄」（全件）が**違う数で並ぶ**。
    同じページに違う数が2つあると、読み手はどちらが正しいか決められない。"""
    day = _day_with_31_stop_highs()
    rows = day["gainers"]
    with_stops = render.day_summary(rows, "gainers")
    without = render.day_summary(rows, "gainers", omit_stops=True)
    assert "ストップ高です" in with_stops
    assert "ストップ高です" not in without
    # 落としても、ほかの事実は残る
    assert "首位は" in without and "10%以上" in without

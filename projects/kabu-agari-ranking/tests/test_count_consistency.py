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

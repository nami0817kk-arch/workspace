from src import insights


def test_誰かの言葉が何秒目に出るか():
    """**早いほど残る**（2026-09-10 の実測）。ショート20本で 50.4% と 33.7%。"""
    from src import insights

    script = {"scenes": [
        {"lines": [{"speaker": "キャスター", "text": "タイトル", "duration": 7.0}]},
        {"lines": [
            {"speaker": "解説", "text": "状況です", "duration": 8.0},
            {"speaker": "チアゴ", "text": "賛成しない", "duration": 2.0},
        ]},
    ]}
    assert insights.quote_start(script) == 15.0

    only = {"scenes": [{"lines": [
        {"speaker": "キャスター", "text": "あ", "duration": 3.0},
        {"speaker": "解説", "text": "い", "duration": 3.0},
    ]}]}
    assert insights.quote_start(only) is None


def test_早い遅いに分けて中央値を出す():
    """**測れた本数も一緒に返す。**上位25本だけ見て結論を出さないため。"""
    from src import insights

    got = insights.split_by_quote([
        (5.0, 60.0), (8.0, 50.0), (30.0, 30.0), (40.0, 20.0), (None, 10.0),
    ])
    assert got["n_early"] == 2 and got["n_late"] == 2
    assert got["early"] == 55.0 and got["late"] == 25.0
    assert got["none"] == 10.0 and got["n_none"] == 1

    thin = insights.split_by_quote([(5.0, 60.0), (8.0, 50.0)])
    assert thin["edge"] is None and thin["early"] is None

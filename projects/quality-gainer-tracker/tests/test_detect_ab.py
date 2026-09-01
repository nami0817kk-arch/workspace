"""detect_ab（A=全モ手法 / B=手法２改）の出力を固定するテスト。

売買ロジックの中核なので、切り出しリファクタで振る舞いが変わっていないことを
ここで担保する。判定そのものの是非は問わない。**現行の出力をそのまま写している**。

価格は合成データ。ネットワーク・DB には触らない。
"""

import pandas as pd
import pytest

from src.analysis import pattern_detector
from src.analysis.pattern_detector import detect_ab

# 営業日40本。前半25本が急騰前の水平帯（1000円）。
DATES = pd.bdate_range("2026-01-01", periods=40)
FLAT_DAYS = 25
REC_DATE = DATES[FLAT_DAYS].strftime("%Y-%m-%d")


def _series(spike_close: float, settle_close: float) -> pd.DataFrame:
    """水平 → 急騰 → 落ち着く、という1銘柄分の値動きを作る。"""
    closes = [1000.0] * FLAT_DAYS + [spike_close] + [settle_close] * (len(DATES) - FLAT_DAYS - 1)
    highs = list(closes)
    return pd.DataFrame({"Close": closes, "High": highs}, index=DATES)


# 元値1000へ戻る → A のみ該当（フィボ半値1150 から -13% なので B は外れる）
PRICES_A = _series(spike_close=1300.0, settle_close=1000.0)
# 急騰高値2000のフィボ半値1500で丸ばり → B のみ該当（元値比 +50% なので A は外れる）
PRICES_B = _series(spike_close=2000.0, settle_close=1500.0)

FRAMES = {"1111": PRICES_A, "2222": PRICES_B}


@pytest.fixture(autouse=True)
def fake_market(monkeypatch):
    """価格取得と指標計算を差し替える。指標は判定が安定する固定値。"""

    def fake_fetch_price(ticker, period="6mo"):
        return FRAMES[ticker].copy()

    def fake_add_indicators(df):
        df = df.copy()
        df["RSI14"] = 55.0
        df["MACD"] = 1.0
        df["MACD_signal"] = 0.5
        return df

    monkeypatch.setattr(pattern_detector, "fetch_price", fake_fetch_price)
    monkeypatch.setattr(pattern_detector, "add_indicators", fake_add_indicators)


def _record(ticker, rec_date=REC_DATE, rec_close=1300.0, name=None):
    return {"ticker": ticker, "name": name or f"銘柄{ticker}",
            "rec_date": rec_date, "rec_close": rec_close}


def test_pattern_a_row_contents():
    """A の1行が、列名・値ともに現行のまま出る。"""
    df_a, df_b = detect_ab([_record("1111")])

    assert list(df_a.columns) == [
        "ticker", "name", "元値", "現在価格", "元値差%", "水平CV%", "RSI14", "MACD", "急騰日",
    ]
    assert df_a.to_dict("records") == [{
        "ticker": "1111", "name": "銘柄1111",
        "元値": 1000.0, "現在価格": 1000.0, "元値差%": 0.0, "水平CV%": 0.0,
        "RSI14": 55.0, "MACD": "↑買い", "急騰日": REC_DATE,
    }]
    assert df_b.empty


def test_pattern_b_row_contents():
    """B の1行が、列名・値ともに現行のまま出る。"""
    df_a, df_b = detect_ab([_record("2222", rec_close=2000.0)])

    assert list(df_b.columns) == [
        "ticker", "name", "フィボ半値", "現在価格", "フィボ差%", "丸ばりCV%",
        "高値比%", "RSI14", "MACD", "急騰日",
    ]
    assert df_b.to_dict("records") == [{
        "ticker": "2222", "name": "銘柄2222",
        "フィボ半値": 1500.0, "現在価格": 1500.0, "フィボ差%": 0.0, "丸ばりCV%": 0.0,
        "高値比%": -25.0, "RSI14": 55.0, "MACD": "↑買い", "急騰日": REC_DATE,
    }]
    assert df_a.empty


def test_both_patterns_detected_together():
    df_a, df_b = detect_ab([_record("1111"), _record("2222", rec_close=2000.0)])
    assert df_a["ticker"].tolist() == ["1111"]
    assert df_b["ticker"].tolist() == ["2222"]


def test_latest_record_wins_per_ticker():
    """同じ銘柄が複数回記録されていたら、rec_date が新しい方だけを使う。"""
    old = _record("1111", rec_date="2026-01-05", name="古い方")
    new = _record("1111", name="新しい方")
    df_a, _ = detect_ab([old, new])
    assert df_a["name"].tolist() == ["新しい方"]
    assert df_a["急騰日"].tolist() == [REC_DATE]


def test_records_without_close_are_ignored():
    """rec_close が無い記録は採用しない（0 も同様）。"""
    assert detect_ab([_record("1111", rec_close=None)])[0].empty
    assert detect_ab([_record("1111", rec_close=0)])[0].empty


def test_non_trading_rec_date_is_moved_to_next_session():
    """記録日が非営業日なら翌営業日に補正する。急騰日の表示は元の値のまま。"""
    weekend = (DATES[FLAT_DAYS] - pd.Timedelta(days=1)).strftime("%Y-%m-%d")
    df_a, _ = detect_ab([_record("1111", rec_date=weekend)])
    assert df_a["急騰日"].tolist() == [weekend], "表示は入力された記録日を保つ"
    assert df_a["元値"].tolist() == [1000.0]


def test_rec_date_after_all_sessions_is_skipped():
    assert detect_ab([_record("1111", rec_date="2099-01-01")])[0].empty


def test_a_candidates_sorted_by_distance_from_base():
    """A は元値差の絶対値が小さい順。"""
    near = _series(spike_close=1300.0, settle_close=1000.0)   # 0%
    far = _series(spike_close=1300.0, settle_close=1050.0)    # +5%
    FRAMES["3333"], FRAMES["4444"] = far, near
    try:
        df_a, _ = detect_ab([_record("3333"), _record("4444")])
        assert df_a["ticker"].tolist() == ["4444", "3333"]
        assert df_a["元値差%"].tolist() == [0.0, 5.0]
    finally:
        del FRAMES["3333"], FRAMES["4444"]


def test_fetch_failure_warns_and_continues(monkeypatch, capsys):
    """1銘柄が落ちても他の銘柄の検出は続く。"""

    def boom(ticker, period="6mo"):
        if ticker == "9999":
            raise RuntimeError("取得できません")
        return FRAMES[ticker].copy()

    monkeypatch.setattr(pattern_detector, "fetch_price", boom)

    df_a, _ = detect_ab([_record("9999"), _record("1111")])

    assert df_a["ticker"].tolist() == ["1111"]
    out = capsys.readouterr().out
    assert "[WARN]" in out and "9999" in out

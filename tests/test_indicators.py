"""指標計算のテスト。列が揃うこと＝後段のスクリーニングが読める形であること。"""
import numpy as np
import pandas as pd

from src.analysis.indicators import add_indicators


def _ohlcv(n=60):
    rng = np.random.default_rng(0)
    close = pd.Series(100 + rng.normal(0, 1, n).cumsum())
    return pd.DataFrame({
        "Open": close, "High": close + 1, "Low": close - 1,
        "Close": close, "Volume": pd.Series(rng.integers(1000, 5000, n)),
    })


def test_adds_all_expected_indicator_columns():
    df = add_indicators(_ohlcv())
    for col in ["SMA20", "MACD", "MACD_signal", "RSI14",
                "STOCH_K", "STOCH_D", "BB_upper", "BB_lower", "OBV"]:
        assert col in df.columns, col


def test_sma20_matches_rolling_mean():
    df = add_indicators(_ohlcv())
    expected = df["Close"].rolling(20).mean()
    pd.testing.assert_series_equal(df["SMA20"], expected, check_names=False)

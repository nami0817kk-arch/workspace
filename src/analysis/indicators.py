import pandas as pd
import ta


def add_indicators(df: pd.DataFrame) -> pd.DataFrame:
    close  = df["Close"]
    high   = df["High"]
    low    = df["Low"]
    volume = df["Volume"]

    df["SMA20"]       = ta.trend.sma_indicator(close, window=20)
    df["MACD"]        = ta.trend.macd(close)
    df["MACD_signal"] = ta.trend.macd_signal(close)
    df["RSI14"]       = ta.momentum.rsi(close, window=14)

    stoch             = ta.momentum.StochasticOscillator(high, low, close, window=14, smooth_window=3)
    df["STOCH_K"]     = stoch.stoch()
    df["STOCH_D"]     = stoch.stoch_signal()

    bb                = ta.volatility.BollingerBands(close)
    df["BB_upper"]    = bb.bollinger_hband()
    df["BB_lower"]    = bb.bollinger_lband()

    df["OBV"]         = ta.volume.on_balance_volume(close, volume)

    return df

import yfinance as yf
import pandas as pd
from pathlib import Path

DATA_DIR = Path(__file__).parent.parent.parent / "data" / "raw"


def fetch_price(ticker: str, period: str = "3mo") -> pd.DataFrame:
    df = yf.download(ticker, period=period, interval="1d", auto_adjust=True, progress=False)
    df.columns = df.columns.droplevel(1) if isinstance(df.columns, pd.MultiIndex) else df.columns
    return df

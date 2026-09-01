import pandas as pd
from pathlib import Path
from src.data.ranking_fetcher import fetch_jp_gainers

WATCHLIST = Path(__file__).parent.parent.parent / "data" / "watchlist.csv"


def load_watchlist(market: str | None = None, cap_types: list[str] | None = None) -> pd.DataFrame:
    df = pd.read_csv(WATCHLIST)
    if market:
        df = df[df["market"] == market.upper()]
    if cap_types:
        df = df[df["cap_type"].isin(cap_types)]
    return df.drop_duplicates(subset=["ticker"]).reset_index(drop=True)


def screen_quality_gainers(
    top_n: int = 20,
    min_gain_pct: float = 0.5,
    source: str = "kabudragon",
    date_str: str | None = None,
    **_kwargs,
) -> pd.DataFrame:
    df = fetch_jp_gainers(top_n=top_n * 3, date_str=date_str, source=source)
    if df.empty:
        print("  [WARN] Web からランキングを取得できませんでした。")
        return pd.DataFrame()

    df = df[df["値上がり率%"] >= min_gain_pct].head(top_n).reset_index(drop=True)
    print(f"  {len(df)} 銘柄取得")
    return df

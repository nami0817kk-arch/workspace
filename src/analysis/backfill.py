"""
過去の営業日ごとの値上がり質ランキングを価格履歴から再構築する。

yfinance の3ヶ月分の日足データを使い、指定した過去 n 営業日分を
1日ずつ遡って当日ランキングを計算し DataFrame として返す。
"""
import pandas as pd
from src.data.fetcher import fetch_price
from src.analysis.indicators import add_indicators
from src.analysis.screener import load_watchlist


def _quality_gain_score(gain_pct: float, volume_ratio: float,
                        rsi: float | None, macd_buy: bool) -> float:
    score = min(gain_pct, 5.0)
    if volume_ratio >= 3.0:
        score += 3.0
    elif volume_ratio >= 2.0:
        score += 2.0
    elif volume_ratio >= 1.5:
        score += 1.0
    if rsi is not None and 40 <= rsi <= 70:
        score += 1.0
    if macd_buy:
        score += 1.0
    return round(min(score, 10.0), 2)


def _day_metrics(df_to_date: pd.DataFrame, target_date: str,
                 min_gain_pct: float) -> dict | None:
    """
    df_to_date: target_date 当日までのデータ（指標未計算）
    target_date がデータの最終行でなければ None を返す。
    """
    if len(df_to_date) < 35:           # MACD(26日) + 余裕
        return None
    if df_to_date.index[-1] != target_date:
        return None

    df_ind = add_indicators(df_to_date.copy())
    last = df_ind.iloc[-1]
    prev = df_ind.iloc[-2]

    def _f(row, col):
        v = row.get(col) if hasattr(row, "get") else (row[col] if col in row.index else None)
        return float(v) if v is not None and not pd.isna(v) else None

    close_t = _f(last, "Close")
    close_p = _f(prev, "Close")
    vol_t   = _f(last, "Volume")

    if close_t is None or close_p is None or close_p == 0:
        return None

    gain_pct = (close_t - close_p) / close_p * 100
    if gain_pct < min_gain_pct:
        return None

    vol_ma20     = df_to_date["Volume"].tail(21).iloc[:-1].mean()
    volume_ratio = float(vol_t / vol_ma20) if vol_ma20 and vol_ma20 > 0 else 1.0

    rsi      = _f(last, "RSI14")
    macd     = _f(last, "MACD")
    macd_sig = _f(last, "MACD_signal")
    bb_upper = _f(last, "BB_upper")
    bb_lower = _f(last, "BB_lower")
    stoch_k  = _f(last, "STOCH_K")

    macd_buy = macd is not None and macd_sig is not None and macd > macd_sig

    bb_pos = "不明"
    if bb_upper and bb_lower and close_t:
        band = bb_upper - bb_lower
        if band > 0:
            pos = (close_t - bb_lower) / band
            bb_pos = "上限付近" if pos > 0.67 else "中央付近" if pos > 0.33 else "下限付近"

    q_score = _quality_gain_score(gain_pct, volume_ratio, rsi, macd_buy)

    return {
        "終値":          round(close_t, 2),
        "値上がり率%":   round(gain_pct, 2),
        "出来高比率":    round(volume_ratio, 2),
        "RSI14":         round(rsi, 1) if rsi is not None else None,
        "MACD方向":      "↑買い" if macd_buy else "↓売り",
        "BB位置":        bb_pos,
        "Stoch%K":       round(stoch_k, 1) if stoch_k is not None else None,
        "quality_score": q_score,
    }


def build_historical_rankings(
    n_days: int = 14,
    market: str | None = None,
    cap_types: list[str] | None = None,
    top_n: int = 20,
    min_gain_pct: float = 0.5,
    skip_dates: set[str] | None = None,
) -> dict[str, pd.DataFrame]:
    """
    過去 n_days 営業日分の値上がり質ランキングを再構築する。

    Args:
        n_days:       遡る営業日数（デフォルト14）
        skip_dates:   既にDBに記録済みの日付セット（スキップ）

    Returns:
        {date_str: DataFrame}  日付→当日TOP20のDict
    """
    wl      = load_watchlist(market, cap_types)
    tickers = wl["ticker"].tolist()
    names   = dict(zip(wl["ticker"], wl["name"]))

    print(f"  対象銘柄: {len(tickers)} 件")
    print(f"  価格データ取得中...")

    # 全銘柄の3ヶ月分価格データを一括取得（インデックスは YYYY-MM-DD 文字列）
    ticker_data: dict[str, pd.DataFrame] = {}
    for i, ticker in enumerate(tickers, 1):
        try:
            df = fetch_price(ticker, period="3mo")
            if not df.empty:
                df.index = pd.to_datetime(df.index).strftime("%Y-%m-%d")
                ticker_data[ticker] = df
        except Exception:
            pass
        if i % 15 == 0 or i == len(tickers):
            print(f"    {i}/{len(tickers)} 銘柄完了")

    print(f"  取得完了: {len(ticker_data)} 銘柄")

    # 最も行数の多い銘柄から営業日リストを取得
    if not ticker_data:
        print("  価格データが取得できませんでした。")
        return {}

    ref_dates = sorted(max(ticker_data.values(), key=len).index.tolist())

    # 直近 n_days 営業日（本日は除外）
    candidate_dates = ref_dates[-(n_days + 1):-1]
    target_dates = [d for d in candidate_dates
                    if skip_dates is None or d not in skip_dates]

    if not target_dates:
        print("  すべての対象日が既に記録済みです。")
        return {}

    print(f"  集計対象: {target_dates[0]} 〜 {target_dates[-1]}  ({len(target_dates)} 営業日)\n")

    daily_results: dict[str, pd.DataFrame] = {}

    for target_date in target_dates:
        day_rows = []
        for ticker, df in ticker_data.items():
            try:
                df_to = df[df.index <= target_date]
                metrics = _day_metrics(df_to, target_date, min_gain_pct)
                if metrics is None:
                    continue
                metrics["ticker"] = ticker
                metrics["name"]   = names.get(ticker, ticker)
                day_rows.append(metrics)
            except Exception:
                continue

        if day_rows:
            day_df = (
                pd.DataFrame(day_rows)
                .sort_values("quality_score", ascending=False)
                .head(top_n)
                .reset_index(drop=True)
            )
            daily_results[target_date] = day_df
            top3 = ", ".join(
                f"{r['name']}({r['値上がり率%']:+.1f}%)"
                for _, r in day_df.head(3).iterrows()
            )
            print(f"  {target_date}: {len(day_df)}件  [{top3}]")
        else:
            print(f"  {target_date}: 0件（条件に合う値上がりなし）")

    return daily_results

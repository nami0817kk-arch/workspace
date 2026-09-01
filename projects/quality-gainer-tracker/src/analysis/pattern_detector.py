"""
A=全モ手法 / B=手法２改 / C=急落1000円節目手法 の候補を DB履歴から検出する

A. 全モ手法    : 急騰→急落→元値の水平サポート帯に戻ってきた
B. 手法２改    : 急騰→数日かけて下落→フィボナッチ半値付近で丸ばり（水平化）
C. 急落1000節目: RSI25以下 かつ 500/1000/2000等の節目価格付近
"""
import pandas as pd
from src.data.fetcher import fetch_price
from src.analysis.indicators import add_indicators
from src.analysis.screener import load_watchlist

_ROUND_LEVELS = [
    100, 150, 200, 250, 300, 350, 400, 450, 500,
    600, 700, 800, 900, 1000, 1200, 1300, 1500,
    2000, 2500, 3000, 4000, 5000, 10000,
]


def _cv(prices: pd.Series) -> float:
    """変動係数 = std/mean。小さいほど水平。"""
    m = prices.mean()
    return float(prices.std() / m) if m and m != 0 else 999.0


def _nearest_round(price: float, tol: float = 0.05) -> float | None:
    """price から tol（5%）以内の最も近い節目を返す。なければ None。"""
    best, best_diff = None, tol
    for lvl in _ROUND_LEVELS:
        diff = abs(price - lvl) / price
        if diff < best_diff:
            best_diff, best = diff, float(lvl)
    return best


def _pre_spike_base(df: pd.DataFrame, rec_date: str) -> tuple[float, float]:
    """
    急騰前の元値（水平帯の中央値）と変動係数を返す。

    Returns:
        (base_price, cv)  cv が小さいほど水平な元値帯
    """
    pre_dates = [d for d in df.index if d < rec_date]
    if len(pre_dates) < 20:
        return 0.0, 999.0

    closes = df.loc[pre_dates, "Close"]
    # 直近5日は急騰前の動意で動いている可能性があるため除外
    if len(closes) > 25:
        closes = closes.iloc[:-5]
    if len(closes) < 15:
        return 0.0, 999.0

    window = closes.tail(60)
    return float(window.median()), _cv(window)


def _macd_dir(df: pd.DataFrame) -> str:
    macd = df["MACD"].iloc[-1]
    sig  = df["MACD_signal"].iloc[-1]
    return "↑買い" if (not pd.isna(macd) and not pd.isna(sig) and macd > sig) else "↓売り"


def _latest_per_ticker(past_records: list[dict]) -> dict[str, dict]:
    """ticker ごとに、終値が入っている中で最も新しい記録だけを残す。"""
    best: dict[str, dict] = {}
    for r in past_records:
        t = r["ticker"]
        if r.get("rec_close") and (t not in best or r["rec_date"] > best[t]["rec_date"]):
            best[t] = r
    return best


def _align_to_session(rec_date: str, dates: list[str]) -> str | None:
    """記録日が非営業日なら翌営業日に補正する。以降に営業日が無ければ None。"""
    if rec_date in dates:
        return rec_date
    later = [d for d in dates if d >= rec_date]
    return later[0] if later else None


def _spike_high(df: pd.DataFrame, dates: list[str], rec_date: str, rec_close) -> float:
    """急騰高値 = 記録日前後3日の最高値。High が無ければ記録時終値の15%増で代用。"""
    if "High" not in df.columns:
        return float(rec_close) * 1.15
    rec_idx = dates.index(rec_date)
    window = df.iloc[max(0, rec_idx - 1): min(len(df), rec_idx + 3)]
    return float(window["High"].max())


def _measure(ticker: str, info: dict) -> dict | None:
    """1銘柄分の判定材料を測る。材料が揃わなければ None。"""
    df = fetch_price(ticker, period="6mo")
    if len(df) < 30:
        return None
    df = add_indicators(df)
    df.index = pd.to_datetime(df.index).strftime("%Y-%m-%d")

    dates = df.index.tolist()
    rec_date = _align_to_session(info["rec_date"], dates)
    if rec_date is None:
        return None

    base_price, base_cv = _pre_spike_base(df, rec_date)
    if base_price == 0.0:
        return None

    spike_high = _spike_high(df, dates, rec_date, info["rec_close"])
    # データ異常チェック（急騰高値 < 元値は有り得ない）
    if spike_high <= base_price * 1.05:
        return None

    rsi_raw = df["RSI14"].iloc[-1]
    return {
        "base_price": base_price,
        "base_cv":    base_cv,
        "spike_high": spike_high,
        "current":    float(df["Close"].iloc[-1]),
        "rsi":        round(float(rsi_raw), 1) if not pd.isna(rsi_raw) else None,
        "macd":       _macd_dir(df),
        "recent_cv":  _cv(df["Close"].tail(7)),
    }


def _pattern_a_row(ticker: str, name: str, info: dict, m: dict) -> dict | None:
    """A: 全モ手法。

    ① 急騰前の水平帯が存在（CV < 6%）
    ② 現在価格が元値の ±6% 以内に戻っている
    """
    pct_from_base = (m["current"] - m["base_price"]) / m["base_price"] * 100
    if not (m["base_cv"] < 0.06 and abs(pct_from_base) <= 6.0):
        return None
    return {
        "ticker":   ticker,
        "name":     name,
        "元値":     round(m["base_price"], 2),
        "現在価格": round(m["current"], 2),
        "元値差%":  round(pct_from_base, 1),
        "水平CV%":  round(m["base_cv"] * 100, 1),
        "RSI14":    m["rsi"],
        "MACD":     m["macd"],
        "急騰日":   info["rec_date"],
    }


def _pattern_b_row(ticker: str, name: str, info: dict, m: dict) -> dict | None:
    """B: 手法２改。

    ① 急騰高値から20%以上下落している
    ② 現在価格がフィボナッチ半値（元値〜急騰高値の50%）の ±12% 圏内
    ③ 直近7本の価格が水平（丸ばり: CV < 5%）
    """
    fib50         = (m["base_price"] + m["spike_high"]) / 2
    pct_fib       = (m["current"] - fib50) / fib50 * 100
    pct_from_high = (m["current"] - m["spike_high"]) / m["spike_high"] * 100

    if not (pct_from_high <= -20.0 and abs(pct_fib) <= 12.0 and m["recent_cv"] < 0.05):
        return None
    return {
        "ticker":    ticker,
        "name":      name,
        "フィボ半値": round(fib50, 2),
        "現在価格":  round(m["current"], 2),
        "フィボ差%": round(pct_fib, 1),
        "丸ばりCV%": round(m["recent_cv"] * 100, 1),
        "高値比%":   round(pct_from_high, 1),
        "RSI14":     m["rsi"],
        "MACD":      m["macd"],
        "急騰日":    info["rec_date"],
    }


def _ranked_frame(rows: list[dict], key: str) -> pd.DataFrame:
    """候補を key の絶対値が小さい順（元値・半値に近い順）に並べる。"""
    if not rows:
        return pd.DataFrame()
    return (
        pd.DataFrame(rows)
        .sort_values(key, key=lambda s: s.abs())
        .reset_index(drop=True)
    )


def detect_ab(past_records: list[dict]) -> tuple[pd.DataFrame, pd.DataFrame]:
    """
    A（全モ手法）・B（手法２改）の候補を過去ランキング記録から検出する。

    Args:
        past_records: DB から取得した [{"ticker","name","rec_date","rec_close"}, ...]

    Returns:
        (df_a, df_b) 各手法の候補 DataFrame
    """
    results_a, results_b = [], []

    for ticker, info in _latest_per_ticker(past_records).items():
        try:
            m = _measure(ticker, info)
            if m is None:
                continue

            name = info.get("name", ticker)
            row_a = _pattern_a_row(ticker, name, info, m)
            if row_a:
                results_a.append(row_a)
            row_b = _pattern_b_row(ticker, name, info, m)
            if row_b:
                results_b.append(row_b)

        except Exception as e:
            # 1銘柄の失敗で検出全体は止めない。原因は追えるように残す。
            print(f"  [WARN] {ticker}: A/B判定に失敗: {e}")
            continue

    return _ranked_frame(results_a, "元値差%"), _ranked_frame(results_b, "フィボ差%")


def detect_c(
    market: str | None = None,
    cap_types: list[str] | None = None,
    past_set: set[str] | None = None,
    rsi_threshold: float = 25.0,
) -> pd.DataFrame:
    """
    C: 急落1000円節目手法の候補を全ウォッチリストからスキャンする。

    RSI25以下 かつ 節目価格（500/1000/2000...）の5%以内にある銘柄を返す。
    past_set が指定されていれば過去ランキング入りを「◎」でマーク。
    """
    wl      = load_watchlist(market, cap_types)
    names   = dict(zip(wl["ticker"], wl["name"]))
    tickers = wl["ticker"].tolist()

    results = []
    for ticker in tickers:
        try:
            df = fetch_price(ticker, period="3mo")
            if len(df) < 20:
                continue
            df = add_indicators(df)

            current = float(df["Close"].iloc[-1])
            rsi_raw = df["RSI14"].iloc[-1]

            if pd.isna(rsi_raw) or float(rsi_raw) > rsi_threshold:
                continue

            nearest = _nearest_round(current)
            if nearest is None:
                continue

            results.append({
                "ticker":  ticker,
                "name":    names.get(ticker, ticker),
                "節目価格": int(nearest),
                "現在価格": round(current, 2),
                "節目差%": round((current - nearest) / nearest * 100, 1),
                "RSI14":   round(float(rsi_raw), 1),
                "MACD":    _macd_dir(df),
                "既ランク": "◎" if (past_set and ticker in past_set) else "",
            })
        except Exception as e:
            # 1銘柄の失敗で検出全体は止めない。原因は追えるように残す。
            print(f"  [WARN] {ticker}: C判定に失敗: {e}")
            continue

    if not results:
        return pd.DataFrame()
    return pd.DataFrame(results).sort_values("RSI14").reset_index(drop=True)

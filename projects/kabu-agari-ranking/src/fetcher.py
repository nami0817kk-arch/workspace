"""
当日の株価ランキングを kabutan.jp から取得する。

HTML の取得・解析は 共有パッケージ kabutan-client に一本化してある
（quality-gainer-tracker と共通）。kabutan.jp の構造が変わったときに
直すのは kabutan-client 側で、このファイルはランキングの組み立てだけを持つ。

kabutan.jp/warning/ の各ランキングの mode:
  2_1: 今日の上昇率（値上がり率ランキング）
  2_2: 今日の下落率（値下がり率ランキング）
  2_9: 本日の活況銘柄（約定回数ランキング。出来高そのものではない点に注意）
"""
import time
from datetime import date

import pandas as pd
from kabutan import (
    MARKETS as _KABUTAN_MARKETS,
    MODE_ACTIVE as _MODE_ACTIVE,
    MODE_GAINERS as _MODE_GAINERS,
    MODE_LOSERS as _MODE_LOSERS,
    fetch_errors,
)
from kabutan import extract_asof_date as _extract_asof_date
from kabutan import fetch_ranking_html as _lib_fetch_ranking_html
from kabutan import fetch_stock_name as _fetch_name
from kabutan import parse_ranking_table as _parse_market_html


def _fetch_market_html(mode: str, market: int, retries: int = 3) -> str | None:
    # テストが monkeypatch で差し替えるため、モジュール内の関数として残している
    return _lib_fetch_ranking_html(mode, market, retries=retries)


def _fill_names(df: pd.DataFrame) -> pd.DataFrame:
    """銘柄名がコード（数字4桁）になっている行を kabutan 個別ページで補完する。"""
    needs_name = df["name"].str.match(r"^\d{4}$")
    for idx, row in df[needs_name].iterrows():
        df.at[idx, "name"] = _fetch_name(row["code"])
        time.sleep(0.5)
    return df


def _fetch_ranking(mode: str, label: str, top_n: int) -> tuple[pd.DataFrame, str | None]:
    """3市場を集約した生データ（フィルタ・ソート前）と、実際の終値基準日を返す。"""
    print(f"  {label}取得中（kabutan.jp）...")
    all_rows = []
    asof_date = None
    for market in _KABUTAN_MARKETS:
        html = _fetch_market_html(mode, market)
        if html:
            if asof_date is None:
                asof_date = _extract_asof_date(html)
            df_m = _parse_market_html(html)
            if not df_m.empty:
                all_rows.append(df_m)
        time.sleep(1)

    if not all_rows:
        return pd.DataFrame(), asof_date

    df = (
        pd.concat(all_rows, ignore_index=True)
        .drop_duplicates("ticker")
        .reset_index(drop=True)
    )
    return df, asof_date


def _finalize(df: pd.DataFrame, rec_date: str | None) -> pd.DataFrame:
    df = _fill_names(df.reset_index(drop=True))
    df["rec_date"] = rec_date or str(date.today())
    df.insert(0, "rank", range(1, len(df) + 1))
    return df


def fetch_gainers(top_n: int = 30) -> pd.DataFrame:
    """値上がり率上位 top_n 件。columns: rank,ticker,code,name,close,change_pct,metric_value(出来高),rec_date"""
    df, asof_date = _fetch_ranking(_MODE_GAINERS, "値上がりランキング", top_n)
    if df.empty:
        return df
    df = df[df["change_pct"] > 0].sort_values("change_pct", ascending=False).head(top_n)
    return _finalize(df, asof_date)


def fetch_losers(top_n: int = 30) -> pd.DataFrame:
    """値下がり率上位 top_n 件（下落率が大きい順）。columns同上（change_pctは負値）。"""
    df, asof_date = _fetch_ranking(_MODE_LOSERS, "値下がりランキング", top_n)
    if df.empty:
        return df
    df = df[df["change_pct"] < 0].sort_values("change_pct", ascending=True).head(top_n)
    return _finalize(df, asof_date)


def fetch_active(top_n: int = 30) -> pd.DataFrame:
    """約定回数（取引の活発さ）上位 top_n 件。metric_valueは約定回数。"""
    df, asof_date = _fetch_ranking(_MODE_ACTIVE, "活況銘柄ランキング", top_n)
    if df.empty:
        return df
    df = df.sort_values("metric_value", ascending=False).head(top_n)
    return _finalize(df, asof_date)

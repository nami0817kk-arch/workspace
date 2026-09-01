"""kabutan の HTML 解析まわりのテスト。

ここが壊れると、サイトは「エラーも出さずにランキングが空になる」という
一番気づきにくい壊れ方をする。取得先の HTML 構造は先方の都合で変わるので、
想定している形を固定しておく。
"""

import pandas as pd
import pytest

from fetcher import (
    _extract_asof_date,
    _parse_market_html,
    fetch_active,
    fetch_gainers,
    fetch_losers,
)


def _row(cells: list[str]) -> str:
    return "<tr>" + "".join(f"<td>{c}</td>" for c in cells) + "</tr>"


# プライム市場: 13列。code[0] name[1] market[2] _ _ close[5] _ 前日比[7] change%[8] metric[9]
def _prime_row(code, name, close, change, metric):
    return _row([code, name, "プライム", "-", "-", close, "-", "+10", change, metric, "-", "-", "-"])


# スタンダード/グロース: 12列。code[0] market[1] _ _ close[4] _ 前日比[6] change%[7] metric[8]
def _standard_row(code, close, change, metric):
    return _row([code, "スタンダード", "-", "-", close, "-", "+5", change, metric, "-", "-", "-"])


def _table(rows: list[str], asof: str | None = "2026-08-28") -> str:
    time_tag = f'<time datetime="{asof}">終値</time>' if asof else ""
    return f'<html>{time_tag}<table class="stock_table">{"".join(rows)}</table></html>'


def test_parses_prime_market_rows():
    df = _parse_market_html(_table([_prime_row("7203", "トヨタ自動車", "2,500", "+12.5%", "1,234,000")]))

    assert len(df) == 1
    row = df.iloc[0]
    assert row["code"] == "7203"
    assert row["ticker"] == "7203.T"
    assert row["name"] == "トヨタ自動車"
    assert row["close"] == 2500.0
    assert row["change_pct"] == 12.5
    assert row["metric_value"] == 1234000


def test_parses_standard_market_rows_without_a_name_column():
    df = _parse_market_html(_table([_standard_row("3990", "1,200", "+8.0%", "45,000")]))

    row = df.iloc[0]
    # 12列版には銘柄名が無いので、いったんコードで埋めて後段で補完する
    assert row["name"] == "3990"
    assert row["change_pct"] == 8.0
    assert row["metric_value"] == 45000


def test_parses_negative_change_percentages():
    df = _parse_market_html(_table([_prime_row("9984", "ソフトバンクG", "8,000", "-15.3%", "900,000")]))
    assert df.iloc[0]["change_pct"] == -15.3


def test_skips_header_and_malformed_rows():
    rows = [
        _row(["コード", "銘柄名"]),                       # 列数が足りないヘッダ
        _row(["ABCD", "変な行", "-", "-", "-", "1", "-", "-", "+1%", "1", "-", "-", "-"]),  # コードが4桁数字でない
        _prime_row("7203", "トヨタ自動車", "2,500", "+12.5%", "1,000"),
    ]
    df = _parse_market_html(_table(rows))
    assert list(df["code"]) == ["7203"]


def test_missing_table_returns_empty_frame_instead_of_raising():
    df = _parse_market_html("<html><body>メンテナンス中</body></html>")
    assert isinstance(df, pd.DataFrame) and df.empty


def test_extracts_the_closing_date_from_the_page():
    """休場日に実行しても、取得日ではなく終値の営業日をラベルにする。"""
    assert _extract_asof_date(_table([], asof="2026-08-28")) == "2026-08-28"
    assert _extract_asof_date(_table([], asof=None)) is None


# --- ランキングの絞り込み・並び替え --------------------------------------

@pytest.fixture
def offline(monkeypatch):
    """ネットワークに出ずに fetch_* を動かせるようにする。"""
    import fetcher

    monkeypatch.setattr(fetcher.time, "sleep", lambda *_: None)
    monkeypatch.setattr(fetcher, "_fetch_name", lambda code: f"銘柄{code}")

    def _serve(html: str):
        # 3市場ぶん呼ばれるが、重複は ticker で落ちるので同じ HTML を返してよい
        monkeypatch.setattr(fetcher, "_fetch_market_html", lambda mode, market, retries=3: html)

    return _serve


def test_gainers_keep_only_rises_sorted_high_to_low(offline):
    offline(_table([
        _prime_row("1111", "A", "100", "+3.0%", "10"),
        _prime_row("2222", "B", "100", "+9.0%", "10"),
        _prime_row("3333", "C", "100", "-4.0%", "10"),
    ]))
    df = fetch_gainers(top_n=10)

    assert list(df["code"]) == ["2222", "1111"]      # 下落銘柄は除外される
    assert list(df["rank"]) == [1, 2]
    assert df["rec_date"].iloc[0] == "2026-08-28"    # 終値日付が使われる


def test_gainers_respect_top_n(offline):
    offline(_table([_prime_row(f"{1000+i}", f"A{i}", "100", f"+{i}.0%", "10") for i in range(1, 6)]))
    assert len(fetch_gainers(top_n=2)) == 2


def test_losers_keep_only_falls_sorted_by_severity(offline):
    offline(_table([
        _prime_row("1111", "A", "100", "-3.0%", "10"),
        _prime_row("2222", "B", "100", "-9.0%", "10"),
        _prime_row("3333", "C", "100", "+4.0%", "10"),
    ]))
    assert list(fetch_losers(top_n=10)["code"]) == ["2222", "1111"]


def test_active_ranks_by_trade_count_not_by_change(offline):
    offline(_table([
        _prime_row("1111", "A", "100", "+30.0%", "10"),
        _prime_row("2222", "B", "100", "+1.0%", "9,999"),
    ]))
    assert list(fetch_active(top_n=10)["code"]) == ["2222", "1111"]


def test_empty_source_yields_an_empty_frame_not_an_exception(offline):
    offline(_table([]))
    assert fetch_gainers(top_n=10).empty

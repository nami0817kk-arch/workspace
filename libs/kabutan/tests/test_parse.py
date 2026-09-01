"""kabutan の HTML 解析のテスト。

ここが壊れると、利用側（kabu-agari-ranking / quality-gainer-tracker）は
「エラーも出さずにランキングが空になる」という一番気づきにくい壊れ方をする。
取得先の HTML 構造は先方の都合で変わるので、想定している形を固定しておく。
"""

import pandas as pd

from kabutan import extract_asof_date, parse_ranking_table


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
    df = parse_ranking_table(
        _table([_prime_row("7203", "トヨタ自動車", "2,500", "+12.5%", "1,234,000")])
    )

    assert len(df) == 1
    row = df.iloc[0]
    assert row["code"] == "7203"
    assert row["ticker"] == "7203.T"
    assert row["name"] == "トヨタ自動車"
    assert row["close"] == 2500.0
    assert row["change_pct"] == 12.5
    assert row["metric_value"] == 1234000


def test_parses_standard_market_rows_without_a_name_column():
    df = parse_ranking_table(_table([_standard_row("3990", "1,200", "+8.0%", "45,000")]))

    row = df.iloc[0]
    # 12列版には銘柄名が無いので、いったんコードで埋めて利用側で補完する
    assert row["name"] == "3990"
    assert row["change_pct"] == 8.0
    assert row["metric_value"] == 45000


def test_parses_negative_change_percentages():
    df = parse_ranking_table(
        _table([_prime_row("9984", "ソフトバンクG", "8,000", "-15.3%", "900,000")])
    )
    assert df.iloc[0]["change_pct"] == -15.3


def test_skips_header_and_malformed_rows():
    rows = [
        _row(["コード", "銘柄名"]),  # 列数が足りないヘッダ
        _row(["ABCD", "変な行", "-", "-", "-", "1", "-", "-", "+1%", "1", "-", "-", "-"]),
        _prime_row("7203", "トヨタ自動車", "2,500", "+12.5%", "1,000"),
    ]
    df = parse_ranking_table(_table(rows))
    assert list(df["code"]) == ["7203"]


def test_missing_table_returns_empty_frame_instead_of_raising():
    df = parse_ranking_table("<html><body>メンテナンス中</body></html>")
    assert isinstance(df, pd.DataFrame) and df.empty


def test_extracts_the_closing_date_from_the_page():
    """休場日に実行しても、取得日ではなく終値の営業日をラベルにできる。"""
    assert extract_asof_date(_table([], asof="2026-08-28")) == "2026-08-28"
    assert extract_asof_date(_table([], asof=None)) is None

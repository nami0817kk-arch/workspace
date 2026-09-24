"""kabutan の HTML 解析のテスト。

ここが壊れると、利用側（kabu-agari-ranking / quality-gainer-tracker）は
「エラーも出さずにランキングが空になる」という一番気づきにくい壊れ方をする。
取得先の HTML 構造は先方の都合で変わるので、想定している形を固定しておく。
"""

import pandas as pd

from kabutan import extract_asof_date, parse_daily_prices, parse_ranking_table


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


# --- as-of 日付の取り違え防止 ---------------------------------------------

_INDEX_HEADER = (
    '<a href="/stock/?code=0800">NYダウ</a><time datetime="2026-09-04">終値</time>'
    '<a href="/stock/?code=0823">東証グロース</a><time datetime="2026-09-07">終値</time>'
)


def test_asof_date_comes_from_the_ranking_not_the_dow_header():
    """先頭の <time> は NYダウ。これを採ると国内ランキングが1営業日ずれる。"""
    html = (
        f"<html>{_INDEX_HEADER}"
        '<div class="meigara_count"><ul><li>2026年09月07日</li><li>16:00現在</li></ul></div>'
        "</html>"
    )
    assert extract_asof_date(html) == "2026-09-07"


def test_asof_date_falls_back_to_the_newest_time_tag():
    """表の日付が取れないときも、古い方（米国市場）を掴まない。"""
    assert extract_asof_date(f"<html>{_INDEX_HEADER}</html>") == "2026-09-07"


def test_asof_date_pads_single_digit_month_and_day():
    html = '<div class="meigara_count"><ul><li>2026年1月5日</li></ul></div>'
    assert extract_asof_date(html) == "2026-01-05"


# --- 日足（時系列）の解析 ---------------------------------------------------

_DAILY_PAGE = """
<html><body>
<table class="stock_kabuka0">
<tr><th>日付</th><th>始値</th><th>高値</th><th>安値</th><th>終値</th>
    <th>前日比</th><th>前日比％</th><th>売買高(株)</th></tr>
<tr><td>26/09/18</td><td>1300</td><td>1600</td><td>1290</td><td>1591</td>
    <td>300</td><td>23.24</td><td>1000000</td></tr>
<tr><td>26/09/17</td><td>1380</td><td>1549</td><td>1283</td><td>1291</td>
    <td>-118</td><td>-8.37</td><td>1294700</td></tr>
</table>
</body></html>
"""


def test_日足を日付つきで読む():
    df = parse_daily_prices(_DAILY_PAGE)
    assert list(df.columns) == ["date", "close", "change_pct"]
    assert df["date"].tolist() == ["2026-09-18", "2026-09-17"]
    assert df["close"].tolist() == [1591, 1291]
    assert df["change_pct"].tolist() == [23.24, -8.37]


def test_日足の表が無ければ空を返す():
    assert parse_daily_prices("<html><body>表がありません</body></html>").empty

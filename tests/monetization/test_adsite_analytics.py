from datetime import date

import pytest

from adsite.analytics import ingest, parse_report, summarize_rows, top_pages
from adsite.ledger import month_range, summarize
from adsite.models import AdDaily

CSV_EN = """Date,Page URL,Ad impressions,Clicks,Estimated earnings (USD),Page views
2026-08-01,/tools/llm-cost/,1200,14,$3.40,900
2026-08-01,/tools/automation-roi/,800,6,$1.60,600
2026-08-02,/tools/llm-cost/,1500,20,$4.80,1100
"""

CSV_JA = """日付,ページ,広告の表示回数,クリック数,推定収益額,ページビュー
2026/08/01,/tools/llm-cost/,"1,200",14,"3.40","900"
"""


def test_parses_english_report():
    rows, errors = parse_report(CSV_EN)
    assert errors == [] and len(rows) == 3
    assert rows[0].day == date(2026, 8, 1)
    assert rows[0].page == "/tools/llm-cost/"
    assert rows[0].earnings_usd == pytest.approx(3.40)


def test_parses_japanese_report_with_thousand_separators():
    rows, errors = parse_report(CSV_JA)
    assert errors == []
    assert rows[0].impressions == 1200 and rows[0].pageviews == 900


def test_column_with_currency_suffix_is_matched():
    rows, errors = parse_report("Date,Estimated earnings (USD)\n2026-08-01,1.50\n")
    assert errors == [] and rows[0].earnings_usd == pytest.approx(1.50)


def test_page_column_is_not_stolen_by_page_views():
    rows, _ = parse_report("Date,Page views,Page URL,Estimated earnings\n2026-08-01,900,/a/,1.00\n")
    assert rows[0].page == "/a/" and rows[0].pageviews == 900


def test_missing_required_column_is_reported():
    rows, errors = parse_report("Foo,Bar\n1,2\n")
    assert rows == [] and "必須列" in errors[0]


def test_empty_csv_is_reported():
    assert parse_report("") == ([], ["CSVが空です"])


def test_bad_date_row_is_skipped_with_reason():
    rows, errors = parse_report("Date,Estimated earnings\nnot-a-date,1.00\n2026-08-01,2.00\n")
    assert len(rows) == 1 and "日付を解釈できません" in errors[0]


def test_rpm_prefers_pageviews_over_impressions():
    stats = summarize_rows([AdDaily(day=date(2026, 8, 1), page="/", impressions=2000, clicks=10, pageviews=1000, earnings_usd=5.0)])
    assert stats.rpm_usd == pytest.approx(5.0)
    assert stats.ctr == pytest.approx(0.005)


def test_rpm_falls_back_to_impressions():
    stats = summarize_rows([AdDaily(day=date(2026, 8, 1), page="/", impressions=1000, earnings_usd=2.0)])
    assert stats.rpm_usd == pytest.approx(2.0)


def test_empty_rows_do_not_divide_by_zero():
    stats = summarize_rows([])
    assert stats.rpm_usd == 0.0 and stats.ctr == 0.0


def test_top_pages_ranks_by_earnings():
    rows, _ = parse_report(CSV_EN)
    assert top_pages(rows, limit=1) == [("/tools/llm-cost/", pytest.approx(8.20))]


def test_ingest_records_daily_stats_and_revenue(storage):
    rows, _ = parse_report(CSV_EN)
    days, total = ingest(storage, rows)

    assert days == 2 and total == pytest.approx(9.80)
    since, until = month_range(date(2026, 8, 1))
    econ = summarize(storage, since=since, until=until)
    assert econ.revenue_usd == pytest.approx(9.80)
    assert econ.pageviews == 2600
    assert econ.impressions == 3500


def test_reingest_does_not_double_count(storage):
    rows, _ = parse_report(CSV_EN)
    ingest(storage, rows)
    ingest(storage, rows)
    since, until = month_range(date(2026, 8, 1))
    econ = summarize(storage, since=since, until=until)
    assert econ.revenue_usd == pytest.approx(9.80)
    assert econ.pageviews == 2600


def test_revised_estimates_overwrite_previous_values(storage):
    """AdSenseの金額は推定値で、後日確定値に改定される。最後の取り込みが正。"""
    ingest(storage, parse_report("Date,Estimated earnings,Page views\n2026-08-01,3.00,500\n")[0])
    ingest(storage, parse_report("Date,Estimated earnings,Page views\n2026-08-01,2.75,520\n")[0])

    since, until = month_range(date(2026, 8, 1))
    econ = summarize(storage, since=since, until=until)
    assert econ.revenue_usd == pytest.approx(2.75)
    assert econ.pageviews == 520

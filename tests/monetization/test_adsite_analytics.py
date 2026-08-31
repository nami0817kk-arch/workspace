from datetime import date

import pytest

from adsite.analytics import (
    AdRow,
    parse_report,
    pageviews_needed,
    record_ad_revenue,
    summarize_rows,
    top_pages,
)
from moneyloop.ledger import summarize
from moneyloop.storage import Storage

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


def test_missing_required_column_is_reported():
    rows, errors = parse_report("Foo,Bar\n1,2\n")
    assert rows == [] and "必須列" in errors[0]


def test_empty_csv_is_reported():
    assert parse_report("") == ([], ["CSVが空です"])


def test_bad_date_row_is_skipped_with_reason():
    rows, errors = parse_report("Date,Estimated earnings\nnot-a-date,1.00\n2026-08-01,2.00\n")
    assert len(rows) == 1
    assert "日付を解釈できません" in errors[0]


def test_rpm_prefers_pageviews_over_impressions():
    stats = summarize_rows([AdRow(day=date(2026, 8, 1), page="/", impressions=2000, clicks=10, earnings_usd=5.0, pageviews=1000)])
    assert stats.rpm_usd == pytest.approx(5.0)
    assert stats.ctr == pytest.approx(0.005)


def test_rpm_falls_back_to_impressions():
    stats = summarize_rows([AdRow(day=date(2026, 8, 1), page="/", impressions=1000, clicks=0, earnings_usd=2.0)])
    assert stats.rpm_usd == pytest.approx(2.0)


def test_empty_rows_do_not_divide_by_zero():
    stats = summarize_rows([])
    assert stats.rpm_usd == 0.0 and stats.ctr == 0.0


def test_top_pages_ranks_by_earnings():
    rows, _ = parse_report(CSV_EN)
    assert top_pages(rows, limit=1) == [("/tools/llm-cost/", pytest.approx(8.20))]


def test_ad_revenue_is_recorded_once_per_day(config):
    rows, _ = parse_report(CSV_EN)
    with Storage(":memory:") as storage:
        count, total = record_ad_revenue(storage, rows)
        assert count == 2  # 2日分
        assert total == pytest.approx(9.80)

        # 同じCSVを再取り込みしても二重計上しない
        assert record_ad_revenue(storage, rows) == (0, 0.0)

        econ = summarize(storage, config, date(2026, 8, 1), date(2026, 8, 31))
        assert econ.revenue_usd == pytest.approx(9.80)


def test_ad_revenue_lands_in_the_same_pl_as_subscriptions(config):
    """広告と購読は別の収益源だが、同じ台帳・同じPLで見えることを確認する。"""
    from moneyloop.ledger import accrue_subscriptions
    from moneyloop.models import Subscriber

    rows, _ = parse_report(CSV_EN)
    with Storage(":memory:") as storage:
        storage.upsert_subscriber(
            Subscriber(email="p@x.test", niche="ai-ops", plan="pro", started_at=date(2026, 8, 1))
        )
        accrue_subscriptions(storage, config, on=date(2026, 8, 5))
        record_ad_revenue(storage, rows)

        econ = summarize(storage, config, date(2026, 8, 1), date(2026, 8, 31))
        assert econ.revenue_usd == pytest.approx(30.0 + 9.80)
        categories = {e.category for e in storage.ledger_entries() if e.kind == "revenue"}
        assert categories == {"subscription:pro", "ads:adsense"}


def test_pageviews_needed_is_the_scale_of_the_business():
    # RPM $4 で月$700 を狙うなら 175,000 PV/月
    assert pageviews_needed(700, 4.0) == 175_000
    assert pageviews_needed(700, 0) == 0


def test_column_with_currency_suffix_is_matched():
    """AdSenseは 'Estimated earnings (USD)' のように単位を付けてくる。"""
    rows, errors = parse_report("Date,Estimated earnings (USD)\n2026-08-01,1.50\n")
    assert errors == [] and rows[0].earnings_usd == pytest.approx(1.50)


def test_page_column_is_not_stolen_by_page_views():
    rows, _ = parse_report("Date,Page views,Page URL,Estimated earnings\n2026-08-01,900,/a/,1.00\n")
    assert rows[0].page == "/a/" and rows[0].pageviews == 900

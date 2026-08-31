from datetime import date, datetime

import pytest

from adsite.ledger import (
    month_range,
    pageviews_needed,
    record_cost,
    record_monthly_fixed_cost,
    record_revenue,
    summarize,
)
from adsite.pricing import token_cost_usd
from adsite.storage import Storage


def test_token_cost_matches_price_table():
    assert token_cost_usd("claude-opus-5", 1_000_000, 0) == pytest.approx(5.0)
    assert token_cost_usd("claude-opus-5", 0, 1_000_000) == pytest.approx(25.0)
    assert token_cost_usd("claude-opus-5", 0, 0, 1_000_000) == pytest.approx(0.5)


def test_unknown_model_falls_back_to_opus_pricing():
    assert token_cost_usd("mystery-model", 1_000_000, 0) == pytest.approx(5.0)


def test_cost_is_idempotent_by_ref(storage):
    assert record_cost(storage, category="llm", amount_usd=1.0, ref="r1") is True
    assert record_cost(storage, category="llm", amount_usd=9.0, ref="r1") is False
    assert sum(e.amount_usd for e in storage.ledger_entries()) == pytest.approx(1.0)


def test_ref_is_required(storage):
    with pytest.raises(ValueError):
        record_cost(storage, category="llm", amount_usd=1.0, ref="")


def test_revenue_can_be_revised_when_replace_is_set(storage):
    record_revenue(storage, category="ads", amount_usd=3.0, ref="d1", replace=True)
    record_revenue(storage, category="ads", amount_usd=2.5, ref="d1", replace=True)
    assert sum(e.amount_usd for e in storage.ledger_entries()) == pytest.approx(2.5)


def test_monthly_fixed_cost_is_charged_once_per_month(storage):
    assert record_monthly_fixed_cost(storage, category="domain", amount_usd=1.2, on=date(2026, 8, 3)) is True
    assert record_monthly_fixed_cost(storage, category="domain", amount_usd=1.2, on=date(2026, 8, 20)) is False
    assert record_monthly_fixed_cost(storage, category="domain", amount_usd=1.2, on=date(2026, 9, 1)) is True


def test_summarize_computes_ad_unit_economics(storage):
    from adsite.analytics import ingest, parse_report

    ingest(storage, parse_report(
        "Date,Page URL,Ad impressions,Clicks,Estimated earnings,Page views\n"
        "2026-08-01,/a/,10000,80,20.00,8000\n"
    )[0])
    record_cost(storage, category="fixed:domain", amount_usd=1.20, ref="c1", ts=datetime(2026, 8, 1))

    since, until = month_range(date(2026, 8, 1))
    econ = summarize(storage, since=since, until=until)

    assert econ.revenue_usd == pytest.approx(20.0)
    assert econ.profit_usd == pytest.approx(18.8)
    assert econ.rpm_usd == pytest.approx(2.5)  # $20 / 8000PV × 1000
    assert econ.ctr == pytest.approx(0.008)
    assert econ.breakeven_pageviews == 480  # $1.20 ÷ RPM$2.5 × 1000


def test_breakeven_is_zero_without_measured_rpm(storage):
    record_cost(storage, category="fixed:domain", amount_usd=1.20, ref="c1", ts=datetime(2026, 8, 1))
    since, until = month_range(date(2026, 8, 1))
    assert summarize(storage, since=since, until=until).breakeven_pageviews == 0


def test_period_boundaries_are_inclusive_of_last_day(storage):
    record_cost(storage, category="llm", amount_usd=1.0, ref="in", ts=datetime(2026, 8, 31, 23, 59))
    record_cost(storage, category="llm", amount_usd=99.0, ref="out", ts=datetime(2026, 9, 1, 0, 1))
    since, until = month_range(date(2026, 8, 1))
    assert summarize(storage, since=since, until=until).cost_usd == pytest.approx(1.0)


def test_empty_period_does_not_divide_by_zero(storage):
    since, until = month_range(date(2026, 8, 1))
    econ = summarize(storage, since=since, until=until)
    assert econ.margin == 0.0 and econ.rpm_usd == 0.0 and econ.ctr == 0.0


def test_pageviews_needed_is_the_scale_of_the_business():
    # RPM $4 で月$700 を狙うなら 175,000 PV/月
    assert pageviews_needed(700, 4.0) == 175_000
    assert pageviews_needed(700, 0) == 0


def test_ad_daily_is_scoped_to_the_period():
    with Storage(":memory:") as storage:
        from adsite.analytics import ingest, parse_report

        ingest(storage, parse_report(
            "Date,Estimated earnings,Page views\n2026-07-31,5.00,400\n2026-08-01,3.00,300\n"
        )[0])
        since, until = month_range(date(2026, 8, 1))
        assert summarize(storage, since=since, until=until).pageviews == 300

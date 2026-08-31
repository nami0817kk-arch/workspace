from datetime import date, datetime

import pytest

from moneyloop.ledger import accrue_subscriptions, month_range, record_cost, summarize
from moneyloop.models import Subscriber
from moneyloop.pricing import token_cost_usd


def test_token_cost_matches_price_table():
    # Opus 5: $5 / $25 per MTok
    assert token_cost_usd("claude-opus-5", 1_000_000, 0) == pytest.approx(5.0)
    assert token_cost_usd("claude-opus-5", 0, 1_000_000) == pytest.approx(25.0)
    # キャッシュ読みは入力単価の10%
    assert token_cost_usd("claude-opus-5", 0, 0, 1_000_000) == pytest.approx(0.5)


def test_unknown_model_falls_back_to_opus_pricing():
    assert token_cost_usd("mystery-model", 1_000_000, 0) == pytest.approx(5.0)


def test_record_cost_is_idempotent_by_ref(storage):
    assert record_cost(storage, category="llm", amount_usd=1.0, ref="r1") is True
    assert record_cost(storage, category="llm", amount_usd=1.0, ref="r1") is False
    assert sum(e.amount_usd for e in storage.ledger_entries()) == pytest.approx(1.0)


def test_record_cost_requires_ref(storage):
    with pytest.raises(ValueError):
        record_cost(storage, category="llm", amount_usd=1.0, ref="")


def test_accrue_subscriptions_charges_paid_plans_once_per_month(config, storage):
    started = date(2026, 8, 1)
    storage.upsert_subscriber(Subscriber(email="p@x.test", niche="ai-ops", plan="pro", started_at=started))
    storage.upsert_subscriber(Subscriber(email="f@x.test", niche="ai-ops", plan="free", started_at=started))
    on = date(2026, 8, 10)

    count, total = accrue_subscriptions(storage, config, on=on)
    assert (count, total) == (1, 30.0)

    # 同月に再実行しても二重計上しない
    assert accrue_subscriptions(storage, config, on=date(2026, 8, 25)) == (0, 0.0)
    # 翌月は新たに計上される
    assert accrue_subscriptions(storage, config, on=date(2026, 9, 1)) == (1, 30.0)


def test_future_dated_subscriber_is_not_accrued_yet(config, storage):
    storage.upsert_subscriber(
        Subscriber(email="later@x.test", niche="ai-ops", plan="pro", started_at=date(2026, 9, 1))
    )
    assert accrue_subscriptions(storage, config, on=date(2026, 8, 10)) == (0, 0.0)


def test_canceled_subscriber_stops_accruing(config, storage):
    storage.upsert_subscriber(Subscriber(email="p@x.test", niche="ai-ops", plan="pro", started_at=date(2026, 8, 1)))
    storage.cancel_subscriber("p@x.test", "ai-ops")
    assert accrue_subscriptions(storage, config, on=date(2026, 8, 10)) == (0, 0.0)


def test_summarize_computes_unit_economics(config, storage):
    on = date(2026, 8, 10)
    since, until = month_range(on)
    for i in range(4):
        storage.upsert_subscriber(
            Subscriber(email=f"p{i}@x.test", niche="ai-ops", plan="pro", started_at=date(2026, 8, 1))
        )
    storage.upsert_subscriber(
        Subscriber(email="f@x.test", niche="ai-ops", plan="free", started_at=date(2026, 8, 1))
    )
    accrue_subscriptions(storage, config, on=on)
    record_cost(storage, category="llm", amount_usd=12.0, ref="c1", ts=datetime(2026, 8, 10))

    econ = summarize(storage, config, since, until)
    assert econ.revenue_usd == pytest.approx(120.0)
    assert econ.cost_usd == pytest.approx(12.0)
    assert econ.gross_profit_usd == pytest.approx(108.0)
    assert econ.gross_margin == pytest.approx(0.9)
    assert econ.paying_subscribers == 4 and econ.free_subscribers == 1
    assert econ.conversion_rate == pytest.approx(0.8)
    # $12 の原価は $30 プラン1人で賄える
    assert econ.breakeven_subscribers == 1


def test_breakeven_rounds_up(config, storage):
    since, until = month_range(date(2026, 8, 1))
    record_cost(storage, category="llm", amount_usd=31.0, ref="c1", ts=datetime(2026, 8, 5))
    assert summarize(storage, config, since, until).breakeven_subscribers == 2


def test_summarize_handles_empty_period(config, storage):
    since, until = month_range(date(2026, 8, 1))
    econ = summarize(storage, config, since, until)
    assert econ.gross_margin == 0.0 and econ.arpu_usd == 0.0 and econ.cost_per_issue_usd == 0.0


def test_period_boundaries_are_inclusive_of_last_day(config, storage):
    since, until = month_range(date(2026, 8, 1))
    record_cost(storage, category="llm", amount_usd=1.0, ref="in", ts=datetime(2026, 8, 31, 23, 59))
    record_cost(storage, category="llm", amount_usd=99.0, ref="out", ts=datetime(2026, 9, 1, 0, 1))
    assert summarize(storage, config, since, until).cost_usd == pytest.approx(1.0)


def test_issue_count_is_bounded_by_period(config, storage):
    from moneyloop.models import Issue

    for d in (date(2026, 7, 31), date(2026, 8, 15), date(2026, 9, 1)):
        storage.save_issue(Issue(niche="ai-ops", issue_date=d, title="t", teaser_md="", body_md=""))
    since, until = month_range(date(2026, 8, 1))
    assert summarize(storage, config, since, until).issues == 1

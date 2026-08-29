"""パイプライン全体の結線と冪等性の検証。LLMはスタブなので課金は発生しない。"""

from datetime import date

import pytest

from moneyloop.llm import StubClient
from moneyloop.models import Subscriber
from moneyloop.orchestrator import run_daily, run_niche

RUN_DATE = date(2026, 8, 29)


def _seed_subscribers(storage):
    storage.upsert_subscriber(Subscriber(email="pro@x.test", niche="ai-ops", plan="pro"))
    storage.upsert_subscriber(Subscriber(email="free@x.test", niche="ai-ops", plan="free"))


def test_end_to_end_produces_issue_and_delivers(config, storage, fetcher):
    _seed_subscribers(storage)
    report = run_niche(config, storage, StubClient(), config.niches[0], run_date=RUN_DATE, fetcher=fetcher)

    assert report.errors == []
    assert report.collected == 3 and report.fresh == 3
    assert report.selected == 3
    assert report.issue is not None and report.issue.id is not None
    assert (report.delivered_paid, report.delivered_free) == (1, 1)
    assert report.cost_usd > 0


def test_rerun_same_day_does_not_regenerate_or_redeliver(config, storage, fetcher):
    _seed_subscribers(storage)
    llm = StubClient()
    run_niche(config, storage, llm, config.niches[0], run_date=RUN_DATE, fetcher=fetcher)
    calls_after_first = len(llm.calls)

    second = run_niche(config, storage, llm, config.niches[0], run_date=RUN_DATE, fetcher=fetcher)

    assert len(llm.calls) == calls_after_first  # 追加のAPI呼び出しなし
    assert "生成済み" in second.skipped_reason
    assert (second.delivered_paid, second.delivered_free) == (0, 0)


def test_cost_is_recorded_once_per_day(config, storage, fetcher):
    run_niche(config, storage, StubClient(), config.niches[0], run_date=RUN_DATE, fetcher=fetcher)
    run_niche(config, storage, StubClient(), config.niches[0], run_date=RUN_DATE, fetcher=fetcher)
    costs = [e for e in storage.ledger_entries() if e.kind == "cost"]
    assert len(costs) == 2  # scoring と generation の2件のみ
    assert {e.category for e in costs} == {"llm:scoring", "llm:generation"}


def test_second_day_skips_already_seen_articles(config, storage, fetcher):
    run_niche(config, storage, StubClient(), config.niches[0], run_date=RUN_DATE, fetcher=fetcher)
    next_day = run_niche(
        config, storage, StubClient(), config.niches[0], run_date=date(2026, 8, 30), fetcher=fetcher
    )
    assert next_day.fresh == 0
    assert "新規記事が0件" in next_day.skipped_reason
    assert next_day.issue is None


def test_quality_gate_blocks_thin_issue(config, storage, fetcher):
    """スコアがしきい値に届かない日は号を出さず、採点原価だけを計上する。"""

    class LowScoreClient(StubClient):
        def complete(self, prompt, **kwargs):
            result = super().complete(prompt, **kwargs)
            if kwargs.get("schema", {}).get("properties", {}).get("scores"):
                result.text = '{"scores": [{"index": 0, "score": 10, "why": "薄い", "tags": []}]}'
            return result

    report = run_niche(config, storage, LowScoreClient(), config.niches[0], run_date=RUN_DATE, fetcher=fetcher)
    assert report.issue is None
    assert "スコア60以上" in report.skipped_reason
    assert [e.category for e in storage.ledger_entries()] == ["llm:scoring"]


def test_generation_failure_is_reported_not_raised(config, storage, fetcher):
    class BrokenClient(StubClient):
        def complete(self, prompt, **kwargs):
            result = super().complete(prompt, **kwargs)
            if kwargs.get("schema", {}).get("properties", {}).get("body_md"):
                result.text = "not json"
            return result

    report = run_niche(config, storage, BrokenClient(), config.niches[0], run_date=RUN_DATE, fetcher=fetcher)
    assert report.issue is None
    assert any("生成に失敗" in e for e in report.errors)


def test_run_daily_accrues_subscription_revenue(config, storage, fetcher):
    _seed_subscribers(storage)
    run_daily(config, storage, StubClient(), run_date=RUN_DATE, fetcher=fetcher)
    revenue = [e for e in storage.ledger_entries() if e.kind == "revenue"]
    assert len(revenue) == 1
    assert revenue[0].amount_usd == pytest.approx(30.0)


def test_file_deliverer_writes_one_file_per_variant(config, storage, fetcher, tmp_path):
    from dataclasses import replace

    config = replace(config, output_dir=tmp_path, delivery=replace(config.delivery, file=True))
    _seed_subscribers(storage)
    storage.upsert_subscriber(Subscriber(email="pro2@x.test", niche="ai-ops", plan="pro"))

    run_niche(config, storage, StubClient(), config.niches[0], run_date=RUN_DATE, fetcher=fetcher)

    written = sorted(p.name for p in (tmp_path / "ai-ops").glob("*.md"))
    assert written == ["2026-08-29-free.md", "2026-08-29-paid.md"]


def test_unknown_plan_is_skipped_with_error(config, storage, fetcher):
    storage.upsert_subscriber(Subscriber(email="ghost@x.test", niche="ai-ops", plan="enterprise"))
    report = run_niche(config, storage, StubClient(), config.niches[0], run_date=RUN_DATE, fetcher=fetcher)
    assert any("未定義プラン" in e for e in report.errors)
    assert (report.delivered_free, report.delivered_paid) == (0, 0)

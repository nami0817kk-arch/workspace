"""パイプライン本体。収集→選別→生成→分割→配信→計上を1本につなぐ。

同じ日に何度実行しても、号は1つ・配信は1回・計上は1回になるよう設計している
（cronの二重起動やリトライで課金が増えないことが運用上いちばん重要）。
"""

from __future__ import annotations

from datetime import date

from . import curate, deliver, generate, ledger, sources
from .config import Config
from .llm import LLMClient, LLMError
from .models import Niche, RunReport
from .storage import Storage


def run_niche(
    config: Config,
    storage: Storage,
    llm: LLMClient,
    niche: Niche,
    *,
    run_date: date | None = None,
    fetcher=sources.fetch,
    send: bool = True,
) -> RunReport:
    """1ニッチ・1日分を処理する。"""
    run_date = run_date or date.today()
    report = RunReport(niche=niche.code, run_date=run_date)

    existing = storage.get_issue(niche.code, run_date)
    if existing is not None:
        # 生成済みなら作り直さない。配信だけ再開できるようにする。
        report.issue = existing
        report.skipped_reason = "この日の号は生成済みのため再生成をスキップしました"
        if send:
            deliver_to_subscribers(config, storage, niche, existing, report)
        return report

    items, errors = sources.collect(
        niche,
        max_items_per_source=config.curation.max_items_per_source,
        lookback_hours=config.curation.lookback_hours,
        fetcher=fetcher,
    )
    report.errors.extend(errors)
    report.collected = len(items)

    fresh = curate.dedupe(items, storage.known_hashes(niche.code))
    report.fresh = len(fresh)
    if not fresh:
        report.skipped_reason = "新規記事が0件のため号を作成しませんでした"
        return report

    try:
        scored, score_results = curate.score_items(
            llm,
            niche,
            fresh,
            model=config.llm.scoring_model,
            batch_size=config.curation.score_batch_size,
        )
    except LLMError as exc:
        report.errors.append(f"採点に失敗: {exc}")
        return report

    report.scored = len(scored)
    scoring_cost = sum(r.cost_usd for r in score_results)

    selected = curate.select_top(
        scored, min_score=config.curation.min_score, limit=config.curation.items_per_issue
    )
    report.selected = len(selected)

    # 採点までは実施済みなので、号を出さなくても原価は必ず計上する。
    _charge(storage, niche.code, run_date, "llm:scoring", scoring_cost, report)

    if not selected:
        # 品質基準を割ったら出さない。惰性で薄い号を出すのが解約の最大要因。
        storage.save_items(fresh)
        report.skipped_reason = (
            f"スコア{config.curation.min_score}以上の記事がなかったため号を作成しませんでした"
        )
        return report

    try:
        issue, gen_result = generate.generate_issue(
            llm,
            niche,
            run_date,
            selected,
            model=config.llm.model,
            max_tokens=config.llm.max_tokens,
            effort=config.llm.effort,
        )
    except (LLMError, ValueError) as exc:
        report.errors.append(f"生成に失敗: {exc}")
        return report

    storage.save_items(fresh)
    issue = storage.save_issue(issue)
    report.issue = issue

    _charge(storage, niche.code, run_date, "llm:generation", gen_result.cost_usd, report)

    if send:
        deliver_to_subscribers(config, storage, niche, issue, report)
    return report


def deliver_to_subscribers(config: Config, storage: Storage, niche: Niche, issue, report: RunReport) -> None:
    deliverers: list[deliver.Deliverer] = []
    if config.delivery.file:
        deliverers.append(deliver.FileDeliverer(config.output_dir))
    if config.delivery.webhook_url:
        deliverers.append(deliver.WebhookDeliverer(config.delivery.webhook_url))

    result = deliver.deliver_issue(
        storage,
        issue,
        niche,
        storage.subscribers(niche.code, status="active"),
        {p.code: p for p in config.plans},
        deliverers,
    )
    report.delivered_free = result.free
    report.delivered_paid = result.paid
    report.errors.extend(result.errors)


def _charge(storage: Storage, niche_code: str, run_date: date, category: str, amount: float, report: RunReport) -> None:
    if amount <= 0:
        return
    if ledger.record_cost(
        storage,
        category=category,
        amount_usd=amount,
        ref=f"{category}:{niche_code}:{run_date.isoformat()}",
        note=f"{niche_code} {run_date.isoformat()}",
    ):
        report.cost_usd += amount


def run_daily(
    config: Config,
    storage: Storage,
    llm: LLMClient,
    *,
    run_date: date | None = None,
    niches: list[str] | None = None,
    fetcher=sources.fetch,
    send: bool = True,
) -> list[RunReport]:
    """全ニッチを回し、最後に当月の購読収益を計上する。"""
    run_date = run_date or date.today()
    targets = [n for n in config.niches if niches is None or n.code in niches]
    reports = [
        run_niche(config, storage, llm, niche, run_date=run_date, fetcher=fetcher, send=send)
        for niche in targets
    ]
    ledger.accrue_subscriptions(storage, config, on=run_date)
    return reports

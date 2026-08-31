from datetime import date

from moneyloop.models import Issue
from moneyloop.paywall import render_for_plan, render_free, render_paid


def _issue():
    return Issue(
        niche="ai-ops",
        issue_date=date(2026, 8, 29),
        title="今週の号",
        teaser_md="今週は3件を扱います。",
        body_md="## 本文\n結論はこうだ。",
        takeaways=("要点1", "要点2", "要点3"),
        item_hashes=("h1", "h2", "h3"),
    )


def test_free_version_hides_body_and_extra_takeaways(config):
    text = render_free(_issue(), config.niches[0], config.plan("pro"))
    assert "結論はこうだ" not in text
    assert "要点1" in text and "要点2" not in text
    assert "ほか2点" in text
    assert "月$30" in text


def test_paid_version_contains_everything(config):
    text = render_paid(_issue(), config.niches[0])
    assert "結論はこうだ" in text
    assert all(t in text for t in ("要点1", "要点2", "要点3"))
    assert "月$30" not in text


def test_render_for_plan_picks_variant(config):
    issue, niche = _issue(), config.niches[0]
    _, free_variant = render_for_plan(issue, niche, config.plan("free"), config.plan("pro"))
    _, paid_variant = render_for_plan(issue, niche, config.plan("pro"), config.plan("pro"))
    assert (free_variant, paid_variant) == ("free", "paid")

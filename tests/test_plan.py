from datetime import date

import pytest

from src.plan import PlanError, build_plan, load_plan, render, tokens, worksheet

RAW = {
    "domains": {"english": ["skysports.com", "espn.com"], "social": ["x.com"]},
    "tiers": {
        "確定": {"needs_sources": 1, "needs_official": True},
        "報道": {"needs_sources": 2, "needs_official": False},
        "未確認": {"needs_sources": 1, "needs_official": False},
    },
    "cadence": {"per_day": 3, "slots": ["weekly"]},
    "routines": {
        "weekly": {
            "name": "週まとめ",
            "when": "毎週土曜",
            "cover_hours": 12,
            "target_minutes": 3,
            "steps": [
                {
                    "id": "confirmed",
                    "what": "確定した移籍",
                    "tier": "確定",
                    "queries": [{"q": "confirmed transfers {period_en}", "domains": "english"}],
                    "check": "発表日を控える",
                },
                {
                    "id": "rumours",
                    "what": "噂",
                    "tier": "未確認",
                    "topics": ["選手A", "選手B"],
                    "queries": [{"q": "{topic} transfer latest", "domains": "social"}],
                },
            ],
        }
    },
}


def test_topics_expand_into_one_query_each():
    plan = build_plan(RAW)
    rumours = plan.routine("weekly").steps[1]
    assert [q.text for q in rumours.queries] == ["選手A transfer latest", "選手B transfer latest"]
    assert rumours.queries[0].domains == ["x.com"]


def test_topic_query_is_dropped_when_no_topics():
    raw = {**RAW}
    raw["routines"]["weekly"]["steps"][1]["topics"] = []
    plan = build_plan(raw)
    assert plan.routine("weekly").steps[1].queries == []
    raw["routines"]["weekly"]["steps"][1]["topics"] = ["選手A", "選手B"]  # 戻す


def test_unknown_tier_is_rejected():
    raw = {
        **RAW,
        "routines": {
            "x": {"steps": [{"id": "a", "tier": "たぶん", "queries": []}]}
        },
    }
    with pytest.raises(PlanError, match="未定義の確度"):
        build_plan(raw)


def test_unknown_routine_lists_the_known_ones():
    plan = build_plan(RAW)
    with pytest.raises(PlanError, match="weekly"):
        plan.routine("なにか")


def test_date_tokens():
    words = tokens(date(2026, 8, 29), 7)
    assert words["{date_ja}"] == "2026年8月29日"
    assert words["{period_en}"] == "August 2026"
    assert words["{today_en}"] == "29 August 2026"


def test_render_fills_dates_and_domains():
    text = render(build_plan(RAW).routine("weekly"), date(2026, 8, 29))
    assert "confirmed transfers August 2026" in text
    assert "skysports.com" in text
    assert "発表日を控える" in text


def test_worksheet_is_a_deep_dive_template():
    """1本＝1テーマなので、雛形はテーマ・問い・節で構成される。"""
    text = worksheet(build_plan(RAW).routine("weekly"), date(2026, 8, 29))
    assert "theme:" in text and "question:" in text and "answer:" in text
    assert "sections:" in text
    # structure 未定義なら既定の3節（何が起きたか／なぜ／これから）
    assert text.count("- id:") == 3


def test_worksheet_follows_the_configured_structure():
    raw = {**RAW}
    raw["routines"]["weekly"] = {
        **raw["routines"]["weekly"],
        "structure": [
            {"id": "a", "heading": "見出しA", "tier": "確定"},
            {"id": "b", "heading": "見出しB", "tier": "背景"},
        ],
    }
    text = worksheet(build_plan(raw).routine("weekly"), date(2026, 8, 29))
    assert "heading: 見出しA" in text and "tier: 背景" in text
    assert text.count("- id:") == 2
    del raw["routines"]["weekly"]["structure"]


def test_cover_hours_reads_as_a_span():
    routine = build_plan(RAW).routine("weekly")
    assert routine.cover_hours == 12
    assert routine.span == "直近12時間"


def test_cover_days_is_still_understood():
    """日単位の旧表記も時間に直して読む。"""
    raw = {**RAW}
    raw["routines"]["weekly"] = {**raw["routines"]["weekly"], "cover_hours": None,
                                 "cover_days": 3}
    del raw["routines"]["weekly"]["cover_hours"]
    routine = build_plan(raw).routine("weekly")
    assert routine.cover_hours == 72 and routine.span == "直近3日"
    raw["routines"]["weekly"]["cover_hours"] = 12  # 戻す


def test_slot_without_a_routine_is_rejected():
    raw = {**RAW, "cadence": {"slots": ["morning"]}}
    with pytest.raises(PlanError, match="morning"):
        build_plan(raw)


def test_render_lists_recent_coverage():
    from datetime import datetime

    from src.coverage import Entry

    covered = [Entry("a", "扱った話題", "morning", datetime(2026, 8, 29, 7, 0))]
    text = render(build_plan(RAW).routine("weekly"), date(2026, 8, 29), covered)
    assert "扱った話題" in text and "morning" in text


def test_bundled_plan_has_three_daily_slots():
    plan = load_plan()
    assert plan.slots == ["morning", "noon", "evening"]
    assert all(slot in plan.routines for slot in plan.slots)
    assert set(plan.tiers) >= {"確定", "報道", "未確認"}


def test_domains_map_to_their_confidence_ceiling():
    from src.plan import build_plan

    plan = build_plan(RAW)
    plan.domains = {
        "official": ["atleticodemadrid.com"],
        "english": ["skysports.com"],
        "blocked": ["bbc.com"],
    }
    plan.domain_tiers = {"official": "確定", "english": "報道"}

    assert plan.group_of("https://en.atleticodemadrid.com/noticias/x") == "official"
    assert plan.ceiling("https://en.atleticodemadrid.com/noticias/x") == "確定"
    assert plan.ceiling("https://www.skysports.com/football/news/1/2/x") == "報道"
    assert plan.ceiling("https://example.com/x") == ""


def test_blocked_domains_are_recognised_but_not_grouped():
    from src.plan import build_plan

    plan = build_plan(RAW)
    plan.domains = {"english": ["skysports.com"], "blocked": ["bbc.com"]}

    assert plan.is_blocked("https://www.bbc.com/sport/1") is True
    assert plan.group_of("https://www.bbc.com/sport/1") == ""   # blocked は群にしない
    assert plan.is_blocked("https://www.skysports.com/x") is False

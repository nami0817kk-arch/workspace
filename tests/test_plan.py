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
    "routines": {
        "weekly": {
            "name": "週まとめ",
            "when": "毎週土曜",
            "cover_days": 7,
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


def test_worksheet_has_one_entry_per_step():
    text = worksheet(build_plan(RAW).routine("weekly"), date(2026, 8, 29))
    assert text.count("- id:") == 2
    assert "tier: 確定" in text and "tier: 未確認" in text


def test_bundled_plan_loads():
    plan = load_plan()
    assert "weekly" in plan.routines
    assert set(plan.tiers) >= {"確定", "報道", "未確認"}

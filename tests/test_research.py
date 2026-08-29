import pytest

from src.plan import build_plan
from src.research import ResearchError, build_notes, load_notes, to_script, verify
from tests.test_plan import RAW

BASE = {
    "date": "2026年8月29日",
    "title": "テストのまとめ",
    "items": [
        {
            "id": "a",
            "tier": "確定",
            "headline": "移籍が決まった",
            "telop": "A → B",
            "say": "えーからびーへうつりました。",
            "official": True,
            "sources": ["https://example.com/1"],
        }
    ],
}


def _plan():
    return build_plan(RAW)


def test_valid_notes_pass():
    assert verify(build_notes(BASE), _plan()) == []


def test_report_tier_needs_two_sources():
    raw = {**BASE, "items": [{**BASE["items"][0], "tier": "報道", "official": False}]}
    problems = verify(build_notes(raw), _plan())
    assert any("出典が2本必要" in p for p in problems)


def test_confirmed_tier_needs_an_official_announcement():
    raw = {**BASE, "items": [{**BASE["items"][0], "official": False}]}
    problems = verify(build_notes(raw), _plan())
    assert any("発表が条件" in p for p in problems)


def test_missing_fields_are_reported_with_the_item_id():
    raw = {**BASE, "items": [{**BASE["items"][0], "id": "zzz", "telop": "", "say": ""}]}
    problems = verify(build_notes(raw), _plan())
    assert any(p.startswith("zzz:") and "telop" in p for p in problems)
    assert any(p.startswith("zzz:") and "say" in p for p in problems)


def test_empty_items_is_an_error():
    with pytest.raises(ResearchError, match="items が空"):
        build_notes({"date": "d", "title": "t", "items": []})


def test_sources_are_collected_without_duplicates():
    raw = {
        **BASE,
        "items": [
            BASE["items"][0],
            {**BASE["items"][0], "id": "b", "sources": ["https://example.com/1",
                                                        "https://example.com/2"]},
        ],
    }
    notes = build_notes(raw)
    assert notes.sources == ["https://example.com/1", "https://example.com/2"]


def test_to_script_refuses_notes_that_fail_verification():
    raw = {**BASE, "items": [{**BASE["items"][0], "official": False}]}
    with pytest.raises(ResearchError, match="不備"):
        to_script(build_notes(raw), _plan())


def test_generated_script_is_parseable_and_carries_the_tiers():
    from src.script_model import parse_script

    raw = {
        **BASE,
        "items": [
            BASE["items"][0],
            {
                "id": "b",
                "tier": "未確認",
                "headline": "噂の話",
                "telop": "噂です",
                "say": ["うわさです。", "かくていではありません。"],
                "sources": ["https://example.com/3"],
                "card": {"type": "points", "title": "整理", "items": ["ひとつ"]},
            },
        ],
    }
    script = parse_script(to_script(build_notes(raw), _plan()))

    assert [s.title for s in script.scenes] == [
        "オープニング", "移籍が決まった", "噂の話", "まとめ"
    ]
    assert {line.source for line in script.lines} == {None, "official", "rumor"}
    assert "b_card" in script.cards and "wrap" in script.cards
    assert len(script.sources) == 2

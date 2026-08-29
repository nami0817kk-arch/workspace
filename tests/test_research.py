from datetime import datetime, timedelta

import pytest

from src import coverage
from src.plan import build_plan
from src.research import (
    ResearchError,
    build_notes,
    check_repeats,
    to_script,
    verify,
)
from tests.test_plan import RAW

NOW = datetime(2026, 8, 29, 19, 0)


def _section(**overrides):
    base = {
        "id": "what",
        "heading": "何が起きたか",
        "tier": "確定",
        "telop": "A → B",
        "say": "えーからびーへうつりました。",
        "official": True,
        "sources": ["https://example.com/1"],
    }
    return {**base, **overrides}


def _raw(**overrides):
    base = {
        "date": "2026年8月29日",
        "slot": "evening",
        "theme": {
            "id": "move",
            "title": "なぜ移籍が決まらないのか",
            "hook": "大きな移籍が動いています。",
            "question": "なぜ金の問題ではないのか",
        },
        "answer": "ライバルに売りたくないから",
        "watch": "本人の決断",
        "sections": [
            _section(),
            _section(id="why", heading="なぜそうなったか", tier="背景", sources=[],
                     official=False),
            _section(id="next", heading="これからどうなる", tier="未確認", official=False),
        ],
    }
    return {**base, **overrides}


def _plan():
    plan = build_plan(RAW)
    plan.tiers["背景"] = {"needs_sources": 0, "needs_official": False}
    plan.policy = {"min_sections": 3, "require_question": True}
    return plan


def test_valid_notes_pass():
    assert verify(build_notes(_raw()), _plan()) == []


def test_theme_is_required():
    with pytest.raises(ResearchError, match="1本＝1テーマ"):
        build_notes({"date": "d", "sections": [_section()]})


def test_sections_are_required():
    with pytest.raises(ResearchError, match="sections が空"):
        build_notes({"theme": {"title": "t"}, "sections": []})


def test_question_is_required():
    raw = _raw()
    raw["theme"] = {**raw["theme"], "question": ""}
    problems = verify(build_notes(raw), _plan())
    assert any("question" in p for p in problems)


def test_answer_is_required():
    problems = verify(build_notes(_raw(answer="")), _plan())
    assert any("answer" in p for p in problems)


def test_too_few_sections_is_not_a_deep_dive():
    problems = verify(build_notes(_raw(sections=[_section()])), _plan())
    assert any("深掘りには3つ以上" in p for p in problems)


def test_context_tier_needs_no_sources():
    """背景の説明は新規の報道ではないので、出典を求めない。"""
    raw = _raw()
    raw["sections"][1]["sources"] = []
    assert verify(build_notes(raw), _plan()) == []


def test_report_tier_needs_two_sources():
    raw = _raw()
    raw["sections"][0] = _section(tier="報道", official=False)
    problems = verify(build_notes(raw), _plan())
    assert any("出典が2本必要" in p for p in problems)


def test_confirmed_tier_needs_an_official_announcement():
    raw = _raw()
    raw["sections"][0] = _section(official=False)
    problems = verify(build_notes(raw), _plan())
    assert any("発表が条件" in p for p in problems)


def test_problems_name_the_section():
    raw = _raw()
    raw["sections"][0] = _section(id="zzz", telop="", say="")
    problems = verify(build_notes(raw), _plan())
    assert any(p.startswith("zzz:") and "telop" in p for p in problems)


def test_sources_are_collected_without_duplicates():
    raw = _raw()
    raw["sections"][2]["sources"] = ["https://example.com/1", "https://example.com/2"]
    assert build_notes(raw).sources == ["https://example.com/1", "https://example.com/2"]


def test_to_script_refuses_notes_that_fail_verification():
    with pytest.raises(ResearchError, match="不備"):
        to_script(build_notes(_raw(answer="")), _plan())


def test_generated_script_opens_with_the_question():
    from src.script_model import parse_script

    script = parse_script(to_script(build_notes(_raw()), _plan()))
    assert [s.title for s in script.scenes] == [
        "オープニング", "何が起きたか", "なぜそうなったか", "これからどうなる", "まとめ"
    ]
    # 冒頭で問いを立て、まとめで答える
    assert any("なぜ金の問題ではないのか" in line.telop_text() for line in script.lines)
    assert any("ライバルに売りたくないから" in line.telop_text() for line in script.lines)
    assert "wrap" in script.cards


def test_generated_script_carries_the_context_tier():
    from src.script_model import parse_script

    script = parse_script(to_script(build_notes(_raw()), _plan()))
    assert "context" in {line.source for line in script.lines}


def test_repeat_is_flagged(tmp_path):
    ledger = tmp_path / "covered.yaml"
    coverage.save(
        ledger, [coverage.Entry("move", "なぜ移籍が決まらないのか", "morning",
                                NOW - timedelta(hours=6))]
    )
    plan = _plan()
    plan.coverage = {"ledger": str(ledger), "repeat_within_hours": 36}
    problems = check_repeats(build_notes(_raw()), plan, now=NOW)
    assert len(problems) == 1 and "morning" in problems[0]


def test_follow_up_is_allowed(tmp_path):
    ledger = tmp_path / "covered.yaml"
    coverage.save(
        ledger, [coverage.Entry("move", "なぜ移籍が決まらないのか", "morning",
                                NOW - timedelta(hours=6))]
    )
    plan = _plan()
    plan.coverage = {"ledger": str(ledger), "repeat_within_hours": 36}
    assert check_repeats(build_notes(_raw(follow_up=True)), plan, now=NOW) == []


def test_video_title_takes_a_prefix():
    raw = _raw()
    raw["theme"] = {**raw["theme"], "prefix": "速報"}
    assert build_notes(raw).video_title == "【速報】なぜ移籍が決まらないのか"
    assert build_notes(_raw()).video_title == "なぜ移籍が決まらないのか"


def test_breaking_prefix_without_solid_sections_is_flagged():
    """未確認だけの回に【速報】を付けると、内容と釣り合わない。"""
    from src.research import advise

    raw = _raw()
    raw["theme"] = {**raw["theme"], "prefix": "速報"}
    raw["sections"] = [
        _section(id="a", tier="未確認", official=False),
        _section(id="b", tier="未確認", official=False),
        _section(id="c", tier="未確認", official=False),
    ]
    assert any("速報" in w for w in advise(build_notes(raw)))


def test_breaking_prefix_is_fine_with_a_confirmed_section():
    from src.research import advise

    raw = _raw()
    raw["theme"] = {**raw["theme"], "prefix": "速報"}
    raw["thumbnail"] = {"line1": "短い見出し", "line2": "赤帯の文字"}
    assert advise(build_notes(raw)) == []


def test_unknown_prefix_is_flagged():
    from src.research import advise

    raw = _raw()
    raw["theme"] = {**raw["theme"], "prefix": "衝撃"}
    raw["thumbnail"] = {"line1": "短い見出し", "line2": "赤帯の文字"}
    assert any("定番ではありません" in w for w in advise(build_notes(raw)))


def test_long_thumbnail_lines_are_flagged():
    from src.research import advise

    raw = _raw(thumbnail={"line1": "あ" * 20, "line2": "い" * 25})
    hints = advise(build_notes(raw))
    assert any("line1 が長め" in w for w in hints)
    assert any("line2 が長め" in w for w in hints)


def test_thumbnail_lines_reach_the_script():
    from src.script_model import parse_script

    raw = _raw(thumbnail={"line1": "黄色帯の文字", "line2": "赤帯の文字",
                          "tags": ["反応1", "反応2"]})
    script = parse_script(to_script(build_notes(raw), _plan()))
    assert script.meta["thumbnail_line1"] == "黄色帯の文字"
    assert script.meta["thumbnail_tags"] == ["反応1", "反応2"]

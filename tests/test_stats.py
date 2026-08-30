from datetime import datetime, timedelta

from src.coverage import Entry
from src.stats import advice, bars, summarise

NOW = datetime(2026, 8, 30, 20, 0)


def _entries(*offsets_and_slots):
    return [
        Entry(key=key, headline=key, slot=slot, at=NOW - timedelta(days=days))
        for days, slot, key in offsets_and_slots
    ]


def test_counting_covers_the_window_only():
    entries = _entries((0, "morning", "a"), (3, "noon", "b"), (30, "evening", "old"))
    summary = summarise(entries, days=14, now=NOW)
    assert summary.total == 2          # 30日前は数えない
    assert summary.slots["morning"] == 1


def test_empty_days_are_counted_as_days():
    summary = summarise(_entries((0, "morning", "a")), days=5, now=NOW)
    assert len(summary.per_day) == 5
    assert summary.empty_days == 4
    assert summary.average == 1 / 5


def test_bars_show_the_shortfall_against_the_target():
    summary = summarise(_entries((0, "morning", "a"), (0, "noon", "b")), days=1, now=NOW)
    (row,) = bars(summary, target=3)
    assert "■■□" in row
    assert "2本" in row


def test_a_slot_that_hogs_the_output_is_reported():
    entries = _entries(*[(day, "morning", f"k{day}") for day in range(5)])
    summary = summarise(entries, days=5, now=NOW)
    assert any("偏っています" in note for note in advice(summary, target=1))


def test_a_repeated_theme_is_reported():
    entries = _entries((0, "morning", "alvarez"), (1, "noon", "alvarez"), (2, "evening", "alvarez"))
    summary = summarise(entries, days=5, now=NOW)
    assert any("alvarez" in note and "3回" in note for note in advice(summary, target=3))


def test_falling_short_of_the_target_is_reported():
    summary = summarise(_entries((0, "morning", "a")), days=10, now=NOW)
    notes = advice(summary, target=3)
    assert any("目標3本" in note for note in notes)
    assert any("出していない日" in note for note in notes)


def test_hitting_the_target_says_nothing():
    entries = _entries(
        *[(day, slot, f"{slot}{day}") for day in range(5) for slot in ("morning", "noon", "evening")]
    )
    summary = summarise(entries, days=5, now=NOW)
    assert advice(summary, target=3) == []


def test_an_empty_ledger_says_so():
    summary = summarise([], days=7, now=NOW)
    assert summary.total == 0
    assert any("まだ記録がありません" in note for note in advice(summary, target=3))

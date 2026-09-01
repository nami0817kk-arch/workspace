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


LEAGUES = {
    "england": {"name": "プレミアリーグ"},
    "spain": {"name": "ラ・リーガ"},
    "japan": {"name": "Jリーグ"},
}


def _entry(days, league="", kind=""):
    return Entry(key="k", headline="h", slot="morning",
                 at=NOW - timedelta(days=days), league=league, kind=kind)


def test_untouched_leagues_are_marked_as_never():
    from src.stats import gaps

    leagues, _ = gaps([_entry(0, "england", "match")], LEAGUES, now=NOW)
    by_key = {key: days for key, _, days in leagues}
    assert by_key["england"] == 0
    assert by_key["spain"] == -1        # 一度も扱っていない
    assert by_key["japan"] == -1


def test_the_longest_untouched_comes_first():
    from src.stats import gaps

    entries = [_entry(0, "england"), _entry(20, "spain")]
    leagues, _ = gaps(entries, LEAGUES, now=NOW)
    assert leagues[0][0] == "japan"     # 一度も（-1 が先頭）
    assert [key for key, _, _ in leagues][-1] == "england"


def test_kinds_are_tracked_too():
    from src.stats import gaps

    _, kinds = gaps([_entry(3, "england", "match")], LEAGUES, now=NOW)
    by_kind = dict(kinds)
    assert by_kind["match"] == 3
    assert by_kind["transfer"] == -1


def test_old_entries_without_a_league_are_ignored():
    from src.stats import gaps

    # league を記録する前の古い行があっても落ちない
    leagues, kinds = gaps([_entry(1)], LEAGUES, now=NOW)
    assert all(days == -1 for _, _, days in leagues)
    assert all(days == -1 for _, days in kinds)


def test_the_ledger_keeps_the_new_fields(tmp_path):
    from src import coverage

    ledger = tmp_path / "c.yaml"
    coverage.record(ledger, "morning", [("k", "見出し")], NOW, league="germany", kind="match")
    (entry,) = coverage.load(ledger)
    assert entry.league == "germany"
    assert entry.kind == "match"


def test_old_ledger_rows_still_load(tmp_path):
    from src import coverage

    ledger = tmp_path / "c.yaml"
    ledger.write_text(
        "covered:\n  - {key: k, headline: h, slot: morning, at: '2026-08-30T10:00'}\n",
        encoding="utf-8",
    )
    (entry,) = coverage.load(ledger)
    assert entry.league == "" and entry.kind == ""

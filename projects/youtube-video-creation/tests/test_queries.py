from datetime import datetime, timedelta

from src.queries import Run, dead, load, record, save, tally

NOW = datetime(2026, 8, 30, 6, 0)


def _runs(*rows):
    return [Run(label=label, at=NOW - timedelta(days=days), hits=hits) for label, days, hits in rows]


def test_a_run_is_recorded_including_the_zeroes(tmp_path):
    ledger = tmp_path / "q.yaml"
    record({"効く検索": 3, "効かない検索": 0}, NOW, ledger)
    runs = load(ledger)
    # 0件だった検索こそ記録したい
    assert {r.label: r.hits for r in runs} == {"効く検索": 3, "効かない検索": 0}


def test_runs_pile_up_across_days(tmp_path):
    ledger = tmp_path / "q.yaml"
    record({"検索": 1}, NOW, ledger)
    record({"検索": 2}, NOW - timedelta(days=1), ledger)
    assert len(load(ledger)) == 2


def test_the_tally_puts_the_weakest_first():
    rows = tally(_runs(("よく効く", 0, 5), ("効かない", 0, 0), ("そこそこ", 0, 2)), now=NOW)
    assert [row[0] for row in rows] == ["効かない", "そこそこ", "よく効く"]


def test_the_tally_adds_up_runs_and_hits():
    rows = tally(_runs(("検索", 0, 2), ("検索", 1, 3), ("検索", 2, 0)), now=NOW)
    assert rows == [("検索", 3, 5)]


def test_old_runs_fall_out_of_the_window():
    rows = tally(_runs(("検索", 0, 1), ("検索", 60, 99)), days=30, now=NOW)
    assert rows == [("検索", 1, 1)]


def test_a_search_that_never_returns_anything_is_named():
    rows = tally(_runs(*[("空振り", day, 0) for day in range(6)]), now=NOW)
    assert dead(rows) == ["空振り"]


def test_a_search_tried_only_a_few_times_is_left_alone():
    rows = tally(_runs(*[("まだ様子見", day, 0) for day in range(3)]), now=NOW)
    assert dead(rows) == []


def test_a_search_that_hit_once_is_not_called_dead():
    rows = tally(_runs(*[("たまに効く", day, 0) for day in range(6)], ("たまに効く", 7, 1)), now=NOW)
    assert dead(rows) == []


def test_the_ledger_survives_a_round_trip(tmp_path):
    ledger = tmp_path / "q.yaml"
    runs = _runs(("検索", 0, 2))
    save(runs, ledger)
    assert load(ledger) == runs


def test_a_missing_ledger_reads_as_empty(tmp_path):
    assert load(tmp_path / "none.yaml") == []


def test_broken_rows_are_skipped(tmp_path):
    ledger = tmp_path / "q.yaml"
    ledger.write_text(
        "runs:\n  - {label: ok, at: '2026-08-30T06:00', hits: 1}\n"
        "  - {label: bad, at: nonsense, hits: 1}\n",
        encoding="utf-8",
    )
    assert [r.label for r in load(ledger)] == ["ok"]

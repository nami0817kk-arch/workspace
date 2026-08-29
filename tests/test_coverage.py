from datetime import datetime, timedelta

from src.coverage import Entry, duplicates, load, recent, record, save

NOW = datetime(2026, 8, 29, 19, 0)


def _entries():
    return [
        Entry("suzuki", "鈴木彩艶がヴィラへ", "morning", NOW - timedelta(hours=12)),
        Entry("sano", "佐野海舟の去就", "noon", NOW - timedelta(hours=6)),
        Entry("old", "古い話題", "evening", NOW - timedelta(hours=72)),
    ]


def test_round_trip(tmp_path):
    path = tmp_path / "covered.yaml"
    save(path, _entries())
    loaded = load(path)
    assert [e.key for e in loaded] == ["suzuki", "sano", "old"]
    assert loaded[0].at == NOW - timedelta(hours=12)


def test_missing_file_is_empty(tmp_path):
    assert load(tmp_path / "none.yaml") == []


def test_broken_rows_are_skipped(tmp_path):
    path = tmp_path / "covered.yaml"
    path.write_text("covered:\n- key: a\n  at: これは日付ではない\n- key: b\n  at: 2026-08-29T10:00\n",
                    encoding="utf-8")
    assert [e.key for e in load(path)] == ["b"]


def test_duplicates_only_inside_the_window(tmp_path):
    hits = duplicates(_entries(), ["suzuki", "sano", "old"], within_hours=36, now=NOW)
    assert set(hits) == {"suzuki", "sano"}   # 72時間前の old は対象外


def test_duplicates_ignores_unlisted_keys():
    assert duplicates(_entries(), ["ほかの話題"], 36, NOW) == {}


def test_recent_is_newest_first():
    assert [e.key for e in recent(_entries(), 2)] == ["sano", "suzuki"]


def test_record_appends(tmp_path):
    path = tmp_path / "covered.yaml"
    save(path, _entries())
    record(path, "evening", [("new", "新しい話題")], now=NOW)
    assert [e.key for e in load(path)] == ["suzuki", "sano", "old", "new"]

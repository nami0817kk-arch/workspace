"""台帳（記憶と学習）のテスト。"""

from __future__ import annotations

from growth.ledger import DISMISSED, OPEN, RESOLVED, Ledger
from growth.models import Finding


def _finding(rule_id="test.missing", ref_key="app", **kw) -> Finding:
    kw.setdefault("title", "テストが無い")
    kw.setdefault("why", "w")
    kw.setdefault("action", "a")
    return Finding(rule_id=rule_id, ref_key=ref_key, **kw)


def test_fingerprint_is_stable_across_wording_changes():
    a = _finding(title="テストが無い")
    b = _finding(title="自動テストが1本もない", why="別の説明", exemplar="other")
    assert a.fingerprint == b.fingerprint


def test_fingerprint_differs_per_project_and_rule():
    assert _finding(ref_key="a").fingerprint != _finding(ref_key="b").fingerprint
    assert _finding(rule_id="ci.missing").fingerprint != _finding(rule_id="test.missing").fingerprint


def test_new_finding_is_recorded_as_open(tmp_path):
    ledger = Ledger(path=tmp_path / "l.json")
    report = ledger.reconcile([_finding()])
    assert len(report["new"]) == 1
    entry = ledger.entry(_finding().fingerprint)
    assert entry["status"] == OPEN and entry["seen_count"] == 1


def test_repeat_run_increments_seen_count_without_duplicating(tmp_path):
    ledger = Ledger(path=tmp_path / "l.json")
    ledger.reconcile([_finding()])
    report = ledger.reconcile([_finding()])
    assert report["new"] == []
    assert ledger.seen_count(_finding().fingerprint) == 2
    assert len(ledger.proposals) == 1


def test_disappearing_finding_counts_as_resolved(tmp_path):
    ledger = Ledger(path=tmp_path / "l.json")
    ledger.reconcile([_finding()])
    report = ledger.reconcile([])
    assert len(report["resolved"]) == 1
    assert ledger.entry(_finding().fingerprint)["status"] == RESOLVED
    assert ledger.rule_stats["test.missing"]["resolved"] == 1


def test_reappearing_finding_is_reported_as_regression(tmp_path):
    ledger = Ledger(path=tmp_path / "l.json")
    ledger.reconcile([_finding()])
    ledger.reconcile([])
    report = ledger.reconcile([_finding()])
    assert len(report["regressed"]) == 1
    assert ledger.entry(_finding().fingerprint)["status"] == OPEN


def test_dismissed_findings_stay_dismissed(tmp_path):
    """却下したものは、次回以降も再提案されない。"""
    ledger = Ledger(path=tmp_path / "l.json")
    ledger.reconcile([_finding()])
    ledger.mark(_finding().fingerprint, DISMISSED, note="この方針は取らない")

    ledger.reconcile([_finding()])
    entry = ledger.entry(_finding().fingerprint)
    assert entry["status"] == DISMISSED
    assert entry["note"] == "この方針は取らない"
    assert ledger.is_muted(_finding().fingerprint)


def test_dismissed_finding_is_not_marked_resolved_when_it_disappears(tmp_path):
    ledger = Ledger(path=tmp_path / "l.json")
    ledger.reconcile([_finding()])
    ledger.mark(_finding().fingerprint, DISMISSED)
    report = ledger.reconcile([])
    assert report["resolved"] == []


def test_rule_confidence_drops_as_a_rule_gets_rejected(tmp_path):
    ledger = Ledger(path=tmp_path / "l.json")
    assert ledger.rule_confidence("test.missing") == 1.0

    for i in range(4):
        f = _finding(ref_key=f"p{i}")
        ledger.reconcile([f])
        ledger.mark(f.fingerprint, DISMISSED)
    assert ledger.rule_confidence("test.missing") < 0.3


def test_rule_confidence_recovers_when_findings_get_fixed(tmp_path):
    ledger = Ledger(path=tmp_path / "l.json")
    rejected = _finding(ref_key="p0")
    ledger.reconcile([rejected])
    ledger.mark(rejected.fingerprint, DISMISSED)
    low = ledger.rule_confidence("test.missing")

    for i in range(1, 5):
        f = _finding(ref_key=f"p{i}")
        ledger.reconcile([f])
        ledger.reconcile([])
    assert ledger.rule_confidence("test.missing") > low


def test_history_keeps_one_row_per_day(tmp_path):
    ledger = Ledger(path=tmp_path / "l.json")
    ledger.record_history({"a": 10, "b": 20}, open_count=2)
    ledger.record_history({"a": 30, "b": 50}, open_count=1)
    assert len(ledger.history) == 1
    assert ledger.history[-1]["average"] == 40


def test_roundtrip_through_disk(tmp_path):
    path = tmp_path / "growth" / "l.json"
    ledger = Ledger(path=path)
    ledger.reconcile([_finding()])
    ledger.record_history({"app": 42}, open_count=1)
    ledger.attach_issue(_finding().fingerprint, "https://example.test/1")
    ledger.save()

    loaded = Ledger.load(path)
    assert loaded.entry(_finding().fingerprint)["issue_url"] == "https://example.test/1"
    assert loaded.latest_scores() == {"app": 42}


def test_marking_an_unknown_fingerprint_fails_cleanly(tmp_path):
    assert Ledger(path=tmp_path / "l.json").mark("deadbeef", DISMISSED) is False

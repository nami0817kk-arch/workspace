"""絞り込み（planner）のテスト。"""

from __future__ import annotations

from growth.ledger import DISMISSED, Ledger
from growth.models import Finding, ProjectRef, Snapshot
from growth.planner import build_plan, merge_topics, score_priority


def _finding(rule_id, ref_key="app", severity="medium", topic="", **kw) -> Finding:
    kw.setdefault("title", rule_id)
    kw.setdefault("why", "w")
    kw.setdefault("action", "a")
    return Finding(rule_id=rule_id, ref_key=ref_key, severity=severity, topic=topic, **kw)


def _snap(key="app", weight=1.0) -> Snapshot:
    return Snapshot(
        ref=ProjectRef(key=key, repo=f"owner/{key}", weight=weight),
        collected_at="2026-01-01T00:00:00+00:00",
        kind="python",
        files=["main.py"],
        signals={"has_readme": True, "has_gitignore": True},
    )


# --- 論点のマージ ---------------------------------------------------------

def test_baseline_and_crosspollination_on_one_topic_become_one_proposal():
    baseline = _finding("test.missing", severity="high", topic="tests")
    xpol = _finding("xpol.automated-tests", severity="medium", topic="tests",
                    category="crosspollination", exemplar="other", evidence=["お手本: owner/other"])
    merged = merge_topics([baseline, xpol])

    assert len(merged) == 1
    kept = merged[0]
    # 重い方（ベースライン診断）を残しつつ、お手本の情報だけ引き継ぐ
    assert kept.rule_id == "test.missing"
    assert kept.exemplar == "other"
    assert "参考: other" in kept.action


def test_merge_keeps_different_topics_separate():
    merged = merge_topics([
        _finding("test.missing", topic="tests"),
        _finding("ci.missing", topic="ci"),
    ])
    assert len(merged) == 2


def test_merge_keeps_same_topic_on_different_projects():
    merged = merge_topics([
        _finding("test.missing", ref_key="a", topic="tests"),
        _finding("test.missing", ref_key="b", topic="tests"),
    ])
    assert len(merged) == 2


def test_merge_is_order_independent():
    a = _finding("test.missing", severity="high", topic="tests")
    b = _finding("xpol.automated-tests", severity="medium", topic="tests",
                 category="crosspollination", exemplar="other")
    assert merge_topics([a, b])[0].rule_id == merge_topics([b, a])[0].rule_id


# --- 優先度 ---------------------------------------------------------------

def test_severity_drives_priority(tmp_path):
    ledger = Ledger(path=tmp_path / "l.json")
    high = score_priority(_finding("x", severity="high"), ledger, 1.0, 3)
    low = score_priority(_finding("y", severity="low"), ledger, 1.0, 3)
    assert high > low


def test_project_weight_is_applied(tmp_path):
    ledger = Ledger(path=tmp_path / "l.json")
    f = _finding("x", severity="medium")
    assert score_priority(f, ledger, 1.5, 3) > score_priority(f, ledger, 1.0, 3)


def test_repeated_unaddressed_proposal_gets_quieter(tmp_path):
    """何度言っても動かないものは、他の提案を押しのけないよう優先度を下げる。"""
    ledger = Ledger(path=tmp_path / "l.json")
    f = _finding("x", severity="high")
    fresh = score_priority(f, ledger, 1.0, 3)
    for day in range(6):
        ledger.reconcile([f])
        # 日をまたいで提示し続けた状況を作る（同じ日に何度回しても1回分）
        ledger.proposals[f.fingerprint]["last_seen_date"] = f"2026-01-{day + 1:02d}"
    assert score_priority(f, ledger, 1.0, 3) < fresh


# --- 計画づくり全体 -------------------------------------------------------

def test_per_project_cap_limits_noise(tmp_path):
    ledger = Ledger(path=tmp_path / "l.json")
    findings = [_finding(f"rule.{i}", severity="medium", topic=f"t{i}") for i in range(8)]
    plan = build_plan([_snap()], findings, ledger,
                      {"max_proposals_per_project": 2, "max_proposals_total": 50})
    assert len(plan.proposals) == 2
    assert len(plan.deferred) == 6


def test_critical_findings_bypass_the_cap(tmp_path):
    """漏らすと意味がない種類の指摘は、上限に関係なく必ず出す。"""
    ledger = Ledger(path=tmp_path / "l.json")
    findings = [_finding(f"rule.{i}", severity="medium", topic=f"t{i}") for i in range(5)]
    findings.append(_finding("secret.tracked-env-file", severity="critical", topic="secrets"))
    plan = build_plan([_snap()], findings, ledger,
                      {"max_proposals_per_project": 1, "max_proposals_total": 1})
    assert "secret.tracked-env-file" in {p.finding.rule_id for p in plan.proposals}


def test_total_cap_is_enforced_across_projects(tmp_path):
    ledger = Ledger(path=tmp_path / "l.json")
    snaps = [_snap("a"), _snap("b"), _snap("c")]
    findings = [
        _finding(f"rule.{i}", ref_key=key, topic=f"t{i}")
        for key in ("a", "b", "c") for i in range(3)
    ]
    plan = build_plan(snaps, findings, ledger,
                      {"max_proposals_per_project": 3, "max_proposals_total": 4})
    assert len(plan.proposals) == 4


def test_dismissed_findings_never_reach_the_plan(tmp_path):
    ledger = Ledger(path=tmp_path / "l.json")
    f = _finding("test.missing", severity="high", topic="tests")
    build_plan([_snap()], [f], ledger, {})
    ledger.mark(f.fingerprint, DISMISSED)

    plan = build_plan([_snap()], [f], ledger, {})
    assert plan.proposals == [] and plan.deferred == []


def test_plan_reports_resolved_and_score_delta(tmp_path):
    ledger = Ledger(path=tmp_path / "l.json")
    f = _finding("test.missing", severity="high", topic="tests")
    build_plan([_snap()], [f], ledger, {})
    # 2回目のランは別の日として履歴に積みたいので、日付を書き換えておく
    ledger.history[-1]["date"] = "2000-01-01"
    ledger.history[-1]["scores"] = {"app": 10}

    plan = build_plan([_snap()], [], ledger, {})
    assert len(plan.resolved) == 1
    assert plan.resolved[0]["project"] == "app"
    assert plan.score_delta["app"] == plan.scores["app"] - 10


def test_unavailable_projects_are_excluded_from_scores(tmp_path):
    ledger = Ledger(path=tmp_path / "l.json")
    gone = Snapshot(ref=ProjectRef(key="gone", repo="owner/gone"),
                    collected_at="", kind="unknown", unavailable=True)
    plan = build_plan([_snap(), gone], [], ledger, {})
    assert set(plan.scores) == {"app"}

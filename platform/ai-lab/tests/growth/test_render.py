"""出力整形のテスト。"""

from __future__ import annotations

from growth.ledger import Ledger
from growth.models import Finding, Proposal, ProjectRef, Snapshot
from growth.planner import build_plan
from growth.render import (
    MARKER_PREFIX,
    claude_prompt,
    issue_marker,
    render_dashboard,
    render_digest,
    render_issue,
    render_status,
    render_summary_issue,
)


def _proposal(**kw) -> Proposal:
    finding = Finding(
        rule_id=kw.pop("rule_id", "test.missing"),
        ref_key="app",
        title="自動テストが1本もない",
        why="壊れたことに気づけない",
        action="tests/test_x.py を1本書く",
        severity=kw.pop("severity", "high"),
        category="reliability",
        topic="tests",
        evidence=kw.pop("evidence", ["お手本: owner/other", "main.py"]),
        exemplar=kw.pop("exemplar", "other"),
    )
    return Proposal(finding=finding, priority=60.0, seen_count=kw.pop("seen_count", 1))


def _snap(key="app") -> Snapshot:
    return Snapshot(ref=ProjectRef(key=key, repo=f"owner/{key}"),
                    collected_at="2026-01-01T00:00:00+00:00", kind="python",
                    files=["main.py"], signals={})


def test_claude_prompt_contains_everything_needed_to_act():
    prompt = claude_prompt(_proposal(), "owner/app")
    assert "owner/app" in prompt
    assert "自動テストが1本もない" in prompt
    assert "tests/test_x.py を1本書く" in prompt
    assert "お手本: other" in prompt


def test_claude_prompt_does_not_repeat_the_exemplar_as_evidence():
    prompt = claude_prompt(_proposal(), "owner/app")
    assert "該当: main.py" in prompt
    assert "該当: お手本" not in prompt


def test_issue_body_carries_a_stable_dedupe_marker():
    proposal = _proposal()
    title, body = render_issue(proposal, "owner/app")
    assert title.startswith("[成長ループ/高]")
    assert issue_marker(proposal.fingerprint) in body
    assert MARKER_PREFIX + proposal.fingerprint in body
    assert proposal.fingerprint in body


def test_digest_lists_proposals_and_the_dismiss_command(tmp_path):
    ledger = Ledger(path=tmp_path / "l.json")
    plan = build_plan([_snap()], [_proposal().finding], ledger, {})
    text = render_digest(plan, ledger)

    assert "# 成長ループ ダイジェスト" in text
    assert "自動テストが1本もない" in text
    assert "growth dismiss" in text
    assert "| プロジェクト |" in text


def test_digest_reports_resolved_and_regressed(tmp_path):
    ledger = Ledger(path=tmp_path / "l.json")
    finding = _proposal().finding
    build_plan([_snap()], [finding], ledger, {})

    plan = build_plan([_snap()], [], ledger, {})
    assert "前回から解決したもの" in render_digest(plan, ledger)

    plan = build_plan([_snap()], [finding], ledger, {})
    assert "一度直ったのに戻ったもの" in render_digest(plan, ledger)


def test_dashboard_summarises_without_requiring_history(tmp_path):
    ledger = Ledger(path=tmp_path / "l.json")
    plan = build_plan([_snap()], [_proposal().finding], ledger, {})
    text = render_dashboard(plan, ledger)

    assert "# 成長ダッシュボード" in text
    assert "平均成熟度" in text
    assert "次にやること" in text


def test_dashboard_handles_a_clean_slate(tmp_path):
    ledger = Ledger(path=tmp_path / "l.json")
    plan = build_plan([_snap()], [], ledger, {})
    text = render_dashboard(plan, ledger)
    assert "なし。" in text


def test_status_output(tmp_path):
    ledger = Ledger(path=tmp_path / "l.json")
    assert "未対応の提案はありません" in render_status(ledger)

    proposal = _proposal()
    ledger.reconcile([proposal.finding])
    text = render_status(ledger)
    assert proposal.fingerprint in text and "app" in text


def test_summary_issue_is_self_contained_and_dated(tmp_path):
    ledger = Ledger(path=tmp_path / "l.json")
    plan = build_plan([_snap()], [_proposal().finding], ledger, {})
    marker, title, body = render_summary_issue(plan, ledger)

    assert marker.startswith(f"<!-- {MARKER_PREFIX}digest:")
    assert marker in body
    assert title.startswith("[成長ループ]")
    assert "自動テストが1本もない" in body
    assert "GROWTH.md" in body


def test_summary_issue_reports_a_quiet_week(tmp_path):
    ledger = Ledger(path=tmp_path / "l.json")
    plan = build_plan([_snap()], [], ledger, {})
    _, title, body = render_summary_issue(plan, ledger)
    assert "提案 0 件" in title
    assert "なし。" in body

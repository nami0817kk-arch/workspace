"""自動化系ルールのテスト（CI / 定期実行 / 依存）。"""

from __future__ import annotations

from growth import rules
from growth.survey import collect
from helpers import PY_APP, PY_APP2, make_repo, ref


def _ids(findings) -> set[str]:
    return {f.rule_id for f in findings}


def _snap(tmp_path, name, files, **kw):
    make_repo(tmp_path, name, files)
    return collect(tmp_path, ref(name, **kw))


def test_scheduled_workflow_without_failure_alert_is_flagged(tmp_path):
    snap = _snap(tmp_path, "cronjob", {
        "main.py": PY_APP2,
        ".github/workflows/daily.yml": "on:\n  schedule:\n    - cron: '0 7 * * 1-5'\njobs:\n  b:\n    steps:\n      - run: python main.py\n",
    })
    assert "ci.silent-failure" in _ids(rules.run_baseline([snap]))


def test_scheduled_workflow_with_a_failure_alert_is_not_flagged(tmp_path):
    """通知ステップが既にあるものを、いつまでも指摘し続けない。"""
    snap = _snap(tmp_path, "cronjob", {
        "main.py": PY_APP2,
        ".github/workflows/daily.yml": (
            "on:\n  schedule:\n    - cron: '0 7 * * 1-5'\n"
            "jobs:\n  b:\n    steps:\n      - run: python main.py\n"
            "      - name: alert\n        if: failure()\n        run: echo notify\n"
        ),
    })
    assert "ci.silent-failure" not in _ids(rules.run_baseline([snap]))


def test_unpinned_action_refs_are_flagged(tmp_path):
    snap = _snap(tmp_path, "app", {
        "main.py": PY_APP2,
        ".github/workflows/ci.yml": "jobs:\n  t:\n    steps:\n      - uses: actions/checkout@main\n",
    })
    found = [f for f in rules.run_baseline([snap]) if f.rule_id == "ci.unpinned-actions"]
    assert found and found[0].evidence == ["actions/checkout@main"]


def test_ci_without_tests_step_is_flagged(tmp_path):
    snap = _snap(tmp_path, "app", {
        "main.py": PY_APP2,
        "tests/test_a.py": "def test_a():\n    assert True\n",
        ".github/workflows/ci.yml": "jobs:\n  t:\n    steps:\n      - run: python main.py\n",
    })
    assert "ci.no-test-run" in _ids(rules.run_baseline([snap]))


def test_workflow_without_a_time_limit_is_flagged(tmp_path):
    snap = _snap(tmp_path, "app", {
        "main.py": PY_APP2,
        ".github/workflows/ci.yml": "jobs:\n  t:\n    steps:\n      - run: pytest\n",
    })
    assert "ci.no-timeout" in _ids(rules.run_baseline([snap]))


def test_workflow_with_a_time_limit_is_not_flagged(tmp_path):
    snap = _snap(tmp_path, "app", {
        "main.py": PY_APP2,
        ".github/workflows/ci.yml": "jobs:\n  t:\n    timeout-minutes: 10\n    steps:\n      - run: pytest\n",
    })
    assert "ci.no-timeout" not in _ids(rules.run_baseline([snap]))


def test_workflow_without_explicit_permissions_is_flagged(tmp_path):
    snap = _snap(tmp_path, "app", {
        "main.py": PY_APP2,
        ".github/workflows/ci.yml": "jobs:\n  t:\n    steps:\n      - run: pytest\n",
    })
    assert "ci.broad-permissions" in _ids(rules.run_baseline([snap]))

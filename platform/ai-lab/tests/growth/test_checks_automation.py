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


# --- 再利用ワークフロー呼び出し（uses:）を呼び出し側だけで見ない ---
#
# 呼び出しだけの job には timeout-minutes を書けない（GitHub が受け付けない）。
# 呼び出し側のファイルに文字列が無いことを理由に指摘すると、共通ワークフロー
# 方式を採っている全PJTで永久に誤検知が出続ける。

_CALLEE_WITH_LIMIT = (
    "on:\n  workflow_call:\n    inputs:\n      workdir:\n        type: string\n"
    "jobs:\n  pytest:\n    runs-on: ubuntu-latest\n    timeout-minutes: 15\n"
    "    steps:\n      - run: pytest\n"
)
_CALLEE_WITHOUT_LIMIT = (
    "on:\n  workflow_call:\n    inputs:\n      workdir:\n        type: string\n"
    "jobs:\n  pytest:\n    runs-on: ubuntu-latest\n    steps:\n      - run: pytest\n"
)
_CALLER = (
    "jobs:\n  pytest:\n    uses: ./.github/workflows/python-tests.yml\n"
    "    with:\n      workdir: \"app\"\n"
)


def test_reusable_call_is_not_flagged_when_the_callee_has_a_time_limit(tmp_path):
    """呼び出しだけの job は、呼び先に上限があれば指摘しない。"""
    snap = _snap(tmp_path, "app", {
        "main.py": PY_APP2,
        ".github/workflows/ci.yml": _CALLER,
        ".github/workflows/python-tests.yml": _CALLEE_WITH_LIMIT,
    })
    assert "ci.no-timeout" not in _ids(rules.run_baseline([snap]))


def test_reusable_call_is_flagged_when_the_callee_has_no_time_limit(tmp_path):
    """呼び先を辿った結果、そこにも上限が無いなら指摘する。"""
    snap = _snap(tmp_path, "app", {
        "main.py": PY_APP2,
        ".github/workflows/ci.yml": _CALLER,
        ".github/workflows/python-tests.yml": _CALLEE_WITHOUT_LIMIT,
    })
    assert "ci.no-timeout" in _ids(rules.run_baseline([snap]))


def test_reusable_call_to_another_repository_is_not_flagged(tmp_path):
    """外部リポジトリの呼び先は辿れないので、対象外として扱う。"""
    snap = _snap(tmp_path, "app", {
        "main.py": PY_APP2,
        ".github/workflows/ci.yml": "jobs:\n  pytest:\n    uses: owner/shared/.github/workflows/t.yml@v1\n",
    })
    assert "ci.no-timeout" not in _ids(rules.run_baseline([snap]))


def test_a_normal_job_without_a_time_limit_is_still_flagged(tmp_path):
    """通常の job（runs-on と steps を持つ）は従来どおり指摘する。"""
    snap = _snap(tmp_path, "app", {
        "main.py": PY_APP2,
        ".github/workflows/ci.yml": (
            "jobs:\n  t:\n    runs-on: ubuntu-latest\n"
            "    steps:\n      - uses: actions/checkout@v7\n      - run: pytest\n"
        ),
    })
    assert "ci.no-timeout" in _ids(rules.run_baseline([snap]))


def test_a_workflow_mixing_a_reusable_call_and_a_bare_job_is_flagged(tmp_path):
    """呼び出し job が免除でも、同じファイルの通常 job は見逃さない。"""
    snap = _snap(tmp_path, "app", {
        "main.py": PY_APP2,
        ".github/workflows/ci.yml": (
            _CALLER + "  lint:\n    runs-on: ubuntu-latest\n    steps:\n      - run: ruff check .\n"
        ),
        ".github/workflows/python-tests.yml": _CALLEE_WITH_LIMIT,
    })
    assert "ci.no-timeout" in _ids(rules.run_baseline([snap]))

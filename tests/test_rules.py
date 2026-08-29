"""ルールと横展開のテスト。"""

from __future__ import annotations

from growth import rules
from growth.survey import collect
from helpers import PY_APP, PY_APP2, make_repo, ref


def _ids(findings) -> set[str]:
    return {f.rule_id for f in findings}


def _snap(tmp_path, name, files, **kw):
    make_repo(tmp_path, name, files)
    return collect(tmp_path, ref(name, **kw))


def test_bare_python_project_gets_the_expected_findings(tmp_path):
    snap = _snap(tmp_path, "app", {"main.py": PY_APP, "util.py": PY_APP2})
    ids = _ids(rules.run_baseline([snap]))
    assert {"test.missing", "ci.missing", "deps.undeclared",
            "docs.readme-missing", "env.no-example", "secret.gitignore-env"} <= ids


def test_healthy_project_produces_no_baseline_findings(tmp_path):
    snap = _snap(tmp_path, "good", {
        "README.md": "# good\n## 使い方\n```bash\npytest\n```\n",
        "main.py": PY_APP2,
        "util.py": PY_APP2,
        "requirements.txt": "requests==2.31.0\n",
        ".gitignore": ".env\n",
        "tests/test_a.py": "def test_a():\n    assert True\n",
        ".github/workflows/ci.yml": "jobs:\n  t:\n    steps:\n      - uses: actions/checkout@v4\n      - run: pytest\n",
        ".github/dependabot.yml": "version: 2\n",
    })
    assert _ids(rules.run_baseline([snap])) == set()


def test_tracked_env_file_is_critical(tmp_path):
    snap = _snap(tmp_path, "leaky", {".env": "TOKEN=x\n", "main.py": PY_APP2})
    found = [f for f in rules.run_baseline([snap]) if f.rule_id == "secret.tracked-env-file"]
    assert found and found[0].severity == "critical"
    assert found[0].evidence == [".env"]


def test_scheduled_workflow_without_failure_alert_is_flagged(tmp_path):
    snap = _snap(tmp_path, "cronjob", {
        "main.py": PY_APP2,
        ".github/workflows/daily.yml": "on:\n  schedule:\n    - cron: '0 7 * * 1-5'\njobs:\n  b:\n    steps:\n      - run: python main.py\n",
    })
    assert "ci.silent-failure" in _ids(rules.run_baseline([snap]))


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


def test_empty_scaffold_is_nudged_but_not_over_reported(tmp_path):
    snap = _snap(tmp_path, "empty", {"README.md": "# x\n", "src/.gitkeep": ""})
    ids = _ids(rules.run_baseline([snap]))
    assert "scaffold.dormant" in ids
    # 中身が無いのに「テストを書け」「CIを作れ」とは言わない
    assert "test.missing" not in ids and "ci.missing" not in ids


# --- 横展開 ---------------------------------------------------------------

def test_crosspollination_needs_an_exemplar(tmp_path):
    """誰もやっていない習慣については何も言わない。"""
    a = _snap(tmp_path, "a", {"main.py": PY_APP2, "b.py": PY_APP2})
    b = _snap(tmp_path, "b", {"main.py": PY_APP2, "b.py": PY_APP2})
    assert not [f for f in rules.run_crosspollination([a, b]) if f.rule_id == "xpol.claude-md"]


def test_practice_is_carried_to_projects_that_lack_it(tmp_path):
    a = _snap(tmp_path, "a", {"main.py": PY_APP2, "b.py": PY_APP2, "CLAUDE.md": "# ctx\n"})
    b = _snap(tmp_path, "b", {"main.py": PY_APP2, "b.py": PY_APP2})
    found = [f for f in rules.run_crosspollination([a, b]) if f.rule_id == "xpol.claude-md"]
    assert len(found) == 1
    assert found[0].ref_key == "b"
    assert found[0].exemplar == "a"
    assert found[0].category == "crosspollination"


def test_exemplar_is_never_told_to_copy_itself(tmp_path):
    a = _snap(tmp_path, "a", {"main.py": PY_APP2, "b.py": PY_APP2, "CLAUDE.md": "# ctx\n"})
    found = rules.run_crosspollination([a])
    assert [f for f in found if f.ref_key == "a" and f.rule_id == "xpol.claude-md"] == []


def test_practice_respects_project_kind(tmp_path):
    """.env.example は Python/Node 向け。Flutter には持ち込まない。"""
    a = _snap(tmp_path, "a", {"main.py": PY_APP2, "b.py": PY_APP2, ".env.example": "TOKEN=\n"})
    flutter = _snap(tmp_path, "f", {"pubspec.yaml": "name: f\n", "lib/main.dart": "void main() {}\n"})
    targets = {f.ref_key for f in rules.run_crosspollination([a, flutter]) if f.rule_id == "xpol.env-example"}
    assert "f" not in targets


def test_inactive_projects_are_skipped(tmp_path):
    snap = _snap(tmp_path, "app", {"main.py": PY_APP, "util.py": PY_APP2}, active=False)
    assert rules.run_all([snap]) == []


def test_every_registered_rule_has_a_unique_id():
    ids = rules.registered_rule_ids()
    assert len(ids) == len(set(ids))


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


def test_practice_is_not_pushed_where_it_would_be_meaningless(tmp_path):
    """依存を1つも持たないPJTに「バージョンを固定しろ」とは言わない。"""
    pinned = _snap(tmp_path, "pinned", {
        "main.py": PY_APP2, "b.py": PY_APP2,
        "requirements.txt": "requests==2.31.0\nlxml==5.0.0\n",
    })
    no_deps = _snap(tmp_path, "nodeps", {"main.py": PY_APP2, "b.py": PY_APP2})
    loose = _snap(tmp_path, "loose", {
        "main.py": PY_APP2, "b.py": PY_APP2,
        "requirements.txt": "requests>=2.31.0\nlxml>=5.0.0\n",
    })

    targets = {
        f.ref_key for f in rules.run_crosspollination([pinned, no_deps, loose])
        if f.rule_id == "xpol.pinned-deps"
    }
    assert targets == {"loose"}          # 緩い固定のPJTにだけ伝える
    assert "nodeps" not in targets       # 固定すべき依存が無いPJTには言わない


def test_baseline_and_crosspollination_are_both_reachable_from_rules(tmp_path):
    """モジュールを分けても、まとめて走らせる入口は1つに保つ。"""
    a = _snap(tmp_path, "a", {"main.py": PY_APP2, "b.py": PY_APP2, "CLAUDE.md": "# ctx\n"})
    b = _snap(tmp_path, "b", {"main.py": PY_APP2, "b.py": PY_APP2})
    ids = _ids(rules.run_all([a, b]))
    assert "test.missing" in ids           # ベースライン診断
    assert "xpol.claude-md" in ids         # 横展開

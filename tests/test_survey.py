"""観測（survey）のテスト。"""

from __future__ import annotations

from growth.survey import collect, maturity_score, walk_files
from helpers import PY_APP, PY_APP2, make_repo, ref


def test_walk_files_skips_noise_dirs(tmp_path):
    make_repo(tmp_path, "app", {
        "main.py": "x = 1\n",
        ".venv/lib/junk.py": "x = 1\n",
        "node_modules/pkg/index.js": "x\n",
        "output/build.html": "<p></p>",
    })
    assert walk_files(tmp_path / "app") == ["main.py"]


def test_walk_files_honours_exclude(tmp_path):
    make_repo(tmp_path, "mono", {
        "CLAUDE.md": "# ws\n",
        "projects/a/main.py": "x = 1\n",
    })
    assert walk_files(tmp_path / "mono", exclude=("projects/a",)) == ["CLAUDE.md"]


def test_detects_python_project_signals(tmp_path):
    make_repo(tmp_path, "app", {
        "README.md": "# app\n\n## 使い方\n\n```bash\npython main.py\n```\n",
        "main.py": PY_APP,
        "src/util.py": PY_APP2,
        "requirements.txt": "requests==2.31.0\nlxml==5.0.0\n",
        ".gitignore": ".env\n",
        "tests/test_util.py": "def test_x():\n    assert True\n",
    })
    snap = collect(tmp_path, ref("app"))

    assert snap.kind == "python"
    assert snap.has("has_readme") and snap.has("readme_has_runbook")
    assert snap.has("has_tests") and snap.get("test_file_count") == 1
    assert snap.has("uses_env_vars")
    assert snap.has("gitignore_covers_env")
    assert snap.get("pinned_ratio") == 1.0


def test_unpinned_dependencies_are_measured(tmp_path):
    make_repo(tmp_path, "app", {
        "main.py": PY_APP2,
        "requirements.txt": "# comment\nrequests>=2.31.0\nlxml>=5.0.0\npandas==2.0.0\n",
    })
    snap = collect(tmp_path, ref("app"))
    assert snap.get("dependency_count") == 3
    assert snap.get("pinned_ratio") == round(1 / 3, 3)


def test_scaffold_is_recognised(tmp_path):
    make_repo(tmp_path, "empty", {
        "README.md": "# empty\n",
        "src/.gitkeep": "",
        "tests/.gitkeep": "",
    })
    snap = collect(tmp_path, ref("empty"))
    assert snap.kind == "scaffold"
    assert snap.has("has_empty_test_dir")
    assert maturity_score(snap) == 15


def test_missing_clone_is_marked_unavailable(tmp_path):
    snap = collect(tmp_path, ref("nope"))
    assert snap.unavailable
    assert maturity_score(snap) == 0


def test_tracked_env_file_and_hardcoded_secret(tmp_path):
    make_repo(tmp_path, "leaky", {
        ".env": "TOKEN=abc\n",
        "main.py": 'API_KEY = "sk_live_0123456789abcdefghij"\n',
    })
    snap = collect(tmp_path, ref("leaky"))
    assert snap.get("tracked_env_file") == [".env"]
    assert snap.get("hardcoded_secret_files") == ["main.py"]


def test_subproject_only_counts_workflows_that_mention_it(tmp_path):
    make_repo(tmp_path, "mono", {
        ".github/workflows/web.yml": "on: push\njobs:\n  a:\n    steps:\n      - run: cd projects/b && flutter test\n",
        ".github/workflows/nightly.yml": "on:\n  schedule:\n    - cron: '0 7 * * *'\n",
        "projects/a/main.py": PY_APP2,
        "projects/b/lib/main.dart": "void main() {}\n",
        "projects/b/pubspec.yaml": "name: b\n",
    })
    a = collect(tmp_path, ref("mono", "projects/a", key="mono/a"))
    b = collect(tmp_path, ref("mono", "projects/b", key="mono/b"))

    # a を扱うワークフローは無いので CI 無し扱い
    assert not a.has("has_ci")
    # b は web.yml に登場するので CI あり、かつテストも走っている
    assert b.has("has_ci") and b.has("ci_runs_tests")
    # 別ワークフローの cron を b の定期実行と誤認しない
    assert not b.has("has_scheduled_workflow")


def test_oversized_files_are_reported(tmp_path):
    make_repo(tmp_path, "big", {"huge.py": "x = 1\n" * 500, "small.py": "y = 2\n"})
    snap = collect(tmp_path, ref("big"))
    assert len(snap.get("oversized_files")) == 1
    assert snap.get("oversized_files")[0].startswith("huge.py")


def test_maturity_score_rises_with_practices(tmp_path):
    bare = make_repo(tmp_path, "bare", {"main.py": PY_APP2, "other.py": PY_APP2})
    good = make_repo(tmp_path, "good", {
        "main.py": PY_APP2,
        "other.py": PY_APP2,
        "README.md": "# good\n## 使い方\n```bash\nrun\n```\n",
        "requirements.txt": "requests==2.31.0\n",
        ".gitignore": ".env\n",
        "CLAUDE.md": "# ctx\n",
        "tests/test_a.py": "def test_a():\n    assert True\n",
        ".github/workflows/ci.yml": "jobs:\n  t:\n    steps:\n      - run: pytest\n",
    })
    assert good.exists() and bare.exists()
    low = maturity_score(collect(tmp_path, ref("bare")))
    high = maturity_score(collect(tmp_path, ref("good")))
    assert low < 40 < high


def test_dummy_secrets_in_test_code_are_not_flagged(tmp_path):
    """テストのダミー鍵で鳴ると、本物の指摘まで信用されなくなる。"""
    make_repo(tmp_path, "app", {
        "main.py": PY_APP2,
        "tests/test_auth.py": 'API_KEY = "sk_live_0123456789abcdefghij"\n',
        "conftest.py": 'TOKEN = "abcdefghijklmnopqrstuvwx"\n',
    })
    snap = collect(tmp_path, ref("app"))
    assert snap.get("hardcoded_secret_files") == []


def test_real_hardcoded_secret_outside_tests_is_still_flagged(tmp_path):
    make_repo(tmp_path, "app", {
        "client.py": 'API_KEY = "sk_live_0123456789abcdefghij"\n',
        "tests/test_a.py": "def test_a():\n    assert True\n",
    })
    snap = collect(tmp_path, ref("app"))
    assert snap.get("hardcoded_secret_files") == ["client.py"]


def test_failure_alert_in_workflow_is_detected(tmp_path):
    make_repo(tmp_path, "app", {
        "main.py": PY_APP2,
        ".github/workflows/daily.yml": "on:\n  schedule:\n    - cron: '0 7 * * *'\njobs:\n  b:\n    steps:\n      - if: failure()\n        run: echo alert\n",
    })
    snap = collect(tmp_path, ref("app"))
    assert snap.has("has_scheduled_workflow") and snap.has("has_failure_alert")


def test_long_test_files_are_not_counted_as_oversized(tmp_path):
    """テストが増えて長くなることを欠陥として数えない。"""
    make_repo(tmp_path, "app", {
        "main.py": PY_APP2,
        "tests/test_all.py": "def test_x():\n    assert True\n" * 300,
    })
    snap = collect(tmp_path, ref("app"))
    assert snap.get("oversized_files") == []

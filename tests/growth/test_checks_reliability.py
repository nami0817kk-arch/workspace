"""動作の確からしさ系ルールのテスト（秘密情報 / テスト / 例外 / 構造）。"""

from __future__ import annotations

from growth import rules
from growth.survey import collect
from helpers import PY_APP, PY_APP2, make_repo, ref


def _ids(findings) -> set[str]:
    return {f.rule_id for f in findings}


def _snap(tmp_path, name, files, **kw):
    make_repo(tmp_path, name, files)
    return collect(tmp_path, ref(name, **kw))


def test_tracked_env_file_is_critical(tmp_path):
    snap = _snap(tmp_path, "leaky", {".env": "TOKEN=x\n", "main.py": PY_APP2})
    found = [f for f in rules.run_baseline([snap]) if f.rule_id == "secret.tracked-env-file"]
    assert found and found[0].severity == "critical"
    assert found[0].evidence == [".env"]


def test_empty_scaffold_is_nudged_but_not_over_reported(tmp_path):
    snap = _snap(tmp_path, "empty", {"README.md": "# x\n", "src/.gitkeep": ""})
    ids = _ids(rules.run_baseline([snap]))
    assert "scaffold.dormant" in ids
    # 中身が無いのに「テストを書け」「CIを作れ」とは言わない
    assert "test.missing" not in ids and "ci.missing" not in ids


# --- 横展開 ---------------------------------------------------------------


def test_swallowed_exception_is_found_across_multiple_lines(tmp_path):
    """正規表現では見落とす複数行の except 本体も、構文木なら拾える。"""
    snap = _snap(tmp_path, "app", {
        "main.py": (
            "def a():\n    try:\n        risky()\n    except Exception:\n        pass\n\n"
            "def b():\n    try:\n        risky()\n    except Exception:\n        print('log')\n"
        ),
        "util.py": PY_APP2,
    })
    found = [f for f in rules.run_baseline([snap]) if f.rule_id == "quality.swallowed-exception"]
    assert found and found[0].evidence == ["main.py:4"]   # b() は握りつぶしていない


def test_swallowed_exception_in_tests_is_ignored(tmp_path):
    snap = _snap(tmp_path, "app", {
        "main.py": PY_APP2,
        "tests/test_a.py": "try:\n    x()\nexcept Exception:\n    pass\n",
    })
    assert "quality.swallowed-exception" not in _ids(rules.run_baseline([snap]))


def test_bare_except_is_reported_separately(tmp_path):
    snap = _snap(tmp_path, "app", {
        "main.py": "try:\n    x()\nexcept:\n    print('oops')\n",
        "util.py": PY_APP2,
    })
    ids = _ids(rules.run_baseline([snap]))
    assert "quality.bare-except" in ids
    # 本体が pass ではないので握りつぶしとしては数えない
    assert "quality.swallowed-exception" not in ids


def test_syntax_error_does_not_break_the_scan(tmp_path):
    snap = _snap(tmp_path, "app", {"broken.py": "def (:\n", "util.py": PY_APP2})
    assert snap.get("swallowed_exceptions") == []


def test_continue_only_except_counts_as_swallowing(tmp_path):
    """`except: continue` も、失敗を黙って飛ばしている点では pass と同じ。"""
    snap = _snap(tmp_path, "app", {
        "main.py": (
            "def run(items):\n"
            "    for i in items:\n"
            "        try:\n"
            "            work(i)\n"
            "        except Exception:\n"
            "            continue\n"
        ),
        "util.py": PY_APP2,
    })
    assert snap.get("swallowed_exceptions") == ["main.py:5"]
    assert "quality.swallowed-exception" in _ids(rules.run_baseline([snap]))


def test_except_that_logs_before_continuing_is_not_flagged(tmp_path):
    snap = _snap(tmp_path, "app", {
        "main.py": (
            "def run(items):\n"
            "    for i in items:\n"
            "        try:\n"
            "            work(i)\n"
            "        except Exception as e:\n"
            "            print(e)\n"
            "            continue\n"
        ),
        "util.py": PY_APP2,
    })
    assert snap.get("swallowed_exceptions") == []


def test_narrow_except_that_skips_a_row_is_not_flagged(tmp_path):
    """`except (IndexError, ValueError): continue` は行スキップの意図表明。

    表の解析ループなどで正当に使われるので、ここで鳴らすと
    「握りつぶし」の指摘そのものが信用されなくなる。
    """
    snap = _snap(tmp_path, "app", {
        "main.py": (
            "def parse(rows):\n"
            "    for r in rows:\n"
            "        try:\n"
            "            use(r[0])\n"
            "        except (IndexError, ValueError):\n"
            "            continue\n"
        ),
        "util.py": PY_APP2,
    })
    assert snap.get("swallowed_exceptions") == []


def test_broad_except_that_skips_is_still_flagged(tmp_path):
    snap = _snap(tmp_path, "app", {
        "main.py": (
            "def parse(rows):\n"
            "    for r in rows:\n"
            "        try:\n"
            "            use(r[0])\n"
            "        except Exception:\n"
            "            continue\n"
        ),
        "util.py": PY_APP2,
    })
    assert snap.get("swallowed_exceptions") == ["main.py:5"]


def test_long_function_names_the_place_to_fix(tmp_path):
    body = "\n".join(f"    x{i} = {i}" for i in range(120))
    snap = _snap(tmp_path, "app", {
        "main.py": f"def big():\n{body}\n\n\ndef small():\n    return 1\n",
        "util.py": PY_APP2,
    })
    found = [f for f in rules.run_baseline([snap]) if f.rule_id == "quality.long-function"]
    assert found
    assert found[0].evidence[0].startswith("main.py:1 big()")
    assert "small" not in " ".join(found[0].evidence)


def test_long_functions_in_tests_are_ignored(tmp_path):
    body = "\n".join(f"    x{i} = {i}" for i in range(120))
    snap = _snap(tmp_path, "app", {
        "main.py": PY_APP2,
        "util.py": PY_APP2,
        "tests/test_big.py": f"def test_big():\n{body}\n",
    })
    assert "quality.long-function" not in _ids(rules.run_baseline([snap]))


def test_long_function_outranks_file_size_for_the_same_project(tmp_path):
    """同じ「構造」の論点は1件にまとまり、直す場所を名指しできる側が残る。"""
    from growth.planner import merge_topics

    body = "\n".join(f"    x{i} = {i}" for i in range(120))
    snap = _snap(tmp_path, "app", {
        "main.py": f"def big():\n{body}\n" + "# pad\n" * 400,
        "util.py": PY_APP2,
    })
    merged = merge_topics(rules.run_baseline([snap]))
    structure = [f for f in merged if f.topic == "structure"]
    assert len(structure) == 1
    assert structure[0].rule_id == "quality.long-function"

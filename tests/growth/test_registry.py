"""レジストリ読み込みとモノレポ展開のテスト。"""

from __future__ import annotations

from growth.registry import expand_subprojects, load_registry, repo_names
from helpers import make_repo

TOML = """
[config]
max_proposals_total = 5

[[project]]
repo = "owner/solo"
title = "単体"

[[project]]
key = "mono"
repo = "owner/mono"
weight = 2.0
subprojects = ["projects/*"]
"""


def _registry(tmp_path):
    path = tmp_path / "projects.toml"
    path.write_text(TOML, encoding="utf-8")
    return path


def test_load_registry_reads_config_and_defaults_the_key(tmp_path):
    refs, config = load_registry(_registry(tmp_path))
    assert config["max_proposals_total"] == 5
    assert [r.key for r in refs] == ["solo", "mono"]
    assert refs[0].path == "." and refs[0].title == "単体"


def test_subprojects_are_discovered_from_disk(tmp_path):
    ws = tmp_path / "ws"
    make_repo(ws, "mono", {
        "CLAUDE.md": "# ws\n",
        "projects/PJT001/main.py": "x = 1\n",
        "projects/PJT002/README.md": "# b\n",
    })
    refs, _ = load_registry(_registry(tmp_path))
    expanded = expand_subprojects(refs, ws, _registry(tmp_path))

    keys = [r.key for r in expanded]
    assert keys == ["solo", "mono", "mono/projects/PJT001", "mono/projects/PJT002"]
    child = next(r for r in expanded if r.key == "mono/projects/PJT001")
    assert child.repo == "owner/mono" and child.path == "projects/PJT001"
    # 親の重みは子にも引き継ぐ
    assert child.weight == 2.0


def test_parent_excludes_its_children_and_becomes_a_monorepo(tmp_path):
    ws = tmp_path / "ws"
    make_repo(ws, "mono", {"projects/PJT001/main.py": "x = 1\n"})
    refs, _ = load_registry(_registry(tmp_path))
    parent = next(r for r in expand_subprojects(refs, ws, _registry(tmp_path)) if r.key == "mono")
    assert parent.exclude == ("projects/PJT001",)
    assert parent.kind == "monorepo"


def test_missing_clone_yields_no_children(tmp_path):
    refs, _ = load_registry(_registry(tmp_path))
    expanded = expand_subprojects(refs, tmp_path / "empty-ws", _registry(tmp_path))
    assert [r.key for r in expanded] == ["solo", "mono"]


def test_repo_names_are_deduplicated(tmp_path):
    ws = tmp_path / "ws"
    make_repo(ws, "mono", {"projects/a/main.py": "x\n", "projects/b/main.py": "x\n"})
    refs, _ = load_registry(_registry(tmp_path))
    expanded = expand_subprojects(refs, ws, _registry(tmp_path))
    assert repo_names(expanded) == ["owner/solo", "owner/mono"]

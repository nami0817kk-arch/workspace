"""ドキュメント系ルールのテスト（README / ライセンス / 体裁 / 参照）。"""

from __future__ import annotations

from growth import rules
from growth.survey import collect
from helpers import PY_APP, PY_APP2, make_repo, ref


def _ids(findings) -> set[str]:
    return {f.rule_id for f in findings}


def _snap(tmp_path, name, files, **kw):
    make_repo(tmp_path, name, files)
    return collect(tmp_path, ref(name, **kw))


def test_license_is_only_required_for_repositories_tagged_public(tmp_path):
    private = _snap(tmp_path, "priv", {"main.py": PY_APP2, "util.py": PY_APP2})
    make_repo(tmp_path, "pub", {"main.py": PY_APP2, "util.py": PY_APP2})
    public = collect(tmp_path, ref("pub", tags=("public",)))

    assert "legal.no-license" not in _ids(rules.run_baseline([private]))
    assert "legal.no-license" in _ids(rules.run_baseline([public]))


def test_license_present_clears_the_finding(tmp_path):
    make_repo(tmp_path, "pub", {"main.py": PY_APP2, "util.py": PY_APP2, "LICENSE": "MIT\n"})
    snap = collect(tmp_path, ref("pub", tags=("public",)))
    assert "legal.no-license" not in _ids(rules.run_baseline([snap]))


def test_byte_order_mark_is_detected(tmp_path):
    root = make_repo(tmp_path, "app", {"main.py": PY_APP2})
    (root / "README.md").write_bytes("\ufeff# タイトル\n".encode("utf-8"))
    snap = collect(tmp_path, ref("app"))
    assert snap.get("bom_files") == ["README.md"]
    assert "docs.bom" in _ids(rules.run_baseline([snap]))


def test_broken_relative_links_are_found_but_urls_are_left_alone(tmp_path):
    snap = _snap(tmp_path, "app", {
        "main.py": PY_APP2,
        "guide.md": "[ある](main.py) [ない](nope.md) [外部](https://example.test) [見出し](#x)\n",
    })
    assert snap.get("broken_links") == ["guide.md -> nope.md"]
    assert "docs.broken-link" in _ids(rules.run_baseline([snap]))


def test_stale_reference_only_matches_real_paths(tmp_path):
    """裸のファイル名は文中の言及なので拾わない。拾うと誤検知だらけになる。"""
    snap = _snap(tmp_path, "app", {
        "main.py": PY_APP2,
        "util.py": PY_APP2,
        "README.md": (
            "構成は `src/gone/missing.py` にある。\n"
            "`main.py` を編集する。\n"           # 実在するので対象外
            "`rules.py` の話をしている。\n"       # 区切りが無い＝言及。拾わない
        ),
    })
    assert snap.get("stale_references") == ["README.md -> src/gone/missing.py"]
    assert "docs.stale-reference" in _ids(rules.run_baseline([snap]))


def test_subproject_docs_may_reference_repository_level_paths(tmp_path):
    """子PJTのREADMEから .github/ を指しても誤検知しないこと。"""
    make_repo(tmp_path, "mono", {
        ".github/workflows/ci.yml": "on: push\n",
        "projects/a/main.py": PY_APP2,
        "projects/a/README.md": "デプロイは `.github/workflows/ci.yml` が行う。\n",
    })
    snap = collect(tmp_path, ref("mono", "projects/a", key="mono/a"))
    assert snap.get("stale_references") == []

"""決まりと実装の突き合わせ（2026-09-13）。

2026-09-07 に決めた「報道の出典は1社でよい」が config に反映されず、
5日間ズレたまま動いていた。人が見比べ続けるのは無理なので機械に任せる。
"""

from pathlib import Path

from src import rules


def _write(tmp_path: Path, doc: str, yaml_text: str = "") -> Path:
    (tmp_path / "CLAUDE.md").write_text(doc, encoding="utf-8")
    if yaml_text:
        (tmp_path / "config").mkdir(exist_ok=True)
        (tmp_path / "config" / "sources.yaml").write_text(yaml_text, encoding="utf-8")
    return tmp_path


def test_marks_are_picked_up():
    got = rules.marks("前置き\n<!-- 突き合わせ: config/sources.yaml tiers.報道.needs_sources = 1 -->\n続き")
    assert got == [("config/sources.yaml", "tiers.報道.needs_sources", "1")]


def test_matching_value_is_not_reported(tmp_path):
    root = _write(tmp_path,
                  "<!-- 突き合わせ: config/sources.yaml tiers.報道.needs_sources = 1 -->",
                  "tiers:\n  報道:\n    needs_sources: 1\n")
    assert rules.check(root) == []


def test_mismatch_is_reported(tmp_path):
    """**これが本番で起きた形。**決まりは1、config は2のまま。"""
    root = _write(tmp_path,
                  "<!-- 突き合わせ: config/sources.yaml tiers.報道.needs_sources = 1 -->",
                  "tiers:\n  報道:\n    needs_sources: 2\n")
    gaps = rules.check(root)
    assert len(gaps) == 1
    assert "1" in gaps[0].wanted and "2" in gaps[0].found


def test_missing_name_is_reported(tmp_path):
    root = _write(tmp_path,
                  "<!-- 突き合わせ: config/sources.yaml tiers.報道.needs_sources = 1 -->",
                  "tiers:\n  報道:\n    needs_official: false\n")
    assert "その名前がありません" in rules.check(root)[0].note


def test_python_constant_is_read():
    """実際の CLAUDE.md と src を突き合わせて、食い違いが無いこと。"""
    assert rules.counted() > 0
    assert rules.check() == []

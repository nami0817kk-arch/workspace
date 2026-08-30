import json

import pytest

from src.review import built_duration, inspect, manual_checks
from src.script_model import parse_script

BODY = (
    "---\ntitle: T\nsources: [https://example.com/a]\n---\n\n"
    "## 章1\n\nキャスター: いちぎょうめ。\n  source: 確定\n\n"
    "## 章2\n\nキャスター: にぎょうめ。\n  source: 報道\n"
)


def _built(tmp_path, seconds=150.0):
    for name in ("video.mp4", "thumbnail.png", "subtitles.srt"):
        (tmp_path / name).write_bytes(b"x")
    (tmp_path / "description.txt").write_text("概要", encoding="utf-8")
    (tmp_path / "script.json").write_text(
        json.dumps({"scenes": [{"lines": [{"start": seconds - 10, "duration": 10}]}]}),
        encoding="utf-8",
    )
    return tmp_path


def _by_label(findings):
    return {f.label: f for f in findings}


def test_a_finished_build_passes_everything(tmp_path):
    findings = inspect(parse_script(BODY), _built(tmp_path), 150.0)
    assert all(f.ok for f in findings), [f.line() for f in findings if not f.ok]


def test_missing_files_are_named(tmp_path):
    (tmp_path / "video.mp4").write_bytes(b"x")
    result = _by_label(inspect(parse_script(BODY), tmp_path))
    assert result["書き出し"].ok is False
    assert "thumbnail.png" in result["書き出し"].detail
    assert "video.mp4" not in result["書き出し"].detail


def test_a_script_without_sources_fails(tmp_path):
    body = BODY.replace("sources: [https://example.com/a]\n", "")
    result = _by_label(inspect(parse_script(body), _built(tmp_path)))
    assert result["出典"].ok is False


def test_a_script_without_any_tier_fails(tmp_path):
    body = BODY.replace("  source: 確定\n", "").replace("  source: 報道\n", "")
    result = _by_label(inspect(parse_script(body), _built(tmp_path)))
    assert result["確度"].ok is False


def test_a_single_chapter_fails(tmp_path):
    body = "---\ntitle: T\nsources: [https://example.com/a]\n---\n\n## 章1\n\nキャスター: あ。\n  source: 確定\n"
    result = _by_label(inspect(parse_script(body), _built(tmp_path)))
    assert result["チャプター"].ok is False


@pytest.mark.parametrize(
    "seconds, ok",
    [(60.0, False), (95.0, True), (150.0, True), (235.0, True), (300.0, False)],
)
def test_the_length_has_a_floor_and_a_ceiling(tmp_path, seconds, ok):
    result = _by_label(inspect(parse_script(BODY), _built(tmp_path), seconds))
    assert result["尺"].ok is ok


def test_the_length_is_skipped_before_a_build(tmp_path):
    labels = [f.label for f in inspect(parse_script(BODY), tmp_path, None)]
    assert "尺" not in labels


def test_an_over_long_title_fails(tmp_path):
    body = BODY.replace("title: T", "title: " + "あ" * 120)
    result = _by_label(inspect(parse_script(body), _built(tmp_path)))
    assert result["タイトル"].ok is False


def test_the_duration_is_read_from_the_build(tmp_path):
    assert built_duration(_built(tmp_path, 165.0)) == 165.0


def test_a_missing_or_broken_build_file_gives_no_duration(tmp_path):
    assert built_duration(tmp_path) is None
    (tmp_path / "script.json").write_text("{ broken", encoding="utf-8")
    assert built_duration(tmp_path) is None


def test_manual_checks_are_listed():
    checks = manual_checks()
    assert len(checks) >= 4
    assert any("確度バッジ" in c for c in checks)

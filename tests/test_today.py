from datetime import date

import pytest

from src.today import STEPS, Slot, next_step, survey

DAY = date(2026, 8, 30)
SLOTS = [("morning", "朝の一報"), ("noon", "昼の話題"), ("evening", "夜のまとめ")]


def _slot(tmp_path, key="morning", notes=False, script=False, video=False):
    slot = Slot(
        key=key, name=key,
        notes=tmp_path / "n.yaml", script=tmp_path / "s.md", output=tmp_path / "out",
    )
    if notes:
        slot.notes.write_text("x", encoding="utf-8")
    if script:
        slot.script.write_text("x", encoding="utf-8")
    if video:
        slot.output.mkdir(exist_ok=True)
        (slot.output / "video.mp4").write_bytes(b"x")
    return slot


def test_progress_is_read_from_the_files(tmp_path):
    assert _slot(tmp_path).done == []
    assert _slot(tmp_path, notes=True).done == ["取材メモ"]
    assert _slot(tmp_path, notes=True, script=True, video=True).done == list(STEPS[1:])


def test_each_stage_suggests_the_next_command(tmp_path):
    assert "plan --routine" in _slot(tmp_path).next_command("20260830")
    assert "draft" in _slot(tmp_path, notes=True).next_command("20260830")
    assert "build" in _slot(tmp_path, notes=True, script=True).next_command("20260830")
    assert "review" in _slot(tmp_path, notes=True, script=True, video=True).next_command("20260830")


def test_the_day_starts_with_a_scan(tmp_path):
    missing = tmp_path / "none.yaml"
    assert "scan" in next_step(missing, [_slot(tmp_path)], "20260830")


def test_candidates_without_any_notes_means_pick(tmp_path):
    candidates = tmp_path / "c.yaml"
    candidates.write_text("x", encoding="utf-8")
    assert "pick" in next_step(candidates, [_slot(tmp_path)], "20260830")


def test_a_skipped_first_slot_does_not_hide_the_others(tmp_path):
    # 朝を飛ばして昼から作った日。pick に戻さず、朝の続きを促す
    candidates = tmp_path / "c.yaml"
    candidates.write_text("x", encoding="utf-8")
    (tmp_path / "a").mkdir()
    (tmp_path / "b").mkdir()
    morning = _slot(tmp_path / "a", "morning")
    noon = _slot(tmp_path / "b", "noon", notes=True)

    step = next_step(candidates, [morning, noon], "20260830")
    assert "pick" not in step
    assert "plan --routine morning" in step


def test_everything_done_moves_to_upload(tmp_path):
    candidates = tmp_path / "c.yaml"
    candidates.write_text("x", encoding="utf-8")
    slot = _slot(tmp_path, notes=True, script=True, video=True)
    assert "upload" in next_step(candidates, [slot], "20260830")


def test_survey_builds_the_paths_for_the_day():
    candidates, slots = survey(SLOTS, DAY)
    assert candidates.name == "20260830_candidates.yaml"
    assert [s.key for s in slots] == ["morning", "noon", "evening"]
    assert slots[0].script.name == "20260830_morning.md"
    assert slots[2].output.name == "20260830_evening"

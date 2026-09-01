"""タイムライン（構成）の読み込みと長さの決め方。"""

import json

import pytest

from videogen import timeline as timeline_module
from videogen.errors import TimelineError
from videogen.timeline import Scene, Timeline

BASE = {"scenes": [{"image": "a.png"}]}


# --- サイズ -----------------------------------------------------------
def test_parse_size():
    assert timeline_module.parse_size("1920x1080") == (1920, 1080)
    assert timeline_module.parse_size("1080×1920") == (1080, 1920)


def test_parse_size_rejects_garbage():
    with pytest.raises(TimelineError, match="size の指定が不正"):
        timeline_module.parse_size("おおきい")


def test_parse_size_rejects_odd_numbers():
    """H.264 は偶数でないと encode できないので、作る前に止める。"""
    with pytest.raises(TimelineError, match="偶数"):
        timeline_module.parse_size("1921x1080")


# --- シーン -----------------------------------------------------------
def test_scene_requires_an_image():
    with pytest.raises(TimelineError, match="image"):
        Scene.from_dict({"text": "字幕だけ"}, 1)


def test_scene_reports_unknown_keys():
    """綴り間違いを黙って無視しない（無視すると効いていない設定に気づけない）。"""
    with pytest.raises(TimelineError, match="second"):
        Scene.from_dict({"image": "a.png", "second": 3}, 2)


def test_scene_rejects_unknown_motion():
    with pytest.raises(TimelineError, match="motion"):
        Scene.from_dict({"image": "a.png", "motion": "spin"}, 1)


def test_scene_rejects_a_too_short_duration():
    with pytest.raises(TimelineError, match="短すぎ"):
        Scene.from_dict({"image": "a.png", "seconds": 0.01}, 1)


def test_scene_must_be_a_mapping():
    with pytest.raises(TimelineError, match="辞書"):
        Scene.from_dict("a.png", 1)


# --- タイムライン -----------------------------------------------------
def test_defaults():
    loaded = Timeline.from_dict(BASE)
    assert loaded.size == "1920x1080"
    assert loaded.fps == 30
    assert loaded.dimensions == (1920, 1080)
    assert loaded.tail == timeline_module.DEFAULT_TAIL


def test_needs_at_least_one_scene():
    with pytest.raises(TimelineError, match="scenes"):
        Timeline.from_dict({"scenes": []})


def test_rejects_a_bad_fps():
    with pytest.raises(TimelineError, match="fps"):
        Timeline.from_dict({**BASE, "fps": 0})


def test_rejects_a_negative_fade():
    with pytest.raises(TimelineError, match="fade"):
        Timeline.from_dict({**BASE, "fade": -1})


def test_checks_the_size_before_rendering():
    with pytest.raises(TimelineError, match="size"):
        Timeline.from_dict({**BASE, "size": "1920"})


def test_must_be_a_mapping():
    with pytest.raises(TimelineError, match="辞書"):
        Timeline.from_dict([{"image": "a.png"}])


# --- 長さ -------------------------------------------------------------
def test_explicit_seconds_wins(tmp_path, make_wav):
    audio = make_wav(tmp_path / "n.wav", seconds=5.0)
    loaded = Timeline.from_dict(
        {"scenes": [{"image": "a.png", "audio": str(audio), "seconds": 2.0}]}
    )
    assert loaded.durations() == [2.0]


def test_audio_decides_the_length_with_a_tail(tmp_path, make_wav):
    """WAV は ffmpeg を呼ばずに測れる。"""
    audio = make_wav(tmp_path / "n.wav", seconds=1.5)
    loaded = Timeline.from_dict({"scenes": [{"image": "a.png", "audio": str(audio)}], "tail": 0.5})
    assert loaded.durations() == [2.0]


def test_scene_without_audio_uses_the_default_length():
    assert Timeline.from_dict(BASE).durations() == [timeline_module.DEFAULT_SECONDS]


def test_total_is_the_sum():
    loaded = Timeline.from_dict(
        {"scenes": [{"image": "a.png", "seconds": 1.5}, {"image": "b.png", "seconds": 2.25}]}
    )
    assert loaded.total_seconds() == 3.75


def test_durations_can_use_an_injected_probe():
    loaded = Timeline.from_dict({"scenes": [{"image": "a.png", "audio": "n.mp3"}], "tail": 0})
    assert loaded.durations(probe=lambda path: 9.0) == [9.0]


# --- 素材の確認 -------------------------------------------------------
def test_missing_files_are_listed(tmp_path):
    image = tmp_path / "a.png"
    image.write_bytes(b"x")
    loaded = Timeline.from_dict(
        {
            "scenes": [{"image": str(image)}, {"image": str(tmp_path / "b.png")}],
            "bgm": str(tmp_path / "bgm.wav"),
        }
    )
    missing = loaded.missing_files()
    assert len(missing) == 2
    assert str(image) not in missing


# --- 読み込み ---------------------------------------------------------
def test_load_json(tmp_path):
    path = tmp_path / "t.json"
    path.write_text(json.dumps({"scenes": [{"image": "a.png", "text": "字幕"}]}), encoding="utf-8")
    assert timeline_module.load(path).scenes[0].text == "字幕"


def test_load_yaml(tmp_path):
    path = tmp_path / "t.yaml"
    path.write_text("scenes:\n  - image: a.png\n    motion: pan_left\n", encoding="utf-8")
    assert timeline_module.load(path).scenes[0].motion == "pan_left"


def test_load_accepts_a_dict():
    assert timeline_module.load(BASE).scenes[0].image == "a.png"


def test_load_reports_a_missing_file(tmp_path):
    with pytest.raises(TimelineError, match="構成ファイルがありません"):
        timeline_module.load(tmp_path / "nope.yaml")

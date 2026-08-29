import pytest

from src.config import ConfigError, build_config, load_config

RAW = {
    "video": {"width": 1280, "height": 720},
    "voicevox": {"pause": 0.5},
    "cast": {
        "霊夢": {"key": "reimu", "style_id": 2, "aliases": ["れいむ"]},
        "魔理沙": {"key": "marisa", "style_id": 3},
    },
}


def test_build_config_defaults_and_overrides():
    config = build_config(RAW)
    assert config.video.width == 1280
    assert config.video.fps == 30  # 未指定は既定値
    assert config.voicevox.pause == 0.5


def test_resolve_speaker_by_name_alias_and_key():
    config = build_config(RAW)
    assert config.resolve_speaker("霊夢").key == "reimu"
    assert config.resolve_speaker("れいむ").key == "reimu"
    assert config.resolve_speaker("MARISA").key == "marisa"


def test_unknown_speaker_raises():
    config = build_config(RAW)
    with pytest.raises(ConfigError, match="ゆかり"):
        config.resolve_speaker("ゆかり")


def test_style_id_is_required():
    with pytest.raises(ConfigError, match="style_id"):
        build_config({"cast": {"霊夢": {"key": "reimu"}}})


def test_project_config_loads():
    config = load_config()
    assert config.cast
    assert config.video.font_path().exists()

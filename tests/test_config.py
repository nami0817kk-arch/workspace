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


# ---------------------------------------------------------------- 出力の文字コード
# Windows で出力をパイプに渡すと cp932 で書こうとして、
# kicker の見出しの ü や、画面の ✓ で落ちる。実運用のPCで見つかった。

def test_cp932の出力をUTF8にそろえる():
    import io

    from src.cli import _use_utf8

    raw = io.BytesIO()
    stream = io.TextIOWrapper(raw, encoding="cp932")
    _use_utf8(stream)

    stream.write("✓ kicker　Bürki trifft in der 97. Minute")
    stream.flush()
    assert "Bürki" in raw.getvalue().decode("utf-8")


def test_すでにUTF8なら触らない():
    import io

    from src.cli import _use_utf8

    stream = io.TextIOWrapper(io.BytesIO(), encoding="utf-8")
    _use_utf8(stream)
    assert stream.encoding.lower().replace("-", "") == "utf8"


def test_差し替えられた出力先でも落ちない():
    from src.cli import _use_utf8

    class Fake:
        encoding = "cp932"

    _use_utf8(Fake())   # reconfigure を持たない。例外を出さずに済ませる

"""プロンプトのプリセット。"""

import json

import pytest

from imagegen import styles
from imagegen.core.errors import ConfigError


def test_style_is_appended_to_the_prompt():
    result = styles.apply("猫のイラスト", "flat")
    assert result.startswith("猫のイラスト, ")
    assert "flat vector illustration" in result


def test_no_style_leaves_the_prompt_alone():
    assert styles.apply("猫のイラスト", None) == "猫のイラスト"
    assert styles.apply("猫のイラスト", "") == "猫のイラスト"


def test_unknown_style_lists_the_available_ones():
    with pytest.raises(ConfigError, match="未知のスタイル"):
        styles.apply("猫", "浮世絵")
    try:
        styles.apply("猫", "浮世絵")
    except ConfigError as exc:
        assert "flat" in str(exc)


def test_builtin_styles_are_usable():
    assert {"flat", "banner", "icon"} <= set(styles.names())
    for description, prompt in styles.all_styles().values():
        assert description and prompt


def test_user_styles_can_be_added(tmp_path, monkeypatch):
    path = tmp_path / "styles.json"
    path.write_text(json.dumps({"ukiyoe": "浮世絵風、木版画の質感"}), encoding="utf-8")
    monkeypatch.setenv("IMAGEGEN_STYLES_FILE", str(path))

    assert "ukiyoe" in styles.names()
    assert "浮世絵風" in styles.apply("富士山", "ukiyoe")


def test_user_styles_can_override_builtins(tmp_path, monkeypatch):
    path = tmp_path / "styles.json"
    path.write_text(
        json.dumps({"flat": {"description": "社内用", "prompt": "社内資料のトーンで"}}),
        encoding="utf-8",
    )
    monkeypatch.setenv("IMAGEGEN_STYLES_FILE", str(path))

    assert styles.all_styles()["flat"] == ("社内用", "社内資料のトーンで")


def test_broken_style_file_falls_back_to_builtins(tmp_path, monkeypatch):
    path = tmp_path / "styles.json"
    path.write_text("{壊れている", encoding="utf-8")
    monkeypatch.setenv("IMAGEGEN_STYLES_FILE", str(path))

    assert "flat" in styles.names()


def test_generate_uses_the_style(tmp_path, monkeypatch):
    from imagegen import generation

    monkeypatch.setenv("IMAGEGEN_OUTPUT_DIR", str(tmp_path))
    image = generation.generate("猫", provider="local", size="64x64", style="flat")[0]
    assert "flat vector illustration" in image.prompt  # プロバイダへ渡ったプロンプトが残る

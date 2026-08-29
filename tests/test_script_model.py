import pytest

from src.script_model import ScriptError, parse_script

BASIC = """---
title: テスト動画
tags: [tag1, tag2]
---

## イントロ
@bg: assets/backgrounds/other.png

霊夢: こんにちは。
  telop: ごあいさつ
  pause: 0.9
魔理沙: よろしくな。
  emotion: smile

## 本編
霊夢: 本編よ。
"""


def test_frontmatter_and_structure():
    script = parse_script(BASIC)
    assert script.title == "テスト動画"
    assert script.tags == ["tag1", "tag2"]
    assert [scene.title for scene in script.scenes] == ["イントロ", "本編"]
    assert len(script.lines) == 3


def test_line_attributes():
    script = parse_script(BASIC)
    first, second = script.lines[0], script.lines[1]
    assert first.telop_text() == "ごあいさつ"
    assert first.pause == 0.9
    assert second.emotion == "smile"
    # telop 未指定ならセリフをそのまま表示する
    assert second.telop_text() == "よろしくな。"


def test_scene_background_directive():
    script = parse_script(BASIC)
    assert script.scenes[0].background == "assets/backgrounds/other.png"
    assert script.scenes[1].background is None


def test_no_telop_flag():
    script = parse_script("## S\n霊夢: 表示しない。\n  no_telop: true\n")
    assert script.lines[0].telop_text() == ""


def test_fullwidth_colon_is_accepted():
    script = parse_script("## S\n霊夢：全角コロンでも通る。\n")
    assert script.lines[0].speaker == "霊夢"


def test_error_reports_line_number():
    with pytest.raises(ScriptError) as exc:
        parse_script("## S\n霊夢: ok\nコロンのない行\n")
    assert "3行目" in str(exc.value)


def test_unknown_attribute_is_rejected():
    with pytest.raises(ScriptError, match="unknown"):
        parse_script("## S\n霊夢: ok\n  unknown: 1\n")


def test_empty_script_is_rejected():
    with pytest.raises(ScriptError):
        parse_script("## 見出しだけ\n")


def test_estimated_duration_grows_with_text():
    script = parse_script("## S\n霊夢: 短い。\n霊夢: " + "長い文章。" * 10 + "\n")
    short, long = script.lines
    assert long.estimated_duration() > short.estimated_duration()


def test_broken_frontmatter_gives_a_readable_message():
    """YAMLの生の例外ではなく、直し方が分かるメッセージにする。"""
    with pytest.raises(ScriptError, match="引用符"):
        parse_script("---\ntitle: {{PLACEHOLDER}}\n---\n\n## S\n霊夢: あ。\n")

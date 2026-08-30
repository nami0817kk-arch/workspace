import pytest

from src.config import load_config
from src.script_model import parse_script
from src.shorts import MAX_SECONDS, SIZE, ShortError, _estimate, portrait, trim

BODY = (
    "---\ntitle: T\n---\n\n"
    "## オープニング\n\nキャスター: つかみです。\n\n"
    "## 何が起きたか\n\nキャスター: いち。\n解説: に。\n解説: さん。\n\n"
    "## 数字で見ると\n\nキャスター: すうじ。\n\n"
    "## まとめ\n\nキャスター: まとめ。\n"
)


def test_portrait_flips_the_frame_and_shrinks_the_text():
    wide = load_config()
    tall = portrait(wide)
    assert (tall.video.width, tall.video.height) == SIZE
    assert tall.video.telop_size < wide.video.telop_size
    assert wide.video.width == 1920      # 元の設定は変えない


def test_the_default_cut_is_the_opening_plus_the_next_section():
    short = trim(parse_script(BODY))
    assert [scene.title for scene in short.scenes] == ["オープニング", "何が起きたか"]


def test_a_named_section_can_be_used_instead():
    short = trim(parse_script(BODY), "数字で見ると")
    assert [scene.title for scene in short.scenes] == ["オープニング", "数字で見ると"]


def test_an_unknown_section_lists_the_choices():
    with pytest.raises(ShortError, match="数字で見ると"):
        trim(parse_script(BODY), "存在しない節")


def test_the_original_script_is_left_alone():
    script = parse_script(BODY)
    trim(script)
    assert len(script.scenes) == 4       # 元の台本は削らない


def test_lines_are_dropped_from_the_back_until_it_fits():
    script = parse_script(BODY)
    short = trim(script, "何が起きたか", max_seconds=1.0)
    # 冒頭は削らず、掘る節から後ろを落とす
    assert len(short.scenes[0].lines) == 1
    assert len(short.scenes[1].lines) == 1
    assert short.scenes[1].lines[0].text == "いち。"


def test_a_one_scene_script_is_refused():
    with pytest.raises(ShortError, match="節が1つ"):
        trim(parse_script("---\ntitle: T\n---\n\n## だけ\n\nキャスター: あ。\n"))


def test_the_estimate_uses_the_pre_build_guess():
    short = trim(parse_script(BODY))
    assert _estimate(short) > 0          # ビルド前でも尺が出る
    assert _estimate(short) < MAX_SECONDS

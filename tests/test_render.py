import pytest
from PIL import Image, ImageDraw, ImageFont

from src.config import load_config
from src.render import Renderer, wrap_text
from src.script_model import parse_script

SCRIPT = "## 章1\n霊夢: あいうえお。\n  telop: テロップ\n魔理沙: かきくけこ。\n"


def _script_with_timing():
    script = parse_script(SCRIPT)
    for line in script.lines:
        line.duration = 2.0
        line.pause = 0.4
    return script


def test_wrap_text_respects_width():
    image = Image.new("RGB", (10, 10))
    draw = ImageDraw.Draw(image)
    font = ImageFont.truetype(str(load_config().video.font_path()), 40)
    lines = wrap_text(draw, "あ" * 20, font, 200)
    assert len(lines) > 1
    assert "".join(lines) == "あ" * 20


def test_wrap_text_keeps_punctuation_off_line_head():
    image = Image.new("RGB", (10, 10))
    draw = ImageDraw.Draw(image)
    font = ImageFont.truetype(str(load_config().video.font_path()), 40)
    lines = wrap_text(draw, "ああああ、いいいい。", font, 165)
    assert not any(line.startswith(("、", "。")) for line in lines)


@pytest.mark.parametrize("motion", [True, False])
def test_frame_entries_match_audio_duration(tmp_path, motion):
    """演出を入れても映像の尺は音声とずれない（演出は発話時間の内側で行う）。"""
    config = load_config()
    config.motion.enabled = motion
    script = _script_with_timing()
    renderer = Renderer(config, tmp_path)
    entries = renderer.frame_entries(script)
    total = sum(duration for _, duration in entries)
    assert total == pytest.approx(script.duration, abs=1e-6)


def test_frames_are_cached_by_content(tmp_path):
    config = load_config()
    config.motion.enabled = False
    script = _script_with_timing()
    renderer = Renderer(config, tmp_path)
    renderer.frame_entries(script)
    # 2行 x (口を閉じた絵 + 開けた絵) = 4枚だけ
    assert len(list((tmp_path / "frames").glob("*.png"))) == 4


def test_motion_adds_intro_frames(tmp_path):
    config = load_config()
    script = _script_with_timing()

    config.motion.enabled = False
    without = len(Renderer(config, tmp_path / "off").frame_entries(script))
    config.motion.enabled = True
    with_motion = len(Renderer(config, tmp_path / "on").frame_entries(script))
    assert with_motion > without


def test_scene_change_uses_crossfade(tmp_path):
    """2つ目のシーンの頭には、前の画面と混ざった中間フレームが入る。"""
    config = load_config()
    script = parse_script("## 章1\n霊夢: あいうえお。\n\n## 章2\n魔理沙: かきくけこ。\n")
    for line in script.lines:
        line.duration, line.pause = 2.0, 0.4
    renderer = Renderer(config, tmp_path)
    renderer.frame_entries(script)
    # blend() が作る中間フレームは x で始まる名前にしている
    assert list((tmp_path / "frames").glob("x*.png"))


def test_intro_is_capped_by_speaking_time(tmp_path):
    """発話が極端に短くても、演出が音声をはみ出さない。"""
    config = load_config()
    script = parse_script("## S\n霊夢: あ。\n")
    script.lines[0].duration, script.lines[0].pause = 0.2, 0.0
    renderer = Renderer(config, tmp_path)
    entries = renderer.frame_entries(script)
    assert sum(d for _, d in entries) == pytest.approx(0.2, abs=1e-6)


def test_is_video_detects_clip_extensions():
    from src.render import is_video

    assert is_video("assets/backgrounds/clip.mp4")
    assert is_video("CLIP.MOV")
    assert not is_video("assets/backgrounds/stadium.png")
    assert not is_video(None)


def test_video_background_frames_keep_alpha(tmp_path):
    """動画背景に重ねるフレームは、透過を残して書き出す。"""
    from PIL import Image

    config = load_config()
    script = parse_script("## S\n霊夢: あ。\n")
    script.background = "clip.mp4"
    script.lines[0].duration, script.lines[0].pause = 1.0, 0.0

    renderer = Renderer(config, tmp_path)
    renderer.frame_entries(script)
    frames = list((tmp_path / "frames").glob("*.png"))
    assert frames
    with Image.open(frames[0]) as image:
        assert image.mode == "RGBA"
        # 上端は完全に透過していて、下端は幕がかかっている
        assert image.getpixel((10, 10))[3] == 0
        assert image.getpixel((10, config.video.height - 10))[3] > 0

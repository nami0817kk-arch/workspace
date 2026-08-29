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


def test_frame_entries_match_audio_duration(tmp_path):
    config = load_config()
    script = _script_with_timing()
    renderer = Renderer(config, tmp_path)
    entries = renderer.frame_entries(script)
    total = sum(duration for _, duration in entries)
    assert abs(total - script.duration) < 0.01


def test_frames_are_cached_by_content(tmp_path):
    config = load_config()
    script = _script_with_timing()
    renderer = Renderer(config, tmp_path)
    renderer.frame_entries(script)
    # 2行 x (口を閉じた絵 + 開けた絵) = 4枚だけ
    assert len(list((tmp_path / "frames").glob("*.png"))) == 4

from src.script_model import parse_script
from src.subtitles import _clock, _timestamp, chapters, description, to_srt


def _timed_script():
    script = parse_script(
        "---\ntitle: T\ntags: [a]\ndescription: 説明文\n---\n\n"
        "## 章1\n霊夢: あいうえお。\n\n## 章2\n魔理沙: かきくけこ。\n"
    )
    start = 0.0
    for line in script.lines:
        line.duration = 3.0
        line.pause = 0.5
        line.start = start
        start += line.duration
    return script


def test_timestamp_format():
    assert _timestamp(0) == "00:00:00,000"
    assert _timestamp(3661.5) == "01:01:01,500"


def test_clock_format():
    assert _clock(9) == "0:09"
    assert _clock(75) == "1:15"
    assert _clock(3725) == "1:02:05"


def test_srt_excludes_trailing_pause():
    srt = to_srt(_timed_script())
    # 3.0秒 - 0.5秒の無音 = 2.5秒で字幕を消す
    assert "00:00:00,000 --> 00:00:02,500" in srt
    assert srt.count("-->") == 2


def test_chapters_start_at_zero():
    marks = chapters(_timed_script())
    assert marks[0] == (0.0, "章1")
    assert marks[1][0] == 3.0


def test_chapters_follow_actual_line_starts():
    """タイトルカードで時刻がずれても、チャプターは実際の開始時刻に追従する。"""
    script = _timed_script()
    # 冒頭に2.6秒、2章の前に1.4秒のタイトルカードが入った状態
    script.scenes[0].lines[0].start = 2.6
    script.scenes[1].lines[0].start = 7.0

    marks = chapters(script)
    assert marks[0] == (0.0, "章1")   # 先頭は必ず 0:00
    assert marks[1] == (7.0, "章2")


def test_description_contains_toc_and_tags():
    text = description(_timed_script())
    assert "説明文" in text
    assert "0:00 章1" in text
    assert "#a" in text

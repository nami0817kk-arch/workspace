"""字幕（SRT）の書き出し。"""

from videogen import subtitles


def test_timestamp_format():
    assert subtitles.timestamp(0) == "00:00:00,000"
    assert subtitles.timestamp(1.5) == "00:00:01,500"
    assert subtitles.timestamp(3661.25) == "01:01:01,250"


def test_timestamp_never_goes_negative():
    assert subtitles.timestamp(-5) == "00:00:00,000"


def test_srt_numbers_only_scenes_with_text():
    body = subtitles.build_srt(["最初", "", "最後"], [2.0, 3.0, 1.5])
    assert body.splitlines()[0] == "1"
    assert "00:00:00,000 --> 00:00:02,000" in body
    # 字幕の無いシーンぶんも時間は進む
    assert "00:00:05,000 --> 00:00:06,500" in body
    assert body.count("-->") == 2


def test_srt_is_empty_without_any_text():
    assert subtitles.build_srt(["", "  "], [1.0, 1.0]).strip() == ""


def test_write_srt_skips_the_file_when_there_is_nothing(tmp_path):
    assert subtitles.write_srt(["", ""], [1.0, 1.0], tmp_path / "a.srt") is None
    assert not (tmp_path / "a.srt").exists()


def test_write_srt_creates_the_folder(tmp_path):
    path = subtitles.write_srt(["字幕"], [1.0], tmp_path / "sub" / "a.srt")
    assert path.is_file()
    assert "字幕" in path.read_text(encoding="utf-8")


def test_escape_for_filter_handles_windows_paths():
    escaped = subtitles.escape_for_filter(r"C:\Users\a\b.srt")
    # 区切りは / に、コロンは退避する
    assert escaped == "C" + chr(92) + ":/Users/a/b.srt"

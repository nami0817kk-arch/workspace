"""試聴ページ生成のテスト。"""

from __future__ import annotations

import os

import pytest

from audiogen import core, preview, sfx

SR = 11025


@pytest.fixture
def sample_dir(tmp_path):
    core.write_wav(tmp_path / "sfx_coin.wav", sfx.generate("coin", sr=SR), sr=SR)
    core.write_wav(tmp_path / "bgm_calm.wav", sfx.generate("heal", sr=SR), sr=SR)
    core.write_wav(
        tmp_path / "wide.wav", core.to_stereo([0.5] * 100, [-0.5] * 100), sr=SR, channels=2
    )
    return tmp_path


def test_read_peaks_reports_the_file_details(sample_dir):
    track = preview.read_peaks(str(sample_dir / "sfx_coin.wav"))
    assert track.name == "sfx_coin"
    assert track.path == "sfx_coin.wav"
    assert track.sample_rate == SR
    assert track.channels == 1
    assert track.label == "mono"
    assert track.seconds == pytest.approx(0.38, abs=0.05)


def test_peaks_stay_in_range_and_bracket_zero(sample_dir):
    track = preview.read_peaks(str(sample_dir / "sfx_coin.wav"))
    assert 0 < len(track.peaks) <= preview.WAVEFORM_COLUMNS
    for low, high in track.peaks:
        assert -1.0 <= low <= 0.0 <= high <= 1.0


def test_stereo_files_are_labelled(sample_dir):
    assert preview.read_peaks(str(sample_dir / "wide.wav")).label == "stereo"


def test_collect_finds_every_wav_in_name_order(sample_dir):
    assert [track.name for track in preview.collect(str(sample_dir))] == [
        "bgm_calm",
        "sfx_coin",
        "wide",
    ]


def test_the_page_lists_every_track(sample_dir):
    page = preview.build_page(preview.collect(str(sample_dir)))
    assert page.startswith("<!doctype html>")
    for name in ("bgm_calm", "sfx_coin", "wide"):
        assert f'src="{name}.wav"' in page
    assert page.count("<audio") == 3


def test_the_page_separates_bgm_from_sfx(sample_dir):
    page = preview.build_page(preview.collect(str(sample_dir)))
    assert "BGM (1)" in page
    assert "効果音 (2)" in page


def test_each_track_gets_one_waveform_path(sample_dir):
    page = preview.build_page(preview.collect(str(sample_dir)))
    assert page.count("<svg") == 3
    assert page.count("<path") == 3  # 列ごとの線ではなく1本にまとめている


@pytest.mark.skipif(
    os.name == "nt",
    reason="Windows では < > がファイル名の予約文字で、この名前のファイルを作れない",
)
def test_track_names_are_escaped(tmp_path):
    core.write_wav(tmp_path / "a<b>&c.wav", [0.1, -0.1], sr=SR)
    page = preview.build_page(preview.collect(str(tmp_path)))
    assert "<b>" not in page
    assert "&lt;b&gt;" in page


def test_write_preview_creates_the_page(sample_dir):
    path = preview.write_preview(str(sample_dir))
    assert path.endswith("index.html")
    assert "<audio" in (sample_dir / "index.html").read_text(encoding="utf-8")


def test_write_preview_uses_the_given_title(sample_dir):
    preview.write_preview(str(sample_dir), title="ゲーム素材")
    assert "ゲーム素材" in (sample_dir / "index.html").read_text(encoding="utf-8")


def test_an_empty_directory_is_reported(tmp_path):
    with pytest.raises(ValueError, match="no .wav files"):
        preview.write_preview(str(tmp_path))


def test_only_16_bit_wav_is_supported(tmp_path):
    import wave

    path = tmp_path / "eight.wav"
    with wave.open(str(path), "wb") as fp:
        fp.setnchannels(1)
        fp.setsampwidth(1)
        fp.setframerate(SR)
        fp.writeframes(b"\x80" * 100)
    with pytest.raises(ValueError, match="16-bit"):
        preview.read_peaks(str(path))

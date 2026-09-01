"""filter_complex の組み立て（ffmpeg は起動しない）。"""

import pytest

from videogen import filters
from videogen.errors import TimelineError


def test_still_scene_shows_the_whole_image():
    """動かさないシーンは切り取らずに収める（図やサムネイルを欠けさせない）。"""
    chain = filters.scene_video(0, width=1280, height=720, fps=30, seconds=2.0)
    assert "force_original_aspect_ratio=decrease" in chain
    assert "pad=1280:720" in chain
    assert "zoompan" not in chain
    assert chain.startswith("[0:v]") and chain.endswith("[v0]")


def test_moving_scene_fills_the_frame_and_zooms():
    chain = filters.scene_video(1, width=1280, height=720, fps=30, seconds=2.0, motion="zoom_in")
    assert "force_original_aspect_ratio=increase" in chain
    assert "scale=2560:1440" in chain  # がたつきを抑えるため一度大きく作る
    assert "d=60" in chain  # 2秒 × 30fps
    assert "s=1280x720" in chain


def test_zoom_out_starts_wide():
    chain = filters.zoompan("zoom_out", width=640, height=360, fps=30, frames=60)
    assert f"max({filters.ZOOM_MAX}" in chain


def test_pans_move_in_opposite_directions():
    right = filters.zoompan("pan_right", width=640, height=360, fps=30, frames=60)
    left = filters.zoompan("pan_left", width=640, height=360, fps=30, frames=60)
    assert "x='(iw-iw/zoom)*on/60'" in right
    assert "x='(iw-iw/zoom)*(1-on/60)'" in left


def test_zoompan_rejects_unknown_motion():
    with pytest.raises(TimelineError, match="motion"):
        filters.zoompan("spin", width=640, height=360, fps=30, frames=30)


def test_scene_audio_is_trimmed_to_the_scene():
    """音がシーンより長くても短くても、ぴったりに揃える（ずれを溜めない）。"""
    chain = filters.scene_audio(3, 1, 2.5)
    assert chain.startswith("[3:a]")
    assert "apad" in chain and "atrim=0:2.5" in chain
    assert chain.endswith("[a1]")


def test_concat_pairs_every_scene():
    assert filters.concat(3).startswith("[v0][a0][v1][a1][v2][a2]concat=n=3:v=1:a=1")


def test_bgm_does_not_quiet_the_narration():
    """amix の既定は入力を等分に下げる。ナレーションはそのままにする。"""
    chain = filters.bgm_mix(4, -18.0)
    assert "volume=-18.0dB" in chain
    assert "normalize=0" in chain


def test_fade_out_starts_before_the_end():
    assert "st=9.5:d=0.5" in filters.fade_video("vc", "vout", 0.5, 10.0)
    assert "st=9.5:d=0.5" in filters.fade_audio("ac", "aout", 0.5, 10.0)


def test_fade_never_starts_before_zero():
    assert "st=0:d=2" in filters.fade_video("vc", "vout", 2.0, 1.0)


def test_burn_subtitles_escapes_the_path_and_sets_the_font():
    chain = filters.burn_subtitles("vc", "vsub", r"C:\out\a.srt", font="Meiryo")
    assert "C" + chr(92) + ":/out/a.srt" in chain
    assert "force_style='FontName=Meiryo'" in chain

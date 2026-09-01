"""タイムライン → ffmpeg コマンド → 書き出し。"""

import pytest

from videogen import build
from videogen.errors import TimelineError
from videogen.timeline import Timeline


@pytest.fixture
def materials(tmp_path, make_wav):
    """画像2枚と音声1本を用意する（中身は使わない。存在確認と長さだけ）。"""
    (tmp_path / "a.png").write_bytes(b"x")
    (tmp_path / "b.png").write_bytes(b"x")
    make_wav(tmp_path / "n.wav", seconds=1.7)
    make_wav(tmp_path / "bgm.wav", seconds=30.0)
    return tmp_path


def timeline_for(materials, **overrides):
    data = {
        "scenes": [
            {"image": str(materials / "a.png"), "text": "見出し", "audio": str(materials / "n.wav")},
            {"image": str(materials / "b.png"), "seconds": 2.0, "motion": "zoom_in"},
        ],
        "size": "1280x720",
        "fps": 30,
        "tail": 0.3,
    }
    data.update(overrides)
    return Timeline.from_dict(data)


# --- コマンドの組み立て -----------------------------------------------
def test_inputs_are_images_then_audio(materials):
    command = build.build_command(timeline_for(materials), "out.mp4", [2.0, 2.0])
    text = " ".join(command)
    assert text.count("-i ") == 4  # 画像2枚 + 音声2本（無音を含む）
    # 音声の無いシーンには無音を作る（concat のペアを必ず揃えるため）
    assert "anullsrc=channel_layout=stereo:sample_rate=48000" in text
    assert text.endswith("out.mp4")


def test_still_scenes_loop_the_image_for_its_whole_length():
    assert build.image_input("none", seconds=2.5, fps=30) == [
        "-loop", "1", "-framerate", "30", "-t", "2.5",
    ]


def test_moving_scenes_never_loop_the_image():
    """zoompan の d は「入力1フレームあたりに作る枚数」。

    ループ入力（尺×fps 枚）と掛け算になり、5.7秒のつもりが494秒の動画になった。
    動かすシーンでは静止画を1フレームだけ渡し、尺は zoompan に作らせる。
    """
    assert build.image_input("zoom_in", seconds=2.5, fps=30) == []


def test_only_the_still_scene_is_looped(materials):
    command = build.build_command(timeline_for(materials), "out.mp4", [2.0, 2.0])
    # 1つ目が静止（motion なし）、2つ目が zoom_in
    assert " ".join(command).count("-loop 1") == 1


def test_maps_the_final_labels(materials):
    command = build.build_command(timeline_for(materials), "out.mp4", [2.0, 2.0])
    assert "-map" in command
    assert "[vc]" in command and "[ac]" in command


def test_fade_replaces_the_mapped_labels(materials):
    command = build.build_command(timeline_for(materials, fade=0.5), "out.mp4", [2.0, 2.0])
    assert "[vout]" in command and "[aout]" in command
    assert "[vc]" not in command


def test_bgm_is_looped_and_mixed(materials):
    command = build.build_command(
        timeline_for(materials, bgm=str(materials / "bgm.wav")), "out.mp4", [2.0, 2.0]
    )
    text = " ".join(command)
    assert "-stream_loop -1" in text  # 尺が足りなくても最後まで鳴らす
    assert "[amixed]" in command


def test_burn_needs_a_subtitle_file(materials):
    with pytest.raises(TimelineError, match="字幕"):
        build.build_command(timeline_for(materials), "out.mp4", [2.0, 2.0], burn=True)


def test_burn_inserts_the_subtitles_filter(materials):
    command = build.build_command(
        timeline_for(materials), "out.mp4", [2.0, 2.0], srt_path="a.srt", burn=True
    )
    assert "[vsub]" in command
    assert "subtitles=" in " ".join(command)


def test_duration_count_must_match(materials):
    with pytest.raises(TimelineError, match="長さの数"):
        build.build_command(timeline_for(materials), "out.mp4", [2.0])


def test_no_scenes_is_refused():
    empty = Timeline()
    with pytest.raises(TimelineError, match="シーンが1つも"):
        build.build_command(empty, "out.mp4", [])


# --- 書き出し ---------------------------------------------------------
def test_dry_run_does_not_start_ffmpeg(materials):
    """conftest が subprocess を塞いでいるので、起動したらここで落ちる。"""
    result = build.render(timeline_for(materials), materials / "out.mp4", dry_run=True)

    assert result.dry_run
    assert result.seconds == 4.0  # 1.7 + 0.3（余白）+ 2.0
    assert result.scenes == 2
    assert not (materials / "out.mp4").exists()
    assert "[ドライラン]" in result.describe()


def test_subtitles_are_written_even_without_burning(materials):
    """焼き込まなくても字幕は必ず残す（YouTube にそのまま渡せる）。"""
    result = build.render(timeline_for(materials), materials / "out.mp4", dry_run=True)
    assert result.srt == materials / "out.srt"
    assert "見出し" in result.srt.read_text(encoding="utf-8")


def test_render_calls_ffmpeg(materials, monkeypatch):
    calls = []
    monkeypatch.setattr(build.ffmpeg_module, "run", lambda args: calls.append(args))

    result = build.render(timeline_for(materials), materials / "out.mp4")
    assert len(calls) == 1
    assert calls[0] == result.command
    assert not result.dry_run


def test_missing_material_is_reported_before_rendering(tmp_path):
    timeline = Timeline.from_dict({"scenes": [{"image": str(tmp_path / "nope.png")}]})
    with pytest.raises(TimelineError, match="素材が見つかりません"):
        build.render(timeline, tmp_path / "out.mp4", dry_run=True)


def test_burning_without_any_text_is_refused(materials):
    timeline = Timeline.from_dict({"scenes": [{"image": str(materials / "a.png"), "seconds": 1}]})
    with pytest.raises(TimelineError, match="焼き込めません"):
        build.render(timeline, materials / "out.mp4", dry_run=True, burn=True)

"""BGM ジェネレータのテスト。"""

from __future__ import annotations

import pytest

from audiogen import bgm, core, drums

SR = 11025


def _config(**kwargs) -> bgm.BGMConfig:
    params = {"bars": 2, "seed": 0, "sr": SR}
    params.update(kwargs)
    return bgm.BGMConfig(**params)


@pytest.mark.parametrize("style", bgm.style_names())
def test_every_style_renders_audible_bounded_audio(style):
    buf = bgm.generate(_config(style=style))
    assert core.peak(buf) == pytest.approx(bgm.TARGET_PEAK, abs=1e-6)
    assert max(abs(v) for v in buf) <= 1.0


@pytest.mark.parametrize("style", bgm.style_names())
def test_every_style_is_free_of_dc_offset(style):
    buf = bgm.generate(_config(style=style))
    assert abs(sum(buf) / len(buf)) < 0.01


@pytest.mark.parametrize("style", bgm.style_names())
def test_loop_length_matches_bars_and_tempo(style):
    config = _config(style=style, bars=2)
    buf = bgm.generate(config)
    bpm = config.resolved_style().bpm
    expected = core.num_samples(2 * bgm.BEATS_PER_BAR * 60.0 / bpm, SR)
    assert len(buf) == expected


def test_no_loop_keeps_the_reverb_tail():
    looped = bgm.generate(_config(style="night", loop=True))
    open_ended = bgm.generate(_config(style="night", loop=False))
    assert len(open_ended) > len(looped)


def test_same_seed_gives_the_same_track():
    assert bgm.generate(_config(seed=42)) == bgm.generate(_config(seed=42))


def test_different_seeds_give_different_tracks():
    assert bgm.generate(_config(seed=1)) != bgm.generate(_config(seed=2))


def test_bars_scale_the_duration():
    short = bgm.generate(_config(bars=2))
    long = bgm.generate(_config(bars=4))
    assert len(long) == pytest.approx(2 * len(short), rel=0.01)


def test_bpm_override_shortens_the_track():
    fast = bgm.generate(_config(style="calm", bpm=160))
    slow = bgm.generate(_config(style="calm", bpm=80))
    assert len(fast) < len(slow)


def test_key_override_transposes_the_track():
    c_major = bgm.generate(_config(key="C"))
    a_major = bgm.generate(_config(key="A"))
    assert c_major != a_major


def test_render_tracks_returns_the_requested_parts():
    tracks = bgm.render_tracks(_config(style="adventure"))
    assert set(tracks) == {"chords", "bass", "lead", "drums"}
    assert all(len(track) > 0 for track in tracks.values())


def test_parts_can_be_dropped():
    tracks = bgm.render_tracks(_config(parts=("bass",)))
    assert set(tracks) == {"bass"}


def test_style_without_drums_yields_no_drum_track():
    assert "drums" not in bgm.render_tracks(_config(style="night"))


def test_drum_pattern_override_is_applied():
    tracks = bgm.render_tracks(_config(style="night", drum_pattern="basic"))
    assert "drums" in tracks


def test_progression_override_changes_the_harmony():
    a = bgm.generate(_config(progression="I-I-I-I", parts=("chords",)))
    b = bgm.generate(_config(progression="I-V-vi-IV", parts=("chords",)))
    assert a != b


def test_stereo_output_is_interleaved_and_twice_as_long():
    config = _config(style="menu")
    mono = bgm.generate(config)
    stereo = bgm.generate_stereo(config)
    assert len(stereo) == 2 * len(mono)
    assert stereo[0::2] != stereo[1::2]  # パンで L/R に差が出る


def test_keyword_overrides_work_without_building_a_config():
    buf = bgm.generate(bars=1, seed=3, sr=SR, style="menu")
    assert len(buf) > 0


def test_unknown_style_raises():
    with pytest.raises(ValueError, match="unknown bgm style"):
        bgm.generate(_config(style="jazz-fusion"))


def test_zero_bars_raises():
    with pytest.raises(ValueError, match="bars"):
        bgm.generate(_config(bars=0))


def test_unknown_drum_pattern_raises():
    with pytest.raises(ValueError, match="unknown drum pattern"):
        bgm.generate(_config(drum_pattern="bossa"))


@pytest.mark.parametrize("name", drums.pattern_names())
def test_drum_patterns_are_sixteen_steps(name):
    for steps in drums.get_pattern(name).values():
        assert len(steps) == drums.STEPS_PER_BAR
        assert set(steps) <= {"x", "o", "."}


@pytest.mark.parametrize("name", drums.pattern_names())
def test_drum_patterns_only_use_known_voices(name):
    assert set(drums.get_pattern(name)) <= set(drums.VOICES)


@pytest.mark.parametrize("voice", sorted(drums.VOICES))
def test_drum_voices_are_short_and_audible(voice):
    buf = drums.VOICES[voice](sr=SR)
    assert 0.1 < core.peak(buf) <= 1.0
    assert core.duration_of(buf, SR) < 0.5

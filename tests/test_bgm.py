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


# --- 曲構成 -------------------------------------------------------------------


@pytest.mark.parametrize("structure", bgm.structure_names())
def test_every_structure_renders(structure):
    buf = bgm.generate(_config(style="adventure", bars=8, structure=structure))
    assert core.peak(buf) == pytest.approx(bgm.TARGET_PEAK, abs=1e-6)


@pytest.mark.parametrize("structure", bgm.structure_names())
@pytest.mark.parametrize("bars", [1, 2, 3, 8, 16, 17])
def test_section_bars_always_sum_to_the_requested_total(structure, bars):
    plan = bgm.plan_sections(structure, bars)
    assert sum(count for _, _, count in plan) == bars
    assert all(count >= 1 for _, _, count in plan)


@pytest.mark.parametrize("structure", bgm.structure_names())
def test_sections_are_laid_out_end_to_end(structure):
    plan = bgm.plan_sections(structure, 16)
    expected_start = 0
    for _, start, count in plan:
        assert start == expected_start
        expected_start += count


def test_structure_does_not_change_the_total_length():
    """構成を変えても、小節数が同じなら曲の長さは変わらない。"""
    plain = bgm.generate(_config(style="adventure", bars=8, structure="loop"))
    full = bgm.generate(_config(style="adventure", bars=8, structure="full"))
    assert len(plain) == len(full)


def test_intro_section_has_no_drums():
    """イントロではドラムが鳴らないこと。"""
    config = _config(style="adventure", bars=8, structure="intro")
    tracks = bgm.render_tracks(config)
    bar_seconds = bgm.BEATS_PER_BAR * 60.0 / config.resolved_style().bpm
    intro_bars = bgm.plan_sections("intro", 8)[0][2]
    intro_end = core.num_samples(intro_bars * bar_seconds, SR)
    assert core.peak(tracks["drums"][:intro_end]) == 0.0
    assert core.peak(tracks["drums"][intro_end:]) > 0.0


def test_chorus_lead_sits_higher_than_the_verse_lead():
    """サビのメロディが A メロより高い位置にあること。"""
    config = _config(style="adventure", bars=8, structure="verse_chorus", parts=("lead",))
    lead = bgm.render_tracks(config)["lead"]
    half = len(lead) // 2
    verse, chorus = lead[:half], lead[half:]
    assert _zero_crossing_rate(chorus) > _zero_crossing_rate(verse)


def test_too_few_bars_falls_back_to_the_leading_sections():
    plan = bgm.plan_sections("full", 2)
    assert [section.name for section, _, _ in plan] == ["intro", "verse"]


def test_unknown_structure_raises():
    with pytest.raises(ValueError, match="unknown structure"):
        bgm.generate(_config(structure="sonata"))


def _zero_crossing_rate(buf) -> float:
    """ゼロ交差の割合。音の高さの目安になる。"""
    crossings = sum(1 for a, b in zip(buf, buf[1:]) if (a < 0) != (b < 0))
    return crossings / max(1, len(buf))

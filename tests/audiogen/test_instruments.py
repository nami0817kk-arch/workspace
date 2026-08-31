"""楽器(音色)のテスト。"""

from __future__ import annotations

import math

import pytest

from audiogen import bgm, core, instruments

SR = 11025


@pytest.mark.parametrize("name", instruments.available())
def test_every_instrument_renders_bounded_audio(name):
    buf = instruments.get(name).render(440.0, 0.4, SR)
    assert len(buf) == core.num_samples(0.4, SR)
    assert 0.2 < core.peak(buf) <= 1.0


@pytest.mark.parametrize("name", instruments.available())
def test_every_instrument_is_dc_free(name):
    buf = instruments.get(name).render(440.0, 0.4, SR)
    assert abs(sum(buf) / len(buf)) < 0.01


@pytest.mark.parametrize("name", instruments.available())
def test_instrument_levels_are_matched(name):
    """楽器を差し替えても音量バランスが崩れないよう、実効値がそろっていること。"""
    buf = instruments.get(name).render(440.0, 0.5, 22050)
    rms = math.sqrt(sum(value * value for value in buf) / len(buf))
    assert 0.2 < rms < 0.45


@pytest.mark.parametrize("name", instruments.available())
def test_every_instrument_starts_and_ends_quietly(name):
    buf = instruments.get(name).render(440.0, 0.4, SR)
    assert abs(buf[0]) < 0.05
    assert abs(buf[-1]) < 0.1


def test_unknown_instrument_raises():
    with pytest.raises(ValueError, match="unknown instrument"):
        instruments.get("theremin")


def test_layers_stack_into_a_richer_spectrum():
    """層を重ねた音色は、単一波形より倍音が多いこと。"""
    plain = instruments.get("sine").render(220.0, 0.5, SR)
    layered = instruments.get("organ").render(220.0, 0.5, SR)
    assert _partials(layered, 220.0) > _partials(plain, 220.0)


def test_ratio_places_a_layer_at_the_requested_interval():
    octave_up = instruments.Instrument((instruments.Layer("sine", ratio=2.0),), attack=0.001, sustain=1.0)
    buf = octave_up.render(220.0, 0.3, SR)
    assert _goertzel(buf, 440.0, SR) > 5 * _goertzel(buf, 220.0, SR)


def test_detune_creates_beating_between_layers():
    """デチューンした2枚を重ねると、うなりで音量が周期的に上下すること。"""
    detuned = instruments.Instrument(
        (instruments.Layer("sine", detune=-0.01), instruments.Layer("sine", detune=0.01)),
        attack=0.001, decay=0.001, sustain=1.0, release_ratio=0.0,
    )
    buf = detuned.render(220.0, 1.0, SR)
    window = SR // 20
    levels = [core.peak(buf[i : i + window]) for i in range(0, len(buf) - window, window)]
    assert max(levels) - min(levels) > 0.3


def test_cutoff_sweep_starts_brighter_than_it_ends():
    swept = instruments.Instrument(
        (instruments.Layer("saw"),), attack=0.001, tau=1.0,
        cutoff=300.0, cutoff_sweep=8.0,
    )
    buf = swept.render(110.0, 0.6, SR)
    half = len(buf) // 2
    assert _brightness(buf[:half]) > _brightness(buf[half:])


def test_vibrato_moves_the_pitch():
    steady = instruments.Instrument((instruments.Layer("sine"),), attack=0.001, sustain=1.0)
    wobbly = instruments.Instrument(
        (instruments.Layer("sine"),), attack=0.001, sustain=1.0,
        vibrato_rate=6.0, vibrato_depth=0.03,
    )
    assert steady.render(440.0, 0.5, SR) != wobbly.render(440.0, 0.5, SR)


def test_vibrato_keeps_the_centre_pitch():
    """揺らしても中心の音程は保たれていること。"""
    wobbly = instruments.Instrument(
        (instruments.Layer("sine"),), attack=0.001, sustain=1.0,
        vibrato_rate=6.0, vibrato_depth=0.02,
    )
    buf = wobbly.render(440.0, 0.5, SR)
    assert _goertzel(buf, 440.0, SR) > _goertzel(buf, 415.0, SR)
    assert _goertzel(buf, 440.0, SR) > _goertzel(buf, 466.0, SR)


def test_styles_only_use_known_instruments():
    for name in bgm.style_names():
        style = bgm.STYLES[name]
        for part in ("chord_instrument", "bass_instrument", "lead_instrument"):
            instruments.get(getattr(style, part))


def test_instrument_can_be_overridden_per_track():
    marimba = bgm.generate(bgm.BGMConfig(bars=2, seed=1, sr=SR, lead_instrument="marimba"))
    bell = bgm.generate(bgm.BGMConfig(bars=2, seed=1, sr=SR, lead_instrument="bell"))
    assert marimba != bell


def test_unknown_instrument_override_raises():
    with pytest.raises(ValueError, match="unknown instrument"):
        bgm.generate(bgm.BGMConfig(bars=1, sr=SR, lead_instrument="kazoo"))


def _goertzel(buf, freq, sr):
    w = 2 * math.pi * freq / sr
    cosine, sine = math.cos(w), math.sin(w)
    s1 = s2 = 0.0
    for value in buf:
        s0 = value + 2 * cosine * s1 - s2
        s2, s1 = s1, s0
    return math.hypot(s1 - s2 * cosine, s2 * sine) / len(buf)


def _partials(buf, fundamental, count=6, floor=0.01):
    """基音の整数倍のうち、はっきり鳴っている数を数える。"""
    return sum(1 for n in range(1, count + 1) if _goertzel(buf, fundamental * n, SR) > floor)


def _brightness(buf):
    """隣り合うサンプルの差の大きさ。高い成分が多いほど大きくなる。"""
    return sum(abs(b - a) for a, b in zip(buf, buf[1:])) / max(1, len(buf))

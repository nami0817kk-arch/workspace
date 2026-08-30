"""core / oscillators / envelope / effects の基本動作。"""

from __future__ import annotations

import math
import wave

import pytest

from audiogen import core, effects, envelope, oscillators

SR = 8000  # テストは軽い設定で回す


def test_silence_length_matches_duration():
    assert len(core.silence(0.5, SR)) == 4000


def test_mix_pads_to_longest_track():
    mixed = core.mix([1.0, 1.0], [0.5, 0.5, 0.5])
    assert mixed == [1.5, 1.5, 0.5]


def test_mix_applies_gains():
    assert core.mix([1.0], [1.0], gains=(0.25, 0.5)) == [0.75]


def test_mix_rejects_mismatched_gains():
    with pytest.raises(ValueError):
        core.mix([1.0], [1.0], gains=(0.5,))


def test_add_into_extends_destination():
    dst = [1.0]
    core.add_into(dst, [2.0, 2.0], offset=2)
    assert dst == [1.0, 0.0, 2.0, 2.0]


def test_normalize_hits_target_peak():
    assert core.peak(core.normalize([0.1, -0.2], target=0.8)) == pytest.approx(0.8)


def test_normalize_leaves_silence_untouched():
    assert core.normalize([0.0, 0.0]) == [0.0, 0.0]


def test_remove_dc_centres_the_signal():
    assert core.remove_dc([1.0, 3.0]) == [-1.0, 1.0]


def test_remove_dc_leaves_centred_signals_alone():
    assert core.remove_dc([-0.5, 0.5]) == [-0.5, 0.5]


def test_remove_dc_of_empty_buffer():
    assert core.remove_dc([]) == []


def test_fade_zeroes_the_edges():
    faded = core.fade([1.0] * SR, fade_in=0.1, fade_out=0.1, sr=SR)
    assert faded[0] == 0.0
    assert faded[-1] == 0.0
    assert faded[len(faded) // 2] == pytest.approx(1.0)


def test_wrap_tail_folds_the_reverb_back_to_the_start():
    wrapped = core.wrap_tail([1.0, 1.0, 0.5], length=2)
    assert wrapped == [1.5, 1.0]


def test_wrap_tail_folds_tails_longer_than_the_loop():
    assert core.wrap_tail([1.0, 1.0, 0.5, 0.25, 0.125], length=2) == [1.625, 1.25]


def test_wrap_tail_of_zero_length_is_empty():
    assert core.wrap_tail([1.0, 2.0], length=0) == []


def test_clip_bounds_values():
    assert core.clip(2.0) == 1.0
    assert core.clip(-2.0) == -1.0
    assert core.clip(0.3) == 0.3


def test_to_stereo_interleaves_channels():
    assert core.to_stereo([1.0, 2.0], [3.0, 4.0]) == [1.0, 3.0, 2.0, 4.0]


def test_pan_keeps_constant_power():
    left, right = core.pan([1.0], 0.0)
    assert left[0] == pytest.approx(right[0])
    left, right = core.pan([1.0], -1.0)
    assert right[0] == pytest.approx(0.0, abs=1e-9)


def test_write_wav_roundtrip(tmp_path):
    path = core.write_wav(tmp_path / "out.wav", [0.0, 0.5, -0.5], sr=SR)
    with wave.open(path, "rb") as fp:
        assert fp.getnchannels() == 1
        assert fp.getsampwidth() == 2
        assert fp.getframerate() == SR
        assert fp.getnframes() == 3


def test_write_wav_creates_missing_directories(tmp_path):
    path = core.write_wav(tmp_path / "nested" / "dir" / "out.wav", [0.0], sr=SR)
    assert (tmp_path / "nested" / "dir" / "out.wav").exists()
    assert path.endswith("out.wav")


def test_write_wav_rejects_odd_stereo_buffer(tmp_path):
    with pytest.raises(ValueError):
        core.write_wav(tmp_path / "bad.wav", [0.0, 0.0, 0.0], sr=SR, channels=2)


def test_write_wav_clips_out_of_range_samples(tmp_path):
    path = core.write_wav(tmp_path / "loud.wav", [5.0, -5.0], sr=SR)
    with wave.open(path, "rb") as fp:
        frames = fp.readframes(2)
    assert int.from_bytes(frames[0:2], "little", signed=True) == 32767
    assert int.from_bytes(frames[2:4], "little", signed=True) == -32767


def test_sine_matches_the_analytic_waveform():
    buf = oscillators.sine(1000.0, 0.01, SR)
    for i, value in enumerate(buf):
        assert value == pytest.approx(math.sin(2 * math.pi * 1000.0 * i / SR), abs=1e-9)


def test_oscillator_shapes_stay_in_range():
    for name in oscillators.SHAPES:
        buf = oscillators.render(name, 440.0, 0.02, SR)
        assert max(abs(v) for v in buf) <= 1.0


def test_render_rejects_unknown_shape():
    with pytest.raises(ValueError):
        oscillators.render("kazoo", 440.0, 0.01, SR)


def test_square_duty_controls_the_high_portion():
    buf = oscillators.square(100.0, 0.05, SR, duty=0.25)
    high = sum(1 for value in buf if value > 0)
    assert high / len(buf) == pytest.approx(0.25, abs=0.05)


def test_square_with_default_duty_is_a_plain_square_wave():
    assert set(oscillators.square(100.0, 0.05, SR)) == {1.0, -1.0}


@pytest.mark.parametrize("duty", [0.125, 0.25, 0.5, 0.75])
def test_pulse_shape_integrates_to_zero(duty):
    """デューティ比を変えても波形1周期の平均が 0 になること。"""
    samples = [oscillators.square_shape(i / 10000, duty) for i in range(10000)]
    assert sum(samples) / len(samples) == pytest.approx(0.0, abs=1e-3)
    assert max(abs(v) for v in samples) == pytest.approx(1.0)


@pytest.mark.parametrize("duty", [0.125, 0.25, 0.5, 0.75])
def test_rendered_pulse_waves_have_negligible_dc(duty):
    """レンダリング後も直流成分が実用上無視できる大きさに収まること。"""
    buf = oscillators.square(100.0, 0.1, SR, duty=duty)
    assert abs(sum(buf) / len(buf)) < 0.01
    assert core.peak(buf) == pytest.approx(1.0)


def test_noise_is_reproducible_from_a_seed():
    import random

    a = oscillators.noise(0.01, SR, rng=random.Random(42))
    b = oscillators.noise(0.01, SR, rng=random.Random(42))
    assert a == b


def test_exp_sweep_reaches_the_end_frequency():
    fn = oscillators.sweep(100.0, 800.0, 1.0)
    assert fn(0.0) == pytest.approx(100.0)
    assert fn(1.0) == pytest.approx(800.0)
    assert fn(5.0) == pytest.approx(800.0)  # 終了後はクランプされる


def test_linear_sweep_is_halfway_at_the_midpoint():
    fn = oscillators.sweep(100.0, 300.0, 1.0, curve="linear")
    assert fn(0.5) == pytest.approx(200.0)


def test_steps_switches_frequency_on_schedule():
    fn = oscillators.steps([100.0, 200.0], 0.1)
    assert fn(0.05) == 100.0
    assert fn(0.15) == 200.0
    assert fn(9.0) == 200.0


def test_adsr_starts_and_ends_at_zero():
    env = envelope.adsr(1.0, 0.1, 0.1, 0.5, 0.2, SR)
    assert len(env) == SR
    assert env[0] == 0.0
    assert env[-1] == pytest.approx(0.0, abs=0.02)
    assert max(env) == pytest.approx(1.0, abs=0.02)


def test_adsr_shrinks_stages_that_do_not_fit():
    env = envelope.adsr(0.05, attack=1.0, decay=1.0, sustain=0.5, release=1.0, sr=SR)
    assert len(env) == envelope.num_samples(0.05, SR)


def test_percussive_envelope_decays_monotonically():
    env = envelope.percussive(0.5, tau=0.1, attack=0.001, sr=SR)
    peak_index = env.index(max(env))
    tail = env[peak_index:]
    assert all(b <= a + 1e-12 for a, b in zip(tail, tail[1:]))


def test_apply_truncates_to_the_envelope():
    assert envelope.apply([1.0, 1.0, 1.0], [0.5, 0.5]) == [0.5, 0.5]


def test_lowpass_attenuates_high_frequencies_more():
    low = effects.lowpass(oscillators.sine(200.0, 0.2, SR), 400.0, SR)
    high = effects.lowpass(oscillators.sine(3000.0, 0.2, SR), 400.0, SR)
    assert core.peak(high) < core.peak(low)


def test_highpass_attenuates_low_frequencies_more():
    low = effects.highpass(oscillators.sine(50.0, 0.2, SR), 1000.0, SR)
    high = effects.highpass(oscillators.sine(3000.0, 0.2, SR), 1000.0, SR)
    assert core.peak(low) < core.peak(high)


def test_delay_adds_a_tail_and_repeats_the_signal():
    impulse = [1.0] + [0.0] * (SR // 10)
    out = effects.delay(impulse, time=0.01, feedback=0.5, wet=1.0, sr=SR, tail=0.05)
    assert len(out) > len(impulse)
    assert out[int(0.01 * SR)] == pytest.approx(0.5, abs=1e-6)


def test_reverb_extends_the_signal_and_stays_bounded():
    out = effects.reverb(oscillators.sine(440.0, 0.05, SR), sr=SR, tail=0.2)
    assert len(out) > int(0.05 * SR)
    assert core.peak(out) < 10.0


def test_distort_is_bounded_and_monotonic():
    out = effects.distort([-1.0, -0.5, 0.0, 0.5, 1.0], drive=4.0)
    assert max(abs(v) for v in out) <= 1.0
    assert all(a < b for a, b in zip(out, out[1:]))


def test_bitcrush_quantizes_to_few_levels():
    ramp = [i / 100 * 2 - 1 for i in range(101)]
    out = effects.bitcrush(ramp, bits=2)
    assert len(set(out)) <= 4


def test_bitcrush_downsample_holds_values():
    out = effects.bitcrush([0.1, 0.9, -0.9, 0.4], bits=16, downsample=2)
    assert out[0] == out[1]
    assert out[2] == out[3]


def test_tremolo_modulates_amplitude():
    out = effects.tremolo([1.0] * SR, rate=2.0, depth=1.0, sr=SR)
    assert min(out) < 0.1
    assert max(out) > 0.9

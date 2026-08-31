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


def test_square_without_antialiasing_is_a_plain_square_wave():
    assert set(oscillators.square(100.0, 0.05, SR, antialias=False)) == {1.0, -1.0}


def test_antialiasing_only_smooths_the_edges():
    """帯域制限をかけても、段差の前後以外は素の矩形波と同じ値であること。"""
    plain = oscillators.square(100.0, 0.05, SR, antialias=False)
    smooth = oscillators.square(100.0, 0.05, SR)
    differing = [i for i, (a, b) in enumerate(zip(plain, smooth)) if a != b]
    edges_per_second = 2 * 100.0
    assert 0 < len(differing) <= 2 * edges_per_second * 0.05 + 2


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


def test_pulse_shape_reuses_instances():
    assert oscillators.pulse_shape(0.25) is oscillators.pulse_shape(0.25)
    assert oscillators.pulse_shape(0.25) is not oscillators.pulse_shape(0.5)


def test_pulse_object_matches_the_shape_function():
    pulse = oscillators.Pulse(0.3)
    for phase in (0.0, 0.1, 0.29, 0.31, 0.9):
        assert pulse(phase) == oscillators.square_shape(phase, 0.3)


def test_constant_frequency_fast_path_matches_the_generic_loop():
    """固定周波数の高速経路が、汎用の積算ループと同じ音を出すこと。"""
    fast = oscillators.render("sine", 300.0, 0.05, SR)
    generic = oscillators.render("sine", lambda _t: 300.0, 0.05, SR)
    assert fast == pytest.approx(generic, abs=1e-9)


def test_fast_path_matches_the_generic_loop_except_at_wrap_points():
    """不連続な波形では、位相が 0 に折り返す瞬間だけ丸め方の違いが出る。

    その差はサイクルごとに高々1サンプルで、それ以外は完全に一致する。
    """
    freq, duration = 300.0, 0.05
    fast = oscillators.render("saw", freq, duration, SR)
    generic = oscillators.render("saw", lambda _t: freq, duration, SR)
    differing = [i for i, (a, b) in enumerate(zip(fast, generic)) if abs(a - b) > 1e-6]
    assert len(differing) <= int(freq * duration) + 1
    period = SR / freq
    for index in differing:
        offset = index % period
        assert min(offset, period - offset) < 1.0  # 位相の折り返し位置にだけ現れる


def test_write_wav_rounds_rather_than_truncates(tmp_path):
    path = core.write_wav(tmp_path / "round.wav", [0.99999], sr=SR)
    with wave.open(path, "rb") as fp:
        frames = fp.readframes(1)
    assert int.from_bytes(frames[0:2], "little", signed=True) == 32767


# --- 帯域制限(エイリアシング対策) -------------------------------------------


def _goertzel(buf, freq, sr):
    """1周波数だけの離散フーリエ変換。スペクトルの一点を測るのに使う。"""
    w = 2 * math.pi * freq / sr
    cosine, sine = math.cos(w), math.sin(w)
    s1 = s2 = 0.0
    for value in buf:
        s0 = value + 2 * cosine * s1 - s2
        s2, s1 = s1, s0
    return math.hypot(s1 - s2 * cosine, s2 * sine) / len(buf)


@pytest.mark.parametrize("shape", ["saw", "square", "pulse25"])
def test_antialiasing_suppresses_folded_partials(shape):
    """折り返してきた倍音が、帯域制限によって桁違いに小さくなること。

    3000Hz を 8000Hz で鳴らすと 3倍音 9000Hz は 1000Hz に折り返す。
    そこは本来の倍音列にない周波数なので、残っていればエイリアシング。
    """
    freq, folded = 3000.0, 1000.0
    plain = oscillators.render(shape, freq, 0.25, SR, antialias=False)
    limited = oscillators.render(shape, freq, 0.25, SR)
    assert _goertzel(limited, folded, SR) < 0.05 * _goertzel(plain, folded, SR)


@pytest.mark.parametrize("shape", ["saw", "square"])
def test_antialiasing_keeps_the_fundamental(shape):
    """基音の大きさは帯域制限の前後でほとんど変わらないこと。"""
    freq = 500.0
    plain = oscillators.render(shape, freq, 0.2, SR, antialias=False)
    limited = oscillators.render(shape, freq, 0.2, SR)
    assert _goertzel(limited, freq, SR) == pytest.approx(_goertzel(plain, freq, SR), rel=0.1)


@pytest.mark.parametrize("shape", ["saw", "square", "pulse25", "pulse12"])
def test_fast_and_reference_bandlimiting_agree(shape):
    """段差だけ補正する高速版と、1サンプルずつ補正する参照版が一致すること。"""
    freq = 700.0
    fast = oscillators.render(shape, freq, 0.05, SR)
    reference = oscillators.render(shape, lambda _t: freq, 0.05, SR)
    differing = [i for i, (a, b) in enumerate(zip(fast, reference)) if abs(a - b) > 1e-9]
    assert len(differing) <= int(freq * 0.05) + 1  # 位相の折り返し位置のみ


@pytest.mark.parametrize("shape", ["saw", "square", "pulse25", "pulse12"])
def test_bandlimited_output_stays_in_range_and_dc_free(shape):
    buf = oscillators.render(shape, 1200.0, 0.1, SR)
    assert core.peak(buf) <= 1.0
    assert abs(sum(buf) / len(buf)) < 0.01


def test_antialiasing_is_skipped_at_and_above_nyquist():
    """1サンプルあたりの位相が半周を超えると PolyBLEP は成り立たないので素の波形に戻る。"""
    buf = oscillators.render("square", SR * 0.5, 0.01, SR)
    assert set(buf) == {1.0, -1.0}


def test_sine_ignores_the_antialias_flag():
    assert oscillators.sine(440.0, 0.01, SR) == oscillators.sine(440.0, 0.01, SR, antialias=False)


# --- マスター段(リミッター・サイドチェイン) ---------------------------------


def test_limiter_pulls_loud_material_down_to_the_threshold():
    loud = [0.9 * math.sin(i * 0.1) for i in range(SR)]
    limited = effects.limiter(loud, threshold=0.5, sr=SR)
    assert core.peak(limited[SR // 2 :]) == pytest.approx(0.5, abs=0.06)


def test_limiter_leaves_quiet_material_alone():
    quiet = [0.2 * math.sin(i * 0.1) for i in range(SR // 2)]
    assert effects.limiter(quiet, threshold=0.7, sr=SR) == pytest.approx(quiet, abs=1e-9)


def test_mastering_chain_raises_loudness_at_the_same_peak():
    """まばらに飛び出す音に引きずられず、全体を持ち上げられること。

    ピーク正規化だけだと、たまに出る大きな音に合わせて曲全体が小さくなる。
    リミッターで山を削ってから正規化すると、同じピークでも中身が大きくなる。
    """
    signal = [0.3 * math.sin(i * 0.05) for i in range(SR * 2)]
    for position in (SR // 2, SR, SR + SR // 2):
        for k in range(int(0.02 * SR)):
            signal[position + k] = 0.95 * math.sin((position + k) * 0.05)

    plain = core.normalize(signal, 0.9)
    mastered = core.normalize(
        effects.soft_clip(effects.limiter(signal, threshold=0.4, sr=SR), 0.98), 0.9
    )
    assert _rms(mastered) > _rms(plain) * 1.1
    assert core.peak(mastered) == pytest.approx(0.9)


def test_limiter_alone_does_not_lift_evenly_loud_material():
    """全体が一様に大きい音では、削る山がないので得はしない(副作用の確認)。"""
    steady = [0.8 * math.sin(i * 0.05) for i in range(SR)]
    limited = effects.limiter(steady, threshold=0.4, sr=SR)
    assert core.peak(limited[SR // 2 :]) < core.peak(steady)


def test_limiter_of_an_empty_buffer():
    assert effects.limiter([], sr=SR) == []


def test_soft_clip_never_exceeds_the_ceiling():
    clipped = effects.soft_clip([-3.0, -1.0, 0.0, 1.0, 3.0], ceiling=0.9)
    assert max(abs(value) for value in clipped) < 0.9
    assert all(a < b for a, b in zip(clipped, clipped[1:]))


def test_soft_clip_barely_touches_quiet_material():
    assert effects.soft_clip([0.05, -0.05], ceiling=0.98) == pytest.approx([0.05, -0.05], abs=1e-3)


def test_sidechain_envelope_dips_at_each_trigger():
    env = effects.sidechain_envelope([0.0, 0.5], SR, sr=SR, amount=0.4)
    assert len(env) == SR
    assert min(env[: SR // 4]) == pytest.approx(0.6, abs=1e-6)
    assert min(env[SR // 2 : 3 * SR // 4]) == pytest.approx(0.6, abs=1e-6)
    assert max(env) == pytest.approx(1.0)
    assert min(env) >= 0.6 - 1e-9


def test_sidechain_envelope_recovers_between_triggers():
    env = effects.sidechain_envelope([0.0], SR, sr=SR, amount=0.5, attack=0.005, release=0.1)
    assert env[-1] == pytest.approx(1.0)


def test_sidechain_envelope_without_triggers_is_flat():
    assert set(effects.sidechain_envelope([], 100, sr=SR, amount=0.5)) == {1.0}


def test_sidechain_envelope_with_zero_amount_is_flat():
    assert set(effects.sidechain_envelope([0.0, 0.1], 100, sr=SR, amount=0.0)) == {1.0}


def test_sidechain_ignores_triggers_past_the_end():
    assert set(effects.sidechain_envelope([10.0], 100, sr=SR, amount=0.5)) == {1.0}


def _rms(buf):
    return math.sqrt(sum(value * value for value in buf) / len(buf))


# --- 帯域バランス(シェルフ / バンド) ---------------------------------------


def _band_level(buf, freq):
    """指定周波数の正弦波成分の大きさ。"""
    w = 2 * math.pi * freq / SR
    cosine, sine = math.cos(w), math.sin(w)
    s1 = s2 = 0.0
    for value in buf:
        s0 = value + 2 * cosine * s1 - s2
        s2, s1 = s1, s0
    return math.hypot(s1 - s2 * cosine, s2 * sine) / len(buf)


def _shift_db(processed, plain, freq):
    return 20 * math.log10(_band_level(processed, freq) / _band_level(plain, freq))


# 1次フィルタなので肩は緩く、帯域外にも 1dB 弱は漏れる。実用上は問題ない範囲。
LEAKAGE_DB = 1.0


def test_high_shelf_lifts_the_top_and_leaves_the_bottom():
    low = oscillators.sine(80.0, 0.3, SR)
    high = oscillators.sine(3000.0, 0.3, SR)
    assert _shift_db(effects.high_shelf(high, 1200.0, 6.0, SR), high, 3000.0) > 4.0
    assert abs(_shift_db(effects.high_shelf(low, 1200.0, 6.0, SR), low, 80.0)) < LEAKAGE_DB


def test_low_shelf_lifts_the_bottom_and_leaves_the_top():
    low = oscillators.sine(60.0, 0.3, SR)
    high = oscillators.sine(3000.0, 0.3, SR)
    assert _shift_db(effects.low_shelf(low, 200.0, 6.0, SR), low, 60.0) > 4.0
    assert abs(_shift_db(effects.low_shelf(high, 200.0, 6.0, SR), high, 3000.0)) < LEAKAGE_DB


def test_band_gain_only_touches_the_chosen_band():
    inside = oscillators.sine(300.0, 0.3, SR)
    outside = oscillators.sine(2500.0, 0.3, SR)
    assert _shift_db(effects.band_gain(inside, 200.0, 450.0, -6.0, SR), inside, 300.0) < -2.0
    assert abs(_shift_db(effects.band_gain(outside, 200.0, 450.0, -6.0, SR), outside, 2500.0)) < LEAKAGE_DB


@pytest.mark.parametrize("shaper", ["low_shelf", "high_shelf"])
def test_zero_db_passes_the_signal_through(shaper):
    tone = oscillators.sine(440.0, 0.05, SR)
    assert getattr(effects, shaper)(tone, 1000.0, 0.0, SR) == tone


def test_band_gain_of_zero_db_passes_through():
    tone = oscillators.sine(440.0, 0.05, SR)
    assert effects.band_gain(tone, 200.0, 400.0, 0.0, SR) == tone


@pytest.mark.parametrize("rate,limit_db", [(8000, -40), (22050, -50), (44100, -55)])
def test_block_updated_filter_coefficients_match_per_sample_updates(rate, limit_db):
    """係数をブロック単位で更新しても、音は実質変わらないこと。

    誤差はブロックの長さ(秒)に比例するので、サンプリング周波数が低いほど
    大きくなる。既定の 44.1kHz では -55dB 以下、8kHz でも -40dB 以下に収まる。
    """
    buf = oscillators.saw(220.0, 0.5, rate)
    sweep = oscillators.sweep(3000.0, 200.0, 0.5)

    blocked = effects.lowpass(buf, sweep, rate)
    original = effects.FILTER_BLOCK
    try:
        effects.FILTER_BLOCK = 1
        per_sample = effects.lowpass(buf, sweep, rate)
    finally:
        effects.FILTER_BLOCK = original

    error = max(abs(a - b) for a, b in zip(blocked, per_sample))
    assert 20 * math.log10(error / core.peak(per_sample)) < limit_db


def test_a_constant_cutoff_is_unaffected_by_the_block_size():
    buf = oscillators.saw(220.0, 0.2, SR)
    original = effects.FILTER_BLOCK
    try:
        effects.FILTER_BLOCK = 1
        one = effects.lowpass(buf, 800.0, SR)
    finally:
        effects.FILTER_BLOCK = original
    assert effects.lowpass(buf, 800.0, SR) == one


# --- 体感音量 -----------------------------------------------------------------


def test_loudness_tracks_amplitude():
    """振幅を半分にすると 6dB 下がること。"""
    tone = oscillators.sine(1000.0, 1.5, SR)
    half = [v * 0.5 for v in tone]
    assert core.loudness(tone, SR) - core.loudness(half, SR) == pytest.approx(6.0, abs=0.1)


def test_silence_reports_the_gate_level():
    assert core.loudness([0.0] * SR, SR) == core.ABSOLUTE_GATE
    assert core.loudness([], SR) == core.ABSOLUTE_GATE


def test_loudness_weights_the_midrange_above_the_bass():
    """同じ振幅でも、低い音のほうが小さく聞こえる重み付けになっていること。"""
    low = oscillators.sine(50.0, 1.5, SR)
    mid = oscillators.sine(1000.0, 1.5, SR)
    assert core.loudness(low, SR) < core.loudness(mid, SR)


def test_loudness_ignores_a_long_silent_tail():
    """静かな区間は平均から外れるので、後ろに無音を足しても値が変わらないこと。"""
    tone = oscillators.sine(1000.0, 2.0, SR)
    padded = tone + [0.0] * (SR * 3)
    assert core.loudness(padded, SR) == pytest.approx(core.loudness(tone, SR), abs=0.5)


def test_normalize_loudness_hits_the_target_when_there_is_headroom():
    quiet = [v * 0.05 for v in oscillators.sine(1000.0, 1.5, SR)]
    louder = core.normalize_loudness(quiet, target=-16.0, sr=SR)
    assert core.loudness(louder, SR) == pytest.approx(-16.0, abs=0.05)


def test_normalize_loudness_stops_at_the_ceiling():
    """目標に届かなくても、天井を越えて歪ませないこと。"""
    dense = oscillators.sine(1000.0, 1.5, SR)
    result = core.normalize_loudness(dense, target=0.0, sr=SR, ceiling=0.5)
    assert core.peak(result) == pytest.approx(0.5)
    assert core.loudness(result, SR) < 0.0


def test_normalize_loudness_of_silence_is_unchanged():
    assert core.normalize_loudness([0.0, 0.0], sr=SR) == [0.0, 0.0]
    assert core.normalize_loudness([], sr=SR) == []


# --- ステレオのマスター処理 ---------------------------------------------------


def test_stereo_reverb_decorrelates_the_two_channels():
    """左右の残響が食い違い、1点から鳴っているようには聞こえないこと。"""
    tone = oscillators.sine(440.0, 0.2, SR)
    left, right = effects.reverb_stereo(tone, sr=SR, tail=0.4)
    assert _correlation(left, right) < 0.9


def test_stereo_reverb_survives_a_mono_fold_down():
    """モノラルにまとめても打ち消しで消えないこと。"""
    tone = oscillators.sine(440.0, 0.2, SR)
    left, right = effects.reverb_stereo(tone, sr=SR, tail=0.4)
    summed = [(a + b) * 0.5 for a, b in zip(left, right)]
    assert core.peak(summed) > core.peak(left) * 0.6


def test_a_wider_spread_decorrelates_more():
    tone = oscillators.sine(440.0, 0.2, SR)
    narrow = effects.reverb_stereo(tone, sr=SR, tail=0.4, spread=0.002)
    wide = effects.reverb_stereo(tone, sr=SR, tail=0.4, spread=0.06)
    assert _correlation(*wide) < _correlation(*narrow)


def test_the_linked_limiter_applies_one_gain_to_both_channels():
    """片方だけ抑えて音像が横へ動かないこと。"""
    loud = [0.9 * math.sin(i * 0.05) for i in range(SR)]
    quiet = [0.2 * math.sin(i * 0.05) for i in range(SR)]
    left, right = effects.linked_limiter([loud, quiet], threshold=0.4, sr=SR)
    ratios = [b / a for a, b in zip(quiet[SR // 2 :], right[SR // 2 :]) if abs(a) > 0.05]
    assert max(ratios) - min(ratios) < 0.05  # 右も左と同じ倍率で動く


def test_the_linked_limiter_matches_the_plain_limiter_on_one_channel():
    tone = [0.9 * math.sin(i * 0.05) for i in range(SR // 2)]
    assert effects.linked_limiter([tone], threshold=0.5, sr=SR)[0] == effects.limiter(
        tone, threshold=0.5, sr=SR
    )


def test_the_linked_limiter_of_empty_input():
    assert effects.linked_limiter([]) == []
    assert effects.linked_limiter([[]]) == [[]]


def _correlation(a, b):
    mean_a, mean_b = sum(a) / len(a), sum(b) / len(b)
    numerator = sum((x - mean_a) * (y - mean_b) for x, y in zip(a, b))
    da = math.sqrt(sum((x - mean_a) ** 2 for x in a))
    db = math.sqrt(sum((y - mean_b) ** 2 for y in b))
    return numerator / (da * db) if da and db else 1.0

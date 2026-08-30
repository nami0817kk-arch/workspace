"""効果音プリセットのテスト。"""

from __future__ import annotations

import pytest

from audiogen import core, sfx

SR = 11025


@pytest.mark.parametrize("name", sorted(sfx.PRESETS))
def test_every_preset_produces_audible_bounded_audio(name):
    buf = sfx.generate(name, sr=SR, seed=0)
    assert len(buf) > 0
    peak = core.peak(buf)
    assert 0.3 < peak <= 1.0, f"{name}: peak={peak}"


@pytest.mark.parametrize("name", sorted(sfx.PRESETS))
def test_every_preset_stays_under_three_seconds(name):
    buf = sfx.generate(name, sr=SR, seed=0)
    assert core.duration_of(buf, SR) < 3.0


@pytest.mark.parametrize("name", sorted(sfx.PRESETS))
def test_every_preset_starts_and_ends_quietly(name):
    """先頭・末尾が無音に近いこと(プチッというノイズが出ない)。"""
    buf = sfx.generate(name, sr=SR, seed=0)
    assert abs(buf[0]) < 0.05
    assert abs(buf[-1]) < 0.05


@pytest.mark.parametrize("name", sorted(sfx.PRESETS))
def test_every_preset_is_free_of_dc_offset(name):
    buf = sfx.generate(name, sr=SR, seed=0)
    assert abs(sum(buf) / len(buf)) < 0.01


@pytest.mark.parametrize("name", sorted(sfx.PRESETS))
def test_seeded_presets_are_deterministic(name):
    assert sfx.generate(name, sr=SR, seed=7) == sfx.generate(name, sr=SR, seed=7)


def test_unknown_preset_raises():
    with pytest.raises(ValueError, match="unknown sfx preset"):
        sfx.generate("nope")


def test_available_lists_every_preset():
    assert sfx.available() == sorted(sfx.PRESETS)
    assert "coin" in sfx.available()


def test_pitch_parameter_shifts_the_sound():
    low = sfx.generate("coin", sr=SR, pitch=0.5)
    high = sfx.generate("coin", sr=SR, pitch=2.0)
    assert _zero_crossings(low) < _zero_crossings(high)


def test_noise_presets_differ_between_seeds():
    assert sfx.generate("explosion", sr=SR, seed=1) != sfx.generate("explosion", sr=SR, seed=2)


def _zero_crossings(buf) -> int:
    return sum(1 for a, b in zip(buf, buf[1:]) if (a < 0) != (b < 0))

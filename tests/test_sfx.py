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


# --- バリエーション -----------------------------------------------------------


def test_variations_returns_the_requested_number_of_takes():
    takes = sfx.variations("footstep", count=5, sr=SR, seed=1)
    assert len(takes) == 5
    assert all(len(take) > 0 for take in takes)


def test_variations_all_differ_from_each_other():
    takes = sfx.variations("hit", count=4, sr=SR, seed=2)
    for index, take in enumerate(takes):
        for other in takes[index + 1 :]:
            assert take != other


def test_the_first_variation_keeps_the_requested_pitch():
    """1つ目は指定どおりの音程にしておき、2つ目以降を散らす。"""
    takes = sfx.variations("coin", count=4, sr=SR, seed=3, spread=0.2)
    plain = sfx.generate("coin", sr=SR)
    assert _zero_crossings(takes[0]) == _zero_crossings(plain)
    assert any(_zero_crossings(take) != _zero_crossings(plain) for take in takes[1:])


def test_variations_are_reproducible():
    assert sfx.variations("shatter", count=3, sr=SR, seed=7) == sfx.variations(
        "shatter", count=3, sr=SR, seed=7
    )


def test_variations_stay_close_in_character():
    """音程は散らすが、長さは大きく変わらないこと。"""
    takes = sfx.variations("coin", count=6, sr=SR, seed=4, spread=0.12)
    lengths = [len(take) for take in takes]
    assert max(lengths) == min(lengths)  # 長さは変えていない
    assert all(0.3 < core.peak(take) <= 1.0 for take in takes)


def test_zero_spread_only_changes_the_noise():
    """ばらつき 0 なら、音程は変わらず種だけが変わること。"""
    takes = sfx.variations("coin", count=3, sr=SR, seed=5, spread=0.0)
    assert all(take == takes[0] for take in takes)  # coin はノイズを使わない


def test_variations_reject_a_zero_count():
    with pytest.raises(ValueError, match="count"):
        sfx.variations("coin", count=0, sr=SR)


def test_variations_reject_an_unknown_preset():
    with pytest.raises(ValueError, match="unknown sfx preset"):
        sfx.variations("kazoo", count=2, sr=SR)


@pytest.mark.parametrize("name", sorted(sfx.PRESETS))
def test_every_preset_accepts_pitch(name):
    low = sfx.generate(name, sr=SR, seed=0, pitch=0.7)
    high = sfx.generate(name, sr=SR, seed=0, pitch=1.4)
    assert low != high

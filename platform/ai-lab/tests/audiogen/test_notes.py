"""音名・音階・和音のテスト。"""

from __future__ import annotations

import pytest

from audiogen import notes


def test_a4_is_440hz():
    assert notes.note_to_freq("A4") == pytest.approx(440.0)


def test_middle_c_frequency():
    assert notes.note_to_freq("C4") == pytest.approx(261.6256, abs=1e-3)


def test_octave_up_doubles_the_frequency():
    assert notes.note_to_freq("A5") == pytest.approx(2 * notes.note_to_freq("A4"))


@pytest.mark.parametrize(
    "name,midi",
    [("C-1", 0), ("C4", 60), ("A4", 69), ("C#3", 49), ("Db3", 49), ("Bb3", 58), ("G9", 127)],
)
def test_note_to_midi(name, midi):
    assert notes.note_to_midi(name) == midi


@pytest.mark.parametrize("name", ["H4", "C", "4C", "", "C#x"])
def test_invalid_note_names_raise(name):
    with pytest.raises(ValueError):
        notes.note_to_midi(name)


def test_midi_to_name_roundtrip():
    for midi in range(0, 128):
        assert notes.note_to_midi(notes.midi_to_name(midi)) == midi


def test_scale_notes_spans_requested_octaves():
    scale = notes.scale_notes("C4", "major", octaves=2)
    assert len(scale) == 14
    assert scale[0] == 60
    assert scale[7] == 72


def test_unknown_scale_raises():
    with pytest.raises(ValueError):
        notes.scale_notes("C4", "bebop")


def test_degree_to_midi_wraps_across_octaves():
    assert notes.degree_to_midi("C4", "major", 0) == 60
    assert notes.degree_to_midi("C4", "major", 7) == 72
    assert notes.degree_to_midi("C4", "major", -1) == 59  # 下のオクターブの B


def test_chord_midi_builds_a_major_triad():
    assert notes.chord_midi("C4", "maj") == [60, 64, 67]


def test_chord_inversion_moves_the_bottom_note_up():
    assert notes.chord_midi("C4", "maj", inversion=1) == [64, 67, 72]


def test_unknown_chord_raises():
    with pytest.raises(ValueError):
        notes.chord_midi("C4", "mystery")


def test_diatonic_chord_in_c_major():
    assert notes.diatonic_chord("C4", "major", 0) == [60, 64, 67]  # C
    assert notes.diatonic_chord("C4", "major", 4) == [67, 71, 74]  # G
    assert notes.diatonic_chord("C4", "major", 5) == [69, 72, 76]  # Am


def test_diatonic_seventh_adds_a_fourth_note():
    assert notes.diatonic_chord("C4", "major", 0, seventh=True) == [60, 64, 67, 71]


@pytest.mark.parametrize(
    "text,expected",
    [
        ("I-V-vi-IV", [0, 4, 5, 3]),
        ("i VI VII v", [0, 5, 6, 4]),
        ("I,IV,V", [0, 3, 4]),
        ("ii7-V7-I", [1, 4, 0]),
    ],
)
def test_parse_progression(text, expected):
    assert notes.parse_progression(text) == expected


@pytest.mark.parametrize("text", ["", "IX-V", "hello"])
def test_invalid_progression_raises(text):
    with pytest.raises(ValueError):
        notes.parse_progression(text)


# --- 声部連結 -----------------------------------------------------------------


def test_voice_leading_moves_less_than_root_position():
    """基本形で並べるより、声部の移動量が小さくなること。"""
    root = notes.note_to_midi("C4")
    progression = [notes.diatonic_chord(root, "major", d) for d in (0, 3, 4, 0)]

    plain = sum(notes.voice_movement(a, b) for a, b in zip(progression, progression[1:]))
    voiced, previous = [], None
    for chord in progression:
        previous = notes.voice_lead(chord, previous)
        voiced.append(previous)
    led = sum(notes.voice_movement(a, b) for a, b in zip(voiced, voiced[1:]))

    assert led < plain / 2


def test_voice_leading_keeps_the_same_notes():
    """鳴る音の種類は変えず、オクターブだけ選び直すこと。"""
    root = notes.note_to_midi("C4")
    chord = notes.diatonic_chord(root, "major", 4)
    voiced = notes.voice_lead(chord, [60, 65, 69])
    assert sorted(m % 12 for m in voiced) == sorted(m % 12 for m in chord)
    assert len(voiced) == len(chord)


def test_voice_leading_without_a_previous_chord_is_the_plain_chord():
    chord = notes.diatonic_chord(notes.note_to_midi("C4"), "major", 3)
    assert notes.voice_lead(chord, None) == sorted(chord)
    assert notes.voice_lead(chord, []) == sorted(chord)


def test_voice_leading_stays_in_register():
    """連結を優先しすぎて音域が上下へ流れていかないこと。"""
    root = notes.note_to_midi("C4")
    previous = None
    for degree in [0, 4, 1, 5, 2, 6, 3] * 3:  # わざと跳ねる進行を長く続ける
        chord = notes.diatonic_chord(root, "major", degree)
        previous = notes.voice_lead(chord, previous)
        centre = sum(previous) / len(previous)
        nominal = sum(chord) / len(chord)
        assert abs(centre - nominal) <= 7


def test_voice_leading_handles_seventh_chords():
    root = notes.note_to_midi("C4")
    chord = notes.diatonic_chord(root, "major", 4, seventh=True)
    voiced = notes.voice_lead(chord, [60, 64, 67])
    assert len(voiced) == 4
    assert sorted(m % 12 for m in voiced) == sorted(m % 12 for m in chord)


def test_voice_movement_pairs_equal_sized_chords_in_order():
    assert notes.voice_movement([60, 64, 67], [60, 64, 67]) == 0
    assert notes.voice_movement([60, 64, 67], [62, 65, 69]) == 2 + 1 + 2


def test_voice_movement_of_an_empty_chord_is_zero():
    assert notes.voice_movement([], [60]) == 0
    assert notes.voice_movement([60], []) == 0


# --- 借用和音 -----------------------------------------------------------------


def test_a_flat_seven_lowers_the_root_and_turns_major():
    """C メジャーの ♭VII は B♭ の長三和音(音階どおりなら B の減三和音)。"""
    degree = notes.parse_progression("bVII")[0]
    assert degree == 6 and degree.alter == -1
    chord = notes.progression_chord("C4", "major", degree)
    assert [notes.midi_to_name(m) for m in chord] == ["A#4", "D5", "F5"]


def test_a_plain_numeral_still_gives_the_diatonic_chord():
    degree = notes.parse_progression("vii")[0]
    assert degree.alter == 0
    assert notes.progression_chord("C4", "major", degree) == notes.diatonic_chord(
        "C4", "major", 6
    )


@pytest.mark.parametrize("token", ["bVII", "♭VII", "bvii"])
def test_flat_signs_are_accepted_in_either_form(token):
    assert notes.parse_progression(token)[0].alter == -1


def test_a_sharp_raises_the_root():
    assert notes.parse_progression("#IV")[0].alter == 1


def test_the_borrowed_degrees_of_a_sports_rock_loop():
    """I-bVII-IV は、メジャーのまま ♭VII を借りるスポーツ中継の定番。"""
    degrees = notes.parse_progression("I-bVII-IV-I")
    assert [(int(d), d.alter) for d in degrees] == [(0, 0), (6, -1), (3, 0), (0, 0)]


def test_a_degree_still_behaves_as_an_int():
    """既存のコードは度数を int として扱うので、そのまま使えること。"""
    degree = notes.parse_progression("bVII")[0]
    assert degree + 1 == 7
    assert [0, 1, 2, 3, 4, 5, 6][degree] == 6


def test_an_unknown_numeral_names_what_is_allowed():
    with pytest.raises(ValueError, match="bVII"):
        notes.parse_progression("H")

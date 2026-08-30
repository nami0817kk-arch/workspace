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

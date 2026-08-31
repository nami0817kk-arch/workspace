"""音名・音階・和音のユーティリティ。

MIDI ノート番号を基準に扱う(69 = A4 = 440Hz)。
"""

from __future__ import annotations

import itertools
import re
from typing import Sequence

A4_MIDI = 69
A4_FREQ = 440.0

_PITCH_CLASS = {
    "C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11,
}
_ACCIDENTALS = {"#": 1, "s": 1, "b": -1}
# ``-`` はフラットではなく負のオクターブ(C-1 など)として扱う。
_NOTE_RE = re.compile(r"^([A-Ga-g])([#sb]*)(-?\d+)$")

NOTE_NAMES = ("C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B")

SCALES: dict[str, tuple[int, ...]] = {
    "major": (0, 2, 4, 5, 7, 9, 11),
    "minor": (0, 2, 3, 5, 7, 8, 10),
    "harmonic_minor": (0, 2, 3, 5, 7, 8, 11),
    "dorian": (0, 2, 3, 5, 7, 9, 10),
    "phrygian": (0, 1, 3, 5, 7, 8, 10),
    "lydian": (0, 2, 4, 6, 7, 9, 11),
    "mixolydian": (0, 2, 4, 5, 7, 9, 10),
    "pentatonic_major": (0, 2, 4, 7, 9),
    "pentatonic_minor": (0, 3, 5, 7, 10),
    "blues": (0, 3, 5, 6, 7, 10),
    "whole_tone": (0, 2, 4, 6, 8, 10),
}

CHORDS: dict[str, tuple[int, ...]] = {
    "maj": (0, 4, 7),
    "min": (0, 3, 7),
    "dim": (0, 3, 6),
    "aug": (0, 4, 8),
    "sus2": (0, 2, 7),
    "sus4": (0, 5, 7),
    "maj7": (0, 4, 7, 11),
    "min7": (0, 3, 7, 10),
    "dom7": (0, 4, 7, 10),
    "add9": (0, 4, 7, 14),
    "power": (0, 7),
}

_ROMAN = {"i": 0, "ii": 1, "iii": 2, "iv": 3, "v": 4, "vi": 5, "vii": 6}


def midi_to_freq(midi: float) -> float:
    """MIDI ノート番号を周波数 (Hz) に変換する。"""
    return A4_FREQ * (2.0 ** ((midi - A4_MIDI) / 12.0))


def note_to_midi(name: str) -> int:
    """``"A4"`` ``"C#3"`` ``"Bb5"`` などの音名を MIDI ノート番号にする。"""
    match = _NOTE_RE.match(name.strip())
    if not match:
        raise ValueError(f"invalid note name: {name!r}")
    letter, accidentals, octave = match.groups()
    midi = _PITCH_CLASS[letter.upper()] + (int(octave) + 1) * 12
    for accidental in accidentals:
        midi += _ACCIDENTALS[accidental]
    return midi


def note_to_freq(name: str) -> float:
    """音名を周波数 (Hz) に変換する。"""
    return midi_to_freq(note_to_midi(name))


def midi_to_name(midi: int) -> str:
    """MIDI ノート番号を音名にする。"""
    return f"{NOTE_NAMES[midi % 12]}{midi // 12 - 1}"


def scale_degrees(scale: str) -> tuple[int, ...]:
    """音階名から半音間隔のタプルを取り出す。"""
    try:
        return SCALES[scale]
    except KeyError:
        raise ValueError(f"unknown scale: {scale!r} (available: {', '.join(sorted(SCALES))})") from None


def scale_notes(root: int | str, scale: str = "major", octaves: int = 2) -> list[int]:
    """ルートから ``octaves`` オクターブぶんの音階を MIDI 番号で並べる。"""
    root_midi = note_to_midi(root) if isinstance(root, str) else int(root)
    degrees = scale_degrees(scale)
    return [root_midi + octave * 12 + step for octave in range(octaves) for step in degrees]


def degree_to_midi(root: int | str, scale: str, degree: int) -> int:
    """音階上の度数(0 始まり、負数・オクターブ超えも可)を MIDI 番号にする。"""
    root_midi = note_to_midi(root) if isinstance(root, str) else int(root)
    degrees = scale_degrees(scale)
    size = len(degrees)
    octave, index = divmod(degree, size)
    return root_midi + octave * 12 + degrees[index]


def chord_midi(root: int | str, quality: str = "maj", inversion: int = 0) -> list[int]:
    """和音の構成音を MIDI 番号のリストで返す。"""
    root_midi = note_to_midi(root) if isinstance(root, str) else int(root)
    try:
        intervals = CHORDS[quality]
    except KeyError:
        raise ValueError(f"unknown chord: {quality!r} (available: {', '.join(sorted(CHORDS))})") from None
    notes = [root_midi + interval for interval in intervals]
    for _ in range(inversion % max(1, len(notes))):
        notes = notes[1:] + [notes[0] + 12]
    return notes


def diatonic_chord(root: int | str, scale: str, degree: int, seventh: bool = False) -> list[int]:
    """音階内の三和音(または四和音)を作る。``degree`` は 0 始まり。"""
    steps = [0, 2, 4, 6] if seventh else [0, 2, 4]
    return [degree_to_midi(root, scale, degree + step) for step in steps]


def voice_movement(a: Sequence[int], b: Sequence[int]) -> int:
    """2つの和音のあいだで、各声部が動いた半音数の合計。

    声部数が同じなら低い順に対応づける。違う場合はいちばん近い音との距離で測る。
    """
    if not a or not b:
        return 0
    if len(a) == len(b):
        return sum(abs(x - y) for x, y in zip(sorted(a), sorted(b)))
    return sum(min(abs(note - other) for other in a) for note in b)


def voice_lead(chord: Sequence[int], previous: Sequence[int] | None, drift: int = 7) -> list[int]:
    """前の和音から動きが小さくなるよう、各構成音のオクターブを選び直す。

    和音が変わるたびに全部の音を基本形へ飛ばすと、いちばん上の声部が大きく
    跳ね回って不自然に聞こえる。構成音は変えずにオクターブだけ選び直すことで、
    近い音へなめらかに移る(声部連結)。

    候補は各音を1オクターブ上下させた組み合わせ全部で、そのうち移動量が
    最小のものを選ぶ。``drift`` は和音の中心が元の音域からどれだけ離れて
    よいかの上限(半音)で、連結を優先しすぎて音域が流れるのを防ぐ。
    """
    chord = list(chord)
    if not chord or not previous:
        return sorted(chord)

    nominal = sum(chord) / len(chord)
    best: list[int] | None = None
    best_score: int | None = None
    for shifts in itertools.product((-12, 0, 12), repeat=len(chord)):
        candidate = sorted(midi + shift for midi, shift in zip(chord, shifts))
        if abs(sum(candidate) / len(candidate) - nominal) > drift:
            continue
        score = voice_movement(previous, candidate)
        if best_score is None or score < best_score:
            best, best_score = candidate, score
    return best if best is not None else sorted(chord)


def parse_progression(progression: str) -> list[int]:
    """``"I-V-vi-IV"`` のようなローマ数字表記を 0 始まりの度数リストにする。"""
    degrees: list[int] = []
    for token in re.split(r"[-,\s|]+", progression.strip()):
        if not token:
            continue
        key = token.lower().rstrip("°o+7")
        if key not in _ROMAN:
            raise ValueError(f"invalid roman numeral: {token!r}")
        degrees.append(_ROMAN[key])
    if not degrees:
        raise ValueError("progression is empty")
    return degrees

"""BGM ジェネレータ。

コード進行・ベース・メロディ・ドラムを組み立ててループ可能な曲を作る。
``seed`` を固定すれば、同じ設定からは必ず同じ曲が出る。
"""

from __future__ import annotations

import random
from dataclasses import dataclass, field, replace
from typing import Sequence

from . import drums
from . import effects as fx
from . import envelope as env
from . import notes
from . import oscillators as osc
from .core import (
    SAMPLE_RATE,
    add_into,
    mix,
    normalize,
    num_samples,
    pan,
    peak,
    remove_dc,
    to_stereo,
    wrap_tail,
)

BEATS_PER_BAR = 4


@dataclass(frozen=True)
class Style:
    """曲想ごとのパラメータ一式。"""

    scale: str = "major"
    bpm: int = 100
    progression: str = "I-V-vi-IV"
    chord_shape: str = "triangle"
    chord_seventh: bool = False
    chord_octave: int = 4
    chord_gain: float = 0.30
    bass_shape: str = "triangle"
    bass_octave: int = 2
    bass_gain: float = 0.55
    bass_pattern: str = "x...x...x...x..."
    lead_shape: str = "square"
    lead_octave: int = 5
    lead_gain: float = 0.40
    lead_rest_prob: float = 0.22
    lead_durations: tuple[float, ...] = (0.5, 0.5, 1.0, 1.0, 2.0)
    lead_range: int = 8
    drum_pattern: str = "basic"
    drum_gain: float = 0.55
    reverb_wet: float = 0.22
    reverb_room: float = 0.7
    delay_wet: float = 0.0
    bitcrush_bits: int = 0


STYLES: dict[str, Style] = {
    "calm": Style(
        scale="major", bpm=76, progression="I-vi-IV-V",
        chord_shape="triangle", chord_seventh=True, chord_gain=0.34,
        bass_shape="sine", bass_pattern="x.......x.......",
        lead_shape="sine", lead_gain=0.30, lead_rest_prob=0.35,
        lead_durations=(1.0, 2.0, 2.0, 4.0),
        drum_pattern="soft", drum_gain=0.30, reverb_wet=0.38,
    ),
    "adventure": Style(
        scale="major", bpm=132, progression="I-V-vi-IV",
        chord_shape="triangle", bass_shape="saw", bass_pattern="x.x.x.x.x.x.x.x.",
        lead_shape="pulse25", lead_gain=0.42, lead_rest_prob=0.15,
        lead_durations=(0.5, 0.5, 0.5, 1.0, 1.0),
        drum_pattern="drive", reverb_wet=0.20,
    ),
    "battle": Style(
        scale="harmonic_minor", bpm=158, progression="i-vi-vii-v",
        chord_shape="saw", chord_gain=0.24, chord_octave=3,
        bass_shape="saw", bass_pattern="x.xxx.xxx.xxx.xx", bass_gain=0.6,
        lead_shape="saw", lead_gain=0.36, lead_rest_prob=0.12,
        lead_durations=(0.25, 0.5, 0.5, 0.5, 1.0), lead_range=10,
        drum_pattern="drive", drum_gain=0.6, reverb_wet=0.16,
    ),
    "menu": Style(
        scale="pentatonic_major", bpm=96, progression="I-IV-I-V",
        chord_shape="triangle", chord_gain=0.28,
        bass_shape="triangle", bass_pattern="x...x...x...x...",
        lead_shape="square", lead_gain=0.36, lead_rest_prob=0.28,
        lead_durations=(0.5, 1.0, 1.0, 2.0), lead_range=6,
        drum_pattern="soft", drum_gain=0.35, reverb_wet=0.26, delay_wet=0.18,
    ),
    "night": Style(
        scale="minor", bpm=68, progression="i-VI-III-VII",
        chord_shape="sine", chord_seventh=True, chord_gain=0.36,
        bass_shape="sine", bass_pattern="x.......x.......", bass_gain=0.5,
        lead_shape="triangle", lead_gain=0.28, lead_rest_prob=0.45,
        lead_durations=(2.0, 2.0, 4.0), lead_range=6,
        drum_pattern="none", reverb_wet=0.45, reverb_room=0.82, delay_wet=0.22,
    ),
    "chiptune": Style(
        scale="major", bpm=144, progression="I-V-vi-IV",
        chord_shape="pulse25", chord_gain=0.24,
        bass_shape="square", bass_pattern="x.x.x.x.x.x.x.x.", bass_gain=0.5,
        lead_shape="pulse12", lead_gain=0.40, lead_rest_prob=0.12,
        lead_durations=(0.25, 0.5, 0.5, 1.0),
        drum_pattern="march", drum_gain=0.45, reverb_wet=0.10, bitcrush_bits=6,
    ),
    "tension": Style(
        scale="phrygian", bpm=104, progression="i-ii-i-vii",
        chord_shape="saw", chord_gain=0.22, chord_octave=3,
        bass_shape="saw", bass_pattern="x...x...x..x.x..",
        lead_shape="triangle", lead_gain=0.30, lead_rest_prob=0.4,
        lead_durations=(0.5, 1.0, 2.0), lead_range=7,
        drum_pattern="shuffle", drum_gain=0.4, reverb_wet=0.32,
    ),
}


@dataclass(frozen=True)
class Section:
    """曲の一区切り。どのパートを鳴らすか、どのくらいの長さかを持つ。"""

    name: str
    weight: float
    """曲全体の小節数に対する比。"""
    drop: tuple[str, ...] = ()
    """この区間で鳴らさないパート。"""
    gain: float = 1.0
    lead_octave: int = 0
    """メロディのオクターブ移動。サビを1つ上げる、といった使い方をする。"""


STRUCTURES: dict[str, tuple[Section, ...]] = {
    # 8小節をそのまま繰り返す、いちばん素直な構成。
    "loop": (Section("main", 1.0),),
    # 静かに入って本編へ。
    "intro": (
        Section("intro", 0.25, drop=("drums", "lead"), gain=0.75),
        Section("main", 0.75),
    ),
    # A メロ → サビ。サビでメロディが1オクターブ上がる。
    "verse_chorus": (
        Section("verse", 0.5, gain=0.85),
        Section("chorus", 0.5, gain=1.0, lead_octave=1),
    ),
    # イントロ・A メロ・サビ・アウトロの4部構成。
    "full": (
        Section("intro", 0.15, drop=("drums", "lead"), gain=0.7),
        Section("verse", 0.35, gain=0.85),
        Section("chorus", 0.35, gain=1.0, lead_octave=1),
        Section("outro", 0.15, drop=("drums",), gain=0.65),
    ),
}


def structure_names() -> list[str]:
    """使える曲構成の名前を並べる。"""
    return sorted(STRUCTURES)


def plan_sections(structure: str, bars: int) -> list[tuple[Section, int, int]]:
    """構成と総小節数から ``(区間, 開始小節, 小節数)`` の並びを組み立てる。

    比率で割り振ったうえで、どの区間も最低1小節を確保し、
    端数は最後の区間で吸収して合計をぴったり ``bars`` に合わせる。
    """
    try:
        sections = STRUCTURES[structure]
    except KeyError:
        raise ValueError(
            f"unknown structure: {structure!r} (available: {', '.join(structure_names())})"
        ) from None
    if bars < 1:
        raise ValueError("bars must be >= 1")

    if bars < len(sections):  # 小節が足りないときは前半の区間だけ使う
        sections = sections[:bars]

    counts = [max(1, round(section.weight * bars)) for section in sections]
    while sum(counts) > bars:  # 丸めで溢れたぶんは長い区間から削る
        counts[counts.index(max(counts))] -= 1
    counts[-1] += bars - sum(counts)

    plan: list[tuple[Section, int, int]] = []
    start = 0
    for section, count in zip(sections, counts):
        plan.append((section, start, count))
        start += count
    return plan


@dataclass
class BGMConfig:
    """1曲ぶんの設定。未指定の項目はスタイルの既定値を使う。"""

    style: str = "calm"
    key: str = "C"
    scale: str | None = None
    bpm: int | None = None
    bars: int = 8
    seed: int | None = None
    sr: int = SAMPLE_RATE
    progression: str | None = None
    drum_pattern: str | None = None
    structure: str = "loop"
    parts: Sequence[str] = field(default_factory=lambda: ("chords", "bass", "lead", "drums"))
    loop: bool = True
    stereo: bool = False

    def resolved_style(self) -> Style:
        """スタイルの既定値に、明示指定された項目を上書きしたものを返す。"""
        try:
            base = STYLES[self.style]
        except KeyError:
            raise ValueError(
                f"unknown bgm style: {self.style!r} (available: {', '.join(sorted(STYLES))})"
            ) from None
        overrides = {}
        if self.scale is not None:
            overrides["scale"] = self.scale
        if self.bpm is not None:
            overrides["bpm"] = int(self.bpm)
        if self.progression is not None:
            overrides["progression"] = self.progression
        if self.drum_pattern is not None:
            overrides["drum_pattern"] = self.drum_pattern
        return replace(base, **overrides) if overrides else base


def style_names() -> list[str]:
    """使える BGM スタイル名を並べる。"""
    return sorted(STYLES)


# --- パート生成 ---------------------------------------------------------------


def _chord_degrees_for_bars(style: Style, bars: int) -> list[int]:
    progression = notes.parse_progression(style.progression)
    return [progression[bar % len(progression)] for bar in range(bars)]


def _root_midi(key: str, octave: int) -> int:
    """``"C"`` や ``"F#"`` といったキー名を、指定オクターブの MIDI 番号にする。"""
    key = key.strip()
    if key and key[-1].isdigit():
        return notes.note_to_midi(key)
    return notes.note_to_midi(f"{key}{octave}")


def _cached(cache: dict, key: tuple, factory) -> list[float]:
    """同じ音色・音程・長さの音を作り直さずに使い回す。

    小節をまたいで同じ和音や同じベース音が何度も出てくるため、
    ここでの使い回しが生成時間にそのまま効く。返した音は加算にしか使わない
    (``add_into`` は元のバッファを書き換えない)ので共有して問題ない。
    """
    buf = cache.get(key)
    if buf is None:
        buf = cache[key] = factory()
    return buf


def _render_chords(
    config: BGMConfig,
    style: Style,
    degrees: Sequence[int],
    bar_seconds: float,
    cache: dict,
) -> list[float]:
    sr = config.sr
    root = _root_midi(config.key, style.chord_octave)
    shape = style.chord_shape
    out: list[float] = []
    for bar, degree in enumerate(degrees):
        chord = notes.diatonic_chord(root, style.scale, degree, seventh=style.chord_seventh)
        offset = num_samples(bar * bar_seconds, sr)
        for voice, midi in enumerate(chord):
            shaped = _cached(
                cache,
                ("chord", shape, midi),
                lambda midi=midi: env.apply(
                    osc.render(shape, notes.midi_to_freq(midi), bar_seconds, sr),
                    env.adsr(bar_seconds, 0.08, 0.25, 0.6, bar_seconds * 0.3, sr),
                ),
            )
            add_into(out, shaped, offset, gain=1.0 / (voice + 2))
    return out


def _render_bass(
    config: BGMConfig,
    style: Style,
    degrees: Sequence[int],
    bar_seconds: float,
    cache: dict,
) -> list[float]:
    sr = config.sr
    root = _root_midi(config.key, style.bass_octave)
    step_seconds = bar_seconds / drums.STEPS_PER_BAR
    pattern = style.bass_pattern
    length = step_seconds * 1.6
    shape = style.bass_shape
    out: list[float] = []
    for bar, degree in enumerate(degrees):
        midi = notes.degree_to_midi(root, style.scale, degree)
        fifth = notes.degree_to_midi(root, style.scale, degree + 4)
        for step, symbol in enumerate(pattern[: drums.STEPS_PER_BAR]):
            if symbol == ".":
                continue
            note_midi = midi if symbol == "x" else fifth
            shaped = _cached(
                cache,
                ("bass", shape, note_midi),
                lambda m=note_midi: fx.lowpass(
                    env.apply(
                        osc.render(shape, notes.midi_to_freq(m), length, sr),
                        env.adsr(length, 0.006, 0.05, 0.75, length * 0.35, sr),
                    ),
                    900.0,
                    sr,
                ),
            )
            add_into(out, shaped, num_samples(bar * bar_seconds + step * step_seconds, sr))
    return out


# メロディは「1小節ぶんの短いフレーズ(モチーフ)」を作り、それを小節ごとに
# 和音へ合わせて置き直したり少し変えたりして展開する。毎小節ランダムに歩かせると
# とりとめのない音の並びになるが、同じ形が返ってくると旋律として聞こえる。
#
# 4小節ひとまとまりの展開の型。A = モチーフ、A' = 末尾を変えた形、B = 対の句。
DEVELOPMENT = ("A", "A", "B", "A'")

Phrase = list  # [(音階上の度数 | None(休符), 拍数), ...]


def _make_phrase(
    style: Style,
    rng: random.Random,
    scale_size: int,
    start_degree: int = 0,
) -> Phrase:
    """1小節ぶんのフレーズを作る。度数はモチーフ内の相対値として扱う。"""
    phrase: Phrase = []
    position = 0.0
    current = start_degree
    while position < BEATS_PER_BAR - 1e-6:
        remaining = BEATS_PER_BAR - position
        choices = [d for d in style.lead_durations if d <= remaining] or [remaining]
        length = rng.choice(choices)
        if rng.random() < style.lead_rest_prob:
            phrase.append((None, length))
        else:
            on_strong_beat = position < 1e-6 or abs(position - 2.0) < 1e-6
            current = _next_degree(rng, current, 0, scale_size, style.lead_range, on_strong_beat)
            phrase.append((current, length))
        position += length
    return phrase


def _vary_phrase(phrase: Phrase, rng: random.Random, span: int) -> Phrase:
    """フレーズの最後の音だけを動かした変形を作る(A' 用)。"""
    varied = list(phrase)
    for index in range(len(varied) - 1, -1, -1):
        degree, length = varied[index]
        if degree is None:
            continue
        shifted = max(-span, min(span, degree + rng.choice((-2, -1, 1, 2))))
        varied[index] = (shifted, length)
        break
    return varied


def _anchor_shift(phrase: Phrase, chord_degree: int, scale_size: int) -> int:
    """フレーズ最初の音がその小節の和音の構成音に乗るような移動量を返す。"""
    first = next((degree for degree, _ in phrase if degree is not None), None)
    if first is None:
        return 0
    chord_offsets = (0, 2, 4)
    return min(
        (shift for shift in range(-scale_size, scale_size + 1)
         if (first + shift - chord_degree) % scale_size in chord_offsets),
        key=abs,
        default=0,
    )


def _render_lead(
    config: BGMConfig,
    style: Style,
    degrees: Sequence[int],
    bar_seconds: float,
    rng: random.Random,
    cache: dict,
    octave_shift: int = 0,
    motifs: dict | None = None,
    bar_offset: int = 0,
) -> list[float]:
    """モチーフを展開してメロディを作る。"""
    sr = config.sr
    root = _root_midi(config.key, style.lead_octave + octave_shift)
    scale_size = len(notes.scale_degrees(style.scale))
    beat_seconds = bar_seconds / BEATS_PER_BAR
    shape = style.lead_shape
    motifs = {} if motifs is None else motifs

    if "motif" not in motifs:  # 曲を通して同じ素材を使い回す
        motifs["motif"] = _make_phrase(style, rng, scale_size)
        motifs["contrast"] = _make_phrase(style, rng, scale_size, start_degree=2)
        motifs["variation"] = _vary_phrase(motifs["motif"], rng, style.lead_range)

    out: list[float] = []
    for bar, chord_degree in enumerate(degrees):
        role = DEVELOPMENT[(bar + bar_offset) % len(DEVELOPMENT)]
        phrase = {"A": motifs["motif"], "B": motifs["contrast"], "A'": motifs["variation"]}[role]
        shift = _anchor_shift(phrase, chord_degree, scale_size)

        position = 0.0
        for degree, length_beats in phrase:
            start = bar * bar_seconds + position * beat_seconds
            position += length_beats
            if degree is None:
                continue
            length = length_beats * beat_seconds * 0.92
            midi = notes.degree_to_midi(root, style.scale, degree + shift)
            shaped = _cached(
                cache,
                ("lead", shape, midi, round(length, 6)),
                lambda m=midi, ln=length: env.apply(
                    osc.render(shape, notes.midi_to_freq(m), ln, sr),
                    env.adsr(ln, 0.012, 0.08, 0.7, ln * 0.3, sr),
                ),
            )
            add_into(out, shaped, num_samples(start, sr))
    return out


def _next_degree(
    rng: random.Random,
    current: int,
    chord_degree: int,
    scale_size: int,
    span: int,
    prefer_chord_tone: bool,
) -> int:
    """次の音の度数を選ぶ。強拍ではコードトーンに寄せる。"""
    step = rng.choice((-3, -2, -1, -1, 1, 1, 2, 3))
    candidate = current + step
    if prefer_chord_tone:
        chord_offsets = (0, 2, 4)
        options = [
            candidate + shift
            for shift in range(-3, 4)
            if (candidate + shift - chord_degree) % scale_size in chord_offsets
        ]
        if options:
            candidate = min(options, key=lambda value: (abs(value - current), abs(value)))
    return max(-span, min(span, candidate))


def _render_drums(config: BGMConfig, style: Style, bars: int, bar_seconds: float) -> list[float]:
    sr = config.sr
    pattern = drums.get_pattern(style.drum_pattern)
    if not pattern:
        return []
    step_seconds = bar_seconds / drums.STEPS_PER_BAR
    cache = {voice: drums.VOICES[voice](sr=sr) for voice in pattern}
    out: list[float] = []
    for bar in range(bars):
        for voice, steps in pattern.items():
            for step, symbol in enumerate(steps[: drums.STEPS_PER_BAR]):
                if symbol == ".":
                    continue
                gain = 1.0 if symbol == "x" else 0.6
                add_into(out, cache[voice], num_samples(bar * bar_seconds + step * step_seconds, sr), gain)
    return out


def render_tracks(config: BGMConfig) -> dict[str, list[float]]:
    """パートごとのバッファを ``{名前: バッファ}`` で返す(ミックス前)。

    曲は ``structure`` で決まる区間に分けて作り、区間ごとに
    鳴らすパート・音量・メロディの高さを変えてから元の位置に貼り合わせる。
    """
    style = config.resolved_style()
    if config.bars < 1:
        raise ValueError("bars must be >= 1")

    rng = random.Random(config.seed)
    bar_seconds = BEATS_PER_BAR * 60.0 / style.bpm
    degrees = _chord_degrees_for_bars(style, config.bars)
    requested = [part for part in ("chords", "bass", "lead", "drums") if part in set(config.parts)]

    cache: dict = {}
    motifs: dict = {}
    tracks: dict[str, list[float]] = {}
    for section, start_bar, bar_count in plan_sections(config.structure, config.bars):
        offset = num_samples(start_bar * bar_seconds, config.sr)
        section_degrees = degrees[start_bar : start_bar + bar_count]
        for part in requested:
            if part in section.drop:
                continue
            buf = _render_part(
                part, config, style, section, section_degrees,
                bar_seconds, rng, cache, motifs, start_bar,
            )
            if buf:
                add_into(tracks.setdefault(part, []), buf, offset, gain=section.gain)
    return tracks


def _render_part(
    part: str,
    config: BGMConfig,
    style: Style,
    section: Section,
    degrees: Sequence[int],
    bar_seconds: float,
    rng: random.Random,
    cache: dict,
    motifs: dict,
    bar_offset: int,
) -> list[float]:
    """1区間ぶんのパートを、区間の先頭を 0 秒として作る。"""
    if part == "chords":
        return _render_chords(config, style, degrees, bar_seconds, cache)
    if part == "bass":
        return _render_bass(config, style, degrees, bar_seconds, cache)
    if part == "lead":
        return _render_lead(
            config, style, degrees, bar_seconds, rng, cache,
            section.lead_octave, motifs, bar_offset,
        )
    if part == "drums":
        return _render_drums(config, style, len(degrees), bar_seconds)
    raise ValueError(f"unknown part: {part!r}")


_PART_PAN = {"chords": -0.35, "bass": 0.0, "lead": 0.28, "drums": 0.0}


def _part_gains(style: Style) -> dict[str, float]:
    return {
        "chords": style.chord_gain,
        "bass": style.bass_gain,
        "lead": style.lead_gain,
        "drums": style.drum_gain,
    }


TARGET_PEAK = 0.86


def _post_process(buf: list[float], style: Style, config: BGMConfig, length: int) -> list[float]:
    """マスターエフェクトをかけ、ループ用に長さを揃える(音量調整は呼び出し側)。"""
    sr = config.sr
    if style.bitcrush_bits:
        buf = fx.bitcrush(buf, bits=style.bitcrush_bits)
    if style.delay_wet > 0:
        beat_seconds = 60.0 / style.bpm
        buf = fx.delay(buf, time=beat_seconds * 0.75, feedback=0.3, wet=style.delay_wet, sr=sr, tail=beat_seconds * 3)
    if style.reverb_wet > 0:
        buf = fx.reverb(buf, room=style.reverb_room, wet=style.reverb_wet, sr=sr, tail=1.0)
    return remove_dc(wrap_tail(buf, length) if config.loop else buf)


def generate(config: BGMConfig | None = None, **overrides) -> list[float]:
    """BGM をモノラルバッファとして生成する。"""
    config = replace(config or BGMConfig(), **overrides) if overrides else (config or BGMConfig())
    style = config.resolved_style()
    tracks = render_tracks(config)
    gains = _part_gains(style)
    bar_seconds = BEATS_PER_BAR * 60.0 / style.bpm
    length = num_samples(config.bars * bar_seconds, config.sr)

    names = list(tracks)
    mixed = mix(*(tracks[name] for name in names), gains=[gains[name] for name in names]) if names else []
    return normalize(_post_process(mixed, style, config, length), TARGET_PEAK)


def generate_stereo(config: BGMConfig | None = None, **overrides) -> list[float]:
    """BGM を L,R インターリーブのステレオバッファとして生成する。"""
    config = replace(config or BGMConfig(), **overrides) if overrides else (config or BGMConfig())
    style = config.resolved_style()
    tracks = render_tracks(config)
    gains = _part_gains(style)
    bar_seconds = BEATS_PER_BAR * 60.0 / style.bpm
    length = num_samples(config.bars * bar_seconds, config.sr)

    left_parts: list[list[float]] = []
    right_parts: list[list[float]] = []
    for name, track in tracks.items():
        left, right = pan(track, _PART_PAN.get(name, 0.0))
        left_parts.append([value * gains[name] for value in left])
        right_parts.append([value * gains[name] for value in right])

    left = _post_process(mix(*left_parts) if left_parts else [], style, config, length)
    right = _post_process(mix(*right_parts) if right_parts else [], style, config, length)

    # 定位を崩さないよう、L/R をまとめて同じ倍率で正規化する。
    loudest = max(peak(left), peak(right))
    if loudest > 1e-12:
        scale = TARGET_PEAK / loudest
        left = [value * scale for value in left]
        right = [value * scale for value in right]
    return to_stereo(left, right)

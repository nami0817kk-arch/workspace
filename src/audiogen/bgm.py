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
from . import instruments
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
class Groove:
    """機械的に並んだ音符に「ノリ」を与えるための設定。

    完全に等間隔・等音量で並べると、正確ではあるが打ち込みらしさが強く出る。
    裏拍を少し後ろにずらし(スウィング)、拍の重さで音量を変え(アクセント)、
    ごくわずかに時間と音量を揺らす(ヒューマナイズ)ことで人が弾いた感じに近づける。
    """

    swing: float = 0.0
    """裏の8分音符を後ろへずらす量。16分音符を 1.0 とした比。0.67 で三連符のシャッフル。"""
    accent: float = 0.25
    """拍の重さによる音量差の大きさ。0 で強弱なし。"""
    humanize: float = 0.0
    """時間の揺らぎ(秒)。音量も同じ割合で揺らす。"""

    def time_offset(self, step: int, step_seconds: float, rng: random.Random) -> float:
        """16分グリッド上の ``step`` 番目の音を、何秒ずらすか。"""
        offset = 0.0
        if self.swing and step % 4 == 2:  # 各拍の裏の8分音符
            offset += self.swing * step_seconds
        if self.humanize:
            offset += rng.uniform(-self.humanize, self.humanize)
        return offset

    def velocity(self, step: int, rng: random.Random) -> float:
        """16分グリッド上の ``step`` 番目の音の音量倍率。"""
        if step % 16 == 0:
            weight = 1.0
        elif step % 8 == 0:
            weight = 0.95
        elif step % 4 == 0:
            weight = 0.85
        elif step % 2 == 0:
            weight = 0.75
        else:
            weight = 0.65
        level = 1.0 - self.accent * (1.0 - weight)
        if self.humanize:
            level *= 1.0 + rng.uniform(-self.humanize, self.humanize) * 12.0
        return max(0.0, level)


STRAIGHT = Groove()
"""ゆらぎのないグルーヴ。チップチューンなど機械的な曲想向け。"""


@dataclass(frozen=True)
class Style:
    """曲想ごとのパラメータ一式。"""

    scale: str = "major"
    bpm: int = 100
    progression: str = "I-V-vi-IV"
    chord_instrument: str = "pad"
    chord_seventh: bool = False
    chord_octave: int = 4
    chord_gain: float = 0.30
    bass_instrument: str = "sub_bass"
    bass_octave: int = 2
    bass_gain: float = 0.55
    bass_pattern: str = "x...x...x...x..."
    lead_instrument: str = "pulse_lead"
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
    groove: Groove = Groove(humanize=0.003)


STYLES: dict[str, Style] = {
    "calm": Style(
        scale="major", bpm=76, progression="I-vi-IV-V",
        chord_instrument="pad", chord_seventh=True, chord_gain=0.34,
        bass_instrument="sub_bass", bass_pattern="x.......x.......",
        lead_instrument="bell", lead_gain=0.30, lead_rest_prob=0.35,
        lead_durations=(1.0, 2.0, 2.0, 4.0),
        drum_pattern="soft", drum_gain=0.30, reverb_wet=0.38,
        groove=Groove(accent=0.3, humanize=0.006),  # ゆったりした曲ほど揺れてよい
    ),
    "adventure": Style(
        scale="major", bpm=132, progression="I-V-vi-IV",
        chord_instrument="strings", bass_instrument="pick_bass", bass_pattern="x.x.x.x.x.x.x.x.",
        lead_instrument="pulse_lead", lead_gain=0.42, lead_rest_prob=0.15,
        lead_durations=(0.5, 0.5, 0.5, 1.0, 1.0),
        drum_pattern="drive", reverb_wet=0.20,
    ),
    "battle": Style(
        scale="harmonic_minor", bpm=158, progression="i-vi-vii-v",
        chord_instrument="strings", chord_gain=0.24, chord_octave=3,
        bass_instrument="pick_bass", bass_pattern="x.xxx.xxx.xxx.xx", bass_gain=0.6,
        lead_instrument="pulse_lead", lead_gain=0.36, lead_rest_prob=0.12,
        lead_durations=(0.25, 0.5, 0.5, 0.5, 1.0), lead_range=10,
        drum_pattern="drive", drum_gain=0.6, reverb_wet=0.16,
    ),
    "menu": Style(
        scale="pentatonic_major", bpm=96, progression="I-IV-I-V",
        chord_instrument="pluck", chord_gain=0.28,
        bass_instrument="sub_bass", bass_pattern="x...x...x...x...",
        lead_instrument="marimba", lead_gain=0.36, lead_rest_prob=0.28,
        lead_durations=(0.5, 1.0, 1.0, 2.0), lead_range=6,
        drum_pattern="soft", drum_gain=0.35, reverb_wet=0.26, delay_wet=0.18,
        groove=Groove(swing=0.2, accent=0.25, humanize=0.004),
    ),
    "night": Style(
        scale="minor", bpm=68, progression="i-VI-III-VII",
        chord_instrument="pad", chord_seventh=True, chord_gain=0.36,
        bass_instrument="sub_bass", bass_pattern="x.......x.......", bass_gain=0.5,
        lead_instrument="bell", lead_gain=0.28, lead_rest_prob=0.45,
        lead_durations=(2.0, 2.0, 4.0), lead_range=6,
        drum_pattern="none", reverb_wet=0.45, reverb_room=0.82, delay_wet=0.22,
    ),
    "chiptune": Style(
        scale="major", bpm=144, progression="I-V-vi-IV",
        chord_instrument="pulse25", chord_gain=0.24,
        bass_instrument="square", bass_pattern="x.x.x.x.x.x.x.x.", bass_gain=0.5,
        lead_instrument="chip_lead", lead_gain=0.40, lead_rest_prob=0.12,
        lead_durations=(0.25, 0.5, 0.5, 1.0),
        drum_pattern="march", drum_gain=0.45, reverb_wet=0.10, bitcrush_bits=6,
        groove=STRAIGHT,  # チップチューンは正確に並んでいるほうが らしい
    ),
    "tension": Style(
        scale="phrygian", bpm=104, progression="i-ii-i-vii",
        chord_instrument="organ", chord_gain=0.22, chord_octave=3,
        bass_instrument="pick_bass", bass_pattern="x...x...x..x.x..",
        lead_instrument="strings", lead_gain=0.30, lead_rest_prob=0.4,
        lead_durations=(0.5, 1.0, 2.0), lead_range=7,
        drum_pattern="shuffle", drum_gain=0.4, reverb_wet=0.32,
        groove=Groove(swing=0.55, accent=0.3, humanize=0.005),
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
    swing: float | None = None
    humanize: float | None = None
    chord_instrument: str | None = None
    bass_instrument: str | None = None
    lead_instrument: str | None = None
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
        for part in ("chord", "bass", "lead"):
            chosen = getattr(self, f"{part}_instrument")
            if chosen is not None:
                instruments.get(chosen)  # 名前が正しいかここで確かめる
                overrides[f"{part}_instrument"] = chosen
        if self.swing is not None or self.humanize is not None:
            groove_overrides = {}
            if self.swing is not None:
                groove_overrides["swing"] = min(max(float(self.swing), 0.0), 0.7)
            if self.humanize is not None:
                groove_overrides["humanize"] = max(float(self.humanize), 0.0)
            overrides["groove"] = replace(base.groove, **groove_overrides)
        return replace(base, **overrides) if overrides else base


def _with_overrides(config: BGMConfig | None, overrides: dict) -> BGMConfig:
    """設定オブジェクトとキーワード指定をひとつにまとめる。"""
    config = config or BGMConfig()
    return replace(config, **overrides) if overrides else config


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


@dataclass(frozen=True)
class Note:
    """譜面上の1音。「いつ・どの高さで・どれだけ」だけを持ち、音色は持たない。"""

    start: float
    """区間の先頭からの秒数。"""
    midi: int
    length: float
    velocity: float = 1.0


@dataclass(frozen=True)
class Hit:
    """ドラムの1打。"""

    start: float
    voice: str
    velocity: float = 1.0


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


def _place(out: list[float], buf: list[float], start_seconds: float, sr: int, gain: float = 1.0) -> None:
    """音を指定時刻に置く(負の時刻は譜面側で 0 に丸めてある)。"""
    add_into(out, buf, max(0, num_samples(start_seconds, sr)), gain=gain)


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


# --- 作曲(譜面を組み立てる) -------------------------------------------------
#
# 「どの音をいつ鳴らすか」と「その音をどう合成するか」を分けている。
# 前者だけを取り出せるので、音を作らずに中身を確認できる(describe を参照)。


def _plan_chords(config: BGMConfig, style: Style, degrees: Sequence[int], bar_seconds: float) -> list[Note]:
    root = _root_midi(config.key, style.chord_octave)
    plan: list[Note] = []
    for bar, degree in enumerate(degrees):
        chord = notes.diatonic_chord(root, style.scale, degree, seventh=style.chord_seventh)
        for voice, midi in enumerate(chord):
            # 上の声部ほど小さくして、根音が土台に聞こえるようにする。
            plan.append(Note(bar * bar_seconds, midi, bar_seconds, 1.0 / (voice + 2)))
    return plan


def _plan_bass(
    config: BGMConfig,
    style: Style,
    degrees: Sequence[int],
    bar_seconds: float,
    groove_rng: random.Random,
) -> list[Note]:
    root = _root_midi(config.key, style.bass_octave)
    step_seconds = bar_seconds / drums.STEPS_PER_BAR
    groove = style.groove
    length = step_seconds * 1.6
    plan: list[Note] = []
    for bar, degree in enumerate(degrees):
        midi = notes.degree_to_midi(root, style.scale, degree)
        fifth = notes.degree_to_midi(root, style.scale, degree + 4)
        for step, symbol in enumerate(style.bass_pattern[: drums.STEPS_PER_BAR]):
            if symbol == ".":
                continue
            start = bar * bar_seconds + step * step_seconds
            start = max(0.0, start + groove.time_offset(step, step_seconds, groove_rng))
            plan.append(
                Note(start, midi if symbol == "x" else fifth, length, groove.velocity(step, groove_rng))
            )
    return plan


def _plan_lead(
    style: Style,
    degrees: Sequence[int],
    bar_seconds: float,
    root: int,
    groove_rng: random.Random,
    motifs: dict,
    bar_offset: int,
) -> list[Note]:
    """モチーフを小節ごとの和音に合わせて展開し、メロディの譜面を作る。"""
    scale_size = len(notes.scale_degrees(style.scale))
    beat_seconds = bar_seconds / BEATS_PER_BAR
    step_seconds = bar_seconds / drums.STEPS_PER_BAR
    groove = style.groove
    plan: list[Note] = []

    for bar, chord_degree in enumerate(degrees):
        role = DEVELOPMENT[(bar + bar_offset) % len(DEVELOPMENT)]
        phrase = {"A": motifs["motif"], "B": motifs["contrast"], "A'": motifs["variation"]}[role]
        shift = _anchor_shift(phrase, chord_degree, scale_size)

        position = 0.0
        for degree, length_beats in phrase:
            start = bar * bar_seconds + position * beat_seconds
            step = round(position * drums.STEPS_PER_BAR / BEATS_PER_BAR)
            position += length_beats
            if degree is None:
                continue
            start = max(0.0, start + groove.time_offset(step, step_seconds, groove_rng))
            plan.append(
                Note(
                    start,
                    notes.degree_to_midi(root, style.scale, degree + shift),
                    length_beats * beat_seconds * 0.92,
                    groove.velocity(step, groove_rng),
                )
            )
    return plan


def _plan_drums(style: Style, bars: int, bar_seconds: float, groove_rng: random.Random) -> list[Hit]:
    pattern = drums.get_pattern(style.drum_pattern)
    if not pattern:
        return []
    step_seconds = bar_seconds / drums.STEPS_PER_BAR
    groove = style.groove
    plan: list[Hit] = []
    for bar in range(bars):
        for voice, steps in pattern.items():
            for step, symbol in enumerate(steps[: drums.STEPS_PER_BAR]):
                if symbol == ".":
                    continue
                start = bar * bar_seconds + step * step_seconds
                start = max(0.0, start + groove.time_offset(step, step_seconds, groove_rng))
                level = (1.0 if symbol == "x" else 0.6) * groove.velocity(step, groove_rng)
                plan.append(Hit(start, voice, level))
    return plan


def _ensure_motifs(style: Style, rng: random.Random, motifs: dict) -> dict:
    """曲を通して使い回すモチーフを、最初の1回だけ作る。"""
    if "motif" not in motifs:
        scale_size = len(notes.scale_degrees(style.scale))
        motifs["motif"] = _make_phrase(style, rng, scale_size)
        motifs["contrast"] = _make_phrase(style, rng, scale_size, start_degree=2)
        motifs["variation"] = _vary_phrase(motifs["motif"], rng, style.lead_range)
    return motifs


# --- 合成(譜面を音にする) ---------------------------------------------------


def _render_notes(
    plan: Sequence[Note],
    voice: str,
    sr: int,
    cache: dict,
    synth,
) -> list[float]:
    """譜面の各音を ``synth(midi, length)`` で作り、時間軸に並べる。"""
    out: list[float] = []
    for note in plan:
        buf = _cached(
            cache,
            (voice, note.midi, round(note.length, 6)),
            lambda n=note: synth(n.midi, n.length),
        )
        _place(out, buf, note.start, sr, gain=note.velocity)
    return out


def _render_hits(plan: Sequence[Hit], sr: int) -> list[float]:
    # 音色は種類ごとに1回だけ作る(打数ぶん作り直すと桁違いに遅くなる)。
    voices = {voice: drums.VOICES[voice](sr=sr) for voice in {hit.voice for hit in plan}}
    out: list[float] = []
    for hit in plan:
        _place(out, voices[hit.voice], hit.start, sr, gain=hit.velocity)
    return out


def _synth_for(name: str, sr: int):
    """楽器名から ``(midi, 長さ) -> 音`` の関数を作る。"""
    instrument = instruments.get(name)

    def synth(midi: int, length: float) -> list[float]:
        return instrument.render(notes.midi_to_freq(midi), length, sr)

    return synth


@dataclass(frozen=True)
class Arrangement:
    """音にする前の曲の姿。どの音をいつ鳴らすかだけを持つ。"""

    style: Style
    bars: int
    bar_seconds: float
    sections: tuple[tuple[Section, int, int], ...]
    notes: dict[str, list[Note]]
    """パート名 -> 音符の並び(曲頭からの絶対時刻。区間の音量も反映済み)。"""
    hits: list[Hit]

    @property
    def length_seconds(self) -> float:
        return self.bars * self.bar_seconds

    def parts(self) -> list[str]:
        """実際に音の入っているパート名。"""
        return [name for name in ("chords", "bass", "lead", "drums") if self.part_count(name)]

    def part_count(self, name: str) -> int:
        if name == "drums":
            return len(self.hits)
        return len(self.notes.get(name, ()))


def compose(config: BGMConfig | None = None, **overrides) -> Arrangement:
    """音を合成せずに譜面だけを組み立てる。

    生成前に中身を確認したり、別の音源へ渡したりできるようにしてある。
    """
    config = _with_overrides(config, overrides)
    style = config.resolved_style()
    if config.bars < 1:
        raise ValueError("bars must be >= 1")

    rng = random.Random(config.seed)
    # グルーヴ用は別系列にしておく。ゆらぎの有無でメロディまで変わらないようにする。
    groove_rng = random.Random((config.seed or 0) + 7919)
    bar_seconds = BEATS_PER_BAR * 60.0 / style.bpm
    degrees = _chord_degrees_for_bars(style, config.bars)
    requested = [part for part in ("chords", "bass", "lead", "drums") if part in set(config.parts)]
    motifs = _ensure_motifs(style, rng, {})

    plan = plan_sections(config.structure, config.bars)
    notes_by_part: dict[str, list[Note]] = {}
    hits: list[Hit] = []
    for section, start_bar, bar_count in plan:
        offset = start_bar * bar_seconds
        section_degrees = degrees[start_bar : start_bar + bar_count]
        for part in requested:
            if part in section.drop:
                continue
            if part == "drums":
                hits.extend(
                    Hit(hit.start + offset, hit.voice, hit.velocity * section.gain)
                    for hit in _plan_drums(style, bar_count, bar_seconds, groove_rng)
                )
                continue
            for note in _plan_notes(part, config, style, section, section_degrees, bar_seconds, groove_rng, motifs, start_bar):
                notes_by_part.setdefault(part, []).append(
                    replace(note, start=note.start + offset, velocity=note.velocity * section.gain)
                )
    return Arrangement(style, config.bars, bar_seconds, tuple(plan), notes_by_part, hits)


def _plan_notes(
    part: str,
    config: BGMConfig,
    style: Style,
    section: Section,
    degrees: Sequence[int],
    bar_seconds: float,
    groove_rng: random.Random,
    motifs: dict,
    bar_offset: int,
) -> list[Note]:
    if part == "chords":
        return _plan_chords(config, style, degrees, bar_seconds)
    if part == "bass":
        return _plan_bass(config, style, degrees, bar_seconds, groove_rng)
    if part == "lead":
        root = _root_midi(config.key, style.lead_octave + section.lead_octave)
        return _plan_lead(style, degrees, bar_seconds, root, groove_rng, motifs, bar_offset)
    raise ValueError(f"unknown part: {part!r}")


def describe(config: BGMConfig | None = None, **overrides) -> dict:
    """これから作られる曲の中身を、そのまま印刷・JSON 化できる形で返す。"""
    config = _with_overrides(config, overrides)
    arrangement = compose(config)
    style = arrangement.style
    degrees = _chord_degrees_for_bars(style, config.bars)
    root = _root_midi(config.key, style.chord_octave)
    return {
        "style": config.style,
        "key": config.key,
        "scale": style.scale,
        "bpm": style.bpm,
        "bars": config.bars,
        "seed": config.seed,
        "structure": config.structure,
        "progression": style.progression,
        "duration": round(arrangement.length_seconds, 3),
        "swing": style.groove.swing,
        "humanize": style.groove.humanize,
        "sections": [
            {"name": section.name, "start_bar": start, "bars": count}
            for section, start, count in arrangement.sections
        ],
        "chords": [
            {
                "bar": bar,
                "notes": [
                    notes.midi_to_name(midi)
                    for midi in notes.diatonic_chord(root, style.scale, degree, style.chord_seventh)
                ],
            }
            for bar, degree in enumerate(degrees)
        ],
        "melody": [
            {"start": round(note.start, 4), "note": notes.midi_to_name(note.midi), "length": round(note.length, 4)}
            for note in arrangement.notes.get("lead", ())
        ],
        "note_counts": {name: arrangement.part_count(name) for name in arrangement.parts()},
    }


def render_tracks(config: BGMConfig | None = None, **overrides) -> dict[str, list[float]]:
    """パートごとのバッファを ``{名前: バッファ}`` で返す(ミックス前)。"""
    config = _with_overrides(config, overrides)
    arrangement = compose(config)
    style = arrangement.style
    sr = config.sr
    cache: dict = {}

    synths = {
        "chords": _synth_for(style.chord_instrument, sr),
        "bass": _synth_for(style.bass_instrument, sr),
        "lead": _synth_for(style.lead_instrument, sr),
    }
    tracks: dict[str, list[float]] = {}
    for part, plan in arrangement.notes.items():
        if plan:
            tracks[part] = _render_notes(plan, part, sr, cache, synths[part])
    if arrangement.hits:
        tracks["drums"] = _render_hits(arrangement.hits, sr)
    return tracks


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
    config = _with_overrides(config, overrides)
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
    config = _with_overrides(config, overrides)
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

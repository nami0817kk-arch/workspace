"""BGM ジェネレータ。

コード進行・ベース・メロディ・ドラムを組み立ててループ可能な曲を作る。
``seed`` を固定すれば、同じ設定からは必ず同じ曲が出る。
"""

from __future__ import annotations

import math
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
    loudness,
    mix,
    normalize_loudness,
    num_samples,
    pan,
    peak,
    remove_dc,
    to_stereo,
    wrap_tail,
)

MIN_SAMPLE_RATE = 4000
"""これより低いと、可聴域の音がほとんど残らない。"""

MIN_BPM, MAX_BPM = 20, 400
MIN_TEMPO_RATIO, MAX_TEMPO_RATIO = 0.2, 2.0
"""リタルダンドの終端テンポ倍率の範囲。0 以下だと時間が止まる。"""

from .styles import (  # noqa: F401,E402  (公開 API として再輸出する)
    BEATS_PER_BAR,
    FLAT,
    STRAIGHT,
    STRUCTURES,
    STYLES,
    PART_ORDER,
    Groove,
    MasterEQ,
    Section,
    Style,
    TempoCurve,
    plan_sections,
    structure_names,
    style_names,
)


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
    parts: Sequence[str] | None = None
    """鳴らすパートの明示指定。None ならスタイルの既定を使う。"""
    without: Sequence[str] = ()
    """既定から外すパート。"""
    loop: bool = True
    ritardando: float = 0.0
    """最後の何小節でテンポを緩めるか。0 でなし(ループはできなくなる)。"""
    final_tempo: float = 0.72
    """リタルダンドの終端でのテンポ倍率。"""
    ending: bool = False
    """最後の小節を主和音で締める。ループではなく1曲として終わらせたいとき。"""
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


def _chord_degrees_for_bars(style: Style, bars: int) -> list[int]:
    progression = notes.parse_progression(style.progression)
    return [progression[bar % len(progression)] for bar in range(bars)]


def _root_midi(key: str, octave: int) -> int:
    """``"C"`` や ``"F#"`` といったキー名を、指定オクターブの MIDI 番号にする。"""
    key = key.strip()
    name = key if key and key[-1].isdigit() else f"{key}{octave}"
    try:
        return notes.note_to_midi(name)
    except ValueError:
        raise ValueError(
            f"invalid key: {key!r} (例: C, F#, Bb, A3)"
        ) from None


def validate(config: BGMConfig) -> None:
    """設定の値が音として成り立つ範囲にあるか確かめる。

    範囲外の値は、そのまま計算に流すとゼロ除算や無音になり、
    どこが悪かったのか分からなくなる。入口で弾いて理由を返す。
    """
    if config.bars < 1:
        raise ValueError(f"bars must be >= 1 (指定: {config.bars})")
    if config.sr < MIN_SAMPLE_RATE:
        raise ValueError(f"sample rate must be >= {MIN_SAMPLE_RATE}Hz (指定: {config.sr})")
    if config.bpm is not None and not MIN_BPM <= config.bpm <= MAX_BPM:
        raise ValueError(f"bpm must be between {MIN_BPM} and {MAX_BPM} (指定: {config.bpm})")
    if config.ritardando < 0:
        raise ValueError(f"ritardando must be >= 0 (指定: {config.ritardando})")
    if not MIN_TEMPO_RATIO <= config.final_tempo <= MAX_TEMPO_RATIO:
        raise ValueError(
            f"final_tempo must be between {MIN_TEMPO_RATIO} and {MAX_TEMPO_RATIO} "
            f"(指定: {config.final_tempo})"
        )
    unknown = set(config.parts or ()) - set(PART_ORDER)
    if unknown:
        raise ValueError(f"unknown parts: {', '.join(sorted(unknown))} (使えるのは {', '.join(PART_ORDER)})")
    unknown = set(config.without) - set(PART_ORDER)
    if unknown:
        raise ValueError(f"unknown parts in 'without': {', '.join(sorted(unknown))}")
    _root_midi(config.key, 4)  # キー名の妥当性をここで確かめる


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


def _plan_chords(
    config: BGMConfig,
    style: Style,
    degrees: Sequence[int],
    bar_seconds: float,
    groove_rng: random.Random,
    transpose: int = 0,
) -> list[Note]:
    """和音を並べる。

    ``chord_pattern`` が空なら1小節伸ばす。指定があれば16分グリッドで刻む。
    報道やスポーツの曲想では、伸ばしっぱなしより刻んだほうが前へ出る。
    """
    root = _root_midi(config.key, style.chord_octave) + transpose
    step_seconds = bar_seconds / drums.STEPS_PER_BAR
    groove = style.groove
    plan: list[Note] = []
    previous: list[int] | None = None

    for bar, degree in enumerate(degrees):
        chord = notes.diatonic_chord(root, style.scale, degree, seventh=style.chord_seventh)
        if style.chord_voice_lead:
            chord = notes.voice_lead(chord, previous)
        previous = chord
        # 下の声部ほど大きくして、低い音が土台に聞こえるようにする。
        levels = [1.0 / (voice + 2) for voice in range(len(chord))]

        if not style.chord_pattern:
            for midi, level in zip(chord, levels):
                plan.append(Note(bar * bar_seconds, midi, bar_seconds, level))
            continue

        length = bar_seconds * style.chord_length
        for step, symbol in enumerate(style.chord_pattern[: drums.STEPS_PER_BAR]):
            if symbol == ".":
                continue
            start = bar * bar_seconds + step * step_seconds
            start = max(0.0, start + groove.time_offset(step, step_seconds, groove_rng))
            velocity = groove.velocity(step, groove_rng) * (1.0 if symbol == "x" else 0.7)
            for midi, level in zip(chord, levels):
                plan.append(Note(start, midi, length, level * velocity))
    return plan


def _plan_arp(
    config: BGMConfig,
    style: Style,
    degrees: Sequence[int],
    bar_seconds: float,
    groove_rng: random.Random,
    transpose: int = 0,
) -> list[Note]:
    """和音の構成音を順に鳴らす細かい刻み(アルペジオ)を並べる。

    伸ばした和音の上を走る動きが、報道番組のテーマ曲らしい前進感を作る。
    """
    if not style.arp_pattern:
        return []
    root = _root_midi(config.key, style.arp_octave) + transpose
    step_seconds = bar_seconds / drums.STEPS_PER_BAR
    groove = style.groove
    length = step_seconds * 1.5
    plan: list[Note] = []
    position = 0

    for bar, degree in enumerate(degrees):
        chord = notes.diatonic_chord(root, style.scale, degree, seventh=style.chord_seventh)
        for step, symbol in enumerate(style.arp_pattern[: drums.STEPS_PER_BAR]):
            if symbol == ".":
                continue
            index = style.arp_shape[position % len(style.arp_shape)]
            position += 1
            octave, voice = divmod(index, len(chord))
            midi = chord[voice] + octave * 12
            start = bar * bar_seconds + step * step_seconds
            start = max(0.0, start + groove.time_offset(step, step_seconds, groove_rng))
            velocity = groove.velocity(step, groove_rng) * (1.0 if symbol == "x" else 0.75)
            plan.append(Note(start, midi, length, velocity))
    return plan


def _plan_bass(
    config: BGMConfig,
    style: Style,
    degrees: Sequence[int],
    bar_seconds: float,
    groove_rng: random.Random,
    transpose: int = 0,
) -> list[Note]:
    root = _root_midi(config.key, style.bass_octave) + transpose
    step_seconds = bar_seconds / drums.STEPS_PER_BAR
    groove = style.groove
    length = step_seconds * 1.6
    hits = [step for step, symbol in enumerate(style.bass_pattern[: drums.STEPS_PER_BAR]) if symbol != "."]
    last_hit = hits[-1] if hits else -1
    plan: list[Note] = []

    for bar, degree in enumerate(degrees):
        midi = notes.degree_to_midi(root, style.scale, degree)
        fifth = notes.degree_to_midi(root, style.scale, degree + 4)
        next_degree = degrees[bar + 1] if bar + 1 < len(degrees) else None
        for step, symbol in enumerate(style.bass_pattern[: drums.STEPS_PER_BAR]):
            if symbol == ".":
                continue
            note_midi = midi if symbol == "x" else fifth
            if (
                style.bass_walk
                and step == last_hit
                and next_degree is not None
                and next_degree != degree
            ):
                # 小節の最後の音で、次の和音の根音のひとつ下へ寄せておく。
                # 次の小節の頭が「着地」に聞こえる。
                note_midi = notes.degree_to_midi(root, style.scale, next_degree - 1)
            start = bar * bar_seconds + step * step_seconds
            start = max(0.0, start + groove.time_offset(step, step_seconds, groove_rng))
            plan.append(Note(start, note_midi, length, groove.velocity(step, groove_rng)))
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
    fill = drums.get_fill(style.drum_fill) if style.drum_fill else {}
    if not pattern and not fill:
        return []
    step_seconds = bar_seconds / drums.STEPS_PER_BAR
    groove = style.groove
    plan: list[Hit] = []
    for bar in range(bars):
        # 区間の最後の小節だけフィルに差し替える。2小節以上ないと崩しに聞こえない。
        bar_pattern = fill if (fill and bars >= 2 and bar == bars - 1) else pattern
        for voice, steps in bar_pattern.items():
            for step, symbol in enumerate(steps[: drums.STEPS_PER_BAR]):
                weight = drums.symbol_level(symbol)
                if weight <= 0.0:
                    continue
                start = bar * bar_seconds + step * step_seconds
                start = max(0.0, start + groove.time_offset(step, step_seconds, groove_rng))
                level = weight * groove.velocity(step, groove_rng)
                if symbol == drums.FLAM_SYMBOL:
                    # 装飾音を少し前に置く。2連打で一発が厚くなる。
                    grace = max(0.0, start - drums.FLAM_LEAD)
                    plan.append(Hit(grace, voice, level * drums.FLAM_LEVEL))
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
    duration: float = 0.0
    """曲の長さ(秒)。テンポを緩めた場合はそのぶん長い。"""

    @property
    def length_seconds(self) -> float:
        return self.duration or self.bars * self.bar_seconds

    def parts(self) -> list[str]:
        """実際に音の入っているパート名。"""
        return [name for name in PART_ORDER if self.part_count(name)]

    def part_count(self, name: str) -> int:
        if name == "drums":
            return len(self.hits)
        return len(self.notes.get(name, ()))


def compose(config: BGMConfig | None = None, **overrides) -> Arrangement:
    """音を合成せずに譜面だけを組み立てる。

    生成前に中身を確認したり、別の音源へ渡したりできるようにしてある。
    """
    config = _with_overrides(config, overrides)
    validate(config)
    style = config.resolved_style()

    rng = random.Random(config.seed)
    # グルーヴ用は別系列にしておく。ゆらぎの有無でメロディまで変わらないようにする。
    groove_rng = random.Random((config.seed or 0) + 7919)
    bar_seconds = BEATS_PER_BAR * 60.0 / style.bpm
    degrees = _chord_degrees_for_bars(style, config.bars)
    if config.ending:
        degrees[-1] = 0  # 最後は主和音へ帰る
    chosen = set(config.parts if config.parts is not None else style.parts)
    requested = [part for part in PART_ORDER if part in chosen and part not in set(config.without)]
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
    if config.ending:
        _apply_ending(notes_by_part, hits, config.bars, bar_seconds)

    duration = config.bars * bar_seconds
    curve = TempoCurve(config.ritardando, config.final_tempo)
    if curve.enabled():
        duration = _apply_tempo_curve(notes_by_part, hits, curve, duration, bar_seconds)
    return Arrangement(style, config.bars, bar_seconds, tuple(plan), notes_by_part, hits, duration)


def _apply_tempo_curve(
    notes_by_part: dict[str, list[Note]],
    hits: list[Hit],
    curve: TempoCurve,
    total: float,
    bar_seconds: float,
) -> float:
    """等速で並べた譜面の時間軸を伸ばす(その場で書き換える)。

    音の長さも同じ物差しで伸ばすので、緩めた区間では音符も長くなる。
    """
    for part, plan in notes_by_part.items():
        notes_by_part[part] = [
            replace(
                note,
                start=curve.warp(note.start, total, bar_seconds),
                length=curve.warp(note.start + note.length, total, bar_seconds)
                - curve.warp(note.start, total, bar_seconds),
            )
            for note in plan
        ]
    hits[:] = [replace(hit, start=curve.warp(hit.start, total, bar_seconds)) for hit in hits]
    return curve.total(total, bar_seconds)


def _apply_ending(
    notes_by_part: dict[str, list[Note]],
    hits: list[Hit],
    bars: int,
    bar_seconds: float,
) -> None:
    """最後の小節を終止の形に整える(その場で書き換える)。

    刻みを続けたまま切ると「途中で止まった」ように聞こえる。最後の小節は
    主和音をひとつ伸ばし、他は鳴らさないことで、曲として終わった形にする。
    """
    last_start = (bars - 1) * bar_seconds
    tolerance = bar_seconds * 0.05  # 揺らぎで少し前に出た音も最後の小節とみなす

    for part, plan in notes_by_part.items():
        kept = [note for note in plan if note.start < last_start - tolerance]
        if part == "chords":
            # 主和音だけを1小節伸ばして締める。
            final = [note for note in plan if note.start >= last_start - tolerance]
            if final:
                lowest = min(note.start for note in final)
                voicing = {note.midi: note.velocity for note in final if note.start <= lowest + tolerance}
                kept += [
                    Note(last_start, midi, bar_seconds, velocity)
                    for midi, velocity in sorted(voicing.items())
                ]
        elif part == "bass":
            final = [note for note in plan if note.start >= last_start - tolerance]
            if final:
                first = min(final, key=lambda note: note.start)
                kept.append(replace(first, start=last_start, length=bar_seconds * 0.9))
        notes_by_part[part] = kept

    remaining = [hit for hit in hits if hit.start < last_start - tolerance]
    remaining.append(Hit(last_start, "crash", 1.0))
    remaining.append(Hit(last_start, "kick", 1.0))
    hits[:] = remaining


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
    shift = section.transpose
    if part == "chords":
        return _plan_chords(config, style, degrees, bar_seconds, groove_rng, shift)
    if part == "arp":
        return _plan_arp(config, style, degrees, bar_seconds, groove_rng, shift)
    if part == "bass":
        return _plan_bass(config, style, degrees, bar_seconds, groove_rng, shift)
    if part == "lead":
        root = _root_midi(config.key, style.lead_octave + section.lead_octave) + shift
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
            {"name": section.name, "start_bar": start, "bars": count, "transpose": section.transpose}
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
    return _render_arrangement(compose(config), config)


def _render_arrangement(arrangement: Arrangement, config: BGMConfig) -> dict[str, list[float]]:
    style = arrangement.style
    sr = config.sr
    cache: dict = {}

    synths = {
        "chords": _synth_for(style.chord_instrument, sr),
        "arp": _synth_for(style.arp_instrument, sr),
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


# パートの定位。低音とドラムは中央に置き、上物を左右に振って場所を空ける。
# 位相をいじる widening は使わない(モノラルにまとめたとき打ち消しが出る)。
_PART_PAN = {"chords": -0.5, "arp": 0.55, "bass": 0.0, "lead": 0.22, "drums": 0.0}


def _part_gains(style: Style) -> dict[str, float]:
    return {
        "chords": style.chord_gain,
        "arp": style.arp_gain,
        "bass": style.bass_gain,
        "lead": style.lead_gain,
        "drums": style.drum_gain,
    }


TARGET_PEAK = 0.86
TARGET_LOUDNESS = -15.0
"""仕上げの体感音量(LUFS 相当)。

ピークだけ揃えると、音の詰まった曲と隙間の多い曲で聞こえる大きさが変わる。
素材として並べたときに音量を触らなくて済むよう、体感音量の方をそろえる。
天井を越える場合はピーク優先(歪ませない)。"""
DUCK_AMOUNT = 0.22
"""バスドラムの瞬間に他パートを下げる量。"""

LIMIT_THRESHOLD = 0.62
"""リミッターが働き始める大きさ。"""


def _duck_to_kick(
    tracks: dict[str, list[float]],
    arrangement: Arrangement,
    sr: int,
) -> dict[str, list[float]]:
    """バスドラムの瞬間だけ、ドラム以外のパートを軽く下げる。

    低音どうしがぶつかると輪郭がぼやけるので、キックの頭で場所を空ける。
    """
    kicks = [hit.start for hit in arrangement.hits if hit.voice == "kick"]
    if not kicks:
        return tracks
    length = max((len(track) for track in tracks.values()), default=0)
    curve = fx.sidechain_envelope(kicks, length, sr, amount=DUCK_AMOUNT)
    return {
        name: (track if name == "drums" else env.apply(track, curve))
        for name, track in tracks.items()
    }


def _post_process(
    buf: list[float],
    style: Style,
    config: BGMConfig,
    length: int,
    limit: bool = True,
) -> list[float]:
    """モノラル1本にマスター処理をかける(音量調整は呼び出し側)。"""
    return _master([buf], style, config, length, limit)[0]


def _master(
    channels: list[list[float]],
    style: Style,
    config: BGMConfig,
    length: int,
    limit: bool = True,
) -> list[list[float]]:
    """1本(モノラル)または2本(ステレオ)に、同じマスター処理をかける。

    ステレオでは左右を別々に処理せず、残響は共通のセンドから左右へ分け、
    リミッターは共通のゲインで動かす。そうしないと音像が左右へ動いてしまう。
    """
    sr = config.sr
    if style.bitcrush_bits:
        channels = [fx.bitcrush(c, bits=style.bitcrush_bits) for c in channels]
    if style.delay_wet > 0:
        beat = 60.0 / style.bpm
        channels = [
            fx.delay(c, time=beat * 0.75, feedback=0.3, wet=style.delay_wet, sr=sr, tail=beat * 3)
            for c in channels
        ]

    if style.reverb_wet > 0:
        if len(channels) == 2:
            # 左右をまとめた信号を1つの部屋へ送り、返りだけ左右で変える。
            send = [(a + b) * 0.5 for a, b in zip(*channels)]
            wet_pair = fx.reverb_stereo(send, room=style.reverb_room, sr=sr, tail=1.0)
            amount = style.reverb_wet
            channels = [
                [
                    (c[i] if i < len(c) else 0.0) * (1.0 - amount) + w[i] * amount
                    for i in range(len(w))
                ]
                for c, w in zip(channels, wet_pair)
            ]
        else:
            channels = [
                fx.reverb(c, room=style.reverb_room, wet=style.reverb_wet, sr=sr, tail=1.0)
                for c in channels
            ]

    # 終わる曲(と、テンポを緩める曲)は残響を折り返さず鳴らしきる。
    looping = config.loop and not config.ending and config.ritardando <= 0.0
    channels = [remove_dc(wrap_tail(c, length) if looping else c) for c in channels]
    # ループ曲は EQ も一周ぶん前置きしてから通す。そうしないとフィルタの
    # 状態が先頭でゼロ・末尾で満杯になり、継ぎ目に段差が残る。
    if looping:
        channels = [fx.circular(lambda c: style.eq.apply(c, sr), c, sr) for c in channels]
    else:
        channels = [style.eq.apply(c, sr) for c in channels]
    if not limit:
        return channels

    # 飛び出した山を削ってから持ち上げる。天井付近だけ丸めて 0dBFS を超えさせない。
    limited = fx.linked_limiter(channels, threshold=LIMIT_THRESHOLD, sr=sr)
    return [fx.soft_clip(c, ceiling=0.98) for c in limited]


def generate(config: BGMConfig | None = None, **overrides) -> list[float]:
    """BGM をモノラルバッファとして生成する。"""
    config = _with_overrides(config, overrides)
    arrangement = compose(config)
    style = arrangement.style
    tracks = _duck_to_kick(_render_arrangement(arrangement, config), arrangement, config.sr)
    gains = _part_gains(style)
    length = num_samples(arrangement.length_seconds, config.sr)

    names = list(tracks)
    mixed = mix(*(tracks[name] for name in names), gains=[gains[name] for name in names]) if names else []
    return normalize_loudness(
        _post_process(mixed, style, config, length), TARGET_LOUDNESS, config.sr, TARGET_PEAK
    )


def generate_stereo(config: BGMConfig | None = None, **overrides) -> list[float]:
    """BGM を L,R インターリーブのステレオバッファとして生成する。"""
    config = _with_overrides(config, overrides)
    arrangement = compose(config)
    style = arrangement.style
    tracks = _duck_to_kick(_render_arrangement(arrangement, config), arrangement, config.sr)
    gains = _part_gains(style)
    length = num_samples(arrangement.length_seconds, config.sr)

    left_parts: list[list[float]] = []
    right_parts: list[list[float]] = []
    for name, track in tracks.items():
        left, right = pan(track, _PART_PAN.get(name, 0.0))
        left_parts.append([value * gains[name] for value in left])
        right_parts.append([value * gains[name] for value in right])

    left, right = _master(
        [mix(*left_parts) if left_parts else [], mix(*right_parts) if right_parts else []],
        style, config, length,
    )

    # 定位を崩さないよう、L/R をまとめて同じ倍率で調整する。
    summed = [(a + b) * 0.5 for a, b in zip(left, right)]
    scale = _loudness_scale(summed, max(peak(left), peak(right)), config.sr)
    return to_stereo([v * scale for v in left], [v * scale for v in right])


def _loudness_scale(reference: list[float], current_peak: float, sr: int) -> float:
    """体感音量を目標に合わせる倍率。天井を越えるならそこで止める。"""
    if not reference or current_peak < 1e-12:
        return 1.0
    current = loudness(reference, sr)
    scale = 10.0 ** ((TARGET_LOUDNESS - current) / 20.0)
    return min(scale, TARGET_PEAK / current_peak)

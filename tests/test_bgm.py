"""BGM ジェネレータのテスト。"""

from __future__ import annotations

import pytest

from audiogen import bgm, core, drums
from audiogen import notes as notes_module

SR = 11025


def _config(**kwargs) -> bgm.BGMConfig:
    params = {"bars": 2, "seed": 0, "sr": SR}
    params.update(kwargs)
    return bgm.BGMConfig(**params)


@pytest.mark.parametrize("style", bgm.style_names())
def test_every_style_renders_audible_bounded_audio(style):
    buf = bgm.generate(_config(style=style))
    assert core.peak(buf) == pytest.approx(bgm.TARGET_PEAK, abs=1e-6)
    assert max(abs(v) for v in buf) <= 1.0


@pytest.mark.parametrize("style", bgm.style_names())
def test_every_style_is_free_of_dc_offset(style):
    buf = bgm.generate(_config(style=style))
    assert abs(sum(buf) / len(buf)) < 0.01


@pytest.mark.parametrize("style", bgm.style_names())
def test_loop_length_matches_bars_and_tempo(style):
    config = _config(style=style, bars=2)
    buf = bgm.generate(config)
    bpm = config.resolved_style().bpm
    expected = core.num_samples(2 * bgm.BEATS_PER_BAR * 60.0 / bpm, SR)
    assert len(buf) == expected


def test_no_loop_keeps_the_reverb_tail():
    looped = bgm.generate(_config(style="night", loop=True))
    open_ended = bgm.generate(_config(style="night", loop=False))
    assert len(open_ended) > len(looped)


def test_same_seed_gives_the_same_track():
    assert bgm.generate(_config(seed=42)) == bgm.generate(_config(seed=42))


def test_different_seeds_give_different_tracks():
    assert bgm.generate(_config(seed=1)) != bgm.generate(_config(seed=2))


def test_bars_scale_the_duration():
    short = bgm.generate(_config(bars=2))
    long = bgm.generate(_config(bars=4))
    assert len(long) == pytest.approx(2 * len(short), rel=0.01)


def test_bpm_override_shortens_the_track():
    fast = bgm.generate(_config(style="calm", bpm=160))
    slow = bgm.generate(_config(style="calm", bpm=80))
    assert len(fast) < len(slow)


def test_key_override_transposes_the_track():
    c_major = bgm.generate(_config(key="C"))
    a_major = bgm.generate(_config(key="A"))
    assert c_major != a_major


def test_render_tracks_returns_the_requested_parts():
    tracks = bgm.render_tracks(_config(style="adventure"))
    assert set(tracks) == {"chords", "bass", "lead", "drums"}
    assert all(len(track) > 0 for track in tracks.values())


def test_parts_can_be_dropped():
    tracks = bgm.render_tracks(_config(parts=("bass",)))
    assert set(tracks) == {"bass"}


def test_style_without_drums_yields_no_drum_track():
    assert "drums" not in bgm.render_tracks(_config(style="night"))


def test_drum_pattern_override_is_applied():
    tracks = bgm.render_tracks(_config(style="night", drum_pattern="basic"))
    assert "drums" in tracks


def test_progression_override_changes_the_harmony():
    a = bgm.generate(_config(progression="I-I-I-I", parts=("chords",)))
    b = bgm.generate(_config(progression="I-V-vi-IV", parts=("chords",)))
    assert a != b


def test_stereo_output_is_interleaved_and_twice_as_long():
    config = _config(style="menu")
    mono = bgm.generate(config)
    stereo = bgm.generate_stereo(config)
    assert len(stereo) == 2 * len(mono)
    assert stereo[0::2] != stereo[1::2]  # パンで L/R に差が出る


def test_keyword_overrides_work_without_building_a_config():
    buf = bgm.generate(bars=1, seed=3, sr=SR, style="menu")
    assert len(buf) > 0


def test_unknown_style_raises():
    with pytest.raises(ValueError, match="unknown bgm style"):
        bgm.generate(_config(style="jazz-fusion"))


def test_zero_bars_raises():
    with pytest.raises(ValueError, match="bars"):
        bgm.generate(_config(bars=0))


def test_unknown_drum_pattern_raises():
    with pytest.raises(ValueError, match="unknown drum pattern"):
        bgm.generate(_config(drum_pattern="bossa"))


@pytest.mark.parametrize("name", drums.pattern_names())
def test_drum_patterns_are_sixteen_steps(name):
    for steps in drums.get_pattern(name).values():
        assert len(steps) == drums.STEPS_PER_BAR
        assert set(steps) <= {"x", "o", "."}


@pytest.mark.parametrize("name", drums.pattern_names())
def test_drum_patterns_only_use_known_voices(name):
    assert set(drums.get_pattern(name)) <= set(drums.VOICES)


@pytest.mark.parametrize("voice", sorted(drums.VOICES))
def test_drum_voices_are_audible_and_bounded(voice):
    buf = drums.VOICES[voice](sr=SR)
    assert 0.1 < core.peak(buf) <= 1.0
    assert core.duration_of(buf, SR) < 1.5


@pytest.mark.parametrize("voice", ["kick", "snare", "hihat", "clap", "tom", "ride"])
def test_tight_drum_voices_stay_short(voice):
    """打点がはっきりしていてほしい音色は、次の16分に被らない長さに収める。"""
    assert core.duration_of(drums.VOICES[voice](sr=SR), SR) < 0.5


@pytest.mark.parametrize("voice", ["timpani", "crash"])
def test_orchestral_voices_are_allowed_to_ring(voice):
    """ティンパニとシンバルは余韻が持ち味なので長くてよい。"""
    assert 0.5 <= core.duration_of(drums.VOICES[voice](sr=SR), SR) < 1.5


# --- 曲構成 -------------------------------------------------------------------


@pytest.mark.parametrize("structure", bgm.structure_names())
def test_every_structure_renders(structure):
    buf = bgm.generate(_config(style="adventure", bars=8, structure=structure))
    assert core.peak(buf) == pytest.approx(bgm.TARGET_PEAK, abs=1e-6)


@pytest.mark.parametrize("structure", bgm.structure_names())
@pytest.mark.parametrize("bars", [1, 2, 3, 8, 16, 17])
def test_section_bars_always_sum_to_the_requested_total(structure, bars):
    plan = bgm.plan_sections(structure, bars)
    assert sum(count for _, _, count in plan) == bars
    assert all(count >= 1 for _, _, count in plan)


@pytest.mark.parametrize("structure", bgm.structure_names())
def test_sections_are_laid_out_end_to_end(structure):
    plan = bgm.plan_sections(structure, 16)
    expected_start = 0
    for _, start, count in plan:
        assert start == expected_start
        expected_start += count


def test_structure_does_not_change_the_total_length():
    """構成を変えても、小節数が同じなら曲の長さは変わらない。"""
    plain = bgm.generate(_config(style="adventure", bars=8, structure="loop"))
    full = bgm.generate(_config(style="adventure", bars=8, structure="full"))
    assert len(plain) == len(full)


def test_intro_section_has_no_drums():
    """イントロではドラムが鳴らないこと。"""
    config = _config(style="adventure", bars=8, structure="intro", humanize=0.0)
    arrangement = bgm.compose(config)
    intro_bars = arrangement.sections[0][2]
    intro_end = intro_bars * arrangement.bar_seconds
    assert arrangement.hits
    assert min(hit.start for hit in arrangement.hits) >= intro_end


def test_chorus_lead_sits_higher_than_the_verse_lead():
    """サビのメロディが A メロより高い位置にあること。"""
    config = _config(style="adventure", bars=8, structure="verse_chorus", parts=("lead",))
    lead = bgm.render_tracks(config)["lead"]
    half = len(lead) // 2
    verse, chorus = lead[:half], lead[half:]
    assert _zero_crossing_rate(chorus) > _zero_crossing_rate(verse)


def test_too_few_bars_falls_back_to_the_leading_sections():
    plan = bgm.plan_sections("full", 2)
    assert [section.name for section, _, _ in plan] == ["intro", "verse"]


def test_unknown_structure_raises():
    with pytest.raises(ValueError, match="unknown structure"):
        bgm.generate(_config(structure="sonata"))


def _zero_crossing_rate(buf) -> float:
    """ゼロ交差の割合。音の高さの目安になる。"""
    crossings = sum(1 for a, b in zip(buf, buf[1:]) if (a < 0) != (b < 0))
    return crossings / max(1, len(buf))


# --- モチーフによるメロディ展開 -----------------------------------------------


def _bar_rhythm(lead, bar_index, bar_seconds, sr, slots=16):
    """1小節を16分割し、それぞれの区画に音があるかどうかを並べる。"""
    start = core.num_samples(bar_index * bar_seconds, sr)
    step = core.num_samples(bar_seconds / slots, sr)
    return [core.peak(lead[start + i * step : start + (i + 1) * step]) > 1e-6 for i in range(slots)]


def test_repeated_bars_share_the_same_rhythm():
    """同じ役割の小節では、音の置かれる位置がそろっていること。"""
    config = _config(style="adventure", bars=4, parts=("lead",), seed=11)
    lead = bgm.render_tracks(config)["lead"]
    bar_seconds = bgm.BEATS_PER_BAR * 60.0 / config.resolved_style().bpm
    first = _bar_rhythm(lead, 0, bar_seconds, SR)   # A
    second = _bar_rhythm(lead, 1, bar_seconds, SR)  # A(同じモチーフ)
    assert first == second
    assert any(first)  # 全休符ではない


def test_the_contrasting_bar_differs_from_the_motif():
    """3小節目(B)はモチーフと別の句であること。"""
    config = _config(style="adventure", bars=4, parts=("lead",), seed=11)
    lead = bgm.render_tracks(config)["lead"]
    bar_seconds = bgm.BEATS_PER_BAR * 60.0 / config.resolved_style().bpm
    assert _bar_rhythm(lead, 0, bar_seconds, SR) != _bar_rhythm(lead, 2, bar_seconds, SR)


@pytest.mark.parametrize("style", bgm.style_names())
def test_phrases_fill_exactly_one_bar(style):
    import random as _random

    resolved = bgm.STYLES[style]
    phrase = bgm._make_phrase(resolved, _random.Random(0), 7)
    assert sum(length for _, length in phrase) == pytest.approx(bgm.BEATS_PER_BAR)


def test_anchor_shift_lands_the_first_note_on_a_chord_tone():
    phrase = [(3, 1.0), (5, 1.0), (None, 2.0)]
    for chord_degree in range(7):
        shift = bgm._anchor_shift(phrase, chord_degree, 7)
        assert (3 + shift - chord_degree) % 7 in (0, 2, 4)


def test_anchor_shift_of_an_all_rest_phrase_is_zero():
    assert bgm._anchor_shift([(None, 4.0)], 3, 7) == 0


def test_variation_changes_only_the_last_sounding_note():
    import random as _random

    motif = [(0, 1.0), (2, 1.0), (None, 1.0), (4, 1.0)]
    varied = bgm._vary_phrase(motif, _random.Random(1), span=8)
    assert varied[:3] == motif[:3]
    assert varied[3] != motif[3]
    assert varied[3][1] == motif[3][1]  # 長さは変わらない


def test_verse_and_chorus_reuse_the_same_motif():
    """区間をまたいでも同じ素材を使い、曲としてのまとまりを保つこと。"""
    config = _config(style="adventure", bars=8, structure="verse_chorus", parts=("lead",), seed=3)
    lead = bgm.render_tracks(config)["lead"]
    bar_seconds = bgm.BEATS_PER_BAR * 60.0 / config.resolved_style().bpm
    assert _bar_rhythm(lead, 0, bar_seconds, SR) == _bar_rhythm(lead, 4, bar_seconds, SR)


# --- グルーヴ -----------------------------------------------------------------


def test_swing_delays_only_the_offbeat_eighths():
    import random as _random

    groove = bgm.Groove(swing=0.5)
    rng = _random.Random(0)
    offsets = [groove.time_offset(step, 0.1, rng) for step in range(16)]
    assert [i for i, value in enumerate(offsets) if value > 0] == [2, 6, 10, 14]
    assert offsets[2] == pytest.approx(0.05)


def test_a_straight_groove_moves_nothing():
    import random as _random

    rng = _random.Random(0)
    assert all(bgm.STRAIGHT.time_offset(step, 0.1, rng) == 0.0 for step in range(16))


def test_accents_make_the_downbeat_the_loudest():
    import random as _random

    groove = bgm.Groove(accent=0.4)
    rng = _random.Random(0)
    levels = [groove.velocity(step, rng) for step in range(16)]
    assert levels[0] == max(levels)
    assert levels[1] == min(levels)
    assert levels[8] > levels[4] > levels[2] > levels[1]


def test_no_accent_means_every_note_is_equal():
    import random as _random

    rng = _random.Random(0)
    groove = bgm.Groove(accent=0.0)
    assert {groove.velocity(step, rng) for step in range(16)} == {1.0}


def test_humanize_jitters_within_the_requested_range():
    import random as _random

    groove = bgm.Groove(humanize=0.01)
    rng = _random.Random(0)
    offsets = [groove.time_offset(step, 0.1, rng) for step in range(200) if step % 4 != 2]
    assert all(abs(value) <= 0.01 for value in offsets)
    assert any(value != 0.0 for value in offsets)


def test_swing_shifts_the_offbeat_later():
    """スウィングを強めると、裏の8分音符だけが後ろへ動くこと。"""
    straight = bgm.compose(_config(bars=1, parts=("drums",), swing=0.0, humanize=0.0)).hits
    swung = bgm.compose(_config(bars=1, parts=("drums",), swing=0.6, humanize=0.0)).hits
    assert len(straight) == len(swung)
    assert all(b.start >= a.start for a, b in zip(straight, swung))
    assert any(b.start > a.start for a, b in zip(straight, swung))


def test_humanize_zero_keeps_the_grid_exact():
    """ゆらぎ 0 なら、音は16分グリッドの上にぴったり乗ること。"""
    config = _config(style="adventure", bars=2, parts=("drums",), swing=0.0, humanize=0.0)
    arrangement = bgm.compose(config)
    step = arrangement.bar_seconds / drums.STEPS_PER_BAR
    for hit in arrangement.hits:
        assert hit.start % step == pytest.approx(0.0, abs=1e-9) or (
            step - hit.start % step
        ) == pytest.approx(0.0, abs=1e-9)


def test_humanize_moves_notes_off_the_grid():
    exact = bgm.compose(_config(bars=2, parts=("drums",), swing=0.0, humanize=0.0)).hits
    loose = bgm.compose(_config(bars=2, parts=("drums",), swing=0.0, humanize=0.01)).hits
    assert [hit.start for hit in exact] != [hit.start for hit in loose]
    assert all(abs(b.start - a.start) <= 0.01 for a, b in zip(exact, loose))


def test_groove_does_not_change_the_melody():
    """ゆらぎを変えても、メロディの音そのものは変わらないこと。"""
    tight = bgm.compose(_config(bars=4, parts=("lead",), humanize=0.0, seed=5)).notes["lead"]
    loose = bgm.compose(_config(bars=4, parts=("lead",), humanize=0.01, seed=5)).notes["lead"]
    assert [note.midi for note in tight] == [note.midi for note in loose]
    assert [note.start for note in tight] != [note.start for note in loose]


def test_chiptune_stays_perfectly_quantized():
    assert bgm.STYLES["chiptune"].groove is bgm.STRAIGHT


def test_swing_is_clamped_to_a_usable_range():
    assert _config(swing=5.0).resolved_style().groove.swing == pytest.approx(0.7)
    assert _config(swing=-1.0).resolved_style().groove.swing == 0.0




# --- 譜面(compose / describe) -----------------------------------------------


def test_compose_returns_notes_for_every_requested_part():
    arrangement = bgm.compose(_config(style="adventure", bars=4))
    assert set(arrangement.notes) == {"chords", "bass", "lead"}
    assert arrangement.hits
    assert arrangement.parts() == ["chords", "bass", "lead", "drums"]


def test_composed_notes_stay_inside_the_track():
    arrangement = bgm.compose(_config(style="adventure", bars=4))
    for plan in arrangement.notes.values():
        assert all(0.0 <= note.start < arrangement.length_seconds for note in plan)
    assert all(0.0 <= hit.start < arrangement.length_seconds for hit in arrangement.hits)


def test_composed_notes_are_in_the_scale():
    """作られた音がすべて指定した音階に収まっていること。"""
    config = _config(style="calm", key="C", bars=8)
    arrangement = bgm.compose(config)
    allowed = {(60 + step) % 12 for step in notes_module.scale_degrees(arrangement.style.scale)}
    for part, plan in arrangement.notes.items():
        for note in plan:
            assert note.midi % 12 in allowed, f"{part}: {notes_module.midi_to_name(note.midi)}"


def test_compose_is_deterministic():
    assert bgm.compose(_config(seed=9)).notes == bgm.compose(_config(seed=9)).notes


def test_compose_costs_no_audio_rendering():
    """譜面だけなら小節数を増やしても音符が増えるだけであること。"""
    short = bgm.compose(_config(bars=4, style="adventure"))
    long = bgm.compose(_config(bars=8, style="adventure"))
    assert long.part_count("lead") > short.part_count("lead")
    assert long.length_seconds == pytest.approx(2 * short.length_seconds)


def test_describe_summarises_the_track():
    summary = bgm.describe(_config(style="battle", key="A", bars=8, structure="full", seed=2))
    assert summary["style"] == "battle"
    assert summary["key"] == "A"
    assert summary["bars"] == 8
    assert [section["name"] for section in summary["sections"]] == ["intro", "verse", "chorus", "outro"]
    assert len(summary["chords"]) == 8
    assert all(len(chord["notes"]) >= 3 for chord in summary["chords"])
    assert summary["melody"]
    assert summary["note_counts"]["lead"] == len(summary["melody"])


def test_describe_is_json_serialisable():
    import json

    assert json.loads(json.dumps(bgm.describe(_config(bars=4))))["bars"] == 4


# --- マスター段 ---------------------------------------------------------------


def test_kick_ducks_the_other_parts():
    """バスドラムの瞬間に、ドラム以外のパートが下がること。"""
    config = _config(style="adventure", bars=2, humanize=0.0)
    arrangement = bgm.compose(config)
    plain = bgm._render_arrangement(arrangement, config)
    ducked = bgm._duck_to_kick(dict(plain), arrangement, SR)

    kick = min(hit.start for hit in arrangement.hits if hit.voice == "kick")
    at_kick = core.num_samples(kick + 0.02, SR)
    assert abs(ducked["bass"][at_kick]) < abs(plain["bass"][at_kick])
    assert ducked["drums"] == plain["drums"]  # ドラム自身は下げない


def test_ducking_is_skipped_without_a_kick():
    config = _config(style="night", bars=2)
    arrangement = bgm.compose(config)
    plain = bgm._render_arrangement(arrangement, config)
    assert bgm._duck_to_kick(dict(plain), arrangement, SR) == plain


def test_mastering_raises_loudness_without_clipping():
    """リミッターを通したほうが、同じピークでも中身が大きいこと。"""
    config = _config(style="battle", bars=4, seed=4)
    mastered = bgm.generate(config)

    style = config.resolved_style()
    arrangement = bgm.compose(config)
    tracks = bgm._render_arrangement(arrangement, config)
    gains = bgm._part_gains(style)
    names = list(tracks)
    raw = core.mix(*(tracks[name] for name in names), gains=[gains[name] for name in names])
    raw = bgm._post_process(raw, style, config, len(mastered), limit=False)
    raw = core.normalize(raw, bgm.TARGET_PEAK)

    assert core.peak(mastered) == pytest.approx(bgm.TARGET_PEAK, abs=1e-6)
    assert _rms(mastered) > _rms(raw) * 1.15


def _rms(buf):
    import math

    return math.sqrt(sum(value * value for value in buf) / len(buf))


# --- 放送向けの曲想 -----------------------------------------------------------

BROADCAST = ["news_open", "news_bed", "sports_anthem", "sports_drive"]


@pytest.mark.parametrize("style", BROADCAST)
def test_broadcast_styles_render(style):
    buf = bgm.generate(_config(style=style, bars=4))
    assert core.peak(buf) == pytest.approx(bgm.TARGET_PEAK, abs=1e-6)


def test_the_news_bed_leaves_out_the_melody():
    """話し声とぶつからないよう、下敷きにはメロディを乗せない。"""
    arrangement = bgm.compose(_config(style="news_bed", bars=4))
    assert "lead" not in arrangement.parts()
    assert "chords" in arrangement.parts()


def test_the_news_bed_is_quieter_than_the_opening_theme():
    bed = bgm.compose(_config(style="news_bed", bars=4))
    theme = bgm.compose(_config(style="news_open", bars=4))
    assert bed.style.drum_gain < theme.style.drum_gain
    assert bed.part_count("lead") == 0 < theme.part_count("lead")


def test_a_style_can_declare_its_own_parts():
    assert "arp" in bgm.STYLES["news_open"].parts
    assert "arp" not in bgm.STYLES["calm"].parts
    assert "arp" not in bgm.compose(_config(style="calm", bars=2)).parts()


def test_without_drops_a_part_from_the_style_default():
    arrangement = bgm.compose(_config(style="news_open", bars=2, without=("arp", "drums")))
    assert "arp" not in arrangement.parts()
    assert "drums" not in arrangement.parts()
    assert "chords" in arrangement.parts()


def test_explicit_parts_override_the_style_default():
    assert bgm.compose(_config(style="news_open", bars=2, parts=("bass",))).parts() == ["bass"]


# --- 和音のリズムとアルペジオ -------------------------------------------------


def test_a_chord_pattern_turns_sustained_chords_into_stabs():
    """刻みを指定すると、1小節1回ではなくパターンどおりの回数だけ鳴る。"""
    held = bgm.compose(_config(style="calm", bars=1, parts=("chords",))).notes["chords"]
    stabs = bgm.compose(_config(style="news_open", bars=1, parts=("chords",))).notes["chords"]
    assert len({round(note.start, 4) for note in held}) == 1
    assert len({round(note.start, 4) for note in stabs}) == 5  # x..x..x...x.x...


def test_stabbed_chords_are_shorter_than_a_bar():
    arrangement = bgm.compose(_config(style="news_open", bars=1, parts=("chords",)))
    assert all(note.length < arrangement.bar_seconds * 0.5 for note in arrangement.notes["chords"])


def test_sustained_chords_fill_the_whole_bar():
    arrangement = bgm.compose(_config(style="calm", bars=1, parts=("chords",)))
    assert all(
        note.length == pytest.approx(arrangement.bar_seconds) for note in arrangement.notes["chords"]
    )


def test_the_arpeggio_walks_through_the_chord_tones():
    """アルペジオが和音の構成音だけを、指定した順に辿ること。"""
    config = _config(style="news_open", bars=1, parts=("chords", "arp"))
    arrangement = bgm.compose(config)
    chord_classes = {note.midi % 12 for note in arrangement.notes["chords"]}
    arp = arrangement.notes["arp"]
    assert len(arp) == 16  # oxoxoxoxoxoxoxox
    assert all(note.midi % 12 in chord_classes for note in arp)
    assert len({note.midi for note in arp}) > 1  # 同じ音の連打ではない


def test_the_arpeggio_sits_above_the_chords():
    arrangement = bgm.compose(_config(style="news_open", bars=1, parts=("chords", "arp")))
    lowest_arp = min(note.midi for note in arrangement.notes["arp"])
    highest_chord = max(note.midi for note in arrangement.notes["chords"])
    assert lowest_arp >= highest_chord


def test_a_style_without_an_arp_pattern_has_no_arpeggio():
    assert bgm.compose(_config(style="sports_anthem", bars=2)).part_count("arp") == 0


def test_the_arpeggio_is_panned_opposite_the_chords():
    """和音とアルペジオが左右に分かれ、混ざって団子にならないこと。"""
    assert bgm._PART_PAN["arp"] * bgm._PART_PAN["chords"] < 0


# --- 編曲の仕上げ(声部連結・フィル・終止・経過音) ---------------------------


def _voicings_by_bar(arrangement, part="chords"):
    bars = {}
    for note in arrangement.notes[part]:
        bars.setdefault(int(note.start / arrangement.bar_seconds + 0.001), set()).add(note.midi)
    return [sorted(bars[bar]) for bar in sorted(bars)]


def test_chords_are_voice_led_between_bars():
    """和音が毎回基本形へ飛ばず、近い音へつながっていること。"""
    config = _config(style="sports_anthem", bars=4, parts=("chords",), humanize=0.0)
    voiced = _voicings_by_bar(bgm.compose(config))
    led = sum(notes_module.voice_movement(a, b) for a, b in zip(voiced, voiced[1:]))

    plain_style = bgm.STYLES["sports_anthem"]
    root = bgm._root_midi("C", plain_style.chord_octave)
    plain_chords = [
        notes_module.diatonic_chord(root, plain_style.scale, degree)
        for degree in notes_module.parse_progression(plain_style.progression)
    ]
    plain = sum(notes_module.voice_movement(a, b) for a, b in zip(plain_chords, plain_chords[1:]))
    assert led < plain


def test_voice_leading_can_be_turned_off_per_style():
    """基本形の並びが持ち味の曲想では、連結しないこと。"""
    assert bgm.STYLES["chiptune"].chord_voice_lead is False
    voiced = _voicings_by_bar(bgm.compose(_config(style="chiptune", bars=4, parts=("chords",))))
    root = bgm._root_midi("C", bgm.STYLES["chiptune"].chord_octave)
    expected = notes_module.diatonic_chord(root, "major", 0)
    assert voiced[0] == sorted(expected)


def test_a_fill_replaces_the_last_bar_of_a_section():
    """区間の最後の小節だけ、いつもと違う手になること。"""
    config = _config(style="sports_drive", bars=4, parts=("drums",), humanize=0.0)
    arrangement = bgm.compose(config)
    bar = arrangement.bar_seconds

    def voices(index):
        return sorted({h.voice for h in arrangement.hits if index * bar <= h.start < (index + 1) * bar})

    assert voices(0) == voices(1) == voices(2)
    assert voices(3) != voices(0)


def test_a_fill_needs_at_least_two_bars():
    """1小節しかないときは、フィルだけの曲にならないこと。"""
    arrangement = bgm.compose(_config(style="sports_drive", bars=1, parts=("drums",)))
    assert "ride" in {hit.voice for hit in arrangement.hits}


def test_styles_only_use_known_fills():
    for name in bgm.style_names():
        fill = bgm.STYLES[name].drum_fill
        if fill:
            drums.get_fill(fill)


def test_unknown_fill_raises():
    with pytest.raises(ValueError, match="unknown drum fill"):
        drums.get_fill("paradiddle")


@pytest.mark.parametrize("name", drums.fill_names())
def test_fills_are_sixteen_steps_of_known_voices(name):
    for voice, steps in drums.get_fill(name).items():
        assert voice in drums.VOICES
        assert len(steps) == drums.STEPS_PER_BAR
        assert set(steps) <= {"x", "o", "."}


def test_the_ending_lands_on_the_tonic():
    """終止を付けると、最後の小節が主和音になること。"""
    config = _config(style="sports_anthem", bars=8, ending=True, humanize=0.0)
    arrangement = bgm.compose(config)
    last = (arrangement.bars - 1) * arrangement.bar_seconds
    final = {note.midi % 12 for note in arrangement.notes["chords"] if note.start >= last - 0.1}
    tonic = {m % 12 for m in notes_module.diatonic_chord(bgm._root_midi("C", 4), "major", 0)}
    assert final == tonic


def test_the_ending_stops_the_melody_and_the_groove():
    config = _config(style="sports_anthem", bars=8, ending=True, humanize=0.0)
    arrangement = bgm.compose(config)
    last = (arrangement.bars - 1) * arrangement.bar_seconds
    assert not [note for note in arrangement.notes["lead"] if note.start >= last - 0.1]
    assert sorted({h.voice for h in arrangement.hits if h.start >= last - 0.1}) == ["crash", "kick"]


def test_the_ending_holds_the_final_chord_for_a_whole_bar():
    arrangement = bgm.compose(_config(style="sports_anthem", bars=8, ending=True, humanize=0.0))
    last = (arrangement.bars - 1) * arrangement.bar_seconds
    final = [note for note in arrangement.notes["chords"] if note.start >= last - 0.1]
    assert final
    assert all(note.length == pytest.approx(arrangement.bar_seconds) for note in final)


def test_the_ending_keeps_the_tail_instead_of_looping():
    """終わる曲は、残響を先頭に折り返さずそのまま鳴らしきること。"""
    looped = bgm.generate(_config(style="sports_anthem", bars=4))
    ended = bgm.generate(_config(style="sports_anthem", bars=4, ending=True))
    assert len(ended) > len(looped)


def test_the_ending_leaves_earlier_bars_alone():
    plain = bgm.compose(_config(style="sports_anthem", bars=8, humanize=0.0))
    ended = bgm.compose(_config(style="sports_anthem", bars=8, ending=True, humanize=0.0))
    limit = (plain.bars - 1) * plain.bar_seconds - 0.1
    assert [n for n in plain.notes["lead"] if n.start < limit] == [
        n for n in ended.notes["lead"] if n.start < limit
    ]


def test_the_bass_walks_into_the_next_chord():
    """和音が変わる直前の音が、次の根音の隣へ寄っていること。"""
    config = _config(style="sports_anthem", bars=4, parts=("bass",), humanize=0.0)
    arrangement = bgm.compose(config)
    bar = arrangement.bar_seconds
    by_bar = {}
    for note in arrangement.notes["bass"]:
        by_bar.setdefault(int(note.start / bar + 0.001), []).append(note)

    for index in range(len(by_bar) - 1):
        approach = max(by_bar[index], key=lambda n: n.start).midi
        landing = min(by_bar[index + 1], key=lambda n: n.start).midi
        assert abs(approach - landing) <= 2, f"bar {index}: {approach} -> {landing}"


def test_styles_without_walking_keep_the_plain_root():
    assert bgm.STYLES["calm"].bass_walk is False
    arrangement = bgm.compose(_config(style="calm", bars=4, parts=("bass",), humanize=0.0))
    root = bgm._root_midi("C", bgm.STYLES["calm"].bass_octave)
    assert arrangement.notes["bass"][0].midi == root

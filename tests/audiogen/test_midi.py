"""MIDI 書き出しのテスト。

書き出したバイト列を読み返して構造を確かめる(自前で解析するので、
外部ライブラリなしで往復を検証できる)。
"""

from __future__ import annotations

import pytest

from audiogen import bgm, midi

SR = 11025


def _read_vlq(data, pos):
    value = 0
    while True:
        byte = data[pos]
        pos += 1
        value = (value << 7) | (byte & 0x7F)
        if not byte & 0x80:
            return value, pos


def parse(data):
    """MIDI を ``(ヘッダ, [トラック])`` に分解する。トラックは (絶対tick, 生イベント)。"""
    assert data[:4] == b"MThd"
    header_len = int.from_bytes(data[4:8], "big")
    fmt = int.from_bytes(data[8:10], "big")
    count = int.from_bytes(data[10:12], "big")
    division = int.from_bytes(data[12:14], "big")

    tracks = []
    pos = 8 + header_len
    while pos < len(data):
        assert data[pos : pos + 4] == b"MTrk"
        length = int.from_bytes(data[pos + 4 : pos + 8], "big")
        body, pos = data[pos + 8 : pos + 8 + length], pos + 8 + length

        events, tick, index, status = [], 0, 0, None
        while index < len(body):
            delta, index = _read_vlq(body, index)
            tick += delta
            if body[index] == 0xFF:  # メタイベント
                kind = body[index + 1]
                size, index = _read_vlq(body, index + 2)
                events.append((tick, ("meta", kind, body[index : index + size])))
                index += size
            else:
                if body[index] & 0x80:
                    status = body[index]
                    index += 1
                kind = status & 0xF0
                size = 1 if kind == 0xC0 else 2
                events.append((tick, ("midi", status, body[index : index + size])))
                index += size
        tracks.append(events)
    return {"format": fmt, "tracks": count, "division": division}, tracks


@pytest.fixture
def arrangement():
    return bgm.compose(bgm.BGMConfig(style="sports_anthem", bars=4, seed=3, sr=SR))


def test_the_header_declares_a_multi_track_file(arrangement):
    header, tracks = parse(midi.build(arrangement))
    assert header["format"] == 1
    assert header["division"] == midi.TICKS_PER_QUARTER
    assert header["tracks"] == len(tracks)


def test_the_first_track_carries_the_tempo(arrangement):
    _, tracks = parse(midi.build(arrangement))
    tempo = [e for _, e in tracks[0] if e[0] == "meta" and e[1] == 0x51]
    assert len(tempo) == 1
    microseconds = int.from_bytes(tempo[0][2], "big")
    assert round(60_000_000 / microseconds) == arrangement.style.bpm


def test_every_part_becomes_its_own_named_track(arrangement):
    _, tracks = parse(midi.build(arrangement))
    names = [
        e[2].decode("utf-8")
        for track in tracks
        for _, e in track
        if e[0] == "meta" and e[1] == 0x03
    ]
    assert names[0].startswith("audiogen")
    assert set(names[1:]) == set(arrangement.parts())


def test_every_composed_note_appears_once(arrangement):
    _, tracks = parse(midi.build(arrangement))
    note_ons = [
        e for track in tracks for _, e in track
        if e[0] == "midi" and e[1] & 0xF0 == 0x90 and e[1] & 0x0F != midi.DRUM_CHANNEL
    ]
    assert len(note_ons) == sum(len(plan) for plan in arrangement.notes.values())


def test_pitches_match_the_arrangement(arrangement):
    _, tracks = parse(midi.build(arrangement))
    written = sorted(
        e[2][0] for track in tracks for _, e in track
        if e[0] == "midi" and e[1] & 0xF0 == 0x90 and e[1] & 0x0F != midi.DRUM_CHANNEL
    )
    composed = sorted(note.midi for plan in arrangement.notes.values() for note in plan)
    assert written == composed


def test_note_offs_balance_the_note_ons(arrangement):
    _, tracks = parse(midi.build(arrangement))
    for track in tracks:
        ons = [e for _, e in track if e[0] == "midi" and e[1] & 0xF0 == 0x90]
        offs = [e for _, e in track if e[0] == "midi" and e[1] & 0xF0 == 0x80]
        assert len(ons) == len(offs)


def test_every_note_lasts_at_least_one_tick(arrangement):
    _, tracks = parse(midi.build(arrangement))
    for track in tracks:
        open_notes = {}
        for tick, event in track:
            if event[0] != "midi":
                continue
            if event[1] & 0xF0 == 0x90:
                open_notes[event[2][0]] = tick
            elif event[1] & 0xF0 == 0x80 and event[2][0] in open_notes:
                assert tick > open_notes.pop(event[2][0])


def test_drums_land_on_the_gm_percussion_channel(arrangement):
    _, tracks = parse(midi.build(arrangement))
    drum_notes = [
        e[2][0] for track in tracks for _, e in track
        if e[0] == "midi" and e[1] == 0x90 | midi.DRUM_CHANNEL
    ]
    assert drum_notes
    assert len(drum_notes) == len(arrangement.hits)
    assert set(drum_notes) <= set(midi.GM_PERCUSSION.values())


def test_pitched_parts_avoid_the_drum_channel(arrangement):
    _, tracks = parse(midi.build(arrangement))
    for index, track in enumerate(tracks[1:-1], start=1):  # 最後はドラム
        channels = {e[1] & 0x0F for _, e in track if e[0] == "midi"}
        assert midi.DRUM_CHANNEL not in channels


def test_each_part_picks_a_general_midi_program(arrangement):
    _, tracks = parse(midi.build(arrangement))
    programs = [
        e[2][0] for track in tracks for _, e in track
        if e[0] == "midi" and e[1] & 0xF0 == 0xC0
    ]
    assert len(programs) == len(arrangement.notes)
    assert midi.GM_PROGRAMS["brass"] in programs  # sports_anthem の和音は brass


def test_timing_follows_the_tempo(arrangement):
    """1小節の長さが、分解能から計算した値と一致すること。"""
    _, tracks = parse(midi.build(arrangement))
    bar_ticks = midi.TICKS_PER_QUARTER * bgm.BEATS_PER_BAR
    last = max(tick for track in tracks for tick, _ in track)
    assert last == pytest.approx(bar_ticks * arrangement.bars, rel=0.05)


@pytest.mark.parametrize("bpm", [72, 160])
def test_the_bar_grid_lines_up_at_any_tempo(bpm):
    """テンポを変えても、書き出した小節線が譜面の小節と一致すること。"""
    plan = bgm.compose(bgm.BGMConfig(style="sports_anthem", bars=4, bpm=bpm, seed=3, sr=SR))
    header, tracks = parse(midi.build(plan))
    tempo = [e for _, e in tracks[0] if e[0] == "meta" and e[1] == 0x51][0]
    assert round(60_000_000 / int.from_bytes(tempo[2], "big")) == bpm

    bar_ticks = midi.TICKS_PER_QUARTER * bgm.BEATS_PER_BAR
    last = max(tick for track in tracks for tick, _ in track)
    assert last == pytest.approx(bar_ticks * plan.bars, rel=0.05)


def test_write_creates_the_file(tmp_path, arrangement):
    path = midi.write(tmp_path / "nested" / "song.mid", arrangement)
    assert (tmp_path / "nested" / "song.mid").exists()
    assert open(path, "rb").read(4) == b"MThd"


def test_variable_length_encoding():
    assert midi._vlq(0) == b"\x00"
    assert midi._vlq(127) == b"\x7f"
    assert midi._vlq(128) == b"\x81\x00"
    assert midi._vlq(0x3FFF) == b"\xff\x7f"
    with pytest.raises(ValueError):
        midi._vlq(-1)


def test_velocity_stays_in_range():
    assert midi._velocity(0.0) == 1
    assert midi._velocity(2.0) == 127
    assert 1 < midi._velocity(0.5) < 127


def test_a_style_without_drums_writes_no_drum_track():
    quiet = bgm.compose(bgm.BGMConfig(style="night", bars=2, seed=1, sr=SR))
    _, tracks = parse(midi.build(quiet))
    names = [e[2].decode() for track in tracks for _, e in track if e[0] == "meta" and e[1] == 0x03]
    assert "drums" not in names

"""譜面を標準 MIDI ファイルとして書き出す。

``compose()`` は「どの音をいつ鳴らすか」を持っているので、それをそのまま
MIDI にできる。合成音では物足りないとき、同じ曲を DAW の音源で鳴らしたり、
人の手で編集したりできる。

パートごとに1トラック、ドラムは GM の打楽器チャンネル(10ch)へ割り当てる。
"""

from __future__ import annotations

import os
from typing import Sequence

TICKS_PER_QUARTER = 480
"""4分音符あたりのティック数。"""

DRUM_CHANNEL = 9
"""GM で打楽器に割り当てられているチャンネル(1始まりで10ch)。"""

# 楽器名 -> GM 音色番号。合成音の性格に近いものを選んである。
GM_PROGRAMS: dict[str, int] = {
    "sine": 12, "triangle": 12, "saw": 81, "square": 80,
    "pulse25": 80, "pulse12": 80, "chip_lead": 80, "pulse_lead": 81,
    "pad": 89, "strings": 48, "choir": 52, "organ": 19,
    "brass": 61, "low_brass": 58, "bell": 14, "marimba": 12,
    "pluck": 45, "sub_bass": 38, "pick_bass": 34,
}
DEFAULT_PROGRAM = 0

# ドラム音色 -> GM 打楽器のノート番号。
GM_PERCUSSION: dict[str, int] = {
    "kick": 36,        # Bass Drum 1
    "snare": 38,       # Acoustic Snare
    "hihat": 42,       # Closed Hi-Hat
    "open_hihat": 46,  # Open Hi-Hat
    "clap": 39,        # Hand Clap
    "tom": 45,         # Low Tom
    "timpani": 41,     # Low Floor Tom(GM に大太鼓がないため代用)
    "crash": 49,       # Crash Cymbal 1
    "ride": 51,        # Ride Cymbal 1
}

DRUM_LENGTH = 0.05
"""打楽器の音の長さ(秒)。打点さえ合っていればよいので短くてよい。"""


def _vlq(value: int) -> bytes:
    """MIDI の可変長数値。7ビットずつ、最後以外は最上位ビットを立てる。"""
    if value < 0:
        raise ValueError("variable-length quantity must be >= 0")
    chunk = [value & 0x7F]
    value >>= 7
    while value:
        chunk.append((value & 0x7F) | 0x80)
        value >>= 7
    return bytes(reversed(chunk))


def _chunk(tag: bytes, body: bytes) -> bytes:
    return tag + len(body).to_bytes(4, "big") + body


def _velocity(value: float) -> int:
    return max(1, min(127, round(value * 100)))


def _track(events: Sequence[tuple[int, bytes]], name: str, extra: bytes = b"") -> bytes:
    """``(ティック, イベント)`` の並びを1トラックにまとめる。

    同じ時刻ではノートオフを先に出す。同じ高さの音が続くとき、
    次の音の頭で前の音が切られてしまうのを防ぐ。
    """
    body = bytearray()
    body += b"\x00\xff\x03" + _vlq(len(name.encode("utf-8"))) + name.encode("utf-8")
    body += extra

    previous = 0
    for tick, event in sorted(events, key=lambda item: (item[0], item[1][0] & 0xF0)):
        body += _vlq(tick - previous) + event
        previous = tick
    body += b"\x00\xff\x2f\x00"
    return _chunk(b"MTrk", bytes(body))


def build(arrangement) -> bytes:
    """``compose()`` の結果を標準 MIDI ファイル(format 1)のバイト列にする。

    テンポは譜面のものをそのまま書く。音符の時刻は秒で持っているので、
    別のテンポを宣言すると小節線とずれてしまう(だから上書きは受け付けない)。

    リタルダンドは音符の位置そのものに織り込まれる。再生は正しく遅くなるが、
    テンポ変化イベントは書かないので、DAW 上では小節線からずれて見える。
    """
    tempo = arrangement.style.bpm
    beat_seconds = 60.0 / tempo

    def to_ticks(seconds: float) -> int:
        return max(0, round(seconds / beat_seconds * TICKS_PER_QUARTER))

    # 1トラック目はテンポだけを持つ(format 1 の約束)。
    microseconds = round(60_000_000 / tempo)
    tempo_event = (0, b"\xff\x51\x03" + microseconds.to_bytes(3, "big"))
    tracks = [_track([tempo_event], f"audiogen {tempo}bpm")]

    style = arrangement.style
    instruments = {
        "chords": style.chord_instrument,
        "arp": style.arp_instrument,
        "bass": style.bass_instrument,
        "lead": style.lead_instrument,
    }
    channel = 0
    for part, plan in arrangement.notes.items():
        if not plan:
            continue
        if channel == DRUM_CHANNEL:  # 打楽器チャンネルは避ける
            channel += 1
        program = GM_PROGRAMS.get(instruments.get(part, ""), DEFAULT_PROGRAM)
        events: list[tuple[int, bytes]] = []
        for note in plan:
            start = to_ticks(note.start)
            end = max(start + 1, to_ticks(note.start + note.length))
            pitch = max(0, min(127, note.midi))
            events.append((start, bytes([0x90 | channel, pitch, _velocity(note.velocity)])))
            events.append((end, bytes([0x80 | channel, pitch, 0])))
        tracks.append(_track(events, part, extra=b"\x00" + bytes([0xC0 | channel, program])))
        channel += 1

    if arrangement.hits:
        events = []
        for hit in arrangement.hits:
            pitch = GM_PERCUSSION.get(hit.voice)
            if pitch is None:
                continue
            start = to_ticks(hit.start)
            end = max(start + 1, to_ticks(hit.start + DRUM_LENGTH))
            events.append((start, bytes([0x90 | DRUM_CHANNEL, pitch, _velocity(hit.velocity)])))
            events.append((end, bytes([0x80 | DRUM_CHANNEL, pitch, 0])))
        if events:
            tracks.append(_track(events, "drums"))

    header = (1).to_bytes(2, "big") + len(tracks).to_bytes(2, "big") + TICKS_PER_QUARTER.to_bytes(2, "big")
    return _chunk(b"MThd", header) + b"".join(tracks)


def write(path: str | os.PathLike[str], arrangement) -> str:
    """MIDI ファイルを書き出し、書き込んだパスを返す。"""
    path = os.fspath(path)
    parent = os.path.dirname(os.path.abspath(path))
    os.makedirs(parent, exist_ok=True)
    with open(path, "wb") as fp:
        fp.write(build(arrangement))
    return path

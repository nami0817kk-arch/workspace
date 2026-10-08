"""行ごとの音声を、間を挟んで1本につなぐ。字幕（SRT）と章（概要欄のタイムスタンプ）もここで作る。"""
from __future__ import annotations

import wave
from dataclasses import dataclass
from pathlib import Path

from .voice import gap_before

TAIL = 1.5        # 最後の行のあとに残す無音（秒）


@dataclass
class Cue:
    line: object          # script.Line
    start: float          # 話し始め（秒）
    end: float            # 話し終わり（秒）
    wav: Path


def plan(lines: list, spoken: dict[int, object]) -> tuple[list[Cue], float]:
    """行の並びと音声の長さから、各行の開始・終了時刻を決める。全体の長さも返す。"""
    cues: list[Cue] = []
    t = 0.0
    prev = None
    for line in lines:
        s = spoken[line.index]
        t += gap_before(prev, line)
        cues.append(Cue(line, round(t, 3), round(t + s.seconds, 3), s.wav))
        t += s.seconds
        prev = line
    return cues, round(t + TAIL, 3)


def write_audio(cues: list[Cue], total: float, target: Path, effects: list | None = None) -> None:
    """全行を1本の wav にする（VOICEVOX の出力はどれも同じ形式なので、そのまま並べる）。
    effects は (時刻, 音の名前) の並び（chiso/sfx.py）。あれば小さく重ねる。"""
    params = None
    chunks: list[bytes] = []
    cursor = 0  # フレーム数
    for cue in cues:
        with wave.open(str(cue.wav)) as w:
            if params is None:
                params = w.getparams()
            elif (w.getframerate(), w.getnchannels(), w.getsampwidth()) != (
                    params.framerate, params.nchannels, params.sampwidth):
                raise ValueError(f"音声の形式が揃っていません: {cue.wav}")
            frames = w.readframes(w.getnframes())
        start = int(round(cue.start * params.framerate))
        if start > cursor:
            chunks.append(b"\x00" * ((start - cursor) * params.sampwidth * params.nchannels))
            cursor = start
        chunks.append(frames)
        cursor += len(frames) // (params.sampwidth * params.nchannels)
    end = int(round(total * params.framerate))
    if end > cursor:
        chunks.append(b"\x00" * ((end - cursor) * params.sampwidth * params.nchannels))
    data = b"".join(chunks)
    if effects:
        from array import array
        from . import sfx
        if params.sampwidth != 2:
            raise ValueError("効果音は 16bit の音声にだけ重ねられます")
        samples = array("h")
        samples.frombytes(data)
        data = sfx.overlay(samples, params.framerate, params.nchannels, effects).tobytes()
    target.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(target), "wb") as out:
        out.setparams(params)
        out.writeframes(data)


def _srt_time(t: float) -> str:
    ms = int(round(t * 1000))
    h, ms = divmod(ms, 3_600_000)
    m, ms = divmod(ms, 60_000)
    s, ms = divmod(ms, 1000)
    return f"{h:02}:{m:02}:{s:02},{ms:03}"


def srt(cues: list[Cue], names: dict[str, str]) -> str:
    """YouTube に渡す字幕。話者名を頭に付ける（掛け合いなので誰の言葉か分かるように）。"""
    # 画面の字幕と同じかたまりで切り、時間は字数の割合で配る
    from .subs import chunks, plain
    out = []
    n = 0
    for cue in cues:
        name = names.get(cue.line.speaker, cue.line.speaker)
        cs = [plain(c) for c in chunks(cue.line.text)]
        total = sum(len(c) for c in cs) or 1
        t = cue.start
        for c in cs:
            d = (cue.end - cue.start) * len(c) / total
            n += 1
            out.append(f"{n}\n{_srt_time(t)} --> {_srt_time(t + d)}\n{name}：{c}\n")
            t += d
    return "\n".join(out)


def _clock(t: float) -> str:
    t = int(t)
    h, rest = divmod(t, 3600)
    m, s = divmod(rest, 60)
    return f"{h}:{m:02}:{s:02}" if h else f"{m}:{s:02}"


def chapters(cues: list[Cue], titles: list[str]) -> list[str]:
    """概要欄の章。YouTube の決まりで最初は 0:00 にする。"""
    firsts: dict[int, float] = {}
    for cue in cues:
        firsts.setdefault(cue.line.section, cue.start)
    out = []
    for n, (section, start) in enumerate(sorted(firsts.items())):
        out.append(f"{_clock(0 if n == 0 else start)} {titles[section]}")
    return out

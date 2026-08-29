"""BGM・効果音のプレースホルダ生成。

配布音源はライセンス確認が要るので、まずは自前で合成した音でミックスを通せるようにする。
`assets/audio/` に自分の音源を置けばそちらが使われる。
"""

from __future__ import annotations

import math
import random
import struct
import wave
from pathlib import Path

from .config import _resolve

RATE = 44100
BPM = 96
BEAT = 60.0 / BPM
BARS_PER_CHORD = 2
BEATS_PER_BAR = 4

# Am - F - C - G。ニュースの下に敷いても邪魔にならない進行
PROGRESSION = [
    (220.00, 261.63, 329.63),  # Am
    (174.61, 220.00, 261.63),  # F
    (261.63, 329.63, 392.00),  # C
    (196.00, 246.94, 293.66),  # G
]
CHORD_SECONDS = BEAT * BEATS_PER_BAR * BARS_PER_CHORD
BGM_SECONDS = CHORD_SECONDS * len(PROGRESSION)

EDGE = 0.06  # 継ぎ目のクリックを消すための立ち上がり/立ち下がり


def ensure_audio_assets(force: bool = False) -> list[Path]:
    """不足している BGM / 効果音を生成する。"""
    directory = _resolve("assets/audio")
    directory.mkdir(parents=True, exist_ok=True)
    created: list[Path] = []

    targets = {
        "bgm_loop.wav": generate_bgm,
        "se_pon.wav": generate_pon,
        "se_whoosh.wav": generate_whoosh,
        "se_jingle.wav": generate_jingle,
    }
    for name, generator in targets.items():
        path = directory / name
        if force or not path.exists():
            generator(path)
            created.append(path)
    return created


def generate_bgm(path: Path) -> Path:
    """ニュースの下に敷く BGM。

    パッド（和音の持続音）・アルペジオ・低音のパルスの3層を重ねる。
    喋りとぶつからないよう、中音域は薄めにして低音と高音に寄せている。
    ループさせる前提なので、両端は無音に落として継ぎ目が鳴らないようにする。
    """
    total = int(RATE * BGM_SECONDS)
    left = [0.0] * total
    right = [0.0] * total

    _lay_pad(left, right)
    _lay_arpeggio(left, right)
    _lay_pulse(left, right)

    for index in range(total):
        gain = _edge_gain(index / RATE, BGM_SECONDS)
        left[index] *= gain
        right[index] *= gain

    _write_stereo(path, left, right)
    return path


def _chord_at(seconds: float) -> tuple[float, ...]:
    return PROGRESSION[int(seconds / CHORD_SECONDS) % len(PROGRESSION)]


def _lay_pad(left: list[float], right: list[float]) -> None:
    """和音の持続音。わずかにデチューンした2声を左右に振って広がりを出す。"""
    for index in range(len(left)):
        t = index / RATE
        chord = _chord_at(t)
        value_l = value_r = 0.0
        for freq in chord:
            value_l += math.sin(2 * math.pi * freq * t)
            value_r += math.sin(2 * math.pi * freq * 1.003 * t)  # デチューン
        # 1オクターブ下を薄く足して土台にする
        low = math.sin(math.pi * chord[0] * t) * 0.6
        left[index] += (value_l / len(chord) * 0.5 + low) * 0.17
        right[index] += (value_r / len(chord) * 0.5 + low) * 0.17


def _lay_arpeggio(left: list[float], right: list[float]) -> None:
    """8分音符のアルペジオ。1音ずつ左右に振る。"""
    step = BEAT / 2
    count = int(BGM_SECONDS / step)
    length = int(RATE * step * 1.8)

    for number in range(count):
        start = number * step
        chord = _chord_at(start)
        freq = chord[number % len(chord)] * 2  # 1オクターブ上
        offset = int(start * RATE)
        pan = 0.62 if number % 2 == 0 else 0.38

        for n in range(length):
            index = offset + n
            if index >= len(left):
                break
            t = n / RATE
            decay = math.exp(-t * 7.5)
            value = (math.sin(2 * math.pi * freq * t) * 0.7
                     + math.sin(4 * math.pi * freq * t) * 0.18) * decay * 0.16
            left[index] += value * pan
            right[index] += value * (1 - pan)


def _lay_pulse(left: list[float], right: list[float]) -> None:
    """拍を感じさせる低音。強く出すと喋りを邪魔するので控えめに。"""
    length = int(RATE * 0.24)
    beats = int(BGM_SECONDS / BEAT)

    for beat in range(beats):
        if beat % 2:  # 1拍おき
            continue
        offset = int(beat * BEAT * RATE)
        for n in range(length):
            index = offset + n
            if index >= len(left):
                break
            t = n / RATE
            freq = 92 - 46 * min(1.0, t / 0.16)   # 下に落ちるサイン
            value = math.sin(2 * math.pi * freq * t) * math.exp(-t * 13) * 0.30
            left[index] += value
            right[index] += value


def _edge_gain(t: float, length: float) -> float:
    if t < EDGE:
        return t / EDGE
    if t > length - EDGE:
        return max(0.0, (length - t) / EDGE)
    return 1.0


def generate_pon(path: Path) -> Path:
    """テロップ用の軽い「ポン」。"""
    samples = []
    length = 0.18
    for n in range(int(RATE * length)):
        t = n / RATE
        decay = math.exp(-t * 26)
        value = math.sin(2 * math.pi * 880 * t) + 0.4 * math.sin(2 * math.pi * 1320 * t)
        samples.append(value * decay * 0.4)
    _write(path, samples)
    return path


def generate_whoosh(path: Path) -> Path:
    """場面転換用のノイズスイープ。"""
    random.seed(7)
    length = 0.5
    previous = 0.0
    samples = []
    for n in range(int(RATE * length)):
        t = n / RATE
        ratio = t / length
        noise = random.uniform(-1.0, 1.0)
        # カットオフを上げ下げして「シュッ」と鳴らす
        alpha = 0.02 + 0.35 * math.sin(math.pi * ratio)
        previous += alpha * (noise - previous)
        envelope = math.sin(math.pi * ratio) ** 2
        samples.append(previous * envelope * 0.5)
    _write(path, samples)
    return path


def generate_jingle(path: Path) -> Path:
    """章の切り替えに使う3音のアルペジオ。"""
    samples = []
    for freq in (523.25, 659.25, 783.99):
        for n in range(int(RATE * 0.14)):
            t = n / RATE
            decay = math.exp(-t * 12)
            samples.append(math.sin(2 * math.pi * freq * t) * decay * 0.35)
    _write(path, samples)
    return path


def _write_stereo(path: Path, left: list[float], right: list[float]) -> None:
    """ステレオ16bitで書き出す。"""
    frames = bytearray()
    for value_l, value_r in zip(left, right):
        frames += struct.pack(
            "<hh",
            int(max(-1.0, min(1.0, value_l)) * 32000),
            int(max(-1.0, min(1.0, value_r)) * 32000),
        )
    with wave.open(str(path), "wb") as out:
        out.setnchannels(2)
        out.setsampwidth(2)
        out.setframerate(RATE)
        out.writeframes(bytes(frames))


def _write(path: Path, samples: list[float]) -> None:
    """モノラル16bitで書き出す。範囲外はクリップする。"""
    frames = bytearray()
    for value in samples:
        clipped = max(-1.0, min(1.0, value))
        frames += struct.pack("<h", int(clipped * 32000))
    with wave.open(str(path), "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(RATE)
        out.writeframes(bytes(frames))

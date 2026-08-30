"""信号バッファの基本操作と WAV 書き出し。

音声は「-1.0〜1.0 の float を並べた list」で表現する。
外部ライブラリに依存せず、標準ライブラリだけで完結させている。
"""

from __future__ import annotations

import math
import os
import wave
from typing import Iterable, Sequence

SAMPLE_RATE = 44100
"""既定のサンプリング周波数 (Hz)。"""

Buffer = list


def num_samples(duration: float, sr: int = SAMPLE_RATE) -> int:
    """秒数をサンプル数に変換する(負値は 0 に丸める)。"""
    return max(0, int(round(duration * sr)))


def silence(duration: float, sr: int = SAMPLE_RATE) -> list[float]:
    """指定秒数の無音バッファを作る。"""
    return [0.0] * num_samples(duration, sr)


def concat(*buffers: Sequence[float]) -> list[float]:
    """複数のバッファを時間軸方向に連結する。"""
    out: list[float] = []
    for buf in buffers:
        out.extend(buf)
    return out


def add_into(dst: list[float], src: Sequence[float], offset: int = 0, gain: float = 1.0) -> list[float]:
    """``dst`` の ``offset`` サンプル目に ``src`` を加算する(足りなければ伸ばす)。"""
    if offset < 0:
        raise ValueError("offset must be >= 0")
    end = offset + len(src)
    if end > len(dst):
        dst.extend([0.0] * (end - len(dst)))
    for i, value in enumerate(src):
        dst[offset + i] += value * gain
    return dst


def mix(*buffers: Sequence[float], gains: Sequence[float] | None = None) -> list[float]:
    """複数トラックを重ねる。長さは最も長いバッファに合わせる。"""
    if not buffers:
        return []
    if gains is None:
        gains = [1.0] * len(buffers)
    if len(gains) != len(buffers):
        raise ValueError("gains must have the same length as buffers")
    out = [0.0] * max(len(b) for b in buffers)
    for buf, g in zip(buffers, gains):
        for i, value in enumerate(buf):
            out[i] += value * g
    return out


def gain(buf: Sequence[float], amount: float) -> list[float]:
    """一定倍率をかける。"""
    return [value * amount for value in buf]


def peak(buf: Iterable[float]) -> float:
    """絶対値の最大を返す。"""
    return max((abs(value) for value in buf), default=0.0)


def remove_dc(buf: Sequence[float]) -> list[float]:
    """直流成分(平均値)を取り除く。ヘッドルームの無駄と再生時のノイズを防ぐ。"""
    if not buf:
        return []
    offset = sum(buf) / len(buf)
    if abs(offset) < 1e-9:
        return list(buf)
    return [value - offset for value in buf]


def normalize(buf: Sequence[float], target: float = 0.89) -> list[float]:
    """ピークが ``target`` になるよう正規化する。無音はそのまま返す。"""
    current = peak(buf)
    if current < 1e-12:
        return list(buf)
    return gain(buf, target / current)


def fade(
    buf: Sequence[float],
    fade_in: float = 0.0,
    fade_out: float = 0.0,
    sr: int = SAMPLE_RATE,
) -> list[float]:
    """先頭・末尾に直線フェードをかける(クリックノイズ防止)。"""
    out = list(buf)
    n = len(out)
    n_in = min(num_samples(fade_in, sr), n)
    n_out = min(num_samples(fade_out, sr), n)
    for i in range(n_in):
        out[i] *= i / n_in
    for i in range(n_out):
        out[n - 1 - i] *= i / n_out
    return out


def pad_to(buf: Sequence[float], length: int) -> list[float]:
    """無音を足して指定サンプル数に揃える(長い場合は切り詰める)。"""
    out = list(buf[:length])
    if len(out) < length:
        out.extend([0.0] * (length - len(out)))
    return out


def wrap_tail(buf: Sequence[float], length: int) -> list[float]:
    """``length`` を超えた残響を先頭へ回り込ませ、継ぎ目のないループを作る。

    残響がループ長より長い場合も、剰余で何周ぶんでも畳み込む。
    """
    if length <= 0:
        return []
    out = pad_to(buf, length)
    for i in range(length, len(buf)):
        out[i % length] += buf[i]
    return out


def clip(value: float) -> float:
    """-1.0〜1.0 に丸める。"""
    if value > 1.0:
        return 1.0
    if value < -1.0:
        return -1.0
    return value


def to_stereo(left: Sequence[float], right: Sequence[float]) -> list[float]:
    """L/R を L,R,L,R... のインターリーブ列にする。"""
    length = max(len(left), len(right))
    left = pad_to(left, length)
    right = pad_to(right, length)
    out: list[float] = [0.0] * (length * 2)
    out[0::2] = left
    out[1::2] = right
    return out


def pan(buf: Sequence[float], position: float = 0.0) -> tuple[list[float], list[float]]:
    """定パワーパンニング。``position`` は -1.0(左) 〜 1.0(右)。"""
    position = max(-1.0, min(1.0, position))
    angle = (position + 1.0) * (math.pi / 4.0)
    return gain(buf, math.cos(angle)), gain(buf, math.sin(angle))


def write_wav(
    path: str | os.PathLike[str],
    buf: Sequence[float],
    sr: int = SAMPLE_RATE,
    channels: int = 1,
) -> str:
    """16bit PCM の WAV として書き出し、書き込んだパスを返す。"""
    if channels not in (1, 2):
        raise ValueError("channels must be 1 or 2")
    if channels == 2 and len(buf) % 2 != 0:
        raise ValueError("stereo buffer length must be even (interleaved L,R)")

    path = os.fspath(path)
    parent = os.path.dirname(os.path.abspath(path))
    os.makedirs(parent, exist_ok=True)

    frames = bytearray()
    for value in buf:
        sample = int(round(clip(value) * 32767.0))
        frames += sample.to_bytes(2, "little", signed=True)

    with wave.open(path, "wb") as fp:
        fp.setnchannels(channels)
        fp.setsampwidth(2)
        fp.setframerate(sr)
        fp.writeframes(bytes(frames))
    return path


def duration_of(buf: Sequence[float], sr: int = SAMPLE_RATE, channels: int = 1) -> float:
    """バッファの再生秒数を返す。"""
    return len(buf) / channels / sr

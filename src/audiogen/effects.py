"""エフェクト(フィルタ・空間系・歪み)。"""

from __future__ import annotations

import math
from typing import Callable, Sequence

from .core import SAMPLE_RATE, num_samples

CutoffLike = float | Callable[[float], float]


def _as_cutoff_fn(cutoff: CutoffLike, sr: int) -> Callable[[float], float]:
    nyquist = sr / 2.0 - 1.0
    if callable(cutoff):
        return lambda t: min(max(cutoff(t), 1.0), nyquist)
    value = min(max(float(cutoff), 1.0), nyquist)
    return lambda _t: value


def lowpass(buf: Sequence[float], cutoff: CutoffLike, sr: int = SAMPLE_RATE) -> list[float]:
    """1次ローパス。``cutoff`` に ``f(t) -> Hz`` を渡すとフィルタスイープになる。"""
    cutoff_fn = _as_cutoff_fn(cutoff, sr)
    out = [0.0] * len(buf)
    y = 0.0
    for i, x in enumerate(buf):
        dt = 1.0 / sr
        rc = 1.0 / (2.0 * math.pi * cutoff_fn(i / sr))
        alpha = dt / (rc + dt)
        y += alpha * (x - y)
        out[i] = y
    return out


def highpass(buf: Sequence[float], cutoff: CutoffLike, sr: int = SAMPLE_RATE) -> list[float]:
    """1次ハイパス。"""
    cutoff_fn = _as_cutoff_fn(cutoff, sr)
    out = [0.0] * len(buf)
    prev_x = 0.0
    y = 0.0
    for i, x in enumerate(buf):
        dt = 1.0 / sr
        rc = 1.0 / (2.0 * math.pi * cutoff_fn(i / sr))
        alpha = rc / (rc + dt)
        y = alpha * (y + x - prev_x)
        prev_x = x
        out[i] = y
    return out


def bandpass(buf: Sequence[float], low: CutoffLike, high: CutoffLike, sr: int = SAMPLE_RATE) -> list[float]:
    """ローパスとハイパスを直列にした簡易バンドパス。"""
    return highpass(lowpass(buf, high, sr), low, sr)


def delay(
    buf: Sequence[float],
    time: float = 0.25,
    feedback: float = 0.35,
    wet: float = 0.35,
    sr: int = SAMPLE_RATE,
    tail: float | None = None,
) -> list[float]:
    """フィードバックディレイ。``tail`` 秒ぶん余韻を後ろに伸ばす。"""
    step = max(1, num_samples(time, sr))
    tail_samples = num_samples(tail if tail is not None else time * 4, sr)
    out = list(buf) + [0.0] * tail_samples
    for i in range(len(out)):
        if i >= step:
            out[i] += out[i - step] * feedback
    dry = list(buf) + [0.0] * tail_samples
    return [d + (w - d) * wet for d, w in zip(dry, out)]


_COMB_DELAYS = (0.0297, 0.0371, 0.0411, 0.0437)
_ALLPASS_DELAYS = (0.0050, 0.0017)


def reverb(
    buf: Sequence[float],
    room: float = 0.7,
    wet: float = 0.3,
    sr: int = SAMPLE_RATE,
    damping: float = 0.35,
    tail: float = 1.2,
) -> list[float]:
    """Schroeder 型リバーブ(コムフィルタ4本 + オールパス2段)。"""
    room = min(max(room, 0.0), 0.95)
    n = len(buf) + num_samples(tail, sr)
    src = list(buf) + [0.0] * (n - len(buf))

    wet_signal = [0.0] * n
    for delay_time in _COMB_DELAYS:
        step = max(1, num_samples(delay_time, sr))
        line = [0.0] * n
        filtered = 0.0
        for i in range(n):
            delayed = line[i - step] if i >= step else 0.0
            filtered = delayed * (1.0 - damping) + filtered * damping
            line[i] = src[i] + filtered * room
            wet_signal[i] += line[i] / len(_COMB_DELAYS)

    for delay_time in _ALLPASS_DELAYS:
        step = max(1, num_samples(delay_time, sr))
        line = [0.0] * n
        g = 0.5
        for i in range(n):
            delayed = line[i - step] if i >= step else 0.0
            line[i] = wet_signal[i] + delayed * g
            wet_signal[i] = delayed - line[i] * g

    return [src[i] + (wet_signal[i] - src[i]) * wet for i in range(n)]


def distort(buf: Sequence[float], drive: float = 3.0) -> list[float]:
    """tanh によるソフトクリップ。"""
    drive = max(drive, 1e-6)
    norm = math.tanh(drive)
    return [math.tanh(value * drive) / norm for value in buf]


def bitcrush(buf: Sequence[float], bits: int = 8, downsample: int = 1) -> list[float]:
    """ビット深度とサンプルレートを落としてレトロゲーム機風にする。"""
    levels = 2 ** max(1, bits) - 1
    downsample = max(1, downsample)
    out = [0.0] * len(buf)
    held = 0.0
    for i, value in enumerate(buf):
        if i % downsample == 0:
            held = round((value + 1.0) / 2.0 * levels) / levels * 2.0 - 1.0
        out[i] = held
    return out


def tremolo(buf: Sequence[float], rate: float = 5.0, depth: float = 0.5, sr: int = SAMPLE_RATE) -> list[float]:
    """周期的な音量変化。"""
    depth = min(max(depth, 0.0), 1.0)
    return [
        value * (1.0 - depth + depth * (0.5 + 0.5 * math.sin(2.0 * math.pi * rate * (i / sr))))
        for i, value in enumerate(buf)
    ]

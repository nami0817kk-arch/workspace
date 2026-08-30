"""エフェクト(フィルタ・空間系・歪み)。"""

from __future__ import annotations

import math
from typing import Callable, Sequence

from .core import SAMPLE_RATE, num_samples

CutoffLike = float | Callable[[float], float]


def _clamp_cutoff(value: float, sr: int) -> float:
    return min(max(float(value), 1.0), sr / 2.0 - 1.0)


def _as_cutoff_fn(cutoff: CutoffLike, sr: int) -> Callable[[float], float]:
    if callable(cutoff):
        return lambda t: _clamp_cutoff(cutoff(t), sr)
    value = _clamp_cutoff(cutoff, sr)
    return lambda _t: value


def _alpha_lowpass(cutoff: float, sr: int) -> float:
    """1次ローパスの平滑化係数。"""
    dt = 1.0 / sr
    rc = 1.0 / (2.0 * math.pi * cutoff)
    return dt / (rc + dt)


def _alpha_highpass(cutoff: float, sr: int) -> float:
    """1次ハイパスの平滑化係数。"""
    dt = 1.0 / sr
    rc = 1.0 / (2.0 * math.pi * cutoff)
    return rc / (rc + dt)


def lowpass(buf: Sequence[float], cutoff: CutoffLike, sr: int = SAMPLE_RATE) -> list[float]:
    """1次ローパス。``cutoff`` に ``f(t) -> Hz`` を渡すとフィルタスイープになる。"""
    out = [0.0] * len(buf)
    y = 0.0
    if not callable(cutoff):  # 係数が一定なら毎サンプル計算しない
        alpha = _alpha_lowpass(_clamp_cutoff(cutoff, sr), sr)
        for i, x in enumerate(buf):
            y += alpha * (x - y)
            out[i] = y
        return out

    cutoff_fn = _as_cutoff_fn(cutoff, sr)
    for i, x in enumerate(buf):
        y += _alpha_lowpass(cutoff_fn(i / sr), sr) * (x - y)
        out[i] = y
    return out


def highpass(buf: Sequence[float], cutoff: CutoffLike, sr: int = SAMPLE_RATE) -> list[float]:
    """1次ハイパス。"""
    out = [0.0] * len(buf)
    prev_x = 0.0
    y = 0.0
    if not callable(cutoff):
        alpha = _alpha_highpass(_clamp_cutoff(cutoff, sr), sr)
        for i, x in enumerate(buf):
            y = alpha * (y + x - prev_x)
            prev_x = x
            out[i] = y
        return out

    cutoff_fn = _as_cutoff_fn(cutoff, sr)
    for i, x in enumerate(buf):
        y = _alpha_highpass(cutoff_fn(i / sr), sr) * (y + x - prev_x)
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
    dry = list(buf) + [0.0] * tail_samples
    out = list(dry)
    for i in range(step, len(out)):  # 最初の step サンプルには帰還が届かない
        out[i] += out[i - step] * feedback
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
    share = 1.0 / len(_COMB_DELAYS)
    keep = 1.0 - damping
    for delay_time in _COMB_DELAYS:
        step = min(max(1, num_samples(delay_time, sr)), n)
        line = [0.0] * n
        # 遅延線が埋まるまでは帰還がないので、入力をそのまま通す。
        line[:step] = src[:step]
        filtered = 0.0
        for i in range(step, n):
            filtered = line[i - step] * keep + filtered * damping
            line[i] = src[i] + filtered * room
        wet_signal = [w + v * share for w, v in zip(wet_signal, line)]

    g = 0.5
    for delay_time in _ALLPASS_DELAYS:
        step = min(max(1, num_samples(delay_time, sr)), n)
        line = [0.0] * n
        line[:step] = wet_signal[:step]
        wet_signal[:step] = [-value * g for value in line[:step]]
        for i in range(step, n):
            delayed = line[i - step]
            line[i] = wet_signal[i] + delayed * g
            wet_signal[i] = delayed - line[i] * g

    return [s + (w - s) * wet for s, w in zip(src, wet_signal)]


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

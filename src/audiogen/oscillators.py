"""オシレータ(音源波形)。

周波数には固定値のほか ``f(t) -> Hz`` の関数も渡せる。位相を積算しているので、
スイープさせても波形が途切れない。
"""

from __future__ import annotations

import math
import random
from typing import Callable, Sequence

from .core import SAMPLE_RATE, num_samples

FreqLike = float | Callable[[float], float]
Shape = Callable[[float], float]


def _as_freq_fn(freq: FreqLike) -> Callable[[float], float]:
    if callable(freq):
        return freq
    return lambda _t: float(freq)


# --- 波形(位相 0.0〜1.0 を受け取り -1.0〜1.0 を返す) -------------------------


def sine_shape(phase: float) -> float:
    return math.sin(2.0 * math.pi * phase)


def saw_shape(phase: float) -> float:
    return 2.0 * phase - 1.0


def triangle_shape(phase: float) -> float:
    return 4.0 * abs(phase - 0.5) - 1.0


def square_shape(phase: float, duty: float = 0.5) -> float:
    """矩形波。デューティ比を変えても直流成分が出ないよう上下を釣り合わせる。

    duty=0.5 では通常の ±1 の矩形波と一致する。
    """
    duty = min(max(duty, 1e-6), 1.0 - 1e-6)
    scale = max(duty, 1.0 - duty)
    return (1.0 - duty) / scale if phase < duty else -duty / scale


SHAPES: dict[str, Shape] = {
    "sine": sine_shape,
    "saw": saw_shape,
    "triangle": triangle_shape,
    "square": square_shape,
    "pulse25": lambda p: square_shape(p, 0.25),
    "pulse12": lambda p: square_shape(p, 0.125),
}


def render(
    shape: Shape | str,
    freq: FreqLike,
    duration: float,
    sr: int = SAMPLE_RATE,
    amp: float = 1.0,
    phase: float = 0.0,
) -> list[float]:
    """任意の波形関数を鳴らす。位相積算式なので周波数変化に追従する。"""
    if isinstance(shape, str):
        try:
            shape = SHAPES[shape]
        except KeyError:
            raise ValueError(f"unknown shape: {shape!r} (available: {', '.join(SHAPES)})") from None

    n = num_samples(duration, sr)
    freq_fn = _as_freq_fn(freq)
    out = [0.0] * n
    ph = phase
    for i in range(n):
        out[i] = amp * shape(ph)
        ph += freq_fn(i / sr) / sr
        ph -= math.floor(ph)
    return out


def sine(freq: FreqLike, duration: float, sr: int = SAMPLE_RATE, amp: float = 1.0) -> list[float]:
    return render(sine_shape, freq, duration, sr, amp)


def saw(freq: FreqLike, duration: float, sr: int = SAMPLE_RATE, amp: float = 1.0) -> list[float]:
    return render(saw_shape, freq, duration, sr, amp)


def triangle(freq: FreqLike, duration: float, sr: int = SAMPLE_RATE, amp: float = 1.0) -> list[float]:
    return render(triangle_shape, freq, duration, sr, amp)


def square(
    freq: FreqLike,
    duration: float,
    sr: int = SAMPLE_RATE,
    amp: float = 1.0,
    duty: float = 0.5,
) -> list[float]:
    return render(lambda p: square_shape(p, duty), freq, duration, sr, amp)


def noise(
    duration: float,
    sr: int = SAMPLE_RATE,
    amp: float = 1.0,
    rng: random.Random | None = None,
) -> list[float]:
    """ホワイトノイズ。"""
    rng = rng or random.Random()
    return [amp * (rng.random() * 2.0 - 1.0) for _ in range(num_samples(duration, sr))]


def supersaw(
    freq: FreqLike,
    duration: float,
    sr: int = SAMPLE_RATE,
    amp: float = 1.0,
    voices: int = 3,
    detune: float = 0.012,
) -> list[float]:
    """複数のノコギリ波をデチューンして重ねた、厚みのある音。"""
    freq_fn = _as_freq_fn(freq)
    n = num_samples(duration, sr)
    out = [0.0] * n
    for v in range(voices):
        ratio = 1.0 + detune * (v - (voices - 1) / 2.0)
        voice = render(saw_shape, lambda t, r=ratio: freq_fn(t) * r, duration, sr, amp / voices)
        for i, value in enumerate(voice):
            out[i] += value
    return out


# --- 周波数エンベロープ -------------------------------------------------------


def sweep(start: float, end: float, duration: float, curve: str = "exp") -> Callable[[float], float]:
    """``start`` から ``end`` へ変化する周波数関数を返す。"""
    if duration <= 0:
        return lambda _t: end
    if curve == "linear":
        return lambda t: start + (end - start) * min(1.0, max(0.0, t / duration))
    if curve == "exp":
        start = max(start, 1e-6)
        end = max(end, 1e-6)
        ratio = end / start
        return lambda t: start * (ratio ** min(1.0, max(0.0, t / duration)))
    raise ValueError(f"unknown curve: {curve!r}")


def vibrato(base: FreqLike, rate: float = 5.5, depth: float = 0.02) -> Callable[[float], float]:
    """周波数を周期的に揺らす(``depth`` は比率)。"""
    base_fn = _as_freq_fn(base)
    return lambda t: base_fn(t) * (1.0 + depth * math.sin(2.0 * math.pi * rate * t))


def steps(values: Sequence[float], step_duration: float) -> Callable[[float], float]:
    """``step_duration`` ごとに周波数を階段状に切り替える(アルペジオ音源向け)。"""
    if not values:
        raise ValueError("values must not be empty")

    def fn(t: float) -> float:
        index = int(t / step_duration) if step_duration > 0 else 0
        return values[min(index, len(values) - 1)]

    return fn

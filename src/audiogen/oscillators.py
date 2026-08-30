"""オシレータ(音源波形)。

周波数には固定値のほか ``f(t) -> Hz`` の関数も渡せる。位相を積算しているので、
スイープさせても波形が途切れない。

固定周波数の場合は、波形ごとに専用ループへ分岐して1サンプルあたりの
関数呼び出しを省いている(可変周波数のときだけ汎用の積算ループを使う)。
"""

from __future__ import annotations

import math
import random
from typing import Callable, Sequence

from .core import SAMPLE_RATE, num_samples

FreqLike = float | Callable[[float], float]
Shape = Callable[[float], float]

_TAU = 2.0 * math.pi


def _as_freq_fn(freq: FreqLike) -> Callable[[float], float]:
    if callable(freq):
        return freq
    return lambda _t: float(freq)


# --- 波形(位相 0.0〜1.0 を受け取り -1.0〜1.0 を返す) -------------------------


def sine_shape(phase: float) -> float:
    return math.sin(_TAU * phase)


def saw_shape(phase: float) -> float:
    return 2.0 * phase - 1.0


def triangle_shape(phase: float) -> float:
    return 4.0 * abs(phase - 0.5) - 1.0


def _pulse_levels(duty: float) -> tuple[float, float, float]:
    """デューティ比から、直流成分が出ない上下の振幅を求める。"""
    duty = min(max(duty, 1e-6), 1.0 - 1e-6)
    scale = max(duty, 1.0 - duty)
    return duty, (1.0 - duty) / scale, -duty / scale


def square_shape(phase: float, duty: float = 0.5) -> float:
    """矩形波。デューティ比を変えても直流成分が出ないよう上下を釣り合わせる。

    duty=0.5 では通常の ±1 の矩形波と一致する。
    """
    duty, high, low = _pulse_levels(duty)
    return high if phase < duty else low


class Pulse:
    """デューティ比を保持する矩形波。``render()`` から専用ループを選ぶ目印も兼ねる。"""

    __slots__ = ("duty", "high", "low")

    def __init__(self, duty: float = 0.5) -> None:
        self.duty, self.high, self.low = _pulse_levels(duty)

    def __call__(self, phase: float) -> float:
        return self.high if phase < self.duty else self.low

    def __repr__(self) -> str:  # pragma: no cover - デバッグ用
        return f"Pulse(duty={self.duty})"


SHAPES: dict[str, Shape] = {
    "sine": sine_shape,
    "saw": saw_shape,
    "triangle": triangle_shape,
    "square": Pulse(0.5),
    "pulse25": Pulse(0.25),
    "pulse12": Pulse(0.125),
}


def _resolve_shape(shape: Shape | str) -> Shape:
    if callable(shape):
        return shape
    try:
        return SHAPES[shape]
    except KeyError:
        raise ValueError(f"unknown shape: {shape!r} (available: {', '.join(SHAPES)})") from None


def _render_constant(shape: Shape, n: int, inc: float, amp: float, phase: float) -> list[float]:
    """周波数が一定の場合の高速経路。位相を直接計算して関数呼び出しを避ける。"""
    if shape is sine_shape:
        sin = math.sin
        return [amp * sin(_TAU * ((phase + i * inc) % 1.0)) for i in range(n)]
    if shape is saw_shape:
        return [amp * (2.0 * ((phase + i * inc) % 1.0) - 1.0) for i in range(n)]
    if shape is triangle_shape:
        return [amp * (4.0 * abs(((phase + i * inc) % 1.0) - 0.5) - 1.0) for i in range(n)]
    if isinstance(shape, Pulse):
        duty = shape.duty
        high = amp * shape.high
        low = amp * shape.low
        return [high if ((phase + i * inc) % 1.0) < duty else low for i in range(n)]
    return [amp * shape((phase + i * inc) % 1.0) for i in range(n)]


def render(
    shape: Shape | str,
    freq: FreqLike,
    duration: float,
    sr: int = SAMPLE_RATE,
    amp: float = 1.0,
    phase: float = 0.0,
) -> list[float]:
    """任意の波形関数を鳴らす。位相積算式なので周波数変化に追従する。"""
    shape = _resolve_shape(shape)
    n = num_samples(duration, sr)
    if n == 0:
        return []

    if not callable(freq):
        return _render_constant(shape, n, float(freq) / sr, amp, phase)

    out = [0.0] * n
    ph = phase
    for i in range(n):
        out[i] = amp * shape(ph)
        ph += freq(i / sr) / sr
        ph %= 1.0
    return out


def sine(freq: FreqLike, duration: float, sr: int = SAMPLE_RATE, amp: float = 1.0) -> list[float]:
    return render(sine_shape, freq, duration, sr, amp)


def saw(freq: FreqLike, duration: float, sr: int = SAMPLE_RATE, amp: float = 1.0) -> list[float]:
    return render(saw_shape, freq, duration, sr, amp)


def triangle(freq: FreqLike, duration: float, sr: int = SAMPLE_RATE, amp: float = 1.0) -> list[float]:
    return render(triangle_shape, freq, duration, sr, amp)


_PULSE_CACHE: dict[float, Pulse] = {}


def pulse_shape(duty: float = 0.5) -> Pulse:
    """デューティ比つきの矩形波オブジェクトを(使い回しつつ)返す。"""
    shape = _PULSE_CACHE.get(duty)
    if shape is None:
        shape = _PULSE_CACHE[duty] = Pulse(duty)
    return shape


def square(
    freq: FreqLike,
    duration: float,
    sr: int = SAMPLE_RATE,
    amp: float = 1.0,
    duty: float = 0.5,
) -> list[float]:
    return render(pulse_shape(duty), freq, duration, sr, amp)


def noise(
    duration: float,
    sr: int = SAMPLE_RATE,
    amp: float = 1.0,
    rng: random.Random | None = None,
) -> list[float]:
    """ホワイトノイズ。"""
    rng = rng or random.Random()
    uniform = rng.uniform
    return [uniform(-amp, amp) for _ in range(num_samples(duration, sr))]


def supersaw(
    freq: FreqLike,
    duration: float,
    sr: int = SAMPLE_RATE,
    amp: float = 1.0,
    voices: int = 3,
    detune: float = 0.012,
) -> list[float]:
    """複数のノコギリ波をデチューンして重ねた、厚みのある音。"""
    n = num_samples(duration, sr)
    out = [0.0] * n
    for v in range(voices):
        ratio = 1.0 + detune * (v - (voices - 1) / 2.0)
        if callable(freq):
            voice_freq: FreqLike = lambda t, r=ratio: freq(t) * r
        else:
            voice_freq = float(freq) * ratio
        voice = render(saw_shape, voice_freq, duration, sr, amp / voices)
        out = [a + b for a, b in zip(out, voice)]
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
    return lambda t: base_fn(t) * (1.0 + depth * math.sin(_TAU * rate * t))


def steps(values: Sequence[float], step_duration: float) -> Callable[[float], float]:
    """``step_duration`` ごとに周波数を階段状に切り替える(アルペジオ音源向け)。"""
    if not values:
        raise ValueError("values must not be empty")

    def fn(t: float) -> float:
        index = int(t / step_duration) if step_duration > 0 else 0
        return values[min(index, len(values) - 1)]

    return fn

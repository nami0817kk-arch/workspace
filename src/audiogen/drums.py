"""ドラム音源と、16分音符グリッドのパターン。

パターンは16文字の文字列で表す。``x`` = 強、``o`` = 弱、``.`` = 休符。
"""

from __future__ import annotations

import random

from . import effects as fx
from . import envelope as env
from . import oscillators as osc
from .core import SAMPLE_RATE, mix

STEPS_PER_BAR = 16


def kick(sr: int = SAMPLE_RATE, duration: float = 0.32) -> list[float]:
    """バスドラム。ピッチが急降下するサイン波。"""
    body = osc.sine(osc.sweep(140.0, 45.0, duration * 0.25), duration, sr)
    body = env.apply(body, env.percussive(duration, tau=duration * 0.3, attack=0.002, sr=sr))
    return fx.distort(body, drive=1.6)


def snare(sr: int = SAMPLE_RATE, duration: float = 0.24, seed: int | None = None) -> list[float]:
    """スネア。ノイズ + 胴鳴りのトーン。"""
    rng = random.Random(seed if seed is not None else 0)
    body = fx.highpass(osc.noise(duration, sr, rng=rng), 900.0, sr)
    body = env.apply(body, env.percussive(duration, tau=0.075, attack=0.001, sr=sr))
    tone = osc.triangle(190.0, duration, sr, amp=0.5)
    tone = env.apply(tone, env.percussive(duration, tau=0.045, attack=0.001, sr=sr))
    return mix(body, tone, gains=(0.8, 0.5))


def hihat(sr: int = SAMPLE_RATE, duration: float = 0.07, seed: int | None = None) -> list[float]:
    """クローズドハイハット。"""
    rng = random.Random(seed if seed is not None else 1)
    body = fx.highpass(osc.noise(duration, sr, rng=rng), 6500.0, sr)
    return env.apply(body, env.percussive(duration, tau=0.018, attack=0.0005, sr=sr))


def open_hihat(sr: int = SAMPLE_RATE, duration: float = 0.28, seed: int | None = None) -> list[float]:
    """オープンハイハット。"""
    rng = random.Random(seed if seed is not None else 2)
    body = fx.highpass(osc.noise(duration, sr, rng=rng), 5500.0, sr)
    return env.apply(body, env.percussive(duration, tau=0.11, attack=0.0005, sr=sr))


def clap(sr: int = SAMPLE_RATE, duration: float = 0.22, seed: int | None = None) -> list[float]:
    """ハンドクラップ。短いノイズを3連で重ねる。"""
    rng = random.Random(seed if seed is not None else 3)
    out = [0.0] * int(duration * sr)
    for i, offset in enumerate((0.0, 0.011, 0.022)):
        burst = fx.bandpass(osc.noise(duration - offset, sr, rng=rng), 900.0, 4500.0, sr)
        burst = env.apply(burst, env.percussive(duration - offset, tau=0.05 if i == 2 else 0.012, sr=sr))
        start = int(offset * sr)
        for j, value in enumerate(burst):
            if start + j < len(out):
                out[start + j] += value * 0.6
    return out


VOICES = {
    "kick": kick,
    "snare": snare,
    "hihat": hihat,
    "open_hihat": open_hihat,
    "clap": clap,
}


PATTERNS: dict[str, dict[str, str]] = {
    "none": {},
    "soft": {
        "hihat": "..o...o...o...o.",
        "kick": "x.......x.......",
    },
    "basic": {
        "kick": "x.......x.......",
        "snare": "....x.......x...",
        "hihat": "o.o.o.o.o.o.o.o.",
    },
    "drive": {
        "kick": "x..x..x.x..x..x.",
        "snare": "....x.......x...",
        "hihat": "oxoxoxoxoxoxoxox",
    },
    "march": {
        "kick": "x...x...x...x...",
        "snare": "..o...o...o...o.",
        "hihat": "o.o.o.o.o.o.o.o.",
    },
    "shuffle": {
        "kick": "x.....x.....x...",
        "clap": "....x.......x...",
        "open_hihat": "..o.....o.....o.",
    },
}


def pattern_names() -> list[str]:
    """使えるドラムパターン名を並べる。"""
    return sorted(PATTERNS)


def get_pattern(name: str) -> dict[str, str]:
    """パターン名から ``{音色: 16文字}`` を取り出す。"""
    try:
        return PATTERNS[name]
    except KeyError:
        raise ValueError(
            f"unknown drum pattern: {name!r} (available: {', '.join(pattern_names())})"
        ) from None

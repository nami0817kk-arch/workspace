"""音量エンベロープ。"""

from __future__ import annotations

import math
from typing import Sequence

from .core import SAMPLE_RATE, num_samples


def adsr(
    duration: float,
    attack: float = 0.01,
    decay: float = 0.05,
    sustain: float = 0.7,
    release: float = 0.1,
    sr: int = SAMPLE_RATE,
) -> list[float]:
    """ADSR カーブを作る。``duration`` はリリースを含む全体長。

    A+D+R が全体長を超える場合は、比率を保ったまま縮める。
    """
    n = num_samples(duration, sr)
    if n == 0:
        return []

    attack = max(0.0, attack)
    decay = max(0.0, decay)
    release = max(0.0, release)
    total = attack + decay + release
    limit = duration * 0.999
    if total > limit and total > 0:
        scale = limit / total
        attack, decay, release = attack * scale, decay * scale, release * scale

    n_a = num_samples(attack, sr)
    n_d = num_samples(decay, sr)
    n_r = num_samples(release, sr)
    n_s = max(0, n - n_a - n_d - n_r)

    env: list[float] = []
    for i in range(n_a):
        env.append(i / n_a)
    for i in range(n_d):
        env.append(1.0 + (sustain - 1.0) * (i / n_d))
    env.extend([sustain] * n_s)
    for i in range(n_r):
        env.append(sustain * (1.0 - i / n_r))
    del env[n:]
    env.extend([0.0] * (n - len(env)))
    return env


def percussive(duration: float, tau: float = 0.12, attack: float = 0.002, sr: int = SAMPLE_RATE) -> list[float]:
    """立ち上がりが速く指数減衰する打楽器向けエンベロープ。"""
    n = num_samples(duration, sr)
    n_a = min(num_samples(attack, sr), n)
    tau = max(tau, 1e-4)
    env = [0.0] * n
    for i in range(n_a):
        env[i] = i / n_a
    for i in range(n_a, n):
        env[i] = math.exp(-((i - n_a) / sr) / tau)
    return env


def ramp(duration: float, start: float = 1.0, end: float = 0.0, sr: int = SAMPLE_RATE) -> list[float]:
    """直線的に変化するエンベロープ。"""
    n = num_samples(duration, sr)
    if n <= 1:
        return [start] * n
    return [start + (end - start) * (i / (n - 1)) for i in range(n)]


def apply(buf: Sequence[float], env: Sequence[float]) -> list[float]:
    """バッファにエンベロープを掛ける。長さは短い方に揃う。"""
    return [value * env[i] for i, value in enumerate(buf[: len(env)])]

"""効果音(SFX)のプリセット。

すべて ``preset(sr=..., seed=..., **params) -> list[float]`` の形で、
モノラルの float バッファを返す。``PRESETS`` から名前で引ける。
"""

from __future__ import annotations

import random
from typing import Callable

from . import effects as fx
from . import envelope as env
from . import oscillators as osc
from .core import SAMPLE_RATE, add_into, concat, fade, mix, normalize, remove_dc, silence

SfxFunc = Callable[..., list]


def _finish(buf: list[float], sr: int, level: float = 0.85) -> list[float]:
    """直流除去・正規化・極短フェードで仕上げる(クリックノイズ防止)。"""
    return fade(normalize(remove_dc(buf), level), fade_in=0.001, fade_out=0.008, sr=sr)


def coin(sr: int = SAMPLE_RATE, seed: int | None = None, pitch: float = 1.0) -> list[float]:
    """コイン取得音。短い音のあと高い音を伸ばす、定番の2音。"""
    first = osc.square(988.0 * pitch, 0.055, sr, duty=0.5)
    second = osc.square(1319.0 * pitch, 0.32, sr, duty=0.5)
    first = env.apply(first, env.adsr(0.055, 0.002, 0.01, 0.9, 0.01, sr))
    second = env.apply(second, env.percussive(0.32, tau=0.13, attack=0.002, sr=sr))
    return _finish(concat(first, second), sr)


def jump(sr: int = SAMPLE_RATE, seed: int | None = None, pitch: float = 1.0) -> list[float]:
    """ジャンプ音。上昇するパルス波スイープ。"""
    duration = 0.22
    freq = osc.sweep(220.0 * pitch, 880.0 * pitch, duration * 0.8)
    tone = osc.render("pulse25", freq, duration, sr)
    return _finish(env.apply(tone, env.percussive(duration, tau=0.09, attack=0.003, sr=sr)), sr)


def laser(sr: int = SAMPLE_RATE, seed: int | None = None, pitch: float = 1.0) -> list[float]:
    """レーザー / ショット音。急降下スイープ。"""
    duration = 0.28
    freq = osc.sweep(1800.0 * pitch, 120.0 * pitch, duration)
    tone = mix(
        osc.saw(freq, duration, sr, amp=0.7),
        osc.square(freq, duration, sr, amp=0.4),
    )
    tone = fx.lowpass(tone, osc.sweep(6000.0, 800.0, duration), sr)
    return _finish(env.apply(tone, env.percussive(duration, tau=0.1, attack=0.001, sr=sr)), sr)


def explosion(sr: int = SAMPLE_RATE, seed: int | None = None, duration: float = 1.4) -> list[float]:
    """爆発音。ノイズのフィルタスイープ + 低音のドン。"""
    rng = random.Random(seed)
    body = osc.noise(duration, sr, rng=rng)
    body = fx.lowpass(body, osc.sweep(3200.0, 90.0, duration), sr)
    body = env.apply(body, env.percussive(duration, tau=duration * 0.32, attack=0.004, sr=sr))
    body = fx.distort(body, drive=2.2)

    boom = osc.sine(osc.sweep(150.0, 35.0, duration * 0.6), duration, sr, amp=0.9)
    boom = env.apply(boom, env.percussive(duration, tau=duration * 0.22, attack=0.002, sr=sr))
    return _finish(mix(body, boom, gains=(0.75, 0.6)), sr, level=0.92)


def hit(sr: int = SAMPLE_RATE, seed: int | None = None) -> list[float]:
    """被弾 / 打撃音。ノイズのアタックに低音の芯を足す。"""
    rng = random.Random(seed)
    duration = 0.26
    crack = fx.highpass(osc.noise(duration, sr, rng=rng), 600.0, sr)
    crack = env.apply(crack, env.percussive(duration, tau=0.05, attack=0.001, sr=sr))
    thump = osc.sine(osc.sweep(320.0, 60.0, 0.12), duration, sr)
    thump = env.apply(thump, env.percussive(duration, tau=0.08, attack=0.001, sr=sr))
    return _finish(mix(crack, thump, gains=(0.6, 0.8)), sr)


def powerup(sr: int = SAMPLE_RATE, seed: int | None = None, pitch: float = 1.0) -> list[float]:
    """パワーアップ音。上昇アルペジオ。"""
    freqs = [261.63, 329.63, 392.0, 523.25, 659.26, 783.99]
    step = 0.06
    out: list[float] = []
    for freq in freqs:
        step_tone = osc.square(freq * pitch, step, sr, duty=0.5)
        step_tone = env.apply(step_tone, env.adsr(step, 0.004, 0.02, 0.8, 0.02, sr))
        out = concat(out, step_tone)
    tail = osc.square(freqs[-1] * 2 * pitch, 0.3, sr, duty=0.25)
    tail = env.apply(tail, env.percussive(0.3, tau=0.11, attack=0.003, sr=sr))
    return _finish(concat(out, tail), sr)


def blip(sr: int = SAMPLE_RATE, seed: int | None = None, pitch: float = 1.0) -> list[float]:
    """UI のカーソル移動音。ごく短い一発。"""
    duration = 0.05
    tone = osc.square(880.0 * pitch, duration, sr, duty=0.5)
    return _finish(env.apply(tone, env.percussive(duration, tau=0.02, attack=0.001, sr=sr)), sr, 0.7)


def select(sr: int = SAMPLE_RATE, seed: int | None = None, pitch: float = 1.0) -> list[float]:
    """決定音。二段の上昇ブリップ。"""
    step = 0.055
    low = env.apply(
        osc.square(659.26 * pitch, step, sr, duty=0.5),
        env.adsr(step, 0.003, 0.01, 0.9, 0.015, sr),
    )
    high = env.apply(
        osc.square(987.77 * pitch, 0.16, sr, duty=0.5),
        env.percussive(0.16, tau=0.06, attack=0.002, sr=sr),
    )
    return _finish(concat(low, high), sr, 0.8)


def error(sr: int = SAMPLE_RATE, seed: int | None = None) -> list[float]:
    """エラー / キャンセル音。低い方へ落ちる2音。"""
    step = 0.13
    first = env.apply(osc.square(220.0, step, sr, duty=0.5), env.adsr(step, 0.004, 0.02, 0.85, 0.03, sr))
    second = env.apply(osc.square(155.56, 0.3, sr, duty=0.5), env.percussive(0.3, tau=0.12, attack=0.003, sr=sr))
    return _finish(concat(first, second), sr, 0.8)


def heal(sr: int = SAMPLE_RATE, seed: int | None = None) -> list[float]:
    """回復音。柔らかい上昇アルペジオに残響。"""
    freqs = [523.25, 659.26, 783.99, 1046.5]
    step = 0.09
    out: list[float] = []
    for i, freq in enumerate(freqs):
        tone = osc.triangle(freq, 0.4, sr)
        tone = env.apply(tone, env.percussive(0.4, tau=0.16, attack=0.012, sr=sr))
        add_into(out, tone, offset=int(i * step * sr), gain=0.7)
    return _finish(fx.reverb(out, room=0.72, wet=0.35, sr=sr, tail=0.7), sr, 0.8)


def whoosh(sr: int = SAMPLE_RATE, seed: int | None = None, duration: float = 0.6) -> list[float]:
    """風切り音。ノイズをバンドパスで往復させる。"""
    rng = random.Random(seed)
    body = osc.noise(duration, sr, rng=rng)
    center_up = osc.sweep(300.0, 3000.0, duration * 0.55)
    body = fx.bandpass(
        body,
        low=lambda t: center_up(t) * 0.5,
        high=lambda t: center_up(t) * 1.8,
        sr=sr,
    )
    shape = env.apply(body, env.adsr(duration, duration * 0.45, duration * 0.1, 0.75, duration * 0.4, sr))
    return _finish(shape, sr, 0.8)


def teleport(sr: int = SAMPLE_RATE, seed: int | None = None) -> list[float]:
    """ワープ音。揺らしながら上昇し、ディレイで消える。"""
    duration = 0.5
    base = osc.sweep(200.0, 2400.0, duration)
    freq = osc.vibrato(base, rate=22.0, depth=0.08)
    tone = osc.render("pulse12", freq, duration, sr)
    tone = env.apply(tone, env.adsr(duration, 0.02, 0.05, 0.8, 0.2, sr))
    return _finish(fx.delay(tone, time=0.09, feedback=0.45, wet=0.4, sr=sr, tail=0.6), sr, 0.8)


def footstep(sr: int = SAMPLE_RATE, seed: int | None = None) -> list[float]:
    """足音。ごく短いローパスノイズ。"""
    rng = random.Random(seed)
    duration = 0.16
    body = fx.lowpass(osc.noise(duration, sr, rng=rng), osc.sweep(1400.0, 300.0, duration), sr)
    return _finish(env.apply(body, env.percussive(duration, tau=0.035, attack=0.002, sr=sr)), sr, 0.6)


def alarm(sr: int = SAMPLE_RATE, seed: int | None = None, repeats: int = 3) -> list[float]:
    """警報音。2音を交互に繰り返す。"""
    step = 0.18
    out: list[float] = []
    for i in range(max(1, repeats)):
        for freq in (880.0, 587.33):
            tone = osc.square(freq, step, sr, duty=0.5)
            tone = env.apply(tone, env.adsr(step, 0.006, 0.02, 0.85, 0.05, sr))
            out = concat(out, tone)
        out = concat(out, silence(0.05, sr))
    return _finish(out, sr, 0.8)


def pickup(sr: int = SAMPLE_RATE, seed: int | None = None) -> list[float]:
    """アイテム取得音。短い上昇スイープ + キラッとした倍音。"""
    duration = 0.24
    freq = osc.sweep(600.0, 1500.0, duration * 0.7)
    body = osc.triangle(freq, duration, sr)
    sparkle = osc.sine(lambda t: freq(t) * 3.0, duration, sr, amp=0.3)
    tone = mix(body, sparkle)
    return _finish(env.apply(tone, env.percussive(duration, tau=0.09, attack=0.004, sr=sr)), sr, 0.8)


PRESETS: dict[str, SfxFunc] = {
    "coin": coin,
    "jump": jump,
    "laser": laser,
    "explosion": explosion,
    "hit": hit,
    "powerup": powerup,
    "blip": blip,
    "select": select,
    "error": error,
    "heal": heal,
    "whoosh": whoosh,
    "teleport": teleport,
    "footstep": footstep,
    "alarm": alarm,
    "pickup": pickup,
}


def generate(name: str, sr: int = SAMPLE_RATE, seed: int | None = None, **params) -> list[float]:
    """プリセット名から効果音を生成する。"""
    try:
        preset = PRESETS[name]
    except KeyError:
        raise ValueError(f"unknown sfx preset: {name!r} (available: {', '.join(sorted(PRESETS))})") from None
    return preset(sr=sr, seed=seed, **params)


def available() -> list[str]:
    """使えるプリセット名を並べる。"""
    return sorted(PRESETS)

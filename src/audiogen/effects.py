"""エフェクト(フィルタ・空間系・歪み)。"""

from __future__ import annotations

import math
from typing import Callable, Sequence

from .core import SAMPLE_RATE, num_samples

CutoffLike = float | Callable[[float], float]


FILTER_BLOCK = 16
"""スイープするフィルタの係数を作り直す間隔(サンプル)。

44.1kHz なら 0.36ms ごと。この間にカットオフが動く量は無視できるので、
1サンプルごとに pow と除算をやり直すより桁違いに速く、音は変わらない。
"""


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
    alpha = 0.0
    for i, x in enumerate(buf):
        if i % FILTER_BLOCK == 0:
            alpha = _alpha_lowpass(cutoff_fn(i / sr), sr)
        y += alpha * (x - y)
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
    alpha = 0.0
    for i, x in enumerate(buf):
        if i % FILTER_BLOCK == 0:
            alpha = _alpha_highpass(cutoff_fn(i / sr), sr)
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
    dry = list(buf) + [0.0] * tail_samples
    out = list(dry)
    for i in range(step, len(out)):  # 最初の step サンプルには帰還が届かない
        out[i] += out[i - step] * feedback
    return [d + (w - d) * wet for d, w in zip(dry, out)]


# 遅延長は、互いが単純な整数比にならないよう散らす。2倍・3倍のような比が
# あると反射が同じ位置に重なり、同じ間隔の繰り返し(金属的な響き)になる。
# 値は Freeverb の系列から取った(公約数は残るが、比はどれも 1.05〜1.34)。
_COMB_DELAYS = tuple(n / 44100 for n in (1116, 1188, 1277, 1356, 1422, 1491))
_ALLPASS_DELAYS = tuple(n / 44100 for n in (556, 441, 341, 225))


def _reverb_wet(
    src: Sequence[float],
    comb_delays: Sequence[float],
    room: float,
    damping: float,
    sr: int,
) -> list[float]:
    """コムフィルタとオールパスを通した残響成分だけを返す。"""
    n = len(src)
    wet = [0.0] * n
    share = 1.0 / len(comb_delays)
    keep = 1.0 - damping
    for delay_time in comb_delays:
        step = min(max(1, num_samples(delay_time, sr)), n)
        line = [0.0] * n
        # 遅延線が埋まるまでは帰還がないので、入力をそのまま通す。
        line[:step] = src[:step]
        filtered = 0.0
        for i in range(step, n):
            filtered = line[i - step] * keep + filtered * damping
            line[i] = src[i] + filtered * room
        wet = [w + v * share for w, v in zip(wet, line)]

    g = 0.5
    for delay_time in _ALLPASS_DELAYS:
        step = min(max(1, num_samples(delay_time, sr)), n)
        line = [0.0] * n
        line[:step] = wet[:step]
        wet[:step] = [-value * g for value in line[:step]]
        for i in range(step, n):
            delayed = line[i - step]
            line[i] = wet[i] + delayed * g
            wet[i] = delayed - line[i] * g
    return wet


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
    wet_signal = _reverb_wet(src, _COMB_DELAYS, room, damping, sr)
    return [s + (w - s) * wet for s, w in zip(src, wet_signal)]


STEREO_SPREAD = 0.021
"""左右で遅延時間をずらす割合。

左右にまったく同じ残響を出すと、耳には1点から鳴っているように聞こえる。
遅延時間を数%ずらすと反射の並びが食い違い、空間として広がる。
ずらしすぎると左右で別の部屋になり、モノラルにまとめたとき打ち消しが出る。
"""


def reverb_stereo(
    buf: Sequence[float],
    room: float = 0.7,
    sr: int = SAMPLE_RATE,
    damping: float = 0.35,
    tail: float = 1.2,
    spread: float = STEREO_SPREAD,
) -> tuple[list[float], list[float]]:
    """モノラル入力から、左右で異なる残響成分を作る(センド用)。

    戻り値は残響成分だけ。元の音とどう混ぜるかは呼び出し側が決める。
    """
    room = min(max(room, 0.0), 0.95)
    n = len(buf) + num_samples(tail, sr)
    src = list(buf) + [0.0] * (n - len(buf))
    right_delays = tuple(d * (1.0 + spread) for d in _COMB_DELAYS)
    return (
        _reverb_wet(src, _COMB_DELAYS, room, damping, sr),
        _reverb_wet(src, right_delays, room, damping, sr),
    )


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


def soft_clip(buf: Sequence[float], ceiling: float = 0.98) -> list[float]:
    """天井付近だけを丸めて 0dBFS を超えさせない。"""
    ceiling = max(1e-6, ceiling)
    return [ceiling * math.tanh(value / ceiling) for value in buf]


def limiter(
    buf: Sequence[float],
    threshold: float = 0.7,
    attack: float = 0.004,
    release: float = 0.12,
    sr: int = SAMPLE_RATE,
) -> list[float]:
    """飛び出した音だけを押さえるリミッター。

    ピークだけを見て正規化すると、一発の立ち上がりに引きずられて曲全体が
    小さくなる。しきい値を超えたぶんだけ滑らかに抑えることで、
    山を削って全体を持ち上げられる。
    """
    if not buf:
        return []
    threshold = max(1e-6, threshold)
    attack_coef = 1.0 - math.exp(-1.0 / max(1.0, attack * sr))
    release_coef = 1.0 - math.exp(-1.0 / max(1.0, release * sr))

    out = [0.0] * len(buf)
    gain = 1.0
    for i, value in enumerate(buf):
        level = abs(value)
        target = threshold / level if level > threshold else 1.0
        gain += (target - gain) * (attack_coef if target < gain else release_coef)
        out[i] = value * gain
    return out


def linked_limiter(
    channels: Sequence[Sequence[float]],
    threshold: float = 0.7,
    attack: float = 0.004,
    release: float = 0.12,
    sr: int = SAMPLE_RATE,
) -> list[list[float]]:
    """複数チャンネルに同じ音量変化をかけるリミッター。

    左右を別々に抑えると、片方だけ小さくなった瞬間に音像が横へ動く。
    大きいほうのチャンネルから1つのゲインを決め、両方に同じだけ掛ける。
    """
    if not channels or not channels[0]:
        return [list(channel) for channel in channels]
    if len(channels) == 1:  # 1本ならチャンネル間の比較がいらない
        return [limiter(channels[0], threshold, attack, release, sr)]

    threshold = max(1e-6, threshold)
    attack_coef = 1.0 - math.exp(-1.0 / max(1.0, attack * sr))
    release_coef = 1.0 - math.exp(-1.0 / max(1.0, release * sr))

    left, right = channels[0], channels[1]
    out_left = [0.0] * len(left)
    out_right = [0.0] * len(right)
    gain = 1.0
    for i, (a, b) in enumerate(zip(left, right)):
        level = -a if a < 0.0 else a
        other = -b if b < 0.0 else b
        if other > level:
            level = other
        target = threshold / level if level > threshold else 1.0
        gain += (target - gain) * (attack_coef if target < gain else release_coef)
        out_left[i] = a * gain
        out_right[i] = b * gain
    return [out_left, out_right] + [list(c) for c in channels[2:]]


def sidechain_envelope(
    triggers: Sequence[float],
    length: int,
    sr: int = SAMPLE_RATE,
    amount: float = 0.25,
    attack: float = 0.006,
    release: float = 0.13,
) -> list[float]:
    """指定時刻で一瞬へこむ音量カーブを作る。

    バスドラムの瞬間だけ他のパートを下げると、低音がぶつからず
    リズムの芯が前に出る(サイドチェインコンプの簡易版)。
    """
    amount = min(max(amount, 0.0), 1.0)
    env = [1.0] * max(0, length)
    if not env or amount == 0.0:
        return env

    n_attack = max(1, num_samples(attack, sr))
    n_release = max(1, num_samples(release, sr))
    for trigger in triggers:
        start = num_samples(trigger, sr)
        if start >= length:
            continue
        for k in range(n_attack):
            index = start + k
            if index >= length:
                break
            env[index] = min(env[index], 1.0 - amount * (k / n_attack))
        for k in range(n_release):
            index = start + n_attack + k
            if index >= length:
                break
            env[index] = min(env[index], 1.0 - amount * (1.0 - k / n_release))
    return env


def _gain_from_db(db: float) -> float:
    return 10.0 ** (db / 20.0)


def low_shelf(buf: Sequence[float], cutoff: float, db: float, sr: int = SAMPLE_RATE) -> list[float]:
    """``cutoff`` より下だけ持ち上げる(または下げる)。"""
    if db == 0.0:
        return list(buf)
    amount = _gain_from_db(db) - 1.0
    return [x + amount * low for x, low in zip(buf, lowpass(buf, cutoff, sr))]


def high_shelf(buf: Sequence[float], cutoff: float, db: float, sr: int = SAMPLE_RATE) -> list[float]:
    """``cutoff`` より上だけ持ち上げる(または下げる)。"""
    if db == 0.0:
        return list(buf)
    amount = _gain_from_db(db) - 1.0
    return [x + amount * high for x, high in zip(buf, highpass(buf, cutoff, sr))]


def band_gain(
    buf: Sequence[float], low: float, high: float, db: float, sr: int = SAMPLE_RATE
) -> list[float]:
    """``low``〜``high`` の帯域だけ持ち上げる(または下げる)。

    音を重ねると 200〜400Hz あたりが溜まって全体がこもる。そこを少し
    削るだけで、上の帯域を上げなくても見通しがよくなる。
    """
    if db == 0.0:
        return list(buf)
    amount = _gain_from_db(db) - 1.0
    return [x + amount * mid for x, mid in zip(buf, bandpass(buf, low, high, sr))]

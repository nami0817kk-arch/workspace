"""信号バッファの基本操作と WAV 書き出し。

音声は「-1.0〜1.0 の float を並べた list」で表現する。
外部ライブラリに依存せず、標準ライブラリだけで完結させている。
"""

from __future__ import annotations

import array
import itertools
import math
import os
import sys
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
    if gain == 1.0:
        dst[offset:end] = [a + b for a, b in zip(dst[offset:end], src)]
    else:
        dst[offset:end] = [a + b * gain for a, b in zip(dst[offset:end], src)]
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
        end = len(buf)
        if g == 1.0:
            out[:end] = [a + b for a, b in zip(out, buf)]
        else:
            out[:end] = [a + b * g for a, b in zip(out, buf)]
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


BLOCK_SECONDS = 0.4
"""ラウドネスを測る窓の長さ。BS.1770 に合わせてある。"""

ABSOLUTE_GATE = -70.0
RELATIVE_GATE = -10.0
"""静かな区間を平均から外すためのしきい値(LUFS / dB)。"""


def loudness(buf: Sequence[float], sr: int = SAMPLE_RATE) -> float:
    """体感音量の目安を LUFS 相当で返す。

    ピークだけ揃えても、音の詰まり方によって聞こえる大きさは変わる。
    ITU-R BS.1770 の考え方(K特性で重み付け → 0.4秒ごとの二乗平均 →
    静かな区間を除いて平均)を簡略化して実装している。

    正確な実装ではないので絶対値の保証はしないが、同じ物差しで比べるぶんには足りる。
    """
    if not buf:
        return ABSOLUTE_GATE
    weighted = k_weight(buf, sr)

    size = max(1, num_samples(BLOCK_SECONDS, sr))
    # 二乗の累積和を1度だけ作れば、重なり合う窓の合計を引き算で取り出せる。
    # 窓ごとに数え直すと重なりのぶんだけ同じ計算を繰り返すことになる。
    cumulative = [0.0]
    cumulative.extend(itertools.accumulate(v * v for v in weighted))
    step = max(1, size // 4)
    blocks = [
        (cumulative[i + size] - cumulative[i]) / size
        for i in range(0, max(1, len(weighted) - size + 1), step)
        if i + size < len(cumulative)
    ]
    if not blocks:
        blocks = [cumulative[-1] / len(weighted)]

    def level(mean_square: float) -> float:
        return -0.691 + 10.0 * math.log10(mean_square + 1e-12)

    loud = [b for b in blocks if level(b) > ABSOLUTE_GATE]
    if not loud:
        return ABSOLUTE_GATE
    ungated = level(sum(loud) / len(loud))
    kept = [b for b in loud if level(b) > ungated + RELATIVE_GATE]
    return level(sum(kept) / len(kept)) if kept else ungated


K_HIGHPASS = 38.0
K_SHELF = 1500.0
K_SHELF_DB = 4.0


def k_weight(buf: Sequence[float], sr: int = SAMPLE_RATE) -> list[float]:
    """人の耳の感度に寄せた重み付け。低域を落とし、中高域を持ち上げる。

    ハイパスとシェルフを別々に掛けると同じ列を3回なめることになるので、
    2つのフィルタの状態を持って1回で通す。
    """
    dt = 1.0 / sr
    rc_high = 1.0 / (2.0 * math.pi * K_HIGHPASS)
    alpha_high = rc_high / (rc_high + dt)
    rc_shelf = 1.0 / (2.0 * math.pi * K_SHELF)
    alpha_shelf = rc_shelf / (rc_shelf + dt)
    amount = 10.0 ** (K_SHELF_DB / 20.0) - 1.0

    out = [0.0] * len(buf)
    low_y = low_prev = 0.0
    shelf_y = shelf_prev = 0.0
    for i, x in enumerate(buf):
        low_y = alpha_high * (low_y + x - low_prev)
        low_prev = x
        shelf_y = alpha_shelf * (shelf_y + low_y - shelf_prev)
        shelf_prev = low_y
        out[i] = low_y + amount * shelf_y
    return out


def normalize_loudness(
    buf: Sequence[float],
    target: float = -16.0,
    sr: int = SAMPLE_RATE,
    ceiling: float = 0.89,
) -> list[float]:
    """体感音量を ``target`` に合わせる。``ceiling`` を超える場合はそこで止める。

    音量を上げると波形が天井を越えることがある。そのときは目標より小さくても
    天井に合わせる(歪ませない方を優先する)。
    """
    if not buf:
        return []
    current = loudness(buf, sr)
    if current <= ABSOLUTE_GATE:
        return list(buf)
    scale = 10.0 ** ((target - current) / 20.0)
    current_peak = peak(buf)
    if current_peak * scale > ceiling:
        scale = ceiling / current_peak
    return [value * scale for value in buf]


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

    frames = array.array("h", (round(clip(value) * 32767.0) for value in buf))
    if sys.byteorder == "big":  # WAV は常にリトルエンディアン
        frames.byteswap()

    with wave.open(path, "wb") as fp:
        fp.setnchannels(channels)
        fp.setsampwidth(2)
        fp.setframerate(sr)
        fp.writeframes(frames.tobytes())
    return path


def duration_of(buf: Sequence[float], sr: int = SAMPLE_RATE, channels: int = 1) -> float:
    """バッファの再生秒数を返す。"""
    return len(buf) / channels / sr

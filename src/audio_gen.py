"""BGM・効果音のプレースホルダ生成。

配布音源はライセンス確認が要るので、まずは自前で合成した音でミックスを通せるようにする。
`assets/audio/` に自分の音源を置けばそちらが使われる。
"""

from __future__ import annotations

import math
import random
import struct
import wave
from pathlib import Path

from .config import _resolve

RATE = 44100
BGM_SECONDS = 8.0  # ループ素材。長さは ffmpeg 側で伸ばす

# Am - F - C - G。1コードあたり2秒
PROGRESSION = [
    (220.00, 261.63, 329.63),  # Am
    (174.61, 220.00, 261.63),  # F
    (261.63, 329.63, 392.00),  # C
    (196.00, 246.94, 293.66),  # G
]


def ensure_audio_assets(force: bool = False) -> list[Path]:
    """不足している BGM / 効果音を生成する。"""
    directory = _resolve("assets/audio")
    directory.mkdir(parents=True, exist_ok=True)
    created: list[Path] = []

    targets = {
        "bgm_loop.wav": generate_bgm,
        "se_pon.wav": generate_pon,
        "se_whoosh.wav": generate_whoosh,
        "se_jingle.wav": generate_jingle,
    }
    for name, generator in targets.items():
        path = directory / name
        if force or not path.exists():
            generator(path)
            created.append(path)
    return created


def generate_bgm(path: Path) -> Path:
    """コード進行をなぞるだけの静かなパッド。喋りの下に敷く前提で倍音は少なめ。"""
    samples: list[float] = []
    chord_len = BGM_SECONDS / len(PROGRESSION)
    for index, chord in enumerate(PROGRESSION):
        for n in range(int(RATE * chord_len)):
            t = n / RATE
            # コードの継ぎ目でプツッと鳴らないよう、両端をなだらかにする
            envelope = _fade_window(t, chord_len, 0.35)
            value = sum(math.sin(2 * math.pi * freq * (t + index * chord_len)) for freq in chord)
            # 低いオクターブを薄く足して厚みを出す
            value += 0.5 * math.sin(math.pi * chord[0] * (t + index * chord_len))
            samples.append(value / 4.0 * envelope * 0.5)
    _write(path, samples)
    return path


def generate_pon(path: Path) -> Path:
    """テロップ用の軽い「ポン」。"""
    samples = []
    length = 0.18
    for n in range(int(RATE * length)):
        t = n / RATE
        decay = math.exp(-t * 26)
        value = math.sin(2 * math.pi * 880 * t) + 0.4 * math.sin(2 * math.pi * 1320 * t)
        samples.append(value * decay * 0.4)
    _write(path, samples)
    return path


def generate_whoosh(path: Path) -> Path:
    """場面転換用のノイズスイープ。"""
    random.seed(7)
    length = 0.5
    previous = 0.0
    samples = []
    for n in range(int(RATE * length)):
        t = n / RATE
        ratio = t / length
        noise = random.uniform(-1.0, 1.0)
        # カットオフを上げ下げして「シュッ」と鳴らす
        alpha = 0.02 + 0.35 * math.sin(math.pi * ratio)
        previous += alpha * (noise - previous)
        envelope = math.sin(math.pi * ratio) ** 2
        samples.append(previous * envelope * 0.5)
    _write(path, samples)
    return path


def generate_jingle(path: Path) -> Path:
    """章の切り替えに使う3音のアルペジオ。"""
    samples = []
    for freq in (523.25, 659.25, 783.99):
        for n in range(int(RATE * 0.14)):
            t = n / RATE
            decay = math.exp(-t * 12)
            samples.append(math.sin(2 * math.pi * freq * t) * decay * 0.35)
    _write(path, samples)
    return path


def _fade_window(t: float, length: float, edge: float) -> float:
    if t < edge:
        return t / edge
    if t > length - edge:
        return max(0.0, (length - t) / edge)
    return 1.0


def _write(path: Path, samples: list[float]) -> None:
    """モノラル16bitで書き出す。範囲外はクリップする。"""
    frames = bytearray()
    for value in samples:
        clipped = max(-1.0, min(1.0, value))
        frames += struct.pack("<h", int(clipped * 32000))
    with wave.open(str(path), "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(RATE)
        out.writeframes(bytes(frames))

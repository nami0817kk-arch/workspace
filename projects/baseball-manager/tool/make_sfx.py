"""効果音を合成して assets/sfx/*.wav に書き出す(goso-boat の tool/make_sfx.py と同じ方式)。

外部の音素材を使わず、波形から作る(使用許諾の心配が無く、全部で数十KBに収まる)。
音を直したいときはこのファイルを変えて `python tool/make_sfx.py` を回す。
鳴らす場面は `lib/ui/sound.dart` の `Sfx` と、`GameController` の `_cue` を見る。
"""
from __future__ import annotations

import wave
from pathlib import Path

import numpy as np

RATE = 22050
OUT = Path(__file__).resolve().parent.parent / "assets/sfx"


def env(n: int, attack: float = 0.005, release: float = 0.08) -> np.ndarray:
    """立ち上がりと減衰。ぷつっという音を防ぐ。"""
    t = np.arange(n) / RATE
    a = np.clip(t / attack, 0, 1)
    r = np.clip((n / RATE - t) / release, 0, 1)
    return a * r


def tone(freq: float, dur: float, kind: str = "sine", slide: float = 0.0,
         vol: float = 0.5, release: float = 0.08) -> np.ndarray:
    n = int(RATE * dur)
    t = np.arange(n) / RATE
    f = freq + slide * t / dur  # 音程を滑らせる
    phase = 2 * np.pi * np.cumsum(f) / RATE
    if kind == "sine":
        w = np.sin(phase)
    elif kind == "square":
        w = np.sign(np.sin(phase)) * 0.6
    elif kind == "tri":
        w = 2 / np.pi * np.arcsin(np.sin(phase))
    else:
        raise ValueError(kind)
    return w * env(n, release=release) * vol


def noise(dur: float, vol: float = 0.3, lowpass: int = 8) -> np.ndarray:
    n = int(RATE * dur)
    w = np.random.default_rng(7).uniform(-1, 1, n)
    k = np.ones(lowpass) / lowpass  # 簡単な低域通過で「シャー」を柔らかく
    w = np.convolve(w, k, mode="same")
    return w * env(n, 0.01, dur * 0.8) * vol


def seq(*parts: tuple[float, np.ndarray]) -> np.ndarray:
    """(開始秒, 波形) を重ねる。"""
    end = max(int(s * RATE) + len(w) for s, w in parts)
    out = np.zeros(end)
    for s, w in parts:
        i = int(s * RATE)
        out[i:i + len(w)] += w
    return out


def chord(freqs, dur, vol=0.25, kind="tri", release=0.2):
    return sum(tone(f, dur, kind, vol=vol, release=release) for f in freqs)


SOUNDS = {
    # 行動を選ぶ: 軽い「こつ」
    "tap": lambda: tone(900, 0.04, "sine", vol=0.25),
    # 能力が1つ上がる: 短い上昇音
    "gain": lambda: seq((0, tone(700, 0.07, "tri", vol=0.4)), (0.06, tone(1050, 0.1, "tri", vol=0.4))),
    # ランクアップ: 3音の上昇
    "rankup": lambda: seq(*[(i * 0.07, tone(f, 0.16, "tri", vol=0.38)) for i, f in enumerate([660, 880, 1320])]),
    # 練習が好調・大成功: 「きらっ」
    "great": lambda: seq((0, tone(1318, 0.18, "sine", vol=0.35)), (0.04, tone(1976, 0.22, "sine", vol=0.22))),
    # 練習の失敗: 低い「ぶっ」
    "bad": lambda: tone(170, 0.16, "square", slide=-50, vol=0.22),
    # 出来事が起きた: 柔らかい2音
    "event": lambda: seq((0, tone(784, 0.12, "sine", vol=0.35)), (0.11, tone(988, 0.2, "sine", vol=0.3))),
    # 怪我: 下がる音
    "injury": lambda: seq((0, tone(420, 0.14, "tri", slide=-140, vol=0.4)), (0.13, tone(260, 0.2, "tri", slide=-60, vol=0.35))),
    # 特性の習得・覚醒: 澄んだ上昇の和音
    "trait": lambda: seq(*[(i * 0.08, tone(f, 0.3, "sine", vol=0.3)) for i, f in enumerate([784, 988, 1175, 1568])]),
    # 実績: 明るい3和音
    "achievement": lambda: seq((0, chord([523, 659, 784], 0.22)), (0.16, chord([659, 784, 1046], 0.4, release=0.3))),
    # タイトル: 力強い2和音
    "title": lambda: seq((0, chord([392, 494, 587], 0.2)), (0.18, chord([523, 659, 784, 1046], 0.5, release=0.35))),
    # ドラフト指名: 華やかなファンファーレ
    "draft": lambda: seq(
        (0.00, tone(523, 0.12, "square", vol=0.2)), (0.12, tone(523, 0.12, "square", vol=0.2)),
        (0.24, tone(523, 0.12, "square", vol=0.2)), (0.36, tone(659, 0.34, "square", vol=0.22)),
        (0.36, tone(523, 0.34, "tri", vol=0.2)), (0.70, tone(784, 0.5, "square", vol=0.22)),
        (0.70, chord([523, 659], 0.5, vol=0.15, release=0.3))),
    # 優勝: 長めのファンファーレと拍手のようなノイズ
    "champion": lambda: seq(
        (0.00, tone(523, 0.14, "square", vol=0.2)), (0.16, tone(659, 0.14, "square", vol=0.2)),
        (0.32, tone(784, 0.14, "square", vol=0.2)), (0.48, tone(1046, 0.5, "square", vol=0.24)),
        (0.48, chord([523, 659, 784], 0.6, vol=0.15, release=0.4)),
        (0.60, noise(0.9, 0.12, 3))),
    # 進学・節目: 穏やかな2和音
    "stage": lambda: seq((0, chord([392, 523], 0.25, vol=0.22)), (0.22, chord([440, 587], 0.4, vol=0.22, release=0.3))),
    # 引退: ゆっくり下がる和音
    "retire": lambda: seq((0, chord([523, 659, 784], 0.5, vol=0.2, release=0.4)), (0.5, chord([392, 494, 587], 0.9, vol=0.2, release=0.7))),
}


def write(name: str, w: np.ndarray) -> int:
    w = np.clip(w, -1, 1)
    data = (w * 32767 * 0.9).astype("<i2").tobytes()
    OUT.mkdir(parents=True, exist_ok=True)
    p = OUT / f"{name}.wav"
    with wave.open(str(p), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(data)
    return p.stat().st_size


if __name__ == "__main__":
    total = 0
    for name, make in SOUNDS.items():
        total += write(name, make())
    print(f"{len(SOUNDS)}音 {total // 1024}KB -> {OUT}")

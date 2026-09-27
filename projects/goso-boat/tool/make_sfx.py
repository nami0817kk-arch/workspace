"""効果音を合成して assets/sfx/*.wav に書き出す。

外部の音素材を使わず、ここで波形から作る（使用許諾の心配が無く、全部で数十KBに収まる）。
音を直したいときはこのファイルを変えて `python tool/make_sfx.py` を回す。
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


def tone(freq: float, dur: float, kind: str = "sine", slide: float = 0.0, vol: float = 0.5) -> np.ndarray:
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
    return w * env(n) * vol


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


SOUNDS = {
    # 舟に乗る: 軽い「ぽこっ」
    "board": lambda: tone(620, 0.09, "tri", slide=260, vol=0.55),
    # 降りる: 少し低い
    "unboard": lambda: tone(520, 0.08, "tri", slide=-180, vol=0.45),
    # 出発: 水をかく音＋低い「ぐっ」
    "depart": lambda: seq((0, noise(0.35, 0.22, 20)), (0, tone(180, 0.18, "sine", slide=60, vol=0.35))),
    # 着く: 小さな「とん」
    "arrive": lambda: seq((0, tone(260, 0.08, "sine", slide=-80, vol=0.45)), (0, noise(0.06, 0.12, 6))),
    # できない操作: 低い「ぶっ」
    "nope": lambda: tone(150, 0.12, "square", slide=-30, vol=0.25),
    # 逃げられた: 笛のような警報を2回
    "escape": lambda: seq((0, tone(1180, 0.16, "square", slide=-200, vol=0.25)), (0.2, tone(1180, 0.22, "square", slide=-380, vol=0.25))),
    # 川に飛び込む
    "splash": lambda: seq((0, noise(0.45, 0.35, 4)), (0, tone(420, 0.12, "sine", slide=-300, vol=0.25))),
    # クリア: 上がっていく和音
    "clear": lambda: seq(*[(i * 0.09, tone(f, 0.28, "tri", vol=0.38)) for i, f in enumerate([523, 659, 784, 1046])]),
    # 星1つぶん: 「きらっ」
    "star": lambda: seq((0, tone(1318, 0.18, "sine", vol=0.35)), (0.03, tone(1976, 0.2, "sine", vol=0.2))),
    # ヒント: 柔らかい2音
    "hint": lambda: seq((0, tone(880, 0.14, "sine", vol=0.35)), (0.1, tone(1175, 0.2, "sine", vol=0.3))),
    # ボタン
    "tap": lambda: tone(900, 0.04, "sine", vol=0.25),
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
    print(f"{len(SOUNDS)}音 {total // 1024}KB → {OUT}")

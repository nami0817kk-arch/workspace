"""効果音。BGM は入れず、画面の切り替えと札が出る瞬間にだけ短い音を小さく置く。

音はここで合成する(素材のライセンスも課金も要らない)。作りは歴史の地層・断面図の sfx と同じ。
  カメラ・見せ方が切り替わる  … 空気が滑る「シュッ」 whoosh
  札(地点・数字)が出る        … 小さな「ポン」 pop
声(ピーク 0.5〜0.7)よりずっと小さく置く。気づかれるほど鳴らすとうるさい動画になる。
"""
from __future__ import annotations

import wave
from pathlib import Path
from typing import List, Tuple

import numpy as np

GAIN = {"whoosh": 0.13, "pop": 0.06}
MIN_GAP = {"whoosh": 2.5, "pop": 0.8}      # 同じ音が続きすぎないように(秒)


def whoosh(sr: int) -> np.ndarray:
    n = int(0.45 * sr)
    rnd = np.random.default_rng(11).uniform(-1, 1, n)
    x = np.arange(n) / n
    out, lp, prev = np.zeros(n), 0.0, 0.0
    for i in range(n):                       # だんだん明るくなる低域通過のざわざわ
        lp += (0.05 + 0.25 * x[i]) * (rnd[i] - lp)
        out[i] = lp * 0.6 + (lp - prev) * 2
        prev = lp
    return out * np.sin(np.pi * x) ** 1.5


def pop(sr: int) -> np.ndarray:
    n = int(0.12 * sr)
    x = np.arange(n) / n
    ph = np.cumsum(2 * np.pi * (700 + 600 * x) / sr)
    return np.sin(ph) * np.sin(np.pi * np.minimum(1.0, x * 6)) * (1 - x) ** 2


SOUNDS = {"whoosh": whoosh, "pop": pop}


def thin(events: List[Tuple[float, str]]) -> List[Tuple[float, str]]:
    out, last = [], {}
    for t, name in sorted(events):
        if t - last.get(name, -1e9) >= MIN_GAP[name]:
            out.append((t, name))
            last[name] = t
    return out


def mix(narration: Path, events: List[Tuple[float, str]], out: Path) -> Path:
    """語りの wav に効果音を足した wav を書く(語りの wav はそのまま残す)。"""
    with wave.open(str(narration)) as w:
        sr, ch, n = w.getframerate(), w.getnchannels(), w.getnframes()
        a = np.frombuffer(w.readframes(n), np.int16).astype(np.float32).reshape(-1, ch)
    cache = {}
    for t, name in thin(events):
        s = cache.setdefault(name, SOUNDS[name](sr)) * GAIN[name] * 32767
        i = int(t * sr)
        j = min(len(a), i + len(s))
        if i < j:
            a[i:j] += s[: j - i, None]
    with wave.open(str(out), "wb") as o:
        o.setnchannels(ch)
        o.setsampwidth(2)
        o.setframerate(sr)
        o.writeframes(a.clip(-32768, 32767).astype(np.int16).tobytes())
    return out

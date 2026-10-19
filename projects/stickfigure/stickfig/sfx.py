"""効果音と BGM を、計算で作る(外部の音源・著作権のあるものは使わない)。numpy だけ。

- se(plan): 命中・斬り・壁・着地・溜めの効果音。events と fx.charge の時刻に合わせる
- bgm(seconds, mood): 雰囲気(battle / tense / calm / sad)ごとの伴奏
- render(plan, path, mood): 効果音+BGM を混ぜて wav に書く(44.1kHz ステレオ)
"""
from __future__ import annotations

import math
import wave
from typing import Dict, List

import numpy as np

SR = 44100


def _env(n: int, a: float, d: float) -> np.ndarray:
    t = np.arange(n) / SR
    return np.minimum(1.0, t / max(a, 1e-4)) * np.exp(-t / max(d, 1e-4))


def _noise(n: int, rng) -> np.ndarray:
    return rng.standard_normal(n).astype(np.float64)


def _filt(x: np.ndarray, lo: float = 0.0, hi: float = SR / 2) -> np.ndarray:
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    X[(f < lo) | (f > hi)] = 0
    return np.fft.irfft(X, len(x))


def _sweep(n: int, f0: float, f1: float) -> np.ndarray:
    t = np.arange(n) / SR
    T = max(t[-1], 1e-4)
    f = f0 * (f1 / f0) ** (t / T)
    return np.sin(2 * np.pi * np.cumsum(f) / SR)


def thump(rng, low=140.0, dur=0.32, noise=0.35) -> np.ndarray:
    n = int(SR * dur)
    x = _sweep(n, low, 42.0) * _env(n, 0.002, dur / 3) + noise * _filt(_noise(n, rng), 80, 3500) * _env(n, 0.001, 0.05)
    return x


def slash(rng) -> np.ndarray:
    n = int(SR * 0.42)
    w = _filt(_noise(n, rng), 1800, 9000) * (np.minimum(1.0, np.arange(n) / (SR * 0.14)) ** 2) * _env(n, 0.0001, 0.18)
    t = np.arange(n) / SR
    ring = sum(np.sin(2 * np.pi * f * t) * a for f, a in ((2340, 0.25), (3110, 0.18), (4720, 0.1))) * _env(n, 0.0005, 0.16)
    return 0.55 * w + 0.5 * ring


def whoosh(rng, dur=0.22) -> np.ndarray:
    n = int(SR * dur)
    ramp = np.sin(np.pi * np.arange(n) / n) ** 2
    return 0.5 * _filt(_noise(n, rng), 600, 5000) * ramp


def boom(rng) -> np.ndarray:
    n = int(SR * 1.1)
    x = _sweep(n, 70, 26) * _env(n, 0.003, 0.45) * 1.0
    x += 0.5 * _filt(_noise(n, rng), 40, 900) * _env(n, 0.002, 0.5)
    for _ in range(14):                                  # 崩れる破片のカチカチ
        i = int(rng.uniform(0.05, 0.9) * n)
        k = int(SR * 0.012)
        x[i:i + k] += 0.35 * _noise(min(k, n - i), rng) * np.exp(-np.arange(min(k, n - i)) / (SR * 0.003))
    return x


def land(rng) -> np.ndarray:
    n = int(SR * 0.28)
    return 0.7 * _filt(_noise(n, rng), 60, 700) * _env(n, 0.003, 0.08)


def riser(dur: float, rng) -> np.ndarray:
    n = int(SR * dur)
    t = np.arange(n) / SR
    f = 180 * (7.0 ** (t / max(dur, 1e-3)))
    x = np.sin(2 * np.pi * np.cumsum(f) / SR) * 0.5 + 0.25 * np.sin(4 * np.pi * np.cumsum(f * 1.5) / SR)
    x += 0.3 * _filt(_noise(n, rng), 2000, 9000) * (np.arange(n) / n)
    return x * (np.arange(n) / n) ** 1.5


def _add(buf: np.ndarray, x: np.ndarray, t: float, gain: float = 1.0) -> None:
    i = int(max(0.0, t) * SR)
    if i >= len(buf):
        return
    m = min(len(x), len(buf) - i)
    buf[i:i + m] += gain * x[:m]


def se(plan: dict, seed: int = 7) -> np.ndarray:
    rng = np.random.default_rng(seed)
    fps = plan["fps"]
    dur = plan["n"] / fps
    buf = np.zeros(int(SR * (dur + 1.2)))
    for e in plan["events"]:
        t = e["frame"] / fps
        k = e["kind"]
        if k == "slash":
            _add(buf, slash(rng), t - 0.16, 0.85)
            _add(buf, thump(rng, 220, 0.18, 0.2), t, 0.5)
        elif k in ("kick", "hit"):
            _add(buf, whoosh(rng, 0.16), t - 0.12, 0.6)
            _add(buf, thump(rng, 160 if k == "kick" else 200, 0.3, 0.45), t, 1.0)
        elif k == "miss":
            _add(buf, whoosh(rng, 0.26), t - 0.14, 0.9)
        elif k == "pose":                               # 止め絵(溜め・対峙): 短い低い唸り(間を音で支える)
            n_ = int(SR * 0.5)
            tt = np.arange(n_) / SR
            drone = (np.sin(2 * np.pi * 62 * tt) + 0.5 * np.sin(2 * np.pi * 93 * tt)) * _env(n_, 0.02, 0.3)
            _add(buf, drone, t - 0.05, 0.28)
        elif k == "clash":                              # 金属どうし: 高い倍音の鳴り + 短い打撃
            n_ = int(SR * 0.55)
            tt = np.arange(n_) / SR
            ring = sum(np.sin(2 * np.pi * fq * tt) * a_ for fq, a_ in ((3150, 0.3), (4420, 0.22), (6180, 0.14), (1880, 0.18))) * _env(n_, 0.0005, 0.22)
            _add(buf, ring, t, 0.9)
            _add(buf, thump(rng, 260, 0.14, 0.5), t, 0.6)
        elif k == "heel":
            _add(buf, thump(rng, 120, 0.5, 0.5), t, 1.1)
            _add(buf, boom(rng), t, 0.45)
        elif k == "wall":
            _add(buf, boom(rng), t, 1.0)
        elif k in ("land", "land2"):
            _add(buf, land(rng), t, 0.8)
    # 足音: 足が浮いてから床に着いたコマで、小さく低い音(踏み込み・踏み替えが聞こえると、体が動いて見える)
    try:
        from . import fk
        for who, a in plan["actors"].items():
            sg = 1 if a.get("facing", 1) >= 0 else -1
            was_up = {"foot": False, "rear_foot": False}
            for f, frm in enumerate(plan["frames"]):
                if f > 0 and plan["frames"][f - 1]["tau"] == frm["tau"]:
                    continue
                pa = frm["actors"][who]
                sk = fk.skeleton(pa, sg, pa["root_x"], a.get("scale", 1.0))
                for key in ("foot", "rear_foot"):
                    z = sk[key][1]
                    if z > 0.10:
                        was_up[key] = True
                    elif z < 0.05 and was_up[key]:
                        was_up[key] = False
                        _add(buf, thump(rng, 95, 0.09, 0.6), f / fps, 0.22)
    except Exception:
        pass
    fx = plan.get("scene", {}).get("fx", {})
    for c in fx.get("charge", []):
        f0 = next((i for i, fr in enumerate(plan["frames"]) if fr["tau"] >= c["start"]), None)
        if f0 is not None:
            _add(buf, riser(max(0.2, c["end"] - c["start"]) * 1.3, rng), f0 / fps, 0.5)
    return buf[:int(SR * dur)]


# ---- BGM ----
NOTE = {"A": 57, "B": 59, "C": 60, "D": 62, "E": 64, "F": 65, "G": 67}


def _hz(m: float) -> float:
    return 440.0 * 2 ** ((m - 69) / 12)


def _tone(f: float, dur: float, kind: str = "saw", dec: float = 0.2) -> np.ndarray:
    n = int(SR * dur)
    t = np.arange(n) / SR
    if kind == "saw":
        x = 2 * ((t * f) % 1.0) - 1
    elif kind == "square":
        x = np.sign(np.sin(2 * np.pi * f * t))
    else:
        x = np.sin(2 * np.pi * f * t)
    return x * _env(n, 0.004, dec)


def bgm(seconds: float, mood: str = "battle", seed: int = 3) -> np.ndarray:
    rng = np.random.default_rng(seed)
    buf = np.zeros(int(SR * (seconds + 1.0)))
    if mood in ("battle", "tense"):
        bpm = 156 if mood == "battle" else 120
        beat = 60.0 / bpm
        prog = [57, 53, 55, 52]                          # Am F G E の根音
        nb = int(seconds / beat) + 1
        for b in range(nb):
            t = b * beat
            root = prog[(b // 4) % 4]
            if mood == "battle" and b % 2 == 0:
                _add(buf, thump(rng, 110, 0.22, 0.0), t, 0.55)
            if mood == "battle" and b % 4 in (1, 3):
                _add(buf, _filt(_noise(int(SR * 0.12), rng), 1500, 9000) * _env(int(SR * 0.12), 0.001, 0.045), t, 0.28)
            for h in range(2):
                _add(buf, _filt(_noise(int(SR * 0.04), rng), 6000, 12000) * _env(int(SR * 0.04), 0.0005, 0.012), t + h * beat / 2, 0.12)
            _add(buf, _tone(_hz(root - 12), beat * 0.9, "saw", 0.16), t, 0.22)
            arp = [0, 7, 12, 7][b % 4] + (3 if (b // 4) % 4 in (0, 3) else 4)
            _add(buf, _tone(_hz(root + 12 + arp), beat * 0.45, "square", 0.1), t + beat / 2, 0.07)
        return _filt(buf, 40, 14000)[:int(SR * seconds)]
    # calm / sad: ゆっくりした和音の持続
    chords = [[57, 60, 64], [53, 57, 60], [55, 59, 62], [52, 56, 59]] if mood == "calm" else [[57, 60, 64], [52, 55, 59], [53, 57, 60], [52, 56, 59]]
    seg = 3.2 if mood == "calm" else 4.0
    k = 0
    t = 0.0
    while t < seconds:
        for m in chords[k % 4]:
            x = _tone(_hz(m), seg * 1.15, "sine", seg * 0.9)
            _add(buf, x, t, 0.18)
        if mood == "calm":
            for j, m in enumerate((chords[k % 4][0] + 12, chords[k % 4][2] + 12, chords[k % 4][1] + 12, chords[k % 4][2] + 12)):
                _add(buf, _tone(_hz(m), 0.5, "sine", 0.25), t + j * seg / 4, 0.1)
        t += seg
        k += 1
    return buf[:int(SR * seconds)]


def render(plan: dict, path, mood: str = "battle", bgm_gain: float = 0.5, seed: int = 7) -> str:
    s = se(plan, seed)
    dur = len(s) / SR
    m = bgm(dur, mood) if mood else np.zeros_like(s)
    n = min(len(s), len(m))
    mix = s[:n] + bgm_gain * m[:n]
    fade = int(SR * 0.4)
    if n > 2 * fade:
        mix[:int(SR * 0.05)] *= np.linspace(0, 1, int(SR * 0.05))
        mix[-fade:] *= np.linspace(1, 0, fade)
    mix = np.tanh(1.4 * mix) / np.tanh(1.4)
    mix = 0.85 * mix / max(1e-6, np.max(np.abs(mix)))
    pcm = (np.stack([mix, mix], axis=1) * 32767).astype(np.int16)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    return str(path)

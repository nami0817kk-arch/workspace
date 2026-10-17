"""口パクとまばたきの時刻を決める。

口パク：声の大きさを 1/10 秒ごとに測り、大きい区間は口を開ける（小さな揺れは無視する）。
まばたき：3〜5 秒おきに 0.15 秒だけ目を閉じる（行の番号から決めるので、毎回同じになる）。
"""
from __future__ import annotations

import array
import random
import wave
from pathlib import Path

STEP = 0.1          # 口を開け閉めする細かさ（秒）
OPEN_RATIO = 0.35   # その行の声の大きさの最大値に対して、この割合を超えたら口を開ける
BLINK_EVERY = (3.0, 5.0)
BLINK_LENGTH = 0.15


def mouth_track(wav_path: Path) -> list[bool]:
    """STEP 秒ごとに口を開けるか（True）を返す。"""
    with wave.open(str(wav_path)) as w:
        rate, width, ch = w.getframerate(), w.getsampwidth(), w.getnchannels()
        data = array.array("h", w.readframes(w.getnframes())) if width == 2 else array.array("h")
    if not data:
        return []
    n = int(rate * STEP) * ch
    levels = []
    for i in range(0, len(data), n):
        block = data[i:i + n]
        levels.append(sum(abs(x) for x in block) / max(1, len(block)))
    peak = max(levels) or 1
    raw = [lv > peak * OPEN_RATIO for lv in levels]
    # 1区間だけの開け閉めは、前後に合わせる（ぱくぱくしすぎないように）
    out = raw[:]
    for i in range(1, len(raw) - 1):
        if raw[i] != raw[i - 1] and raw[i] != raw[i + 1]:
            out[i] = raw[i - 1]
    return out


def blinks(seed: int, length: float) -> list[tuple[float, float]]:
    """(閉じ始め, 開く) の並び。"""
    rnd = random.Random(seed)
    t = rnd.uniform(*BLINK_EVERY) * 0.6
    out = []
    while t + BLINK_LENGTH < length:
        out.append((t, t + BLINK_LENGTH))
        t += rnd.uniform(*BLINK_EVERY)
    return out


def segments(mouth: list[bool], blink: list[tuple[float, float]], length: float) -> list[tuple[float, bool, bool]]:
    """(長さ, 口が開いているか, 目を閉じているか) の並びに直す。同じ状態は1つにまとめる。"""
    cuts = {0.0, length}
    for i in range(1, len(mouth)):
        if mouth[i] != mouth[i - 1]:
            cuts.add(min(length, i * STEP))
    for a, b in blink:
        cuts.add(a)
        cuts.add(min(length, b))
    times = sorted(t for t in cuts if 0 <= t <= length)
    out: list[tuple[float, bool, bool]] = []
    for a, b in zip(times, times[1:]):
        if b - a <= 1e-6:
            continue
        mid = (a + b) / 2
        idx = int(mid / STEP)
        m = mouth[idx] if 0 <= idx < len(mouth) else False
        e = any(x <= mid < y for x, y in blink)
        if out and out[-1][1] == m and out[-1][2] == e:
            out[-1] = (out[-1][0] + (b - a), m, e)
        else:
            out.append((b - a, m, e))
    return out

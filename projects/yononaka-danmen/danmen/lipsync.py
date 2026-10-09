# -*- coding: utf-8 -*-
"""声から、口の開き具合と瞬きの時刻を決める。

声の大きさを 1/10 秒ごとに測り、大きい区間ほど口を開ける
（歴史の地層の `chiso/lipsync.py` と同じ考え方）。

    levels(wav, fps)   … コマごとの口の段階（0 閉じ / 1 小 / 2 中 / 3 大）
    blinks(sec, fps)   … 瞬きを入れるコマ（1 半目 / 2 閉じ）

**固定の大きさで切ってはいけない。** 最初そうしたら、7割が「大きく開く」になった
（2026-10-09）。声の録り方・話者・調子で平均の大きさが変わるので、
**その声のいちばん大きいところを 1 として相対で**決める。
"""
from __future__ import annotations

import array
import wave
from pathlib import Path

FPS = 10                      # 1秒に何コマ口を切り替えるか
# いちばん大きいところを 1 としたときの境目。実測で 閉じ21% / 小20% / 中42% / 大17%
CUTS = (0.08, 0.40, 0.80)
BLINK_EVERY = 3.6             # 何秒ごとに瞬きするか
BLINK_FIRST = 1.2             # 最初の瞬きまで


def levels(wav: Path, fps: int = FPS) -> tuple[list[int], float]:
    """コマごとの口の段階と、声の長さ（秒）。"""
    with wave.open(str(wav)) as w:
        n, sr = w.getnframes(), w.getframerate()
        raw = array.array("h", w.readframes(n))
    step = max(sr // fps, 1)
    peaks = []
    for i in range(0, n, step):
        chunk = raw[i:i + step]
        if not chunk:
            break
        peaks.append(max(abs(v) for v in chunk) / 32768)
    top = max(peaks) if peaks else 1.0
    if top <= 0:
        top = 1.0
    out = []
    for q in peaks:
        r = q / top
        out.append(0 if r < CUTS[0] else 1 if r < CUTS[1] else 2 if r < CUTS[2] else 3)
    # **1コマだけの開閉は、ちらついて見える。** 前後が閉じている単独の開きは均す
    for i in range(1, len(out) - 1):
        if out[i] and not out[i - 1] and not out[i + 1]:
            out[i] = 0
    return out, n / sr


def blinks(seconds: float, fps: int = FPS, every: float = BLINK_EVERY,
           first: float = BLINK_FIRST) -> dict[int, int]:
    """{コマ番号: 1 半目 / 2 閉じ}。半目→閉じ→半目 の3コマで1回。"""
    out: dict[int, int] = {}
    t = first
    while t < seconds:
        k = int(t * fps)
        out[k] = 1
        out[k + 1] = 2
        out[k + 2] = 1
        t += every
    return out

# -*- coding: utf-8 -*-
"""効果音。**BGM は入れない。** 場面の切り替えにだけ、短い音を小さく置く。

音はここで**合成する**（素材のライセンスも課金も要らない）。
「歴史の地層」の `chiso/sfx.py` と同じ作りで、鳴らす場所だけ断面図に合わせた。

置く場所は3つだけ。

    画面が変わる       … 紙が滑る「シュッ」 whoosh
    節の頭             … 低い「ゴゴッ」 rumble
    聞き手が驚く       … 小さな「ポン」 pop

**声よりずっと小さく置く。** 気づかれるほど鳴らすと、うるさい動画になる。
"""
from __future__ import annotations

import math
import random
from array import array

# 声（ピーク 0.5〜0.7）に対して、これくらい
GAIN = {"rumble": 0.20, "whoosh": 0.15, "pop": 0.07}
POP_LEAD = 0.04          # 驚きの声の少し前に鳴らす
MIN_POP_GAP = 20.0       # ポンが続きすぎないように（秒）
MIN_WHOOSH_GAP = 3.0     # 画面が速く変わるとき、鳴らしすぎないように


def _env(i: int, n: int, attack: float, sr: int) -> float:
    a = int(attack * sr)
    rise = min(1.0, i / a) if a else 1.0
    return rise * (1 - i / n) ** 2


def rumble(sr: int) -> list[float]:
    """低い「ゴゴッ」。節の頭に。"""
    n = int(0.9 * sr)
    rnd = random.Random(7)
    out, lp = [], 0.0
    for i in range(n):
        lp += 0.02 * (rnd.uniform(-1, 1) - lp)
        s = lp * 3 + math.sin(2 * math.pi * 48 * i / sr) * 0.5
        out.append(s * _env(i, n, 0.01, sr))
    return out


def whoosh(sr: int) -> list[float]:
    """紙が滑る「シュッ」。画面が変わるときに。"""
    n = int(0.45 * sr)
    rnd = random.Random(11)
    out, lp, prev = [], 0.0, 0.0
    for i in range(n):
        x = i / n
        k = 0.05 + 0.25 * x                        # だんだん明るく
        lp += k * (rnd.uniform(-1, 1) - lp)
        hp = lp - prev
        prev = lp
        out.append((lp * 0.6 + hp * 2) * math.sin(math.pi * x) ** 1.5)
    return out


def pop(sr: int) -> list[float]:
    """小さな「ポン」。聞き手が驚くところに。"""
    n = int(0.12 * sr)
    out, ph = [], 0.0
    for i in range(n):
        x = i / n
        ph += 2 * math.pi * (700 + 600 * x) / sr
        out.append(math.sin(ph) * math.sin(math.pi * min(1.0, x * 6)) * (1 - x) ** 2)
    return out


SOUNDS = {"rumble": rumble, "whoosh": whoosh, "pop": pop}


def events(steps: list[dict]) -> list[tuple[float, str]]:
    """どの時刻にどの音を鳴らすか。

    `steps` は {start, 秒数, 画面が変わったか, 話者, 強さ} の並び。
    `danmen.movie` が作る。
    """
    out: list[tuple[float, str]] = []
    last_pop = -1e9
    last_whoosh = -1e9
    for s in steps:
        t = float(s["start"])
        if s.get("screen_changed") and t - last_whoosh >= MIN_WHOOSH_GAP:
            out.append((t, "whoosh"))
            last_whoosh = t
        if s.get("section_head"):
            out.append((t, "rumble"))
        if s.get("who") == "聞き" and s.get("tone") in ("強", "特強") \
                and t - last_pop >= MIN_POP_GAP:
            out.append((max(0.0, t - POP_LEAD), "pop"))
            last_pop = t
    return sorted(out)


def overlay(samples: array, rate: int, channels: int,
            evs: list[tuple[float, str]]) -> array:
    """16bit の音声（array('h')）に効果音を足す。はみ出しは切る。"""
    cache: dict[str, list[float]] = {}
    for t, name in evs:
        snd = cache.setdefault(name, SOUNDS[name](rate))
        g = GAIN[name] * 32767
        start = int(t * rate) * channels
        for k, v in enumerate(snd):
            for c in range(channels):
                j = start + k * channels + c
                if j >= len(samples):
                    break
                samples[j] = max(-32768, min(32767, samples[j] + int(v * g)))
    return samples

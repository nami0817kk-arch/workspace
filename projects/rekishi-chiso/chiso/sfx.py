"""効果音。BGM は入れない（10-04 決定）が、場面の切り替えにだけ短い音を小さく置く（10-04「4を実施」）。

音はここで合成する（素材のライセンスと課金の心配がない）。置く場所は4つだけ:
  節の切り替え（地層のワイプ）  … 低い「ゴゴッ」 rumble
  図が出る                      … 紙が滑る「シュッ」 whoosh
  お金の札の数え上がり終わり    … 「チャリン」 coin
  聞き手の驚き                  … 小さな「ポン」 pop
"""
from __future__ import annotations

import json
import math
import random
from array import array

GAIN = {"rumble": 0.22, "whoosh": 0.18, "coin": 0.10, "pop": 0.08}   # 声（ピーク 0.5〜0.7）よりずっと小さく
FIG_SECONDS = 1.5          # render.FIG_FRAMES / 30fps。お金の数え上がりが終わる時刻
POP_LEAD = 0.04            # 驚きの声の少し前に鳴らす
MIN_POP_GAP = 20.0         # ポンが続きすぎないように（秒）


def _env(i: int, n: int, attack: float, sr: int) -> float:
    a = int(attack * sr)
    rise = min(1.0, i / a) if a else 1.0
    return rise * (1 - i / n) ** 2


def rumble(sr: int) -> list[float]:
    n = int(0.9 * sr)
    rnd = random.Random(7)
    out, lp = [], 0.0
    for i in range(n):
        f = 58 - 20 * i / n
        lp += 0.02 * (rnd.uniform(-1, 1) - lp)                       # 低いところだけ残したざらつき
        s = 0.7 * math.sin(2 * math.pi * f * i / sr) + 2.5 * lp
        out.append(s * _env(i, n, 0.01, sr))
    return out


def whoosh(sr: int) -> list[float]:
    n = int(0.45 * sr)
    rnd = random.Random(11)
    out, lp, prev = [], 0.0, 0.0
    for i in range(n):
        x = i / n
        k = 0.05 + 0.25 * x                                           # だんだん明るく
        lp += k * (rnd.uniform(-1, 1) - lp)
        hp = lp - prev
        prev = lp
        out.append((lp * 0.6 + hp * 2) * math.sin(math.pi * x) ** 1.5)
    return out


def coin(sr: int) -> list[float]:
    n = int(0.55 * sr)
    out = []
    for i in range(n):
        t = i / sr
        second = 0.0 if t < 0.07 else math.sin(2 * math.pi * 3950 * (t - 0.07)) * math.exp(-(t - 0.07) * 9)
        out.append(0.5 * math.sin(2 * math.pi * 2640 * t) * math.exp(-t * 14) + 0.6 * second)
    return out


def pop(sr: int) -> list[float]:
    n = int(0.12 * sr)
    out, ph = [], 0.0
    for i in range(n):
        x = i / n
        ph += 2 * math.pi * (700 + 600 * x) / sr
        out.append(math.sin(ph) * math.sin(math.pi * min(1.0, x * 6)) * (1 - x) ** 2)
    return out


SOUNDS = {"rumble": rumble, "whoosh": whoosh, "coin": coin, "pop": pop}


def events(cues: list) -> list[tuple[float, str]]:
    """どの時刻にどの音を鳴らすか。render.frames の見た目の変わり目と合わせる。"""
    out: list[tuple[float, str]] = []
    last_pop = -1e9
    for i, cue in enumerate(cues):
        line, prev = cue.line, (cues[i - 1].line if i else None)
        if prev is not None and prev.section != line.section:
            out.append((cues[i - 1].end, "rumble"))                  # 節の頭のワイプは前の行の話し終わりから
        fig = getattr(line, "figure", None)
        # 同じ図が1項目増えただけ（upto）は鳴らさない（10-07。図が出たときの1回だけ）
        if fig and (prev is None or getattr(prev, "figure", None) != fig) and "grow_from" not in json.loads(fig):
            out.append((cue.start, "whoosh"))
            if json.loads(fig).get("type") == "money":
                out.append((cue.start + FIG_SECONDS, "coin"))
        if line.tone == "驚き" and line.speaker == "聞き" and cue.start - last_pop >= MIN_POP_GAP:
            out.append((max(0.0, cue.start - POP_LEAD), "pop"))
            last_pop = cue.start
    return sorted(out)


def overlay(samples: array, rate: int, channels: int, evs: list[tuple[float, str]]) -> array:
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

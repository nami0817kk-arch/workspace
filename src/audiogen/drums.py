"""ドラム音源と、16分音符グリッドのパターン。

パターンは16文字の文字列で表す。

    ``x`` 強打  ``o`` 弱打  ``g`` ゴーストノート  ``f`` フラム  ``.`` 休符

ゴーストノートは、主要な打点のあいだに入るごく小さな音。譜面には出ないが、
これがあるとリズムが平坦にならない。フラムは装飾音を少し前に置いた2連打で、
一発が厚くなる。
"""

from __future__ import annotations

import random

from . import effects as fx
from . import envelope as env
from . import oscillators as osc
from .core import SAMPLE_RATE, mix, normalize

STEPS_PER_BAR = 16

REST = "."
SYMBOL_LEVELS: dict[str, float] = {"x": 1.0, "o": 0.6, "g": 0.28, "f": 1.0}
"""記号ごとの音量倍率。"""

FLAM_SYMBOL = "f"
FLAM_LEAD = 0.026
"""フラムの装飾音を、本打の何秒前に置くか。"""

FLAM_LEVEL = 0.45
"""装飾音の音量(本打に対する比)。"""


def symbol_level(symbol: str) -> float:
    """記号から音量倍率を引く。未知の記号は休符とみなす。"""
    return SYMBOL_LEVELS.get(symbol, 0.0)


def kick(sr: int = SAMPLE_RATE, duration: float = 0.32) -> list[float]:
    """バスドラム。ピッチが急降下するサイン波。"""
    body = osc.sine(osc.sweep(140.0, 45.0, duration * 0.25), duration, sr)
    body = env.apply(body, env.percussive(duration, tau=duration * 0.3, attack=0.002, sr=sr))
    return fx.distort(body, drive=1.6)


def snare(sr: int = SAMPLE_RATE, duration: float = 0.24, seed: int | None = None) -> list[float]:
    """スネア。ノイズ + 胴鳴りのトーン。"""
    rng = random.Random(seed if seed is not None else 0)
    body = fx.highpass(osc.noise(duration, sr, rng=rng), 900.0, sr)
    body = env.apply(body, env.percussive(duration, tau=0.075, attack=0.001, sr=sr))
    tone = osc.triangle(190.0, duration, sr, amp=0.5)
    tone = env.apply(tone, env.percussive(duration, tau=0.045, attack=0.001, sr=sr))
    return mix(body, tone, gains=(0.8, 0.5))


def hihat(sr: int = SAMPLE_RATE, duration: float = 0.07, seed: int | None = None) -> list[float]:
    """クローズドハイハット。"""
    rng = random.Random(seed if seed is not None else 1)
    body = fx.highpass(osc.noise(duration, sr, rng=rng), 6500.0, sr)
    return env.apply(body, env.percussive(duration, tau=0.018, attack=0.0005, sr=sr))


def open_hihat(sr: int = SAMPLE_RATE, duration: float = 0.28, seed: int | None = None) -> list[float]:
    """オープンハイハット。"""
    rng = random.Random(seed if seed is not None else 2)
    body = fx.highpass(osc.noise(duration, sr, rng=rng), 5500.0, sr)
    return env.apply(body, env.percussive(duration, tau=0.11, attack=0.0005, sr=sr))


def clap(sr: int = SAMPLE_RATE, duration: float = 0.22, seed: int | None = None) -> list[float]:
    """ハンドクラップ。短いノイズを3連で重ねる。"""
    rng = random.Random(seed if seed is not None else 3)
    out = [0.0] * int(duration * sr)
    for i, offset in enumerate((0.0, 0.011, 0.022)):
        burst = fx.bandpass(osc.noise(duration - offset, sr, rng=rng), 900.0, 4500.0, sr)
        burst = env.apply(burst, env.percussive(duration - offset, tau=0.05 if i == 2 else 0.012, sr=sr))
        start = int(offset * sr)
        for j, value in enumerate(burst):
            if start + j < len(out):
                out[start + j] += value * 0.6
    return out


def timpani(sr: int = SAMPLE_RATE, duration: float = 0.9) -> list[float]:
    """ティンパニ。バスドラムより長く鳴り、音程がはっきり残る。"""
    body = mix(
        osc.sine(osc.sweep(110.0, 73.0, duration * 0.3), duration, sr),
        osc.sine(osc.sweep(220.0, 146.0, duration * 0.2), duration, sr, amp=0.35),
    )
    body = env.apply(body, env.percussive(duration, tau=duration * 0.28, attack=0.004, sr=sr))
    # 歪みで持ち上がったぶんを戻す。他の音色と同じ天井にそろえておく。
    return normalize(fx.distort(body, drive=1.4), 0.95)


def tom(sr: int = SAMPLE_RATE, duration: float = 0.35, seed: int | None = None) -> list[float]:
    """タム。胴の鳴りに少しだけ皮の音を混ぜる。"""
    rng = random.Random(seed if seed is not None else 4)
    body = osc.sine(osc.sweep(210.0, 105.0, duration * 0.35), duration, sr)
    body = env.apply(body, env.percussive(duration, tau=0.13, attack=0.002, sr=sr))
    skin = fx.bandpass(osc.noise(duration, sr, rng=rng), 300.0, 2600.0, sr)
    skin = env.apply(skin, env.percussive(duration, tau=0.03, attack=0.001, sr=sr))
    return mix(body, skin, gains=(0.9, 0.25))


def crash(sr: int = SAMPLE_RATE, duration: float = 1.4, seed: int | None = None) -> list[float]:
    """クラッシュシンバル。区切りの一発。"""
    rng = random.Random(seed if seed is not None else 5)
    body = fx.highpass(osc.noise(duration, sr, rng=rng), 3500.0, sr)
    body = env.apply(body, env.percussive(duration, tau=0.42, attack=0.002, sr=sr))
    return fx.lowpass(body, 12000.0, sr)


def ride(sr: int = SAMPLE_RATE, duration: float = 0.5, seed: int | None = None) -> list[float]:
    """ライドシンバル。芯のある短い打点に、わずかな余韻。"""
    rng = random.Random(seed if seed is not None else 6)
    ping = fx.bandpass(osc.noise(duration, sr, rng=rng), 4000.0, 9000.0, sr)
    ping = env.apply(ping, env.percussive(duration, tau=0.035, attack=0.001, sr=sr))
    wash = fx.highpass(osc.noise(duration, sr, rng=rng), 6000.0, sr)
    wash = env.apply(wash, env.percussive(duration, tau=0.16, attack=0.002, sr=sr))
    return mix(ping, wash, gains=(1.0, 0.3))


VOICES = {
    "kick": kick,
    "snare": snare,
    "hihat": hihat,
    "open_hihat": open_hihat,
    "clap": clap,
    "timpani": timpani,
    "tom": tom,
    "crash": crash,
    "ride": ride,
}


PATTERNS: dict[str, dict[str, str]] = {
    "none": {},
    "soft": {
        "hihat": "..o...o...o...o.",
        "kick": "x.......x.......",
    },
    "basic": {
        "kick": "x.......x.......",
        "snare": "....x.......x...",
        "hihat": "o.o.o.o.o.o.o.o.",
    },
    "drive": {
        "kick": "x..x..x.x..x..x.",
        "snare": "..g.x..g..g.x.g.",  # 主要な打点のあいだにゴーストを置く
        "hihat": "oxoxoxoxoxoxoxox",
    },
    "march": {
        "kick": "x...x...x...x...",
        "snare": "..o...o...o...o.",
        "hihat": "o.o.o.o.o.o.o.o.",
    },
    "shuffle": {
        "kick": "x.....x.....x...",
        "clap": "....x.......x...",
        "open_hihat": "..o.....o.....o.",
    },
    # 報道番組向け。細かい刻みの上でティンパニが小節の頭を締める。
    "news": {
        "kick": "x..x..x...x.x...",
        "snare": "....x.......x...",
        "hihat": "oxoxoxoxoxoxoxox",
        "timpani": "x...............",
    },
    # 行進曲風。ゆったりした足取りに小太鼓とティンパニを重ねる。
    "anthem": {
        "kick": "x.......x.......",
        "snare": "..o.f.o...o.o.o.",
        "timpani": "x.......x...x...",
        "crash": "x...............",
    },
    # スポーツ中継向け。押しの強い刻みに、小節終わりのタム回し。
    "sports": {
        "kick": "x..x..x.x..x..x.",
        "snare": "..g.f..g..g.x...",  # 2拍目はフラムで厚くする
        "ride": "oxoxoxoxoxoxoxox",
        "tom": "..............oo",
    },
    # 手拍子で煽る形。隙間が多いぶん実況や歓声が乗せやすい。
    "stomp": {
        "kick": "x.x.....x.x.....",
        "clap": "....x.......x...",
        "crash": "x...............",
    },
}


# 区間の変わり目に入れる1小節ぶんの手。同じ形が続いたあとに崩れが入ると、
# 次の区間へ渡る感じが出る。フィルはその小節のパターンを丸ごと置き換える。
FILLS: dict[str, dict[str, str]] = {
    "none": {},
    # 小太鼓を細かくしていく、いちばん素直なフィル。
    "snare_roll": {
        "kick": "x.......x.......",
        "snare": "........x.x.xxxx",
    },
    # タムを低い方へ落としながら次へ渡す。
    "tom_fall": {
        "kick": "x...............",
        "snare": "........x.......",
        "tom": "..........x.x.xx",
    },
    # ティンパニの連打。報道・アンセム向け。
    "timpani_roll": {
        "kick": "x...............",
        "timpani": "........x.x.xxxx",
    },
    # 一拍だけ残して止める。次の区間の頭が際立つ。
    "break": {
        "kick": "x...............",
        "crash": "x...............",
    },
}


def fill_names() -> list[str]:
    """使えるフィル名を並べる。"""
    return sorted(FILLS)


def get_fill(name: str) -> dict[str, str]:
    """フィル名から ``{音色: 16文字}`` を取り出す。"""
    try:
        return FILLS[name]
    except KeyError:
        raise ValueError(f"unknown drum fill: {name!r} (available: {', '.join(fill_names())})") from None


def pattern_names() -> list[str]:
    """使えるドラムパターン名を並べる。"""
    return sorted(PATTERNS)


def get_pattern(name: str) -> dict[str, str]:
    """パターン名から ``{音色: 16文字}`` を取り出す。"""
    try:
        return PATTERNS[name]
    except KeyError:
        raise ValueError(
            f"unknown drum pattern: {name!r} (available: {', '.join(pattern_names())})"
        ) from None

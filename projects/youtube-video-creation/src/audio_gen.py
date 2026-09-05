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
BPM = 96
BEAT = 60.0 / BPM
BARS_PER_CHORD = 2
BEATS_PER_BAR = 4

# 曲調ごとの和音進行とテンポ。ニュースの中身に合わせて敷き分ける。
#   news     … 通常の枠。Am-F-C-G。下に敷いても邪魔にならない
#   breaking … 速報。半音進行を混ぜて落ち着かなくする。テンポも上げる
#   calm     … まとめ・深掘り。長調で、動きを減らす
MOODS = {
    "news": {
        "bpm": 96,
        "progression": [
            (220.00, 261.63, 329.63),  # Am
            (174.61, 220.00, 261.63),  # F
            (261.63, 329.63, 392.00),  # C
            (196.00, 246.94, 293.66),  # G
        ],
        "pulse": 1.0,
    },
    "breaking": {
        "bpm": 112,
        "progression": [
            (220.00, 261.63, 329.63),  # Am
            (233.08, 277.18, 349.23),  # B♭（半音上。緊張を作る）
            (220.00, 261.63, 329.63),  # Am
            (196.00, 233.08, 293.66),  # Gm
        ],
        "pulse": 1.35,
    },
    "calm": {
        "bpm": 80,
        "progression": [
            (261.63, 329.63, 392.00),  # C
            (220.00, 261.63, 329.63),  # Am
            (174.61, 220.00, 261.63),  # F
            (196.00, 246.94, 293.66),  # G
        ],
        "pulse": 0.55,
    },
    # 【悲報】に breaking（緊迫）を当てていたが、**悲報と速報は温度が違う。**
    # 登録外・退団・敗戦の回に急かす曲が流れると、内容と合わない（2026-09-05）
    "somber": {
        "bpm": 72,
        "progression": [
            (220.00, 261.63, 329.63),  # Am
            (196.00, 233.08, 293.66),  # Gm
            (174.61, 207.65, 261.63),  # Fm（暗くする）
            (164.81, 196.00, 246.94),  # Em
        ],
        "pulse": 0.45,
    },
    # 【朗報】。デビュー弾・移籍成立など、明るく終わる回
    "victory": {
        "bpm": 108,
        "progression": [
            (261.63, 329.63, 392.00),  # C
            (196.00, 246.94, 293.66),  # G
            (220.00, 261.63, 329.63),  # Am
            (174.61, 220.00, 261.63),  # F
        ],
        "pulse": 1.15,
    },
}

# 台本の【】から曲調を選ぶ。書いていなければ news
# 台本の【】から曲調を選ぶ。**悲報と速報を同じ曲にしない。**
PREFIX_MOOD = {"速報": "breaking", "悲報": "somber", "朗報": "victory",
               "詳報": "calm", "衝撃": "breaking", "現地反応": "news"}

PROGRESSION = MOODS["news"]["progression"]
CHORD_SECONDS = BEAT * BEATS_PER_BAR * BARS_PER_CHORD
BGM_SECONDS = CHORD_SECONDS * len(PROGRESSION)

EDGE = 0.06  # 継ぎ目のクリックを消すための立ち上がり/立ち下がり


def ensure_audio_assets(force: bool = False) -> list[Path]:
    """不足している BGM / 効果音を生成する。"""
    directory = _resolve("assets/audio")
    directory.mkdir(parents=True, exist_ok=True)
    created: list[Path] = []

    targets = {
        "bgm_loop.wav": generate_bgm,
        "bgm_breaking.wav": lambda p: generate_bgm(p, "breaking"),
        "bgm_calm.wav": lambda p: generate_bgm(p, "calm"),
        "bgm_somber.wav": lambda p: generate_bgm(p, "somber"),
        "bgm_victory.wav": lambda p: generate_bgm(p, "victory"),
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


def track_for(script_title: str, override: str | None = None) -> str:
    """台本に合う BGM のパスを返す。

    【速報】と【詳報】で同じ曲が流れると、どちらも同じ温度に聞こえる。
    台本の頭の札から曲調を選ぶ。frontmatter に bgm を書けばそちらが優先。
    """
    if override:
        return override
    for prefix, mood in PREFIX_MOOD.items():
        if f"【{prefix}】" in (script_title or ""):
            return f"assets/audio/{TRACKS[mood]}"
    return f"assets/audio/{TRACKS['news']}"


def moods() -> tuple[str, ...]:
    """作れる曲調の一覧。init-assets がこれを全部書き出す。"""
    return tuple(TRACKS)


TRACKS = {"news": "bgm_loop.wav", "breaking": "bgm_breaking.wav",
          "calm": "bgm_calm.wav", "somber": "bgm_somber.wav",
          "victory": "bgm_victory.wav"}


def _mood(name: str) -> dict:
    """曲調の設定を、テンポから割り出した秒数つきで返す。"""
    entry = dict(MOODS.get(name) or MOODS["news"])
    beat = 60.0 / float(entry["bpm"])
    entry["beat"] = beat
    entry["chord_seconds"] = beat * BEATS_PER_BAR * BARS_PER_CHORD
    entry["seconds"] = entry["chord_seconds"] * len(entry["progression"])
    return entry


def generate_bgm(path: Path, mood: str = "news") -> Path:
    """ニュースの下に敷く BGM。

    パッド（和音の持続音）・アルペジオ・低音のパルスの3層を重ねる。
    喋りとぶつからないよう、中音域は薄めにして低音と高音に寄せている。
    ループさせる前提なので、両端は無音に落として継ぎ目が鳴らないようにする。

    速報と、まとめの深掘りで同じ曲が流れると、どちらも同じ温度に聞こえる。
    mood で進行とテンポを変える（MOODS を参照）。
    """
    entry = _mood(mood)
    seconds = entry["seconds"]
    total = int(RATE * seconds)
    left = [0.0] * total
    right = [0.0] * total

    _lay_pad(left, right, entry, seconds)
    _lay_arpeggio(left, right, entry, seconds)
    _lay_pulse(left, right, entry, seconds)

    for index in range(total):
        gain = _edge_gain(index / RATE, seconds)
        left[index] *= gain
        right[index] *= gain

    _write_stereo(path, left, right)
    return path


def _chord_at(seconds: float, progression=None, chord_seconds: float = 0.0) -> tuple[float, ...]:
    progression = progression or PROGRESSION
    chord_seconds = chord_seconds or CHORD_SECONDS
    return progression[int(seconds / chord_seconds) % len(progression)]


def _lay_pad(left: list[float], right: list[float], mood: dict, seconds: float) -> None:
    """和音の持続音。わずかにデチューンした2声を左右に振って広がりを出す。"""
    for index in range(len(left)):
        t = index / RATE
        chord = _chord_at(t, mood["progression"], mood["chord_seconds"])
        value_l = value_r = 0.0
        for freq in chord:
            value_l += math.sin(2 * math.pi * freq * t)
            value_r += math.sin(2 * math.pi * freq * 1.003 * t)  # デチューン
        # 1オクターブ下を薄く足して土台にする
        low = math.sin(math.pi * chord[0] * t) * 0.6
        left[index] += (value_l / len(chord) * 0.5 + low) * 0.17
        right[index] += (value_r / len(chord) * 0.5 + low) * 0.17


def _lay_arpeggio(left: list[float], right: list[float], mood: dict, seconds: float) -> None:
    """8分音符のアルペジオ。1音ずつ左右に振る。"""
    step = mood["beat"] / 2
    count = int(seconds / step)
    length = int(RATE * step * 1.8)

    for number in range(count):
        start = number * step
        chord = _chord_at(start, mood["progression"], mood["chord_seconds"])
        freq = chord[number % len(chord)] * 2  # 1オクターブ上
        offset = int(start * RATE)
        pan = 0.62 if number % 2 == 0 else 0.38

        for n in range(length):
            index = offset + n
            if index >= len(left):
                break
            t = n / RATE
            decay = math.exp(-t * 7.5)
            value = (math.sin(2 * math.pi * freq * t) * 0.7
                     + math.sin(4 * math.pi * freq * t) * 0.18) * decay * 0.16
            left[index] += value * pan
            right[index] += value * (1 - pan)


def _lay_pulse(left: list[float], right: list[float], mood: dict, seconds: float) -> None:
    """拍を感じさせる低音。強く出すと喋りを邪魔するので控えめに。"""
    length = int(RATE * 0.24)
    beats = int(seconds / mood["beat"])

    for beat in range(beats):
        if beat % 2:  # 1拍おき
            continue
        offset = int(beat * mood["beat"] * RATE)
        for n in range(length):
            index = offset + n
            if index >= len(left):
                break
            t = n / RATE
            freq = 92 - 46 * min(1.0, t / 0.16)   # 下に落ちるサイン
            value = math.sin(2 * math.pi * freq * t) * math.exp(-t * 13) * 0.30 * mood["pulse"]
            left[index] += value
            right[index] += value


def _edge_gain(t: float, length: float) -> float:
    if t < EDGE:
        return t / EDGE
    if t > length - EDGE:
        return max(0.0, (length - t) / EDGE)
    return 1.0


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


def _write_stereo(path: Path, left: list[float], right: list[float]) -> None:
    """ステレオ16bitで書き出す。"""
    frames = bytearray()
    for value_l, value_r in zip(left, right):
        frames += struct.pack(
            "<hh",
            int(max(-1.0, min(1.0, value_l)) * 32000),
            int(max(-1.0, min(1.0, value_r)) * 32000),
        )
    with wave.open(str(path), "wb") as out:
        out.setnchannels(2)
        out.setsampwidth(2)
        out.setframerate(RATE)
        out.writeframes(bytes(frames))


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

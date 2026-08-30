"""楽器(音色)。

これまで各パートは単一の波形をそのまま鳴らしていたため、音色が痩せていた。
複数の波形を重ね、フィルタとエンベロープを通したものを「楽器」としてまとめる。

同じ音程・長さの音は BGM 側で使い回されるので、層を増やしても
生成時間にはほとんど響かない。
"""

from __future__ import annotations

import math
from dataclasses import dataclass

from . import effects as fx
from . import envelope as env
from . import oscillators as osc
from .core import SAMPLE_RATE, fade, num_samples

VIBRATO_BLOCK = 0.005
"""ビブラートを刻む単位(秒)。この幅ごとに周波数を更新する。"""


@dataclass(frozen=True)
class Layer:
    """楽器を構成する1枚の波形。"""

    shape: str = "sine"
    ratio: float = 1.0
    """基本周波数に対する倍率。2.0 で1オクターブ上、0.5 で1オクターブ下。"""
    gain: float = 1.0
    detune: float = 0.0
    """わずかな音程のずれ(比率)。重ねるとうねりが出て音が厚くなる。"""


@dataclass(frozen=True)
class Instrument:
    """波形の重ね方・フィルタ・エンベロープをまとめたもの。"""

    layers: tuple[Layer, ...] = (Layer(),)

    # 音量エンベロープ。tau を指定すると打楽器的な指数減衰になる。
    attack: float = 0.01
    decay: float = 0.08
    sustain: float = 0.7
    release_ratio: float = 0.3
    """音長に対するリリースの比。"""
    tau: float | None = None
    """指数減衰の時定数(秒)。指定すると ADSR ではなくこちらを使う。"""

    # ローパスフィルタ。cutoff と cutoff_track の和が実際のカットオフになる。
    cutoff: float = 0.0
    cutoff_track: float = 0.0
    """基本周波数の何倍をカットオフに足すか(高い音ほどフィルタも開く)。"""
    cutoff_sweep: float = 1.0
    """出だしのカットオフ倍率。1.0 より大きいと、開いた状態から閉じていく。"""

    vibrato_rate: float = 0.0
    vibrato_depth: float = 0.0

    level: float = 1.0
    """音量の補正。楽器を差し替えても全体の音量バランスが崩れないよう、
    440Hz を 0.5 秒鳴らしたときの実効値がそろうように決めてある。"""

    RELEASE_FADE = 0.02
    """打楽器的な減衰の終わりに掛ける短いフェード(秒)。切り際のプチッを防ぐ。"""

    def _amp_envelope(self, length: float, sr: int) -> list[float]:
        if self.tau is not None:
            shape = env.percussive(length, tau=self.tau, attack=max(self.attack, 0.001), sr=sr)
            # 減衰しきる前に音を切ると段差が残るので、末尾だけ落としておく。
            return fade(shape, fade_out=min(self.RELEASE_FADE, length * 0.2), sr=sr)
        return env.adsr(
            length, self.attack, self.decay, self.sustain, length * self.release_ratio, sr
        )

    def _has_vibrato(self) -> bool:
        return self.vibrato_depth > 0.0 and self.vibrato_rate > 0.0

    def _render_layer(self, shape: str, freq: float, length: float, sr: int, amp: float) -> list[float]:
        """1枚の波形を鳴らす。ビブラートは短い区間ごとの一定周波数で近似する。

        1サンプルごとに周波数を変える書き方だと、固定周波数用の高速経路が
        使えず数倍遅くなる。5ms ごとに周波数を更新して位相をつないでいけば、
        毎秒5回程度の揺れには十分追随でき、速度も保てる。
        """
        if not self._has_vibrato():
            return osc.render(shape, freq, length, sr, amp)

        total = num_samples(length, sr)
        step = max(1, num_samples(VIBRATO_BLOCK, sr))
        out: list[float] = []
        phase = 0.0
        index = 0
        while index < total:
            count = min(step, total - index)
            centre = (index + count / 2.0) / sr
            current = freq * (1.0 + self.vibrato_depth * math.sin(2.0 * math.pi * self.vibrato_rate * centre))
            out.extend(osc.render(shape, current, count / sr, sr, amp, phase=phase))
            phase = (phase + current * count / sr) % 1.0
            index += count
        return out

    def render(self, freq: float, length: float, sr: int = SAMPLE_RATE) -> list[float]:
        """指定した高さと長さで1音鳴らす。"""
        total_gain = sum(layer.gain for layer in self.layers) or 1.0
        out: list[float] | None = None
        for layer in self.layers:
            base = freq * layer.ratio * (1.0 + layer.detune)
            buf = self._render_layer(layer.shape, base, length, sr, layer.gain / total_gain)
            out = buf if out is None else [a + b for a, b in zip(out, buf)]
        if out is None:
            return []

        cutoff = self.cutoff + self.cutoff_track * freq
        if cutoff > 0.0:
            if self.cutoff_sweep != 1.0:
                out = fx.lowpass(out, osc.sweep(cutoff * self.cutoff_sweep, cutoff, length * 0.6), sr)
            else:
                out = fx.lowpass(out, cutoff, sr)
        out = env.apply(out, self._amp_envelope(length, sr))
        if self.level != 1.0:
            out = [value * self.level for value in out]
        return out


INSTRUMENTS: dict[str, Instrument] = {
    # --- 素の波形(これまでどおりの薄い音色) ---
    "sine": Instrument((Layer("sine"),), attack=0.012, decay=0.06, sustain=0.8, level=0.67),
    "triangle": Instrument((Layer("triangle"),), attack=0.012, decay=0.06, sustain=0.8, level=0.82),
    "saw": Instrument((Layer("saw"),), attack=0.008, decay=0.08, sustain=0.7, level=0.93),
    "square": Instrument((Layer("square"),), attack=0.008, decay=0.06, sustain=0.75, level=0.51),
    "pulse25": Instrument((Layer("pulse25"),), attack=0.006, decay=0.06, sustain=0.75, level=0.88),
    "pulse12": Instrument((Layer("pulse12"),), attack=0.004, decay=0.05, sustain=0.7, level=0.98),

    # --- 重ねた音色 ---
    "pluck": Instrument(
        # 弾いた瞬間だけ明るく、すぐ落ち着く。撥弦楽器の要領。
        layers=(Layer("saw"), Layer("square", gain=0.35)),
        attack=0.002, tau=0.35,
        cutoff=180.0, cutoff_track=2.5, cutoff_sweep=7.0,
     level=2.24,),
    "pad": Instrument(
        # 少しずつ立ち上がる厚い持続音。和音の下敷き向き。
        layers=(
            Layer("saw", gain=0.5, detune=-0.004),
            Layer("saw", gain=0.5, detune=0.004),
            Layer("triangle", ratio=0.5, gain=0.45),
        ),
        attack=0.22, decay=0.35, sustain=0.78, release_ratio=0.45,
        cutoff=400.0, cutoff_track=2.0,
     level=1.71,),
    "strings": Instrument(
        layers=(
            Layer("saw", gain=0.45, detune=-0.006),
            Layer("saw", gain=0.45, detune=0.006),
            Layer("triangle", gain=0.3),
        ),
        attack=0.13, decay=0.25, sustain=0.8, release_ratio=0.4,
        cutoff=500.0, cutoff_track=2.5,
        vibrato_rate=5.2, vibrato_depth=0.006,
     level=1.58,),
    "organ": Instrument(
        # 倍音を足していく加算合成。持続音がまっすぐ伸びる。
        layers=(
            Layer("sine"),
            Layer("sine", ratio=2.0, gain=0.5),
            Layer("sine", ratio=3.0, gain=0.28),
            Layer("sine", ratio=4.0, gain=0.16),
        ),
        attack=0.02, decay=0.05, sustain=0.92, release_ratio=0.15,
     level=0.93,),
    "bell": Instrument(
        # 倍音列から外した比率を重ねると鐘や鉄琴らしくなる。
        layers=(Layer("sine"), Layer("sine", ratio=2.76, gain=0.4), Layer("sine", ratio=5.4, gain=0.18)),
        attack=0.002, tau=0.6,
     level=1.0,),
    "marimba": Instrument(
        layers=(Layer("triangle"), Layer("sine", ratio=4.0, gain=0.25)),
        attack=0.002, tau=0.18,
        cutoff=600.0, cutoff_track=3.0,
     level=1.29,),
    "chip_lead": Instrument(
        # フィルタを通さず、輪郭をそのまま残したレトロゲーム機風の音。
        layers=(Layer("pulse25"), Layer("pulse12", ratio=2.0, gain=0.22)),
        attack=0.003, decay=0.04, sustain=0.8, release_ratio=0.12,
     level=0.92,),
    "pulse_lead": Instrument(
        layers=(Layer("pulse25"), Layer("saw", gain=0.25, detune=0.004)),
        attack=0.008, decay=0.09, sustain=0.72, release_ratio=0.3,
        cutoff=800.0, cutoff_track=4.0,
     level=1.22,),
    "sub_bass": Instrument(
        layers=(Layer("sine"), Layer("triangle", gain=0.35), Layer("sine", ratio=2.0, gain=0.2)),
        attack=0.006, decay=0.1, sustain=0.8, release_ratio=0.3,
        cutoff=320.0, cutoff_track=1.0,
     level=1.15,),
    "pick_bass": Instrument(
        layers=(Layer("saw"), Layer("square", gain=0.4, ratio=0.5)),
        attack=0.004, decay=0.12, sustain=0.6, release_ratio=0.35,
        cutoff=150.0, cutoff_track=3.0, cutoff_sweep=4.0,
     level=1.05,),
}


def available() -> list[str]:
    """使える楽器名を並べる。"""
    return sorted(INSTRUMENTS)


def get(name: str) -> Instrument:
    """名前から楽器を取り出す。"""
    try:
        return INSTRUMENTS[name]
    except KeyError:
        raise ValueError(f"unknown instrument: {name!r} (available: {', '.join(available())})") from None

"""曲想・曲構成の定義。

「どんな音楽か」を決める宣言的な設定をここにまとめる。音を作る処理は持たない。
"""

from __future__ import annotations

import math
import random
from dataclasses import dataclass

from . import effects as fx

BEATS_PER_BAR = 4


@dataclass(frozen=True)
class Groove:
    """機械的に並んだ音符に「ノリ」を与えるための設定。

    完全に等間隔・等音量で並べると、正確ではあるが打ち込みらしさが強く出る。
    裏拍を少し後ろにずらし(スウィング)、拍の重さで音量を変え(アクセント)、
    ごくわずかに時間と音量を揺らす(ヒューマナイズ)ことで人が弾いた感じに近づける。
    """

    swing: float = 0.0
    """裏の8分音符を後ろへずらす量。16分音符を 1.0 とした比。0.67 で三連符のシャッフル。"""
    accent: float = 0.25
    """拍の重さによる音量差の大きさ。0 で強弱なし。"""
    humanize: float = 0.0
    """時間の揺らぎ(秒)。音量も同じ割合で揺らす。"""

    def time_offset(self, step: int, step_seconds: float, rng: random.Random) -> float:
        """16分グリッド上の ``step`` 番目の音を、何秒ずらすか。"""
        offset = 0.0
        if self.swing and step % 4 == 2:  # 各拍の裏の8分音符
            offset += self.swing * step_seconds
        if self.humanize:
            offset += rng.uniform(-self.humanize, self.humanize)
        return offset

    def velocity(self, step: int, rng: random.Random) -> float:
        """16分グリッド上の ``step`` 番目の音の音量倍率。"""
        if step % 16 == 0:
            weight = 1.0
        elif step % 8 == 0:
            weight = 0.95
        elif step % 4 == 0:
            weight = 0.85
        elif step % 2 == 0:
            weight = 0.75
        else:
            weight = 0.65
        level = 1.0 - self.accent * (1.0 - weight)
        if self.humanize:
            level *= 1.0 + rng.uniform(-self.humanize, self.humanize) * 12.0
        return max(0.0, level)


STRAIGHT = Groove()
"""ゆらぎのないグルーヴ。チップチューンなど機械的な曲想向け。"""


@dataclass(frozen=True)
class MasterEQ:
    """仕上げの帯域バランス。

    音を重ねただけでは低い方に energy が偏り、上の帯域が埋もれる。
    実測では最も強い帯域と 3k〜8k のあいだに 20dB 近い差があり、
    メロディやシンバルの輪郭が出ていなかった。

    可聴域より下を削り、溜まりやすい低中域を少し抜き、上を持ち上げる。
    """

    low_cut: float = 30.0
    """これより下は削る。聞こえないのにヘッドルームだけ食う成分。"""
    mud_range: tuple[float, float] = (200.0, 450.0)
    mud_db: float = -2.5
    """音が重なって溜まりやすい帯域を少し抜く。"""
    presence: float = 2500.0
    presence_db: float = 4.0
    """輪郭が出る帯域を持ち上げる。"""

    def apply(self, buf: list[float], sr: int) -> list[float]:
        if self.low_cut > 0.0:
            buf = fx.highpass(buf, self.low_cut, sr)
        buf = fx.band_gain(buf, self.mud_range[0], self.mud_range[1], self.mud_db, sr)
        return fx.high_shelf(buf, self.presence, self.presence_db, sr)


FLAT = MasterEQ(mud_db=0.0, presence_db=0.0)
"""何もしない EQ。素の帯域バランスを見たいとき用。"""


@dataclass(frozen=True)
class TempoCurve:
    """曲の終わりでテンポを落とす(リタルダンド)。

    一定のテンポのまま最後の和音に飛び込むと、演奏が途中で止まったように
    聞こえる。終わりにかけて緩めると「締めた」感じになる。

    音符の時刻は等速で組み立てておき、あとから時間軸を伸ばす形で実装している。
    """

    bars: float = 0.0
    """最後の何小節でテンポを緩めるか。0 でリタルダンドなし。"""
    final_ratio: float = 0.72
    """終端でのテンポ倍率。0.72 なら 1.4 倍近くまで遅くなる。"""

    def enabled(self) -> bool:
        return self.bars > 0.0 and self.final_ratio != 1.0

    def warp(self, seconds: float, total: float, bar_seconds: float) -> float:
        """等速で組み立てた時刻を、テンポを緩めたあとの時刻へ移す。

        テンポ倍率が ``speed(s)`` のとき、実際の時刻は ``∫ds/speed(s)``。
        直線的に緩める場合は対数で閉じた形になる。
        """
        if not self.enabled():
            return seconds
        ramp = min(self.bars * bar_seconds, total)
        start = total - ramp
        if seconds <= start or ramp <= 0.0:
            return seconds
        slope = (self.final_ratio - 1.0) / ramp
        elapsed = min(seconds, total) - start
        stretched = math.log1p(slope * elapsed) / slope if slope else elapsed
        # 終端を越える音(残響用の余白)は、終端の速度のまま伸ばす
        overshoot = max(0.0, seconds - total)
        return start + stretched + overshoot / self.final_ratio

    def total(self, straight_total: float, bar_seconds: float) -> float:
        """緩めたあとの曲全体の長さ。"""
        return self.warp(straight_total, straight_total, bar_seconds)


@dataclass(frozen=True)
class Style:
    """曲想ごとのパラメータ一式。"""

    scale: str = "major"
    bpm: int = 100
    progression: str = "I-V-vi-IV"
    chord_instrument: str = "pad"
    chord_seventh: bool = False
    chord_octave: int = 4
    chord_gain: float = 0.30
    chord_voice_lead: bool = True
    """和音を基本形に飛ばさず、前の和音から近い音へつなぐ。"""
    chord_pattern: str = ""
    """和音を刻む16分グリッド。空なら1小節伸ばす(従来どおり)。"""
    chord_length: float = 0.25
    """``chord_pattern`` を使うときの1音の長さ(1小節を 1.0 とした比)。"""
    bass_instrument: str = "sub_bass"
    bass_octave: int = 2
    bass_gain: float = 0.55
    bass_pattern: str = "x...x...x...x..."
    lead_instrument: str = "pulse_lead"
    lead_octave: int = 5
    lead_gain: float = 0.40
    lead_rest_prob: float = 0.22
    lead_durations: tuple[float, ...] = (0.5, 0.5, 1.0, 1.0, 2.0)
    lead_range: int = 8
    arp_instrument: str = "pluck"
    arp_pattern: str = ""
    """アルペジオを刻む16分グリッド。空ならアルペジオなし。"""
    arp_octave: int = 4
    arp_gain: float = 0.22
    arp_shape: tuple[int, ...] = (0, 1, 2, 1)
    """和音の何番目の音を順に鳴らすか。範囲を超えるとオクターブ上に回る。"""
    drum_pattern: str = "basic"
    drum_fill: str = ""
    """区間の最後の小節に入れるフィル。空ならフィルなし。"""
    drum_gain: float = 0.55
    bass_walk: bool = False
    """次の和音の根音へ、直前の音で半歩近づく(経過音)。"""
    reverb_wet: float = 0.22
    reverb_room: float = 0.7
    delay_wet: float = 0.0
    bitcrush_bits: int = 0
    groove: Groove = Groove(humanize=0.003)
    eq: MasterEQ = MasterEQ()
    parts: tuple[str, ...] = ("chords", "bass", "lead", "drums")
    """既定で鳴らすパート。設定側で明示しなければこれが使われる。"""


PART_ORDER = ("chords", "arp", "bass", "lead", "drums")


STYLES: dict[str, Style] = {
    "calm": Style(
        scale="major", bpm=76, progression="I-vi-IV-V",
        chord_instrument="pad", chord_seventh=True, chord_gain=0.34,
        bass_instrument="sub_bass", bass_pattern="x.......x.......",
        lead_instrument="bell", lead_gain=0.30, lead_rest_prob=0.35,
        lead_durations=(1.0, 2.0, 2.0, 4.0),
        drum_pattern="soft", drum_gain=0.30, reverb_wet=0.38,
        groove=Groove(accent=0.3, humanize=0.006),  # ゆったりした曲ほど揺れてよい
    ),
    "adventure": Style(
        scale="major", bpm=132, progression="I-V-vi-IV",
        chord_instrument="strings", bass_instrument="pick_bass", bass_pattern="x.x.x.x.x.x.x.x.",
        lead_instrument="pulse_lead", lead_gain=0.42, lead_rest_prob=0.15,
        lead_durations=(0.5, 0.5, 0.5, 1.0, 1.0),
        drum_pattern="drive", drum_fill="snare_roll", reverb_wet=0.20,
    ),
    "battle": Style(
        scale="harmonic_minor", bpm=158, progression="i-vi-vii-v",
        chord_instrument="strings", chord_gain=0.24, chord_octave=3,
        bass_instrument="pick_bass", bass_pattern="x.xxx.xxx.xxx.xx", bass_gain=0.6,
        lead_instrument="pulse_lead", lead_gain=0.36, lead_rest_prob=0.12,
        lead_durations=(0.25, 0.5, 0.5, 0.5, 1.0), lead_range=10,
        drum_pattern="drive", drum_fill="tom_fall", drum_gain=0.6, reverb_wet=0.16,
    ),
    "menu": Style(
        scale="pentatonic_major", bpm=96, progression="I-IV-I-V",
        chord_instrument="pluck", chord_gain=0.28,
        bass_instrument="sub_bass", bass_pattern="x...x...x...x...",
        lead_instrument="marimba", lead_gain=0.36, lead_rest_prob=0.28,
        lead_durations=(0.5, 1.0, 1.0, 2.0), lead_range=6,
        drum_pattern="soft", drum_gain=0.35, reverb_wet=0.26, delay_wet=0.18,
        groove=Groove(swing=0.2, accent=0.25, humanize=0.004),
    ),
    "night": Style(
        scale="minor", bpm=68, progression="i-VI-III-VII",
        chord_instrument="pad", chord_seventh=True, chord_gain=0.36,
        bass_instrument="sub_bass", bass_pattern="x.......x.......", bass_gain=0.5,
        lead_instrument="bell", lead_gain=0.28, lead_rest_prob=0.45,
        lead_durations=(2.0, 2.0, 4.0), lead_range=6,
        drum_pattern="none", reverb_wet=0.45, reverb_room=0.82, delay_wet=0.22,
    ),
    "chiptune": Style(
        scale="major", bpm=144, progression="I-V-vi-IV",
        chord_instrument="pulse25", chord_gain=0.24,
        bass_instrument="square", bass_pattern="x.x.x.x.x.x.x.x.", bass_gain=0.5,
        lead_instrument="chip_lead", lead_gain=0.40, lead_rest_prob=0.12,
        lead_durations=(0.25, 0.5, 0.5, 1.0),
        drum_pattern="march", drum_gain=0.45, reverb_wet=0.10, bitcrush_bits=6,
        groove=STRAIGHT,  # チップチューンは正確に並んでいるほうが らしい
        chord_voice_lead=False,  # 当時の音源は基本形で並べるのが持ち味
    ),
    "tension": Style(
        scale="phrygian", bpm=104, progression="i-ii-i-vii",
        chord_instrument="organ", chord_gain=0.22, chord_octave=3,
        bass_instrument="pick_bass", bass_pattern="x...x...x..x.x..",
        lead_instrument="strings", lead_gain=0.30, lead_rest_prob=0.4,
        lead_durations=(0.5, 1.0, 2.0), lead_range=7,
        drum_pattern="shuffle", drum_gain=0.4, reverb_wet=0.32,
        groove=Groove(swing=0.55, accent=0.3, humanize=0.005),
    ),

    # --- 放送向け ---------------------------------------------------------
    # 報道番組のテーマ。ドリアンは短調の緊張感を持ちながら暗くなりすぎない。
    # 刻んだ金管と休みなく走るアルペジオで、切迫感と前進感を作る。
    "news_open": Style(
        scale="dorian", bpm=138, progression="i-vii-i-iv",
        chord_instrument="brass", chord_octave=4, chord_gain=0.30,
        chord_pattern="x..x..x...x.x...", chord_length=0.16,
        arp_instrument="pluck", arp_pattern="oxoxoxoxoxoxoxox", arp_octave=5,
        arp_gain=0.20, arp_shape=(0, 1, 2, 3, 2, 1),
        bass_instrument="pick_bass", bass_pattern="x.x.x.x.x.x.x.x.", bass_gain=0.56,
        lead_instrument="brass", lead_octave=4, lead_gain=0.42, lead_rest_prob=0.18,
        lead_durations=(0.5, 0.5, 1.0, 1.0), lead_range=5,
        drum_pattern="news", drum_fill="timpani_roll", drum_gain=0.58, reverb_wet=0.20,
        bass_walk=True,
        groove=Groove(accent=0.32, humanize=0.002),  # 報道ものは詰めて正確に
        parts=("chords", "arp", "bass", "lead", "drums"),
    ),
    # 番組中に敷く音。話し声の帯域を空けるため、メロディを外して
    # 低い持続音と控えめな刻みだけで進む。和音も動かしすぎない。
    "news_bed": Style(
        scale="dorian", bpm=98, progression="i-i-iv-i",
        chord_instrument="pad", chord_octave=3, chord_gain=0.30, chord_seventh=True,
        arp_instrument="marimba", arp_pattern="o...o...o...o...", arp_octave=5,
        arp_gain=0.13, arp_shape=(0, 2, 1, 2),
        bass_instrument="sub_bass", bass_pattern="x.......x.......", bass_gain=0.42,
        drum_pattern="soft", drum_gain=0.24, reverb_wet=0.30,
        groove=Groove(accent=0.2, humanize=0.004),
        eq=MasterEQ(presence_db=1.5),  # 話し声の帯域を空けたいので上げすぎない
        parts=("chords", "arp", "bass", "drums"),  # メロディなし
    ),
    # 試合前後のアンセム。ゆったりした行進の足取りに、
    # 金管の和音とティンパニを重ねて格式を出す。
    "sports_anthem": Style(
        scale="major", bpm=104, progression="I-IV-V-I",
        chord_instrument="brass", chord_octave=4, chord_gain=0.34,
        chord_pattern="x.......x.......", chord_length=0.42,
        bass_instrument="low_brass", bass_pattern="x...x...x...x...", bass_gain=0.52, bass_octave=2,
        lead_instrument="brass", lead_octave=4, lead_gain=0.44, lead_rest_prob=0.24,
        lead_durations=(0.5, 1.0, 1.0, 2.0), lead_range=5,
        drum_pattern="anthem", drum_fill="timpani_roll", drum_gain=0.60,
        reverb_wet=0.34, reverb_room=0.80, bass_walk=True,
        groove=Groove(accent=0.35, humanize=0.005),
    ),
    # ハイライトや煽り。ミクソリディアンの VII が明るいまま勢いを出す。
    "sports_drive": Style(
        scale="mixolydian", bpm=152, progression="I-vii-IV-I",
        chord_instrument="brass", chord_octave=4, chord_gain=0.28,
        chord_pattern="x.xx..x.x.xx..x.", chord_length=0.12,
        arp_instrument="pluck", arp_pattern="..x...x...x...x.", arp_octave=5,
        arp_gain=0.18, arp_shape=(2, 1, 0, 1),
        bass_instrument="pick_bass", bass_pattern="x.xxx.xxx.xxx.xx", bass_gain=0.58,
        lead_instrument="brass", lead_octave=4, lead_gain=0.40, lead_rest_prob=0.15,
        lead_durations=(0.25, 0.5, 0.5, 1.0), lead_range=6,
        drum_pattern="sports", drum_fill="tom_fall", drum_gain=0.62, reverb_wet=0.16,
        bass_walk=True,
        groove=Groove(accent=0.3, humanize=0.003),
        parts=("chords", "arp", "bass", "lead", "drums"),
    ),
}


@dataclass(frozen=True)
class Section:
    """曲の一区切り。どのパートを鳴らすか、どのくらいの長さかを持つ。"""

    name: str
    weight: float
    """曲全体の小節数に対する比。"""
    drop: tuple[str, ...] = ()
    """この区間で鳴らさないパート。"""
    gain: float = 1.0
    lead_octave: int = 0
    """メロディのオクターブ移動。サビを1つ上げる、といった使い方をする。"""
    transpose: int = 0
    """区間まるごとの移調(半音)。サビで全体を持ち上げる定番の手。"""


STRUCTURES: dict[str, tuple[Section, ...]] = {
    # 8小節をそのまま繰り返す、いちばん素直な構成。
    "loop": (Section("main", 1.0),),
    # 静かに入って本編へ。
    "intro": (
        Section("intro", 0.25, drop=("drums", "lead"), gain=0.75),
        Section("main", 0.75),
    ),
    # A メロ → サビ。サビでメロディが1オクターブ上がる。
    "verse_chorus": (
        Section("verse", 0.5, gain=0.85),
        Section("chorus", 0.5, gain=1.0, lead_octave=1),
    ),
    # A メロ → サビ。サビで全体が全音上がる(転調による持ち上げ)。
    "lift": (
        Section("verse", 0.5, gain=0.85),
        Section("chorus", 0.5, gain=1.0, lead_octave=1, transpose=2),
    ),
    # 放送向けの4部構成。サビで転調し、最後は静かに引く。
    "broadcast": (
        Section("intro", 0.2, drop=("drums", "lead"), gain=0.72),
        Section("verse", 0.3, gain=0.85),
        Section("chorus", 0.35, gain=1.0, lead_octave=1, transpose=2),
        Section("outro", 0.15, drop=("lead",), gain=0.7, transpose=2),
    ),
    # イントロ・A メロ・サビ・アウトロの4部構成。
    "full": (
        Section("intro", 0.15, drop=("drums", "lead"), gain=0.7),
        Section("verse", 0.35, gain=0.85),
        Section("chorus", 0.35, gain=1.0, lead_octave=1),
        Section("outro", 0.15, drop=("drums",), gain=0.65),
    ),
}


def structure_names() -> list[str]:
    """使える曲構成の名前を並べる。"""
    return sorted(STRUCTURES)


def plan_sections(structure: str, bars: int) -> list[tuple[Section, int, int]]:
    """構成と総小節数から ``(区間, 開始小節, 小節数)`` の並びを組み立てる。

    比率で割り振ったうえで、どの区間も最低1小節を確保し、
    端数は最後の区間で吸収して合計をぴったり ``bars`` に合わせる。
    """
    try:
        sections = STRUCTURES[structure]
    except KeyError:
        raise ValueError(
            f"unknown structure: {structure!r} (available: {', '.join(structure_names())})"
        ) from None
    if bars < 1:
        raise ValueError("bars must be >= 1")

    if bars < len(sections):  # 小節が足りないときは前半の区間だけ使う
        sections = sections[:bars]

    counts = [max(1, round(section.weight * bars)) for section in sections]
    while sum(counts) > bars:  # 丸めで溢れたぶんは長い区間から削る
        counts[counts.index(max(counts))] -= 1
    counts[-1] += bars - sum(counts)

    plan: list[tuple[Section, int, int]] = []
    start = 0
    for section, count in zip(sections, counts):
        plan.append((section, start, count))
        start += count
    return plan


def style_names() -> list[str]:
    """使える BGM スタイル名を並べる。"""
    return sorted(STYLES)


# --- パート生成 ---------------------------------------------------------------

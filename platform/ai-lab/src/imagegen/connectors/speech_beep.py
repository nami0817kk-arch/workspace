"""APIキーもENGINEも要らないプレースホルダ音声（標準ライブラリだけで作る）。

読み上げの代わりに「先頭の短いビープ＋文字数から決まる長さの無音」を返す。
声そのものは作れないが、**尺が本物とほぼ同じ WAV** が手に入るので、
動画の並べ方や字幕のタイミングを、TTS を1回も呼ばずに確かめられる。

- 無音ではなくビープを鳴らすのは、プレースホルダのまま公開してしまわないため。
- 同じ文章からは常に同じ WAV が出る（再現性）。
- 読み上げ速度は IMAGEGEN_BEEP_CPS（1秒あたりの文字数、既定7.0）で調整する。
"""

from __future__ import annotations

import io
import math
import struct
import wave

from ..config import get_env
from ..core.connector import AuthSpec, CheckResult, Connector
from ..core.registry import register
from ..core.types import SynthesizedSpeech, Voice

SAMPLE_RATE = 24_000
#: 1秒あたりの文字数（日本語のナレーションのおおよその速さ）
DEFAULT_CHARS_PER_SECOND = 7.0
BEEP_SECONDS = 0.12
MIN_SECONDS = 0.6

#: 声ごとにビープの高さを変える（どれを指定したか耳で分かるように）
TONES = {"low": 440.0, "mid": 660.0, "high": 880.0}


def chars_per_second() -> float:
    try:
        value = float(get_env("IMAGEGEN_BEEP_CPS") or DEFAULT_CHARS_PER_SECOND)
    except ValueError:
        return DEFAULT_CHARS_PER_SECOND
    return value if value > 0 else DEFAULT_CHARS_PER_SECOND


def estimate_seconds(text: str, speed: float = 1.0) -> float:
    """文字数と読み上げ速度から尺を見積もる。"""
    speed = speed if speed > 0 else 1.0
    return max(MIN_SECONDS, len(text) / chars_per_second() / speed)


def render_wav(seconds: float, frequency: float) -> bytes:
    """先頭にビープを置いた WAV（16bit モノラル）を作る。"""
    total = int(SAMPLE_RATE * seconds)
    beep = min(int(SAMPLE_RATE * BEEP_SECONDS), total)
    frames = bytearray()
    for index in range(total):
        if index < beep:
            # 端でプチッと鳴らないよう、両端を絞る
            envelope = min(1.0, min(index, beep - index) / (SAMPLE_RATE * 0.01))
            value = math.sin(2 * math.pi * frequency * index / SAMPLE_RATE) * 0.25 * envelope
        else:
            value = 0.0
        frames += struct.pack("<h", int(value * 32767))

    buffer = io.BytesIO()
    with wave.open(buffer, "wb") as writer:
        writer.setnchannels(1)
        writer.setsampwidth(2)
        writer.setframerate(SAMPLE_RATE)
        writer.writeframes(bytes(frames))
    return buffer.getvalue()


@register
class BeepSpeech(Connector):
    name = "beep"
    category = "speech"
    summary = "APIキー不要のプレースホルダ音声（尺だけ本物に合わせた無音＋ビープ）"
    auth = AuthSpec()
    default_model = "placeholder-v1"
    default_voice = "mid"
    priority = 90

    def list_voices(self) -> list[Voice]:
        return [
            Voice(id=name, name=f"{name}（{int(hz)}Hz のビープ）", provider=self.name)
            for name, hz in TONES.items()
        ]

    def check(self) -> CheckResult:
        return CheckResult(self.name, ok=True, detail="プレースホルダ音声が使えます")

    def synthesize(
        self,
        text: str,
        *,
        voice: str | None = None,
        model: str | None = None,
        speed: float = 1.0,
        fmt: str | None = None,
        timeout: int = 0,
    ) -> SynthesizedSpeech:
        tone = (voice or self.default_voice).lower()
        seconds = estimate_seconds(text, speed)
        return SynthesizedSpeech(
            data=render_wav(seconds, TONES.get(tone, TONES["mid"])),
            mime="audio/wav",
            provider=self.name,
            model=model or self.default_model,
            voice=tone,
            text=text,
            meta={"placeholder": True, "seconds": round(seconds, 3)},
        )

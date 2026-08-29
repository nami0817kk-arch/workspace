"""VOICEVOX ENGINE で各セリフを音声化する。

ENGINE はローカルで起動しておく必要がある（既定 http://127.0.0.1:50021）。
起動していない環境でも動画の尺確認ができるよう、無音で代替するモードを持つ。
"""

from __future__ import annotations

import hashlib
import io
import wave
from pathlib import Path

import requests

from .config import CastMember, ProjectConfig
from .script_model import Line, Script

# 無音フォールバック時の wav フォーマット（VOICEVOX の既定に合わせる）
SILENT_PARAMS = (1, 2, 24000)  # channels, sampwidth, framerate


class TtsError(RuntimeError):
    pass


class VoicevoxClient:
    def __init__(self, url: str, timeout: int = 60):
        self.url = url.rstrip("/")
        self.timeout = timeout

    def available(self) -> bool:
        try:
            requests.get(f"{self.url}/version", timeout=3).raise_for_status()
            return True
        except requests.RequestException:
            return False

    def speakers(self) -> list[dict]:
        """ENGINE が持つ話者とスタイル ID の一覧。"""
        response = requests.get(f"{self.url}/speakers", timeout=self.timeout)
        response.raise_for_status()
        return response.json()

    def synthesize(self, text: str, member: CastMember, speed: float | None = None) -> bytes:
        """1行ぶんの wav バイト列を返す。"""
        try:
            query = requests.post(
                f"{self.url}/audio_query",
                params={"text": text, "speaker": member.style_id},
                timeout=self.timeout,
            )
            query.raise_for_status()
            params = query.json()
            params["speedScale"] = speed if speed is not None else member.speed
            params["pitchScale"] = member.pitch
            params["intonationScale"] = member.intonation

            audio = requests.post(
                f"{self.url}/synthesis",
                params={"speaker": member.style_id},
                json=params,
                timeout=self.timeout,
            )
            audio.raise_for_status()
            return audio.content
        except requests.RequestException as exc:
            raise TtsError(
                f"VOICEVOX への合成リクエストが失敗しました（{self.url}）: {exc}"
            ) from exc


def synthesize_script(
    script: Script,
    config: ProjectConfig,
    out_dir: Path,
    use_tts: bool = True,
) -> bool:
    """台本の全行を音声化し、各 Line に audio_path / duration / start を埋める。

    戻り値は実際に VOICEVOX を使えたかどうか。使えなければ無音で埋める。
    """
    out_dir.mkdir(parents=True, exist_ok=True)
    client = VoicevoxClient(config.voicevox.url, config.voicevox.timeout)
    engine_ready = use_tts and client.available()

    cursor = 0.0
    for index, line in enumerate(script.lines):
        member = config.resolve_speaker(line.speaker)
        pause = config.voicevox.pause if line.pause is None else line.pause
        target = out_dir / f"{index:04d}_{member.key}_{_digest(line, member, pause)}.wav"

        if not target.exists():
            if engine_ready:
                raw = client.synthesize(line.text, member, line.speed)
                _write_padded(raw, pause, target)
            else:
                _write_silence(line.estimated_duration() + pause, target)

        line.audio_path = target
        line.pause = pause  # 描画側が末尾の無音を口パクから外すために使う
        line.duration = wav_duration(target)
        line.start = cursor
        cursor += line.duration

    return engine_ready


def wav_duration(path: Path) -> float:
    with wave.open(str(path), "rb") as handle:
        return handle.getnframes() / float(handle.getframerate())


def _write_padded(raw: bytes, pause: float, target: Path) -> None:
    """合成結果の後ろに無音を足して保存する（行間の“間”）。"""
    with wave.open(io.BytesIO(raw), "rb") as source:
        channels, sampwidth, framerate = (
            source.getnchannels(),
            source.getsampwidth(),
            source.getframerate(),
        )
        frames = source.readframes(source.getnframes())
    silence = b"\x00" * int(framerate * max(0.0, pause)) * channels * sampwidth
    _write_wav(target, channels, sampwidth, framerate, frames + silence)


def _write_silence(seconds: float, target: Path) -> None:
    channels, sampwidth, framerate = SILENT_PARAMS
    frames = b"\x00" * int(framerate * max(0.0, seconds)) * channels * sampwidth
    _write_wav(target, channels, sampwidth, framerate, frames)


def _write_wav(target: Path, channels: int, sampwidth: int, framerate: int, frames: bytes) -> None:
    with wave.open(str(target), "wb") as out:
        out.setnchannels(channels)
        out.setsampwidth(sampwidth)
        out.setframerate(framerate)
        out.writeframes(frames)


def _digest(line: Line, member: CastMember, pause: float) -> str:
    """同じ条件なら再合成しないためのキャッシュキー。"""
    seed = f"{line.text}|{member.style_id}|{line.speed or member.speed}|{member.pitch}|{member.intonation}|{pause}"
    return hashlib.sha1(seed.encode("utf-8")).hexdigest()[:8]

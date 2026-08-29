"""タイトルカードのぶんだけ、映像と音声に時間を差し込む。

冒頭のタイトルと章タイトルは音声がないので、そのぶん無音を入れて尺を合わせる。
ここで各セリフの開始時刻を計算し直すため、字幕とチャプターの時刻も自動で追従する。
"""

from __future__ import annotations

import wave
from dataclasses import dataclass, field
from pathlib import Path

from .config import ProjectConfig
from .script_model import Script


@dataclass
class Inserts:
    intro: float = 0.0                            # 冒頭タイトルの秒数
    chapters: dict[int, float] = field(default_factory=dict)  # シーン番号 -> 秒数

    def before_scene(self, index: int) -> float:
        return self.chapters.get(index, 0.0)

    @property
    def total(self) -> float:
        return self.intro + sum(self.chapters.values())


def plan(script: Script, config: ProjectConfig) -> Inserts:
    """どこに何秒差し込むかを決める。

    冒頭はタイトル、以降の章の頭には章タイトル。最初の章はタイトル直後なので入れない。
    """
    titles = config.titles
    inserts = Inserts(intro=max(0.0, titles.intro))
    if titles.chapter > 0:
        start = 1 if inserts.intro > 0 else 0
        for index in range(start, len(script.scenes)):
            inserts.chapters[index] = titles.chapter
    return inserts


def apply_timing(script: Script, inserts: Inserts) -> None:
    """差し込みを織り込んで、各セリフの開始時刻を振り直す。"""
    cursor = inserts.intro
    for index, scene in enumerate(script.scenes):
        cursor += inserts.before_scene(index)
        for line in scene.lines:
            line.start = cursor
            cursor += line.duration


def audio_segments(script: Script, inserts: Inserts) -> list[tuple[Path | None, float]]:
    """音声をつなぐ順番。パスが None のところは無音を入れる。"""
    segments: list[tuple[Path | None, float]] = []
    if inserts.intro > 0:
        segments.append((None, inserts.intro))
    for index, scene in enumerate(script.scenes):
        gap = inserts.before_scene(index)
        if gap > 0:
            segments.append((None, gap))
        for line in scene.lines:
            if line.audio_path:
                segments.append((line.audio_path, line.duration))
    return segments


def realize_audio(
    segments: list[tuple[Path | None, float]], work_dir: Path
) -> list[Path]:
    """無音の箇所を実ファイルにして、つなげられる並びにする。

    無音のフォーマットは、実際のセリフの wav に合わせる（そろっていないと結合できない）。
    """
    params = _params_of(segments)
    work_dir.mkdir(parents=True, exist_ok=True)

    paths: list[Path] = []
    for number, (path, seconds) in enumerate(segments):
        if path is not None:
            paths.append(path)
            continue
        silence = work_dir / f"gap_{number:03d}_{int(seconds * 1000)}.wav"
        if not silence.exists():
            _write_silence(silence, seconds, params)
        paths.append(silence)
    return paths


def _params_of(segments: list[tuple[Path | None, float]]) -> tuple[int, int, int]:
    for path, _ in segments:
        if path is None:
            continue
        with wave.open(str(path), "rb") as handle:
            return (handle.getnchannels(), handle.getsampwidth(), handle.getframerate())
    return (1, 2, 24000)


def _write_silence(path: Path, seconds: float, params: tuple[int, int, int]) -> None:
    channels, sampwidth, framerate = params
    frames = b"\x00" * int(framerate * max(0.0, seconds)) * channels * sampwidth
    with wave.open(str(path), "wb") as out:
        out.setnchannels(channels)
        out.setsampwidth(sampwidth)
        out.setframerate(framerate)
        out.writeframes(frames)

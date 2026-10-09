"""タイトルカードのぶんだけ、映像と音声に時間を差し込む。

冒頭のタイトルと章タイトルは音声がないので、そのぶん無音を入れて尺を合わせる。
ここで各セリフの開始時刻を計算し直すため、字幕とチャプターの時刻も自動で追従する。
"""

from __future__ import annotations

import os
import wave
from dataclasses import dataclass, field
from pathlib import Path

from .config import ProjectConfig
from .script_model import Script


@dataclass
class Inserts:
    intro: float = 0.0                            # 冒頭タイトルの秒数
    outro: float = 0.0                            # 末尾のカードの秒数
    chapters: dict[int, float] = field(default_factory=dict)  # シーン番号 -> 秒数

    def before_scene(self, index: int) -> float:
        return self.chapters.get(index, 0.0)

    @property
    def total(self) -> float:
        return self.intro + self.outro + sum(self.chapters.values())


def plan(script: Script, config: ProjectConfig) -> Inserts:
    """どこに何秒差し込むかを決める。

    冒頭はタイトル、以降の章の頭には章タイトル。最初の章はタイトル直後なので入れない。
    """
    titles = config.titles
    # 台本が最後のカードを頼んでいれば、その秒数（ショートの続き物の回。shorts.SERIES_END_CARD）
    end_card = float((getattr(script, "meta", None) or {}).get("end_card") or 0.0)
    inserts = Inserts(intro=max(0.0, titles.intro), outro=max(0.0, titles.outro, end_card))
    if titles.chapter > 0:
        # **最初の章にはカードを入れない。**冒頭タイトルの有無に関係なく入れない。
        # 以前は「冒頭タイトルがあるときだけ飛ばす」だったため、冒頭タイトルを 0 に
        # した瞬間、代わりに章タイトル（「オープニング 1/6」）が1.4秒出るようになった
        # （2026-09-07、書き出して初めて気づいた）。**0秒目から本編を始める**のが狙いで、
        # 静止したカードの種類を入れ替えても意味がない。
        for index in range(1, len(script.scenes)):
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
    if inserts.outro > 0:
        segments.append((None, inserts.outro))
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
        if not _silence_ready(silence, seconds, params):
            _write_silence(silence, seconds, params)
        paths.append(silence)
    return paths


def _silence_ready(path: Path, seconds: float, params: tuple[int, int, int]) -> bool:
    """**中身まで見てから使い回す**（2026-10-10）。

    前は `path.exists()` だけだった。work_dir は失敗した書き出しのあと残るので、
    **途中まで書かれた無音**（ディスクが埋まった・途中で止めた）がそのまま
    次の回で使われる。ffmpeg は**ヘッダではなく実際のバイト数**で尺を決めるので、
    15秒のつもりの無音が 0.4秒になっても**警告もエラーも出ない**。
    その結果、音が14秒短くなり、`-shortest` で動画の末尾（終了画面の置き場）が
    黙って切られていた。
    """
    try:
        if not path.exists():
            return False
        with wave.open(str(path), "rb") as handle:
            if (handle.getnchannels(), handle.getsampwidth(), handle.getframerate()) != params:
                return False
            frames = handle.getnframes()
        if frames != _silence_frames(seconds, params):
            return False
        channels, sampwidth, _ = params
        # ヘッダが正しくても、バイトが足りていなければ尺は足りない
        return path.stat().st_size >= frames * channels * sampwidth
    except (wave.Error, OSError, EOFError):
        return False


def _silence_frames(seconds: float, params: tuple[int, int, int]) -> int:
    _, _, framerate = params
    return int(framerate * max(0.0, seconds))


def _params_of(segments: list[tuple[Path | None, float]]) -> tuple[int, int, int]:
    for path, _ in segments:
        if path is None:
            continue
        with wave.open(str(path), "rb") as handle:
            return (handle.getnchannels(), handle.getsampwidth(), handle.getframerate())
    return (1, 2, 24000)


def _write_silence(path: Path, seconds: float, params: tuple[int, int, int]) -> None:
    """無音を1つ書く。**書きかけを残さない**（2026-10-10）。

    別名に書いてから置き換える（`render._write_image` と同じ）。途中で落ちても
    `path` は出来ないので、次の回が**半分の無音**を拾うことがない。
    """
    channels, sampwidth, framerate = params
    frames = b"\x00" * (_silence_frames(seconds, params) * channels * sampwidth)
    tmp = path.with_name(f"{path.name}.{os.getpid()}.part")
    try:
        with wave.open(str(tmp), "wb") as out:
            out.setnchannels(channels)
            out.setsampwidth(sampwidth)
            out.setframerate(framerate)
            out.writeframes(frames)
        os.replace(tmp, path)
    finally:
        if tmp.exists():
            tmp.unlink(missing_ok=True)

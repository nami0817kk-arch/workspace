"""ffmpeg の場所を決めて実行する。

ffmpeg は pip の依存ではなく外部の実行ファイルなので、探し方と
「無いときに何をすればいいか」をここ1箇所に集める。

探す順番:
1. 環境変数 `VIDEOGEN_FFMPEG`（明示指定）
2. PATH 上の ffmpeg
3. imageio-ffmpeg が同梱しているもの（`pip install -e ".[video]"`）
"""

from __future__ import annotations

import re
import shutil
import subprocess
import wave
from pathlib import Path

from .errors import FfmpegMissingError, VideogenError

#: ffmpeg の場所を明示する環境変数
ENV_NAME = "VIDEOGEN_FFMPEG"

#: 実行結果の読み方。ロケール（Windows なら cp932）で読むと、エラー文の中身に
#: よっては読み取り自体が落ちて、本当の失敗理由が見えなくなる。
CAPTURE = {"capture_output": True, "text": True, "encoding": "utf-8", "errors": "replace"}

DURATION_RE = re.compile(r"Duration:\s*(\d+):(\d\d):(\d\d(?:\.\d+)?)")


def find_ffmpeg() -> str:
    """使う ffmpeg のパスを返す。見つからなければ FfmpegMissingError。"""
    import os

    explicit = (os.environ.get(ENV_NAME) or "").strip()
    if explicit:
        if not (Path(explicit).is_file() or shutil.which(explicit)):
            raise FfmpegMissingError(f"{ENV_NAME} に指定された ffmpeg が見つかりません: {explicit}")
        return explicit

    found = shutil.which("ffmpeg")
    if found:
        return found

    try:
        import imageio_ffmpeg
    except ImportError:
        raise FfmpegMissingError(
            "ffmpeg が見つかりません。次のどれかで用意してください:\n"
            '  pip install -e ".[video]"   （imageio-ffmpeg を入れる。追加の設定は不要）\n'
            "  ffmpeg をインストールして PATH に通す\n"
            f"  {ENV_NAME}=/path/to/ffmpeg を .env に書く"
        ) from None
    return imageio_ffmpeg.get_ffmpeg_exe()


def is_available() -> bool:
    try:
        find_ffmpeg()
    except FfmpegMissingError:
        return False
    return True


def version() -> str:
    """ffmpeg のバージョン行（1行目）。"""
    result = subprocess.run([find_ffmpeg(), "-version"], **CAPTURE)
    first = (result.stdout or "").splitlines()
    return first[0] if first else "不明"


def run(args: list[str], *, quiet: bool = True) -> str:
    """ffmpeg を1回実行する。失敗したら stderr の末尾を添えて例外にする。"""
    command = [find_ffmpeg(), "-y"]
    if quiet:
        command += ["-loglevel", "error"]
    command += args
    result = subprocess.run(command, **CAPTURE)
    if result.returncode != 0:
        tail = "\n".join((result.stderr or "").strip().splitlines()[-15:])
        raise VideogenError(f"ffmpeg が失敗しました（exit {result.returncode}）:\n{tail}")
    return result.stderr or ""


def parse_duration(output: str) -> float | None:
    """ffmpeg の出力から Duration を秒で読む。"""
    match = DURATION_RE.search(output or "")
    if not match:
        return None
    hours, minutes, seconds = match.groups()
    return int(hours) * 3600 + int(minutes) * 60 + float(seconds)


def wav_seconds(path: str | Path) -> float | None:
    """WAV の長さを標準ライブラリだけで測る（ffmpeg を呼ばずに済ませる）。"""
    try:
        with wave.open(str(path)) as reader:
            return reader.getnframes() / float(reader.getframerate() or 1)
    except (wave.Error, OSError, EOFError, ValueError):
        return None


def probe_seconds(path: str | Path) -> float:
    """メディアファイルの長さ（秒）。

    WAV は標準ライブラリで測る。それ以外は ffmpeg に読ませる
    （ffprobe は imageio-ffmpeg に入っていないので使わない）。
    """
    target = Path(path)
    if not target.is_file():
        raise VideogenError(f"ファイルがありません: {target}")

    if target.suffix.lower() == ".wav":
        seconds = wav_seconds(target)
        if seconds is not None:
            return seconds

    result = subprocess.run([find_ffmpeg(), "-hide_banner", "-i", str(target)], **CAPTURE)
    seconds = parse_duration(result.stderr or "")
    if seconds is None:
        raise VideogenError(f"長さを読み取れませんでした: {target}")
    return seconds

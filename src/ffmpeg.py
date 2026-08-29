"""ffmpeg の実行まわり。バイナリはシステム優先、無ければ imageio-ffmpeg 同梱を使う。"""

from __future__ import annotations

import shutil
import subprocess
from pathlib import Path


class FfmpegError(RuntimeError):
    pass


def ffmpeg_exe() -> str:
    system = shutil.which("ffmpeg")
    if system:
        return system
    try:
        import imageio_ffmpeg
    except ImportError as exc:  # pragma: no cover - 依存が入っていれば通らない
        raise FfmpegError(
            "ffmpeg が見つかりません。`pip install imageio-ffmpeg` を実行してください。"
        ) from exc
    return imageio_ffmpeg.get_ffmpeg_exe()


def run(args: list[str], quiet: bool = True) -> None:
    """ffmpeg を1回実行する。失敗したら stderr 末尾を添えて例外にする。"""
    command = [ffmpeg_exe(), "-y"]
    if quiet:
        command += ["-loglevel", "error"]
    command += args
    result = subprocess.run(command, capture_output=True, text=True)
    if result.returncode != 0:
        tail = "\n".join(result.stderr.strip().splitlines()[-15:])
        raise FfmpegError(f"ffmpeg が失敗しました（exit {result.returncode}）:\n{tail}")


def write_concat_list(entries: list[tuple[Path, float]], list_path: Path) -> Path:
    """concat demuxer 用のリストを書き出す。

    entries は (ファイル, 表示秒数) の並び。静止画を並べて可変長の動画にするために使う。
    最後の1枚は duration 無しでもう一度書くのが concat demuxer の作法。
    """
    if not entries:
        raise FfmpegError("concat する要素がありません")
    lines = []
    for path, duration in entries:
        lines.append(f"file '{path.resolve().as_posix()}'")
        lines.append(f"duration {duration:.3f}")
    lines.append(f"file '{entries[-1][0].resolve().as_posix()}'")
    list_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return list_path


def concat_audio(paths: list[Path], out_path: Path, work_dir: Path) -> Path:
    """同じフォーマットの wav を順につないで1本にする。"""
    list_path = work_dir / "audio_concat.txt"
    list_path.write_text(
        "\n".join(f"file '{p.resolve().as_posix()}'" for p in paths) + "\n",
        encoding="utf-8",
    )
    run(["-f", "concat", "-safe", "0", "-i", str(list_path), "-c", "copy", str(out_path)])
    return out_path


def encode_video(
    frame_list: Path,
    audio_path: Path | None,
    out_path: Path,
    fps: int = 30,
) -> Path:
    """静止画リスト（+音声）を YouTube 向けの MP4 にエンコードする。"""
    args = ["-f", "concat", "-safe", "0", "-i", str(frame_list)]
    if audio_path is not None:
        args += ["-i", str(audio_path)]
    args += [
        "-map", "0:v",
        *(["-map", "1:a"] if audio_path is not None else []),
        "-c:v", "libx264",
        "-preset", "medium",
        "-crf", "20",
        "-pix_fmt", "yuv420p",
        "-r", str(fps),
        "-fps_mode", "cfr",
        "-movflags", "+faststart",
    ]
    if audio_path is not None:
        args += ["-c:a", "aac", "-b:a", "192k", "-ar", "48000", "-shortest"]
    args.append(str(out_path))
    run(args)
    return out_path

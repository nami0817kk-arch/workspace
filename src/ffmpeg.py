"""ffmpeg の実行まわり。バイナリはシステム優先、無ければ imageio-ffmpeg 同梱を使う。"""

from __future__ import annotations

import shutil
import subprocess
from pathlib import Path


VIDEO_SUFFIXES = {".mp4", ".mov", ".webm", ".mkv", ".m4v"}


class FfmpegError(RuntimeError):
    pass


def is_video(name: str | Path | None) -> bool:
    return bool(name) and Path(name).suffix.lower() in VIDEO_SUFFIXES


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


def max_volume(path: Path) -> float:
    """ファイルのピーク音量(dB)。完全な無音なら -inf を返す。"""
    result = subprocess.run(
        [ffmpeg_exe(), "-nostats", "-i", str(path), "-af", "volumedetect", "-f", "null", "-"],
        capture_output=True,
        text=True,
    )
    for line in result.stderr.splitlines():
        if "max_volume:" in line:
            try:
                return float(line.split("max_volume:")[1].strip().split()[0])
            except (IndexError, ValueError):
                break
    return float("-inf")


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


def build_background_track(
    segments: list[tuple[Path, float]],
    out_path: Path,
    size: tuple[int, int],
    fps: int = 30,
) -> Path:
    """シーンごとの背景（静止画でも動画でもよい）を、指定の秒数ずつつないだ1本の動画にする。

    静止画はその秒数だけ止め、動画は足りなければループさせる。どちらも画面いっぱいに
    拡大して中央を切り出すので、素材の比率が違っても混ぜられる。
    """
    if not segments:
        raise FfmpegError("背景トラックの素材がありません")
    width, height = size

    args: list[str] = []
    for path, duration in segments:
        if is_video(path):
            args += ["-stream_loop", "-1", "-t", f"{duration:.3f}", "-i", str(path)]
        else:
            args += ["-loop", "1", "-t", f"{duration:.3f}", "-i", str(path)]

    chains = [
        f"[{index}:v]scale={width}:{height}:force_original_aspect_ratio=increase,"
        f"crop={width}:{height},setsar=1,fps={fps},"
        f"trim=duration={duration:.3f},setpts=PTS-STARTPTS[b{index}]"
        for index, (_, duration) in enumerate(segments)
    ]
    chains.append(
        "".join(f"[b{i}]" for i in range(len(segments)))
        + f"concat=n={len(segments)}:v=1:a=0[bg]"
    )
    args += [
        "-filter_complex", ";".join(chains),
        "-map", "[bg]",
        "-c:v", "libx264", "-preset", "veryfast", "-crf", "18",
        "-pix_fmt", "yuv420p",
        str(out_path),
    ]
    run(args)
    return out_path


def still_to_clip(
    image: Path,
    out_path: Path,
    seconds: float = 10.0,
    size: tuple[int, int] = (1920, 1080),
    zoom: float = 1.18,
    fps: int = 30,
) -> Path:
    """静止画から、ゆっくり寄っていく背景クリップを作る。

    フリー素材の写真1枚でも、止まった絵より動画らしくなる。
    """
    width, height = size
    frames = max(1, int(seconds * fps))
    step = (zoom - 1.0) / frames
    run([
        "-loop", "1", "-i", str(image), "-t", f"{seconds:.2f}",
        "-vf",
        f"zoompan=z='min(zoom+{step:.6f},{zoom})':d={frames}"
        f":x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':s={width}x{height}:fps={fps},"
        "format=yuv420p",
        "-c:v", "libx264", "-preset", "medium", "-crf", "22",
        str(out_path),
    ])
    return out_path


def grab_frame(clip: Path, out_path: Path, at: float = 1.0) -> Path:
    """動画から静止画を1枚取り出す。サムネイルの下地に使う。"""
    run(["-ss", f"{at:.2f}", "-i", str(clip), "-frames:v", "1", str(out_path)])
    return out_path


def encode_video_over_clip(
    frame_list: Path,
    clip: Path,
    audio_path: Path | None,
    out_path: Path,
    size: tuple[int, int],
    fps: int = 30,
) -> Path:
    """背景動画の上に、透過PNGのフレーム列を重ねて書き出す。

    背景クリップは尺に足りなければループし、画面いっぱいになるよう拡大して中央を切り出す。
    """
    width, height = size
    args = [
        "-stream_loop", "-1", "-i", str(clip),
        "-f", "concat", "-safe", "0", "-i", str(frame_list),
    ]
    if audio_path is not None:
        args += ["-i", str(audio_path)]

    chains = [
        f"[0:v]scale={width}:{height}:force_original_aspect_ratio=increase,"
        f"crop={width}:{height},setsar=1,fps={fps}[bg]",
        f"[1:v]format=rgba,fps={fps},setsar=1[fg]",
        "[bg][fg]overlay=shortest=1:format=auto[v]",
    ]
    args += [
        "-filter_complex", ";".join(chains),
        "-map", "[v]",
        *(["-map", "2:a"] if audio_path is not None else []),
        "-c:v", "libx264",
        "-preset", "medium",
        "-crf", "20",
        "-pix_fmt", "yuv420p",
        "-r", str(fps),
        "-movflags", "+faststart",
    ]
    if audio_path is not None:
        args += ["-c:a", "aac", "-b:a", "192k", "-ar", "48000", "-shortest"]
    args.append(str(out_path))
    run(args)
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

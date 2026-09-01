"""タイムライン → ffmpeg のコマンド → 動画。

**組み立てと実行を分けてある。** 組み立て（build_command）は純粋な関数なので、
ffmpeg が入っていない環境でも中身をテストできる。実行するのは render だけ。
`--dry-run` で、実行せずに組み上がったコマンドを見られる。
"""

from __future__ import annotations

from collections.abc import Callable
from dataclasses import dataclass, field
from pathlib import Path

from . import ffmpeg as ffmpeg_module
from . import filters, subtitles
from .errors import TimelineError
from .timeline import Timeline

#: 出力の既定（YouTube にそのまま上げられる形）
VIDEO_ARGS = ["-c:v", "libx264", "-preset", "medium", "-crf", "20", "-pix_fmt", "yuv420p"]
AUDIO_ARGS = ["-c:a", "aac", "-b:a", "192k"]


@dataclass
class RenderResult:
    output: Path
    seconds: float
    scenes: int
    command: list[str] = field(default_factory=list)
    srt: Path | None = None
    dry_run: bool = False

    def describe(self) -> str:
        head = "[ドライラン] " if self.dry_run else ""
        return f"{head}{self.output}（{self.seconds:.1f}秒 / {self.scenes}シーン）"


def image_input(motion: str, *, seconds: float, fps: int) -> list[str]:
    """1シーンぶんの画像入力の指定。

    **動かすシーンでは画像をループさせない。** zoompan の `d` は
    「入力1フレームあたりに作る出力フレーム数」なので、ループで入力を
    増やすと掛け算になり、5秒のつもりが数百秒の動画になる（実際になった）。
    動かすときは静止画を1フレームだけ渡し、尺は zoompan に作らせる。
    """
    if motion == "none":
        return ["-loop", "1", "-framerate", str(fps), "-t", str(seconds)]
    return []


def build_command(
    timeline: Timeline,
    output: str | Path,
    durations: list[float],
    *,
    srt_path: str | Path | None = None,
    burn: bool = False,
) -> list[str]:
    """ffmpeg に渡す引数を組み立てる（実行はしない）。

    入力の並びは 画像0..n-1 → 音声n..2n-1 → BGM。音声はシーンごとに必ず1本ある
    （無いシーンには無音を作る）ので、concat のペアが常に揃う。
    """
    scenes = timeline.scenes
    if not scenes:
        raise TimelineError("シーンが1つもありません")
    if len(durations) != len(scenes):
        raise TimelineError(f"長さの数がシーン数と合いません: {len(durations)} != {len(scenes)}")
    if burn and not srt_path:
        raise TimelineError("焼き込む字幕がありません（字幕つきのシーンが必要です）")

    width, height = timeline.dimensions
    fps = timeline.fps
    count = len(scenes)
    total = round(sum(durations), 3)

    args: list[str] = []
    for scene, seconds in zip(scenes, durations, strict=True):
        args += image_input(scene.motion, seconds=seconds, fps=fps) + ["-i", str(scene.image)]
    for scene, seconds in zip(scenes, durations, strict=True):
        if scene.audio:
            args += ["-t", str(seconds), "-i", str(scene.audio)]
        else:
            args += [
                "-f", "lavfi", "-t", str(seconds),
                "-i", "anullsrc=channel_layout=stereo:sample_rate=48000",
            ]
    if timeline.bgm:
        args += ["-stream_loop", "-1", "-i", str(timeline.bgm)]

    graph = [
        filters.scene_video(
            index,
            width=width,
            height=height,
            fps=fps,
            seconds=seconds,
            motion=scene.motion,
        )
        for index, (scene, seconds) in enumerate(zip(scenes, durations, strict=True))
    ]
    graph += [
        filters.scene_audio(count + index, index, seconds)
        for index, seconds in enumerate(durations)
    ]
    graph.append(filters.concat(count))

    video_label = "vc"
    audio_label = "ac"
    if timeline.bgm:
        graph.append(filters.bgm_mix(count * 2, timeline.bgm_gain_db))
        audio_label = "amixed"
    if burn and srt_path:
        graph.append(filters.burn_subtitles(video_label, "vsub", str(srt_path), timeline.font))
        video_label = "vsub"
    if timeline.fade > 0:
        graph.append(filters.fade_video(video_label, "vout", timeline.fade, total))
        graph.append(filters.fade_audio(audio_label, "aout", timeline.fade, total))
        video_label, audio_label = "vout", "aout"

    args += ["-filter_complex", ";".join(graph)]
    args += ["-map", f"[{video_label}]", "-map", f"[{audio_label}]"]
    args += VIDEO_ARGS + ["-r", str(fps)] + AUDIO_ARGS
    args += ["-movflags", "+faststart", str(output)]
    return args


def render(
    timeline: Timeline,
    output: str | Path,
    *,
    dry_run: bool = False,
    burn: bool = False,
    probe: Callable[[str], float] | None = None,
    write_subtitles: bool = True,
) -> RenderResult:
    """タイムラインから動画を書き出す。

    字幕（SRT）は焼き込むかどうかに関係なく、常に動画の隣へ書き出す。
    """
    missing = timeline.missing_files()
    if missing:
        raise TimelineError("素材が見つかりません:\n  " + "\n  ".join(missing))

    target = Path(output)
    target.parent.mkdir(parents=True, exist_ok=True)
    durations = timeline.durations(probe)
    total = round(sum(durations), 3)

    srt = None
    if write_subtitles:
        srt = subtitles.write_srt(
            [scene.text for scene in timeline.scenes], durations, target.with_suffix(".srt")
        )
    if burn and srt is None:
        raise TimelineError("字幕つきのシーンが無いので焼き込めません")

    command = build_command(timeline, target, durations, srt_path=srt, burn=burn)
    if not dry_run:
        ffmpeg_module.run(command)

    return RenderResult(
        output=target,
        seconds=total,
        scenes=len(timeline.scenes),
        command=command,
        srt=srt,
        dry_run=dry_run,
    )

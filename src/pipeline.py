"""台本1本を動画一式にビルドする入口。"""

from __future__ import annotations

import shutil
from dataclasses import dataclass
from pathlib import Path

from . import ffmpeg, subtitles
from .config import ProjectConfig, _resolve
from .render import Renderer
from .script_model import Script, load_script
from .thumbnail import build_thumbnail
from .tts import synthesize_script


@dataclass
class BuildResult:
    video: Path
    thumbnail: Path
    outputs: dict[str, Path]
    duration: float
    used_voicevox: bool


def build(
    script_path: str | Path,
    config: ProjectConfig,
    out_dir: Path | None = None,
    use_tts: bool = True,
    keep_work: bool = False,
) -> BuildResult:
    script = load_script(script_path)
    out_dir = Path(out_dir) if out_dir else _resolve(f"output/{Path(script_path).stem}")
    out_dir.mkdir(parents=True, exist_ok=True)

    work_dir = out_dir / "work"
    work_dir.mkdir(parents=True, exist_ok=True)
    # 音声はキャッシュが効くので work を消してもここは残す
    audio_dir = out_dir / "audio"

    used_voicevox = synthesize_script(script, config, audio_dir, use_tts=use_tts)

    voice_track = ffmpeg.concat_audio(
        [line.audio_path for line in script.lines if line.audio_path],
        work_dir / "voice.wav",
        work_dir,
    )

    renderer = Renderer(config, work_dir)
    video = renderer.build_video(script, voice_track, out_dir / "video.mp4", work_dir)

    thumbnail = build_thumbnail(
        config,
        script.meta.get("thumbnail_title", script.title),
        out_dir / "thumbnail.png",
        subtitle=str(script.meta.get("thumbnail_subtitle", "")),
    )
    outputs = subtitles.write_outputs(script, out_dir)

    if not keep_work:
        shutil.rmtree(work_dir, ignore_errors=True)

    return BuildResult(
        video=video,
        thumbnail=thumbnail,
        outputs=outputs,
        duration=script.duration,
        used_voicevox=used_voicevox,
    )

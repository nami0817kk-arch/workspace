"""台本1本を動画一式にビルドする入口。"""

from __future__ import annotations

import shutil
from dataclasses import dataclass
from pathlib import Path

from . import audio, ffmpeg, inserts as inserts_mod, subtitles
from .config import ProjectConfig, _resolve
from .render import Renderer
from . import audio_gen
from .script_model import Script, load_script
from .thumbnail import build_thumbnail, from_meta
from .tts import create_backend, credits, image_credits, synthesize_script


@dataclass
class BuildResult:
    video: Path
    thumbnail: Path
    outputs: dict[str, Path]
    duration: float
    backend: str


def build(
    script_path: str | Path,
    config: ProjectConfig,
    out_dir: Path | None = None,
    use_tts: bool = True,
    keep_work: bool = False,
) -> BuildResult:
    """台本ファイルから書き出す。"""
    return build_script(
        load_script(script_path),
        config,
        Path(out_dir) if out_dir else _resolve(f"output/{Path(script_path).stem}"),
        use_tts=use_tts,
        keep_work=keep_work,
    )


def build_script(
    script: Script,
    config: ProjectConfig,
    out_dir: Path,
    use_tts: bool = True,
    keep_work: bool = False,
) -> BuildResult:
    """読み込み済みの台本から書き出す。

    ショートのように、台本を加工してから書き出したいときはこちらを使う。
    """
    out_dir = Path(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    work_dir = out_dir / "work"
    work_dir.mkdir(parents=True, exist_ok=True)
    # 音声はキャッシュが効くので work を消してもここは残す
    audio_dir = out_dir / "audio"

    backend = create_backend(config, use_tts)
    synthesize_script(script, config, audio_dir, backend=backend)

    # タイトルカードのぶんの無音を挟み、各セリフの開始時刻を振り直す
    inserts = inserts_mod.plan(script, config)
    inserts_mod.apply_timing(script, inserts)
    voice_track = ffmpeg.concat_audio(
        inserts_mod.realize_audio(inserts_mod.audio_segments(script, inserts), work_dir / "gaps"),
        work_dir / "voice.wav",
        work_dir,
    )

    soundtrack = audio.mix(
        voice_track,
        work_dir / "soundtrack.m4a",
        work_dir,
        config.audio,
        duration=script.duration + inserts.total,
        effects=audio.collect_effects(script, config),
        # 【速報】は緊迫した曲、【詳報】は落ち着いた曲。frontmatter の bgm が優先
        bgm=audio_gen.track_for(script.title, script.meta.get("bgm")),
    )

    renderer = Renderer(config, work_dir)
    video = renderer.build_video(
        script, soundtrack, out_dir / "video.mp4", work_dir, inserts
    )

    look = from_meta(script.meta, script.title)
    thumbnail = build_thumbnail(
        config,
        look["title"],
        out_dir / "thumbnail.png",
        subtitle=look["subtitle"],
        background=script.background,
        badge=look["badge"],
        date=script.date,
        lines=look["lines"],
        tags=look["tags"],
    )
    # 画像のクレジットも概要欄に出す。CC BY 系は表示しないと利用条件を満たさない
    outputs = subtitles.write_outputs(
        script, out_dir,
        credits=credits(script, config, backend) + image_credits(script),
    )

    if not keep_work:
        shutil.rmtree(work_dir, ignore_errors=True)

    return BuildResult(
        video=video,
        thumbnail=thumbnail,
        outputs=outputs,
        duration=script.duration + inserts.total,
        backend=backend.name,
    )

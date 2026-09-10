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
from .thumbnail import build_thumbnail, from_meta, reaction_line, short_quote
from .tts import (create_backend, credits, image_credits, image_details,
                  synthesize_script)


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

    # 尺が決まってから、長く止まる絵をほぐす。合成の前だと秒数が分からない。
    # 縦型（ショート）は同じ絵を出しておける時間が短い
    from .review import hold_limit

    spread_long_cards(script, hold_limit(config.video.height > config.video.width))

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
    # 帯の上に出す反応。指定が無ければ台本から短いものを拾う（2026-09-07）
    reaction = look.get("reaction") or reaction_line(script)
    thumbnail = build_thumbnail(
        config,
        look["title"],
        out_dir / "thumbnail.png",
        subtitle=look["subtitle"],
        background=look["photo"] or script.background,
        focus=look.get("focus"),
        badge=look["badge"],
        date=script.date,
        lines=look["lines"],
        tags=look["tags"],
        reaction=reaction,
        points=look.get("points") or [],
        photos=look.get("photos") or [],
        # 縦サムネの下に置く一言。横型では使わない
        quote=short_quote(script),
        crest_main=look.get("crest_main") or [],
        crests=look.get("crests"),
        crest_link=look.get("crest_link", "対"),
    )
    # 画像のクレジットも概要欄に出す。CC BY 系は表示しないと利用条件を満たさない
    outputs = subtitles.write_outputs(
        script, out_dir,
        credits=credits(script, config, backend) + image_credits(script),
        # 表示義務のある写真の詳細は、ハッシュタグより下に畳む
        footnotes=image_details(script),
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


def spread_long_cards(script: Script, limit: float | None = None) -> int:
    """同じ絵が続きすぎるところに、サムネイルの写真を挟む。

    カードは指定した行で差し替わり、それ以外の行では出たまま残る。そのため
    下のテロップだけが変わり、**画面は20秒以上動かない**ことがあった
    （2026-09-07 実測で、本編22〜27秒・ショート17〜21秒）。伸びている
    参考チャンネルは8秒で必ず変えている。

    写真を持たない台本では何もしない。その場合は `review` の「カードの持ち」が
    × を出すので、人が節を分けるなり写真を足すなりする。**黙って直さない。**
    """
    from .review import CARD_HOLD_MAX

    limit = CARD_HOLD_MAX if limit is None else limit
    photo = str((script.meta or {}).get("thumbnail_photo") or "").strip()
    if not photo:
        return 0

    inserted = 0
    look = None
    span = 0.0
    showing = None      # いま画面に出ているカード
    for scene in script.scenes:
        showing = None  # カードは節をまたいで引き継がない
        for line in scene.lines:
            seconds = float(line.duration or 0)
            # **カードは書かれた行で切り替わり、次の行からは引き継がれて残る。**
            # 生の line.card を見ると、引き継いでいる行が「カード無し」に見えて
            # 区間が分断され、判定が効かなかった（2026-09-07 実測。23秒の区間を
            # 9.1秒と14秒に割って数えていた）。script_model._scene_lines と同じ扱いにする。
            if line.card is not None:
                showing = None if line.card in ("none", "なし") else line.card
            now = (showing or "", line.image or "")
            if now != look:
                look, span = now, seconds
                continue
            # **超えてから挟むと手遅れ。**超える行に先回りして画面を変える
            # （後追いにしたら 23秒→16秒 までしか縮まなかった。2026-09-07 実測）
            if span + seconds > limit and not line.image:
                line.image = photo
                inserted += 1
                look, span = (showing or "", photo), seconds
                continue
            span += seconds
    return inserted

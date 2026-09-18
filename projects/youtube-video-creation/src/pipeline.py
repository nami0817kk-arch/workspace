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


def drop_short_only(script):
    """**ショート専用の行を本編から落とす**（2026-09-14）。

    ショートは節を1つ切り出して単体で出すので、「いつ・どこの試合か」を
    節の頭に置く必要がある。本編では前の節で言い終えているため、
    そのまま残すと**節をまたいだ言い直し**になる（`_advise_repeats` が
    止めるのと同じ型）。台本には `only: short` と書き、本編でだけ捨てる。
    """
    for scene in script.scenes:
        scene.lines = [l for l in scene.lines if getattr(l, "only", None) != "short"]
    return script


def build(
    script_path: str | Path,
    config: ProjectConfig,
    out_dir: Path | None = None,
    use_tts: bool = True,
    keep_work: bool = False,
) -> BuildResult:
    """台本ファイルから書き出す。"""
    return build_script(
        drop_short_only(load_script(script_path)),
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
    max_seconds: float | None = None,
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

    # **上限があるなら、実尺で収める**（2026-09-16）。見積りの安全率では
    # 短くなりすぎるか、超えるかのどちらかにしかならなかった
    if max_seconds:
        from .shorts import enforce_limit

        cut = enforce_limit(script, max_seconds, config)
        if cut:
            print(f"　上限{max_seconds:.0f}秒に収めるため、後ろから{cut}行落としました")

    # 尺が決まってから、長く止まる絵をほぐす。合成の前だと秒数が分からない。
    # 縦型（ショート）は同じ絵を出しておける時間が短い
    from .review import hold_limit

    spread_long_cards(script, hold_limit(config.video.height > config.video.width))
    # **冒頭だけは、もっと早く変える**（2026-09-15）。spread_long_cards の
    # あとに置く。先に置くと、こちらが挟んだ1枚で「絵が変わった」ことになり、
    # そのあと20秒の判定が効かなくなる
    open_early(script)
    hold_photo(script)

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
    reaction = look.get("reaction") or (
        "" if look.get("no_auto_reaction") else reaction_line(script))
    thumbnail = build_thumbnail(
        config,
        look["title"],
        out_dir / "thumbnail.png",
        subtitle=look["subtitle"],
        background=look["photo"] or script.background,
        focus=look.get("focus"),
        focus_x=look.get("focus_x"),
        badge=look["badge"],
        date=script.date,
        lines=look["lines"],
        tags=look["tags"],
        reaction=reaction,
        points=look.get("points") or [],
        # **書き出しの経路にも渡す**（2026-09-14）。`thumbnail` コマンドにだけ
        # 渡していたので、単体で作ると正しく、build で上書きすると崩れていた
        # （バルセロナの帯が左半分のまま／バレンシアの赤い一行が消えていた）
        note_red=look.get("note_red") or "",
        band_full=bool(look.get("band_full")),
        photos=look.get("photos") or [],
        # 縦サムネの下に置く一言。横型では使わない
        quote=short_quote(script),
        crest_main=look.get("crest_main") or [],
        crests=look.get("crests"),
        crest_link=look.get("crest_link", "対"),
        face_link=look.get("face_link", ""),
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


def hold_photo(script: Script) -> int:
    """**写真は一度出たら、そのあとも出したままにする**（2026-09-15）。

    `spread_long_cards` は「同じ絵が20秒止まる」ところに写真を1枚挟むが、
    **次の行で下地へ戻っていた。**フォーデンの回の本編は
    スタジアム → 写真 → スタジアム → 写真 と**3回**入れ替わっていて、
    2026-09-14 の指摘「一つの章で背景を変えるのやめて」
    「この間に一瞬背景が切り替わってるなおして」がそのまま再発していた。

    `research.to_script` の側は「山場の節から写真にして最後まで残す」と
    書いているのに、**あとから挟むほうがその決まりを知らなかった。**
    書き出しの最後に、写真を前から後ろへ引き継ぐ。

    `scan_switch.py` で数えると、入れ替えは1本につき1回に収まる。
    """
    filled = 0
    holding = ""
    for scene in script.scenes:
        for line in scene.lines:
            if line.image:
                holding = line.image
            elif holding:
                line.image = holding
                filled += 1
    return filled


# **冒頭で絵が止まっている時間**（2026-09-15）。視聴維持のカーブを読んだら、
# 崖は 12秒→24秒 の1か所で、82% から 50% へ落ちていた。そこは
# **1枚目の絵が出っぱなしの区間**で、spread_long_cards が写真を挟むのは
# 20秒を超えてから。**落ちきってから変えていた。**
#
# 参考にしている3チャンネルは8秒で必ず画面を変えている（2026-09-07 実測）。
# 本編全体を8秒にすると写真1枚では足りないので、**冒頭だけ**詰める。
OPENING_WINDOW = 25.0     # ここまでを「冒頭」とみなす（秒）
OPENING_HOLD_MAX = 8.0    # 冒頭で同じ絵が止まってよい秒数


def open_early(script: Script, within: float = OPENING_WINDOW,
               limit: float = OPENING_HOLD_MAX) -> int:
    """冒頭で、同じ絵が `limit` 秒を超える前に写真へ切り替える。

    `spread_long_cards` と同じ道具（サムネイルの写真）を使う。
    **1枚しか無いので、挟むのも1回だけ。**そのあとは `hold_photo` が
    後ろへ引き継ぐので、入れ替えの回数は増えない
    （`scan_switch.py` で数えて1本1回のまま）。

    写真を持たない回（エンブレムで作る回）は何もしない。
    """
    photo = str((script.meta or {}).get("thumbnail_photo") or "").strip()
    if not photo:
        return 0

    elapsed = 0.0
    span = 0.0
    look = None
    showing = None
    for scene in script.scenes:
        showing = None            # カードは節をまたいで引き継がない
        for line in scene.lines:
            if elapsed >= within:
                return 0
            seconds = float(line.duration or 0)
            if line.card is not None:
                showing = None if line.card in ("none", "なし") else line.card
            now = (showing or "", line.image or "")
            if now != look:
                look, span = now, seconds
                elapsed += seconds
                continue
            # **超える行に先回りする。**超えてから挟むと、崖のあとになる
            if span + seconds > limit and not line.image:
                line.image = photo
                return 1
            span += seconds
            elapsed += seconds
    return 0

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

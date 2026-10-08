"""台本1本を動画一式にビルドする入口。"""

from __future__ import annotations

import shutil
from concurrent.futures import ThreadPoolExecutor
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

    tall = config.video.height > config.video.width
    spread_long_cards(script, hold_limit(tall), portrait=tall)
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

    # **音の混ぜは、絵を描くあいだに別スレッドで回す**（2026-10-08）。どちらも相手の
    # 結果を要らないので、順に待つ意味が無い。`build_video` が ffmpeg に渡す手前で待つ
    bgm = audio_gen.track_for(script.title, script.meta.get("bgm"))
    renderer = Renderer(config, work_dir)
    with ThreadPoolExecutor(max_workers=1, thread_name_prefix="mix") as pool:
        soundtrack = pool.submit(
            audio.mix,
            voice_track,
            work_dir / "soundtrack.m4a",
            work_dir,
            config.audio,
            duration=script.duration + inserts.total,
            effects=audio.collect_effects(script, config),
            # 【速報】は緊迫した曲、【詳報】は落ち着いた曲。frontmatter の bgm が優先
            bgm=bgm,
        )
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

    **板は引き継がない**（2026-09-20）。ここで言う「写真」は本当に写真のことで、
    板（`assets/stats/` の一覧板・数字の図）を引き継ぐと**そのあとの節のカードが
    全部消える。**プレミア20クラブ紹介のボーンマスで、基礎DATAの板が
    20秒から165秒まで出っぱなしになり、歩んできた道・名選手・宿敵の
    カードが1枚も画面に出ていなかった。板の上には何も重ねない決まり
    （render.py の `board`）と噛み合って、**節が進んでも絵が変わらない**。
    """
    from .render import _is_board

    filled = 0
    holding = ""
    for scene in script.scenes:
        for line in scene.lines:
            if line.image:
                holding = "" if _is_board(line.image) else line.image
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
    from .review import card_look

    photo = str((script.meta or {}).get("thumbnail_photo") or "").strip()
    if not photo:
        return 0

    specs = script.cards or {}
    elapsed = 0.0
    span = 0.0
    look = None
    for scene in script.scenes:
        showing = None            # カードは節をまたいで引き継がない
        stage = ""                # 画面に出ている写真（書いた行から引き継がれる）
        for number, line in enumerate(scene.lines):
            if elapsed >= within:
                return 0
            seconds = float(line.duration or 0)
            if line.card is not None:
                showing = None if line.card in ("none", "なし") else line.card
            # 光らせる行だけが違う同じ表は、同じ絵（`card_look`）。
            # 写真も引き継ぎ後の姿で見る（`spread_long_cards` と同じ数え方）
            stage = _stage_of(line, stage)
            now = (card_look(showing, specs), stage)
            if now != look:
                look, span = now, seconds
                elapsed += seconds
                continue
            # **超える行に先回りする。**超えてから挟むと、崖のあとになる
            if span + seconds > limit and _change_photo(scene, number, stage, photo):
                return 1
            span += seconds
            elapsed += seconds
    return 0

def spread_long_cards(script: Script, limit: float | None = None, portrait: bool = False) -> int:
    """同じ絵が続きすぎるところに、サムネイルの写真を挟む。

    カードは指定した行で差し替わり、それ以外の行では出たまま残る。そのため
    下のテロップだけが変わり、**画面は20秒以上動かない**ことがあった
    （2026-09-07 実測で、本編22〜27秒・ショート17〜21秒）。伸びている
    参考チャンネルは8秒で必ず変えている。

    写真を持たない台本では何もしない。その場合は `review` の「カードの持ち」が
    × を出すので、人が節を分けるなり写真を足すなりする。**黙って直さない。**

    **行ごとにカードを分けた節にも効かせる**（2026-10-08）。見分けは名前ではなく
    中身（`review.card_look`）。光らせる行だけが違う同じ表は同じ絵として数える。

    **すでに写真が出ている行でも挟めるようにした**（2026-10-08）。それまでは
    「写真の無い行」にしか挟めず、`output/20261008_finance_arteta` 第4節のように
    **全部の行に写真が書いてある節**では、数え方を直しても手が出せなかった
    （10/7〜10/8 の本編15本は、長く止まる区間がすべてこの形）。
    その場合は**別の写真へ替え、次に台本が写真を指定するまで持ち越す**ので、
    入れ替えの回数は増えても1回（`_change_photo`）。
    """
    from .review import CARD_HOLD_MAX, card_look

    limit = CARD_HOLD_MAX if limit is None else limit
    photo = str((script.meta or {}).get("thumbnail_photo") or "").strip()
    if not photo:
        return 0
    # 縦の画面（ショート）では、隣にある縦版を使う（上の `tall_twin` に理由）
    if portrait:
        photo = tall_twin(photo)

    from .marks import on_screen

    specs = script.cards or {}
    inserted = 0
    look = None
    span = 0.0
    for scene in script.scenes:
        showing = None  # カードは節をまたいで引き継がない
        stage = ""      # いま画面に出ている写真（書いた行から引き継がれる）
        # **書き込みを足した行は画面が変わる**（2026-10-07）。review の「カードの持ち」と同じ数え方
        drawn = on_screen(scene, specs)
        for number, line in enumerate(scene.lines):
            seconds = float(line.duration or 0)
            # **カードは書かれた行で切り替わり、次の行からは引き継がれて残る。**
            # 生の line.card を見ると、引き継いでいる行が「カード無し」に見えて
            # 区間が分断され、判定が効かなかった（2026-09-07 実測。23秒の区間を
            # 9.1秒と14秒に割って数えていた）。script_model._scene_lines と同じ扱いにする。
            if line.card is not None:
                showing = None if line.card in ("none", "なし") else line.card
            # **写真も同じ**（2026-10-08）。`hold_photo` はこのあとに動くので、ここでは
            # 引き継ぎ前の台本を見ている。生の `line.image` で数えると、写真を書いた行だけが
            # 「別の絵」に見えて区間が切れ、長く止まっている所を見落としていた
            stage = _stage_of(line, stage)
            now = (card_look(showing, specs), stage, len(drawn[number]))
            if now != look:
                look, span = now, seconds
                continue
            # **超えてから挟むと手遅れ。**超える行に先回りして画面を変える
            # （後追いにしたら 23秒→16秒 までしか縮まなかった。2026-09-07 実測）
            if span + seconds > limit and _change_photo(scene, number, stage, photo):
                inserted += 1
                stage = photo
                look, span = (now[0], photo, now[2]), seconds
                continue
            span += seconds
    return inserted


def _stage_of(line, stage: str) -> str:
    """その行で画面に出ている写真。板（`assets/stats/`）は引き継がない（`hold_photo` と同じ）。"""
    from .render import _is_board

    if line.image:
        return "" if _is_board(line.image) else line.image
    return stage


# 写真の切り方の後ろ書き（`tools/facecrop.py` が付ける）。`03_x_w.jpg` と `03_x_v.jpg` は
# **同じ1枚の写真を切り直しただけ**なので、入れ替えても画面はほとんど変わらない
_CROP_SUFFIXES = ("_w", "_v", "_r", "_h")


def photo_key(path: str | None) -> str:
    """同じ写真かどうかの見分け。切り方の後ろ書き（`_w` `_v` …）を落とした名前。"""
    from pathlib import PurePosixPath

    text = str(path or "").strip().replace("\\", "/")
    if not text:
        return ""
    pure = PurePosixPath(text)
    stem = pure.stem
    changed = True
    while changed:
        changed = False
        for suffix in _CROP_SUFFIXES:
            if stem.endswith(suffix) and len(stem) > len(suffix):
                stem, changed = stem[: -len(suffix)], True
    return f"{pure.parent.as_posix()}/{stem}"


def tall_twin(photo: str) -> str:
    """縦の画面のために、その写真の**縦版**（隣の `_v`）を返す。無ければそのまま。

    **縦の画面では、板と顔は共存できない**（2026-10-08 夜に実測して分かった）。
    板は画面の 11〜62% を占めるので、顔を上へ逃がすと頭が切れ、下へ逃がすと板が乗る。
    ところが `spread_long_cards` は縦横の別を見ずに**サムネの写真（たいてい顔が主役）**を
    差し込むので、**板の長い節があるショートでは誰の回でも顔が板に潰される**
    （ネイマールの回の 39.0〜50.4秒で見つけた。4コマは27.7秒を見るので当たらなかった）。

    縦版（`tools/facecrop.py` や `tools/pairphoto.py` が書く `<名前>_v.<拡張子>`）は
    縦の画面に合わせて切ってあるので、そちらを使う。`shorts._drop_boards` が
    台本の写真に対してやっているのと同じ差し替えを、**あとから挟む写真にも当てる**。
    """
    from pathlib import Path as _P

    if not photo:
        return photo
    name = _P(photo)
    if name.stem.endswith("_v"):
        return photo
    twin = name.with_name(name.stem + "_v" + name.suffix)
    root = _P(__file__).resolve().parents[1]
    return twin.as_posix() if (root / twin).exists() else photo


def _change_photo(scene, number: int, stage: str, photo: str) -> bool:
    """`number` 行目で画面の写真を `photo` に替える（2026-10-08）。

    写真が出ていない所では、今までどおり1枚挟むだけ（`hold_photo` が後ろへ引き継ぐ）。
    **すでに写真が出ている所でも替えられるようにした。**実物で長く止まっている区間は、
    どれも**全部の行に写真が書いてある節**で、挟む隙間が無かった。

    **1行だけ替えると明滅する**（2026-09-15 に `hold_photo` を作った理由と同じ）。
    いまの写真を書いている後ろの行も同じだけ替え、**台本が別の写真を指定した行で止める**。
    節はまたがない。替えても画面が変わらないとき（同じ写真を切り直しただけ・すでに
    その写真）は **False** を返して何もしない——`review` の「カードの持ち」が × を出すので、
    人がカードを2枚に割る（CLAUDE.md の直し方の1つめ）。
    """
    if photo_key(stage) == photo_key(photo):
        return False
    scene.lines[number].image = photo
    if stage:
        for line in scene.lines[number + 1:]:
            if not line.image:
                continue            # 引き継ぎの行。そのままで新しい写真が出る
            if line.image != stage:
                break               # 台本が指定した別の写真。そこで戻す
            line.image = photo
    return True


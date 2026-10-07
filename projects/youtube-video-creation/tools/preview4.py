# -*- coding: utf-8 -*-
"""書き出す前の4コマの下見（2026-10-05）。声も動画も作らずに、`tools/frames.py` と同じ4コマを描く。

    python tools/preview4.py scripts/20261005_doan_captain.md            # 本編とショートの両方
    python tools/preview4.py scripts/20261005_*.md --main                # 本編だけ
    python tools/preview4.py scripts/20261005_doan_captain.md --short    # ショートだけ
    python tools/preview4.py scripts/<台本>.md --open                     # 作ったら開く

**なぜ要るか。**表・字幕・白い箱が顔に重なる、頭が切れる、に気づくのは、
`build`（声の合成＋書き出しで10分以上）が終わってから `tools/frames.py`・`tools/facecheck.py` で
4コマを見たときだった。10/4〜10/5 だけで7回作り直している。絵の作りは台本と写真で決まるので、
**声を待たなくても同じ絵が描ける。**

- **描くのは実際の書き出しと同じ道筋。**本編は `pipeline.drop_short_only` → `spread_long_cards`
  → `open_early` → `hold_photo` → `inserts`、ショートは `shorts.trim`（`_add_face`・`short_photo`・
  `_v.jpg` の差し替え）→ `crest_background` → `shorts.portrait` → `enforce_limit` を通し、
  絵は `render.Renderer.frame_entries` が並べたものを使う。違うのは2つだけ:
  - **声を作らない。**行の長さは、書き出し済みの声の控え（`output/<名前>/audio/` に同じ鍵の wav）が
    あればその実尺、無ければ `Line.estimated_duration()` を話速で割り、行末の間を足した見積り
  - **全部のコマを描かない。**`Renderer.frame` などを「あとで描く札」に差し替えて並びだけ作り、
    4つの時点に当たるコマだけを本物の `Renderer.frame` で描く。背景の動画（スタジアムの実写）は
    その時点の1コマを ffmpeg で抜いて、書き出しと同じく下に敷く
- 時点は `tools/frames.py` と同じ（冒頭 0:03／山場の頭／60秒／最後の5秒前。ショートは
  冒頭／山場の頭／中ほど／最後の5秒前）。**時刻は見積りなので、実物と数秒ずれる。**絵の作りは同じ
- 顔の判定は `tools/facecheck.py` の `judge` をそのまま当てる。顔は**できあがったコマ**と
  **写真だけの絵（板を重ねる前）**の両方から探すので、表が顔を丸ごと覆ったコマも拾える
  （facecheck は動画しか無いので、そこを見逃す）。写真を敷いた行は、写真だけの絵とコマの差で
  「顔の上に何か描いた」も見る（半透明の表は色で見る facecheck の判定をすり抜ける）。
  赤＝顔（写真を敷いた行は写真だけの絵で探した顔）、橙＝背景の絵から借りた顔、緑＝頭の推定の枠
- 出力は `output/<名前>/preview4.png`（ショートは `output/<名前>_short/preview4.png`）。
  × があれば終了コード1。**× が無くても、出来た絵は目で見る。**書き出したあとの
  `frames.py`・`facecheck.py` の決まりも変わらない（声の長さで時点がずれる）
"""
from __future__ import annotations

import argparse
import math
import os
import subprocess
import sys
import tempfile
import time
from contextlib import contextmanager
from dataclasses import dataclass, field, replace
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageOps

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

# Windows のコンソールは cp932 なので「✓」で落ちる（facecheck.py と同じ手当て）
for _stream in (sys.stdout, sys.stderr):
    try:
        _stream.reconfigure(encoding="utf-8", errors="replace")
    except (AttributeError, ValueError):
        pass

from src import faces, shorts  # noqa: E402
from src import ffmpeg as ffmpeg_mod  # noqa: E402
from src import inserts as inserts_mod  # noqa: E402
from src.config import ProjectConfig, load_config  # noqa: E402
from src.ffmpeg import is_video  # noqa: E402
from src.pipeline import drop_short_only, hold_photo, open_early, spread_long_cards  # noqa: E402
from src.reading import apply as apply_reading  # noqa: E402
from src.reading import load_dictionary, split_dictionary, words_in  # noqa: E402
from src.render import PHOTO_MAX_ZOOM, Renderer  # noqa: E402
from src.review import hold_limit  # noqa: E402
from src.script_model import Script, load_script  # noqa: E402
from src.tts import _digest, pause_for, voice_params, voice_variants, wav_duration  # noqa: E402
from tools.facecheck import _overlaps, judge  # noqa: E402
from tools.frames import _duration  # noqa: E402

SHORT_MAX = 70.0      # これ以下の尺は「60秒」の代わりに「中ほど」を見る（facecheck.py と同じ境）
TILE = 640            # 並べるときのコマの長い辺
# 背景の動画から抜いたコマの控え（1秒刻み）。4K でなくても、重い 1080p60 のクリップは1コマ数秒かかる。
# 下に敷くスタジアムの実写は1秒で見た目が変わらないので、秒に丸めて使い回す
BG_CACHE = ROOT / "output" / ".preview4_bg"
ENGINE = "engine"     # 声の控えの鍵に入るバックエンド名（書き出しは VOICEVOX ENGINE）
# 見積りの補正。`estimated_duration()÷話速` は実尺より長く出る。10/1〜10/5 に書き出した
# 本編43本・ショート43本で、実尺÷見積り（間を除く読み上げのぶん）は中央値 0.92（0.77〜0.99）
PACE = 0.92


# ---------------------------------------------------------------- 行の長さ


def set_timing(script: Script, config: ProjectConfig, audio_dir: Path | None = None) -> int:
    """各行に duration / start / pause を入れる。声は作らない。返すのは実尺が取れた行の数。

    並びと鍵は `tts.synthesize_script` と同じ。書き出し済みの声の控えに同じ鍵の wav があれば
    その長さ（間を含む）、無ければ `estimated_duration()` を話速で割り、行末の間を足す。
    """
    readings = load_dictionary()
    # ENGINE はユーザー辞書を持つので、名前は辞書側に分けてから鍵を作る（synthesize_script と同じ）
    words, readings = split_dictionary(readings)
    variants = voice_variants(script.lines)
    cursor = 0.0
    real = 0
    for index, line in enumerate(script.lines):
        member = config.resolve_speaker(line.speaker, variants[index])
        pause = pause_for(config, line)
        seconds = None
        if audio_dir is not None and Path(audio_dir).is_dir():
            spoken = replace(line, text=apply_reading(line.text or "", readings))
            hit = words_in(spoken.text, words)
            seed = replace(spoken, text=f"{spoken.text}#{hit}") if hit else spoken
            wav = Path(audio_dir) / f"{index:04d}_{member.key}_{_digest(seed, member, pause, ENGINE)}.wav"
            if wav.exists():
                seconds = wav_duration(wav)
                real += 1
        if seconds is None:
            speed = voice_params(line, member)[0] or 1.0
            seconds = line.estimated_duration() / speed * PACE + pause
        line.pause = pause
        line.duration = seconds
        line.start = cursor
        cursor += seconds
    return real


# ---------------------------------------------------------------- 組み立て


@dataclass
class Plan:
    """書き出しの直前まで組んだ台本。"""

    script: Script
    config: ProjectConfig
    inserts: inserts_mod.Inserts
    out_dir: Path
    short: bool
    real_lines: int
    lines: int
    dropped: int = 0


def plan(script_path: str | Path, short: bool = False, section: str = "",
         work_dir: Path | None = None, config: ProjectConfig | None = None,
         use_audio: bool = True) -> Plan:
    """`_cmd_build`／`_cmd_short` → `build_script` と同じ順に、声の合成だけ抜いて組む。"""
    path = Path(script_path)
    config = config or load_config()
    if short:
        short_script = shorts.trim(load_script(path), section)
        out_dir = ROOT / shorts.default_path(path)
        # エンブレムの回は下地をエンブレムにする（_cmd_short と同じ）。絵は作業場所に置く
        crest_bg = shorts.crest_background(short_script, work_dir or out_dir)
        if crest_bg:
            short_script.background = crest_bg
            for scene in short_script.scenes:
                scene.background = crest_bg
        script, config, limit = short_script, shorts.portrait(config), shorts.MAX_SECONDS
    else:
        script = drop_short_only(load_script(path))
        out_dir = ROOT / "output" / path.stem
        limit = None
    real = set_timing(script, config, out_dir / "audio" if use_audio else None)
    lines = len(script.lines)
    dropped = shorts.enforce_limit(script, limit, config) if limit else 0
    # ここから下は pipeline.build_script と同じ並び
    spread_long_cards(script, hold_limit(config.video.height > config.video.width))
    open_early(script)
    hold_photo(script)
    inserts = inserts_mod.plan(script, config)
    inserts_mod.apply_timing(script, inserts)
    return Plan(script, config, inserts, out_dir, short, real, lines, dropped)


# ---------------------------------------------------------------- 描画


class _Lazy:
    """あとで描くコマの札。`frame_entries` の並びの中では、これがパスの代わりに流れる。"""

    __slots__ = ("kind", "args", "kwargs")

    def __init__(self, kind: str, *args, **kwargs):
        self.kind, self.args, self.kwargs = kind, args, kwargs


class _Clip(str):
    """背景の「ゆっくり寄るクリップ」の代わり。ffmpeg で作らず、元の絵と寄り方だけ持つ。"""

    def __new__(cls, source: Path, length: float, zoom: float, max_zoom: float):
        obj = str.__new__(cls, f"{source}#preview.mp4")   # is_video が True を返す名前
        obj.source, obj.length, obj.zoom, obj.max_zoom = Path(source), length, zoom, max_zoom
        return obj


class PreviewRenderer(Renderer):
    """`Renderer` の並べ方はそのまま、描くのを要るコマだけにする。"""

    def __init__(self, config: ProjectConfig, work_dir: Path):
        super().__init__(config, work_dir)
        self._clip_seconds: dict[str, float] = {}
        self._bg: dict[float, Image.Image] = {}
        self._rgb_stages: dict[str, Image.Image] = {}

    # --- 札を返す（frame_entries・_intro・_transition から呼ばれる）
    def frame(self, *args, **kwargs):
        return _Lazy("frame", *args, **kwargs)

    def title_frame(self, *args, **kwargs):
        return _Lazy("title", *args, **kwargs)

    def blend(self, first, second, ratio):
        return _Lazy("blend", first, second, ratio)

    def _black(self):
        return _Lazy("black")

    def _moving(self, path: Path, seconds: float, zoom: float | None = None):
        """背景のクリップは作らない。寄る条件は Renderer._moving と同じ。"""
        max_zoom = ffmpeg_mod.MAX_ZOOM if zoom is None else PHOTO_MAX_ZOOM
        zoom = self.config.motion.background_zoom if zoom is None else zoom
        if zoom <= 1.0 or is_video(path) or not Path(path).exists():
            return path
        return _Clip(Path(path), max(4.0, math.ceil(seconds)), zoom, max_zoom)

    # --- 札を本物の絵にする
    def realize(self, item) -> Path:
        if not isinstance(item, _Lazy):
            return Path(item)
        if item.kind == "frame":
            return Renderer.frame(self, *item.args, **item.kwargs)
        if item.kind == "title":
            return Renderer.title_frame(self, *item.args, **item.kwargs)
        if item.kind == "black":
            return Renderer._black(self)
        first, second, ratio = item.args
        return Renderer.blend(self, self.realize(first), self.realize(second), ratio)

    def _cover(self, image: Image.Image) -> Image.Image:
        """ffmpeg の scale=...:force_original_aspect_ratio=increase,crop=W:H と同じ（真ん中で切る）。"""
        size = (self.layout.width, self.layout.height)
        return ImageOps.fit(image.convert("RGB"), size, method=Image.Resampling.BICUBIC)

    def background_at(self, segments, t: float) -> Image.Image:
        """背景の列（background_segments）の t 秒目の1コマ。同じ秒は1回しか取らない。"""
        key = round(t, 2)
        if key not in self._bg:
            self._bg[key] = self._background_at(segments, t)
        return self._bg[key]

    def _background_at(self, segments, t: float) -> Image.Image:
        start = 0.0
        path, offset = segments[-1][0], 0.0
        for seg, seconds in segments:
            if t < start + seconds:
                path, offset = seg, t - start
                break
            start += seconds
        else:
            offset = max(0.0, t - (start - segments[-1][1]))
        if isinstance(path, _Clip):
            # ffmpeg.still_to_clip の zoompan と同じ寄り方（真ん中へ、1秒あたり一定の速さ）
            total = min(path.max_zoom, 1.0 + (path.zoom - 1.0) / ffmpeg_mod.REFERENCE_SECONDS * path.length)
            z = 1.0 + (total - 1.0) * min(1.0, offset / path.length)
            with Image.open(path.source) as opened:
                image = self._cover(opened)
            w, h = image.size
            cw, ch = w / z, h / z
            box = ((w - cw) / 2, (h - ch) / 2, (w + cw) / 2, (h + ch) / 2)
            return image.resize(image.size, Image.Resampling.BICUBIC, box=box)
        if is_video(path):
            # 書き出しは -stream_loop -1 で回すので、クリップの長さで割った余りの位置
            clip = Path(path)
            stat = clip.stat()
            stamp = f"{clip.stem}_{stat.st_size}_{int(stat.st_mtime)}"
            BG_CACHE.mkdir(parents=True, exist_ok=True)
            length_file = BG_CACHE / f"{stamp}.len"
            if stamp not in self._clip_seconds:
                try:
                    self._clip_seconds[stamp] = float(length_file.read_text())
                except (OSError, ValueError):
                    self._clip_seconds[stamp] = _duration(clip) or 0.0
                    length_file.write_text(str(self._clip_seconds[stamp]))
            length = self._clip_seconds[stamp]
            at = int(offset % length) if length > 1.0 else 0
            # PNG で書くと遅い（facecheck.py と同じ理由）。下に敷くだけなので JPEG の高画質で足りる
            shot = BG_CACHE / f"{stamp}_{at:04d}.jpg"
            if not shot.exists():
                subprocess.run([ffmpeg_mod.ffmpeg_exe(), "-y", "-loglevel", "error", "-ss", str(at),
                                "-i", str(clip), "-frames:v", "1", "-q:v", "2", str(shot)], capture_output=True)
            if shot.exists():
                with Image.open(shot) as opened:
                    return self._cover(opened)
            return Image.new("RGB", (self.layout.width, self.layout.height), (0, 0, 0))
        with Image.open(path) as opened:
            return self._cover(opened)

    def photo_layer(self, item, segments, t: float) -> tuple[Image.Image | None, bool]:
        """板を重ねる前の、写真だけの絵（顔を探すため）と、それがコマの真下の絵そのものか。

        写真を敷いた行は、`frame` が写真の下地（`_photo_stage`）を写してから表や字幕を描くので、
        下地とコマの差がそのまま「上に描いたもの」になる（True）。写真の無い行・寄る写真は
        背景の動画の絵を返すが、上に暗い幕が掛かるので差は使えない（False）。板の行は None。
        """
        if isinstance(item, _Lazy) and item.kind == "frame":
            line, scene = item.args[0], item.args[1]
            panel = item.kwargs.get("panel")
            if self.is_full_card(panel[2] if panel is not None else line.card):
                # **左右の比べ（versus）は画面いっぱいの絵**（2026-10-07）。写真の下地と比べると全面が
                # 「上に描いたもの」になり、顔に板が掛かったと誤って出る。板と同じくコマで顔を探す
                return None, False
            opening = scene.title == self.opening_scene and self.opening_photo
            stage_path = line.image or (self.opening_photo if opening else None)
            stage = self._photo_stage(stage_path)
            if stage is not None:
                if str(stage_path) in self._board_stages:
                    return None, False    # 板は文字の絵。顔はできあがったコマで探す
                if self.over_video and self.moving_photo(stage_path):
                    return self.background_at(segments, t), False
                key = str(stage_path)
                if key not in self._rgb_stages:
                    self._rgb_stages[key] = stage.convert("RGB")
                return self._rgb_stages[key], True
        return (self.background_at(segments, t) if self.over_video else None), False


# 下地と比べて「上に何か描いてある」とみなす画素の差（RGB のいちばん大きい差）と、顔の枠の割合。
# facecheck の `overlay_on_face` は色（白い箱・暗く色の薄い板）で見るので、半透明の紺の表が
# 顔に掛かったコマ（10/5 ニュージーランドの60秒）を ✓ にする。下見は下地を持っているので差で見る
DIFF_MIN = 48
COVER_X = 0.25
# 写真だけの絵で顔を探すときの厳しさ（faces.find_faces の既定は 6）。10/5 の8本で、本物の顔は
# 10 でも全部残り、ポルトガルの冒頭で足を顔と取ったものだけが落ちた
BASE_NEIGHBORS = 10
COVER_TRI = 0.08


def covered(picture: Image.Image, base: Image.Image, boxes: list, already: list) -> list[tuple[str, str]]:
    """写真だけの絵と比べて、顔の枠の上に何かが描かれているか。facecheck が (c) を出した顔は見ない。"""
    import numpy as np

    if not boxes:
        return []
    a = np.asarray(picture.convert("RGB"), dtype=np.int16)
    b = np.asarray(base.convert("RGB"), dtype=np.int16)
    drawn = np.abs(a - b).max(axis=2) > DIFF_MIN
    biggest = max(box[2] for box in boxes)
    seen = " ".join(text for _, text in already if text.startswith("(c)"))
    out: list[tuple[str, str]] = []
    for x, y, w, h in boxes:
        where = f"顔 x{x} y{y} {w}px"
        if w < biggest * 0.5 or where in seen:
            continue
        part = drawn[max(0, y):y + h, max(0, x):x + w]
        if part.size == 0:
            continue
        share = float(part.mean())
        if share >= COVER_X:
            out.append(("×", f"(c) 顔に表・字幕・箱がかかっています（写真だけの絵と比べて顔の枠の{share:.0%}）: {where}"))
        elif share >= COVER_TRI:
            out.append(("△", f"(c) 顔の枠の端に表・字幕・箱がかかっています（{share:.0%}）: {where}"))
    return out


@dataclass
class Shot:
    label: str
    at: float
    image: Image.Image
    own: list = field(default_factory=list)
    extra: list = field(default_factory=list)
    found: list = field(default_factory=list)     # [(印, 文)]


def marks(script: Script, total: float, short: bool) -> list[tuple[str, float]]:
    """見る時点。frames.py・facecheck.py と同じ4つ（尺が短ければ「60秒」の代わりに「中ほど」）。"""
    out = [("冒頭 0:03", 3.0)]
    main = next((scene for scene in script.scenes if scene.main and scene.lines), None)
    if main is None and short and len(script.scenes) > 1 and script.scenes[1].lines:
        main = script.scenes[1]        # ショートは切り出した節が山場
    if main is not None:
        out.append(("山場の頭", main.lines[0].start + 1.0))
    if total > SHORT_MAX:
        out.append(("60秒", 60.0))
    elif total > 10:
        out.append(("中ほど", total / 2))
    if total > 10:
        out.append(("最後の5秒前", total - 5.0))
    kept: list[tuple[str, float]] = []
    for label, at in sorted(out, key=lambda m: m[1]):
        if at < total and all(abs(at - k[1]) >= 1.5 for k in kept):
            kept.append((label, at))
    return kept


def shoot(p: Plan, work_dir: Path) -> tuple[list[Shot], float]:
    """4つの時点のコマを描いて、顔を見る。返すのは (コマ, 尺)。"""
    renderer = PreviewRenderer(p.config, work_dir)
    entries = renderer.frame_entries(p.script, p.inserts)
    total = sum(seconds for _, seconds in entries)
    segments = renderer.background_segments(p.script, p.inserts) if renderer.over_video else []
    shots: list[Shot] = []
    found_on: dict[int, list] = {}     # 同じ写真の絵で顔を探し直さない（1回1〜4秒かかる）
    for label, at in marks(p.script, total, p.short):
        cursor = 0.0
        item = entries[-1][0]
        for candidate, seconds in entries:
            if at < cursor + seconds:
                item = candidate
                break
            cursor += seconds
        with Image.open(renderer.realize(item)) as opened:
            layer = opened.convert("RGBA")
        # 写真を敷いた行のコマは不透明なので、背景の動画からコマを抜かなくてよい（1コマ数秒かかる）
        if renderer.over_video and layer.getchannel("A").getextrema()[0] < 255:
            picture = renderer.background_at(segments, at).convert("RGBA")
            picture.alpha_composite(layer)
        else:
            picture = layer
        picture = picture.convert("RGB")
        shot = Shot(label, at, picture)
        if faces.available():
            base, exact = renderer.photo_layer(item, segments, at)
            if base is not None and base.size != picture.size:
                base, exact = None, False
            if base is not None and id(base) not in found_on:
                # 写真だけの絵は、ふだんより厳しく探す（板の下は人の目で確かめられないので、
                # 足や服を顔と取ると「顔に字幕がかかる」が誤って出る。ポルトガルの冒頭で起きた）。
                # 同じ写真が続けば探し直さない
                found_on[id(base)] = faces.find_faces(base, neighbors=BASE_NEIGHBORS)
            seen = faces.find_faces(picture)
            if exact:
                # 写真を敷いた行：写真だけの絵で見つけた顔（板で隠れた顔も入る）＋コマで見つけた顔
                shot.own = list(found_on[id(base)])
                shot.own += [b for b in seen if not _overlaps(b, shot.own)]
            else:
                shot.own = seen
                if base is not None:
                    shot.extra = [(b, None) for b in found_on[id(base)] if not _overlaps(b, shot.own)]
            shot.found = judge(picture, label, shot.own, shot.extra)
            if exact:
                shot.found += covered(picture, base, shot.own, shot.found)
        shots.append(shot)
    return shots, total


# ---------------------------------------------------------------- 並べる


def _font(size: int):
    try:
        return ImageFont.truetype(str(load_config().video.font_path()), size)
    except Exception:
        return ImageFont.load_default()


def _wrap(draw, text: str, font, width: int) -> list[str]:
    rows, row = [], ""
    for ch in text:
        if draw.textlength(row + ch, font=font) > width and row:
            rows.append(row)
            row = ch
        else:
            row += ch
    if row:
        rows.append(row)
    return rows


def _boxed(shot: Shot) -> Image.Image:
    im = shot.image.copy()
    d = ImageDraw.Draw(im)
    for box, color in [(b, (255, 40, 40)) for b in shot.own] + [(b, (255, 160, 0)) for b, _ in shot.extra]:
        x, y, w, h = box
        d.rectangle([x, y, x + w, y + h], outline=color, width=5)
        hx, hy, hw, hh = faces.head_box(box)
        d.rectangle([hx, hy, hx + hw, hy + hh], outline=(40, 220, 40), width=3)
    return im


def sheet(shots: list[Shot], title: str, note: str, path: Path) -> Path:
    """コマを1枚に並べる。各コマの下に × / △ を書く。"""
    portrait = shots[0].image.height > shots[0].image.width
    cols = 4 if portrait else 2
    tiles = []
    for shot in shots:
        im = _boxed(shot)
        im.thumbnail((TILE * 9 // 16 if portrait else TILE, TILE if portrait else TILE * 9 // 16))
        tiles.append(im)
    tw = max(im.width for im in tiles)
    th = max(im.height for im in tiles)
    font, small, head = _font(18), _font(15), _font(20)
    probe = ImageDraw.Draw(Image.new("RGB", (8, 8)))
    notes = []
    for shot in shots:
        rows = []
        for mark, text in shot.found or [("✓", "顔に板なし・頭の切れなし" if faces.available()
                                         else "顔の判定なし（OpenCV が無い）")]:
            rows += _wrap(probe, f"{mark} {text}", small, tw - 8)
        notes.append(rows)
    text_h = max(len(r) for r in notes) * 19 + 6
    rows = (len(shots) + cols - 1) // cols
    cell_h = 26 + th + text_h
    top = 58
    out = Image.new("RGB", (8 + cols * (tw + 8), top + rows * (cell_h + 8)), (12, 12, 12))
    draw = ImageDraw.Draw(out)
    draw.text((10, 6), title, fill=(255, 213, 74), font=head)
    draw.text((10, 32), note, fill=(190, 200, 216), font=small)
    for i, (shot, im, lines) in enumerate(zip(shots, tiles, notes)):
        x = 8 + (i % cols) * (tw + 8)
        y = top + (i // cols) * (cell_h + 8)
        bad = any(m == "×" for m, _ in shot.found)
        mark = "×" if bad else ("△" if shot.found else "✓")
        draw.text((x + 2, y + 2), f"{mark} {shot.label}（{shot.at:.1f}秒）", font=font,
                  fill=(255, 90, 90) if bad else (240, 240, 240))
        out.paste(im, (x, y + 26))
        for k, row in enumerate(lines):
            color = (255, 120, 120) if row.startswith("×") else (255, 200, 120) if row.startswith("△") else (150, 220, 150)
            draw.text((x + 4, y + 26 + th + 4 + k * 19), row, font=small, fill=color)
    path.parent.mkdir(parents=True, exist_ok=True)
    out.save(path)
    return path


# ---------------------------------------------------------------- 入口


@dataclass
class Result:
    path: Path
    short: bool
    total: float
    seconds: float
    shots: list[Shot]
    real_lines: int
    lines: int

    @property
    def problems(self) -> list[tuple[str, str, str]]:
        """[(コマの名前, 印, 文), ...]（facecheck.check と同じ形）。"""
        return [(f"{s.label}（{s.at:.1f}秒）", m, t) for s in self.shots for m, t in s.found]


@contextmanager
def _at_root():
    """写真の相対パス（assets/images/…）は ROOT から見る。shorts.stacked_photo などがそう書いている。"""
    before = Path.cwd()
    os.chdir(ROOT)
    try:
        yield
    finally:
        os.chdir(before)


def preview(script_path: str | Path, short: bool = False, section: str = "",
            out_path: Path | None = None, use_audio: bool = True) -> Result:
    began = time.perf_counter()
    script_path = Path(script_path).resolve()
    with _at_root(), tempfile.TemporaryDirectory(prefix="preview4_") as tmp:
        work = Path(tmp)
        p = plan(script_path, short=short, section=section, work_dir=work, use_audio=use_audio)
        shots, total = shoot(p, work)
        kind = "ショート" if short else "本編"
        title = f"{p.out_dir.name}　{kind}の下見（書き出す前）"
        source = (f"声の実尺 {p.real_lines}/{p.lines}行" if p.real_lines else "声は見積り")
        cut = f"・上限で{p.dropped}行落とす" if p.dropped else ""
        note = (f"尺 約{int(total // 60)}分{int(total % 60):02d}秒（{source}{cut}）"
                "　時刻は見積りなので実物と数秒ずれる。絵の作りは書き出しと同じ")
        path = sheet(shots, title, note, out_path or (p.out_dir / "preview4.png"))
    return Result(path, short, total, time.perf_counter() - began, shots, p.real_lines, p.lines)


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("scripts", nargs="+", help="台本（scripts/<名前>.md）")
    kind = ap.add_mutually_exclusive_group()
    kind.add_argument("--short", action="store_true", help="ショートだけ")
    kind.add_argument("--main", action="store_true", help="本編だけ")
    ap.add_argument("--section", default="", help="ショートに切り出す節（short --section と同じ）")
    ap.add_argument("--open", action="store_true", help="作ったら開く")
    ap.add_argument("--estimate", action="store_true",
                    help="書き出し済みの声の長さを使わず、見積りだけで組む（見積りのずれを確かめるとき）")
    ap.add_argument("--out", help="絵の置き先（既定は output/<名前>/preview4.png。台本1本・種類1つのときだけ）")
    args = ap.parse_args(argv)
    kinds = [True] if args.short else [False] if args.main else [False, True]
    if not faces.available():
        print("※ 顔の検出が使えません（`pip install opencv-python-headless==4.14.0.94`）。絵だけ作ります")
    bad = 0
    made = []
    for script in args.scripts:
        for is_short in kinds:
            try:
                result = preview(script, short=is_short, section=args.section, use_audio=not args.estimate,
                                 out_path=Path(args.out) if args.out else None)
            except shorts.ShortError as error:
                print(f"× {Path(script).name} ショート: {error}")
                bad += 1
                continue
            made.append(result.path)
            kind = "ショート" if is_short else "本編"
            print(f"{Path(script).stem}　{kind}　約{result.total:.0f}秒　（{result.seconds:.1f}秒で作成）")
            for shot in result.shots:
                name = f"{shot.label}（{shot.at:.1f}秒）"
                if not shot.found:
                    print(f"  ✓ {name}")
                for mark, text in shot.found:
                    print(f"  {mark} {name} {text}")
            print(f"  絵: {result.path}", flush=True)
            bad += any(m == "×" for _, m, _ in result.problems)
    if args.open:
        for path in made:
            subprocess.run(["cmd", "/c", "start", "", str(path)], capture_output=True)
    return 1 if bad else 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))

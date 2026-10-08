# -*- coding: utf-8 -*-
"""出来上がった動画を通しで点検する（2026-10-08、別チャンネル「歴史の地層」の qc から移した）。

    python tools/qc.py output/20261008_xxx                      # 本編1本
    python tools/qc.py output/20261008_xxx output/20261008_xxx_short
    python tools/qc.py output/20261008_xxx --every 15           # 何秒ごとにコマを抜くか（既定 本編20・ショート5）
    python tools/qc.py output/20261008_xxx --scene 0.12 --open

**なぜ要るか。**ここにある見る道具は `tools/frames.py`（4コマ）と
`tools/preview4.py`（書き出す前の4コマ）だけだった。シリーズの本編は4〜6分あるので、
4コマでは**途中で止まっている区間**も**途中の崩れ**も見つけられない。実際に
「表が途中で非表示に」「写真が替わる瞬間に下地が出る」「表が毎回開き直し」は、
どれも公開したあとにユーザーが見つけている。

**`python -m src.cli review` と重ならないようにしてある。**review が見るのは
台本（script.json）の上の「見た目の変化」で、**書き出した絵そのものは見ていない**。
qc は出来上がった mp4 を見て、本当に画面が動いていない区間を測る。
音の大きさと字幕の終わりは review と同じ物差しだが、同じ1回の読み取りから
ただで付いてくるので控えには書く（判定の文にも「review と同じ」と添える）。

出すもの:

- `output/<名前>/qc.png` … `--every` 秒ごとのコマを1枚に並べた一覧。節ごとに段を分け、
  各コマに時刻を焼き込む。上限を超えて止まっている区間のコマは赤い枠で囲む
- `output/<名前>/qc.md` … 日本語の控え
- 標準出力に要点。上限超えは ×・惜しいものは △。× があれば終了コード1

**動画は1回だけ読む**（`src.ffmpeg.scan`）。1本40〜50MB あるので、scene 検出・音・コマ抜きで
3回起こすとその回数ぶん丸ごと読み直すことになる。本編1本で約19秒、ショートで約5秒。

**見逃し**（分かっているもの。だから一覧の画像を目で見る）:

- **ffmpeg の scene は明るさだけを見る。**同じ構図で色だけ替わる差し替え
  （青いユニフォーム → 赤いユニフォーム。どちらも芝の上）は 0.064、
  暗い板どうしの差し替えは 0.046 にしかならず、テロップの変わり目（0.04〜0.08）と区別が付かない。
  その分、止まっている区間が**実際より長く**出ることがある（2つの区間が1つに繋がる）。
  短いほうに倒れることは無いので、× は信じてよい。長さは一覧の画像で確かめる
- **語りの切れ目は RMS の中央値を基準にする。**語りがほとんど無い回（紹介の板だけの回）では
  中央値そのものが下がるので、境も一緒に下がる
- 字幕・音の2つは review と同じ物差しなので、**qc で直しても review を通し直す**
"""
from __future__ import annotations

import argparse
import json
import re
import statistics
import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from src import ffmpeg as ff  # noqa: E402
from src.review import (  # noqa: E402
    SAME_SCREEN_MAX,
    SHORT_CARD_HOLD_MAX,
    TAIL_SILENCE_MAX,
    TAIL_SILENCE_MAX_MAIN,
)

# コマを抜く間隔（秒）。本編は4〜6分なので20秒で15〜18コマ、ショートは1分なので5秒で12コマ
STEP_MAIN = 20.0
STEP_SHORT = 5.0

# 画面が「大きく変わった」とみなす scene の点数。
# 2026-10-08 に output/20261008_record_pedro（本編4:47・ショート0:54）で点数の分布を測った:
#   本編 中央値 0.012 / 上8割 0.073 / 上9割 0.087 / 最大 0.47。
# テロップだけが変わった行は 0.01〜0.07 に入り、写真・表が替わると 0.08 を超える。
# 0.12 まで上げると「108秒変わらない」と出てしまい（実際は写真が替わっている）、
# 0.04 まで下げるとテロップの変わり目を全部拾って最長6秒になり、どちらも使えない。
# **ショートは 0.06**。縦の画面は写真が全面なのに、同じ構図で色だけ替わる差し替え
# （青いユニフォーム → 赤いユニフォーム。どちらも芝の上）が 0.064 にしかならず、
# 0.08 では 0:06〜0:24 の18秒を1区間に繋げてしまった。0.06 なら 11.8秒＋10.6秒に割れる
SCENE = 0.08
SCENE_SHORT = 0.06

# 語りの切れ目（長い無音）。**BGM が -22dB で鳴っているので silencedetect は使えない**
# （2026-10-08 実測：-45dB・-35dB では1件も出ない）。0.5秒ごとの RMS を測り、
# その中央値（＝語っている大きさ。実測 -17.6dB）から下に QUIET_GAP だけ落ちた区間を切れ目とみなす。
# 実測では -29.6dB が境になり、2秒以上の切れ目は終了画面の中だけだった
QUIET_GAP = 12.0
QUIET_BAD = 2.0    # これ以上続けば ×
QUIET_NEAR = 1.5   # これ以上続けば △

TARGET_LUFS = -14.0   # YouTube の基準（review の _loudness と同じ）
LUFS_BAD = 2.0        # review が × にする幅
LUFS_NEAR = 1.0

NEAR = 0.8            # 上限のこの割合を超えたら △

THUMB_BOX = 320       # 一覧の1コマの長い辺
PAD = 6
HEAD = 40
BACK = (18, 18, 20)
BAND = (214, 178, 110)
ALERT = (228, 72, 72)


# --- ffmpeg の出力を読む（本物の動画なしで試せるように、文字列から取り出すだけにしてある） ----

_LOG = re.compile(r"^\[(?P<tag>Parsed_\w+) @ [^\]]*\]\s*(?P<body>.*)$")


def metadata_pairs(stderr: str, key: str) -> list[tuple[float, float]]:
    """metadata / ametadata の出力から (時刻, 値) を取り出す。

    絵の枝と音の枝が同時に流れるので行が入り混じる。`[Parsed_metadata_4 @ …]` の
    **名札ごとに直前の pts_time を覚えて**組にする（隣の行と素朴に組むと、
    絵の時刻に音の値がくっつく）。
    """
    last: dict[str, float] = {}
    out: list[tuple[float, float]] = []
    want = re.compile(re.escape(key) + r"=(-?(?:\d+(?:\.\d+)?|inf|nan))")
    for raw in stderr.splitlines():
        found = _LOG.match(raw.strip())
        if not found:
            continue
        tag, body = found.group("tag"), found.group("body")
        at = re.search(r"pts_time:\s*(\d+(?:\.\d+)?)", body)
        if at:
            last[tag] = float(at.group(1))
            continue
        value = want.search(body)
        if value and tag in last:
            text = value.group(1)
            if text.endswith("nan"):
                continue
            if text.endswith("inf"):
                number = float("-inf") if text.startswith("-") else float("inf")
            else:
                number = float(text)
            out.append((last[tag], number))
    return out


def parse_scene_scores(stderr: str) -> list[tuple[float, float]]:
    """画面の変化の点数 (時刻, 0〜1)。"""
    return metadata_pairs(stderr, "lavfi.scene_score")


def parse_levels(stderr: str) -> list[tuple[float, float]]:
    """刻みごとの音の大きさ (時刻, RMS dB)。"""
    return metadata_pairs(stderr, "lavfi.astats.Overall.RMS_level")


def parse_frame_times(stderr: str) -> list[float]:
    """一覧に並べるコマが**何秒のコマか**（showinfo の出力）。

    番号×間隔と決め打ちにすると、コマが1枚落ちただけで以降の時刻が全部ずれる。
    焼き込む時刻がずれた一覧は、見る道具として使えない。
    """
    return [float(at) for at in
            re.findall(r"Parsed_showinfo[^\]]*\][^\n]*?pts_time:\s*(\d+(?:\.\d+)?)", stderr)]


def parse_loudnorm(stderr: str) -> dict:
    """loudnorm の測定値。出力の最後のかたまりを使う。"""
    last = None
    for found in re.finditer(r"\{[^{}]*\"input_i\"[^{}]*\}", stderr):
        last = found
    if last is None:
        return {}
    try:
        raw = json.loads(last.group(0))
    except json.JSONDecodeError:
        return {}
    out = {}
    for key in ("input_i", "input_tp", "input_lra", "input_thresh"):
        try:
            out[key] = float(raw[key])
        except (KeyError, TypeError, ValueError):
            pass
    return out


def parse_srt(text: str) -> list[tuple[float, float]]:
    """字幕の (始まり, 終わり) の並び。"""
    def seconds(stamp: str) -> float:
        hours, minutes, rest = stamp.split(":")
        return int(hours) * 3600 + int(minutes) * 60 + float(rest.replace(",", "."))

    return [
        (seconds(a), seconds(b))
        for a, b in re.findall(r"(\d+:\d+:\d+,\d+)\s*-->\s*(\d+:\d+:\d+,\d+)", text)
    ]


# --- 数える -------------------------------------------------------------------------

def still_runs(scores: list[tuple[float, float]], duration: float,
               threshold: float = SCENE) -> list[tuple[float, float]]:
    """画面が大きく変わらない区間 (始まり, 長さ)。変わった時刻で尺を切るだけ。"""
    if duration <= 0:
        return []
    cuts = [0.0]
    cuts += sorted(t for t, score in scores if score > threshold and 0.0 < t < duration)
    cuts.append(duration)
    return [(a, b - a) for a, b in zip(cuts, cuts[1:]) if b - a > 0]


def quiet_floor(levels: list[tuple[float, float]], gap: float = QUIET_GAP) -> float | None:
    """ここより小さければ「語っていない」とみなす大きさ（dB）。語りの中央値から下に gap。"""
    usable = [db for _, db in levels if db > float("-inf")]
    if not usable:
        return None
    return statistics.median(usable) - gap


def quiet_runs(levels: list[tuple[float, float]], duration: float, floor: float,
               window: float = ff.SCAN_WINDOW) -> list[tuple[float, float]]:
    """語りが止まっている区間 (始まり, 長さ)。刻みは [時刻, 時刻+window) を覆う。"""
    runs: list[tuple[float, float]] = []
    start: float | None = None
    end = 0.0
    for at, db in levels:
        if db < floor:
            if start is None:
                start = at
            end = min(duration, at + window) if duration > 0 else at + window
        elif start is not None:
            runs.append((start, end - start))
            start = None
    if start is not None:
        runs.append((start, end - start))
    return [(s, d) for s, d in runs if d > 0]


def sections_from_script(data: dict) -> list[tuple[float, str]]:
    """節の始まりの時刻と題。script.json の各節の最初の行の `start` から取る。

    `start` が無い古い書き出しは `duration` を積んで数える。
    """
    out: list[tuple[float, str]] = []
    running = 0.0
    for number, scene in enumerate(data.get("scenes") or [], start=1):
        lines = scene.get("lines") or []
        if not lines:
            continue
        head = lines[0].get("start")
        start = float(head) if head is not None else running
        title = (scene.get("title") or "").strip()
        label = f"第{number}節 {title}".strip()
        if scene.get("main") or scene.get("is_main"):
            label += "（山場）"
        if scene.get("viewpoint"):
            label += "（見立て）"
        out.append((start, label))
        for line in lines:
            running += float(line.get("duration") or 0.0)
    return out


def clock(at: float) -> str:
    at = int(round(max(0.0, at)))
    hours, rest = divmod(at, 3600)
    minutes, seconds = divmod(rest, 60)
    return f"{hours}:{minutes:02}:{seconds:02}" if hours else f"{minutes}:{seconds:02}"


def section_at(sections: list[tuple[float, str]], at: float) -> str:
    name = ""
    for start, label in sections:
        if start <= at + 1e-6:
            name = label
    return name


def still_limit(portrait: bool) -> float:
    """見た目が変わらないままでよい上限（秒）。src/review.py の決まりをそのまま使う。"""
    return SHORT_CARD_HOLD_MAX if portrait else SAME_SCREEN_MAX


def tail_limit(portrait: bool) -> float:
    """読み上げの終わりから動画の終わりまで、許す無音（秒）。review の決まりと同じ。"""
    return TAIL_SILENCE_MAX if portrait else TAIL_SILENCE_MAX_MAIN


# --- 点検の結果 ---------------------------------------------------------------------

@dataclass
class Finding:
    mark: str          # ○ △ ×
    label: str
    detail: str = ""
    extra: list[str] = field(default_factory=list)

    def line(self) -> str:
        return f"{self.mark} {self.label}" + (f"　{self.detail}" if self.detail else "")


@dataclass
class Report:
    name: str
    duration: float
    portrait: bool
    step: float
    scene: float = SCENE
    outro: float = 0.0
    scores: list[tuple[float, float]] = field(default_factory=list)
    levels: list[tuple[float, float]] = field(default_factory=list)
    loud: dict = field(default_factory=dict)
    subs_end: float | None = None
    sections: list[tuple[float, str]] = field(default_factory=list)


def judge(rep: Report) -> list[Finding]:
    """上限と突き合わせて ○△× を付ける。"""
    found: list[Finding] = []

    # ① 画面が大きく変わらない区間（qc だけが見る。review は台本の上でしか数えていない）
    limit = still_limit(rep.portrait)
    runs = still_runs(rep.scores, rep.duration, rep.scene)
    label = f"画面が大きく変わらない区間（scene>{rep.scene:g}）"
    if runs:
        lengths = [d for _, d in runs]
        over = [r for r in runs if r[1] > limit]
        near = [r for r in runs if limit * NEAR < r[1] <= limit]
        mark = "×" if over else ("△" if near else "○")
        detail = (f"{len(runs)}区間・中央値 {statistics.median(lengths):.1f}秒・"
                  f"最長 {max(lengths):.1f}秒（上限 {limit:.0f}秒）・超え {len(over)}か所")
        extra = []
        for start, length in sorted(runs, key=lambda r: -r[1])[:5]:
            tag = "　← 上限超え" if length > limit else ("　← 惜しい" if length > limit * NEAR else "")
            # 節は区間の**真ん中**で引く（節の変わり目にかかる区間が前の節の名前になる）
            extra.append(f"{clock(start)}〜{clock(start + length)}（{length:.0f}秒）"
                         f"{section_at(rep.sections, start + length / 2)}{tag}")
        found.append(Finding(mark, label, detail, extra))
    else:
        found.append(Finding("×", label, "画面の変化を読み取れませんでした"))

    # ② 字幕の終わりと尺の差（本編の最後は終了画面の置き場なので、そのぶんは差として数えない）
    expect = 0.0 if rep.portrait else rep.outro
    allowed = tail_limit(rep.portrait)
    if rep.subs_end is None:
        found.append(Finding("×", "字幕の終わりと尺の差", "subtitles.srt が読めませんでした"))
    else:
        gap = rep.duration - rep.subs_end
        spare = gap - expect
        if gap > allowed or spare < -2.0:
            mark = "×"
        elif gap > expect + 0.9 * (allowed - expect):
            mark = "△"
        else:
            mark = "○"
        head = f"字幕 {clock(rep.subs_end)} / 動画 {clock(rep.duration)}・差 {gap:.1f}秒"
        if expect > 0:
            head += (f"（終了画面の置き場 {expect:.0f}秒を除くと {spare:+.1f}秒"
                     f"・上限 {allowed:.1f}秒）")
        else:
            head += f"（上限 {allowed:.1f}秒）"
        found.append(Finding(mark, "字幕の終わりと尺の差",
                             head + "　review の『末尾の無音』と同じ物差し"))

    # ③ 音の大きさ（review と同じ数字。1回の読み取りから付いてくるので控えに残す）
    measured = rep.loud.get("input_i")
    if measured is None:
        found.append(Finding("△", "音の大きさ", "測れませんでした（音の無い動画かもしれません）"))
    else:
        off = measured - TARGET_LUFS
        mark = "×" if abs(off) > LUFS_BAD else ("△" if abs(off) > LUFS_NEAR else "○")
        bits = [f"{measured:.1f} LUFS（基準 {TARGET_LUFS:.0f}、差 {off:+.1f} dB）"]
        if "input_tp" in rep.loud:
            bits.append(f"最大 {rep.loud['input_tp']:.1f} dBTP")
        if "input_lra" in rep.loud:
            bits.append(f"幅 {rep.loud['input_lra']:.1f} LU")
        found.append(Finding(mark, "音の大きさ",
                             "・".join(bits) + "　review の『音の大きさ』と同じ物差し"))

    # ④ 語りが止まっている区間（review は末尾しか見ていない。途中の空きは qc だけが見る）
    floor = quiet_floor(rep.levels)
    if floor is None:
        found.append(Finding("△", "語りの切れ目", "音の大きさを刻みで測れませんでした"))
    else:
        runs = quiet_runs(rep.levels, rep.duration, floor)
        edge = rep.subs_end if rep.subs_end is not None else rep.duration
        body = [(s, d) for s, d in runs if s < edge - 0.5 and d >= QUIET_NEAR]
        tail = [(s, d) for s, d in runs if s >= edge - 0.5 and d >= QUIET_NEAR]
        bad = [r for r in body if r[1] >= QUIET_BAD]
        mark = "×" if bad else ("△" if body else "○")
        detail = (f"{QUIET_NEAR:.1f}秒以上の切れ目 {len(body)}か所"
                  f"（{QUIET_BAD:.0f}秒以上 {len(bad)}か所・境は {floor:.1f} dB）")
        if tail:
            detail += f"　ほかに終了画面の中に {len(tail)}か所"
        extra = [f"{clock(s)}（{d:.1f}秒）{section_at(rep.sections, s)}"
                 + ("　← 長い" if d >= QUIET_BAD else "")
                 for s, d in sorted(body, key=lambda r: -r[1])[:5]]
        found.append(Finding(mark, "語りの切れ目", detail, extra))

    return found


# --- 一覧の画像 ---------------------------------------------------------------------

def thumb_size(width: int, height: int, box: int = THUMB_BOX) -> tuple[int, int]:
    """一覧の1コマの大きさ。縦型は縦を box に合わせる（横型と同じ幅にすると潰れる）。"""
    if width <= 0 or height <= 0:
        return box, box * 9 // 16

    def even(value: float) -> int:
        return max(2, int(round(value / 2)) * 2)

    if width >= height:
        return box, even(box * height / width)
    return even(box * width / height), box


def _font(path: str | None, size: int):
    from PIL import ImageFont
    if path:
        try:
            return ImageFont.truetype(path, size)
        except OSError:
            pass
    try:
        return ImageFont.load_default(size)
    except TypeError:  # pragma: no cover - 古い Pillow
        return ImageFont.load_default()


def bands(frames: list, sections: list[tuple[float, str]]) -> list[tuple[str, list]]:
    """コマを節ごとの段に分ける。節が読めなければ1段にまとめる。"""
    starts = list(sections) or [(0.0, "（節が読めませんでした）")]
    out: list[tuple[str, list]] = []
    for index, (start, label) in enumerate(starts):
        end = starts[index + 1][0] if index + 1 < len(starts) else float("inf")
        low = -1.0 if index == 0 else start
        out.append((label, [(at, image) for at, image in frames if low <= at < end]))
    return out


def sheet(frames: list, sections: list[tuple[float, str]], *, title: str = "",
          alerts: list[tuple[float, float]] | None = None, font_path: str | None = None,
          cols: int | None = None):
    """コマを1枚に並べる。節ごとに段を分け、各コマに時刻を焼き込み、停滞の区間は赤枠。"""
    from PIL import Image, ImageDraw

    if not frames:
        raise ValueError("並べるコマがありません")
    width, height = frames[0][1].size
    groups = [(label, tiles) for label, tiles in bands(frames, sections) if tiles]
    # 段ごとのコマ数は節の長さで決まる。いちばん多い段に合わせて畳む（右の余白を作らない）
    cols = cols or min(10 if height > width else 8, max(len(tiles) for _, tiles in groups))
    rows = sum(max(1, (len(tiles) + cols - 1) // cols) for _, tiles in groups)
    sheet_w = cols * (width + PAD) + PAD
    sheet_h = HEAD + len(groups) * HEAD + rows * (height + PAD) + PAD
    out = Image.new("RGB", (sheet_w, sheet_h), BACK)
    draw = ImageDraw.Draw(out)
    head_font, tile_font = _font(font_path, 24), _font(font_path, 18)
    draw.text((PAD + 4, PAD + 6), title, font=head_font, fill=(240, 240, 240))
    y = HEAD + PAD
    spans = alerts or []
    for label, tiles in groups:
        draw.text((PAD + 4, y + 6), label, font=head_font, fill=BAND)
        y += HEAD
        for index, (at, image) in enumerate(tiles):
            x = PAD + (index % cols) * (width + PAD)
            top = y + (index // cols) * (height + PAD)
            out.paste(image, (x, top))
            hot = any(start <= at < start + length for start, length in spans)
            if hot:
                draw.rectangle([x, top, x + width - 1, top + height - 1], outline=ALERT, width=4)
            stamp = clock(at) + ("　停滞" if hot else "")
            box = tile_font.getlength(stamp) + 12
            draw.rectangle([x, top + height - 24, x + box, top + height], fill=(0, 0, 0))
            draw.text((x + 6, top + height - 22), stamp, font=tile_font,
                      fill=ALERT if hot else (255, 255, 255))
        y += max(1, (len(tiles) + cols - 1) // cols) * (height + PAD)
    return out


# --- 1本を点検する -------------------------------------------------------------------

def scene_limit(portrait: bool) -> float:
    """画面が大きく変わったとみなす点数。縦型は低め（上の SCENE の注記）。"""
    return SCENE_SHORT if portrait else SCENE


def read_build(build_dir: Path, *, every: float | None = None, scene: float | None = None,
               outro: float | None = None) -> tuple[Report, list]:
    """動画を1回読んで Report と一覧のコマを作る。コマは (時刻, PIL 画像) の並び。"""
    from PIL import Image

    build_dir = Path(build_dir)
    video = build_dir / "video.mp4"
    if not video.exists():
        raise FileNotFoundError(f"動画がありません: {video}")
    info = ff.probe(video) or {}
    duration = float(info.get("duration") or 0.0)
    width, height = int(info.get("width") or 0), int(info.get("height") or 0)
    portrait = height > width > 0
    step = float(every) if every else (STEP_SHORT if portrait else STEP_MAIN)
    if outro is None:
        try:
            from src.config import load_config
            outro = 0.0 if portrait else float(load_config().titles.outro)
        except Exception:
            outro = 0.0

    thumb = thumb_size(width, height)
    err, raw = ff.scan(video, step=step, thumb=thumb, audio=bool(info.get("audio", True)))

    size = thumb[0] * thumb[1] * 3
    count = len(raw) // size
    stamps = parse_frame_times(err)
    frames = [(stamps[index] if index < len(stamps) else index * step,
               Image.frombytes("RGB", thumb, raw[index * size:(index + 1) * size]))
              for index in range(count)]

    rep = Report(
        name=build_dir.name,
        duration=duration,
        portrait=portrait,
        step=step,
        scene=scene_limit(portrait) if scene is None else float(scene),
        outro=float(outro),
        scores=parse_scene_scores(err),
        levels=parse_levels(err),
        loud=parse_loudnorm(err),
    )

    subs = build_dir / "subtitles.srt"
    if subs.exists():
        cues = parse_srt(subs.read_text(encoding="utf-8"))
        rep.subs_end = cues[-1][1] if cues else None
    meta = build_dir / "script.json"
    if meta.exists():
        try:
            rep.sections = sections_from_script(json.loads(meta.read_text(encoding="utf-8")))
        except (json.JSONDecodeError, ValueError, TypeError):
            rep.sections = []
    return rep, frames


def markdown(rep: Report, findings: list[Finding], png: Path | None) -> str:
    """日本語の控え。"""
    kind = "ショート" if rep.portrait else "本編"
    lines = [
        f"# 動画の点検：{rep.name}",
        "",
        f"- {kind}・長さ {clock(rep.duration)}（{rep.duration:.1f}秒）・コマは{rep.step:.0f}秒ごと",
    ]
    if rep.sections:
        lines.append(f"- 節 {len(rep.sections)}個：" + "／".join(
            f"{clock(start)} {label}" for start, label in rep.sections))
    lines += ["", "## 結果", ""]
    for finding in findings:
        lines.append(f"- {finding.line()}")
        lines += [f"  - {text}" for text in finding.extra]
    lines += ["", "## 一覧", ""]
    lines.append(f"![一覧]({png.name})" if png else "（一覧の画像は作れませんでした）")
    lines += [
        "",
        "## 読み方",
        "",
        "- 「画面が大きく変わらない区間」と「語りの切れ目」は、"
        "`python -m src.cli review` が見ていないもの（review は台本の上で数える）。ここが qc の本体",
        "- 「字幕の終わりと尺の差」「音の大きさ」は review と同じ物差し。"
        "1回の読み取りから付いてくるので控えに残してある",
        "- 一覧の赤い枠は、上限を超えて画面が止まっている区間に入っているコマ",
        "- **一覧は目で見る。**ffmpeg の画面の変化は明るさだけを見るので、"
        "同じ構図で色だけ替わる差し替えを見落とし、止まっている区間が実際より長く出ることがある",
    ]
    return "\n".join(lines) + "\n"


def inspect(build_dir: Path, *, every: float | None = None, scene: float | None = None,
            outro: float | None = None) -> tuple[Report, list[Finding], Path | None]:
    """1本を点検して qc.png と qc.md を書く。"""
    build_dir = Path(build_dir)
    rep, frames = read_build(build_dir, every=every, scene=scene, outro=outro)
    findings = judge(rep)

    png: Path | None = None
    if frames:
        limit = still_limit(rep.portrait)
        alerts = [r for r in still_runs(rep.scores, rep.duration, rep.scene) if r[1] > limit]
        try:
            from src.config import load_config
            font = str(load_config().video.font_path())
        except Exception:
            font = None
        kind = "ショート" if rep.portrait else "本編"
        title = f"{rep.name}　{kind} {clock(rep.duration)}　{rep.step:.0f}秒ごと"
        png = build_dir / "qc.png"
        sheet(frames, rep.sections, title=title, alerts=alerts, font_path=font).save(png)

    (build_dir / "qc.md").write_text(markdown(rep, findings, png), encoding="utf-8")
    return rep, findings, png


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="出来上がった動画を通しで点検する")
    parser.add_argument("dirs", nargs="+", help="build の出力先（output/<名前>）")
    parser.add_argument("--every", type=float, default=None,
                        help="何秒ごとにコマを抜くか（既定 本編20・ショート5）")
    parser.add_argument("--scene", type=float, default=None,
                        help=f"画面が大きく変わったとみなす scene の点数"
                             f"（既定 本編{SCENE}・ショート{SCENE_SHORT}）")
    parser.add_argument("--open", action="store_true", help="作った一覧を開く")
    args = parser.parse_args(argv)

    made: list[Path] = []
    bad = 0
    for target in args.dirs:
        build_dir = Path(target)
        print(f"\n■ {build_dir}")
        try:
            rep, findings, png = inspect(build_dir, every=args.every, scene=args.scene)
        except (FileNotFoundError, ff.FfmpegError, ValueError) as error:
            print(f"  × {error}")
            bad += 1
            continue
        kind = "ショート" if rep.portrait else "本編"
        print(f"  {kind}・長さ {clock(rep.duration)}・コマは{rep.step:.0f}秒ごと")
        for finding in findings:
            print(f"  {finding.line()}")
            for text in finding.extra:
                print(f"      {text}")
            if finding.mark == "×":
                bad += 1
        print(f"  控え {build_dir / 'qc.md'}")
        if png:
            print(f"  一覧 {png}")
            made.append(png)

    if args.open:
        for path in made:
            subprocess.run(["cmd", "/c", "start", "", str(path)], capture_output=True)
    print("")
    print("× はありません" if bad == 0 else f"× が {bad} 件あります")
    return 1 if bad else 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))

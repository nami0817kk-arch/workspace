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

**台本と突き合わせて、板の中の変化を数に入れる**（2026-10-09）。ffmpeg の scene は
明るさだけを見るので、**暗い板の中で1行の色が変わっても点数が上がらない**（実測 0.046）。
10/9 に16本へ当てたら、本編1本とショート6本の × が出て、**絵を開くとほとんどが誤検知**だった
（`20261009_kit_liverpool_short` の 0:20〜0:45 は年表の光る行が 1987年 → 1993年 と動いている）。
いまは `script.json`（と元の台本の `cards`）を見て、区間の中で

1. 板の絵・写真（`image`）が別のファイルになった
2. カードの絵が替わった（`src.review.card_look`。光らせる行を外した中身で見分ける）
3. **`card_look` は同じで光らせる場所だけが違う**（`src.cards.HIGHLIGHT_KEYS`）＝板の光る行が動いた
4. 書き込み（赤ペン）の数が変わった

のどれかが起きていた時刻で**区間を割る**（`visual_moves` → `stalls`）。
**根拠が無い区間は割らない**（今までどおり × のまま）。短いほうには倒さない。
割った区間は控えと一覧に必ず出す（一覧は赤枠を出さず、金の枠と「光る行」などの札）。

**見逃し**（分かっているもの。だから一覧の画像を目で見る）:

- **ffmpeg の scene は明るさだけを見る。**同じ構図で色だけ替わる差し替え
  （青いユニフォーム → 赤いユニフォーム。どちらも芝の上）は 0.064、
  暗い板どうしの差し替えは 0.046 にしかならず、テロップの変わり目（0.04〜0.08）と区別が付かない。
  その分、止まっている区間が**実際より長く**出ることがある（2つの区間が1つに繋がる）。
  台本に根拠があればそこで割るが、**根拠が無ければ長いまま出る。**長さは一覧の画像で確かめる
- **台本の根拠は「画面が動いた」ことの証拠であって、「見ていて動いて見える」ことの証拠ではない。**
  光る行が1行ずつ動くだけの板が1分続けば、qc は ○ を返す（`review` の「カードの持ち」は
  逆に × を出す。あちらは光らせる行の差を一律「同じ絵」と数える）。**どちらも目で見て決める**
- **元の台本（`scripts/<名前>.md`）が書き出しのあとに直されていると、カードの中身がずれる。**
  名前が合わなければ名前で見分ける側に落ちる（`card_look` と同じ落とし方）
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

from src import cards as cards_mod  # noqa: E402
from src import ffmpeg as ff  # noqa: E402
from src.review import (  # noqa: E402
    SAME_SCREEN_MAX,
    SHORT_CARD_HOLD_MAX,
    TAIL_SILENCE_MAX,
    TAIL_SILENCE_MAX_MAIN,
    card_look,
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


# --- 台本に書いてある「画面が動いた」ところ -------------------------------------------

# カードの中身のうち、**光らせる場所だけを指す鍵**（src/cards.py の決まりをそのまま使う）。
# ここだけが違うカードは「同じ表」。`src.review.card_look` はこの鍵を外した中身で見分ける
HIGHLIGHT_KEYS = cards_mod.HIGHLIGHT_KEYS

# 区間の端にかかる変化では割らない（0秒の切れ端を作らない）
EDGE = 0.1


def card_specs(build_dir: Path) -> dict:
    """台本（`scripts/<名前>.md`）の frontmatter の `cards`。見つからなければ空。

    **書き出した script.json にはカードの名前しか残らない**ので、
    「光らせる行だけが違う同じ表」を見分けるには元の台本が要る
    （`src.review.inspect` も同じようにカードの中身を渡している）。
    ショート（`<名前>_short`）は本編の台本から切り出すので、同じファイルを見る。
    """
    import yaml

    name = Path(build_dir).name
    stem = name[: -len("_short")] if name.endswith("_short") else name
    here = Path(build_dir).resolve().parent.parent / "scripts"
    for folder in dict.fromkeys([here, ROOT / "scripts"]):
        path = folder / f"{stem}.md"
        if not path.exists():
            continue
        try:
            lines = path.read_text(encoding="utf-8").splitlines()
            if not lines or lines[0].strip() != "---":
                continue
            end = next((k for k in range(1, len(lines)) if lines[k].strip() == "---"), None)
            if end is None:
                continue
            meta = yaml.safe_load("\n".join(lines[1:end])) or {}
        except (OSError, UnicodeDecodeError, yaml.YAMLError):
            continue
        if isinstance(meta, dict) and isinstance(meta.get("cards"), dict):
            return dict(meta["cards"])
    return {}


def line_look(line: dict, specs: dict | None = None) -> dict:
    """台本の1行が**画面に出しているもの**。

    **言葉（テロップ）は入れない。**テロップは行ごとに変わるので、入れると
    「動いている」ことにならない（ffmpeg の点数でも 0.01〜0.07 しか上がらない
    ＝目には止まって見える）。見るのは絵・カードの絵・光らせる場所・書き込みの数。
    """
    name = str(line.get("card") or "").strip()
    spec = (specs or {}).get(name)
    hot = tuple(spec.get(key) for key in HIGHLIGHT_KEYS) if isinstance(spec, dict) else ()
    return {
        "name": "" if name in ("", "none", "なし") else name,
        "image": str(line.get("image") or ""),
        # 光らせる行を外したカードの中身（review.card_look）。中身が無ければ名前に落ちる
        "art": card_look(name, specs),
        "hot": json.dumps(hot, sort_keys=True, ensure_ascii=False, default=str),
        "marks": len(line.get("marks") or []),
        "known": isinstance(spec, dict),
    }


def _image_word(path: str) -> str:
    return "板の絵" if "stats" in Path(path).parts else "写真"


def move_reason(before: dict, after: dict) -> tuple[str, str]:
    """前の行との違いから「何が動いたか」。(控えに書く文, 一覧に添える短い札)。

    違いが無ければ `("", "")`。**言葉だけの違いは動いたことにしない**（`line_look`）。
    """
    whys: list[str] = []
    tags: list[str] = []
    if before["image"] != after["image"]:
        word = _image_word(after["image"] or before["image"])
        if not after["image"]:
            whys.append(f"{word}が下がった")
            tags.append(f"{word}下げ")
        else:
            whys.append(f"{word}が替わった（{Path(after['image']).name}）")
            tags.append(f"{word}替わり")
    if before["art"] != after["art"]:
        if not after["art"]:
            whys.append("カードが下がった")
            tags.append("カード下げ")
        elif not before["art"]:
            whys.append(f"カードが出た（{after['name']}）")
            tags.append("カード出")
        elif before["known"] and after["known"]:
            whys.append(f"板の絵そのものが替わった（{after['name']}）")
            tags.append("カード替わり")
        else:
            whys.append(f"カードが替わった（{after['name']}"
                        "・台本にカードの中身が無いので名前で見分けた）")
            tags.append("カード名替わり")
    elif before["hot"] != after["hot"]:
        # **card_look は同じで、光らせる場所だけが違う**＝暗い板の中で1行の色が変わった。
        # ffmpeg の scene は明るさだけを見るので点数が上がらない（実測 0.046）が、画面は動いている
        whys.append(f"カードの光る行・光る点が動いた（{after['name']}）")
        tags.append("光る行")
    if before["marks"] != after["marks"]:
        more = after["marks"] > before["marks"]
        whys.append("書き込み（赤ペン）が増えた" if more else "書き込みが消えた")
        tags.append("赤ペン")
    return "・".join(whys), "・".join(tags)


def visual_moves(data: dict, specs: dict | None = None) -> list[tuple[float, str, str]]:
    """台本の上で**画面が動いた時刻** (時刻, 控えに書く文, 一覧の札)。

    `start` が無い古い書き出しは長さを積んで数える（`sections_from_script` と同じ）。
    """
    out: list[tuple[float, str, str]] = []
    look: dict | None = None
    running = 0.0
    for scene in data.get("scenes") or []:
        for line in scene.get("lines") or []:
            head = line.get("start")
            at = float(head) if head is not None else running
            now = line_look(line, specs)
            if look is not None:
                why, tag = move_reason(look, now)
                if why:
                    out.append((at, why, tag))
            look = now
            running = at + float(line.get("duration") or 0.0)
    return out


@dataclass
class Stall:
    """画面が大きく変わらない1区間と、台本に根拠のある「動いた時刻」で割った中身。"""

    start: float
    length: float
    pieces: list[tuple[float, float]] = field(default_factory=list)
    moves: list[tuple[float, str, str]] = field(default_factory=list)

    @property
    def end(self) -> float:
        return self.start + self.length

    @property
    def worst(self) -> float:
        """割ったあとの最長。根拠が無ければ区間そのままの長さ。"""
        return max((d for _, d in self.pieces), default=self.length)


def stalls(scores: list[tuple[float, float]], duration: float, threshold: float = SCENE,
           moves: list[tuple[float, str, str]] | None = None) -> list[Stall]:
    """止まって見える区間を出し、**台本に根拠のある時刻で割る**。

    **なぜ要るか**（2026-10-09）。ffmpeg の scene は明るさだけを見るので、
    暗い板の中で1行の色が変わっても点数が上がらない（実測 0.046）。
    `output/20261009_kit_liverpool_short` の 0:20〜0:45 は年表の光る行が
    1987年 → 1993年 と動いているのに「停滞」と出ていた。台本に
    「板の絵が替わった」「光らせる行が替わった」と書いてあれば、そこで画面は動いている。

    **根拠が無い区間は割らない**（今までどおり × のまま）。短いほうには倒さない。
    """
    out: list[Stall] = []
    for start, length in still_runs(scores, duration, threshold):
        inside = sorted(at_why for at_why in (moves or [])
                        if start + EDGE < at_why[0] < start + length - EDGE)
        cuts = [start] + [at for at, _, _ in inside] + [start + length]
        pieces = [(a, b - a) for a, b in zip(cuts, cuts[1:]) if b - a > 0]
        out.append(Stall(start, length, pieces, list(inside)))
    return out


def sheet_notes(found: list[Stall], limit: float) -> list[tuple[float, float, str]]:
    """一覧に添える金の札 (始まり, 長さ, 札)。

    scene では止まって見えたが**台本では動いていた**切れ端だけを拾う。
    赤枠（上限を超えて残っている所）とは重ならない。
    """
    out: list[tuple[float, float, str]] = []
    for stall in found:
        if not stall.moves or stall.length <= limit:
            continue
        for (start, length), (_, _, tag) in zip(stall.pieces[1:], stall.moves):
            if length <= limit:
                out.append((start, length, tag))
    return out


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
    # 台本の上で画面が動いた時刻 (時刻, 控えの文, 一覧の札)。空なら今までどおりの数え方
    moves: list[tuple[float, str, str]] = field(default_factory=list)
    specs: int = 0        # 台本から読めたカードの中身の数（0 なら名前で見分けている）


def judge(rep: Report) -> list[Finding]:
    """上限と突き合わせて ○△× を付ける。"""
    found: list[Finding] = []

    # ① 画面が大きく変わらない区間（qc だけが見る。review は台本の上でしか数えていない）
    # **台本に根拠があれば、そこで区間を割る**（2026-10-09。`stalls`）
    limit = still_limit(rep.portrait)
    found_stalls = stalls(rep.scores, rep.duration, rep.scene, rep.moves)
    label = f"画面が大きく変わらない区間（scene>{rep.scene:g}）"
    if found_stalls:
        runs = [piece for stall in found_stalls for piece in stall.pieces]
        lengths = [d for _, d in runs]
        over = [r for r in runs if r[1] > limit]
        near = [r for r in runs if limit * NEAR < r[1] <= limit]
        mark = "×" if over else ("△" if near else "○")
        detail = (f"{len(runs)}区間・中央値 {statistics.median(lengths):.1f}秒・"
                  f"最長 {max(lengths):.1f}秒（上限 {limit:.0f}秒）・超え {len(over)}か所")
        # **黙って通さない。**台本の根拠で割った区間は、何か所あったかを必ず書く
        split = [stall for stall in found_stalls if stall.moves and stall.length > limit]
        if split:
            detail += (f"　台本の根拠で割った区間 {len(split)}か所"
                       f"（scene だけでは最長 {max(s.length for s in split):.1f}秒）")
        if rep.moves and not rep.specs:
            detail += "　※台本のカードの中身が読めず、カードは名前で見分けています"
        extra = []
        for start, length in sorted(runs, key=lambda r: -r[1])[:5]:
            tag = "　← 上限超え" if length > limit else ("　← 惜しい" if length > limit * NEAR else "")
            # 節は区間の**真ん中**で引く（節の変わり目にかかる区間が前の節の名前になる）
            extra.append(f"{clock(start)}〜{clock(start + length)}（{length:.0f}秒）"
                         f"{section_at(rep.sections, start + length / 2)}{tag}")
        for stall in sorted(split, key=lambda s: -s.length)[:5]:
            why = "／".join(f"{clock(at)} {note}" for at, note, _ in stall.moves[:3])
            if len(stall.moves) > 3:
                why += f"／ほか{len(stall.moves) - 3}か所"
            extra.append(f"{clock(stall.start)}〜{clock(stall.end)}（{stall.length:.0f}秒）"
                         f"{section_at(rep.sections, stall.start + stall.length / 2)}"
                         f"　← 台本では動いている（割ると最長 {stall.worst:.0f}秒）：{why}")
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
          alerts: list[tuple[float, float]] | None = None,
          notes: list[tuple[float, float, str]] | None = None,
          font_path: str | None = None, cols: int | None = None):
    """コマを1枚に並べる。節ごとに段を分け、各コマに時刻を焼き込み、停滞の区間は赤枠。

    `notes` は **ffmpeg には止まって見えたが台本では動いていた**ところ
    (始まり, 長さ, 札)。赤枠は出さず、金の細い枠と「光る行」などの札を添える
    （黙って通さないため。2026-10-09）。
    """
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
            note = "" if hot else next(
                (text for start, length, text in (notes or []) if start <= at < start + length), "")
            if hot:
                draw.rectangle([x, top, x + width - 1, top + height - 1], outline=ALERT, width=4)
            elif note:
                draw.rectangle([x, top, x + width - 1, top + height - 1], outline=BAND, width=2)
            stamp = clock(at) + ("　停滞" if hot else (f"　{note}" if note else ""))
            box = tile_font.getlength(stamp) + 12
            draw.rectangle([x, top + height - 24, x + box, top + height], fill=(0, 0, 0))
            draw.text((x + 6, top + height - 22), stamp, font=tile_font,
                      fill=ALERT if hot else (BAND if note else (255, 255, 255)))
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
            data = json.loads(meta.read_text(encoding="utf-8"))
            rep.sections = sections_from_script(data)
            # **台本と突き合わせて、板の中の変化を数に入れる**（2026-10-09）。
            # カードの中身は元の台本にしか無いので読みに行く。無ければ名前で見分ける
            specs = card_specs(build_dir)
            rep.specs = len(specs)
            rep.moves = visual_moves(data, specs)
        except (json.JSONDecodeError, ValueError, TypeError):
            rep.sections, rep.moves, rep.specs = [], [], 0
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
    if rep.moves:
        lines.append(f"- 台本の上で画面が動いた時刻 {len(rep.moves)}か所"
                     + (f"・台本から読めたカードの中身 {rep.specs}件" if rep.specs
                        else "・台本のカードの中身は読めず、カードは名前で見分けた"))
    else:
        lines.append("- 台本の根拠は使っていない（script.json が無いか古い書き出し）")
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
        "- 一覧の**金の枠と札**（「光る行」「板の絵替わり」など）は、"
        "ffmpeg には止まって見えたが**台本では動いていた**ところ。"
        "何を根拠に動いていると数えたかは、上の結果の「← 台本では動いている」の行に書いてある",
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
        found_stalls = stalls(rep.scores, rep.duration, rep.scene, rep.moves)
        # 赤枠は**割ったあとに**上限を超えて残っている所だけ
        alerts = [piece for stall in found_stalls for piece in stall.pieces if piece[1] > limit]
        # 金の札は、scene では止まって見えたが台本では動いていた所（割った切れ端ごと）
        notes = sheet_notes(found_stalls, limit)
        try:
            from src.config import load_config
            font = str(load_config().video.font_path())
        except Exception:
            font = None
        kind = "ショート" if rep.portrait else "本編"
        title = f"{rep.name}　{kind} {clock(rep.duration)}　{rep.step:.0f}秒ごと"
        png = build_dir / "qc.png"
        sheet(frames, rep.sections, title=title, alerts=alerts, notes=notes,
              font_path=font).save(png)

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

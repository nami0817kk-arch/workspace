"""離脱した行の地図（2026-10-03）。どの行で人が離れたかを、行ごとの数字で出す。

    python tools/dropmap.py --days 14 [--kind main|short|all] [--out research/metrics/dropmap_<日付>.md]
    python tools/dropmap.py --days 14 --dry-run --fixture curves.json   # API を呼ばずに動かす

公開済みの動画の視聴維持の曲線（Analytics の audienceWatchRatio）と、
書き出したときの台本（`output/<名前>/script.json` の各行の start・duration）を重ね、
**行ごとの落ち幅**（その行の始まりの維持率 − 終わりの維持率）を出す。
これまで「冒頭が弱い」「数字が続くと離れる」を勘で決めて直していた。直す場所を数字で決めるため。

- 呼ぶのは Analytics（`insights.retention`）だけ。1本1回。**Data API の Queries 枠は使わない**
  （尺は手元の video.mp4 から測る。無ければ台本の最後の行の終わり＋締めのカード3秒）
- 分析は2〜3日遅れ。曲線が空の動画は**「測れなかった」として数え、本数を必ず一緒に出す**
  （CLAUDE.md「全数で見る」）。台本が手元に無いもの・削除したものも内訳に出す
- 計算（行への割り当て・落ち幅・種類分け・まとめ）は API と切り離した関数にしてある

`--fixture` の形は `{"<videoId>": [[経過割合, 維持率], ...], ...}`。
`{"curves": {...}, "views": {"<videoId>": 再生数}}` の形も読む（`--save-curves` が書く形）。

**節の種類でまとめる見方**（2026-10-05、本編の維持を節の種類ごとに測る）:

    python tools/dropmap.py --days 28 --kind main --by section --save-curves <控え.json>
    python tools/dropmap.py --days 28 --kind main --by section --dry-run --fixture <控え.json>

節（script.json の scene）の種類は、見出しと取材メモ `research/<名前>.yaml` の節
（id・viewpoint・quotes_from・card）と、話者の割合から決める（`section_kind`）。
タイトルの行・冒頭・締め（終了画面）は行の単位で切り出す。種類ごとの秒あたりの落ち幅・
出てくる位置・位置帯（0〜30秒・30〜60秒・60〜120秒・120秒以降）ごとの比べ・
落ち幅の大きい節を、全体／ニュースの回／シリーズの回（`series` あり）に分けて出す。
"""

from __future__ import annotations

import argparse
import json
import re
import statistics
import subprocess
import sys
from dataclasses import dataclass, field
from datetime import date, datetime, timedelta, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

# 語りを担当する声（src/insights.py の NARRATORS と同じ）。ここに無い話者は「誰かの言葉」
NARRATORS = ("キャスター", "解説", "ナレーター")
# ネットの声として出す話者（tools/ypp_audit.py の CROWD と同じ。海外の反応もここ）
CROWD = ("ネット民", "現地サポ", "海外のファン")
# 締めの言葉。どこにあっても締めとみなすもの
CLOSING_ANYWHERE = re.compile(r"チャンネル登録|高評価|ご視聴|本編はチャンネル|本編で見られ|続きは本編")
# 最後の節にあるときだけ締めとみなすもの（途中の「続報」は中身の話）
CLOSING_LAST_SCENE = re.compile(r"続報|続きは|お伝えします")
NUMBER = re.compile(r"[0-9０-９]+(?:[.,．][0-9０-９]+)?")
# 本編の終わりに付く締めのカード（実測で台本の終わり＋約3秒）
OUTRO_SECONDS = 3.0

KINDS = ("タイトル", "前置き", "数字", "代弁", "反応", "締め", "その他の語り")


@dataclass
class Line:
    index: int
    scene: str
    scene_index: int
    first_in_scene: bool
    last_scene: bool
    speaker: str
    text: str
    start: float
    duration: float

    @property
    def end(self) -> float:
        return self.start + self.duration


@dataclass
class LineDrop:
    line: Line
    kind: str
    top: float      # 行の始まりの維持率
    bottom: float   # 行の終わりの維持率

    @property
    def drop(self) -> float:
        return self.top - self.bottom

    @property
    def per_second(self) -> float:
        return self.drop / self.line.duration if self.line.duration > 0 else 0.0


@dataclass
class VideoMap:
    video_id: str
    build: str
    short: bool
    length: float
    drops: list[LineDrop] = field(default_factory=list)
    first30: float = 0.0   # 冒頭30秒で落ちた幅
    series: bool = False   # シリーズの回（script.json か取材メモに series がある）
    views: int | None = None   # 期間中の再生数（分からなければ None）
    segments: list = field(default_factory=list)   # 節の単位（--by section のとき）
    points: list = field(default_factory=list)     # 維持の曲線（位置帯で切るときに使う）
    has_research: bool = True   # 取材メモがあったか（無ければ台本だけで種類を決めた）


# ---------------------------------------------------------------- 計算（純粋な関数）

def script_lines(script: dict) -> list[Line]:
    """台本の行を時刻つきで並べる。start が無い行は duration を積み上げて置く。"""
    out: list[Line] = []
    elapsed = 0.0
    scenes = script.get("scenes") or []
    for si, scene in enumerate(scenes):
        for li, raw in enumerate(scene.get("lines") or []):
            duration = float(raw.get("duration") or 0.0)
            start = raw.get("start")
            start = float(start) if start not in (None, "") else elapsed
            out.append(Line(
                index=len(out), scene=str(scene.get("title") or ""), scene_index=si,
                first_in_scene=(li == 0), last_scene=(si == len(scenes) - 1),
                speaker=str(raw.get("speaker") or ""), text=str(raw.get("text") or ""),
                start=start, duration=duration,
            ))
            elapsed = start + duration
    return out


def classify(line: Line) -> str:
    """行の種類。上から順に当てる。"""
    if line.index == 0:
        return "タイトル"
    if CLOSING_ANYWHERE.search(line.text) or (
            line.last_scene and CLOSING_LAST_SCENE.search(line.text)):
        return "締め"
    if line.speaker in CROWD:
        return "反応"
    if line.speaker not in NARRATORS:
        return "代弁"
    if line.first_in_scene:
        return "前置き"
    if len(NUMBER.findall(line.text)) >= 2:
        return "数字"
    return "その他の語り"


def ratio_at(points: list[tuple[float, float]], elapsed: float) -> float:
    """経過割合 elapsed での維持率。点のあいだは直線でつなぎ、端の外は端の値。"""
    if not points:
        raise ValueError("曲線が空です")
    pts = sorted(points)
    if elapsed <= pts[0][0]:
        return pts[0][1]
    for (x1, y1), (x2, y2) in zip(pts, pts[1:]):
        if x1 <= elapsed <= x2:
            if x2 == x1:
                return y2
            return y1 + (y2 - y1) * (elapsed - x1) / (x2 - x1)
    return pts[-1][1]


def map_lines(points: list[tuple[float, float]], lines: list[Line], length: float) -> list[LineDrop]:
    """各行に、始まりと終わりの維持率を割り当てる（秒 → 経過割合 = 秒 ÷ 尺）。"""
    if length <= 0:
        raise ValueError("尺が0です")
    out = []
    for line in lines:
        top = ratio_at(points, min(line.start / length, 1.0))
        bottom = ratio_at(points, min(line.end / length, 1.0))
        out.append(LineDrop(line=line, kind=classify(line), top=top, bottom=bottom))
    return out


def first_drop(points: list[tuple[float, float]], length: float, seconds: float = 30.0) -> float:
    """冒頭 seconds 秒で落ちた幅（0秒の維持率 − seconds 秒の維持率）。"""
    return ratio_at(points, 0.0) - ratio_at(points, min(seconds / length, 1.0))


def script_length(lines: list[Line], short: bool) -> float:
    """台本から見積もる尺。本編は締めのカードのぶんを足す。"""
    end = max((ln.end for ln in lines), default=0.0)
    return end if short else end + OUTRO_SECONDS


@dataclass
class Target:
    video_id: str
    build: str
    short: bool
    reason: str = ""   # 空なら測る対象。入っていれば測れなかった理由


def pick_targets(posted: list[dict], since: datetime, kind: str,
                 has_script) -> list[Target]:
    """控えから期間内の動画を選ぶ。測れないものも理由つきで残す（あとで本数を数える）。"""
    out = []
    for row in posted:
        when = row.get("publish_at") or row.get("at") or ""
        try:
            at = datetime.fromisoformat(when.replace("Z", "+00:00"))
        except ValueError:
            continue
        if at.tzinfo is None:
            at = at.replace(tzinfo=timezone.utc)
        if at < since:
            continue
        build = str(row.get("build") or "")
        short = build.endswith("_short")
        if kind == "main" and short or kind == "short" and not short:
            continue
        target = Target(video_id=str(row.get("video_id") or ""), build=build, short=short)
        if row.get("deleted"):
            target.reason = "削除済み"
        elif build.startswith("(") or not has_script(build):
            target.reason = "台本が手元に無い"
        out.append(target)
    return out


def summarize(maps: list[VideoMap], skipped: list[Target]) -> dict:
    """種類ごとの秒あたり落ち幅の中央値・冒頭30秒の中央値・本数をまとめる。"""
    out: dict = {"measured": len(maps), "skipped": len(skipped), "reasons": {}, "groups": {}}
    for t in skipped:
        out["reasons"][t.reason] = out["reasons"].get(t.reason, 0) + 1
    for short, name in ((False, "本編"), (True, "ショート")):
        sel = [m for m in maps if m.short == short]
        group = {"videos": len(sel),
                 "skipped": sum(1 for t in skipped if t.short == short),
                 "kinds": {}, "first30": None}
        for kind in KINDS:
            vals = [d.per_second for m in sel for d in m.drops
                    if d.kind == kind and d.line.duration > 0]
            if vals:
                group["kinds"][kind] = (statistics.median(vals), len(vals))
        if sel:
            group["first30"] = statistics.median([m.first30 for m in sel])
        out["groups"][name] = group
    return out


def top_lines(maps: list[VideoMap], n: int = 20) -> list[tuple[VideoMap, LineDrop]]:
    """落ち幅の大きい行。"""
    rows = [(m, d) for m in maps for d in m.drops]
    rows.sort(key=lambda pair: pair[1].drop, reverse=True)
    return rows[:n]


def render(summary: dict, top: list[tuple[VideoMap, LineDrop]], days: int,
           kind: str, calls: int, today: date, dry_run: bool) -> str:
    """Markdown にする。維持率はポイント（100倍）で書く。"""
    total = summary["measured"] + summary["skipped"]
    lines = [f"# 離脱した行の地図（{today}、直近{days}日、{kind}）", ""]
    if dry_run:
        lines += ["**dry-run**（API は呼んでいない。曲線は --fixture から）", ""]
    lines += ["## ① 本数", "",
              f"- 対象 {total}本のうち、**測れた {summary['measured']}本 / "
              f"測れなかった {summary['skipped']}本**"]
    for reason, count in sorted(summary["reasons"].items(), key=lambda kv: -kv[1]):
        lines.append(f"  - {reason}: {count}本")
    for name, group in summary["groups"].items():
        lines.append(f"- {name}: 測れた {group['videos']}本 / 測れなかった {group['skipped']}本")
    lines.append(f"- Analytics の呼び出し {calls}回（Data API は使っていない）")
    lines.append("- 曲線が空なのは、再生が少なすぎるか公開が新しすぎるもの（分析は2〜3日遅れ）")

    lines += ["", "## ② 行の種類ごとの落ち幅（秒あたり、中央値）", "",
              "1秒流れるあいだに維持率が何ポイント落ちたか。大きいほど、その種類の行で離れている。", "",
              "| 種類 | 本編 | 行数 | ショート | 行数 |", "|---|---:|---:|---:|---:|"]
    main = summary["groups"]["本編"]["kinds"]
    short = summary["groups"]["ショート"]["kinds"]
    for k in KINDS:
        if k not in main and k not in short:
            continue
        a = f"{main[k][0] * 100:.2f}" if k in main else "—"
        b = f"{short[k][0] * 100:.2f}" if k in short else "—"
        lines.append(f"| {k} | {a} | {main[k][1] if k in main else 0} "
                     f"| {b} | {short[k][1] if k in short else 0} |")

    lines += ["", "## ③ 落ち幅の大きい行（上位20）", "",
              "| # | 動画 | 秒 | 話者 | 種類 | 本文の頭 | 落ち幅 | 秒あたり |",
              "|---:|---|---:|---|---|---|---:|---:|"]
    for i, (m, d) in enumerate(top, 1):
        head = d.line.text[:30].replace("|", "｜")
        lines.append(f"| {i} | {m.build} | {d.line.start:.0f}〜{d.line.end:.0f} | "
                     f"{d.line.speaker} | {d.kind} | {head} | "
                     f"{d.drop * 100:.1f} | {d.per_second * 100:.2f} |")

    lines += ["", "## ④ 冒頭30秒で落ちた幅（中央値）", ""]
    for name, group in summary["groups"].items():
        if group["first30"] is None:
            lines.append(f"- {name}: 測れた動画なし")
        else:
            lines.append(f"- {name}: {group['first30'] * 100:.1f}ポイント（{group['videos']}本）")
    lines += ["", "維持率は Analytics の audienceWatchRatio（繰り返し見られると100%を超える）。"
              "落ち幅は「行の始まり − 行の終わり」のポイント。尺は手元の video.mp4 から測った。", ""]
    return "\n".join(lines)


# ---------------------------------------------------------------- 節の種類でまとめる（2026-10-05）

SECTION_KINDS = ("タイトル", "冒頭", "出来事", "基礎DATA", "数字の表", "歩み", "人物",
                 "本人の言葉", "見立て", "これから", "ネットの反応", "その他", "締め")
# 位置帯（秒）。位置のせいか中身のせいかを分けるため、同じ帯の中で種類を比べる
BANDS = ((0.0, 10.0, "0〜10秒"), (10.0, 30.0, "10〜30秒"), (30.0, 60.0, "30〜60秒"),
         (60.0, 120.0, "60〜120秒"), (120.0, float("inf"), "120秒〜"))
END_CARD = "（終了画面）"

# 取材メモの節の id で決めるもの（上から順に当てる）
_REACTION_IDS = {"voices", "react", "reactions"}
_QUOTE_IDS = {"said", "words", "statement", "press", "quote", "quotes"}
_VIEW_IDS = {"view", "viewpoint"}
_DATA_IDS = {"data"}
_HISTORY_IDS = {"history", "history2", "history3", "career", "past", "before", "after",
                "road", "story", "background", "journey"}
_PEOPLE_IDS = {"legends", "legends2", "legends3", "manager", "coach", "who", "captain"}
_NEXT_IDS = {"next"}
_EVENT_IDS = {"what", "why", "match", "goal", "report", "score", "flow", "result",
              "night", "how", "verdict", "statement_what"}
_TABLE_IDS = {"numbers", "season", "record", "squad", "rating", "stats", "rank", "table"}
# 見出しで決めるもの
_REACTION_HEAD = re.compile(r"反応|ネットの声|見ていた人|ネットでは|受け止め")
_QUOTE_HEAD = re.compile(r"言った|言葉|語った|話した|言い分|コメント|会見")
_VIEW_HEAD = re.compile(r"見立て")
_DATA_HEAD = re.compile(r"基礎DATA|基礎データ")
_HISTORY_HEAD = re.compile(r"歩ん|道のり|経緯|歴史|これまで|転機|経歴|年前|以前")
_PEOPLE_HEAD = re.compile(r"語る3人|今季の監督|どんな選手|どんな監督")
_NEXT_HEAD = re.compile(r"これから|次の試合|今後")
_EVENT_HEAD = re.compile(r"何が|何があ|試合は|試合の流れ|どう動|どんなゴール|起きた")
_TABLE_HEAD = re.compile(r"数字|登録選手|順位|ここまで|ランキング")
_CLOSING_HEAD = re.compile(r"^まとめ$")


def _norm(text: str) -> str:
    return re.sub(r"[\s。、．.！!？?「」『』*]", "", text or "")


def load_research(research_root: Path | None, build: str) -> dict | None:
    """取材メモ（research/<名前>.yaml）。無い・読めないときは None（台本だけで決める）。"""
    if research_root is None:
        return None
    path = research_root / f"{build}.yaml"
    if not path.exists():
        return None
    try:
        import yaml

        data = yaml.safe_load(path.read_text(encoding="utf-8"))
    except Exception:
        return None
    return data if isinstance(data, dict) else None


def is_series(script: dict, research: dict | None) -> bool:
    return bool(str(script.get("series") or "").strip()
                or (research and str(research.get("series") or "").strip()))


def research_sections(research: dict | None) -> dict[str, dict]:
    """見出し → 取材メモの節。"""
    out: dict[str, dict] = {}
    for sec in (research or {}).get("sections") or []:
        if isinstance(sec, dict) and sec.get("heading"):
            out.setdefault(str(sec["heading"]), sec)
    return out


def section_kind(heading: str, scene: dict, section: dict | None,
                 speakers: list[str]) -> str:
    """節の種類。オープニングと締めの行は行の単位で別に切り出す（`line_kinds`）。

    上から順に当てる。話者の半分以上がネットの声なら反応、名前のある人なら本人の言葉。
    """
    sec = section or {}
    sid = str(sec.get("id") or "")
    counted = [s for s in speakers if s]
    crowd = sum(1 for s in counted if s in CROWD)
    named = sum(1 for s in counted if s not in CROWD and s not in NARRATORS)
    card = sec.get("card") if isinstance(sec.get("card"), dict) else {}
    if _CLOSING_HEAD.search(heading):
        return "締め"
    if (counted and crowd * 2 >= len(counted)) or sid in _REACTION_IDS \
            or _REACTION_HEAD.search(heading):
        return "ネットの反応"
    if (counted and named * 2 >= len(counted)) or sid in _QUOTE_IDS \
            or _QUOTE_HEAD.search(heading):
        return "本人の言葉"
    if _truthy(scene.get("viewpoint")) or _truthy(sec.get("viewpoint")) \
            or sid in _VIEW_IDS or _VIEW_HEAD.search(heading):
        return "見立て"
    if sid in _DATA_IDS or _DATA_HEAD.search(heading):
        return "基礎DATA"
    if sid in _HISTORY_IDS or _HISTORY_HEAD.search(heading):
        return "歩み"
    if sid in _PEOPLE_IDS or _PEOPLE_HEAD.search(heading):
        return "人物"
    if sid in _NEXT_IDS or _NEXT_HEAD.search(heading):
        return "これから"
    if sid in _EVENT_IDS or _EVENT_HEAD.search(heading):
        return "出来事"
    if sid in _TABLE_IDS or _TABLE_HEAD.search(heading) \
            or card.get("type") in ("table", "bars"):
        return "数字の表"
    return "その他"


def _truthy(value) -> bool:
    return value is True or str(value).strip().lower() == "true"


def line_kinds(script: dict, research: dict | None) -> list[tuple[str, str]]:
    """台本の各行の (種類, 節の見出し)。`script_lines` と同じ並び。

    - オープニングの節：題（script.json の title）を読む行が「タイトル」、ほかは「冒頭」。
      題と一致する行が無ければ最初の行をタイトルにする
    - 締めの言葉（チャンネル登録など）の行は「締め」
    - それ以外は節の種類（`section_kind`）
    """
    secs = research_sections(research)
    title = _norm(str(script.get("title") or ""))
    out: list[tuple[str, str]] = []
    lines = script_lines(script)
    by_scene: dict[int, list[Line]] = {}
    for ln in lines:
        by_scene.setdefault(ln.scene_index, []).append(ln)
    scenes = script.get("scenes") or []
    kinds_of_scene: dict[int, str] = {}
    title_index: int | None = None
    for si, scene in enumerate(scenes):
        heading = str(scene.get("title") or "")
        members = by_scene.get(si, [])
        if si == 0 and (heading == "オープニング" or not secs.get(heading)):
            kinds_of_scene[si] = "冒頭"
            for ln in members:
                if title and _norm(ln.text) == title:
                    title_index = ln.index
                    break
            continue
        kinds_of_scene[si] = section_kind(heading, scene, secs.get(heading),
                                          [ln.speaker for ln in members])
    if title_index is None and lines:
        title_index = 0
    for ln in lines:
        if ln.index == title_index:
            kind = "タイトル"
        elif classify(ln) == "締め":
            kind = "締め"
        else:
            kind = kinds_of_scene.get(ln.scene_index, "その他")
        out.append((kind, ln.scene))
    return out


@dataclass
class Segment:
    """節（またはタイトル・締めの行のかたまり）1つぶんの落ち幅。"""
    heading: str
    kind: str
    start: float
    end: float
    top: float
    bottom: float
    length: float   # 動画の尺（位置の割合を出すため）

    @property
    def seconds(self) -> float:
        return self.end - self.start

    @property
    def drop(self) -> float:
        return self.top - self.bottom

    @property
    def per_second(self) -> float:
        return self.drop / self.seconds if self.seconds > 0 else 0.0

    @property
    def position(self) -> float:
        return self.start / self.length if self.length > 0 else 0.0


def build_segments(points: list[tuple[float, float]], lines: list[Line],
                   kinds: list[tuple[str, str]], length: float) -> list[Segment]:
    """続く行のうち、同じ節で同じ種類のものを1つにまとめる。最後に終了画面を足す。"""
    if length <= 0:
        raise ValueError("尺が0です")
    groups: list[tuple[str, str, int, float, float]] = []
    for ln, (kind, heading) in zip(lines, kinds):
        key = (ln.scene_index, kind)
        if groups and (groups[-1][2], groups[-1][1]) == key:
            h, k, si, start, _ = groups[-1]
            groups[-1] = (h, k, si, start, ln.end)
        else:
            groups.append((heading, kind, ln.scene_index, ln.start, ln.end))
    out = []
    for heading, kind, _, start, end in groups:
        out.append(Segment(heading=heading, kind=kind, start=start, end=end,
                           top=ratio_at(points, min(start / length, 1.0)),
                           bottom=ratio_at(points, min(end / length, 1.0)), length=length))
    script_end = max((ln.end for ln in lines), default=0.0)
    if length - script_end > 0.5:
        out.append(Segment(heading=END_CARD, kind="締め", start=script_end, end=length,
                           top=ratio_at(points, min(script_end / length, 1.0)),
                           bottom=ratio_at(points, 1.0), length=length))
    return out


def band_of(second: float) -> str:
    for low, high, name in BANDS:
        if low <= second < high:
            return name
    return BANDS[-1][2]


def band_pieces(seg: Segment, points: list[tuple[float, float]]) -> list[tuple[str, float, float, float]]:
    """節を位置帯の境目で切る。(帯, 秒数, 落ち幅, 始まりの維持率)。"""
    out = []
    cuts = [seg.start] + [b for _, b, _ in BANDS if seg.start < b < seg.end] + [seg.end]
    for a, b in zip(cuts, cuts[1:]):
        if b <= a:
            continue
        top = ratio_at(points, min(a / seg.length, 1.0))
        bottom = ratio_at(points, min(b / seg.length, 1.0))
        out.append((band_of(a), b - a, top - bottom, top))
    return out


def _pooled(rows: list[tuple[float, float, float]]) -> tuple[float | None, float | None]:
    """(秒数, 落ち幅, 始まりの維持率) の合算。秒あたり落ち幅と、残った人の何割が1秒に離れるか。"""
    secs = sum(r[0] for r in rows)
    if secs <= 0:
        return None, None
    drop = sum(r[1] for r in rows)
    held = sum(r[0] * r[2] for r in rows)
    return drop / secs, (drop / held if held > 0 else None)


GROUPS = (("全体", lambda m: True), ("ニュース", lambda m: not m.series),
          ("シリーズ", lambda m: m.series))


def content_end(m: VideoMap) -> float:
    """台本の最後の行の終わり（終了画面の手前）。"""
    return max((s.end for s in m.segments if s.heading != END_CARD), default=0.0)


def position_baseline(maps: list[VideoMap]) -> list[float]:
    """1秒ごとの「その秒にふつう何ポイント落ちるか」（その秒まで中身が続いている本の平均）。

    終了画面は数えない（最後に消えるのは位置ではなく終わりの合図のせい）。
    """
    sums: list[float] = []
    counts: list[int] = []
    for m in maps:
        if m.length <= 0 or not m.points:
            continue
        for t in range(int(content_end(m))):
            if t >= len(sums):
                sums += [0.0] * (t + 1 - len(sums))
                counts += [0] * (t + 1 - len(counts))
            a = ratio_at(m.points, min(t / m.length, 1.0))
            b = ratio_at(m.points, min((t + 1) / m.length, 1.0))
            sums[t] += a - b
            counts[t] += 1
    return [s / c if c else 0.0 for s, c in zip(sums, counts)]


def expected_drop(seg: Segment, baseline: list[float]) -> float:
    """その節の秒に、ふつうなら落ちる幅（位置だけで説明できるぶん）。"""
    total = 0.0
    t = int(seg.start)
    while t < seg.end and t < len(baseline):
        overlap = min(seg.end, t + 1) - max(seg.start, t)
        if overlap > 0:
            total += baseline[t] * overlap
        t += 1
    return total


def summarize_sections(maps: list[VideoMap], skipped: list[Target],
                       min_views: int = 100) -> dict:
    """種類ごと・位置帯ごとにまとめる。maps の segments と points を使う。

    「位置の分を引いた落ち幅」は、同じ群の本の1秒ごとの平均（`position_baseline`）を
    その節の秒に当てて差し引いた残り。正なら、その位置のふつうより多く落ちている。
    """
    out: dict = {"measured": len(maps), "skipped": len(skipped), "reasons": {},
                 "groups": {}, "min_views": min_views}
    for t in skipped:
        out["reasons"][t.reason] = out["reasons"].get(t.reason, 0) + 1
    for name, keep in GROUPS:
        sel = [m for m in maps if keep(m)]
        baseline = position_baseline(sel)
        group: dict = {"videos": len(sel), "kinds": {}, "bands": {}, "baseline": baseline}
        for kind in SECTION_KINDS:
            segs = [(m, s) for m in sel for s in m.segments if s.kind == kind and s.seconds > 0]
            if not segs:
                continue
            many = [s.per_second for m, s in segs if (m.views or 0) >= min_views]
            pooled, hazard = _pooled([(s.seconds, s.drop, s.top) for _, s in segs])
            excess = [(s.drop - expected_drop(s, baseline), s.seconds) for _, s in segs]
            group["kinds"][kind] = {
                "excess": sum(e for e, _ in excess) / sum(sec for _, sec in excess),
                "excess_median": statistics.median([e / sec for e, sec in excess]),
                "segments": len(segs),
                "videos": len({m.video_id for m, _ in segs}),
                "median": statistics.median([s.per_second for _, s in segs]),
                "pooled": pooled, "hazard": hazard,
                "start": statistics.median([s.start for _, s in segs]),
                "position": statistics.median([s.position for _, s in segs]),
                "seconds": statistics.median([s.seconds for _, s in segs]),
                "median_many": statistics.median(many) if many else None,
                "n_many": len(many),
            }
            bands: dict[str, list] = {}
            vids: dict[str, set] = {}
            for m, s in segs:
                for band, secs, drop, top in band_pieces(s, m.points):
                    bands.setdefault(band, []).append((secs, drop, top))
                    vids.setdefault(band, set()).add(m.video_id)
            group["bands"][kind] = {
                band: {"pooled": _pooled(rows)[0], "hazard": _pooled(rows)[1],
                       "seconds": sum(r[0] for r in rows), "videos": len(vids[band])}
                for band, rows in bands.items()}
        out["groups"][name] = group
    return out


def top_segments(maps: list[VideoMap], n: int = 20, after: float = 0.0,
                 baseline: list[float] | None = None, min_views: int = 0
                 ) -> list[tuple[VideoMap, Segment]]:
    """落ち幅の大きい節。終了画面は外す（最後に人が消えるのは当たり前なので）。

    baseline を渡すと、位置の分を引いた残り（落ち幅 − ふつうの落ち幅）で並べる。
    """
    rows = [(m, s) for m in maps for s in m.segments
            if s.heading != END_CARD and s.start >= after and (m.views or 0) >= min_views]
    if baseline is None:
        rows.sort(key=lambda pair: pair[1].drop, reverse=True)
    else:
        rows.sort(key=lambda pair: pair[1].drop - expected_drop(pair[1], baseline), reverse=True)
    return rows[:n]


def _signed(value: float | None) -> str:
    return "—" if value is None else f"{value * 100:+.2f}"


def _pt(value: float | None, digits: int = 2) -> str:
    return "—" if value is None else f"{value * 100:.{digits}f}"


def render_sections(summary: dict, maps: list[VideoMap], days: int, kind: str,
                    calls: int, today: date, dry_run: bool) -> str:
    total = summary["measured"] + summary["skipped"]
    out = [f"# 本編の視聴維持を節の種類ごとに（{today}、直近{days}日、{kind}）", ""]
    if dry_run:
        out += ["**dry-run**（API は呼んでいない。曲線は --fixture から）", ""]
    out += ["## ① 本数", "",
            f"- 対象 {total}本のうち、**測れた {summary['measured']}本 / "
            f"測れなかった {summary['skipped']}本**"]
    for reason, count in sorted(summary["reasons"].items(), key=lambda kv: -kv[1]):
        out.append(f"  - {reason}: {count}本")
    for name, group in summary["groups"].items():
        if name != "全体":
            out.append(f"- {name}の回: 測れた {group['videos']}本")
    no_note = sum(1 for m in maps if not m.has_research)
    out.append(f"- 取材メモが無く台本だけで種類を決めた本: {no_note}本")
    known = [m.views for m in maps if m.views is not None]
    if known:
        out.append(f"- 測れた本の期間中の再生: 中央値 {statistics.median(known):.0f}回"
                   f"（{min(known)}〜{max(known)}回。再生が少ない本ほど曲線が粗い）")
    out.append(f"- Analytics の呼び出し {calls}回（Data API は使っていない）")
    out.append("- 曲線が空なのは、再生が少なすぎるか公開が新しすぎるもの（分析は2〜3日遅れ）")

    out += ["", "## ② 節の種類ごとの落ち幅（全体）", "",
            "- **秒あたり**：1秒流れるあいだに維持率が何ポイント落ちたか（節ごとの値の中央値）",
            "- **合算**：その種類の節を全部つないだ落ち幅 ÷ 秒数。**離脱率**：残っていた人のうち1秒に何%が離れたか"
            "（後ろの節ほど残っている人が少ないので、ポイントだけだと後ろが小さく見える）",
            "- **位置の分を引いた**：同じ秒に全体の本がふつう落ちる幅を差し引いた残り（秒あたり、合算）。"
            "**正ならその位置のふつうより多く落ち、負なら持ちこたえている**。位置のせいか中身のせいかを分ける数字",
            f"- **再生{summary['min_views']}回以上**：曲線の粗い本を除いた中央値（括弧は節の数）", "",
            "| 種類 | 節 | 本 | 秒あたり | 合算 | 離脱率%/秒 | **位置の分を引いた** | 位置（秒） | 位置（割合） "
            f"| 長さ（秒） | 再生{summary['min_views']}回以上 |",
            "|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|"]
    kinds = summary["groups"]["全体"]["kinds"]
    for k in SECTION_KINDS:
        if k not in kinds:
            continue
        s = kinds[k]
        out.append(f"| {k} | {s['segments']} | {s['videos']} | {_pt(s['median'])} | "
                   f"{_pt(s['pooled'])} | {_pt(s['hazard'])} | {_signed(s['excess'])} | {s['start']:.0f} | "
                   f"{s['position'] * 100:.0f}% | {s['seconds']:.0f} | "
                   f"{_pt(s['median_many'])}（{s['n_many']}） |")

    out += ["", "## ③ ニュースの回とシリーズの回", "",
            "秒あたりの中央値（括弧は節の数）・位置の分を引いた残り（それぞれの群の平均を差し引く）・"
            "出てくる位置（秒の中央値）。", "",
            "| 種類 | ニュース 秒あたり | 位置の分を引いた | 位置 | シリーズ 秒あたり | 位置の分を引いた | 位置 |",
            "|---|---:|---:|---:|---:|---:|---:|"]
    news = summary["groups"]["ニュース"]["kinds"]
    series = summary["groups"]["シリーズ"]["kinds"]
    for k in SECTION_KINDS:
        if k not in news and k not in series:
            continue
        a = f"{_pt(news[k]['median'])}（{news[k]['segments']}）" if k in news else "—"
        ae = _signed(news[k]["excess"]) if k in news else "—"
        ap = f"{news[k]['start']:.0f}秒" if k in news else "—"
        b = f"{_pt(series[k]['median'])}（{series[k]['segments']}）" if k in series else "—"
        be = _signed(series[k]["excess"]) if k in series else "—"
        bp = f"{series[k]['start']:.0f}秒" if k in series else "—"
        out.append(f"| {k} | {a} | {ae} | {ap} | {b} | {be} | {bp} |")

    band_names = [b[2] for b in BANDS]
    for name in ("全体", "ニュース", "シリーズ"):
        group = summary["groups"][name]
        for field_name, label in (("pooled", "秒あたりの落ち幅（合算、ポイント）"),
                                  ("hazard", "離脱率（残った人の何%が1秒に離れたか）")):
            if name != "全体" and field_name == "hazard":
                continue
            out += ["", f"## ④ 同じ位置帯で種類を比べる（{name}・{label}）", "",
                    "括弧はその帯に入った秒数の合計と本数。**同じ列の中で比べる**（列をまたぐと位置の差が混ざる）。"
                    "合わせて10本に満たないマスは参考まで。", "",
                    "| 種類 | " + " | ".join(band_names) + " |",
                    "|---|" + "---:|" * len(band_names)]
            for k in SECTION_KINDS:
                cells = group["bands"].get(k)
                if not cells:
                    continue
                row = []
                for b in band_names:
                    c = cells.get(b)
                    if not c or c[field_name] is None:
                        row.append("—")
                    else:
                        row.append(f"{_pt(c[field_name])}（{c['seconds']:.0f}秒・{c['videos']}本）")
                out.append(f"| {k} | " + " | ".join(row) + " |")

    baseline = summary["groups"]["全体"]["baseline"]

    def top_table(rows: list[tuple[VideoMap, Segment]]) -> list[str]:
        lines = ["| # | 動画 | 種類 | 節の見出し | 秒 | 位置 | 落ち幅 | 秒あたり | ふつうとの差 | 再生 |",
                 "|---:|---|---|---|---:|---:|---:|---:|---:|---:|"]
        for i, (m, s) in enumerate(rows, 1):
            head = s.heading[:24].replace("|", "｜")
            views = "—" if m.views is None else str(m.views)
            extra = (s.drop - expected_drop(s, baseline)) * 100
            lines.append(f"| {i} | {m.build} | {s.kind} | {head} | {s.start:.0f}〜{s.end:.0f} | "
                         f"{s.position * 100:.0f}% | {s.drop * 100:.1f} | "
                         f"{s.per_second * 100:.2f} | {extra:+.1f} | {views} |")
        return lines

    out += ["", "## ⑤ 落ち幅の大きい節（上位20、終了画面は除く）", "",
            "「ふつうとの差」は、同じ秒に全体の本がふつう落ちる幅を引いた残り（ポイント）。", ""]
    out += top_table(top_segments(maps, 20))
    out += ["", f"## ⑥ 位置の分を引いても大きく落ちた節（上位20、再生{summary['min_views']}回以上の本）", "",
            "前のほうの節は人が多く残っているぶん落ち幅が大きく出る。位置のぶんを差し引いた残りで並べ直したもの。"
            "再生の少ない本は曲線が粗く、1人の離脱で数ポイント動くので外した。", ""]
    out += top_table(top_segments(maps, 20, baseline=baseline, min_views=summary["min_views"]))
    out += ["", "維持率は Analytics の audienceWatchRatio（繰り返し見られると100%を超える）。"
            "落ち幅は「節の始まり − 節の終わり」のポイント。尺は手元の video.mp4 から測った。"
            "終了画面は台本の最後の行の終わりから動画の終わりまで。", ""]
    return "\n".join(out)


# ---------------------------------------------------------------- 外とのやりとり

def probe_length(video: Path) -> float | None:
    """手元の video.mp4 の長さ（秒）。測れなければ None。"""
    if not video.exists():
        return None
    try:
        from src.ffmpeg import ffmpeg_exe

        err = subprocess.run([ffmpeg_exe(), "-i", str(video)], capture_output=True,
                             text=True, encoding="utf-8", errors="replace").stderr
    except Exception:
        return None
    found = re.search(r"Duration: (\d+):(\d+):([\d.]+)", err)
    if not found:
        return None
    return int(found.group(1)) * 3600 + int(found.group(2)) * 60 + float(found.group(3))


def fetch_views(api, video_ids: list[str], days: int, today: date) -> tuple[dict[str, int], int]:
    """期間中の再生数を、動画を名指しして取る（Analytics。100本ずつ1回）。(再生数, 呼んだ回数)。"""
    views: dict[str, int] = {}
    calls = 0
    for i in range(0, len(video_ids), 100):
        chunk = [v for v in video_ids[i:i + 100] if v]
        if not chunk:
            continue
        calls += 1
        got = api.reports().query(
            ids="channel==MINE", startDate=str(today - timedelta(days=days)), endDate=str(today),
            metrics="views", dimensions="video", filters="video==" + ",".join(chunk),
            maxResults=200,
        ).execute()
        for row in got.get("rows") or []:
            views[str(row[0])] = int(row[1])
    return views, calls


def split_fixture(fixture: dict | None) -> tuple[dict, dict]:
    """--fixture の2つの形（曲線だけ／curves と views）を読み分ける。"""
    fixture = fixture or {}
    if isinstance(fixture.get("curves"), dict):
        return fixture["curves"], dict(fixture.get("views") or {})
    return fixture, {}


def run(days: int, kind: str, dry_run: bool, fixture: dict | None,
        today: date, output_root: Path, posted: list[dict], api=None,
        by: str = "line", research_root: Path | None = None,
        save_curves: Path | None = None) -> tuple[str, dict]:
    """対象を選び、1本ずつ曲線を取って行に重ねる。dry_run なら API を呼ばない。

    by="section" なら節の種類でまとめる（取材メモは research_root/<名前>.yaml）。
    """
    since = datetime.combine(today - timedelta(days=days), datetime.min.time(), timezone.utc)
    targets = pick_targets(posted, since, kind,
                           lambda b: (output_root / b / "script.json").exists())
    curves, views = split_fixture(fixture)
    calls = 0
    maps: list[VideoMap] = []
    skipped = [t for t in targets if t.reason]
    fetched: dict[str, list] = {}
    for t in targets:
        if t.reason:
            continue
        if dry_run:
            points = [tuple(p) for p in curves.get(t.video_id, [])]
        else:
            from src import insights

            points = None
            for attempt in range(2):   # 500 は一度だけ取り直す（返らない日もある）
                calls += 1
                try:
                    points = insights.retention(api, t.video_id, days, today).points
                    break
                except Exception as err:
                    if attempt == 1 or "500" not in str(err)[:40]:
                        print(f"  取得失敗 {t.video_id}: {str(err)[:100]}", file=sys.stderr)
                        break
            if points is None:
                t.reason = "取得失敗"
                skipped.append(t)
                continue
            fetched[t.video_id] = [list(p) for p in points]
        if not points:
            t.reason = "曲線がまだ無い"
            skipped.append(t)
            continue
        folder = output_root / t.build
        script = json.loads((folder / "script.json").read_text(encoding="utf-8"))
        lines = script_lines(script)
        if not lines:
            t.reason = "台本に行が無い"
            skipped.append(t)
            continue
        length = probe_length(folder / "video.mp4") or script_length(lines, t.short)
        vm = VideoMap(video_id=t.video_id, build=t.build, short=t.short, length=length,
                      drops=map_lines(points, lines, length),
                      first30=first_drop(points, length), points=list(points))
        if by == "section":
            research = load_research(research_root, t.build)
            vm.has_research = research is not None
            vm.series = is_series(script, research)
            vm.segments = build_segments(points, lines, line_kinds(script, research), length)
        maps.append(vm)
    if by == "section":
        if not dry_run and api is not None and maps:
            got, n = fetch_views(api, [m.video_id for m in maps], days, today)
            views.update(got)
            calls += n
        for m in maps:
            m.views = views.get(m.video_id, 0 if views else None)
    if save_curves is not None and not dry_run:
        save_curves.parent.mkdir(parents=True, exist_ok=True)
        save_curves.write_text(json.dumps({"curves": fetched, "views": views}, ensure_ascii=False),
                               encoding="utf-8")
    if by == "section":
        summary = summarize_sections(maps, skipped)
        summary["calls"] = calls
        text = render_sections(summary, maps, days, kind, calls, today, dry_run)
        summary["maps"] = maps
        return text, summary
    summary = summarize(maps, skipped)
    summary["calls"] = calls
    text = render(summary, top_lines(maps), days, kind, calls, today, dry_run)
    return text, summary


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="どの行で人が離れたかを出す")
    parser.add_argument("--days", type=int, default=14)
    parser.add_argument("--kind", choices=("main", "short", "all"), default="all")
    parser.add_argument("--by", choices=("line", "section"), default="line",
                        help="line=行の種類 / section=節の種類（本編向け）")
    parser.add_argument("--out", default="")
    parser.add_argument("--dry-run", action="store_true", help="API を呼ばない")
    parser.add_argument("--fixture", default="", help="dry-run で使う曲線の JSON")
    parser.add_argument("--save-curves", default="",
                        help="取った曲線と再生数を JSON に控える（あとで --dry-run --fixture で回せる）")
    args = parser.parse_args(argv)

    if args.fixture and not args.dry_run:
        parser.error("--fixture は --dry-run と一緒に使う")
    fixture = None
    if args.fixture:
        fixture = json.loads(Path(args.fixture).read_text(encoding="utf-8"))
    elif args.dry_run:
        print("--fixture が無いので、全部「曲線がまだ無い」になります", file=sys.stderr)

    today = date.today()
    posted = json.loads((ROOT / "research" / "posted.json").read_text(encoding="utf-8"))
    api = None
    if not args.dry_run:
        from src import insights

        try:
            api = insights.service()
        except Exception as err:
            print(f"分析APIに繋がりません: {str(err)[:140]}", file=sys.stderr)
            return 1
    text, summary = run(args.days, args.kind, args.dry_run, fixture, today,
                        ROOT / "output", posted, api, by=args.by,
                        research_root=ROOT / "research",
                        save_curves=Path(args.save_curves) if args.save_curves else None)
    suffix = "_main" if args.by == "section" and args.kind == "main" else ""
    out = Path(args.out) if args.out else (
        ROOT / "research" / "metrics" / f"dropmap{suffix}_{today:%Y%m%d}.md")
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(text, encoding="utf-8")
    print(f"測れた {summary['measured']}本 / 測れなかった {summary['skipped']}本"
          f"　Analytics {summary['calls']}回　→ {out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

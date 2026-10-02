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


def run(days: int, kind: str, dry_run: bool, fixture: dict | None,
        today: date, output_root: Path, posted: list[dict], api=None) -> tuple[str, dict]:
    """対象を選び、1本ずつ曲線を取って行に重ねる。dry_run なら API を呼ばない。"""
    since = datetime.combine(today - timedelta(days=days), datetime.min.time(), timezone.utc)
    targets = pick_targets(posted, since, kind,
                           lambda b: (output_root / b / "script.json").exists())
    calls = 0
    maps: list[VideoMap] = []
    skipped = [t for t in targets if t.reason]
    for t in targets:
        if t.reason:
            continue
        if dry_run:
            points = [tuple(p) for p in (fixture or {}).get(t.video_id, [])]
        else:
            from src import insights

            calls += 1
            try:
                points = insights.retention(api, t.video_id, days, today).points
            except Exception as err:
                print(f"  取得失敗 {t.video_id}: {str(err)[:100]}", file=sys.stderr)
                t.reason = "取得失敗"
                skipped.append(t)
                continue
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
        maps.append(VideoMap(video_id=t.video_id, build=t.build, short=t.short, length=length,
                             drops=map_lines(points, lines, length),
                             first30=first_drop(points, length)))
    summary = summarize(maps, skipped)
    summary["calls"] = calls
    text = render(summary, top_lines(maps), days, kind, calls, today, dry_run)
    return text, summary


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="どの行で人が離れたかを出す")
    parser.add_argument("--days", type=int, default=14)
    parser.add_argument("--kind", choices=("main", "short", "all"), default="all")
    parser.add_argument("--out", default="")
    parser.add_argument("--dry-run", action="store_true", help="API を呼ばない")
    parser.add_argument("--fixture", default="", help="dry-run で使う曲線の JSON")
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
                        ROOT / "output", posted, api)
    out = Path(args.out) if args.out else (
        ROOT / "research" / "metrics" / f"dropmap_{today:%Y%m%d}.md")
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(text, encoding="utf-8")
    print(f"測れた {summary['measured']}本 / 測れなかった {summary['skipped']}本"
          f"　Analytics {summary['calls']}回　→ {out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

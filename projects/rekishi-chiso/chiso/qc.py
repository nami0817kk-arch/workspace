"""出来上がった動画の点検（qc）。2026-10-07。

    python -m chiso.cli qc scripts/x.yaml [--video out/x.mp4]

動画を1回だけ読んで、次をまとめて出す（out/x_qc.md に保存、一覧の画像は out/x_qc.png）:

- 20秒ごとに1コマ抜いた一覧（節ごとに段を分ける。節の時刻は字幕 out/x.srt と台本から）
- 画面が大きく変わらない区間の長さ（ffmpeg の scene 検出）。中央値と、長い順に5つ（時刻つき）
- 字幕の終わりと動画の長さの差（次回予告の12秒のほかに、余りや欠けが無いか）
- 音の大きさ（loudnorm の測定。YouTube の基準 -14 LUFS と比べる）
- 無音が長く続く所（silencedetect）

決まり（質を上げる決まり、10-07）：同じ背景は40秒まで・20秒に1回は新しいもの。
信長の回で「同じ絵が2分前後動かない区間が6か所」と分かったのも scene 検出だった。
"""
from __future__ import annotations

import json
import re
import statistics
import subprocess
from dataclasses import dataclass, field
from pathlib import Path

STEP = 20.0             # 一覧に抜く間隔（秒）
SCENE = 0.08            # scene 検出のしきい値（0〜1。字幕の切り替えだけでは超えない程度）
SCENE_FPS = 5           # scene を見るときのコマ数（溶け合いのようなゆっくりした変化も拾う）
from .check import BG_MAX_SEC as STILL_WARN  # noqa: E402  これより長く画面が大きく変わらない区間を知らせる
SILENCE_DB = -45        # これより小さい音を無音とみなす
SILENCE_SEC = 2.0       # これより長い無音を知らせる（節の切れ目の間は1.2秒）
TARGET_LUFS = -14.0     # YouTube の基準
THUMB = (320, 180)      # 一覧の1コマの大きさ
COLS = 8


@dataclass
class Report:
    duration: float
    scenes: list[float] = field(default_factory=list)          # 画面が大きく変わった時刻
    loud: dict = field(default_factory=dict)                    # loudnorm の測定値
    silences: list[tuple[float, float]] = field(default_factory=list)   # (始まり, 長さ)
    subs_end: float | None = None
    sections: list[tuple[float, str]] = field(default_factory=list)     # (始まり, 題)


# --- ffmpeg の出力を読む（テストできるように、文字列から取り出すだけの関数にしてある） ---------------
def parse_scenes(stderr: str) -> list[float]:
    return [float(m.group(1)) for m in re.finditer(r"\[Parsed_showinfo[^\]]*\].*?pts_time:\s*([\d.]+)", stderr)]


def parse_loudnorm(stderr: str) -> dict:
    m = None
    for m in re.finditer(r"\{[^{}]*\"input_i\"[^{}]*\}", stderr):
        pass
    if m is None:
        return {}
    d = json.loads(m.group(0))
    out = {}
    for k in ("input_i", "input_tp", "input_lra", "input_thresh"):
        try:
            out[k] = float(d[k])
        except (KeyError, ValueError):
            pass
    return out


def parse_silences(stderr: str) -> list[tuple[float, float]]:
    out = []
    start = None
    for line in stderr.splitlines():
        m = re.search(r"silence_start:\s*(-?[\d.]+)", line)
        if m:
            start = max(0.0, float(m.group(1)))
        m = re.search(r"silence_end:\s*([\d.]+)\s*\|\s*silence_duration:\s*([\d.]+)", line)
        if m:
            end, dur = float(m.group(1)), float(m.group(2))
            out.append((start if start is not None else end - dur, dur))
            start = None
    if start is not None:
        out.append((start, -1.0))                                 # 終わりまで無音（長さは後で埋める）
    return out


def parse_srt(text: str) -> list[tuple[float, float]]:
    def sec(s):
        h, m, rest = s.split(":")
        return int(h) * 3600 + int(m) * 60 + float(rest.replace(",", "."))
    return [(sec(a), sec(b)) for a, b in re.findall(r"(\d+:\d+:\d+,\d+)\s*-->\s*(\d+:\d+:\d+,\d+)", text)]


def section_starts(script, srt: list[tuple[float, float]]) -> list[tuple[float, str]]:
    """節の始まりの時刻。字幕は1行を画面と同じかたまりに切っているので、台本から数えて合わせる。
    台本と字幕の数が合わなければ空（作ったあとで台本が変わった）。"""
    from .subs import chunks
    counts = [len(chunks(l.text)) for l in script.lines]
    if sum(counts) != len(srt):
        return []
    out, k, sec = [], 0, None
    for line, n in zip(script.lines, counts):
        if line.section != sec:
            sec = line.section
            # 節の頭の「第N節」の画面は、前の行の話し終わりから出る
            out.append((srt[k - 1][1] if k else 0.0, f"第{sec + 1}節 {script.sections[sec].title}"))
        k += n
    return out


def still_runs(scenes: list[float], duration: float) -> list[tuple[float, float]]:
    """画面が大きく変わらない区間 (始まり, 長さ)。"""
    cuts = [0.0] + sorted(t for t in scenes if 0 < t < duration) + [duration]
    return [(a, b - a) for a, b in zip(cuts, cuts[1:]) if b - a > 0]


def clock(t: float) -> str:
    t = int(round(t))
    h, rest = divmod(t, 3600)
    m, s = divmod(rest, 60)
    return f"{h}:{m:02}:{s:02}" if h else f"{m}:{s:02}"


def section_at(sections, t: float) -> str:
    name = ""
    for s, n in sections:
        if s <= t + 1e-6:
            name = n
    return name


def summarize(rep: Report, end_seconds: float = 12.0) -> list[str]:
    """点検の結果を Markdown の行で。"""
    out = [f"- 長さ：{clock(rep.duration)}（{rep.duration:.1f}秒）"]
    runs = still_runs(rep.scenes, rep.duration)
    if runs:
        lens = [d for _, d in runs]
        long = sorted(runs, key=lambda r: -r[1])[:5]
        over = [r for r in runs if r[1] > STILL_WARN]
        out.append(f"- 画面が大きく変わらない区間（scene>{SCENE}）：{len(runs)}区間・中央値 {statistics.median(lens):.1f}秒・"
                   f"{STILL_WARN:.0f}秒超え {len(over)}か所")
        for s, d in long:
            where = section_at(rep.sections, s)
            out.append(f"  - {clock(s)}〜{clock(s + d)}（{d:.0f}秒）{where}" + ("　← 長い" if d > STILL_WARN else ""))
    if rep.subs_end is not None:
        gap = rep.duration - rep.subs_end
        note = "" if 0 <= gap - end_seconds <= 3.0 else f"　← 次回予告（{end_seconds:.0f}秒）のほかに {gap - end_seconds:+.1f}秒"
        out.append(f"- 字幕の終わり {clock(rep.subs_end)}・動画の終わりとの差 {gap:.1f}秒{note}")
    else:
        out.append("- 字幕（.srt）が見つかりません")
    if rep.loud:
        i = rep.loud.get("input_i")
        tp = rep.loud.get("input_tp")
        lra = rep.loud.get("input_lra")
        note = "" if i is not None and abs(i - TARGET_LUFS) <= 1.0 else f"　← 基準 {TARGET_LUFS:.0f} LUFS からずれています"
        out.append(f"- 音の大きさ：{i} LUFS・最大 {tp} dBTP・幅 {lra} LU{note}")
    long_sil = [(s, d if d >= 0 else rep.duration - s) for s, d in rep.silences]
    long_sil = [(s, d) for s, d in long_sil if d >= SILENCE_SEC]
    tail = [(s, d) for s, d in long_sil if s + d >= rep.duration - 0.5 and d <= end_seconds + 2]
    body = [x for x in long_sil if x not in tail]
    out.append(f"- {SILENCE_SEC:.0f}秒以上の無音（{SILENCE_DB}dB 未満）：{len(body)}か所"
               + (f"（ほかに最後の次回予告 {tail[0][1]:.0f}秒）" if tail else ""))
    for s, d in sorted(body, key=lambda x: -x[1])[:5]:
        out.append(f"  - {clock(s)}（{d:.1f}秒）{section_at(rep.sections, s)}")
    return out


# --- 動画を読む ----------------------------------------------------------------------
def analyze(ffmpeg: str, video: Path, step: float = STEP) -> tuple[Report, list]:
    """動画を1回だけ読み、scene・音・一覧のコマを取る。コマは (時刻, PIL 画像) の並び。"""
    from PIL import Image
    from .video import media_seconds
    duration = media_seconds(ffmpeg, video) or 0.0
    w, h = THUMB
    graph = (f"[0:v]split=2[a][b];"
             f"[a]fps={SCENE_FPS},scale=320:-2,select='gt(scene,{SCENE})',showinfo[s];"
             f"[b]fps=1/{step:g}:round=down,scale={w}:{h}:flags=bicubic,format=rgb24[t];"
             f"[0:a]silencedetect=noise={SILENCE_DB}dB:d=1,loudnorm=print_format=json[x]")
    cmd = [ffmpeg, "-hide_banner", "-nostats", "-i", video.as_posix(), "-filter_complex", graph,
           "-map", "[s]", "-f", "null", "-",
           "-map", "[x]", "-f", "null", "-",
           "-map", "[t]", "-f", "rawvideo", "pipe:1"]
    r = subprocess.run(cmd, capture_output=True)
    err = r.stderr.decode("utf-8", errors="replace")
    if r.returncode != 0:
        raise RuntimeError(f"ffmpeg が失敗しました: {err[-800:]}")
    raw = r.stdout
    size = w * h * 3
    frames = [(k * step, Image.frombytes("RGB", (w, h), raw[k * size:(k + 1) * size]))
              for k in range(len(raw) // size)]
    rep = Report(duration=duration, scenes=parse_scenes(err), loud=parse_loudnorm(err), silences=parse_silences(err))
    return rep, frames


def sheet(frames, sections, font_path: str | None = None):
    """一覧の画像。節ごとに段を分け、各コマに時刻。"""
    from PIL import Image, ImageDraw, ImageFont
    w, h = THUMB

    def font(size):
        try:
            return ImageFont.truetype(font_path, size) if font_path else ImageFont.load_default(size)
        except OSError:
            return ImageFont.load_default(size)
    groups: list[tuple[str, list]] = []
    starts = sections or [(0.0, "")]
    for k, (s, name) in enumerate(starts):
        end = starts[k + 1][0] if k + 1 < len(starts) else float("inf")
        if k == 0:
            s = -1.0
        groups.append((name, [(t, im) for t, im in frames if s <= t < end]))
    head = 40
    pad = 6
    rows = sum(max(1, (len(g) + COLS - 1) // COLS) for _, g in groups)
    W = COLS * (w + pad) + pad
    H = len(groups) * head + rows * (h + pad) + pad
    out = Image.new("RGB", (W, H), (18, 16, 14))
    d = ImageDraw.Draw(out)
    hf, tf = font(24), font(18)
    y = pad
    for name, g in groups:
        d.text((pad + 4, y + 8), name or "（節の区切りが読めませんでした）", font=hf, fill=(214, 178, 110))
        y += head
        for k, (t, im) in enumerate(g):
            x = pad + (k % COLS) * (w + pad)
            yy = y + (k // COLS) * (h + pad)
            out.paste(im, (x, yy))
            label = clock(t)
            d.rectangle([x, yy + h - 24, x + tf.getlength(label) + 12, yy + h], fill=(0, 0, 0))
            d.text((x + 6, yy + h - 22), label, font=tf, fill=(255, 255, 255))
        y += max(1, (len(g) + COLS - 1) // COLS) * (h + pad)
    return out


def run(ffmpeg: str, script, video: Path, out_png: Path, out_md: Path, font_path: str | None = None,
        end_seconds: float = 12.0) -> list[str]:
    rep, frames = analyze(ffmpeg, video)
    srt = video.with_suffix(".srt")
    if not srt.exists() and getattr(script, "path", None) is not None:   # 確認用（x_draft.mp4）も字幕は out/x.srt（10-08）
        srt = video.parent / f"{script.path.stem}.srt"
    if srt.exists():
        cues = parse_srt(srt.read_text(encoding="utf-8"))
        rep.subs_end = cues[-1][1] if cues else None
        rep.sections = section_starts(script, cues)
    sheet(frames, rep.sections, font_path).save(out_png)
    lines = [f"# 点検：{video.name}", ""] + summarize(rep, end_seconds) + ["", f"一覧：{out_png.name}（{STEP:.0f}秒ごと）"]
    if not rep.sections:
        lines.append("（節の時刻が読めませんでした。字幕と台本の行の数が合っていません）")
    out_md.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return lines

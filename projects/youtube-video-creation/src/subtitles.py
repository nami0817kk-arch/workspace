"""字幕(SRT)・チャプター・概要欄などの書き出し。"""

from __future__ import annotations

from pathlib import Path

from .script_model import Script


def to_srt(script: Script) -> str:
    blocks = []
    index = 1
    labels = {"official": "確定", "report": "報道", "rumor": "未確認", "context": "背景"}
    for line in script.lines:
        # 字幕は読み上げた内容そのもの。テロップは画面に焼き込んであるし、
        # 画面用に短く切ってあるので、そのまま字幕にすると途中で切れる
        text = line.text or line.telop_text()
        if line.source in labels:
            text = f"[{labels[line.source]}] {text}"
        pause = line.pause or 0.0
        end = line.start + max(0.4, line.duration - pause)
        blocks.append(
            f"{index}\n{_timestamp(line.start)} --> {_timestamp(end)}\n{line.speaker}: {text}\n"
        )
        index += 1
    return "\n".join(blocks)


def chapters(script: Script) -> list[tuple[float, str]]:
    """YouTube のチャプター。各シーンの最初のセリフの開始時刻を使う。

    タイトルカードのぶん時刻がずれるので、尺の足し算ではなく実際の start を見る。
    """
    result: list[tuple[float, str]] = []
    for scene in script.scenes:
        if not scene.lines:
            continue
        result.append((scene.lines[0].start, scene.title))
    if result:
        result[0] = (0.0, result[0][1])  # 最初のチャプターは必ず 0:00
    return result


def description(script: Script, credits: list[str] | None = None) -> str:
    """概要欄のたたき台（本文 + チャプター + クレジット + タグ）。"""
    parts = [script.description.strip()] if script.description.strip() else []
    marks = chapters(script)
    if len(marks) > 1:
        parts.append("■ 目次\n" + "\n".join(f"{_clock(t)} {title}" for t, title in marks))
    if script.sources:
        # ニュース系では出典の明示が要る。frontmatter の sources をそのまま並べる
        parts.append("■ 出典\n" + "\n".join(script.sources))
    if credits:
        parts.append("■ クレジット\n" + "\n".join(credits))
    if script.tags:
        parts.append(" ".join(f"#{tag}" for tag in script.tags))
    return "\n\n".join(parts).strip() + "\n"


def write_outputs(script: Script, out_dir: Path, credits: list[str] | None = None) -> dict[str, Path]:
    out_dir.mkdir(parents=True, exist_ok=True)
    files = {
        "srt": out_dir / "subtitles.srt",
        "description": out_dir / "description.txt",
        "script_json": out_dir / "script.json",
    }
    files["srt"].write_text(to_srt(script), encoding="utf-8")
    files["description"].write_text(
        f"{script.title}\n\n{description(script, credits)}", encoding="utf-8"
    )
    files["script_json"].write_text(script.to_json(), encoding="utf-8")
    return files


def _timestamp(seconds: float) -> str:
    ms = int(round(seconds * 1000))
    hours, ms = divmod(ms, 3_600_000)
    minutes, ms = divmod(ms, 60_000)
    secs, ms = divmod(ms, 1000)
    return f"{hours:02d}:{minutes:02d}:{secs:02d},{ms:03d}"


def _clock(seconds: float) -> str:
    total = int(seconds)
    hours, rest = divmod(total, 3600)
    minutes, secs = divmod(rest, 60)
    return f"{hours}:{minutes:02d}:{secs:02d}" if hours else f"{minutes}:{secs:02d}"

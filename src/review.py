"""公開前の点検。書き出したものを、出す前にひととおり見る。

チェックリストを人が目で追うと、疲れている日ほど飛ばす。
機械で確かめられるものは機械にやらせ、人にしか見られないものだけ残す。
"""

from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path

from .script_model import Script
from .subtitles import chapters

# YouTube の実務上の上限。超えると切られる
TITLE_LIMIT = 100
DESCRIPTION_LIMIT = 5000
# 参考チャンネルの尺。短すぎても長すぎても離脱する
MIN_SECONDS = 90
MAX_SECONDS = 240


@dataclass
class Finding:
    ok: bool
    label: str
    detail: str = ""

    def line(self) -> str:
        return f"  {'✓' if self.ok else '×'} {self.label}" + (
            f"　{self.detail}" if self.detail else ""
        )


def inspect(script: Script, out_dir: Path, duration: float | None = None) -> list[Finding]:
    """出せる状態かを見る。× が1つでもあれば直してから出す。"""
    findings: list[Finding] = []

    findings.append(_length("タイトル", script.title, TITLE_LIMIT))

    description = out_dir / "description.txt"
    if description.exists():
        body = description.read_text(encoding="utf-8")
        findings.append(_length("概要欄", body, DESCRIPTION_LIMIT))
    else:
        findings.append(Finding(False, "概要欄", "description.txt がありません"))

    findings.append(_files(out_dir))
    findings.append(_sources(script))
    findings.append(_tiers(script))
    findings.append(_marks(script))
    if duration is not None:
        findings.append(_duration(duration))
    return findings


def built_duration(out_dir: Path) -> float | None:
    """ビルドで書き出した script.json から実尺を読む。

    台本ファイル自体には時刻が入っていない（ビルドのときに決まる）ので、
    書き出しの結果を見る。まだビルドしていなければ尺の判定を飛ばす。
    """
    target = out_dir / "script.json"
    if not target.exists():
        return None
    try:
        data = json.loads(target.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return None

    end = 0.0
    for scene in data.get("scenes") or []:
        for line in scene.get("lines") or []:
            end = max(end, float(line.get("start", 0)) + float(line.get("duration", 0)))
    return end or None


def manual_checks() -> list[str]:
    """機械では見られないもの。人が目と耳で確かめる。"""
    return [
        "出典URLを開いて、記事が消えたり内容が変わったりしていないか",
        "確度バッジが画面で正しく出ているか（確定と未確認の取り違えは致命的）",
        "選手名・クラブ名の読み上げが合っているか",
        "サムネの文字が切れていないか、一覧で見て読めるか",
        "BGMがナレーションを潰していないか",
    ]


def _length(label: str, text: str, limit: int) -> Finding:
    size = len(text)
    return Finding(size <= limit, label, f"{size}文字 / 上限{limit}")


def _files(out_dir: Path) -> Finding:
    needed = ["video.mp4", "thumbnail.png", "subtitles.srt", "description.txt"]
    missing = [name for name in needed if not (out_dir / name).exists()]
    if missing:
        return Finding(False, "書き出し", f"足りない: {', '.join(missing)}")
    return Finding(True, "書き出し", f"{len(needed)}件そろっている")


def _sources(script: Script) -> Finding:
    if not script.sources:
        return Finding(False, "出典", "1本もありません")
    return Finding(True, "出典", f"{len(script.sources)}本")


def _tiers(script: Script) -> Finding:
    """確度の付け忘れを見る。ニュースで確度なしの行が続くのは危ない。"""
    labelled = [line for line in script.lines if line.source]
    if not labelled:
        return Finding(False, "確度", "どの行にも source が付いていません")
    return Finding(True, "確度", f"{len(labelled)}行に付いている")


def _marks(script: Script) -> Finding:
    marks = chapters(script)
    if len(marks) < 2:
        return Finding(False, "チャプター", "章が1つしかありません")
    if marks[0][0] != 0.0:
        return Finding(False, "チャプター", "最初が 0:00 になっていません")
    times = [t for t, _ in marks]
    if times != sorted(times):
        return Finding(False, "チャプター", "時刻の順番が乱れています")
    return Finding(True, "チャプター", f"{len(marks)}章")


def _duration(seconds: float) -> Finding:
    shown = f"{int(seconds) // 60}分{int(seconds) % 60}秒"
    if seconds < MIN_SECONDS:
        return Finding(False, "尺", f"{shown}　短すぎます（{MIN_SECONDS // 60}分以上に）")
    if seconds > MAX_SECONDS:
        return Finding(False, "尺", f"{shown}　長すぎます（{MAX_SECONDS // 60}分まで）")
    return Finding(True, "尺", shown)

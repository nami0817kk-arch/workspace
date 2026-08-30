"""今日どこまで進んでいて、次に何をすればよいかを出す。

scan → pick → plan → draft → build → review を毎回手で繋いでいると、
どこまでやったか分からなくなる。ファイルの有無から進み具合を読み取る。
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import date
from pathlib import Path

from .config import _resolve

STEPS = ("候補", "取材メモ", "台本", "書き出し")


@dataclass
class Slot:
    key: str
    name: str
    notes: Path
    script: Path
    output: Path

    @property
    def done(self) -> list[str]:
        found = []
        if self.notes.exists():
            found.append("取材メモ")
        if self.script.exists():
            found.append("台本")
        if (self.output / "video.mp4").exists():
            found.append("書き出し")
        return found

    def next_command(self, stamp: str) -> str:
        if not self.notes.exists():
            return f"python -m src.cli plan --routine {self.key} --write"
        if not self.script.exists():
            return f"python -m src.cli draft {_short(self.notes)}"
        if not (self.output / "video.mp4").exists():
            return f"python -m src.cli build {_short(self.script)}"
        return f"python -m src.cli review {_short(self.script)}"


def survey(slots: list[tuple[str, str]], today: date | None = None) -> tuple[Path, list[Slot]]:
    """候補ファイルと、枠ごとの進み具合を返す。"""
    today = today or date.today()
    stamp = today.strftime("%Y%m%d")
    candidates = _resolve(f"research/{stamp}_candidates.yaml")

    found = [
        Slot(
            key=key,
            name=name,
            notes=_resolve(f"research/{stamp}_{key}.yaml"),
            script=_resolve(f"scripts/{stamp}_{key}.md"),
            output=_resolve(f"output/{stamp}_{key}"),
        )
        for key, name in slots
    ]
    return candidates, found


def next_step(candidates: Path, slots: list[Slot], stamp: str) -> str:
    """いま打つべきコマンドを1つだけ返す。"""
    if not candidates.exists():
        return "python -m src.cli scan --write"

    # どの枠にも取材メモが無いなら、まだテーマが決まっていない
    if not any(slot.notes.exists() for slot in slots):
        return f"python -m src.cli pick {_short(candidates)}"

    for slot in slots:
        if len(slot.done) < len(STEPS) - 1:
            return slot.next_command(stamp)
    return "python -m src.cli upload output/<書き出し先>"


def _short(path: Path) -> str:
    """打ちやすいよう、リポジトリからの相対にする。"""
    try:
        return str(path.relative_to(_resolve(".")))
    except ValueError:
        return str(path)

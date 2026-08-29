"""扱った話題の記録。同じネタを繰り返さないためのもの。

1日3本を続けると「朝に出した話を夜にもう一度出す」が必ず起きる。
台本を作るたびに記録し、次に作るとき突き合わせる。
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timedelta
from pathlib import Path

import yaml

from .config import _resolve


@dataclass
class Entry:
    key: str            # 話題の識別子（取材メモの id）
    headline: str
    slot: str
    at: datetime

    def to_dict(self) -> dict:
        return {
            "key": self.key,
            "headline": self.headline,
            "slot": self.slot,
            "at": self.at.isoformat(timespec="minutes"),
        }


def load(path: str | Path) -> list[Entry]:
    target = _resolve(path)
    if not target.exists():
        return []
    raw = yaml.safe_load(target.read_text(encoding="utf-8")) or {}
    entries: list[Entry] = []
    for row in raw.get("covered") or []:
        try:
            entries.append(
                Entry(
                    key=str(row.get("key", "")),
                    headline=str(row.get("headline", "")),
                    slot=str(row.get("slot", "")),
                    at=datetime.fromisoformat(str(row.get("at"))),
                )
            )
        except (TypeError, ValueError):
            continue  # 壊れた行は読み飛ばす。記録が理由で止まらないように
    return entries


def save(path: str | Path, entries: list[Entry]) -> Path:
    target = _resolve(path)
    target.parent.mkdir(parents=True, exist_ok=True)
    body = {"covered": [entry.to_dict() for entry in entries]}
    target.write_text(
        "# 扱った話題の記録。draft のたびに追記される\n"
        + yaml.safe_dump(body, allow_unicode=True, sort_keys=False),
        encoding="utf-8",
    )
    return target


def recent(entries: list[Entry], limit: int) -> list[Entry]:
    return sorted(entries, key=lambda e: e.at, reverse=True)[:limit]


def duplicates(
    entries: list[Entry], keys: list[str], within_hours: int, now: datetime | None = None
) -> dict[str, Entry]:
    """指定の時間内にすでに扱った話題を返す。"""
    now = now or datetime.now()
    edge = now - timedelta(hours=max(0, within_hours))
    found: dict[str, Entry] = {}
    for entry in sorted(entries, key=lambda e: e.at, reverse=True):
        if entry.at < edge:
            continue
        if entry.key in keys and entry.key not in found:
            found[entry.key] = entry
    return found


def record(
    path: str | Path, slot: str, items: list[tuple[str, str]], now: datetime | None = None
) -> Path:
    """(id, 見出し) の並びを記録に足す。"""
    now = now or datetime.now()
    entries = load(path)
    entries += [Entry(key=key, headline=headline, slot=slot, at=now) for key, headline in items]
    return save(path, entries)

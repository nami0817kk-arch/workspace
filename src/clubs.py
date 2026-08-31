"""クラブ名の別名辞書。見出しの書き方のゆれを1つのクラブに寄せる。

見出しは英語・現地語・日本語・略称が入り混じる。
"Spurs" と "トッテナム" が同じクラブだと分かっていないと、
ビッグクラブの判定も、同じ話題のまとめも、リーグの割り当ても取りこぼす。

照合は長い別名から順に行い、当たった箇所を消してから次を探す。
そうしないと "Inter Milan" が インテル と ミラン の両方に当たる。
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field
from functools import lru_cache
from pathlib import Path

import yaml

from .config import _resolve

DEFAULT_PATH = "config/clubs.yaml"
# 英字の別名は語の切れ目で照合する（"AFC" が "AFCボーンマス" に当たらないように）
WORD_EDGE = re.compile(r"[A-Za-z0-9]")


@dataclass
class Club:
    canonical: str
    league: str = ""
    big: bool = False
    aka: list[str] = field(default_factory=list)

    @property
    def names(self) -> list[str]:
        """照合に使う書き方。長い順（部分一致の食い合いを避ける）。"""
        found = [self.canonical, *self.aka]
        return sorted({n for n in found if n}, key=len, reverse=True)


def load(path: str | Path | None = None) -> list[Club]:
    target = _resolve(path or DEFAULT_PATH)
    if not target.exists():
        return []
    raw = yaml.safe_load(target.read_text(encoding="utf-8")) or {}
    return [
        Club(
            canonical=str(row.get("canonical", "")).strip(),
            league=str(row.get("league", "") or ""),
            big=bool(row.get("big")),
            aka=[str(a) for a in (row.get("aka") or [])],
        )
        for row in (raw.get("clubs") or [])
        if str(row.get("canonical", "")).strip()
    ]


@lru_cache(maxsize=1)
def _cached() -> tuple[Club, ...]:
    return tuple(load())


def find(text: str, clubs: list[Club] | None = None) -> list[Club]:
    """文中に出てくるクラブ。出た順に返す。

    長い別名から先に当てて、当たった箇所を伏せ字にする。
    "Inter Milan" を インテル と ミラン の2件にしない。
    """
    if not text:
        return []
    pool = list(clubs if clubs is not None else _cached())

    # どのクラブのどの別名でも、長いものから順に当てる
    pairs = sorted(
        ((name, club) for club in pool for name in club.names),
        key=lambda pair: len(pair[0]),
        reverse=True,
    )

    rest = text
    hits: list[tuple[int, Club]] = []
    for name, club in pairs:
        if any(club is found for _, found in hits):
            continue
        at = _search(rest, name)
        if at < 0:
            continue
        hits.append((at, club))
        rest = rest[:at] + "\x00" * len(name) + rest[at + len(name):]

    return [club for _, club in sorted(hits, key=lambda pair: pair[0])]


def _search(text: str, name: str) -> int:
    """名前の位置。英字の別名は語の切れ目でのみ当てる。"""
    lower, needle = text.lower(), name.lower()
    at = lower.find(needle)
    while at >= 0:
        if not _ascii(name) or _edges_clear(lower, at, len(needle)):
            return at
        at = lower.find(needle, at + 1)
    return -1


def _ascii(name: str) -> bool:
    return bool(WORD_EDGE.search(name))


def _edges_clear(text: str, at: int, length: int) -> bool:
    before = text[at - 1] if at > 0 else ""
    after = text[at + length] if at + length < len(text) else ""
    return not (WORD_EDGE.match(before or " ") or WORD_EDGE.match(after or " "))


def league_of(text: str, clubs: list[Club] | None = None) -> str:
    """見出しから読めるリーグ。複数のリーグが混ざるなら決めない。

    移籍は2クラブにまたがる。どちらのリーグの話かは書き手が決めることなので、
    分かれているときは空を返して判断を残す。
    """
    found = [club.league for club in find(text, clubs) if club.league]
    if not found or len(set(found)) > 1:
        return ""
    return found[0]


def topic_of(text: str, clubs: list[Club] | None = None) -> str:
    """話題のまとまりの当たり。先に出たクラブの正式表記。"""
    found = find(text, clubs)
    return found[0].canonical if found else ""


def is_big(text: str, clubs: list[Club] | None = None) -> bool:
    return any(club.big for club in find(text, clubs))


def canonical(text: str, clubs: list[Club] | None = None) -> list[str]:
    """文中のクラブを正式表記にそろえて返す。"""
    return [club.canonical for club in find(text, clubs)]

"""同じ話題を追い続けるための、前回との差分。

移籍も監督人事も、1本で終わらない。何日にもわたって動く。
ところが記録には「扱った」としか残っていないので、
次に同じ話が上がってきたとき、

  ・前回いつ、どこまで話したのか
  ・今日の候補のうち、前回のあとに出たものはどれか

が分からない。前回と同じことをもう一度話すか、
新しく出た1件を落とすかのどちらかになる。

ここでは記録と候補を突き合わせて、その差分だけを出す。
"""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime

from . import clubs as club_book

# これより前の記録は「続報」ではなく別件として扱う
MAX_AGE_DAYS = 21


@dataclass
class Followup:
    candidate: object
    past: list = field(default_factory=list)     # coverage.Entry、新しい順
    fresh: list[str] = field(default_factory=list)   # 前回に無い出典

    @property
    def last(self):
        return self.past[0] if self.past else None

    @property
    def is_new(self) -> bool:
        return not self.past

    def hours_since(self, now: datetime) -> float | None:
        if not self.last:
            return None
        return (now - self.last.at).total_seconds() / 3600

    def line(self, now: datetime) -> str:
        if self.is_new:
            return f"  新　{self.candidate.title}"
        gap = self.hours_since(now) or 0.0
        span = f"{gap / 24:.0f}日前" if gap >= 24 else f"{gap:.0f}時間前"
        return (
            f"  続　{self.candidate.title}\n"
            f"      {span}に{self.last.slot}で「{self.last.headline}」"
        )


def _keys(text: str, topic: str, book) -> set[str]:
    """その話題を指す語。id・topic・見出しから読めるクラブ。"""
    found = {topic.strip()} if topic and topic.strip() else set()
    found |= set(club_book.canonical(text, book))
    return {key for key in found if key}


def follow(items, entries, now: datetime | None = None, book=None) -> list[Followup]:
    """候補ごとに、前に扱ったかどうかと、前回に無い出典を出す。"""
    now = now or datetime.now()
    book = club_book.load() if book is None else book

    recent = [
        entry for entry in entries
        if (now - entry.at).days <= MAX_AGE_DAYS
    ]

    found: list[Followup] = []
    for item in items:
        mine = _keys(item.title, item.topic, book)
        past = [
            entry for entry in recent
            if entry.key == item.id or (mine and mine & _keys(entry.headline, entry.topic, book))
        ]
        past.sort(key=lambda entry: entry.at, reverse=True)

        used = {url for entry in past for url in entry.sources}
        fresh = [url for url in _sources(item) if url not in used]
        found.append(Followup(candidate=item, past=past, fresh=fresh))
    return found


def _sources(item) -> list[str]:
    urls = list(getattr(item, "sources", []) or [])
    url = getattr(item, "url", "")
    if url and url not in urls:
        urls.insert(0, url)
    return urls


def advise(followups: list[Followup], now: datetime | None = None) -> list[str]:
    """気をつけるところ。同じ話を同じ材料で二度出さないため。"""
    now = now or datetime.now()
    notes: list[str] = []
    for item in followups:
        if item.is_new or not item.last:
            continue
        if not item.fresh:
            notes.append(
                f"{item.candidate.title}: 前回（{item.last.at:%m/%d}）から新しい出典がありません。"
                "同じ材料で二度目を出すことになります"
            )
        elif len(item.past) >= 3:
            notes.append(
                f"{item.candidate.title}: これで{len(item.past) + 1}本目です。"
                "追い続ける価値があるか、いちど見直してください"
            )
    return notes

"""検索で拾ったURLが「どれくらい新しいか」を判定する。

記事の本文は開けないので、公開日は読めない。
ただしニュースサイトのURLには**連番の記事ID**が入っていて、これは時系列に増える。

  skysports.com/football/news/11095/13576511/...  ブーイングは移籍の後押しか
  skysports.com/football/news/11095/13576975/...  アトレティコは態度を崩さず
  skysports.com/football/news/11095/13577412/...  「可能性はゼロパーセント」
  skysports.com/football/news/11095/13578318/...  本人に決断の期限

話の進んだ順とIDの順が一致する。だから**同じサイトの中でなら、IDの大きいほうが新しい**。

さらに、その日いちばん大きかったIDを記録しておけば、
「検索の索引が昨日から進んだか」が分かる。進んでいなければ、その日の
検索結果はすべて昨日以前のもので、速報として使えない。

x.com だけは別で、投稿URLから正確な時刻が出る（xposts.py）。
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from datetime import datetime, timedelta
from pathlib import Path

import yaml

from . import xposts
from .config import _resolve

# サイトごとの記事IDの取り出し方。連番であることが確認できたものだけ載せる
PATTERNS: dict[str, list[re.Pattern]] = {
    "skysports.com": [
        re.compile(r"skysports\.com/(?:football|transfer)/(?:news|live-blog)/\d+/(\d+)/"),
    ],
    "espn.com": [
        re.compile(r"espn\.com/soccer/story/_/id/(\d+)/"),
    ],
}

# 記録が2点以上あり、これだけの時間が空いていないと増加ペースを出さない
MIN_SPAN_HOURS = 12.0

LEDGER_HEADER = "# 検索の索引がどこまで進んだかの記録。fresh のたびに追記される\n"


class FreshnessError(Exception):
    pass


@dataclass
class Ref:
    """1つのURLから読み取れたもの。"""

    url: str
    site: str = ""
    number: int = 0          # 記事ID。大きいほど新しい
    posted_at: datetime | None = None   # x.com だけ正確に分かる

    @property
    def known(self) -> bool:
        return bool(self.site)


@dataclass
class Observation:
    site: str
    max_number: int
    at: datetime

    def to_dict(self) -> dict:
        return {
            "site": self.site,
            "max": self.max_number,
            "at": self.at.isoformat(timespec="minutes"),
        }


def read(url: str) -> Ref:
    """URLからサイト名と記事IDを取り出す。読めなければ site が空。"""
    text = (url or "").strip()

    if xposts.is_post(text):
        _, post_id = xposts.parse_url(text)
        return Ref(url=text, site="x.com", number=post_id, posted_at=xposts.posted_at(text))

    for site, patterns in PATTERNS.items():
        for pattern in patterns:
            match = pattern.search(text)
            if match:
                return Ref(url=text, site=site, number=int(match.group(1)))
    return Ref(url=text)


def rank(urls: list[str]) -> dict[str, list[Ref]]:
    """サイトごとに、新しい順に並べる。

    サイトをまたいでIDを比べても意味がないので、まとめずに分けて返す。
    """
    groups: dict[str, list[Ref]] = {}
    for url in urls:
        ref = read(url)
        if ref.known:
            groups.setdefault(ref.site, []).append(ref)
    for refs in groups.values():
        refs.sort(key=lambda r: r.number, reverse=True)
    return groups


def load(path: str | Path) -> list[Observation]:
    target = _resolve(path)
    if not target.exists():
        return []
    raw = yaml.safe_load(target.read_text(encoding="utf-8")) or {}
    entries: list[Observation] = []
    for row in raw.get("observed") or []:
        try:
            entries.append(
                Observation(
                    site=str(row["site"]),
                    max_number=int(row["max"]),
                    at=datetime.fromisoformat(str(row["at"])),
                )
            )
        except (KeyError, TypeError, ValueError):
            continue  # 壊れた行で止めない
    return sorted(entries, key=lambda o: o.at)


def save(path: str | Path, entries: list[Observation]) -> Path:
    target = _resolve(path)
    target.parent.mkdir(parents=True, exist_ok=True)
    body = {"observed": [entry.to_dict() for entry in sorted(entries, key=lambda o: o.at)]}
    target.write_text(
        LEDGER_HEADER + yaml.safe_dump(body, allow_unicode=True, sort_keys=False),
        encoding="utf-8",
    )
    return target


def latest(entries: list[Observation], site: str) -> Observation | None:
    found = [e for e in entries if e.site == site]
    return max(found, key=lambda o: o.at) if found else None


def rate(entries: list[Observation], site: str) -> float | None:
    """そのサイトの記事IDが1時間に何ずつ増えるか。

    記録が足りないうちは None を返す。憶測で埋めない。
    """
    found = sorted((e for e in entries if e.site == site), key=lambda o: o.at)
    if len(found) < 2:
        return None
    first, last = found[0], found[-1]
    hours = (last.at - first.at).total_seconds() / 3600
    if hours < MIN_SPAN_HOURS:
        return None
    step = last.max_number - first.max_number
    return step / hours if step > 0 else None


def hours_ago(ref: Ref, entries: list[Observation], now: datetime | None = None) -> float | None:
    """その記事が何時間前のものかの推定。

    x.com は正確な値。ニュースサイトは、記録がたまって増加ペースが出せて
    いれば推定する。出せなければ None。
    """
    now = now or datetime.now()
    if ref.site == "x.com":
        return xposts.Post(url=ref.url, posted_at=ref.posted_at).hours_ago()

    anchor = latest(entries, ref.site)
    pace = rate(entries, ref.site)
    if anchor is None or not pace:
        return None
    behind = (anchor.max_number - ref.number) / pace
    return behind + (now - anchor.at).total_seconds() / 3600


def observe(
    groups: dict[str, list[Ref]], entries: list[Observation], now: datetime | None = None
) -> tuple[list[Observation], dict[str, int]]:
    """今回見た最大IDを記録に足す。(新しい記録, サイトごとの前回からの伸び) を返す。

    x.com は投稿時刻が直接分かるので記録しない。
    """
    now = now or datetime.now()
    added = list(entries)
    growth: dict[str, int] = {}
    for site, refs in groups.items():
        if site == "x.com" or not refs:
            continue
        seen = max(ref.number for ref in refs)
        previous = latest(entries, site)
        growth[site] = seen - previous.max_number if previous else 0
        if previous is None or seen > previous.max_number:
            added.append(Observation(site=site, max_number=seen, at=now))
    return added, growth


def advice(growth: dict[str, int], entries: list[Observation], now=None) -> list[str]:
    """索引が進んでいないサイトを知らせる。"""
    now = now or datetime.now()
    notes: list[str] = []
    for site, step in sorted(growth.items()):
        if step > 0:
            continue
        previous = latest(entries, site)
        if previous is None:
            continue
        stale = (now - previous.at).total_seconds() / 3600
        notes.append(
            f"{site}: 前回（{previous.at:%m/%d %H:%M}／{stale:.0f}時間前）から"
            "いちばん新しい記事が変わっていません。検索の索引が進んでいないので、"
            "この結果は速報には使えません"
        )
    return notes

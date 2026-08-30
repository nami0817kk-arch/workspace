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
from datetime import date, datetime, time, timedelta
from pathlib import Path

import yaml

from . import xposts
from .config import _resolve

# URLに公開日が入っているサイト。ここに当たれば推定は要らない。
# 日本語media はたいてい日付を含む。実測で確認できたものだけ載せる
DATE_PATTERNS: dict[str, re.Pattern] = {
    # soccer-king.jp/news/world/esp/20260828/2197673.html
    "soccer-king.jp": re.compile(r"soccer-king\.jp/news/[^?]*?/(\d{4})(\d{2})(\d{2})/"),
    # footballchannel.jp/2026/08/27/post999381/
    "footballchannel.jp": re.compile(r"footballchannel\.jp/(\d{4})/(\d{2})/(\d{2})/"),
    # caughtoffside.com/2026/08/29/...
    "caughtoffside.com": re.compile(r"caughtoffside\.com/(\d{4})/(\d{2})/(\d{2})/"),
    "football-tribe.com": re.compile(r"football-tribe\.com/[^?]*?/(\d{4})/(\d{2})/(\d{2})/"),
    "slbenfica.pt": re.compile(r"slbenfica\.pt/[^?]*?/(\d{4})/(\d{2})/(\d{2})/"),
    "acmilan.com": re.compile(r"acmilan\.com/[^?]*?/(\d{4})-(\d{2})-(\d{2})/"),
}

# 上のどれにも当たらないとき用。/2026/08/30/ を含むURLはどのサイトでも日付が読める
# （WordPress系に多い）。日付として成立しないものは弾く
GENERIC_DATE = re.compile(r"https?://(?:www\.)?([^/]+)/(?:[^?]*?/)?(\d{4})/(\d{2})/(\d{2})(?:/|-)")

# サイトごとの記事IDの取り出し方。連番であることが確認できたものだけ載せる
PATTERNS: dict[str, list[re.Pattern]] = {
    # セクション名は news / live-blog / transfer-paper-talk など複数ある。
    # 増えても拾えるように、2つめの区切りは決め打ちにしない
    "skysports.com": [
        re.compile(r"skysports\.com/(?:football|transfer)/[a-z0-9-]+/\d+/(\d+)/"),
    ],
    "espn.com": [
        re.compile(r"espn\.com/soccer/story/_/id/(\d+)/"),
    ],
    "web.ultra-soccer.jp": [
        re.compile(r"ultra-soccer\.jp/news/[a-z]+/(\d+)"),
    ],
    "premierleague.com": [
        re.compile(r"premierleague\.com/[a-z-]+/news/(\d+)"),
    ],
}

# 記録が2点以上あり、これだけの時間が空いていないと増加ペースを出さない
MIN_SPAN_HOURS = 4.0

# 測った時間の何倍まで外挿してよいか。
# 記事の出る量は時間帯で変わるので、5時間の観測から4日前を割り出すのは無理がある。
# 範囲を超えたら数字を出さず「不明」にする
MAX_EXTRAPOLATION = 3.0

# 前回からこれだけ経っていないと「索引が止まった」とは言わない。
# 数分後に回し直しただけで警告を出すと、警告として機能しなくなる
MIN_STALL_HOURS = 6.0

LEDGER_HEADER = "# 検索の索引がどこまで進んだかの記録。fresh のたびに追記される\n"


class FreshnessError(Exception):
    pass


@dataclass
class Ref:
    """1つのURLから読み取れたもの。"""

    url: str
    site: str = ""
    number: int = 0          # 記事ID。大きいほど新しい
    posted_at: datetime | None = None   # 正確な時刻が分かるとき（x.com）
    posted_on: date | None = None       # 正確な日付が分かるとき（URLに入っているサイト）

    @property
    def known(self) -> bool:
        return bool(self.site or self.posted_on)

    @property
    def exact(self) -> bool:
        """推定ではなく、はっきり分かっているか。"""
        return self.posted_at is not None or self.posted_on is not None


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

    # URLに日付が入っていれば、それがいちばん確かな手がかり
    for site, pattern in DATE_PATTERNS.items():
        match = pattern.search(text)
        if match:
            year, month, day = (int(g) for g in match.groups())
            try:
                return Ref(url=text, site=site, posted_on=date(year, month, day))
            except ValueError:
                break  # 日付として成立しない。IDの手がかりを探しにいく

    for site, patterns in PATTERNS.items():
        for pattern in patterns:
            match = pattern.search(text)
            if match:
                return Ref(url=text, site=site, number=int(match.group(1)))

    # 登録していないサイトでも、URLに日付が入っていれば読む
    match = GENERIC_DATE.search(text)
    if match:
        host, year, month, day = match.groups()
        try:
            return Ref(url=text, site=host, posted_on=date(int(year), int(month), int(day)))
        except ValueError:
            pass
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
        # 日付が分かるものはそれで、分からなければ記事IDで並べる
        refs.sort(key=lambda r: (r.posted_on or date.min, r.number), reverse=True)
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


def span(entries: list[Observation], site: str) -> float:
    """そのサイトを何時間ぶん観測できているか。"""
    found = sorted((e for e in entries if e.site == site), key=lambda o: o.at)
    if len(found) < 2:
        return 0.0
    return (found[-1].at - found[0].at).total_seconds() / 3600


def hours_ago(ref: Ref, entries: list[Observation], now: datetime | None = None) -> float | None:
    """その記事が何時間前のものかの推定。

    x.com は正確な値。ニュースサイトは、記録がたまって増加ペースが出せて
    いれば推定する。出せなければ None。
    """
    now = now or datetime.now()
    if ref.posted_at is not None:
        return xposts.Post(url=ref.url, posted_at=ref.posted_at).hours_ago()

    if ref.posted_on is not None:
        # 日付までしか分からないので、その日の正午に出たものとして扱う。
        # 半日ぶんの誤差はあるが、推定と違って日付そのものは確かめてある
        noon = datetime.combine(ref.posted_on, time(12, 0))
        return max(0.0, (now - noon).total_seconds() / 3600)

    anchor = latest(entries, ref.site)
    pace = rate(entries, ref.site)
    if anchor is None or not pace:
        return None

    behind = (anchor.max_number - ref.number) / pace
    if behind > span(entries, ref.site) * MAX_EXTRAPOLATION:
        return None  # 測った範囲から離れすぎている。憶測になるので出さない
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
        if stale < MIN_STALL_HOURS:
            continue  # 前回からまだ間がない。止まったかどうかは判断できない
        notes.append(
            f"{site}: 前回（{previous.at:%m/%d %H:%M}／{stale:.0f}時間前）から"
            "いちばん新しい記事が変わっていません。検索の索引が進んでいないので、"
            "この結果は速報には使えません"
        )
    return notes

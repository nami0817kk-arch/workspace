"""移籍期限の日程。近づいたら知らせ、当日は枠を切り替える。

期限日は1日で決着がつくので、前日に気づいても間に合わない。
「あと何時間か」を毎回 today / scan が言うようにして、
気づいたときには終わっていた、を防ぐ。

時刻はすべて日本時間で持つ（config/sources.yaml も日本時間で書く）。
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timedelta, timezone

TOKYO = timezone(timedelta(hours=9))

NOTICE_DAYS = 5      # 何日前から告知するか（config で上書きできる）
AFTER_HOURS = 36     # 期限後、総括を促し続ける時間
NEAR_HOURS = 24      # ここを切ったら時間で数える


@dataclass
class Deadline:
    league: str
    name: str
    at: datetime
    local: str = ""
    confirmed: bool = False

    def hours_from(self, now: datetime) -> float:
        """今から期限までの時間。過ぎていれば負。"""
        return (self.at - _aware(now)).total_seconds() / 3600.0

    @property
    def stamp(self) -> str:
        return f"{self.at.month}月{self.at.day}日 {self.at:%H:%M}"


def _aware(when: datetime) -> datetime:
    """素朴な日時は日本時間とみなす。"""
    return when if when.tzinfo else when.replace(tzinfo=TOKYO)


def parse_at(text: str) -> datetime | None:
    """"2026-09-02 07:00" を日本時間の日時にする。読めなければ None。"""
    for shape in ("%Y-%m-%d %H:%M", "%Y-%m-%dT%H:%M", "%Y-%m-%d"):
        try:
            return datetime.strptime(str(text).strip(), shape).replace(tzinfo=TOKYO)
        except ValueError:
            continue
    return None


def load(plan) -> list[Deadline]:
    """計画の calendar から期限を読み、近い順に返す。"""
    body = getattr(plan, "calendar", None) or {}
    found: list[Deadline] = []
    for row in body.get("deadlines") or []:
        row = dict(row or {})
        at = parse_at(row.get("at", ""))
        if at is None:
            continue
        key = str(row.get("league", ""))
        found.append(
            Deadline(
                league=key,
                name=plan.league_name(key) if key else "移籍期限",
                at=at,
                local=str(row.get("local", "") or ""),
                confirmed=bool(row.get("confirmed")),
            )
        )
    return sorted(found, key=lambda d: d.at)


def active(items: list[Deadline], now: datetime, after_hours: float = AFTER_HOURS) -> list[Deadline]:
    """いま特別編を出すべき期限。当日（残り24時間以内）と、過ぎた直後。"""
    return [
        item for item in items
        if -abs(after_hours) <= item.hours_from(now) <= NEAR_HOURS
    ]


def notices(
    items: list[Deadline],
    now: datetime,
    notice_days: float = NOTICE_DAYS,
    after_hours: float = AFTER_HOURS,
) -> list[str]:
    """告知の行。期限が遠ければ何も返さない。

    同じ時刻に閉まるリーグは1行にまとめる。
    5リーグを5行並べると、どれが今日なのか読み取れなくなる。
    """
    groups: dict[datetime, list[Deadline]] = {}
    for item in items:
        hours = item.hours_from(now)
        if hours > notice_days * 24 or hours < -abs(after_hours):
            continue
        groups.setdefault(item.at, []).append(item)

    return [
        _line(group, group[0].hours_from(now))
        for _, group in sorted(groups.items())
    ]


def _line(group: list[Deadline], hours: float) -> str:
    head = group[0]
    who = " / ".join(item.name for item in group)
    when = f"{head.stamp} JST"
    # 現地時刻はリーグごとに違う。全部が同じときだけ添える。
    # 1つだけ書いてあるものを全体の現地時刻として見せると嘘になる
    locals_ = {item.local for item in group}
    if len(locals_) == 1 and group[0].local:
        when += f"／{group[0].local}"

    if hours < 0:
        text = f"{who}の移籍期限は{_hours(-hours)}前に締まった。成立と破談の総括を出す（{when}）"
    elif hours <= NEAR_HOURS:
        # 当日は時間で言う。「あと1日」では今日中かどうか判断できない
        text = f"⚠ 移籍期限まで残り{_hours(hours)}　{who}（{when}）"
    else:
        text = f"移籍期限まであと{_span(hours)}　{who}（{when}）"

    unsure = [item.name for item in group if not item.confirmed]
    if unsure:
        text += f"　※日付は未確認（{' / '.join(unsure)}）。リーグの発表で確かめる"
    return text


def _span(hours: float) -> str:
    """残り時間を、その場で判断できる粒度で言う。"""
    if hours < NEAR_HOURS:
        return _hours(hours)
    return f"{int(hours // 24)}日"


def _hours(hours: float) -> str:
    if hours < 1 / 6:
        return "わずか"
    if hours < 1:
        return f"{int(hours * 60)}分"
    return f"{int(hours)}時間"


def unconfirmed(items: list[Deadline], now: datetime, notice_days: float = NOTICE_DAYS) -> list[Deadline]:
    """告知するのに日付を確かめていないもの。doctor が拾う。"""
    return [
        item for item in items
        if not item.confirmed and -abs(AFTER_HOURS) <= item.hours_from(now) <= notice_days * 24
    ]

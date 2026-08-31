"""リーグごとに「情報が出る時間帯」を持つ。

欧州の発表は日本の深夜から早朝に出る。日本時間の昼にプレミアを探しても、
そこにあるのは前夜の記事の焼き直しで、新しいものは無い。
逆に朝5時半のスキャンでJリーグを探しても、まだ何も動いていない。

どのリーグが「いま動いているか」を出しておけば、
その時刻に取れるものから順に当たれる。

現地時刻とUTCの差（utc_offset）は夏時間の値で持つ。
冬時間に入ったら1つ減らす（clocks.summer_until を過ぎると doctor が言う）。
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import date, datetime, time

JST_OFFSET = 9
# あと何時間で閉じるなら「先に当たれ」と言うか
CLOSING_SOON = 1.5


@dataclass
class Window:
    league: str
    name: str
    start: time      # 日本時間
    end: time

    @property
    def wraps(self) -> bool:
        """日付をまたぐ帯か（欧州の夜は日本の未明）。"""
        return self.end <= self.start

    def covers(self, at: time) -> bool:
        if self.wraps:
            return at >= self.start or at < self.end
        return self.start <= at < self.end

    @property
    def label(self) -> str:
        return f"{self.start:%H:%M}〜{self.end:%H:%M}"

    def hours_until(self, at: time) -> float:
        """開くまでの時間。開いていれば0。"""
        if self.covers(at):
            return 0.0
        return _gap(at, self.start)

    def hours_left(self, at: time) -> float:
        """閉じるまでの時間。閉じていれば0。"""
        if not self.covers(at):
            return 0.0
        return _gap(at, self.end)


def _parse_span(text: str) -> tuple[time, time] | None:
    head, _, tail = str(text or "").partition("-")
    try:
        return (
            time.fromisoformat(head.strip()),
            time.fromisoformat(tail.strip()),
        )
    except ValueError:
        return None


def _gap(at: time, mark: time) -> float:
    """at から mark までの時間（日付をまたいでも正しく出す）。"""
    now = at.hour + at.minute / 60
    goal = mark.hour + mark.minute / 60
    return (goal - now) % 24


def _shift(at: time, hours: int) -> time:
    total = (at.hour + hours) % 24
    return time(total, at.minute)


def windows(plan) -> list[Window]:
    """各リーグの帯を日本時間に直す。書いていないリーグは出さない。"""
    found: list[Window] = []
    for key, entry in (plan.leagues or {}).items():
        span = _parse_span(entry.get("active_local", ""))
        if span is None:
            continue
        try:
            shift = JST_OFFSET - int(entry.get("utc_offset", JST_OFFSET))
        except (TypeError, ValueError):
            continue
        start, end = span
        found.append(
            Window(
                league=str(key),
                name=plan.league_name(key),
                start=_shift(start, shift),
                end=_shift(end, shift),
            )
        )
    return found


def open_now(plan, now: datetime | None = None) -> list[Window]:
    """いま記事が出ている（はずの）リーグ。"""
    at = (now or datetime.now()).time()
    return [w for w in windows(plan) if w.covers(at)]


def order(plan, keys: list[str], now: datetime | None = None) -> list[str]:
    """リーグの並びを、いま動いている順にする。

    帯を書いていないリーグは順番を変えない（判断の材料が無いので）。
    """
    at = (now or datetime.now()).time()
    known = {w.league: w for w in windows(plan)}

    def rank(key: str) -> tuple[float, int]:
        window = known.get(key)
        if window is None:
            # 帯を書いていないリーグ。開いているものと閉じているものの間に置く
            return (0.5, keys.index(key))
        if window.covers(at):
            # 開いているものは、先に閉じるほうから当たる
            return (window.hours_left(at) / 100, keys.index(key))
        return (1 + window.hours_until(at), keys.index(key))

    return sorted(keys, key=rank)


def advice(plan, now: datetime | None = None) -> list[str]:
    """いま何を見ればよいか。1〜2行。"""
    now = now or datetime.now()
    at = now.time()
    found = windows(plan)
    if not found:
        return []

    live = sorted((w for w in found if w.covers(at)), key=lambda w: w.hours_left(at))
    lines = []
    if live:
        lines.append(f"いま動いている（{now:%H:%M}）: {' / '.join(w.name for w in live)}")
        # 先に閉じるリーグから当たる。閉じたあとは翌日まで新しいものが出ない
        closing = [w for w in live if w.hours_left(at) <= CLOSING_SOON]
        if closing and len(closing) < len(live):
            lines.append(
                f"先に当たる: {' / '.join(w.name for w in closing)}"
                f"（あと{closing[0].hours_left(at):.0f}時間で静かになります）"
            )
    else:
        lines.append(f"どのリーグも静かな時間帯です（{now:%H:%M}）")

    closed = sorted(
        (w for w in found if not w.covers(at)),
        key=lambda w: w.hours_until(at),
    )
    if closed and not live:
        soon = closed[0]
        lines.append(f"次に開くのは {soon.name}　{soon.label}（あと{soon.hours_until(at):.0f}時間）")
    return lines


def summer_over(plan, today: date | None = None) -> bool:
    """夏時間の期限を過ぎたか。offset を直す合図。"""
    raw = (getattr(plan, "clocks", None) or {}).get("summer_until")
    if not raw:
        return False
    limit = raw if isinstance(raw, date) else _as_date(raw)
    if limit is None:
        return False
    return (today or date.today()) > limit


def _as_date(text) -> date | None:
    try:
        return date.fromisoformat(str(text))
    except ValueError:
        return None

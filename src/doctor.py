"""収集の健康診断。

網・記録・検索・カバレッジを別々のコマンドで見ていると、どれかを見忘れる。
まとめて1回で点検し、放っておくと効かなくなるものだけを挙げる。
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import date, datetime

from . import coverage, deadlines, freshness, newsites, queries, stats, timing, xposts

# 情報源の網を確かめ直す間隔。塞がれるサイトも、開くサイトもある
VERIFY_DAYS = 90
# 索引の記録がこれだけ止まっていたら、fresh を回していない
LEDGER_QUIET_DAYS = 3


@dataclass
class Note:
    ok: bool
    label: str
    detail: str = ""

    def line(self) -> str:
        return f"  {'✓' if self.ok else '×'} {self.label}" + (f"　{self.detail}" if self.detail else "")


def diagnose(plan, now: datetime | None = None) -> list[Note]:
    """効かなくなっているところを挙げる。"""
    now = now or datetime.now()
    notes = [
        _network(plan, now),
        _index(plan, now),
        _searches(),
        _reporters(plan),
    ]
    notes.append(_feeds(plan))
    notes.append(_calendar(plan, now))
    notes.append(_newsites())
    notes.append(_clocks(plan, now))
    notes += _coverage(plan, now)
    return notes


def _clocks(plan, now: datetime) -> Note:
    """現地時刻の差。夏時間のまま冬に入ると、時間帯の判断が1時間ずれる。"""
    spans = timing.windows(plan)
    if not spans:
        return Note(True, "時間帯", "リーグに active_local が書かれていません")
    if timing.summer_over(plan, now.date()):
        return Note(
            False,
            "時間帯",
            "夏時間の期限を過ぎています。leagues の utc_offset を1つ減らし、"
            "clocks.summer_until を次の期限に直してください",
        )
    live = timing.open_now(plan, now)
    return Note(True, "時間帯", f"{len(spans)}リーグに設定あり（いま動いている: {len(live)}）")


def _newsites() -> Note:
    """網の外から繰り返し返ってくるサイト。足すべきものを見落としていないか。"""
    sites = newsites.load()
    if not sites:
        return Note(True, "網の外", "控えなし（collect を回すと貯まります）")
    picks = newsites.propose(sites)
    if picks:
        return Note(
            False,
            "網の外",
            f"繰り返し出るサイトが{len(picks)}件: "
            f"{' / '.join(site.host for site in picks[:4])}。"
            "足すか blocked に入れるか決めてください",
        )
    return Note(True, "網の外", f"控え{len(sites)}件（まだ繰り返しは無い）")


def _calendar(plan, now: datetime) -> Note:
    """移籍期限の日程。近いのに日付を確かめていないものは、告知が嘘になる。"""
    items = deadlines.load(plan)
    if not items:
        return Note(True, "日程", "移籍期限の登録なし")

    body = plan.calendar or {}
    notice_days = float(body.get("notice_days", deadlines.NOTICE_DAYS))
    soon = deadlines.notices(items, now, notice_days=notice_days)
    unsure = deadlines.unconfirmed(items, now, notice_days=notice_days)
    if unsure:
        return Note(
            False,
            "日程",
            f"間近の移籍期限{len(unsure)}件の日付が未確認: "
            f"{' / '.join(item.name for item in unsure)}",
        )
    if soon:
        return Note(True, "日程", soon[0])
    return Note(True, "日程", f"移籍期限{len(items)}件を登録（当面なし）")


def _feeds(plan) -> Note:
    feeds = getattr(plan, "feeds", []) or []
    if not feeds:
        return Note(True, "RSSフィード", "登録なし（検索経由のみ）")
    unverified = [f for f in feeds if not f.get("verified")]
    if unverified:
        return Note(
            False,
            "RSSフィード",
            f"{len(feeds)}本のうち{len(unverified)}本が未確認。"
            "運用PCで `fetch --check` を回して verified を直してください",
        )
    return Note(True, "RSSフィード", f"{len(feeds)}本すべて確認済み")


def _network(plan, now: datetime) -> Note:
    sites = sum(len(v) for k, v in plan.domains.items() if k != "blocked")
    if not plan.verified_on:
        return Note(False, "情報源の網", f"{sites}サイト。最終確認の日付がありません")
    try:
        days = (now.date() - date.fromisoformat(plan.verified_on)).days
    except ValueError:
        return Note(False, "情報源の網", f"verified_on が読めません: {plan.verified_on}")

    if days > VERIFY_DAYS:
        return Note(False, "情報源の網", f"{sites}サイト。最終確認から{days}日。確かめ直してください")
    return Note(True, "情報源の網", f"{sites}サイト。最終確認から{days}日")


def _index(plan, now: datetime) -> Note:
    entries = freshness.load("research/freshness.yaml")
    if not entries:
        return Note(False, "索引の記録", "まだありません。fresh を回すと貯まります")

    newest = max(entry.at for entry in entries)
    quiet = (now - newest).days
    if quiet >= LEDGER_QUIET_DAYS:
        return Note(False, "索引の記録", f"{len(entries)}行。{quiet}日更新がありません")

    paces = [site for site in {e.site for e in entries} if freshness.rate(entries, site)]
    return Note(True, "索引の記録", f"{len(entries)}行。ペースが出せるサイト {len(paces)}件")


def _searches() -> Note:
    runs = queries.load()
    if not runs:
        return Note(True, "検索の実績", "まだ記録がありません（collect --from で貯まります）")
    rows = queries.tally(runs)
    empty = queries.dead(rows)
    if empty:
        return Note(False, "検索の実績", f"1件も返していない検索が{len(empty)}本: {' / '.join(empty)}")
    return Note(True, "検索の実績", f"{len(rows)}本を記録")


def _reporters(plan) -> Note:
    calls = xposts.load_calls()
    if not calls:
        return Note(True, "記者の答え合わせ", "まだ控えがありません")
    problems = xposts.review_accounts(calls, plan.accounts)
    pending = sum(1 for call in calls if call.outcome == "未判明")
    if problems:
        return Note(False, "記者の答え合わせ", problems[0])
    return Note(True, "記者の答え合わせ", f"{len(calls)}件（未判明 {pending}件）")


def _coverage(plan, now: datetime) -> list[Note]:
    entries = coverage.load(plan.coverage.get("ledger", "research/covered.yaml"))
    if not entries:
        return [Note(False, "扱った話題", "まだ記録がありません")]

    leagues, kinds = stats.gaps(entries, plan.leagues, now=now)
    never = [name for _, name, days in leagues if days < 0]
    notes = [Note(True, "扱った話題", f"{len(entries)}本")]
    if never:
        notes.append(
            Note(False, "追えていないリーグ", f"{len(never)}つ: {' / '.join(never[:4])}")
        )
    return notes

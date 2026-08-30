"""収集の健康診断。

網・記録・検索・カバレッジを別々のコマンドで見ていると、どれかを見忘れる。
まとめて1回で点検し、放っておくと効かなくなるものだけを挙げる。
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import date, datetime

from . import coverage, freshness, queries, stats, xposts

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
    notes += _coverage(plan, now)
    return notes


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

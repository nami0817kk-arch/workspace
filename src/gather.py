"""収集を一息で行う。

いまは フィード取得 → collect → 重複除去 → 候補ファイル を手で繋いでいる。
毎朝それを打つと、どれかを飛ばす。飛ばしても何も言われないので、
「今日はフィードを見ていなかった」に後から気づくことになる。

ここでは順番を1つにまとめる。取り、既出を外し、控え、候補ファイルにする。
判断の要るところ（確度・話題・リーグ）は今までどおり人が埋める。
"""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import date, datetime

from . import collect as collect_mod
from . import feeds as feeds_mod
from . import freshness, newsites


@dataclass
class Haul:
    hits: list = field(default_factory=list)          # 候補になるもの
    seen: list = field(default_factory=list)          # 既出として外したもの
    notes: list[str] = field(default_factory=list)    # 人に伝えること
    tuned: dict = field(default_factory=dict)         # 較正できたサイト
    fresh_sites: list[str] = field(default_factory=list)   # 網の外で控えたホスト


def from_feeds(plan, hours: float, league: str = "") -> tuple[list, list[str]]:
    """確認済みのフィードだけを取る。未確認のものは黙って飛ばさず、そう言う。"""
    wanted = [
        feed for feed in (plan.feeds or [])
        if (not league or str(feed.get("league")) == league)
    ]
    live = [feed for feed in wanted if feed.get("verified")]
    notes: list[str] = []

    skipped = len(wanted) - len(live)
    if skipped:
        notes.append(
            f"未確認のフィードを{skipped}本飛ばしました。"
            "`fetch --check` で生死を確かめて verified: true にしてください"
        )

    items: list = []
    for feed in live:
        try:
            items += feeds_mod.recent(feeds_mod.fetch(str(feed.get("url", ""))), hours)
        except feeds_mod.FeedError as error:
            notes.append(f"{feed.get('name')} を取得できません: {error}")
    return items, notes


def used_urls(entries) -> set[str]:
    """すでに動画で使った出典。もう一度候補にしても意味がない。"""
    return {url for entry in entries for url in getattr(entry, "sources", []) or []}


def drop_seen(hits: list, known: set[str]) -> tuple[list, list]:
    """既出のURLを外す。同じURLの重複もここで落とす。"""
    kept: list = []
    dropped: list = []
    here: set[str] = set()
    for hit in hits:
        if hit.url in known:
            dropped.append(hit)
        elif hit.url in here:
            continue
        else:
            here.add(hit.url)
            kept.append(hit)
    return kept, dropped


def run(
    plan,
    hours: float,
    pasted: str = "",
    league: str = "",
    covered=None,
    today: date | None = None,
    use_feeds: bool = True,
) -> Haul:
    """取る・外す・控える をまとめて行う。"""
    haul = Haul()
    today = today or date.today()

    items: list = []
    if use_feeds:
        items, notes = from_feeds(plan, hours, league)
        haul.notes += notes
        if not items and not pasted.strip():
            haul.notes.append("フィードから何も取れませんでした。検索結果を貼るか、--paste で足してください")

    # フィードは正確な時刻を持つ。索引の水準を較正しておく
    if items:
        entries = freshness.load(freshness.LEDGER)
        entries, tuned = freshness.calibrate(
            [(item.url, item.published) for item in items if item.published], entries
        )
        if tuned:
            freshness.save(freshness.LEDGER, freshness.prune(entries))
            haul.tuned = tuned

    text = "\n".join(item.line() for item in items)
    if pasted.strip():
        text = f"{text}\n{pasted}" if text else pasted

    hits = collect_mod.enrich(collect_mod.parse(text), freshness.read)
    hits, haul.seen = drop_seen(hits, used_urls(covered or []))
    haul.hits = hits

    if hits:
        haul.fresh_sites = newsites.record([hit.url for hit in hits], plan, today)
    return haul


def summary(haul: Haul) -> list[str]:
    """何が起きたかを短く。"""
    lines = [f"取れたもの {len(haul.hits)}件"]
    if haul.seen:
        lines.append(f"すでに使った出典を{len(haul.seen)}件外しました")
    if haul.tuned:
        lines.append(f"索引の水準を較正: {' / '.join(sorted(haul.tuned))}")
    if haul.fresh_sites:
        lines.append(
            f"網に無いサイト{len(haul.fresh_sites)}件を控えました: {' / '.join(haul.fresh_sites[:4])}"
        )
    return lines

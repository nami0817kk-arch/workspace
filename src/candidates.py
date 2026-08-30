"""候補テーマの採点と、枠への割り振り。

1日3本ぶんのテーマを、毎回同じものさしで選ぶための仕組み。
スキャンで拾った候補を点数化し、朝・昼・夜のどれに回すかを決める。

点数はあくまで並べ替えの目安で、最後に選ぶのは人。
なぜその順になったかを内訳で示すので、違うと思ったら手で入れ替えればよい。
"""

from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path

import yaml

from .config import _resolve


class CandidateError(Exception):
    pass


@dataclass
class Candidate:
    id: str
    title: str
    en: str = ""        # 英語サイトを検索するときの語。無ければ英語の検索は出さない
    url: str = ""       # 元になった記事・投稿。hours_ago を省くとここから割り出す
    topic: str = ""     # 話題のまとまり（クラブ名・移籍案件など）。枠の重複を避けるのに使う
    league: str = ""    # england / spain / germany / italy / france / netherlands / japan
                        # 現地語の検索を出すかどうかの判断に使う
    hours_ago: float = 99.0
    tier: str = "未確認"
    reaction: bool = False
    big_club: bool = False
    numbers: bool = False
    note: str = ""
    sources: list[str] = field(default_factory=list)

    # 採点の結果
    score: int = 0
    breakdown: dict[str, int] = field(default_factory=dict)


def load_candidates(path: str | Path) -> tuple[str, list[Candidate]]:
    target = Path(path)
    if not target.exists():
        raise CandidateError(f"候補ファイルがありません: {target}")
    raw = yaml.safe_load(target.read_text(encoding="utf-8")) or {}

    items: list[Candidate] = []
    for index, entry in enumerate(raw.get("candidates") or [], start=1):
        entry = dict(entry or {})
        title = str(entry.get("title", "")).strip()
        if not title:
            raise CandidateError(f"{index}件目: title が空です")
        items.append(
            Candidate(
                id=str(entry.get("id") or f"c{index}"),
                title=title,
                en=str(entry.get("en", "")).strip(),
                url=str(entry.get("url", "")).strip(),
                topic=str(entry.get("topic", "")).strip(),
                league=str(entry.get("league", "")).strip().lower(),
                hours_ago=float(entry["hours_ago"]) if "hours_ago" in entry else -1.0,
                tier=str(entry.get("tier", "未確認")).strip(),
                reaction=bool(entry.get("reaction", False)),
                big_club=bool(entry.get("big_club", False)),
                numbers=bool(entry.get("numbers", False)),
                note=str(entry.get("note", "")).strip(),
                sources=[str(u).strip() for u in (entry.get("sources") or []) if str(u).strip()],
            )
        )
    if not items:
        raise CandidateError("candidates が空です")
    return str(raw.get("date", "")).strip(), items


def fill_ages(items: list[Candidate], age_of) -> list[str]:
    """hours_ago を書かなかった候補を、url から割り出して埋める。

    割り出せなければ 99（＝古い扱い）にする。新しさで点が付くので、
    分からないものを新しい側に倒すと、確認していない候補が上に来てしまう。
    """
    notes: list[str] = []
    for item in items:
        if item.hours_ago >= 0:
            continue
        age = age_of(item.url) if item.url else None
        if age is None:
            item.hours_ago = 99.0
            reason = "urlが無い" if not item.url else "urlから日付を割り出せない"
            notes.append(f"{item.title}: hours_ago が空で、{reason}ため古い扱いにしました")
        else:
            item.hours_ago = round(age, 1)
    return notes


def score(items: list[Candidate], scoring: dict) -> list[Candidate]:
    """候補に点をつける。内訳も残す。"""
    weights = dict(scoring.get("weights") or {})
    # 「6時間以内なら3点」のような段階。近いものから順に見る
    stages = sorted(
        ((float(k), int(v)) for k, v in (scoring.get("freshness_hours") or {}).items())
    )
    top = max((points for _, points in stages), default=1)
    fresh_weight = int(weights.get("freshness", 0))

    clubs = [str(c).strip() for c in (scoring.get("big_clubs") or []) if str(c).strip()]

    for item in items:
        breakdown: dict[str, int] = {}

        # ビッグクラブは名前で拾えるので、手で立てなくても効くようにする
        if not item.big_club and clubs:
            haystack = f"{item.title} {item.note}"
            item.big_club = any(club in haystack for club in clubs)

        stage = next((points for hours, points in stages if item.hours_ago <= hours), 0)
        if stage:
            # 段階の点を、この項目の重み（満点）に合わせて割り当てる
            breakdown["新しさ"] = round(stage / top * fresh_weight)

        for key, label in (
            ("reaction", "反応"),
            ("big_club", "ビッグクラブ"),
            ("numbers", "数字"),
        ):
            if getattr(item, key):
                breakdown[label] = int(weights.get(key, 0))

        item.breakdown = {k: v for k, v in breakdown.items() if v}
        item.score = sum(item.breakdown.values())
    return sorted(items, key=lambda c: (-c.score, c.hours_ago))


def assign(
    items: list[Candidate], scoring: dict, slots: list[str]
) -> tuple[dict[str, Candidate], dict[str, list[str]]]:
    """枠ごとに1本ずつ割り当てる。同じ候補は2つの枠に入れない。

    条件に合う候補が無ければ全体から選ぶ（枠を空けるより出したほうがよい）。
    そのときは満たせなかった条件を並べて返す。黙って別のものを入れると、
    枠の狙いから外れていることに気づけない。条件は複数外れることがあるので、
    1件で上書きせず全部残す。
    """
    rules = dict(scoring.get("slots") or {})
    spread = bool(scoring.get("spread_topics", True))
    remaining = list(items)
    chosen: dict[str, Candidate] = {}
    fallbacks: dict[str, list[str]] = {}
    used_topics: set[str] = set()

    for slot in slots:
        rule = dict(rules.get(slot) or {})
        pool = remaining

        # 大きい話が1つあると3本ともそれになる。すでに使った話題は外す
        if spread and used_topics:
            fresh_topics = [c for c in pool if not c.topic or c.topic not in used_topics]
            if not fresh_topics and pool:
                fallbacks.setdefault(slot, []).append("他の枠と別の話題が残っていません")
            pool = fresh_topics or pool

        tiers = rule.get("require_tier")
        if tiers:
            filtered = [c for c in pool if c.tier in tiers]
            if not filtered and pool:
                fallbacks.setdefault(slot, []).append(
                    f"確度が{' か '.join(tiers)}の候補がありません"
                )
            pool = filtered or pool

        pick = _prefer(pool, str(rule.get("prefer", "total")), slot, fallbacks)
        if pick is None:
            continue
        chosen[slot] = pick
        remaining = [c for c in remaining if c.id != pick.id]
        if pick.topic:
            used_topics.add(pick.topic)
    return chosen, fallbacks


def _prefer(
    pool: list[Candidate], prefer: str, slot: str, fallbacks: dict[str, list[str]]
) -> Candidate | None:
    """枠の方針に沿って1つ選ぶ。条件に合うものが無ければ全体から最高点。"""
    if not pool:
        return None
    if prefer == "freshness":
        return min(pool, key=lambda c: (c.hours_ago, -c.score))

    flags = {"reaction": "賛否が割れる", "big_club": "ビッグクラブが絡む"}
    if prefer in flags:
        matching = [c for c in pool if getattr(c, prefer)]
        if not matching:
            fallbacks.setdefault(slot, []).append(f"{flags[prefer]}候補がありません")
        return max(matching or pool, key=lambda c: c.score)

    return max(pool, key=lambda c: c.score)


def deep_queries(
    item: Candidate, templates: list[dict], domains: dict[str, list[str]]
) -> list[dict]:
    """選んだテーマの深掘り検索を組み立てる。

    海外サイトを日本語で検索しても何も出ないので、{en} を使う雛形は
    候補に英語の語が入っているときだけ出す。
    when: を書いた雛形は、そのリーグの候補のときだけ出す。
    """
    queries = []
    for template in templates:
        text = str(template.get("q", ""))
        if "{en}" in text and not item.en:
            continue

        # リーグが合うときだけ出す。ドイツ語の検索をスペインの話に出しても返らない
        when = str(template.get("when", "")).strip().lower()
        if when and item.league != when:
            continue

        group = template.get("domains")
        queries.append(
            {
                "q": text.replace("{theme}", item.title).replace("{en}", item.en),
                "label": str(template.get("label", "")),
                "domains": domains.get(str(group), []) if group else [],
            }
        )
    return queries


def exclude_covered(items: list[Candidate], covered: dict[str, object]) -> tuple[list, list]:
    """直近で扱った話題を候補から外す。(残り, 外したもの) を返す。"""
    keep = [c for c in items if c.id not in covered]
    dropped = [c for c in items if c.id in covered]
    return keep, dropped


def worksheet(date_label: str) -> str:
    """候補ファイルの雛形。スキャンで拾ったものをここに並べる。"""
    return f'''# 候補テーマ（{date_label}）
# スキャンで拾ったものを並べる。深掘りはまだしない。
# 埋めたら python -m src.cli pick このファイル
date: "{date_label}"
candidates:
  - id: ""            # 短い識別子。重複判定にも使う
    title: ""         # 一言で。あとで動画タイトルの素になる
    en: ""            # 英語サイトを引くときの語（例: Julian Alvarez Atletico）
    url: ""           # 元の記事・投稿のURL
    topic: ""         # 話題のまとまり（例: alvarez）。同じ topic は1日1枠まで
    league: ""        # england/spain/germany/italy/france/netherlands/japan
                      # 書くと現地語の検索も出る
    hours_ago:        # 何時間前か。空にすると url から割り出す
    tier: 報道         # 確定 / 報道 / 未確認
    reaction: false   # 賛否が割れる・驚きがあるか
    big_club: false   # ビッグクラブが絡むか
    numbers: false    # 金額・記録など数字が立つか
    note: ""          # ひとことメモ
    sources:
      - ""
'''

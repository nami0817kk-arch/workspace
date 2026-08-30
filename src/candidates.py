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
    hours_ago: float = 99.0
    tier: str = "未確認"
    japanese: bool = False
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
                hours_ago=float(entry["hours_ago"]) if "hours_ago" in entry else -1.0,
                tier=str(entry.get("tier", "未確認")).strip(),
                japanese=bool(entry.get("japanese", False)),
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
            ("japanese", "日本人"),
            ("reaction", "反応"),
            ("big_club", "ビッグクラブ"),
            ("numbers", "数字"),
        ):
            if getattr(item, key):
                breakdown[label] = int(weights.get(key, 0))

        item.breakdown = {k: v for k, v in breakdown.items() if v}
        item.score = sum(item.breakdown.values())
    return sorted(items, key=lambda c: (-c.score, c.hours_ago))


def assign(items: list[Candidate], scoring: dict, slots: list[str]) -> dict[str, Candidate]:
    """枠ごとに1本ずつ割り当てる。同じ候補は2つの枠に入れない。"""
    rules = dict(scoring.get("slots") or {})
    remaining = list(items)
    chosen: dict[str, Candidate] = {}

    for slot in slots:
        rule = dict(rules.get(slot) or {})
        pool = remaining
        tiers = rule.get("require_tier")
        if tiers:
            filtered = [c for c in pool if c.tier in tiers]
            pool = filtered or pool  # 条件に合うものが無ければ全体から選ぶ

        prefer = str(rule.get("prefer", "total"))
        if prefer == "freshness":
            pick = min(pool, key=lambda c: (c.hours_ago, -c.score), default=None)
        elif prefer == "japanese":
            japanese = [c for c in pool if c.japanese]
            pick = max(japanese or pool, key=lambda c: c.score, default=None)
        else:
            pick = max(pool, key=lambda c: c.score, default=None)

        if pick is None:
            continue
        chosen[slot] = pick
        remaining = [c for c in remaining if c.id != pick.id]
    return chosen


def deep_queries(
    item: Candidate, templates: list[dict], domains: dict[str, list[str]]
) -> list[dict]:
    """選んだテーマの深掘り検索を組み立てる。

    海外サイトを日本語で検索しても何も出ないので、{en} を使う雛形は
    候補に英語の語が入っているときだけ出す。
    """
    queries = []
    for template in templates:
        text = str(template.get("q", ""))
        if "{en}" in text and not item.en:
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
    hours_ago:        # 何時間前か。空にすると url から割り出す
    tier: 報道         # 確定 / 報道 / 未確認
    japanese: false   # 日本人選手が絡むか
    reaction: false   # 賛否が割れる・驚きがあるか
    big_club: false   # ビッグクラブが絡むか
    numbers: false    # 金額・記録など数字が立つか
    note: ""          # ひとことメモ
    sources:
      - ""
'''

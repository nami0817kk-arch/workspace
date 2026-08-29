"""取材の計画（config/sources.yaml）を読み、その日ぶんの検索リストに展開する。

検索そのものは人（またはAI）が行う。ここが担うのは、
「いつ・どこから・どの情報を取るか」を毎回同じ手順に落とすこと。
"""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import date
from pathlib import Path

import yaml

from .config import _resolve

DEFAULT_PLAN_PATH = "config/sources.yaml"
MONTHS_EN = (
    "January", "February", "March", "April", "May", "June",
    "July", "August", "September", "October", "November", "December",
)


class PlanError(Exception):
    pass


@dataclass
class Query:
    text: str
    domains: list[str] = field(default_factory=list)

    def line(self) -> str:
        if not self.domains:
            return f'"{self.text}"'
        return f'"{self.text}"  （{", ".join(self.domains)} に限定）'


@dataclass
class Step:
    id: str
    what: str
    tier: str
    queries: list[Query]
    check: str = ""


@dataclass
class Routine:
    key: str
    name: str
    when: str
    cover_hours: int
    target_minutes: float
    steps: list[Step]
    angle: str = ""

    @property
    def span(self) -> str:
        if self.cover_hours % 24 == 0 and self.cover_hours >= 24:
            return f"直近{self.cover_hours // 24}日"
        return f"直近{self.cover_hours}時間"


@dataclass
class Plan:
    routines: dict[str, Routine]
    tiers: dict[str, dict]
    domains: dict[str, list[str]]
    slots: list[str] = field(default_factory=list)
    coverage: dict = field(default_factory=dict)

    def routine(self, key: str) -> Routine:
        if key not in self.routines:
            known = " / ".join(self.routines)
            raise PlanError(f"『{key}』という取材計画はありません（定義済み: {known}）")
        return self.routines[key]


def load_plan(path: str | Path | None = None) -> Plan:
    plan_path = _resolve(path or DEFAULT_PLAN_PATH)
    if not plan_path.exists():
        raise PlanError(f"取材計画がありません: {plan_path}")
    raw = yaml.safe_load(plan_path.read_text(encoding="utf-8")) or {}
    return build_plan(raw)


def build_plan(raw: dict) -> Plan:
    domains = {k: list(v or []) for k, v in (raw.get("domains") or {}).items()}
    cadence = raw.get("cadence") or {}
    coverage = dict(raw.get("coverage") or {})
    tiers = dict(raw.get("tiers") or {})
    if not tiers:
        raise PlanError("tiers が定義されていません")

    routines: dict[str, Routine] = {}
    for key, body in (raw.get("routines") or {}).items():
        body = body or {}
        steps: list[Step] = []
        for step in body.get("steps") or []:
            tier = str(step.get("tier", "未確認"))
            if tier not in tiers:
                raise PlanError(f"{key}.{step.get('id')}: 未定義の確度『{tier}』")
            steps.append(
                Step(
                    id=str(step.get("id", "")),
                    what=str(step.get("what", "")),
                    tier=tier,
                    check=str(step.get("check", "")).strip(),
                    queries=_expand_queries(step, domains),
                )
            )
        if not steps:
            raise PlanError(f"{key}: steps が空です")
        # cover_days は日単位の旧表記。時間に直して持つ
        hours = body.get("cover_hours")
        if hours is None:
            hours = int(body.get("cover_days", 1)) * 24
        routines[key] = Routine(
            key=key,
            name=str(body.get("name", key)),
            when=str(body.get("when", "")),
            cover_hours=int(hours),
            target_minutes=float(body.get("target_minutes", 3)),
            steps=steps,
            angle=str(body.get("angle", "")).strip(),
        )
    if not routines:
        raise PlanError("routines が定義されていません")

    slots = [str(s) for s in (cadence.get("slots") or [])]
    for slot in slots:
        if slot not in routines:
            raise PlanError(f"cadence.slots の『{slot}』に対応する routine がありません")
    return Plan(
        routines=routines, tiers=tiers, domains=domains, slots=slots, coverage=coverage
    )


def _expand_queries(step: dict, domains: dict[str, list[str]]) -> list[Query]:
    """{topic} を持つクエリは、topics の数だけ複製する。"""
    topics = [str(t) for t in (step.get("topics") or [])]
    queries: list[Query] = []
    for item in step.get("queries") or []:
        text = str(item.get("q", ""))
        group = item.get("domains")
        resolved = domains.get(str(group), []) if group else []
        if "{topic}" in text:
            if not topics:
                continue  # 追う対象が未設定ならその検索は出さない
            for topic in topics:
                queries.append(Query(text.replace("{topic}", topic), resolved))
        else:
            queries.append(Query(text, resolved))
    return queries


def tokens(today: date, cover_hours: int = 24) -> dict[str, str]:
    """クエリに差し込む日付の言い回し。"""
    yesterday = date.fromordinal(today.toordinal() - 1)
    return {
        "{yesterday_en}": f"{yesterday.day} {MONTHS_EN[yesterday.month - 1]} {yesterday.year}",
        "{cover_hours}": str(cover_hours),
        "{date_ja}": f"{today.year}年{today.month}月{today.day}日",
        "{month_ja}": f"{today.year}年{today.month}月",
        "{year}": str(today.year),
        "{period_en}": f"{MONTHS_EN[today.month - 1]} {today.year}",
        "{today_en}": f"{today.day} {MONTHS_EN[today.month - 1]} {today.year}",
    }


def render(routine: Routine, today: date, covered: list | None = None) -> str:
    """その枠の取材指示書を文字列で組み立てる。"""
    words = tokens(today, routine.cover_hours)
    minutes = f"{routine.target_minutes:g}"
    lines = [
        f"■ {routine.name}　{words['{date_ja}']}",
        f"　収録の目安: {routine.when}",
        f"　対象期間: {routine.span} / 想定尺: 約{minutes}分",
    ]
    if routine.angle:
        for note in routine.angle.splitlines():
            if note.strip():
                lines.append(f"　狙い: {note.strip()}")
    lines.append("")

    if covered:
        lines.append("　直近で扱った話題（繰り返さない）:")
        for entry in covered:
            stamp = entry.at.strftime("%m/%d %H:%M")
            lines.append(f"　　{stamp} [{entry.slot}] {entry.headline}")
        lines.append("")
    for number, step in enumerate(routine.steps, start=1):
        lines.append(f"{number}. {step.what}　［{step.tier}］")
        for query in step.queries:
            lines.append(f"   検索: {_fill(query.line(), words)}")
        if not step.queries:
            lines.append("   検索: （追う対象が未設定。config の topics に足す）")
        if step.check:
            for note in step.check.splitlines():
                if note.strip():
                    lines.append(f"   確認: {note.strip()}")
        lines.append("")
    return "\n".join(lines).rstrip() + "\n"


def worksheet(routine: Routine, today: date) -> str:
    """取材メモの雛形（YAML）。ここに拾った内容を書き込んでいく。"""
    words = tokens(today, routine.cover_hours)
    lines = [
        f"# {routine.name} の取材メモ（{words['{date_ja}']}）",
        "# 埋めたら python -m src.cli draft このファイル で台本になる",
        f"slot: {routine.key}",
        f'date: "{words["{date_ja}"]}"',
        'title: ""            # 動画タイトル（【サッカーニュース】は自動で付く）',
        'intro_title: ""      # 冒頭カードの短いタイトル',
        "items:",
    ]
    for step in routine.steps:
        lines += [
            f"  # --- {step.what}（{step.tier}） ---",
            f"  - id: {step.id}",
            f'    tier: {step.tier}',
            '    headline: ""       # 章タイトルになる',
            '    telop: ""          # 画面の見出し',
            '    say: ""            # 読み上げ文。人名・数字はひらがなに開く',
            "    official: false    # クラブ・当事者の発表なら true",
            "    # follow_up: true  # 前の枠で速報した話題を深掘りするとき",
            "    sources:",
            '      - ""',
            "",
        ]
    return "\n".join(lines)


def _fill(text: str, words: dict[str, str]) -> str:
    for key, value in words.items():
        text = text.replace(key, value)
    return text

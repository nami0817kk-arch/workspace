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
    cover_days: int
    target_minutes: int
    steps: list[Step]


@dataclass
class Plan:
    routines: dict[str, Routine]
    tiers: dict[str, dict]
    domains: dict[str, list[str]]

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
        routines[key] = Routine(
            key=key,
            name=str(body.get("name", key)),
            when=str(body.get("when", "")),
            cover_days=int(body.get("cover_days", 7)),
            target_minutes=int(body.get("target_minutes", 3)),
            steps=steps,
        )
    if not routines:
        raise PlanError("routines が定義されていません")
    return Plan(routines=routines, tiers=tiers, domains=domains)


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


def tokens(today: date, cover_days: int) -> dict[str, str]:
    """クエリに差し込む日付の言い回し。"""
    return {
        "{date_ja}": f"{today.year}年{today.month}月{today.day}日",
        "{month_ja}": f"{today.year}年{today.month}月",
        "{year}": str(today.year),
        "{period_en}": f"{MONTHS_EN[today.month - 1]} {today.year}",
        "{today_en}": f"{today.day} {MONTHS_EN[today.month - 1]} {today.year}",
        "{cover_days}": str(cover_days),
    }


def render(routine: Routine, today: date) -> str:
    """その日の取材指示書を文字列で組み立てる。"""
    words = tokens(today, routine.cover_days)
    lines = [
        f"■ {routine.name}　{words['{date_ja}']}",
        f"　収録の目安: {routine.when}",
        f"　対象期間: 直近{routine.cover_days}日 / 想定尺: 約{routine.target_minutes}分",
        "",
    ]
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
    words = tokens(today, routine.cover_days)
    lines = [
        f"# {routine.name} の取材メモ（{words['{date_ja}']}）",
        "# 埋めたら python -m src.cli draft このファイル で台本になる",
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
            "    sources:",
            '      - ""',
            "",
        ]
    return "\n".join(lines)


def _fill(text: str, words: dict[str, str]) -> str:
    for key, value in words.items():
        text = text.replace(key, value)
    return text

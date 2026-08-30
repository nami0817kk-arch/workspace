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
    structure: list[dict] = field(default_factory=list)

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
    policy: dict = field(default_factory=dict)
    scan: dict = field(default_factory=dict)
    scoring: dict = field(default_factory=dict)
    deep: list = field(default_factory=list)
    accounts: list = field(default_factory=list)
    social: dict = field(default_factory=dict)
    domain_tiers: dict = field(default_factory=dict)
    verified_on: str = ""

    def group_of(self, url: str) -> str:
        """URLがどの情報源の群に属するか。分からなければ空。"""
        text = (url or "").lower()
        for group, hosts in self.domains.items():
            if group == "blocked":
                continue
            if any(str(host).lower() in text for host in hosts):
                return group
        return ""

    def is_blocked(self, url: str) -> bool:
        """恒久的に取得できないサイトか。出典に混ざると検証できなくなる。"""
        text = (url or "").lower()
        return any(str(host).lower() in text for host in (self.domains.get("blocked") or []))

    def ceiling(self, url: str) -> str:
        """そのURLだけを根拠に置ける最大の確度。分からなければ空。"""
        return str(self.domain_tiers.get(self.group_of(url), ""))

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
    policy = dict(raw.get("policy") or {})
    scan = dict(raw.get("scan") or {})
    scoring = dict(raw.get("scoring") or {})
    deep = [dict(x) for x in (raw.get("deep") or [])]
    accounts = [dict(x) for x in (raw.get("accounts") or [])]
    social = dict(raw.get("social") or {})
    domain_tiers = dict(raw.get("domain_tiers") or {})
    verified_on = str(raw.get("verified_on", "") or "")
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
            structure=[dict(x) for x in (body.get("structure") or [])],
        )
    if not routines:
        raise PlanError("routines が定義されていません")

    slots = [str(s) for s in (cadence.get("slots") or [])]
    for slot in slots:
        if slot not in routines:
            raise PlanError(f"cadence.slots の『{slot}』に対応する routine がありません")
    return Plan(
        routines=routines,
        tiers=tiers,
        domains=domains,
        slots=slots,
        coverage=coverage,
        policy=policy,
        scan=scan,
        scoring=scoring,
        deep=deep,
        accounts=accounts,
        social=social,
        domain_tiers=domain_tiers,
        verified_on=verified_on,
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
    """取材メモの雛形（YAML）。1本＝1テーマの深掘りとして書く。"""
    words = tokens(today, routine.cover_hours)
    lines = [
        f"# {routine.name} の取材メモ（{words['{date_ja}']}）",
        "# 1本＝1テーマ。まとめではなく、1つの話を掘る",
        "# 埋めたら python -m src.cli draft このファイル で台本になる",
        f"slot: {routine.key}",
        f'date: "{words["{date_ja}"]}"',
        "",
        "theme:",
        '  id: ""             # 短い識別子。重複の判定に使う（例: alvarez）',
        '  prefix: ""         # 速報 / 朗報 / 悲報。付けないなら空',
        '  title: ""          # 動画タイトル。続きが気になる書き方で',
        '  hook: ""           # 冒頭のつかみ。何が起きたかを一文で',
        '  question: ""       # この動画が答える問い。ここが深掘りの軸',
        "",
        "thumbnail:",
        '  line1: ""          # 主見出し。事実を短く言い切る。14文字くらいまで',
        '  line2: ""          # 副見出し。誰が何と言ったか。18文字くらいまで',
        "  tags: []           # 下部ティッカーのキーワード。選手名・論点を2つまで",
        "",
        'answer: ""           # まとめで問いにどう答えるか',
        'watch: ""            # 次に何を見ればよいか',
        "# follow_up: true    # 前の枠で扱ったテーマを掘り直すとき",
        "",
        "sections:",
    ]

    structure = routine.structure or [
        {"id": "what", "heading": "何が起きたか", "tier": "報道"},
        {"id": "why", "heading": "なぜそうなったか", "tier": "背景"},
        {"id": "next", "heading": "これからどうなる", "tier": "報道"},
    ]
    for block in structure:
        lines += [
            f'  - id: {block.get("id", "s")}',
            f'    heading: {block.get("heading", "")}',
            f'    tier: {block.get("tier", "報道")}',
            '    telop: ""        # 画面の見出し',
            "    say:             # 読み上げ文。人名・数字はひらがなに開く",
            '      - ""',
            "    official: false  # クラブ・当事者の発表なら true",
            "    sources:",
            '      - ""',
            "",
        ]
    return "\n".join(lines)


def _fill(text: str, words: dict[str, str]) -> str:
    for key, value in words.items():
        text = text.replace(key, value)
    return text

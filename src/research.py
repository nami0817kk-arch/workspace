"""取材メモ（YAML）を検証して、台本の下書きに変換する。

1本＝1テーマの深掘りを前提にしている。取材メモは
「テーマ」「動画が答える問い」「節（何が起きたか／なぜ／争点／これから）」で構成する。

検証でやること:
  - 確度の条件（config/sources.yaml の tiers）を満たしているか
  - 深掘りと呼べる節数があるか、問いが立っているか
  - 直近で扱った話題と重なっていないか
"""

from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path

import yaml

from . import coverage
from .plan import Plan

BACKGROUNDS = (
    "assets/backgrounds/pitch.png",
    "assets/backgrounds/tactics.png",
    "assets/backgrounds/stadium.png",
)
SPEAKERS = ("キャスター", "解説")


class ResearchError(Exception):
    pass


@dataclass
class Section:
    """深掘りの1節。動画の1章になる。"""

    id: str
    heading: str
    tier: str
    telop: str
    say: list[str]
    sources: list[str] = field(default_factory=list)
    official: bool = False
    card: dict | None = None


@dataclass
class Notes:
    date: str
    title: str
    question: str                    # この動画が答える問い
    slot: str = ""
    theme_id: str = ""
    hook: str = ""                   # 冒頭のつかみ
    answer: str = ""                 # まとめで返す答え
    watch: str = ""                  # 次に何を見るか
    follow_up: bool = False
    sections: list[Section] = field(default_factory=list)

    @property
    def sources(self) -> list[str]:
        seen: list[str] = []
        for section in self.sections:
            for url in section.sources:
                if url not in seen:
                    seen.append(url)
        return seen


def load_notes(path: str | Path) -> Notes:
    path = Path(path)
    if not path.exists():
        raise ResearchError(f"取材メモがありません: {path}")
    raw = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    return build_notes(raw)


def build_notes(raw: dict) -> Notes:
    theme = dict(raw.get("theme") or {})
    if not theme:
        raise ResearchError(
            "theme がありません。1本＝1テーマなので、扱うテーマを1つ決めてください"
        )

    sections: list[Section] = []
    for index, entry in enumerate(raw.get("sections") or [], start=1):
        entry = dict(entry or {})
        say = entry.get("say")
        lines = [say] if isinstance(say, str) else list(say or [])
        sections.append(
            Section(
                id=str(entry.get("id") or f"s{index}"),
                heading=str(entry.get("heading", "")).strip(),
                tier=str(entry.get("tier", "")).strip(),
                telop=str(entry.get("telop", "")).strip(),
                say=[str(s).strip() for s in lines if str(s).strip()],
                sources=[str(u).strip() for u in (entry.get("sources") or []) if str(u).strip()],
                official=bool(entry.get("official", False)),
                card=entry.get("card"),
            )
        )
    if not sections:
        raise ResearchError("sections が空です。節を立てて掘ってください")

    return Notes(
        date=str(raw.get("date", "")).strip(),
        slot=str(raw.get("slot", "")).strip(),
        title=str(theme.get("title", "")).strip(),
        theme_id=str(theme.get("id", "")).strip(),
        question=str(theme.get("question", "")).strip(),
        hook=str(theme.get("hook", "")).strip(),
        answer=str(raw.get("answer", "")).strip(),
        watch=str(raw.get("watch", "")).strip(),
        follow_up=bool(raw.get("follow_up", False)),
        sections=sections,
    )


def verify(notes: Notes, plan: Plan) -> list[str]:
    """確度と構成の条件を満たしているか調べ、問題を文章で返す。空なら合格。"""
    policy = getattr(plan, "policy", {}) or {}
    problems: list[str] = []

    if not notes.title:
        problems.append("theme.title が空です")
    if not notes.date:
        problems.append("date が空です")
    if policy.get("require_question", True) and not notes.question:
        problems.append(
            "theme.question が空です。この動画が答える問いを1つ立ててください"
            "（例: なぜ金の問題ではないのか）"
        )
    if not notes.answer:
        problems.append("answer が空です。まとめで問いにどう答えるかを書いてください")

    minimum = int(policy.get("min_sections", 3))
    if len(notes.sections) < minimum:
        problems.append(
            f"節が{len(notes.sections)}つしかありません。深掘りには{minimum}つ以上必要です"
            "（何が起きたか／なぜ／争点／これから）"
        )

    for section in notes.sections:
        label = section.id
        if section.tier not in plan.tiers:
            known = " / ".join(plan.tiers)
            problems.append(f"{label}: 確度『{section.tier}』が未定義です（{known}）")
            continue
        rule = plan.tiers[section.tier]

        if not section.heading:
            problems.append(f"{label}: heading が空です")
        if not section.telop:
            problems.append(f"{label}: telop が空です")
        if not section.say:
            problems.append(f"{label}: say が空です")

        needed = int(rule.get("needs_sources", 1))
        if len(section.sources) < needed:
            problems.append(
                f"{label}: 確度『{section.tier}』には出典が{needed}本必要です"
                f"（いまは{len(section.sources)}本）"
            )
        if rule.get("needs_official") and not section.official:
            problems.append(
                f"{label}: 確度『{section.tier}』はクラブ・当事者の発表が条件です。"
                "発表を確認できないなら tier を下げてください"
            )
    return problems


def check_repeats(notes: Notes, plan: Plan, now=None) -> list[str]:
    """直近で扱ったテーマと重なっていないか調べる。

    1日3本だと同じテーマを繰り返しがちなので、記録と突き合わせる。
    掘り直しとして意図的に扱う場合は follow_up: true を書く。
    """
    settings = plan.coverage or {}
    ledger = settings.get("ledger")
    if not ledger or notes.follow_up or not notes.theme_id:
        return []

    within = int(settings.get("repeat_within_hours", 36))
    hits = coverage.duplicates(coverage.load(ledger), [notes.theme_id], within, now)
    entry = hits.get(notes.theme_id)
    if entry is None:
        return []
    stamp = entry.at.strftime("%m/%d %H:%M")
    return [
        f"{notes.theme_id}: {stamp} の［{entry.slot}］で扱ったテーマです（{entry.headline}）。"
        "掘り直すなら follow_up: true を書いてください"
    ]


def to_script(notes: Notes, plan: Plan) -> str:
    """検証を通った取材メモから、台本の Markdown を組み立てる。"""
    problems = verify(notes, plan)
    if problems:
        raise ResearchError("取材メモに不備があります:\n  - " + "\n  - ".join(problems))

    front = {
        "title": f"【サッカーニュース】{notes.title}",
        "thumbnail_title": notes.title,
        "thumbnail_badge": "深掘り",
        "thumbnail_subtitle": notes.question,
        "bg": "assets/backgrounds/stadium.mp4",
        "date": notes.date,
        "intro_title": notes.title,
        "intro_label": "海外サッカー ニュース",
        "outro_title": notes.watch or "続報は次回お伝えします",
        "outro_sub": "チャンネル登録でお待ちください",
        "description": (
            f"{notes.title}\n\n"
            f"この動画が答える問い: {notes.question}\n\n"
            "※各社の報道をもとにしています。クラブが発表した「確定」、\n"
            "報道機関が伝える「報道」、SNS段階の「未確認」、\n"
            "経緯の説明である「背景」を画面上で分けています。\n"
        ),
        "tags": ["サッカー", "海外サッカー", "サッカーニュース", "解説"],
        "sources": notes.sources,
        "cards": _cards(notes),
    }

    lines = ["---", _front_matter(front), "---", "", "## オープニング", ""]
    hook = notes.hook or notes.title
    lines += [
        f"キャスター: 海外サッカーのニュースです。{hook}",
        f"  telop: {notes.title}",
        "  se: assets/audio/se_pon.wav",
        f"キャスター: この動画では、{notes.question}、ここを掘っていきます。",
        f"  telop: 今回の問い: {notes.question}",
        "",
    ]

    for index, section in enumerate(notes.sections):
        lines += [f"## {section.heading}", f"@bg: {BACKGROUNDS[index % len(BACKGROUNDS)]}", ""]
        for number, sentence in enumerate(section.say):
            speaker = SPEAKERS[number % len(SPEAKERS)]
            lines.append(f"{speaker}: {sentence}")
            if number == 0:
                lines.append(f"  telop: {section.telop}")
                lines.append(f"  source: {section.tier}")
                if section.card:
                    lines.append(f"  card: {section.id}_card")
        lines.append("")

    lines += [
        "## まとめ",
        "",
        f"キャスター: まとめます。{notes.question}。{notes.answer}",
        f"  telop: {notes.answer}",
        "  card: wrap",
    ]
    if notes.watch:
        lines += [f"解説: {notes.watch}", f"  telop: 次の焦点: {notes.watch}"]
    lines += [
        "キャスター: 動きがあり次第、あらためてお伝えします。"
        "続報はチャンネル登録してお待ちください。",
        "  telop: 続報はチャンネル登録でチェック",
        "  se: assets/audio/se_jingle.wav",
        "  pause: 1.2",
        "",
    ]
    return "\n".join(lines)


def _cards(notes: Notes) -> dict:
    cards: dict = {}
    for section in notes.sections:
        if section.card:
            cards[f"{section.id}_card"] = section.card
    cards["wrap"] = {
        "type": "points",
        "title": "この動画の答え",
        "items": [notes.question, notes.answer] + ([notes.watch] if notes.watch else []),
    }
    return cards


def _front_matter(front: dict) -> str:
    return yaml.safe_dump(front, allow_unicode=True, sort_keys=False, width=100).rstrip()

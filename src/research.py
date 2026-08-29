"""取材メモ（YAML）を検証して、台本の下書きに変換する。

確度の条件（config/sources.yaml の tiers）を機械的に確認するのが主目的。
「報道」なのに出典が1本しかない、「確定」なのに発表元が無い、といった
取りこぼしをビルド前に止める。
"""

from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path

import yaml

from .config import _resolve
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
class Item:
    id: str
    tier: str
    headline: str
    telop: str
    say: list[str]
    sources: list[str]
    official: bool = False
    card: dict | None = None

    @property
    def scene_title(self) -> str:
        return self.headline


@dataclass
class Notes:
    date: str
    title: str
    intro_title: str = ""
    lead: str = ""
    items: list[Item] = field(default_factory=list)

    @property
    def sources(self) -> list[str]:
        seen: list[str] = []
        for item in self.items:
            for url in item.sources:
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
    items: list[Item] = []
    for index, entry in enumerate(raw.get("items") or [], start=1):
        entry = dict(entry or {})
        item_id = str(entry.get("id") or f"item{index}")
        say = entry.get("say")
        say_lines = [s for s in ([say] if isinstance(say, str) else list(say or [])) if str(s).strip()]
        items.append(
            Item(
                id=item_id,
                tier=str(entry.get("tier", "")).strip(),
                headline=str(entry.get("headline", "")).strip(),
                telop=str(entry.get("telop", "")).strip(),
                say=[str(s).strip() for s in say_lines],
                sources=[str(u).strip() for u in (entry.get("sources") or []) if str(u).strip()],
                official=bool(entry.get("official", False)),
                card=entry.get("card"),
            )
        )
    if not items:
        raise ResearchError("items が空です。取材メモに1件も入っていません")

    return Notes(
        date=str(raw.get("date", "")).strip(),
        title=str(raw.get("title", "")).strip(),
        intro_title=str(raw.get("intro_title", "")).strip(),
        lead=str(raw.get("lead", "")).strip(),
        items=items,
    )


def verify(notes: Notes, plan: Plan) -> list[str]:
    """確度の条件を満たしているか調べ、問題を文章で返す。空なら合格。"""
    problems: list[str] = []
    if not notes.title:
        problems.append("title が空です")
    if not notes.date:
        problems.append("date が空です")

    for item in notes.items:
        label = f"{item.id}"
        if item.tier not in plan.tiers:
            known = " / ".join(plan.tiers)
            problems.append(f"{label}: 確度『{item.tier}』が未定義です（{known}）")
            continue
        rule = plan.tiers[item.tier]

        if not item.headline:
            problems.append(f"{label}: headline が空です")
        if not item.telop:
            problems.append(f"{label}: telop が空です")
        if not item.say:
            problems.append(f"{label}: say が空です")

        needed = int(rule.get("needs_sources", 1))
        if len(item.sources) < needed:
            problems.append(
                f"{label}: 確度『{item.tier}』には出典が{needed}本必要です"
                f"（いまは{len(item.sources)}本）"
            )
        if rule.get("needs_official") and not item.official:
            problems.append(
                f"{label}: 確度『{item.tier}』はクラブ・当事者の発表が条件です。"
                "発表を確認できないなら tier を下げてください"
            )
    return problems


def to_script(notes: Notes, plan: Plan) -> str:
    """検証を通った取材メモから、台本の Markdown を組み立てる。"""
    problems = verify(notes, plan)
    if problems:
        raise ResearchError("取材メモに不備があります:\n  - " + "\n  - ".join(problems))

    wrap_items = [f"{item.tier} … {item.headline}" for item in notes.items[:4]]
    front = {
        "title": f"【サッカーニュース】{notes.title}",
        "thumbnail_title": notes.intro_title or notes.title,
        "thumbnail_badge": "まとめ",
        "thumbnail_subtitle": notes.date,
        "bg": "assets/backgrounds/stadium.mp4",
        "date": notes.date,
        "intro_title": notes.intro_title or notes.title,
        "intro_label": "海外サッカー ニュース",
        "outro_title": "続報は次回お伝えします",
        "outro_sub": "チャンネル登録でお待ちください",
        "description": (
            f"{notes.date}時点の海外サッカーの動きをまとめました。\n"
            "※各社の報道をもとにしています。クラブが発表した「確定」情報と、\n"
            "メディアが伝えている「報道段階」の情報を分けて紹介しています。\n"
        ),
        "tags": ["サッカー", "海外サッカー", "移籍情報", "サッカーニュース"],
        "sources": notes.sources,
        "cards": _cards(notes, wrap_items),
    }

    lines = ["---", _front_matter(front), "---", ""]
    lines += ["## オープニング", ""]
    lead = notes.lead or f"{notes.title}についてお伝えします。"
    lines += [f"キャスター: 海外サッカーのニュースです。{lead}", f"  telop: {notes.title}", ""]

    for index, item in enumerate(notes.items):
        lines += [f"## {item.scene_title}", f"@bg: {BACKGROUNDS[index % len(BACKGROUNDS)]}", ""]
        for number, sentence in enumerate(item.say):
            speaker = SPEAKERS[number % len(SPEAKERS)]
            lines.append(f"{speaker}: {sentence}")
            if number == 0:
                lines.append(f"  telop: {item.telop}")
                lines.append(f"  source: {item.tier}")
                if item.card:
                    lines.append(f"  card: {item.id}_card")
                if index == 0:
                    lines.append("  se: assets/audio/se_pon.wav")
        lines.append("")

    lines += [
        "## まとめ",
        "",
        "キャスター: まとめます。",
        f"  telop: {' ／ '.join(item.headline for item in notes.items[:3])}",
        "  card: wrap",
        "キャスター: 動きがあり次第、あらためてお伝えします。"
        "続報はチャンネル登録してお待ちください。",
        "  telop: 続報はチャンネル登録でチェック",
        "  se: assets/audio/se_jingle.wav",
        "  pause: 1.2",
        "",
    ]
    return "\n".join(lines)


def _cards(notes: Notes, wrap_items: list[str]) -> dict:
    cards: dict = {}
    for item in notes.items:
        if item.card:
            cards[f"{item.id}_card"] = item.card
    cards["wrap"] = {"type": "points", "title": "今回のまとめ", "items": wrap_items}
    return cards


def _front_matter(front: dict) -> str:
    return yaml.safe_dump(front, allow_unicode=True, sort_keys=False, width=100).rstrip()

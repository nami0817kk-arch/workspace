"""号の本文生成。無料ティザーと有料本文を1回の呼び出しで作る。

2回に分けると原価が倍になるうえ、ティザーと本文の内容がずれる。
"""

from __future__ import annotations

from datetime import date

from .llm import EDITOR_SYSTEM, LLMClient, LLMResult
from .models import Issue, Niche, ScoredItem

ISSUE_SCHEMA = {
    "type": "object",
    "properties": {
        "title": {"type": "string"},
        "teaser_md": {"type": "string"},
        "body_md": {"type": "string"},
        "takeaways": {"type": "array", "items": {"type": "string"}},
    },
    "required": ["title", "teaser_md", "body_md", "takeaways"],
    "additionalProperties": False,
}


def build_prompt(niche: Niche, issue_date: date, selected: list[ScoredItem]) -> str:
    lines = [
        f"メディア: {niche.name}",
        f"読者: {niche.audience}",
        f"編集方針: {niche.angle}",
        f"発行日: {issue_date.isoformat()}",
        "",
        "今号で扱う記事は以下です。この範囲を超える事実を書かないでください。",
        "",
    ]
    for i, s in enumerate(selected):
        lines += [
            f"[item {i}] {s.item.title}",
            f"  出典: {s.item.source} / {s.item.url}",
            f"  要約: {s.item.summary[:800] or '(なし)'}",
            f"  リサーチャー所見(スコア{s.score}): {s.why}",
            "",
        ]
    lines += [
        "次の4点を出力してください。",
        "- title: 読者が開封したくなる具体的な号タイトル（40字以内、煽らない）",
        "- teaser_md: 無料読者向けの冒頭。今号の価値が伝わり、かつ結論は伏せる（300-500字）",
        f"- body_md: 有料読者向けの本文。{len(selected)}件すべてを ## 見出しで扱い、"
        "各項に『何が起きたか』『なぜ重要か』『明日やること』と出典リンクを含める",
        "- takeaways: 本文の要点を3-5個の短い箇条書きで",
    ]
    return "\n".join(lines)


def generate_issue(
    llm: LLMClient,
    niche: Niche,
    issue_date: date,
    selected: list[ScoredItem],
    *,
    model: str = "claude-opus-5",
    max_tokens: int = 16000,
    effort: str = "high",
) -> tuple[Issue, LLMResult]:
    if not selected:
        raise ValueError("選別済み記事が0件のため号を生成できません")

    result = llm.complete(
        build_prompt(niche, issue_date, selected),
        model=model,
        schema=ISSUE_SCHEMA,
        max_tokens=max_tokens,
        effort=effort,
        system=EDITOR_SYSTEM,
    )
    data = result.json()
    issue = Issue(
        niche=niche.code,
        issue_date=issue_date,
        title=str(data.get("title", "")).strip() or f"{niche.name} {issue_date.isoformat()}",
        teaser_md=str(data.get("teaser_md", "")).strip(),
        body_md=str(data.get("body_md", "")).strip(),
        takeaways=tuple(str(t) for t in data.get("takeaways", [])),
        item_hashes=tuple(s.item.hash for s in selected),
        model=result.model,
        input_tokens=result.input_tokens,
        output_tokens=result.output_tokens,
        cost_usd=result.cost_usd,
    )
    return issue, result

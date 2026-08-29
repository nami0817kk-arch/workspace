"""選別。ここが有料メディアの品質と原価を同時に決める。

全記事を本文生成に流すと原価が線形に増えるので、
「安い判定でふるいにかけ、高い生成は少数に絞る」構造にしている。
"""

from __future__ import annotations

from .llm import LLMClient, LLMResult
from .models import Item, Niche, ScoredItem

SCORE_SCHEMA = {
    "type": "object",
    "properties": {
        "scores": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "index": {"type": "integer"},
                    "score": {"type": "integer"},
                    "why": {"type": "string"},
                    "tags": {"type": "array", "items": {"type": "string"}},
                },
                "required": ["index", "score", "why", "tags"],
                "additionalProperties": False,
            },
        }
    },
    "required": ["scores"],
    "additionalProperties": False,
}

SCORING_SYSTEM = """あなたは有料ニュースレターのリサーチャーです。読者にとっての価値だけで記事を採点します。
高得点(80-100): 読者の意思決定や数字を今週変えうるもの。
中得点(50-79): 文脈として知る価値はあるが、行動は変わらないもの。
低得点(0-49): 一般論、宣伝、既報の焼き直し、読者層と無関係なもの。
評価は与えられたタイトルと要約のみに基づき、推測で加点しないこと。"""


def dedupe(items: list[Item], known_hashes: set[str]) -> list[Item]:
    """既出（DB）と実行内重複の両方を落とす。"""
    seen = set(known_hashes)
    fresh = []
    for item in items:
        if item.hash in seen:
            continue
        seen.add(item.hash)
        fresh.append(item)
    return fresh


def _prompt(niche: Niche, batch: list[Item]) -> str:
    lines = [
        f"メディア: {niche.name}",
        f"読者: {niche.audience}",
        f"編集方針: {niche.angle}",
        "",
        "以下の記事それぞれに 0-100 のスコアを付け、理由を1文で述べてください。",
        "index は下の番号と一致させること。",
        "",
    ]
    for i, item in enumerate(batch):
        lines += [
            f"[item {i}] {item.title}",
            f"  出典: {item.source} / {item.url}",
            f"  要約: {item.summary[:400] or '(なし)'}",
            "",
        ]
    return "\n".join(lines)


def score_items(
    llm: LLMClient,
    niche: Niche,
    items: list[Item],
    *,
    model: str = "claude-opus-5",
    batch_size: int = 20,
    effort: str = "low",
) -> tuple[list[ScoredItem], list[LLMResult]]:
    """記事をバッチで採点する。判定は安く済ませたいので effort は既定で low。"""
    scored: list[ScoredItem] = []
    results: list[LLMResult] = []
    for start in range(0, len(items), batch_size):
        batch = items[start : start + batch_size]
        result = llm.complete(
            _prompt(niche, batch),
            model=model,
            schema=SCORE_SCHEMA,
            max_tokens=4000,
            effort=effort,
            system=SCORING_SYSTEM,
        )
        results.append(result)
        for row in result.json().get("scores", []):
            index = row.get("index")
            if not isinstance(index, int) or not 0 <= index < len(batch):
                continue
            scored.append(
                ScoredItem(
                    item=batch[index],
                    score=max(0, min(100, int(row.get("score", 0)))),
                    why=str(row.get("why", "")),
                    tags=tuple(str(t) for t in row.get("tags", [])),
                )
            )
    return scored, results


def select_top(scored: list[ScoredItem], *, min_score: int, limit: int) -> list[ScoredItem]:
    """しきい値を超えたものだけを上位から採る。足りなければ号を出さない判断に使う。"""
    passing = [s for s in scored if s.score >= min_score]
    passing.sort(key=lambda s: (-s.score, s.item.title))
    return passing[:limit]

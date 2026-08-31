"""次に作るツールの提案。

広告収益はPVに比例し、PVはツールの本数と検索需要でほぼ決まる。
ここでのAIの役割は「既にあるページを踏まえて、まだ埋めていない検索意図を挙げる」こと。
出力は提案であって公開物ではない ―― 何を作るかは人間が決める。
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import date

from .content import Page
from .llm import DEFAULT_MODEL, LLMClient, LLMResult

IDEAS_SYSTEM = """あなたは実用ツールサイトの企画担当です。広告収益は検索流入に比例するため、
「検索されている具体的な計算ニーズ」だけを提案します。次の規律を守ってください。

1. ブラウザ内で完結する計算ツールに限る。サーバー処理や外部APIが要るものは提案しない。
2. 既存ページと重複する提案はしない。
3. 検索意図が具体的なものだけを挙げる（「AIについて」は不可、「LLM 料金 計算」は可）。
4. 読み物・記事は提案しない。生成記事の量産は検索スパムポリシーに該当する。
5. 各案には、その計算を必要とする具体的な場面を書く。書けないものは提案しない。
"""

IDEAS_SCHEMA = {
    "type": "object",
    "properties": {
        "ideas": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "title": {"type": "string"},
                    "slug": {"type": "string"},
                    "search_intent": {"type": "string"},
                    "scenario": {"type": "string"},
                    "inputs": {"type": "array", "items": {"type": "string"}},
                    "outputs": {"type": "array", "items": {"type": "string"}},
                    "demand": {"type": "integer"},
                    "effort": {"type": "integer"},
                },
                "required": ["title", "slug", "search_intent", "scenario", "inputs", "outputs", "demand", "effort"],
                "additionalProperties": False,
            },
        }
    },
    "required": ["ideas"],
    "additionalProperties": False,
}


@dataclass
class Idea:
    title: str
    slug: str
    search_intent: str
    scenario: str
    inputs: tuple[str, ...]
    outputs: tuple[str, ...]
    demand: int
    effort: int

    @property
    def score(self) -> float:
        """需要が高く実装が軽いものを上に。実装コストがゼロ扱いにならないよう+10する。"""
        return self.demand / (self.effort + 10)


def build_prompt(pages: list[Page], theme: str, count: int) -> str:
    lines = [f"サイトのテーマ: {theme}", "", "既存ページ:"]
    for page in pages:
        kind = "ツール" if page.is_tool else "解説"
        lines.append(f"- [{kind}] {page.title} ({page.url_path}) — {page.description}")
    lines += [
        "",
        f"まだ埋めていない検索意図を{count}件挙げ、それぞれをブラウザ内で完結する計算ツールとして提案してください。",
        "demand は検索需要の見込み(0-100)、effort は実装の重さ(0-100)で答えてください。",
    ]
    return "\n".join(lines)


def propose(
    llm: LLMClient,
    pages: list[Page],
    *,
    theme: str,
    count: int = 8,
    model: str = DEFAULT_MODEL,
) -> tuple[list[Idea], LLMResult]:
    """既存ページを踏まえて次のツール案を出す。スコア順に並べて返す。"""
    result = llm.complete(
        build_prompt(pages, theme, count),
        system=IDEAS_SYSTEM,
        model=model,
        schema=IDEAS_SCHEMA,
        max_tokens=8000,
        effort="high",
    )
    existing = {p.slug for p in pages} | {p.title for p in pages}
    ideas: list[Idea] = []
    for row in result.json().get("ideas", []):
        slug = str(row.get("slug", "")).strip().strip("/")
        if not slug or slug in existing or str(row.get("title", "")) in existing:
            continue  # 既存と重複する提案は落とす
        ideas.append(
            Idea(
                title=str(row.get("title", "")),
                slug=slug,
                search_intent=str(row.get("search_intent", "")),
                scenario=str(row.get("scenario", "")),
                inputs=tuple(str(v) for v in row.get("inputs", [])),
                outputs=tuple(str(v) for v in row.get("outputs", [])),
                demand=max(0, min(100, int(row.get("demand", 0)))),
                effort=max(0, min(100, int(row.get("effort", 0)))),
            )
        )
    ideas.sort(key=lambda i: -i.score)
    return ideas, result


def render_markdown(ideas: list[Idea], on: date | None = None) -> str:
    """人がレビューするための一覧。ここから作るものを選ぶ。"""
    on = on or date.today()
    lines = [
        f"# ツール案 ({on.isoformat()})",
        "",
        "AIによる提案です。**そのまま実装せず、実際に検索されているか確認してから着手してください。**",
        "demand/effort はモデルの見立てであり、実測値ではありません。",
        "",
        "| 優先度 | ツール案 | 検索意図 | 需要 | 実装 |",
        "|---|---|---|---|---|",
    ]
    for i, idea in enumerate(ideas, start=1):
        lines.append(
            f"| {i} | {idea.title} (`/tools/{idea.slug}/`) | {idea.search_intent} | {idea.demand} | {idea.effort} |"
        )
    lines.append("")
    for idea in ideas:
        lines += [
            f"## {idea.title}",
            "",
            f"- **想定URL**: `/tools/{idea.slug}/`",
            f"- **検索意図**: {idea.search_intent}",
            f"- **使う場面**: {idea.scenario}",
            f"- **入力**: {', '.join(idea.inputs) or '—'}",
            f"- **出力**: {', '.join(idea.outputs) or '—'}",
            "",
        ]
    return "\n".join(lines)

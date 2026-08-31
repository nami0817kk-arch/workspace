from adsite.content import Page
from adsite.ideas import Idea, propose, render_markdown
from adsite.llm import StubClient


def _pages() -> list[Page]:
    return [
        Page(slug="tools/llm-cost", title="LLM料金", description="d", body_md="", tool="llm-cost"),
        Page(slug="guides/basics", title="基礎", description="d", body_md=""),
    ]


def test_propose_returns_scored_ideas():
    ideas, result = propose(StubClient(), _pages(), theme="AI導入の計算")
    assert ideas and result.cost_usd > 0
    assert all(isinstance(i, Idea) for i in ideas)


def test_prompt_lists_existing_pages_so_duplicates_are_avoided():
    llm = StubClient()
    propose(llm, _pages(), theme="AI導入の計算")
    prompt = llm.calls[0]["prompt"]
    assert "/tools/llm-cost/" in prompt and "/guides/basics/" in prompt


def test_ideas_duplicating_existing_pages_are_dropped():
    class Dup(StubClient):
        def complete(self, prompt, **kwargs):
            result = super().complete(prompt, **kwargs)
            result.text = (
                '{"ideas": ['
                '{"title":"LLM料金","slug":"tools/llm-cost","search_intent":"a","scenario":"b",'
                '"inputs":[],"outputs":[],"demand":90,"effort":10},'
                '{"title":"新しい案","slug":"new-tool","search_intent":"a","scenario":"b",'
                '"inputs":[],"outputs":[],"demand":80,"effort":20}]}'
            )
            return result

    ideas, _ = propose(Dup(), _pages(), theme="t")
    assert [i.slug for i in ideas] == ["new-tool"]


def test_ranking_prefers_high_demand_and_low_effort():
    high = Idea("a", "a", "", "", (), (), demand=90, effort=10)
    heavy = Idea("b", "b", "", "", (), (), demand=90, effort=90)
    assert high.score > heavy.score


def test_zero_effort_does_not_divide_by_zero():
    assert Idea("a", "a", "", "", (), (), demand=50, effort=0).score == 5.0


def test_markdown_warns_against_implementing_without_checking():
    md = render_markdown([Idea("計算ツール", "calc", "検索意図", "場面", ("入力",), ("出力",), 80, 20)])
    assert "そのまま実装せず" in md
    assert "/tools/calc/" in md
    assert "実測値ではありません" in md

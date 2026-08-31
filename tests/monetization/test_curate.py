from moneyloop.curate import dedupe, score_items, select_top
from moneyloop.llm import StubClient
from moneyloop.models import Item, ScoredItem


def _item(title, url):
    return Item(niche="n", source="s", title=title, url=url, summary="")


def test_dedupe_removes_known_and_intra_run_duplicates():
    a, b = _item("A", "https://x.test/a"), _item("B", "https://x.test/b")
    dup = _item("A", "https://x.test/a")
    assert dedupe([a, dup, b], set()) == [a, b]
    assert dedupe([a, b], {a.hash}) == [b]


def test_select_top_applies_threshold_and_limit():
    scored = [ScoredItem(item=_item(f"t{i}", f"https://x.test/{i}"), score=i * 10, why="") for i in range(10)]
    picked = select_top(scored, min_score=60, limit=2)
    assert [s.score for s in picked] == [90, 80]


def test_select_top_returns_empty_when_nothing_passes():
    scored = [ScoredItem(item=_item("t", "https://x.test/t"), score=10, why="")]
    assert select_top(scored, min_score=60, limit=5) == []


def test_score_items_batches_and_maps_indexes(config):
    llm = StubClient()
    items = [_item(f"t{i}", f"https://x.test/{i}") for i in range(25)]
    scored, results = score_items(llm, config.niches[0], items, batch_size=10)
    assert len(results) == 3  # 10 + 10 + 5
    assert len(scored) == 25
    assert {s.item.hash for s in scored} == {i.hash for i in items}


def test_score_items_ignores_out_of_range_index(config, monkeypatch):
    class BadClient(StubClient):
        def complete(self, prompt, **kwargs):
            result = super().complete(prompt, **kwargs)
            result.text = '{"scores": [{"index": 99, "score": 90, "why": "x", "tags": []}]}'
            return result

    scored, _ = score_items(BadClient(), config.niches[0], [_item("t", "https://x.test/t")])
    assert scored == []

import pytest

from src.candidates import (
    Candidate,
    CandidateError,
    assign,
    deep_queries,
    exclude_covered,
    load_candidates,
    score,
)

SCORING = {
    "weights": {"freshness": 3, "japanese": 3, "reaction": 3, "big_club": 2, "numbers": 1},
    "freshness_hours": {6: 3, 12: 2, 24: 1},
    "big_clubs": ["アーセナル", "バルセロナ"],
    "slots": {
        "morning": {"prefer": "freshness", "require_tier": ["確定", "報道"]},
        "noon": {"prefer": "japanese"},
        "evening": {"prefer": "total"},
    },
}


def test_freshness_is_scaled_to_its_weight():
    fresh, mid, old, stale = score(
        [
            Candidate(id="a", title="A", hours_ago=1),
            Candidate(id="b", title="B", hours_ago=10),
            Candidate(id="c", title="C", hours_ago=20),
            Candidate(id="d", title="D", hours_ago=40),
        ],
        SCORING,
    )
    assert [c.score for c in (fresh, mid, old, stale)] == [3, 2, 1, 0]
    assert "新しさ" not in stale.breakdown


def test_flags_add_their_weights_and_leave_a_breakdown():
    (item,) = score([Candidate(id="a", title="A", hours_ago=1, japanese=True, numbers=True)], SCORING)
    assert item.breakdown == {"新しさ": 3, "日本人": 3, "数字": 1}
    assert item.score == 7


def test_big_club_is_detected_from_the_title():
    (item,) = score([Candidate(id="a", title="アーセナルが動く", hours_ago=99)], SCORING)
    assert item.big_club is True
    assert item.breakdown == {"ビッグクラブ": 2}


def test_scoring_sorts_by_points_then_freshness():
    ranked = score(
        [
            Candidate(id="old", title="古い", hours_ago=5, japanese=True),
            Candidate(id="new", title="新しい", hours_ago=1, japanese=True),
        ],
        SCORING,
    )
    assert [c.id for c in ranked] == ["new", "old"]


def test_each_slot_gets_a_different_candidate():
    ranked = score(
        [
            Candidate(id="a", title="速報", hours_ago=1, tier="報道", reaction=True),
            Candidate(id="b", title="日本人", hours_ago=10, tier="未確認", japanese=True),
            Candidate(id="c", title="その他", hours_ago=20, tier="確定", numbers=True),
        ],
        SCORING,
    )
    chosen = assign(ranked, SCORING, ["morning", "noon", "evening"])
    assert chosen["morning"].id == "a"   # いちばん新しい、かつ確定/報道
    assert chosen["noon"].id == "b"      # 日本人優先
    assert chosen["evening"].id == "c"   # 残りから最高点
    assert len({c.id for c in chosen.values()}) == 3


def test_morning_falls_back_when_no_candidate_matches_the_tier():
    ranked = score([Candidate(id="a", title="噂", hours_ago=1, tier="未確認")], SCORING)
    chosen = assign(ranked, SCORING, ["morning"])
    assert chosen["morning"].id == "a"


def test_slots_are_skipped_when_candidates_run_out():
    ranked = score([Candidate(id="a", title="A", hours_ago=1, tier="報道")], SCORING)
    chosen = assign(ranked, SCORING, ["morning", "noon", "evening"])
    assert set(chosen) == {"morning"}


DEEP = [
    {"q": "{theme} 詳細", "label": "何が起きたか"},
    {"q": "{en} latest news", "domains": "english", "label": "英語"},
    {"q": "{en}", "domains": "social", "label": "反応"},
]
DOMAINS = {"english": ["skysports.com"], "social": ["x.com"]}


def test_english_queries_use_the_english_keywords_and_their_domains():
    item = Candidate(id="a", title="アルバレスの去就", en="Julian Alvarez")
    queries = deep_queries(item, DEEP, DOMAINS)
    assert [q["q"] for q in queries] == [
        "アルバレスの去就 詳細",
        "Julian Alvarez latest news",
        "Julian Alvarez",
    ]
    assert queries[0]["domains"] == []
    assert queries[1]["domains"] == ["skysports.com"]


def test_english_queries_are_dropped_without_english_keywords():
    item = Candidate(id="a", title="J1首位攻防")
    queries = deep_queries(item, DEEP, DOMAINS)
    assert [q["label"] for q in queries] == ["何が起きたか"]


def test_covered_topics_are_separated_out():
    items = [Candidate(id="a", title="A"), Candidate(id="b", title="B")]
    keep, dropped = exclude_covered(items, {"a": object()})
    assert [c.id for c in keep] == ["b"]
    assert [c.id for c in dropped] == ["a"]


def test_loading_reads_flags_and_defaults(tmp_path):
    path = tmp_path / "c.yaml"
    path.write_text(
        "date: 2026年8月29日\n"
        "candidates:\n"
        "  - id: alv\n"
        "    title: アルバレス\n"
        "    en: Julian Alvarez\n"
        "    hours_ago: 4\n"
        "    tier: 報道\n"
        "    reaction: true\n"
        "    sources: [https://example.com/a]\n"
        "  - title: 見出しだけ\n",
        encoding="utf-8",
    )
    date_label, items = load_candidates(path)
    assert date_label == "2026年8月29日"
    assert items[0].en == "Julian Alvarez"
    assert items[0].reaction is True
    assert items[0].japanese is False
    assert items[1].id == "c2"          # id は自動で振る
    assert items[1].hours_ago == 99.0   # 既定は「古い」扱い


def test_loading_rejects_an_empty_title(tmp_path):
    path = tmp_path / "c.yaml"
    path.write_text("candidates:\n  - title: ''\n", encoding="utf-8")
    with pytest.raises(CandidateError, match="title"):
        load_candidates(path)


def test_loading_rejects_an_empty_file(tmp_path):
    path = tmp_path / "c.yaml"
    path.write_text("candidates: []\n", encoding="utf-8")
    with pytest.raises(CandidateError):
        load_candidates(path)


def test_loading_reports_a_missing_file(tmp_path):
    with pytest.raises(CandidateError, match="ありません"):
        load_candidates(tmp_path / "none.yaml")

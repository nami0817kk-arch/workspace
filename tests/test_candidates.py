import pytest

from src.candidates import (
    Candidate,
    CandidateError,
    assign,
    deep_queries,
    exclude_covered,
    fill_ages,
    load_candidates,
    score,
)

SCORING = {
    "weights": {"freshness": 3, "japanese": 1, "reaction": 3, "big_club": 2, "numbers": 1},
    "freshness_hours": {6: 3, 12: 2, 24: 1},
    "big_clubs": ["アーセナル", "バルセロナ"],
    "slots": {
        "morning": {"prefer": "freshness", "require_tier": ["確定", "報道"]},
        "noon": {"prefer": "reaction"},
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
    assert item.breakdown == {"新しさ": 3, "日本人": 1, "数字": 1}
    assert item.score == 5


def test_big_club_is_detected_from_the_title():
    (item,) = score([Candidate(id="a", title="アーセナルが動く", hours_ago=99)], SCORING)
    assert item.big_club is True
    assert item.breakdown == {"ビッグクラブ": 2}


def test_scoring_sorts_by_points_then_freshness():
    ranked = score(
        [
            Candidate(id="old", title="古い", hours_ago=5, reaction=True),
            Candidate(id="new", title="新しい", hours_ago=1, reaction=True),
        ],
        SCORING,
    )
    assert [c.id for c in ranked] == ["new", "old"]


def test_each_slot_gets_a_different_candidate():
    ranked = score(
        [
            Candidate(id="a", title="速報", hours_ago=1, tier="報道", numbers=True),
            Candidate(id="b", title="賛否", hours_ago=10, tier="未確認", reaction=True),
            Candidate(id="c", title="その他", hours_ago=20, tier="確定", big_club=True),
        ],
        SCORING,
    )
    chosen, fallbacks = assign(ranked, SCORING, ["morning", "noon", "evening"])
    assert chosen["morning"].id == "a"   # いちばん新しい、かつ確定/報道
    assert chosen["noon"].id == "b"      # 賛否が割れるもの優先
    assert chosen["evening"].id == "c"   # 残りから最高点
    assert len({c.id for c in chosen.values()}) == 3
    assert fallbacks == {}


def test_the_same_topic_is_not_used_in_two_slots():
    ranked = score(
        [
            Candidate(id="a1", title="移籍の続報", hours_ago=1, tier="報道",
                      topic="alvarez", reaction=True, numbers=True),
            Candidate(id="a2", title="同じ件の別記事", hours_ago=2, tier="報道",
                      topic="alvarez", reaction=True, numbers=True),
            Candidate(id="b", title="別の話", hours_ago=20, tier="報道", topic="spurs"),
        ],
        SCORING,
    )
    chosen, _ = assign(ranked, SCORING, ["morning", "noon"])
    assert chosen["morning"].topic == "alvarez"
    assert chosen["noon"].topic == "spurs"   # 同じ topic は2枠目に入れない


def test_a_repeated_topic_is_allowed_but_reported_when_nothing_else_is_left():
    ranked = score(
        [
            Candidate(id="a1", title="続報1", hours_ago=1, tier="報道", topic="alvarez"),
            Candidate(id="a2", title="続報2", hours_ago=2, tier="報道", topic="alvarez"),
        ],
        SCORING,
    )
    chosen, fallbacks = assign(ranked, SCORING, ["morning", "noon"])
    assert chosen["noon"].topic == "alvarez"
    assert any("別の話題" in r for r in fallbacks["noon"])


def test_candidates_without_a_topic_are_never_blocked():
    ranked = score(
        [
            Candidate(id="a", title="話題つき", hours_ago=1, tier="報道", topic="alvarez"),
            Candidate(id="b", title="話題なし", hours_ago=2, tier="報道"),
            Candidate(id="c", title="話題なし2", hours_ago=3, tier="報道"),
        ],
        SCORING,
    )
    chosen, fallbacks = assign(ranked, SCORING, ["morning", "noon", "evening"])
    assert len(chosen) == 3
    # topic を書いていない候補は、話題の重複では弾かれない
    assert not any("別の話題" in r for r in fallbacks.get("noon", []))


def test_morning_falls_back_when_no_candidate_matches_the_tier():
    ranked = score([Candidate(id="a", title="噂", hours_ago=1, tier="未確認")], SCORING)
    chosen, fallbacks = assign(ranked, SCORING, ["morning"])
    assert chosen["morning"].id == "a"
    assert any("確度" in r for r in fallbacks["morning"])   # 黙って入れ替えない


def test_noon_says_so_when_nothing_divisive_exists():
    ranked = score([Candidate(id="a", title="淡々とした話", hours_ago=1, tier="報道")], SCORING)
    chosen, fallbacks = assign(ranked, SCORING, ["noon"])
    assert chosen["noon"].id == "a"
    assert any("賛否" in r for r in fallbacks["noon"])


def test_no_fallback_is_reported_when_the_conditions_are_met():
    ranked = score(
        [Candidate(id="a", title="賛否のある話", hours_ago=1, tier="報道", reaction=True)], SCORING
    )
    _, fallbacks = assign(ranked, SCORING, ["morning", "noon"])
    assert fallbacks == {}


def test_slots_are_skipped_when_candidates_run_out():
    ranked = score([Candidate(id="a", title="A", hours_ago=1, tier="報道")], SCORING)
    chosen, _ = assign(ranked, SCORING, ["morning", "noon", "evening"])
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


def test_ages_are_filled_in_from_the_url():
    items = [
        Candidate(id="a", title="A", url="https://example.com/a", hours_ago=-1),
        Candidate(id="b", title="B", hours_ago=5),
    ]
    notes = fill_ages(items, lambda url: 3.25)
    assert items[0].hours_ago == 3.2   # 割り出した値
    assert items[1].hours_ago == 5     # 手で書いた値は触らない
    assert notes == []


def test_an_age_that_cannot_be_worked_out_is_treated_as_old():
    items = [
        Candidate(id="a", title="URLなし", hours_ago=-1),
        Candidate(id="b", title="判定できないURL", url="https://example.com/b", hours_ago=-1),
    ]
    notes = fill_ages(items, lambda url: None)
    assert [c.hours_ago for c in items] == [99.0, 99.0]
    assert any("urlが無い" in n for n in notes)
    assert any("割り出せない" in n for n in notes)


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
    assert items[1].hours_ago == -1.0   # 未記入の印。fill_ages で埋める


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


DEEP_WHEN = [
    {"q": "{theme} 詳細", "label": "日本語"},
    {"q": "{theme} のお知らせ", "domains": "official_jp", "when": "japanese", "label": "日本の公式"},
]


def test_japan_only_queries_are_skipped_for_european_topics():
    european = Candidate(id="a", title="アルバレスの去就", japanese=False)
    assert [q["label"] for q in deep_queries(european, DEEP_WHEN, {})] == ["日本語"]


def test_japan_only_queries_appear_for_japanese_topics():
    japanese = Candidate(id="b", title="鈴木彩艶の移籍", japanese=True)
    assert [q["label"] for q in deep_queries(japanese, DEEP_WHEN, {})] == ["日本語", "日本の公式"]


DEEP_LEAGUE = [
    {"q": "{en} latest", "domains": "english", "label": "英語"},
    {"q": "{en} Transfer offiziell", "domains": "german", "when": "germany", "label": "ドイツ語"},
    {"q": "{en} fichaje oficial", "domains": "spanish", "when": "spain", "label": "スペイン語"},
    {"q": "{theme} のお知らせ", "domains": "official_jp", "when": "japanese", "label": "日本の公式"},
]


def test_only_the_matching_leagues_local_language_query_appears():
    spain = Candidate(id="a", title="アルバレス", en="Julian Alvarez", league="spain")
    assert [q["label"] for q in deep_queries(spain, DEEP_LEAGUE, {})] == ["英語", "スペイン語"]

    germany = Candidate(id="b", title="佐野", en="Kaishu Sano", league="germany")
    assert [q["label"] for q in deep_queries(germany, DEEP_LEAGUE, {})] == ["英語", "ドイツ語"]


def test_league_and_japanese_conditions_can_both_fire():
    item = Candidate(id="c", title="佐野海舟", en="Kaishu Sano", league="germany", japanese=True)
    assert [q["label"] for q in deep_queries(item, DEEP_LEAGUE, {})] == [
        "英語", "ドイツ語", "日本の公式",
    ]


def test_no_league_means_no_local_language_query():
    item = Candidate(id="d", title="どこかの話", en="Something")
    assert [q["label"] for q in deep_queries(item, DEEP_LEAGUE, {})] == ["英語"]


def test_the_league_is_read_and_normalised(tmp_path):
    path = tmp_path / "c.yaml"
    path.write_text(
        "candidates:\n  - id: a\n    title: A\n    league: Germany\n    topic: bayern\n",
        encoding="utf-8",
    )
    _, items = load_candidates(path)
    assert items[0].league == "germany"    # 大文字で書かれても拾う
    assert items[0].topic == "bayern"

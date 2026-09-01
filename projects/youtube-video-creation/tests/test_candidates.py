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
    "weights": {"freshness": 3, "reaction": 3, "big_club": 2, "numbers": 1},
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
    (item,) = score([Candidate(id="a", title="A", hours_ago=1, reaction=True, numbers=True)], SCORING)
    assert item.breakdown == {"新しさ": 3, "反応": 3, "数字": 1}
    assert item.score == 7


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
    {"q": "{theme} のお知らせ", "domains": "official_jp", "when": "japan", "label": "日本の公式"},
]


def test_japan_only_queries_are_skipped_for_other_leagues():
    european = Candidate(id="a", title="アルバレスの去就", league="spain")
    assert [q["label"] for q in deep_queries(european, DEEP_WHEN, {})] == ["日本語"]


def test_japan_only_queries_appear_for_the_japanese_league():
    jleague = Candidate(id="b", title="Jリーグの移籍", league="japan")
    assert [q["label"] for q in deep_queries(jleague, DEEP_WHEN, {})] == ["日本語", "日本の公式"]


DEEP_LEAGUE = [
    {"q": "{en} latest", "domains": "english", "label": "英語"},
    {"q": "{en} Transfer offiziell", "domains": "german", "when": "germany", "label": "ドイツ語"},
    {"q": "{en} fichaje oficial", "domains": "spanish", "when": "spain", "label": "スペイン語"},
    {"q": "{theme} のお知らせ", "domains": "official_jp", "when": "japan", "label": "日本の公式"},
]


def test_only_the_matching_leagues_local_language_query_appears():
    spain = Candidate(id="a", title="アルバレス", en="Julian Alvarez", league="spain")
    assert [q["label"] for q in deep_queries(spain, DEEP_LEAGUE, {})] == ["英語", "スペイン語"]

    germany = Candidate(id="b", title="佐野", en="Kaishu Sano", league="germany")
    assert [q["label"] for q in deep_queries(germany, DEEP_LEAGUE, {})] == ["英語", "ドイツ語"]


def test_the_japanese_league_gets_its_own_official_query():
    item = Candidate(id="c", title="Jリーグの移籍", en="J League transfer", league="japan")
    assert [q["label"] for q in deep_queries(item, DEEP_LEAGUE, {})] == ["英語", "日本の公式"]


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


SCORING_KINDS = {
    **SCORING,
    "spread_kinds": True,
    "weights": {**SCORING["weights"], "goals": 2, "upset": 3},
}


def test_two_slots_of_one_kind_is_the_limit():
    ranked = score(
        [
            Candidate(id="m1", title="試合1", hours_ago=1, tier="報道", kind="match", topic="a"),
            Candidate(id="m2", title="試合2", hours_ago=2, tier="報道", kind="match", topic="b"),
            Candidate(id="m3", title="試合3", hours_ago=3, tier="報道", kind="match", topic="c"),
            Candidate(id="t1", title="移籍", hours_ago=9, tier="報道", kind="transfer", topic="d"),
        ],
        SCORING_KINDS,
    )
    chosen, _ = assign(ranked, SCORING_KINDS, ["morning", "noon", "evening"])
    kinds = [c.kind for c in chosen.values()]
    assert kinds.count("match") == 2      # 3本とも試合結果にはしない
    assert "transfer" in kinds


def test_an_all_transfer_day_reports_nothing_about_kinds():
    ranked = score(
        [
            Candidate(id="a", title="A", hours_ago=1, tier="報道", topic="a"),
            Candidate(id="b", title="B", hours_ago=2, tier="報道", topic="b"),
            Candidate(id="c", title="C", hours_ago=3, tier="報道", topic="c"),
        ],
        SCORING_KINDS,
    )
    _, fallbacks = assign(ranked, SCORING_KINDS, ["morning", "noon", "evening"])
    assert not any("種類" in r for reasons in fallbacks.values() for r in reasons)


def test_match_only_queries_are_skipped_for_transfers():
    templates = [
        {"q": "{en} latest", "label": "共通"},
        {"q": "{en} xG shots", "domains": "stats", "when": "match", "label": "試合のスタッツ"},
    ]
    transfer = Candidate(id="a", title="移籍", en="Some Player", kind="transfer")
    match = Candidate(id="b", title="試合", en="Arsenal Liverpool", kind="match")
    assert [q["label"] for q in deep_queries(transfer, templates, {})] == ["共通"]
    assert [q["label"] for q in deep_queries(match, templates, {})] == ["共通", "試合のスタッツ"]


def test_goals_and_upset_score_for_matches():
    (item,) = score(
        [Candidate(id="a", title="番狂わせ", hours_ago=1, kind="match", goals=True, upset=True)],
        SCORING_KINDS,
    )
    assert item.breakdown == {"新しさ": 3, "得点": 2, "番狂わせ": 3}
    assert item.score == 8


LEAGUE_DEEP = [
    {"q": "{en} latest", "domains": "english", "label": "共通"},
    {"q": "{en} fee", "domains": "english", "when": "transfer", "label": "移籍金"},
    {"q": "{en} match report", "domains": "league_official", "when": "match", "label": "公式レポート"},
    {"q": "{en} {match_q}", "domains": "league_media", "when": "match", "label": "現地の報道"},
    {"q": "{en} offiziell", "domains": "german", "when": ["germany", "transfer"], "label": "独・移籍"},
]
DOMAIN_MAP = {"english": ["espn.com"], "german": ["kicker.de"]}


def _labels(item, **kwargs):
    return [q["label"] for q in deep_queries(item, LEAGUE_DEEP, DOMAIN_MAP, **kwargs)]


def test_match_queries_use_the_leagues_own_sites():
    item = Candidate(id="a", title="試合", en="Bayern Dortmund", kind="match", league="germany")
    queries = deep_queries(
        item, LEAGUE_DEEP, DOMAIN_MAP,
        league_official=["bundesliga.com"], league_media=["kicker.de"], match_q="Spielbericht",
    )
    by_label = {q["label"]: q for q in queries}
    assert by_label["公式レポート"]["domains"] == ["bundesliga.com"]
    assert by_label["現地の報道"]["domains"] == ["kicker.de"]
    assert by_label["現地の報道"]["q"] == "Bayern Dortmund Spielbericht"
    assert "移籍金" not in by_label          # 試合に移籍金の検索は出さない
    assert "独・移籍" not in by_label


def test_transfer_queries_do_not_get_the_match_ones():
    item = Candidate(id="b", title="移籍", en="Some Player", kind="transfer", league="germany")
    labels = _labels(item, league_official=["bundesliga.com"], league_media=["kicker.de"])
    assert labels == ["共通", "移籍金", "独・移籍"]


def test_a_when_list_needs_every_condition():
    # ドイツの移籍だけ。スペインの移籍にもドイツの試合にも出さない
    german_move = Candidate(id="c", title="x", en="X", kind="transfer", league="germany")
    spanish_move = Candidate(id="d", title="x", en="X", kind="transfer", league="spain")
    german_match = Candidate(id="e", title="x", en="X", kind="match", league="germany")
    assert "独・移籍" in _labels(german_move)
    assert "独・移籍" not in _labels(spanish_move)
    assert "独・移籍" not in _labels(german_match)


def test_league_scoped_queries_are_dropped_without_hosts():
    item = Candidate(id="f", title="試合", en="X", kind="match", league="netherlands")
    # オランダは公式を登録していない。空のまま検索を出さない
    assert _labels(item, league_official=[], league_media=["vi.nl"], match_q="verslag") == [
        "共通", "現地の報道",
    ]


def test_the_morning_slot_picks_the_bigger_story_among_equally_fresh_ones():
    # 実際に起きた例。8点の大ニュースより、30分新しいだけの4点が選ばれていた
    ranked = score(
        [
            Candidate(id="big", title="大きい話", hours_ago=0.5, tier="確定",
                      reaction=True, big_club=True),
            Candidate(id="small", title="小さい話", hours_ago=0.0, tier="報道", numbers=True),
        ],
        SCORING,
    )
    chosen, _ = assign(ranked, SCORING, ["morning"])
    assert chosen["morning"].id == "big"


def test_freshness_still_wins_across_the_band():
    # 帯を外れるほど古ければ、点数が高くても選ばない
    ranked = score(
        [
            Candidate(id="old", title="古い大物", hours_ago=20, tier="報道",
                      reaction=True, big_club=True, numbers=True),
            Candidate(id="new", title="新しい小物", hours_ago=1, tier="報道"),
        ],
        SCORING,
    )
    chosen, _ = assign(ranked, SCORING, ["morning"])
    assert chosen["morning"].id == "new"


# 何社が同じ話を書いているかは、世の中がいま何に注目しているかの代わりになる。
# reaction / numbers / goals / upset は人が手で立てる欄で、gather は全部 false で
# 書き出す。実際に回すと点数が「新しさ＋ビッグクラブ」だけになり、地域リーグの
# 記事と移籍期限の話が同点で並んでいた。


def test_同じ媒体の複数記事は1社と数える():
    from src.candidates import outlet_count

    assert outlet_count([
        "https://www.kicker.de/a/artikel",
        "https://kicker.de/b/artikel",
        "https://www.skysports.com/football/news/1",
    ]) == 2


def test_出典が無ければ0社():
    from src.candidates import outlet_count

    assert outlet_count([]) == 0
    assert outlet_count(None) == 0


OUTLET_SCORING = {
    "weights": {"freshness": 3, "outlets": 3},
    "freshness_hours": {6: 3, 12: 2, 24: 1},
    "outlets_count": {2: 1, 3: 2, 5: 3},
}


def _scored(sources):
    from src.candidates import Candidate, score

    (item,) = score([Candidate(id="a", title="a", hours_ago=1, sources=sources)], OUTLET_SCORING)
    return item


def test_複数の媒体が書いている話ほど高くなる():
    one = _scored(["https://a.com/1"])
    two = _scored(["https://a.com/1", "https://b.com/1"])
    five = _scored([f"https://{c}.com/1" for c in "abcde"])
    assert one.score < two.score < five.score


def test_1社だけの話には媒体数の点が付かない():
    assert "媒体数" not in _scored(["https://a.com/1"]).breakdown


def test_内訳に媒体数が残る():
    """なぜその順位なのかを、後から説明できるようにしておく。"""
    assert _scored([f"https://{c}.com/1" for c in "abcde"]).breakdown["媒体数"] == 3


def test_同じ媒体の配信面の違いは1社と数える():
    """m.gianlucadimarzio.com と gianlucadimarzio.com を2社にしない（実測で遭遇）。

    媒体数は確度ではなく注目度の指標だが、水増しされると
    1社しか書いていない話が「2社一致」に見えてしまう。
    """
    from src.candidates import outlet_count

    assert outlet_count([
        "https://m.gianlucadimarzio.com/a",
        "https://gianlucadimarzio.com/b",
        "https://amp.theguardian.com/c",
        "https://www.theguardian.com/d",
    ]) == 2

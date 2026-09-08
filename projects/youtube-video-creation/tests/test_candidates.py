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


# 実測（参考チャンネルの再生数）で、日本人選手が絡む話は絡まない話の約2倍。
# 朝2本・夜2本とは別カウントで、毎日1本を日本人枠に充てる。

JAPAN_SCORING = {
    "weights": {"freshness": 3},
    "freshness_hours": {6: 3},
    "japanese": ["鈴木彩艶", "佐藤龍之介", "Japan"],
    "slots": {
        "morning_1": {"prefer": "total"},
        "japan": {"prefer": "total", "require_japanese": True},
    },
}


def _c(cid, title, hours=1.0):
    from src.candidates import Candidate

    return Candidate(id=cid, title=title, hours_ago=hours, topic=cid)


def test_名前で日本人選手の話を見分ける():
    from src.candidates import is_japanese

    words = JAPAN_SCORING["japanese"]
    assert is_japanese(_c("a", "鈴木彩艶がプレミアデビュー"), words)
    assert not is_japanese(_c("b", "Chelsea sign Kone from Roma"), words)


def test_日本人枠には日本人が絡む候補だけが入る():
    from src.candidates import assign, score

    items = score([
        _c("kone", "Chelsea sign Kone from Roma", 0.5),
        _c("sato", "佐藤龍之介がバレンシアで新シーズンへ", 2.0),
    ], JAPAN_SCORING)
    chosen, _ = assign(items, JAPAN_SCORING, ["morning_1", "japan"])
    assert chosen["japan"].id == "sato"
    assert chosen["morning_1"].id == "kone"


def test_日本人の候補が無ければ枠を空ける():
    """別の話で埋めると、枠の意味がなくなる。空けて理由を出す。"""
    from src.candidates import assign, score

    items = score([_c("kone", "Chelsea sign Kone from Roma")], JAPAN_SCORING)
    chosen, fallbacks = assign(items, JAPAN_SCORING, ["japan"])
    assert "japan" not in chosen
    assert any("日本人選手が絡む候補がありません" in n for n in fallbacks["japan"])


# 抽出の軸を2つにした（2026-09-05 ユーザー判断）。
#   1つめ: 新しさ・媒体数・日本人など＝「速報としてどれだけ大きいか」
#   2つめ: まとめ集約サイトの掲載順（クリック数順）＝「いま実際に読まれているか」
# まとめ由来の候補は媒体数1・時刻不明で1つめでは点が伸びず、候補を増やしても
# 枠が埋まらなかった。並び順そのものが手がかりになる。


def _scoring():
    return {
        "weights": {"freshness": 3, "outlets": 3, "topic_rank": 3},
        "freshness_hours": {6: 3, 12: 2, 24: 1},
        "outlets_count": {2: 1, 3: 2, 5: 3},
        "topic_ranks": {10: 3, 25: 2, 50: 1},
    }


def _candidate(**kw):
    from src.candidates import Candidate

    base = dict(id="x", title="見出し", hours_ago=99.0)
    base.update(kw)
    return Candidate(**base)


def test_掲載順が上ほど点が高い():
    from src.candidates import score

    top, middle, low = (_candidate(id=f"c{i}", topic_rank=r) for i, r in enumerate((3, 20, 45)))
    ranked = score([top, middle, low], _scoring())

    points = {c.id: c.breakdown.get("話題順", 0) for c in ranked}
    assert points["c0"] > points["c1"] > points["c2"]


def test_載っていなければ話題順の点は付かない():
    from src.candidates import score

    (item,) = score([_candidate(topic_rank=0)], _scoring())
    assert "話題順" not in item.breakdown


def test_話題順の枠は掲載順だけで選ぶ():
    """こちらの採点を通さない枠。点が低くても、読まれているものを入れる。"""
    from src.candidates import assign, score

    scoring = _scoring()
    scoring["slots"] = {"s": {"prefer": "topic", "min_score": 0}}
    scoring["spread_topics"] = False
    scoring["spread_kinds"] = False
    items = score([
        _candidate(id="高得点", hours_ago=1.0, topic_rank=0),
        _candidate(id="読まれている", hours_ago=99.0, topic_rank=2),
    ], scoring)

    chosen, _ = assign(items, scoring, ["s"])
    assert chosen["s"].id == "読まれている"


def test_話題順の枠に載っている候補が無ければ空ける():
    from src.candidates import assign, score

    scoring = _scoring()
    scoring["slots"] = {"s": {"prefer": "topic"}}
    items = score([_candidate(id="載っていない", topic_rank=0)], scoring)

    chosen, fallbacks = assign(items, scoring, ["s"])
    assert "s" not in chosen
    assert "まとめ集約サイト" in fallbacks["s"][0]


def test_日本人の加点と他の枠を守る仕組みが揃っている():
    """日本人選手に2点。ただし他の枠まで日本人で埋めない。

    2026-09-05 に japanese: 3 を入れたら朝の3枠が全部日本人選手になったので、
    一度0に戻した。2026-09-07 のユーザー判断で2点を入れ直している。
    所属がビッグクラブ13球団に無く、日本語媒体は1社しか書かないことが多いため、
    正攻法では日本人枠が下限5点に届かなかったのが理由。

    当時の再発を防いでいるのは点の大きさではなく、world_* の exclude_japanese。
    **加点と一緒にこのガードが外れていないこと**をここで固定する。
    """
    from src.plan import load_plan

    scoring = load_plan().scoring
    assert int((scoring.get("weights") or {}).get("japanese", 0)) == 2

    slots = scoring.get("slots") or {}
    world = {k: v for k, v in slots.items() if k.startswith("world_")}
    assert world, "world_* の枠が無い"
    for name, slot in world.items():
        assert slot.get("exclude_japanese"), f"{name} が日本人を弾かなくなっている"

# ユーザーが枠を「日本人3・それ以外2・ロマーノ1・プレミア2・ラリーガ1」と
# 指定した（2026-09-05）。群では表せない指定なので、枠の条件を3つ足した。

PICK_SCORING = {
    "weights": {"freshness": 3},
    "freshness_hours": {6: 3},
    "japanese": ["三笘薫", "久保建英"],
    "spread_kinds": False,
    "slots": {
        "japan_1": {"prefer": "total", "require_japanese": True},
        "world_1": {"prefer": "total", "exclude_japanese": True},
        "romano_1": {"prefer": "total", "require_words": ["ロマーノ", "romano"]},
        "premier_1": {"prefer": "total", "require_league": "england"},
        "laliga_1": {"prefer": "total", "require_league": "spain"},
    },
}


def _cl(cid, title, league="", note="", sources=None, hours=1.0):
    from src.candidates import Candidate

    return Candidate(id=cid, title=title, league=league, note=note,
                     sources=list(sources or []), hours_ago=hours, topic=cid)


def test_リーグ指定の枠にはそのリーグだけが入る():
    from src.candidates import assign, score

    items = score([
        _cl("ars", "アーセナルが新加入を発表", "england"),
        _cl("rma", "レアルが新加入を発表", "spain"),
    ], PICK_SCORING)
    chosen, _ = assign(items, PICK_SCORING, ["premier_1", "laliga_1"])
    assert chosen["premier_1"].id == "ars"
    assert chosen["laliga_1"].id == "rma"


def test_指定したリーグが無ければ枠を空ける():
    """別のリーグで埋めたら、枠を分けた意味が無くなる。"""
    from src.candidates import assign, score

    items = score([_cl("rma", "レアルが新加入を発表", "spain")], PICK_SCORING)
    chosen, fallbacks = assign(items, PICK_SCORING, ["premier_1"])
    assert "premier_1" not in chosen
    assert any("england" in m for m in fallbacks["premier_1"])


def test_語で絞る枠は見出し以外も見る():
    """「ロマーノ氏によると」は見出しに出ず、注記や出典側に出る。"""
    from src.candidates import assign, score

    items = score([
        _cl("a", "バルサがバルデ放出へ", "spain", note="ロマーノ氏によると交渉は最終段階"),
        _cl("b", "ミランが新加入を発表", "italy"),
    ], PICK_SCORING)
    chosen, _ = assign(items, PICK_SCORING, ["romano_1"])
    assert chosen["romano_1"].id == "a"


def test_語に触れた候補が無ければ枠を空ける():
    from src.candidates import assign, score

    items = score([_cl("b", "ミランが新加入を発表", "italy")], PICK_SCORING)
    chosen, fallbacks = assign(items, PICK_SCORING, ["romano_1"])
    assert "romano_1" not in chosen
    assert any("ロマーノ" in m for m in fallbacks["romano_1"])


def test_日本人を除く枠には日本人が入らない():
    from src.candidates import assign, score

    items = score([
        _cl("mit", "三笘薫が復帰へ", "england"),
        _cl("hal", "ハーランドが移籍か", "england"),
    ], PICK_SCORING)
    chosen, _ = assign(items, PICK_SCORING, ["world_1"])
    assert chosen["world_1"].id == "hal"


def test_日本人以外が無ければ枠を空ける():
    from src.candidates import assign, score

    items = score([_cl("mit", "三笘薫が復帰へ", "england")], PICK_SCORING)
    chosen, fallbacks = assign(items, PICK_SCORING, ["world_1"])
    assert "world_1" not in chosen
    assert fallbacks["world_1"]

# 実況ブログは1試合を多数の媒体が同時中継するので「媒体数」が伸び、
# 注目度の代わりとして数えている点が高く出る。ところが中身は
# 「47分に1点」だけで動画にならない。実測（2026-09-06）で、8点の
# 「Nottingham Forest vs Tottenham LIVE!」が8点のPSG敗戦記事を押しのけた。

def test_実況やティッカーの見出しを外す():
    from src.candidates import Candidate, is_live_feed

    for title in [
        "Nottingham Forest vs Tottenham LIVE!",
        "Manchester City - Coventry, en directo: Premier League",
        "Serie A Liveblog: Fiorentina vs. Torino",
        "Fiorentina - Torino: Tor zum 1:0 durch Pellegrino in der 47. Minute",
        "トゥールーズvsリール 試合記録",
    ]:
        assert is_live_feed(Candidate(id="x", title=title)), title


def test_普通の記事は外さない():
    """外しすぎると本命が消える。残る側も必ず確かめる。"""
    from src.candidates import Candidate, is_live_feed

    for title in [
        "Luis Enrique unfazed by PSG historic winless start",
        "Raphinha appointed Barcelona captain",
        "リヴァプール、ヒューズSDの辞任を発表…新天地はサウジのアル・ヒラルが決定的",
        "モドリッチ、41歳でクロアチア代表を続行",
    ]:
        assert not is_live_feed(Candidate(id="x", title=title)), title


def test_実況は枠に入らない():
    """点が高くても枠から外れる。理由も残す。"""
    from src.candidates import assign, score

    items = score([
        _cl("live", "Forest vs Tottenham LIVE!", "england", hours=0.1),
        _cl("news", "アーセナルが新加入を発表", "england", hours=3.0),
    ], PICK_SCORING)
    chosen, fallbacks = assign(items, PICK_SCORING, ["premier_1"])
    assert chosen["premier_1"].id == "news"
    assert any("実況" in m for m in fallbacks["_"])

def test_実況とスタメンの両方が外れる():
    """**マージで片方が消えた**（2026-09-07）。

    二人が同じ関数を別々に直し、取り込んだとき一方が落ちた。
    両方が同時に効いていることを、ここで固定する。
    """
    from src.candidates import assign, score

    items = score([
        _cl("live", "Forest vs Tottenham LIVE!", "england", hours=0.1),
        _cl("xi", "アーセナル対チェルシー、スタメン発表！", "england", hours=0.2),
        _cl("news", "90+5! Maitland-Niles stuns Man Utd", "england", hours=3.0),
    ], PICK_SCORING)
    chosen, fallbacks = assign(items, PICK_SCORING, ["premier_1"])
    assert chosen["premier_1"].id == "news"
    notes = " ".join(fallbacks.get("_", []))
    assert "実況" in notes, notes
    assert "スタメン" in notes, notes

# 試合結果の枠（2026-09-07）。2chサッカーの噂話は直近1日で、結果の動画が
# 13万回×2、順位表が6.7万回。移籍の噂と同じかそれ以上に見られていた。

def test_試合結果の枠は移籍の話で埋めない():
    from src.candidates import Candidate, assign

    items = [
        Candidate(id="a", title="移籍の話", url="https://a.example/1", score=9,
                  kind="transfer"),
        Candidate(id="b", title="試合の話", url="https://b.example/2", score=4,
                  kind="match"),
    ]
    picked, _ = assign(
        items, {"slots": {"match_1": {"require_kind": "match"}}}, ["match_1"]
    )
    assert [c.title for c in picked.values()] == ["試合の話"]


def test_試合が無い日は枠を空ける():
    from src.candidates import Candidate, assign

    items = [Candidate(id="a", title="移籍の話", url="https://a.example/1",
                       score=9, kind="transfer")]
    picked, fallbacks = assign(
        items, {"slots": {"match_1": {"require_kind": "match"}}}, ["match_1"]
    )
    assert picked == {}
    assert any("枠を空けます" in m for m in fallbacks.get("match_1", []))

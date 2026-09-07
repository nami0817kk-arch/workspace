from datetime import date

import pytest

from src.plan import PlanError, build_plan, load_plan, render, tokens, worksheet

RAW = {
    "domains": {"english": ["skysports.com", "espn.com"], "social": ["x.com"]},
    "tiers": {
        "確定": {"needs_sources": 1, "needs_official": True},
        "報道": {"needs_sources": 2, "needs_official": False},
        "未確認": {"needs_sources": 1, "needs_official": False},
    },
    "cadence": {"per_day": 3, "slots": ["weekly"]},
    "routines": {
        "weekly": {
            "name": "週まとめ",
            "when": "毎週土曜",
            "cover_hours": 12,
            "target_minutes": 3,
            "steps": [
                {
                    "id": "confirmed",
                    "what": "確定した移籍",
                    "tier": "確定",
                    "queries": [{"q": "confirmed transfers {period_en}", "domains": "english"}],
                    "check": "発表日を控える",
                },
                {
                    "id": "rumours",
                    "what": "噂",
                    "tier": "未確認",
                    "topics": ["選手A", "選手B"],
                    "queries": [{"q": "{topic} transfer latest", "domains": "social"}],
                },
            ],
        }
    },
}


def test_topics_expand_into_one_query_each():
    plan = build_plan(RAW)
    rumours = plan.routine("weekly").steps[1]
    assert [q.text for q in rumours.queries] == ["選手A transfer latest", "選手B transfer latest"]
    assert rumours.queries[0].domains == ["x.com"]


def test_topic_query_is_dropped_when_no_topics():
    raw = {**RAW}
    raw["routines"]["weekly"]["steps"][1]["topics"] = []
    plan = build_plan(raw)
    assert plan.routine("weekly").steps[1].queries == []
    raw["routines"]["weekly"]["steps"][1]["topics"] = ["選手A", "選手B"]  # 戻す


def test_unknown_tier_is_rejected():
    raw = {
        **RAW,
        "routines": {
            "x": {"steps": [{"id": "a", "tier": "たぶん", "queries": []}]}
        },
    }
    with pytest.raises(PlanError, match="未定義の確度"):
        build_plan(raw)


def test_unknown_routine_lists_the_known_ones():
    plan = build_plan(RAW)
    with pytest.raises(PlanError, match="weekly"):
        plan.routine("なにか")


def test_date_tokens():
    words = tokens(date(2026, 8, 29), 7)
    assert words["{date_ja}"] == "2026年8月29日"
    assert words["{period_en}"] == "August 2026"
    assert words["{today_en}"] == "29 August 2026"


def test_render_fills_dates_and_domains():
    text = render(build_plan(RAW).routine("weekly"), date(2026, 8, 29))
    assert "confirmed transfers August 2026" in text
    assert "skysports.com" in text
    assert "発表日を控える" in text


def test_worksheet_is_a_deep_dive_template():
    """1本＝1テーマなので、雛形はテーマ・問い・節で構成される。"""
    text = worksheet(build_plan(RAW).routine("weekly"), date(2026, 8, 29))
    assert "theme:" in text and "question:" in text and "answer:" in text
    assert "sections:" in text
    # structure 未定義なら既定の3節（何が起きたか／なぜ／これから）
    assert text.count("- id:") == 3


def test_worksheet_follows_the_configured_structure():
    raw = {**RAW}
    raw["routines"]["weekly"] = {
        **raw["routines"]["weekly"],
        "structure": [
            {"id": "a", "heading": "見出しA", "tier": "確定"},
            {"id": "b", "heading": "見出しB", "tier": "背景"},
        ],
    }
    text = worksheet(build_plan(raw).routine("weekly"), date(2026, 8, 29))
    assert "heading: 見出しA" in text and "tier: 背景" in text
    assert text.count("- id:") == 2
    del raw["routines"]["weekly"]["structure"]


def test_cover_hours_reads_as_a_span():
    routine = build_plan(RAW).routine("weekly")
    assert routine.cover_hours == 12
    assert routine.span == "直近12時間"


def test_cover_days_is_still_understood():
    """日単位の旧表記も時間に直して読む。"""
    raw = {**RAW}
    raw["routines"]["weekly"] = {**raw["routines"]["weekly"], "cover_hours": None,
                                 "cover_days": 3}
    del raw["routines"]["weekly"]["cover_hours"]
    routine = build_plan(raw).routine("weekly")
    assert routine.cover_hours == 72 and routine.span == "直近3日"
    raw["routines"]["weekly"]["cover_hours"] = 12  # 戻す


def test_slot_without_a_routine_is_rejected():
    raw = {**RAW, "cadence": {"slots": ["morning"]}}
    with pytest.raises(PlanError, match="morning"):
        build_plan(raw)


def test_render_lists_recent_coverage():
    from datetime import datetime

    from src.coverage import Entry

    covered = [Entry("a", "扱った話題", "morning", datetime(2026, 8, 29, 7, 0))]
    text = render(build_plan(RAW).routine("weekly"), date(2026, 8, 29), covered)
    assert "扱った話題" in text and "morning" in text


def test_枠は9本以上で狭い条件の枠が先頭寄り():
    """日本人3・ロマーノ1・ラリーガ1・プレミア2・日本人以外2（2026-09-05 の指定）。

    **条件の狭い枠を先に置く。**枠は書いた順に埋まるので、広い枠を先にすると
    良い候補を先に取られて狭い枠が空になる（popular_1 で実測済み）。
    日本人枠を先頭に置くのは、日本人選手の多くがプレミアにいるため。
    premier を先にすると三笘のような候補をプレミア枠が取り、日本人枠が痩せる。
    """
    plan = load_plan()
    # **9本は下限**（2026-09-06 ユーザー）。良い候補がある日は足す。
    # 足した枠も min_score で守られるので、無い日は空くだけ
    assert len(plan.slots) >= 9
    assert len(set(plan.slots)) == len(plan.slots)     # 同じ枠名を2度書かない
    rules = plan.scoring.get("slots") or {}
    for name in plan.slots:
        assert name in rules, f"{name} に条件がありません"
    assert len([s for s in plan.slots if s.startswith("world_")]) >= 2
    # 日本人3枠・日本人以外2枠。対にして、寄りすぎを防ぐ
    # 2026-09-07: 日本人3枠 → **5枠**（ユーザー判断）。各チャンネルの最高再生を
    # 並べたら、サッカー知恵袋の人気上位15本のうち11本が日本人・日本代表だった。
    # 試合結果の枠も2つ新設した（噂話の直近1日で13万回×2）
    assert len([s for s, r in rules.items() if (r or {}).get("require_japanese")]) == 5
    assert len([s for s, r in rules.items() if (r or {}).get("require_kind")]) == 2
    assert len([s for s, r in rules.items() if (r or {}).get("exclude_japanese")]) >= 2
    # 同じ枠に両方を書くと必ず空になる
    for name, rule in rules.items():
        assert not ((rule or {}).get("require_japanese") and (rule or {}).get("exclude_japanese")), name
    # リーグ指定と記者指定
    assert (rules.get("laliga_1") or {}).get("require_league") == "spain"
    assert (rules.get("premier_1") or {}).get("require_league") == "england"
    assert "ロマーノ" in ((rules.get("romano_1") or {}).get("require_words") or [])
    # 広い枠（日本人以外）は狭い枠より後ろ
    assert plan.slots.index("world_1") > plan.slots.index("laliga_1")
    assert plan.slots.index("japan_1") < plan.slots.index("premier_1")
    # 同じ系統の枠は同じ取材計画を共有する（枠ごとに書き写すと片方が古くなる）
    assert plan.routine("japan_1") is plan.routine("japan_2")
    assert plan.routine("premier_1").name == plan.routine("premier_2").name
    assert plan.routine("japan_1").name == "日本人選手"
    assert set(plan.tiers) >= {"確定", "報道", "未確認"}


def test_枠に入れる下限がある():
    """本数を増やすと埋めるために弱い候補が入る。届かなければ空ける。"""
    plan = load_plan()
    assert int(plan.scoring.get("min_score", 0)) >= 1


def test_domains_map_to_their_confidence_ceiling():
    from src.plan import build_plan

    plan = build_plan(RAW)
    plan.domains = {
        "official": ["atleticodemadrid.com"],
        "english": ["skysports.com"],
        "blocked": ["bbc.com"],
    }
    plan.domain_tiers = {"official": "確定", "english": "報道"}

    assert plan.group_of("https://en.atleticodemadrid.com/noticias/x") == "official"
    assert plan.ceiling("https://en.atleticodemadrid.com/noticias/x") == "確定"
    assert plan.ceiling("https://www.skysports.com/football/news/1/2/x") == "報道"
    assert plan.ceiling("https://example.com/x") == ""


def test_registered_accounts_set_their_own_ceiling():
    """x.com はどのアカウントも同じ群に入るので、群だけ見ると記者ごとの差が出せない。

    accounts に tier を書いたアカウントは、その値をそのアカウントの上限にする。
    書いていないアカウントは従来どおり群（social）の上限のまま。
    """
    from src.plan import build_plan

    plan = build_plan(RAW)
    plan.domains = {"social": ["x.com"]}
    plan.domain_tiers = {"social": "未確認"}
    plan.accounts = [
        {"handle": "FabrizioRomano", "tier": "確定"},
        {"handle": "David_Ornstein", "tier": "未確認"},
    ]

    assert plan.ceiling("https://x.com/FabrizioRomano/status/123") == "確定"
    assert plan.ceiling("https://x.com/David_Ornstein/status/123") == "未確認"
    # 登録していないアカウントは群の上限に落ちる
    assert plan.ceiling("https://x.com/someone_else/status/123") == "未確認"


def test_account_ceiling_only_applies_to_social_urls():
    from src.plan import build_plan

    plan = build_plan(RAW)
    plan.accounts = [{"handle": "FabrizioRomano", "tier": "確定"}]

    assert plan.account_ceiling("https://www.skysports.com/football/news/1/2/x") == ""


def test_blocked_domains_are_recognised_but_not_grouped():
    from src.plan import build_plan

    plan = build_plan(RAW)
    plan.domains = {"english": ["skysports.com"], "blocked": ["bbc.com"]}

    assert plan.is_blocked("https://www.bbc.com/sport/1") is True
    assert plan.group_of("https://www.bbc.com/sport/1") == ""   # blocked は群にしない
    assert plan.is_blocked("https://www.skysports.com/x") is False


def _plan_with_leagues():
    from src.plan import build_plan

    plan = build_plan(RAW)
    plan.domains = {"german": ["kicker.de", "sport1.de"], "english": ["espn.com"]}
    plan.leagues = {
        "germany": {
            "name": "ブンデスリーガ",
            "official": ["bundesliga.com", "bvb.de"],
            "media": "german",
            "match_q": "Spielbericht Noten",
            "official_q": "Spielbericht",
        },
        "netherlands": {"name": "エールディヴィジ", "official": [], "media": "dutch"},
    }
    return plan


def test_match_queries_are_scoped_to_one_league():
    plan = _plan_with_leagues()
    media, official = plan.match_queries("germany")

    assert media.text == "Spielbericht Noten"
    assert media.domains == ["kicker.de", "sport1.de"]
    assert official.text == "Spielbericht"
    assert official.domains == ["bundesliga.com", "bvb.de"]
    assert media.label == official.label == "ブンデスリーガ"


def test_the_official_half_can_be_left_out():
    plan = _plan_with_leagues()
    assert len(plan.match_queries("germany", official=False)) == 1


def test_a_league_without_official_sites_gets_only_the_media_query():
    plan = _plan_with_leagues()
    assert len(plan.match_queries("netherlands")) == 1


def test_an_unknown_league_returns_nothing():
    assert _plan_with_leagues().match_queries("brazil") == []


def test_the_league_name_falls_back_to_its_key():
    plan = _plan_with_leagues()
    assert plan.league_name("germany") == "ブンデスリーガ"
    assert plan.league_name("brazil") == "brazil"


# 取材メモの雛形に league が無く、書く人が埋めようがなかった。
# その結果 covered.yaml にリーグが載らず、stats の「追えていないリーグ」が
# 1本作っても永久に減らなかった。


def test_取材メモの雛形にリーグの欄がある():
    from datetime import date

    from src.plan import load_plan, worksheet

    body = worksheet(load_plan().routine("deadline_day"), date(2026, 9, 1))
    assert "league:" in body
    # 何を書けばよいかまで書いていないと、結局空のままになる
    assert "germany" in body

# 11本つづけて同じ骨格だった（2026-09-06 実測。9本が「何が起きたか」で始まり、
# 7本が「これからどうなる」で終わっていた）。種類ごとに型を分けた。

def test_話の型を選べる():
    from datetime import date

    from src.plan import worksheet

    plan = load_plan()
    routine = plan.routine("world_1")
    shapes = plan.skeletons
    assert {"transfer", "match", "quote", "discipline", "preview"} <= set(shapes)

    sheet = worksheet(routine, date(2026, 9, 6), "discipline", shapes)
    assert "誰にどんな処分が出たか" in sheet
    assert "これからどうなる" not in sheet

    # **試合前の型は「これからどうなる」で締めない。**まだ起きていないので
    sheet = worksheet(routine, date(2026, 9, 6), "preview", shapes)
    assert "何がかかっているか" in sheet
    assert "これからどうなる" not in sheet


def test_知らない型は弾く():
    """黙って既定に落とすと、指定した気になったまま同じ骨格が出る。"""
    from datetime import date

    from src.plan import PlanError, worksheet

    plan = load_plan()
    try:
        worksheet(plan.routine("world_1"), date(2026, 9, 6), "nonsense", plan.skeletons)
    except PlanError as err:
        assert "知らない型" in str(err)
    else:
        raise AssertionError("知らない型を通した")


def test_型を指定しなければ既定に落ちる():
    from datetime import date

    from src.plan import worksheet

    plan = load_plan()
    sheet = worksheet(plan.routine("world_1"), date(2026, 9, 6), "", plan.skeletons)
    assert "sections:" in sheet

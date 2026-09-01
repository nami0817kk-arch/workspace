from datetime import datetime, timedelta

import pytest

from src.freshness import (
    Observation,
    Ref,
    advice,
    hours_ago,
    latest,
    load,
    observe,
    rank,
    rate,
    read,
    save,
)

SKY = "https://www.skysports.com/football/news/11095/13578318/julian-alvarez-deadline"
SKY_OLD = "https://www.skysports.com/football/news/11095/13546220/window-dates"
SKY_TRANSFER = "https://www.skysports.com/transfer/news/12691/13501314/deadline-day-deals"
ESPN = "https://www.espn.com/soccer/story/_/id/49741017/atletico-alvarez-barcelona"
POST = "https://x.com/FabrizioRomano/status/2092160046985543990"
GOAL = "https://www.goal.com/en-us/lists/alvarez/blt1b512ce1c10cf431"

T0 = datetime(2026, 8, 29, 6, 0)


def test_article_ids_come_out_of_news_urls():
    assert read(SKY).site == "skysports.com"
    assert read(SKY).number == 13578318
    assert read(SKY_TRANSFER).number == 13501314
    assert read(ESPN).site == "espn.com"
    assert read(ESPN).number == 49741017


def test_x_posts_carry_their_exact_time():
    ref = read(POST)
    assert ref.site == "x.com"
    assert ref.posted_at.year == 2026 and ref.posted_at.month == 8


def test_urls_without_a_date_clue_are_left_unknown():
    assert read(GOAL).known is False
    assert read("not a url").known is False


def test_results_are_grouped_by_site_and_sorted_newest_first():
    groups = rank([SKY_OLD, GOAL, ESPN, SKY])
    assert set(groups) == {"skysports.com", "espn.com"}
    assert [r.number for r in groups["skysports.com"]] == [13578318, 13546220]


def test_the_pace_needs_two_readings_far_enough_apart():
    one = [Observation("skysports.com", 100, T0)]
    assert rate(one, "skysports.com") is None

    close = one + [Observation("skysports.com", 200, T0 + timedelta(hours=2))]
    assert rate(close, "skysports.com") is None  # 2時間では短すぎる

    apart = one + [Observation("skysports.com", 2500, T0 + timedelta(hours=24))]
    assert rate(apart, "skysports.com") == 100.0


def test_the_pace_is_not_guessed_when_the_index_stood_still():
    entries = [
        Observation("skysports.com", 100, T0),
        Observation("skysports.com", 100, T0 + timedelta(hours=24)),
    ]
    assert rate(entries, "skysports.com") is None


def test_age_is_estimated_from_the_pace():
    entries = [
        Observation("skysports.com", 1000, T0),
        Observation("skysports.com", 3400, T0 + timedelta(hours=24)),  # 100/時
    ]
    now = T0 + timedelta(hours=30)
    assert hours_ago(Ref("", "skysports.com", 3400), entries, now) == 6.0
    assert hours_ago(Ref("", "skysports.com", 2400), entries, now) == 16.0


def test_age_is_not_estimated_without_enough_record():
    entries = [Observation("skysports.com", 1000, T0)]
    assert hours_ago(Ref("", "skysports.com", 900), entries) is None
    assert hours_ago(Ref("", "espn.com", 900), entries) is None


def test_x_post_age_ignores_the_ledger():
    assert hours_ago(read(POST), []) is not None


def test_observing_records_the_highest_id_seen():
    groups = rank([SKY_OLD, SKY, ESPN, POST])
    entries, growth = observe(groups, [], T0)
    assert latest(entries, "skysports.com").max_number == 13578318
    assert latest(entries, "espn.com").max_number == 49741017
    assert latest(entries, "x.com") is None      # Xは時刻が直接分かるので記録しない
    assert growth == {"skysports.com": 0, "espn.com": 0}


def test_growth_is_measured_against_the_previous_reading():
    before = [Observation("skysports.com", 13578000, T0)]
    entries, growth = observe(rank([SKY]), before, T0 + timedelta(hours=24))
    assert growth["skysports.com"] == 318
    assert len(entries) == 2


def test_a_standstill_adds_no_record_and_is_reported():
    before = [Observation("skysports.com", 13578318, T0)]
    now = T0 + timedelta(hours=24)
    entries, growth = observe(rank([SKY]), before, now)
    assert entries == before          # 進んでいないので記録は増えない
    assert growth["skysports.com"] == 0
    assert any("索引が進んでいない" in note for note in advice(growth, before, now))


def test_a_rerun_soon_after_is_not_called_a_standstill():
    before = [Observation("skysports.com", 13578318, T0)]
    soon = T0 + timedelta(minutes=5)
    _, growth = observe(rank([SKY]), before, soon)
    assert growth["skysports.com"] == 0        # 伸びはゼロだが
    assert advice(growth, before, soon) == []  # 止まったとは言わない


def test_growth_is_not_reported_when_the_index_moved():
    before = [Observation("skysports.com", 13578000, T0)]
    assert advice({"skysports.com": 318}, before) == []


def test_the_ledger_survives_a_round_trip(tmp_path):
    path = tmp_path / "f.yaml"
    entries = [Observation("skysports.com", 13578318, T0), Observation("espn.com", 49741017, T0)]
    save(path, entries)
    assert load(path) == entries


def test_a_missing_ledger_reads_as_empty(tmp_path):
    assert load(tmp_path / "none.yaml") == []


def test_broken_rows_are_skipped_rather_than_raising(tmp_path):
    path = tmp_path / "f.yaml"
    path.write_text(
        "observed:\n"
        "  - {site: skysports.com, max: 1, at: '2026-08-29T06:00'}\n"
        "  - {site: espn.com, max: nonsense, at: '2026-08-29T06:00'}\n"
        "  - {max: 3, at: '2026-08-29T06:00'}\n",
        encoding="utf-8",
    )
    assert [e.site for e in load(path)] == ["skysports.com"]


def test_every_sky_section_is_recognised():
    # セクション名は news だけではない。実際に出てきたものを並べる
    sections = {
        "https://www.skysports.com/football/news/11095/13578318/a": 13578318,
        "https://www.skysports.com/football/transfer-paper-talk/12709/13578898/b": 13578898,
        "https://www.skysports.com/football/live-blog/11095/12476234/c": 12476234,
        "https://www.skysports.com/transfer/news/12691/13501314/d": 13501314,
    }
    for url, number in sections.items():
        ref = read(url)
        assert ref.site == "skysports.com", url
        assert ref.number == number, url


def test_other_sky_pages_are_not_mistaken_for_articles():
    assert read("https://www.skysports.com/football/teams/arsenal").known is False


def test_dates_in_the_url_are_read_exactly():
    from datetime import date

    cases = {
        "https://www.soccer-king.jp/news/world/esp/20260828/2197673.html": date(2026, 8, 28),
        "https://www.footballchannel.jp/2026/08/29/post1000500/": date(2026, 8, 29),
        "https://www.caughtoffside.com/2026/08/29/julian-alvarez-arsenal/": date(2026, 8, 29),
    }
    for url, when in cases.items():
        ref = read(url)
        assert ref.posted_on == when, url
        assert ref.exact is True, url
        assert ref.known is True, url


def test_an_exact_date_needs_no_ledger():
    from datetime import date, datetime

    ref = read("https://www.footballchannel.jp/2026/08/29/post1/")
    # その日の正午に出たものとして扱う
    assert hours_ago(ref, [], datetime(2026, 8, 30, 12, 0)) == 24.0
    assert ref.posted_on == date(2026, 8, 29)


def test_a_future_date_does_not_go_negative():
    from datetime import datetime

    ref = read("https://www.footballchannel.jp/2026/08/30/post1/")
    assert hours_ago(ref, [], datetime(2026, 8, 30, 6, 0)) == 0.0


def test_a_nonsense_date_in_the_url_is_ignored():
    assert read("https://www.footballchannel.jp/2026/13/45/post1/").known is False


def test_ultra_soccer_ids_are_recognised():
    ref = read("https://web.ultra-soccer.jp/news/all/34358/")
    assert ref.site == "web.ultra-soccer.jp"
    assert ref.number == 34358


def test_dated_and_numbered_refs_sort_together():
    dated_new = "https://www.footballchannel.jp/2026/08/29/post1/"
    dated_old = "https://www.footballchannel.jp/2026/08/27/post2/"
    groups = rank([dated_old, dated_new])
    assert [r.posted_on.day for r in groups["footballchannel.jp"]] == [29, 27]


def test_premier_league_news_ids_are_recognised():
    ref = read("https://www.premierleague.com/en/news/4664145/when-does-the-window-close")
    assert ref.site == "premierleague.com"
    assert ref.number == 4664145
    assert ref.exact is False      # IDだけなので日付は分からない


def test_any_site_with_a_date_in_the_url_is_read():
    from datetime import date

    # 登録していないサイトでも /2026/08/30/ があれば日付が読める
    ref = read("https://some-new-site.example/news/2026/08/30/a-story/")
    assert ref.site == "some-new-site.example"
    assert ref.posted_on == date(2026, 8, 30)
    assert ref.exact is True


def test_the_generic_pattern_also_reads_hyphenated_dates():
    from datetime import date

    ref = read("https://www.acmilan.com/en/news/articles/media/2026-01-30/official-statement")
    assert ref.posted_on == date(2026, 1, 30)


def test_the_generic_pattern_rejects_impossible_dates():
    assert read("https://example.com/2026/13/45/x/").known is False
    assert read("https://example.com/2026/02/30/x/").known is False


def test_named_patterns_win_over_the_generic_one():
    # skysports は日付ではなく記事IDで判定する
    ref = read("https://www.skysports.com/football/news/11095/13578318/x")
    assert ref.site == "skysports.com"
    assert ref.number == 13578318
    assert ref.posted_on is None


def test_articles_far_below_the_watermark_are_flagged():
    from src.freshness import suspects

    # 実際に踏んだ例。前シーズンの「Matchweek 2」記事が今節として返った
    entries = [Observation("premierleague.com", 4_698_606, T0)]
    groups = rank([
        "https://www.premierleague.com/en/news/4391799/who-was-the-best-player-of-matchweek-2",
        "https://www.premierleague.com/en/news/4698429/the-scouts-fpl-gameweek-2-radar",
    ])
    found = suspects(groups, entries)
    assert [ref.number for ref, _ in found] == [4391799]
    assert found[0][1] == 4_698_606


def test_nothing_is_flagged_without_a_watermark():
    from src.freshness import suspects

    groups = rank(["https://www.premierleague.com/en/news/4391799/x"])
    assert suspects(groups, []) == []


def test_urls_with_a_readable_date_are_not_flagged():
    from src.freshness import suspects

    # 日付が読めるものは、そちらで判断できるので ID を持ち出さない
    entries = [Observation("footballchannel.jp", 999_999, T0)]
    groups = rank(["https://www.footballchannel.jp/2024/01/01/post1/"])
    assert suspects(groups, entries) == []


def test_kicker_match_report_ids_are_recognised():
    ref = read("https://www.kicker.de/leverkusen-gegen-wolfsburg-2026-bundesliga-5050994/spielbericht")
    assert ref.site == "kicker.de"
    assert ref.number == 5050994


def _obs(site, number, days=0, minutes=0):
    return Observation(site, number, T0 - timedelta(days=days, minutes=minutes))


def test_pruning_caps_how_many_are_kept_per_day():
    from src.freshness import KEEP_PER_DAY, prune

    # 同じ日に6回回した。番号は回すほど大きくなる
    entries = [_obs("skysports.com", 1005 - i, minutes=i * 10) for i in range(6)]
    kept = prune(entries, T0)
    assert len(kept) == KEEP_PER_DAY
    # いちばん新しいものは必ず残る（水準の判定に使う）
    assert max(k.max_number for k in kept) == 1005


def test_pruning_keeps_several_days_for_the_pace():
    from src.freshness import prune

    entries = [_obs("skysports.com", 1000 + day * 100, days=day) for day in range(10)]
    kept = prune(entries, T0)
    assert len(kept) == 10          # 日をまたいだぶんは残す


def test_pruning_drops_what_is_too_old():
    from src.freshness import KEEP_DAYS, prune

    entries = [_obs("skysports.com", 900, days=KEEP_DAYS + 10), _obs("skysports.com", 1000)]
    kept = prune(entries, T0)
    assert [k.max_number for k in kept] == [1000]


def test_pruning_never_empties_a_site():
    from src.freshness import KEEP_DAYS, prune

    # 古い記録しかないサイトでも、1つは残す
    kept = prune([_obs("espn.com", 900, days=KEEP_DAYS + 10)], T0)
    assert len(kept) == 1


def test_pruning_handles_each_site_separately():
    from src.freshness import prune

    entries = [_obs("skysports.com", 1000 + i, minutes=i) for i in range(5)]
    entries += [_obs("espn.com", 2000 + i, minutes=i) for i in range(5)]
    kept = prune(entries, T0)
    assert len({k.site for k in kept}) == 2
    assert sum(1 for k in kept if k.site == "espn.com") == 3


def test_pruned_records_stay_in_time_order():
    from src.freshness import prune

    entries = [_obs("skysports.com", 1000 + day * 10, days=day) for day in (3, 1, 2)]
    kept = prune(entries, T0)
    assert [k.at for k in kept] == sorted(k.at for k in kept)


def test_sites_without_article_ids_are_not_recorded():
    from src.freshness import observe

    # 日付が読めるサイトは max が 0 になる。記録すると水準の判定を汚す
    groups = rank([
        "https://www.footballchannel.jp/2026/08/29/post1/",
        "https://www.skysports.com/football/news/11095/13578318/x",
    ])
    entries, growth = observe(groups, [], T0)
    assert [e.site for e in entries] == ["skysports.com"]
    assert "footballchannel.jp" not in growth


# ---------------------------------------------------------------- 較正
# フィードは記事URLと正確な公開時刻を一緒にくれる。
# 「そのIDがいつの時点のものか」が推定ではなく分かる。

def _sky(number: int) -> str:
    return f"https://www.skysports.com/football/news/11661/{number}/story"


def test_フィードの時刻で水準を較正する():
    from datetime import datetime

    from src import freshness

    pairs = [
        (_sky(13000010), datetime(2026, 8, 31, 0, 0)),
        (_sky(13000100), datetime(2026, 8, 31, 8, 0)),
    ]
    entries, tuned = freshness.calibrate(pairs, [])
    assert set(tuned) == {"skysports.com"}
    assert all(entry.exact for entry in entries)


def test_1回の取得だけで伸びの速さが出る():
    from datetime import datetime

    from src import freshness

    # 1本のフィードに新旧の記事が入っている。離れた2点が取れれば、
    # 日をまたいで待たなくてもペースが出せる
    pairs = [
        (_sky(13000010), datetime(2026, 8, 31, 0, 0)),
        (_sky(13000050), datetime(2026, 8, 31, 4, 0)),
        (_sky(13000100), datetime(2026, 8, 31, 8, 0)),
    ]
    entries, _ = freshness.calibrate(pairs, [])
    assert freshness.rate(entries, "skysports.com") == pytest.approx(11.25)


def test_近すぎる2点では1点しか記録しない():
    from datetime import datetime

    from src import freshness

    pairs = [
        (_sky(13000090), datetime(2026, 8, 31, 7, 0)),
        (_sky(13000100), datetime(2026, 8, 31, 8, 0)),
    ]
    entries, _ = freshness.calibrate(pairs, [])
    assert len(entries) == 1


def test_同じ較正を二度足さない():
    from datetime import datetime

    from src import freshness

    pairs = [
        (_sky(13000010), datetime(2026, 8, 31, 0, 0)),
        (_sky(13000100), datetime(2026, 8, 31, 8, 0)),
    ]
    entries, _ = freshness.calibrate(pairs, [])
    again, tuned = freshness.calibrate(pairs, entries)
    assert len(again) == len(entries)
    assert tuned == {}


def test_IDを持たないサイトは較正しない():
    from datetime import datetime

    from src import freshness

    pairs = [
        ("https://www.soccer-king.jp/news/world/2026/08/31/1234567.html", datetime(2026, 8, 31, 8, 0)),
        ("https://x.com/FabrizioRomano/status/1961000000000000000", datetime(2026, 8, 31, 8, 0)),
    ]
    entries, tuned = freshness.calibrate(pairs, [])
    assert entries == [] and tuned == {}


def test_較正した記録があるならそれだけでペースを出す():
    from datetime import datetime

    from src import freshness
    from src.freshness import Observation

    # 「見た時刻」は公開より遅いぶん、混ぜると伸びを実際より遅く見積もる
    rough = [
        Observation("skysports.com", 13000010, datetime(2026, 8, 30, 12, 0)),
        Observation("skysports.com", 13000100, datetime(2026, 8, 31, 12, 0)),
    ]
    pairs = [
        (_sky(13000010), datetime(2026, 8, 31, 0, 0)),
        (_sky(13000100), datetime(2026, 8, 31, 8, 0)),
    ]
    entries, _ = freshness.calibrate(pairs, rough)
    assert freshness.rate(entries, "skysports.com") == pytest.approx(11.25)

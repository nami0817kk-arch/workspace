from datetime import datetime, timedelta

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

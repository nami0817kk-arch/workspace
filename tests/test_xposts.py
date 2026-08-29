from datetime import datetime, timezone

import pytest

from src.xposts import (
    Post,
    XPostError,
    from_search_result,
    is_post,
    parse_url,
    posted_at,
    review,
    trusted,
)

ACCOUNTS = [
    {"handle": "FabrizioRomano", "name": "Fabrizio Romano", "tier": "未確認"},
    {"handle": "@TheAthleticFC", "name": "The Athletic", "tier": "報道"},
]


def test_post_time_comes_out_of_the_url():
    # 実在の投稿（Ranieri 就任時）。2019年10月であることが分かっている
    when = posted_at("https://x.com/FabrizioRomano/status/1183028368629010432")
    assert when.year == 2019 and when.month == 10 and when.day == 12
    assert when.tzinfo is timezone.utc


def test_twitter_com_and_bare_ids_work_too():
    url = posted_at("https://twitter.com/FabrizioRomano/status/2092546263447146991")
    bare = posted_at("2092546263447146991")
    assert url == bare == posted_at(2092546263447146991)


def test_parsing_picks_up_the_handle():
    handle, post_id = parse_url("https://x.com/David_Ornstein/status/1820480131842052513?lang=en")
    assert handle == "David_Ornstein"
    assert post_id == 1820480131842052513


def test_a_non_post_url_is_rejected():
    assert is_post("https://www.skysports.com/football/news/1") is False
    with pytest.raises(XPostError):
        parse_url("https://x.com/FabrizioRomano")


def test_hours_ago_is_measured_against_now():
    post = Post(url="", posted_at=datetime(2026, 8, 29, 0, 0, tzinfo=timezone.utc))
    assert post.hours_ago(datetime(2026, 8, 29, 6, 0, tzinfo=timezone.utc)) == 6.0
    assert Post(url="").hours_ago() is None


def test_search_result_is_split_into_author_and_text():
    post = from_search_result(
        'Fabrizio Romano on X: "🚨 Balde has informed Barcelona of his desire to STAY." / X',
        "https://x.com/FabrizioRomano/status/2092546263447146991",
    )
    assert post.author == "Fabrizio Romano"
    assert post.handle == "FabrizioRomano"
    assert post.text == "🚨 Balde has informed Barcelona of his desire to STAY."
    assert post.truncated is False
    assert post.posted_at.year == 2026


def test_a_cut_off_post_is_flagged():
    post = from_search_result(
        'Fabrizio Romano on X: "So far, Julian only wanted Barcel..." / X',
        "https://x.com/FabrizioRomano/status/2092160046985543990",
    )
    assert post.truncated is True


def test_a_profile_page_result_has_no_text():
    post = from_search_result(
        "Fabrizio Romano (@FabrizioRomano) / Posts / X", "https://x.com/FabrizioRomano"
    )
    assert post.text == ""
    assert post.posted_at is None


def test_trusted_ignores_case_and_the_at_sign():
    assert trusted("fabrizioromano", ACCOUNTS)["tier"] == "未確認"
    assert trusted("@TheAthleticFC", ACCOUNTS)["tier"] == "報道"
    assert trusted("someone_else", ACCOUNTS) is None


NOW = datetime(2026, 8, 26, 12, 0, tzinfo=timezone.utc)  # 投稿の約2.5時間後


def test_a_fresh_post_from_a_known_account_passes():
    url = "https://x.com/FabrizioRomano/status/2092546263447146991"
    assert review(url, ACCOUNTS, 24, NOW) == []


def test_an_unknown_account_is_reported():
    url = "https://x.com/whoever/status/2092546263447146991"
    assert any("登録済み" in p for p in review(url, ACCOUNTS, 24, NOW))


def test_an_old_post_is_reported():
    url = "https://x.com/FabrizioRomano/status/1183028368629010432"  # 2019年
    assert any("時間前" in p for p in review(url, ACCOUNTS, 24, NOW))

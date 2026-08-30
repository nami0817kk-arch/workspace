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


def _call(handle, outcome="未判明", url=""):
    from datetime import datetime

    from src.xposts import Call

    return Call(handle=handle, url=url or f"https://x.com/{handle}/status/1",
                said="x", at=datetime(2026, 8, 30, 12, 0), outcome=outcome)


def test_a_post_is_recorded_with_its_time(tmp_path):
    from src.xposts import load_calls, record_call

    ledger = tmp_path / "r.yaml"
    call = record_call(
        "https://x.com/FabrizioRomano/status/2092160046985543990", "アーセナルが合意", ledger
    )
    assert call.handle == "FabrizioRomano"
    assert call.at.year == 2026
    (stored,) = load_calls(ledger)
    assert stored.said == "アーセナルが合意"
    assert stored.outcome == "未判明"      # 判定は後で人が書く


def test_the_same_post_is_not_recorded_twice(tmp_path):
    from src.xposts import load_calls, record_call

    ledger = tmp_path / "r.yaml"
    url = "https://x.com/FabrizioRomano/status/2092160046985543990"
    record_call(url, "一回目", ledger)
    record_call(url, "二回目", ledger)
    assert len(load_calls(ledger)) == 1


def test_outcomes_are_tallied_per_account():
    from src.xposts import hit_rate

    calls = [_call("A", "的中"), _call("A", "外れ"), _call("A"), _call("B", "的中")]
    assert hit_rate(calls) == {"A": (1, 1, 1), "B": (1, 0, 0)}


def test_nothing_is_said_until_enough_have_been_judged():
    from src.xposts import review_accounts

    calls = [_call("A", "外れ") for _ in range(4)]
    assert review_accounts(calls, [{"handle": "A"}]) == []


def test_a_poor_hit_rate_is_reported():
    from src.xposts import review_accounts

    calls = [_call("A", "外れ") for _ in range(5)] + [_call("A", "的中")]
    notes = review_accounts(calls, [{"handle": "A"}])
    assert any("半分を切っています" in note for note in notes)


def test_a_good_hit_rate_says_nothing():
    from src.xposts import review_accounts

    calls = [_call("A", "的中") for _ in range(5)] + [_call("A", "外れ")]
    assert review_accounts(calls, [{"handle": "A"}]) == []


def test_an_unregistered_account_being_followed_is_reported():
    from src.xposts import review_accounts

    calls = [_call("Unknown", "的中") for _ in range(5)]
    notes = review_accounts(calls, [{"handle": "A"}])
    assert any("accounts に無い" in note for note in notes)


def test_a_missing_ledger_reads_as_empty(tmp_path):
    from src.xposts import load_calls

    assert load_calls(tmp_path / "none.yaml") == []

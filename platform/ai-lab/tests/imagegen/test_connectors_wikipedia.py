"""Wikipedia の記事検索。"""

import pytest
from fakes import FakeResponse, FakeSession

from imagegen.connectors.feed_wikipedia import WikipediaFeed, api_url, split_lang
from imagegen.core.errors import ConfigError

BODY = {
    "query": {
        "pages": {
            "9999": {
                "pageid": 9999,
                "index": 2,
                "title": "リオネル・メッシ",
                "fullurl": "https://ja.wikipedia.org/wiki/リオネル・メッシ",
                "touched": "2026-08-30T00:00:00Z",
                "extract": "リオネル・アンドレス・メッシは、\n\nアルゼンチンの\t サッカー選手。",
            },
            "1111": {
                "pageid": 1111,
                "index": 1,
                "title": "FCバルセロナ",
                "fullurl": "https://ja.wikipedia.org/wiki/FCバルセロナ",
                "extract": "スペインのサッカークラブ。",
            },
        }
    }
}


def test_returns_title_url_and_summary():
    sess = FakeSession([FakeResponse(json_data=BODY)])

    items = WikipediaFeed(session=sess).fetch_items("メッシ", limit=5)

    messi = next(item for item in items if item.title == "リオネル・メッシ")
    assert messi.source == "wikipedia"
    assert messi.url.endswith("リオネル・メッシ")
    assert messi.summary == "リオネル・アンドレス・メッシは、 アルゼンチンの サッカー選手。"  # 空白を整える
    assert messi.meta["pageid"] == 9999


def test_results_keep_the_search_order():
    """APIは辞書で返すので順序が失われる。index で並べ直す。"""
    sess = FakeSession([FakeResponse(json_data=BODY)])
    items = WikipediaFeed(session=sess).fetch_items("メッシ")
    assert [item.title for item in items] == ["FCバルセロナ", "リオネル・メッシ"]


def test_query_goes_to_the_japanese_api_by_default():
    sess = FakeSession([FakeResponse(json_data=BODY)])
    WikipediaFeed(session=sess).fetch_items("メッシ", limit=3)

    _method, url, kwargs = sess.calls[0]
    assert url == api_url("ja")
    assert kwargs["params"]["gsrsearch"] == "メッシ"
    assert kwargs["params"]["gsrlimit"] == 3
    assert kwargs["params"]["exintro"] == 1  # 導入部だけ取る


def test_language_can_be_given_as_a_prefix():
    sess = FakeSession([FakeResponse(json_data={"query": {"pages": {}}})])
    WikipediaFeed(session=sess).fetch_items("en:Lionel Messi")

    assert sess.calls[0][1] == api_url("en")
    assert sess.calls[0][2]["params"]["gsrsearch"] == "Lionel Messi"


def test_default_language_is_configurable(monkeypatch):
    monkeypatch.setenv("IMAGEGEN_WIKIPEDIA_LANG", "en")
    assert split_lang("Messi") == ("en", "Messi")
    assert split_lang("fr:Messi") == ("fr", "Messi")  # 前置きが優先


def test_a_colon_in_the_query_is_not_a_language():
    assert split_lang("2026年:出来事")[0] == "ja"


def test_empty_query_is_rejected():
    with pytest.raises(ConfigError, match="キーワード"):
        WikipediaFeed().fetch_items("en:")


def test_no_results_is_not_an_error():
    sess = FakeSession([FakeResponse(json_data={"batchcomplete": ""})])
    assert WikipediaFeed(session=sess).fetch_items("存在しない見出し") == []


def test_check_reports_the_default_language():
    sess = FakeSession([FakeResponse(json_data={"query": {}})])
    result = WikipediaFeed(session=sess).check()
    assert result.ok and "ja" in result.detail


def test_needs_no_api_key():
    assert WikipediaFeed().is_available()

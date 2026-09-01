from dataclasses import dataclass

import pytest
import requests

from src.xapi import Client, XApiError, to_posts

PAYLOAD = {
    "data": [
        {
            "id": "2092160046985543990",
            "author_id": "11",
            "text": "So far, Julian only wanted Barcelona and nothing has changed.",
            "created_at": "2026-08-25T08:00:00.000Z",
        },
        {
            "id": "2093261309949206660",
            "author_id": "22",
            "text": "Arsenal remain ready to move.",
            "created_at": "2026-08-28T08:56:00.000Z",
        },
    ],
    "includes": {
        "users": [
            {"id": "11", "username": "FabrizioRomano", "name": "Fabrizio Romano"},
            {"id": "22", "username": "David_Ornstein", "name": "David Ornstein"},
        ]
    },
}


@dataclass
class FakeResponse:
    status_code: int = 200
    payload: dict | None = None
    text: str = ""

    def json(self):
        if self.payload is None:
            raise ValueError("no json")
        return self.payload


class FakeSession:
    """通信せずにクライアントを試すための差し替え。"""

    def __init__(self, response=None, error=None):
        self.response = response or FakeResponse(payload=PAYLOAD)
        self.error = error
        self.calls = []

    def get(self, url, params=None, headers=None, timeout=None):
        self.calls.append({"url": url, "params": params, "headers": headers})
        if self.error:
            raise self.error
        return self.response


def _client(session):
    return Client(token="test-token", session=session)


def test_posts_come_back_newest_first_with_full_text():
    posts = to_posts(PAYLOAD)
    assert [p.handle for p in posts] == ["David_Ornstein", "FabrizioRomano"]
    assert posts[1].text.endswith("nothing has changed.")
    assert posts[1].truncated is False   # APIは本文を切らない
    assert posts[1].url == "https://x.com/FabrizioRomano/status/2092160046985543990"


def test_missing_author_details_do_not_crash():
    posts = to_posts({"data": [{"id": "1", "author_id": "99", "text": "hi"}], "includes": {}})
    assert posts[0].handle == ""
    assert posts[0].posted_at is None


def test_an_empty_payload_gives_an_empty_list():
    assert to_posts({}) == []


def test_the_token_is_sent_as_a_bearer_header():
    session = FakeSession()
    _client(session).search_recent("Alvarez")
    assert session.calls[0]["headers"]["Authorization"] == "Bearer test-token"


def test_searching_by_account_limits_the_authors():
    session = FakeSession()
    _client(session).by_accounts(["FabrizioRomano", "@David_Ornstein"], "Alvarez")
    query = session.calls[0]["params"]["query"]
    assert "from:FabrizioRomano" in query
    assert "from:David_Ornstein" in query   # @ は落とす
    assert "-is:retweet" in query
    assert query.endswith("Alvarez")


def test_searching_by_account_needs_at_least_one_handle():
    with pytest.raises(XApiError, match="アカウント"):
        _client(FakeSession()).by_accounts([" ", ""])


def test_max_results_is_kept_inside_the_api_range():
    session = FakeSession()
    _client(session).search_recent("q", max_results=500)
    assert session.calls[0]["params"]["max_results"] == 100
    _client(session).search_recent("q", max_results=1)
    assert session.calls[1]["params"]["max_results"] == 10


def test_a_missing_token_says_which_variable_to_set(monkeypatch):
    monkeypatch.delenv("X_BEARER_TOKEN", raising=False)
    with pytest.raises(XApiError, match="X_BEARER_TOKEN"):
        Client.from_env()


def test_the_token_is_read_from_the_environment(monkeypatch):
    monkeypatch.setenv("X_BEARER_TOKEN", "  from-env  ")
    assert Client.from_env().token == "from-env"


@pytest.mark.parametrize(
    "status, expected",
    [
        (401, "認証"),
        (403, "プラン"),
        (429, "レート制限"),
        (500, "500"),
    ],
)
def test_http_errors_are_explained(status, expected):
    session = FakeSession(FakeResponse(status_code=status, text="detail"))
    with pytest.raises(XApiError, match=expected):
        _client(session).search_recent("q")


def test_a_network_failure_is_reported_as_such():
    session = FakeSession(error=requests.ConnectionError("boom"))
    with pytest.raises(XApiError, match="接続できません"):
        _client(session).search_recent("q")


def test_a_broken_body_is_reported_as_such():
    session = FakeSession(FakeResponse(status_code=200, payload=None))
    with pytest.raises(XApiError, match="読めません"):
        _client(session).search_recent("q")

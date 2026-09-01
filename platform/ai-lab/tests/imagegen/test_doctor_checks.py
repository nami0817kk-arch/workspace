"""各コネクタの疎通確認（imagegen doctor が呼ぶところ）。"""

import pytest
from fakes import FakeResponse, FakeSession

from imagegen.core import registry

# (コネクタ名, 必要な環境変数, 応答, 期待する detail の一部)
CASES = [
    ("openai", {"OPENAI_API_KEY": "sk"}, FakeResponse(json_data={"data": []}), "有効"),
    ("gemini", {"GEMINI_API_KEY": "g"}, FakeResponse(json_data={"models": [1, 2]}), "2"),
    ("stability", {"STABILITY_API_KEY": "s"}, FakeResponse(json_data={"email": "a@b.c"}), "a@b.c"),
    ("replicate", {"REPLICATE_API_TOKEN": "r"}, FakeResponse(json_data={"username": "taro"}), "taro"),
    ("huggingface", {"HF_TOKEN": "h"}, FakeResponse(json_data={"name": "taro"}), "taro"),
    ("pixabay", {"PIXABAY_API_KEY": "p"}, FakeResponse(json_data={"total": 7}), "7"),
    ("openverse", {}, FakeResponse(json_data={"result_count": 3}), "3"),
    ("wikimedia", {}, FakeResponse(json_data={"query": {}}), "検索可能"),
    ("iconify", {}, FakeResponse(json_data={"icons": ["mdi:home"]}), "1"),
    ("qiita", {}, FakeResponse(json_data=[{"title": "x"}]), "検索可能"),
    ("unsplash", {"UNSPLASH_ACCESS_KEY": "u"}, FakeResponse(json_data={"total": 12}), "12"),
    ("pexels", {"PEXELS_API_KEY": "p"}, FakeResponse(json_data={"total_results": 5}), "5"),
]


@pytest.mark.parametrize(("name", "env", "response", "expected"), CASES)
def test_check_reports_success(name, env, response, expected, monkeypatch):
    for key, value in env.items():
        monkeypatch.setenv(key, value)
    connector = registry.get(name, session=FakeSession([response]))

    result = connector.check()

    assert result.ok and not result.skipped
    assert expected in result.detail


@pytest.mark.parametrize(
    "name", ["openai", "gemini", "stability", "replicate", "huggingface", "pixabay", "unsplash", "pexels"]
)
def test_check_is_skipped_without_keys(name):
    """キーが無いものは未確認扱いにする（失敗とは区別する）。"""
    result = registry.get(name, session=FakeSession()).check()
    assert result.skipped and not result.ok
    assert result.detail


def test_check_failure_surfaces_the_error(monkeypatch):
    from imagegen.core import http
    from imagegen.core.errors import AuthError

    monkeypatch.setenv("OPENAI_API_KEY", "sk-bad")
    monkeypatch.setattr(http.time, "sleep", lambda _seconds: None)
    connector = registry.get("openai", session=FakeSession([FakeResponse(status_code=401)]))

    with pytest.raises(AuthError):
        connector.check()

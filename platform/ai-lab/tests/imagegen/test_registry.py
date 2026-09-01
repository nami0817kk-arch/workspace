"""登録簿とコネクタ共通契約の検証（コネクタ追加時の抜けを防ぐ契約テスト）。"""

import pytest

from imagegen.core import registry
from imagegen.core.connector import AuthSpec, Connector, capabilities_of
from imagegen.core.errors import ConfigError

ALL_NAMES = registry.names()


def test_expected_connectors_are_registered():
    expected = {
        "openai", "gemini", "stability", "replicate", "huggingface", "local",
        "iconify", "openverse", "pixabay", "wikimedia", "unsplash", "pexels",
        "github", "rss", "qiita",
        "voicevox", "openai_tts", "elevenlabs", "beep",
        "edinet", "estat",
    }
    assert expected <= set(ALL_NAMES)


def test_github_serves_two_capabilities():
    """1つのコネクタが複数の能力を持てる（プロトコルで判定しているため）。"""
    assert set(capabilities_of(registry.get("github"))) == {"publish", "fetch_items"}


@pytest.mark.parametrize("name", ALL_NAMES)
def test_every_connector_satisfies_the_contract(name):
    connector = registry.get(name)
    assert isinstance(connector, Connector)
    assert connector.category in {"images", "assets", "speech", "publish", "feed", "misc"}
    assert connector.summary, f"{name}: summary が空"
    assert isinstance(connector.auth, AuthSpec)
    assert isinstance(connector.is_available(), bool)  # 例外を投げない
    assert isinstance(connector.unavailable_reason(), str)
    if connector.auth.env:
        assert connector.auth.signup_url, f"{name}: キーの取得先URLが無い"


@pytest.mark.parametrize("name", ALL_NAMES)
def test_every_connector_has_at_least_one_capability(name):
    assert capabilities_of(registry.get(name)), f"{name}: どの能力も実装していない"


def test_connectors_are_ordered_by_priority():
    priorities = [c.priority for c in registry.by_capability("generate")]
    assert priorities == sorted(priorities)
    assert registry.by_capability("generate")[-1].name == "local"  # 最後の砦


def test_speech_connectors_are_ordered_by_priority():
    speech = registry.by_capability("synthesize")
    assert [c.priority for c in speech] == sorted(c.priority for c in speech)
    assert speech[-1].name == "beep"  # キーもENGINEも無いときの最後の砦


def test_by_capability_filters_by_availability(monkeypatch):
    monkeypatch.setenv("OPENAI_API_KEY", "sk-test")
    available = [c.name for c in registry.by_capability("generate", available_only=True)]
    assert available[0] == "openai"  # 優先順位どおり先頭
    assert "local" in available


def test_by_capability_rejects_unknown_capability():
    with pytest.raises(ConfigError):
        registry.by_capability("teleport")


def test_get_rejects_unknown_connector():
    with pytest.raises(ConfigError, match="未知のコネクタ"):
        registry.get("irasutoya")


def test_register_rejects_duplicate_name():
    class Duplicate(Connector):
        name = "openverse"

    with pytest.raises(ConfigError, match="重複"):
        registry.register(Duplicate)


def test_register_rejects_missing_name():
    class Nameless(Connector):
        pass

    with pytest.raises(ConfigError, match="name が設定されていません"):
        registry.register(Nameless)


def test_auth_spec_any_of_needs_only_one(monkeypatch):
    spec = AuthSpec(env=("A_KEY", "B_KEY"), any_of=True)
    assert spec.missing() == ["A_KEY", "B_KEY"]
    monkeypatch.setenv("B_KEY", "value")
    assert spec.is_satisfied()


def test_auth_spec_requires_all_by_default(monkeypatch):
    spec = AuthSpec(env=("A_KEY", "B_KEY"))
    monkeypatch.setenv("A_KEY", "value")
    assert spec.missing() == ["B_KEY"]


# --- レート制限の共有 ---------------------------------------------------
def test_rate_limiter_is_shared_between_instances():
    """registry.get() は毎回新しいインスタンスを作るので、枠は名前で共有する。"""
    first = registry.get("pollinations")
    second = registry.get("pollinations")
    assert first is not second
    assert first.limiter is second.limiter


def test_rate_limiters_are_separate_per_connector():
    assert registry.get("pollinations").limiter is not registry.get("unsplash").limiter


def test_shared_limiter_actually_consumes_the_quota():
    from imagegen.core.errors import RateLimitError

    registry.get("pollinations").limiter.wait()  # 1回目で枠を使い切る（1回/15秒）
    limiter = registry.get("pollinations").limiter
    limiter.max_wait = 0  # 待たずに失敗させて、枠が持ち越されていることを確かめる
    with pytest.raises(RateLimitError):
        limiter.wait()


def test_connector_without_rate_limit_has_no_limiter():
    assert registry.get("local").limiter is None

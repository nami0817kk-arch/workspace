"""登録簿とコネクタ共通契約の検証（コネクタ追加時の抜けを防ぐ契約テスト）。"""

import pytest

from ailab.core import registry
from ailab.core.connector import AuthSpec, Connector, GenerateImage, PublishFile, SearchAssets
from ailab.core.errors import ConfigError

ALL_NAMES = registry.names()


def test_expected_connectors_are_registered():
    assert {"openai", "gemini", "stability", "local", "openverse", "pixabay", "wikimedia", "github"} <= set(
        ALL_NAMES
    )


@pytest.mark.parametrize("name", ALL_NAMES)
def test_every_connector_satisfies_the_contract(name):
    connector = registry.get(name)
    assert isinstance(connector, Connector)
    assert connector.category in {"images", "assets", "publish", "feed", "misc"}
    assert connector.summary, f"{name}: summary が空"
    assert isinstance(connector.auth, AuthSpec)
    assert isinstance(connector.is_available(), bool)  # 例外を投げない
    assert isinstance(connector.unavailable_reason(), str)
    if connector.auth.env:
        assert connector.auth.signup_url, f"{name}: キーの取得先URLが無い"


@pytest.mark.parametrize("name", ALL_NAMES)
def test_every_connector_has_at_least_one_capability(name):
    connector = registry.get(name)
    assert isinstance(connector, (SearchAssets, GenerateImage, PublishFile))


def test_connectors_are_ordered_by_priority():
    priorities = [c.priority for c in registry.by_capability("generate")]
    assert priorities == sorted(priorities)
    assert registry.by_capability("generate")[-1].name == "local"  # 最後の砦


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

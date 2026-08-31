"""後方互換シム。

構成を変えても `ailab.illust` / `ailab.imagegen` の呼び方が壊れていないことを守る。
"""

import pytest

from ailab import illust, imagegen
from ailab.core.errors import ConfigError, ConnectorError


def test_illust_search_still_searches(monkeypatch):
    """illust.search は import 時に assets.search を束縛しているので、
    差し替えではなくコネクタ側を止めて確認する。"""
    from ailab.connectors.assets_iconify import IconifyAssets
    from ailab.connectors.assets_openverse import OpenverseAssets
    from ailab.connectors.assets_wikimedia import WikimediaAssets
    from ailab.core.types import Asset

    monkeypatch.setattr(
        OpenverseAssets, "search_assets", lambda self, q, **kw: [Asset("openverse", q, "https://x/1")]
    )
    for cls in (IconifyAssets, WikimediaAssets):
        monkeypatch.setattr(cls, "search_assets", lambda self, q, **kw: [])

    assert illust.search("猫")[0].title == "猫"


def test_illust_item_is_the_asset_type():
    from ailab.core.types import Asset

    assert illust.IllustItem is Asset
    item = illust.IllustItem(source="openverse", title="Cat", image_url="u", license="CC0")
    assert item.attribution == '"Cat" [CC0]'


def test_source_error_still_catches_connector_errors():
    with pytest.raises(illust.SourceError):
        raise ConnectorError("落ちた")


def test_available_sources_lists_search_connectors():
    names = [name for name, _ok, _reason in illust.available_sources()]
    assert {"iconify", "openverse", "wikimedia"} <= set(names)


def test_get_source_returns_a_connector():
    assert illust.get_source("openverse").name == "openverse"


def test_get_source_rejects_a_connector_without_search():
    with pytest.raises(ConnectorError, match="素材検索に対応していません"):
        illust.get_source("github")


def test_download_helpers_are_re_exported(tmp_path):
    from ailab import assets

    assert illust.download is assets.download
    assert illust.download_all is assets.download_all
    assert illust.write_credits is assets.write_credits


def test_imagegen_generate_still_works(tmp_path, monkeypatch):
    monkeypatch.setenv("AILAB_OUTPUT_DIR", str(tmp_path))
    images = imagegen.generate("互換テスト", provider="local", size="64x64")
    assert images[0].provider == "local"


def test_imagegen_provider_error_is_the_connector_error():
    assert imagegen.ProviderError is ConnectorError


def test_get_provider_rejects_a_connector_without_generate():
    with pytest.raises(ConnectorError, match="画像生成に対応していません"):
        imagegen.get_provider("openverse")


def test_get_provider_rejects_an_unknown_name():
    with pytest.raises(ConfigError, match="未知のコネクタ"):
        imagegen.get_provider("dall-e-9")


def test_auto_provider_prefers_a_configured_one(monkeypatch):
    monkeypatch.setenv("OPENAI_API_KEY", "sk-test")
    assert imagegen.auto_provider().name == "openai"


def test_available_providers_reports_reasons():
    rows = dict((name, reason) for name, _ok, reason in imagegen.available_providers())
    assert "OPENAI_API_KEY" in rows["openai"]
    assert rows["local"] == ""

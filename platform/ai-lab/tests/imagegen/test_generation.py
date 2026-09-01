"""画像生成の入口（generation.generate）。

CLI・レシピ・MCP はすべてここを通るので、コネクタの選び方と
選べなかったときのエラーをここで押さえる。
"""

import pytest

from imagegen import generation
from imagegen.core.errors import ConfigError, ConnectorError


def test_generate_returns_an_image_from_the_named_provider(tmp_path, monkeypatch):
    monkeypatch.setenv("IMAGEGEN_OUTPUT_DIR", str(tmp_path))
    images = generation.generate("生成テスト", provider="local", size="64x64")
    assert images[0].provider == "local"


def test_get_provider_rejects_a_connector_without_generate():
    with pytest.raises(ConnectorError, match="画像生成に対応していません"):
        generation.get_provider("openverse")


def test_get_provider_rejects_an_unknown_name():
    with pytest.raises(ConfigError, match="未知のコネクタ"):
        generation.get_provider("dall-e-9")


def test_auto_provider_prefers_a_configured_one(monkeypatch):
    monkeypatch.setenv("OPENAI_API_KEY", "sk-test")
    assert generation.auto_provider().name == "openai"


def test_available_providers_reports_reasons():
    rows = dict((name, reason) for name, _ok, reason in generation.available_providers())
    assert "OPENAI_API_KEY" in rows["openai"]
    assert rows["local"] == ""

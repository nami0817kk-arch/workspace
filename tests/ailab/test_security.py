"""秘密情報の扱いと、エージェント経由の操作の制限。"""

import json

import pytest
from fakes import FakeResponse, FakeSession

from ailab import cli, mcp_server, usage
from ailab.core import http
from ailab.core.errors import AilabError
from ailab.core.redact import redact, secret_values
from ailab.core.types import GeneratedImage

SECRET = "sk-verysecretvalue1234"


# --- キーを表示しない ---------------------------------------------------
def test_secret_values_are_collected_from_the_environment(monkeypatch):
    monkeypatch.setenv("SOMETHING_API_KEY", SECRET)
    monkeypatch.setenv("PLAIN_SETTING", "not-a-secret")
    values = secret_values()
    assert SECRET in values
    assert "not-a-secret" not in values


def test_short_values_are_not_masked(monkeypatch):
    """短い値まで伏せると、無関係な文字列まで壊れる。"""
    monkeypatch.setenv("TINY_TOKEN", "abc")
    assert redact("abc def") == "abc def"


def test_api_key_in_an_error_body_is_masked(monkeypatch):
    """Pixabay などはクエリ文字列に鍵を載せるので、エラー文に混ざりうる。"""
    monkeypatch.setenv("PIXABAY_API_KEY", SECRET)
    response = FakeResponse(
        status_code=400, json_data={"message": f"invalid key at ?key={SECRET}&q=cat"}
    )
    detail = http.error_detail(response)
    assert SECRET not in detail
    assert "***" in detail


def test_connection_error_does_not_leak_the_key(monkeypatch):
    import requests

    monkeypatch.setenv("PIXABAY_API_KEY", SECRET)
    monkeypatch.setattr(http.time, "sleep", lambda _seconds: None)

    class Broken(FakeSession):
        def request(self, method, url, **kwargs):
            raise requests.ConnectionError(f"failed for url: {url}?key={SECRET}")

    with pytest.raises(AilabError) as caught:
        http.request("GET", "https://pixabay.com/api/", sess=Broken(), label="pixabay")
    assert SECRET not in str(caught.value)


def test_connectors_json_lists_variable_names_not_values(monkeypatch, capsys):
    monkeypatch.setenv("OPENAI_API_KEY", SECRET)
    cli.main(["connectors", "--json"])
    out = capsys.readouterr().out
    assert SECRET not in out
    assert "OPENAI_API_KEY" in out  # 名前は出す（何を設定すべきか分かるように）


def test_doctor_output_has_no_secrets(monkeypatch, capsys):
    monkeypatch.setenv("OPENAI_API_KEY", SECRET)
    cli.main(["doctor", "local"])
    assert SECRET not in capsys.readouterr().out


# --- 記録に残すもの -----------------------------------------------------
def test_prompt_recording_can_be_disabled(tmp_path, monkeypatch):
    log = tmp_path / "usage.jsonl"
    monkeypatch.setenv("AILAB_USAGE_PROMPTS", "0")
    usage.record([GeneratedImage(data=b"x", provider="local", model="m", prompt="社外秘の企画")], path=log)

    entry = usage.load(log)[0]
    assert entry["prompt"] == ""
    assert entry["provider"] == "local"  # 集計に必要なものは残る


def test_prompts_are_recorded_by_default(tmp_path):
    log = tmp_path / "usage.jsonl"
    usage.record([GeneratedImage(data=b"x", provider="local", model="m", prompt="猫")], path=log)
    assert usage.load(log)[0]["prompt"] == "猫"


# --- MCP から送れる範囲 -------------------------------------------------
def test_mcp_refuses_to_publish_outside_the_project(tmp_path):
    """会話の流れで無関係なファイルを外部へ送らせない。"""
    outside = tmp_path / "secret.txt"
    outside.write_text("社外秘", encoding="utf-8")

    result = mcp_server.call_tool("publish_file", {"file": str(outside), "repo": "owner/name"})

    assert result["isError"] is True
    assert "プロジェクトの外" in result["content"][0]["text"]


def test_mcp_allows_files_in_the_project(monkeypatch):
    from ailab.connectors.github import GitHubConnector
    from ailab.core.types import PublishResult

    monkeypatch.setattr(
        GitHubConnector,
        "publish",
        lambda self, path, *, dry_run=True, **options: PublishResult(
            target="github", detail="予定", dry_run=dry_run
        ),
    )
    result = mcp_server.call_tool("publish_file", {"file": "README.md", "repo": "owner/name"})
    assert result["isError"] is False


def test_mcp_tool_definitions_do_not_leak_secrets(monkeypatch):
    monkeypatch.setenv("OPENAI_API_KEY", SECRET)
    assert SECRET not in json.dumps(mcp_server.tool_definitions(), ensure_ascii=False)

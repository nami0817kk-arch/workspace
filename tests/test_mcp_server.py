"""MCP サーバ（stdio / JSON-RPC）。"""

import io
import json
from pathlib import Path

import pytest

from ailab import mcp_server
from ailab.core.types import PublishResult


@pytest.fixture
def output_file():
    """MCP から送れるのはプロジェクト配下のファイルだけなので、出力先に置く。"""
    from ailab.config import output_dir

    path = Path(output_dir()) / "a.png"
    path.write_bytes(b"x")
    return path


def call(method: str, params: dict | None = None, message_id=1):
    return mcp_server.handle(
        {"jsonrpc": "2.0", "id": message_id, "method": method, "params": params or {}}
    )


# --- プロトコル -------------------------------------------------------
def test_initialize_returns_server_info():
    result = call("initialize", {"protocolVersion": "2025-06-18"})["result"]
    assert result["serverInfo"]["name"] == "ailab"
    assert result["capabilities"]["tools"] == {"listChanged": False}


def test_initialize_echoes_the_clients_protocol_version():
    assert call("initialize", {"protocolVersion": "2024-11-05"})["result"]["protocolVersion"] == (
        "2024-11-05"
    )


def test_initialize_falls_back_to_our_version():
    assert call("initialize", {})["result"]["protocolVersion"] == mcp_server.PROTOCOL_VERSION


def test_notifications_get_no_response():
    assert mcp_server.handle({"jsonrpc": "2.0", "method": "notifications/initialized"}) is None


def test_ping_is_answered():
    assert call("ping")["result"] == {}


def test_unknown_method_is_a_jsonrpc_error():
    error = call("resources/list")["error"]
    assert error["code"] == mcp_server.METHOD_NOT_FOUND


def test_tools_call_without_a_name_is_invalid_params():
    assert call("tools/call", {})["error"]["code"] == mcp_server.INVALID_PARAMS


# --- ツール定義 -------------------------------------------------------
def test_tools_list_exposes_every_tool():
    tools = call("tools/list")["result"]["tools"]
    assert {tool["name"] for tool in tools} == set(mcp_server.TOOLS)
    assert all(tool["description"] and tool["inputSchema"] for tool in tools)


def test_tool_choices_come_from_the_registry():
    tools = {tool["name"]: tool for tool in call("tools/list")["result"]["tools"]}
    providers = tools["generate_image"]["inputSchema"]["properties"]["provider"]["enum"]
    assert providers[0] == "auto" and "local" in providers
    assert "github" in tools["fetch_feed"]["inputSchema"]["properties"]["source"]["enum"]


# --- ツール実行 -------------------------------------------------------
def test_generate_image_saves_a_file(tmp_path):
    result = mcp_server.call_tool(
        "generate_image",
        {"prompt": "MCPのテスト", "provider": "local", "size": "64x64", "out": str(tmp_path)},
    )
    assert result["isError"] is False
    assert len(list(tmp_path.glob("*.png"))) == 1
    assert "プレースホルダ" in result["content"][0]["text"]  # local だと注記が付く


def test_generate_image_requires_a_prompt():
    result = mcp_server.call_tool("generate_image", {})
    assert result["isError"] is True
    assert "prompt" in result["content"][0]["text"]


def test_unknown_tool_is_an_error():
    result = mcp_server.call_tool("teleport", {})
    assert result["isError"] is True


def test_list_connectors_reports_capabilities():
    text = mcp_server.call_tool("list_connectors", {})["content"][0]["text"]
    assert "local" in text and "publish/fetch_items" in text  # github は2つの能力を持つ


def test_search_assets_formats_results(monkeypatch):
    from ailab import assets
    from ailab.core.types import Asset

    monkeypatch.setattr(
        assets,
        "search",
        lambda *a, **kw: [
            Asset(source="iconify", title="cat", image_url="https://x/c.svg", license="MIT")
        ],
    )
    text = mcp_server.call_tool("search_assets", {"query": "cat"})["content"][0]["text"]
    assert "ライセンス: MIT" in text


def test_fetch_feed_uses_the_named_source(monkeypatch):
    from ailab.connectors.feed_qiita import QiitaFeed
    from ailab.core.types import FeedItem

    monkeypatch.setattr(
        QiitaFeed, "fetch_items", lambda self, q, **kw: [FeedItem(source="qiita", title=q, url="u")]
    )
    text = mcp_server.call_tool("fetch_feed", {"query": "claude", "source": "qiita"})["content"][0]["text"]
    assert "claude" in text


def test_fetch_feed_requires_a_source():
    assert mcp_server.call_tool("fetch_feed", {"query": "x"})["isError"] is True


def test_publish_is_dry_run_unless_confirmed(monkeypatch, output_file):
    from ailab.connectors.github import GitHubConnector

    seen = {}

    def fake_publish(self, path, *, dry_run=True, **options):
        seen["dry_run"] = dry_run
        return PublishResult(target="github:owner/name", detail="コミット予定", dry_run=dry_run)

    monkeypatch.setattr(GitHubConnector, "publish", fake_publish)

    text = mcp_server.call_tool(
        "publish_file", {"file": str(output_file), "repo": "owner/name"}
    )["content"][0]["text"]

    assert seen["dry_run"] is True
    assert "confirm" in text


def test_publish_sends_when_confirmed(monkeypatch, output_file):
    from ailab.connectors.github import GitHubConnector

    seen = {}

    def fake_publish(self, path, *, dry_run=True, **options):
        seen.update({"dry_run": dry_run, **options})
        return PublishResult(target="github", url="https://github.com/x/y")

    monkeypatch.setattr(GitHubConnector, "publish", fake_publish)

    mcp_server.call_tool(
        "publish_file",
        {"file": str(output_file), "repo": "owner/name", "dest": "docs/a.png", "confirm": True},
    )

    assert seen["dry_run"] is False
    assert seen["dest"] == "docs/a.png"


def test_run_recipe_reports_each_step(tmp_path):
    recipe = tmp_path / "r.yaml"
    recipe.write_text(
        "name: MCPレシピ\n"
        "steps:\n"
        "  - id: img\n"
        "    gen:\n"
        "      provider: local\n"
        "      prompt: 猫\n"
        "      size: 64x64\n"
        f"      out: {tmp_path}\n",
        encoding="utf-8",
    )
    text = mcp_server.call_tool("run_recipe", {"recipe": str(recipe)})["content"][0]["text"]
    assert "MCPレシピ" in text and "gen (img)" in text


# --- stdio ------------------------------------------------------------
def test_serve_answers_line_by_line():
    stdin = io.StringIO(
        json.dumps({"jsonrpc": "2.0", "id": 1, "method": "ping"})
        + "\n\n"  # 空行は読み飛ばす
        + json.dumps({"jsonrpc": "2.0", "method": "notifications/initialized"})
        + "\n"
        + json.dumps({"jsonrpc": "2.0", "id": 2, "method": "tools/list"})
        + "\n"
    )
    stdout = io.StringIO()

    assert mcp_server.serve(stdin, stdout) == 0

    responses = [json.loads(line) for line in stdout.getvalue().splitlines()]
    assert [r["id"] for r in responses] == [1, 2]  # 通知には応答しない


def test_serve_reports_broken_json():
    stdout = io.StringIO()
    mcp_server.serve(io.StringIO("{壊れている\n"), stdout)
    assert json.loads(stdout.getvalue())["error"]["code"] == mcp_server.PARSE_ERROR

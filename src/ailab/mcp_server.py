"""ailab を MCP サーバとして公開する（stdio / JSON-RPC 2.0）。

Claude から `ailab` の連携先を直接呼べるようにするためのもの。
標準出力は JSON-RPC 専用なので、ログや進捗は標準エラーへ出す。
"""

from __future__ import annotations

import json
import sys
from collections.abc import Callable
from typing import Any

from . import __version__, assets, imagegen, recipes
from .config import load_dotenv, output_dir
from .core import registry
from .core.connector import capabilities_of
from .core.errors import AilabError

PROTOCOL_VERSION = "2025-06-18"
SERVER_INFO = {"name": "ailab", "version": __version__}

# JSON-RPC のエラーコード
METHOD_NOT_FOUND = -32601
INVALID_PARAMS = -32602
PARSE_ERROR = -32700


def _sources(capability: str) -> list[str]:
    return [connector.name for connector in registry.by_capability(capability)]


def tool_definitions() -> list[dict]:
    """公開するツールの一覧。選択肢は登録簿から作るのでコネクタ追加に自動で追随する。"""
    return [
        {
            "name": "list_connectors",
            "description": "使える連携先と、APIキーが設定されているかを一覧する。",
            "inputSchema": {"type": "object", "properties": {}},
        },
        {
            "name": "generate_image",
            "description": (
                "プロンプトから画像を生成してファイルに保存し、保存先パスを返す。"
                "APIキーが無い場合は local（プレースホルダ画像）が使われる。"
            ),
            "inputSchema": {
                "type": "object",
                "properties": {
                    "prompt": {"type": "string", "description": "生成したい画像の説明"},
                    "provider": {
                        "type": "string",
                        "enum": ["auto", *_sources("generate")],
                        "description": "既定は auto（使えるものを優先順に選ぶ）",
                    },
                    "size": {"type": "string", "description": "例: 1024x1024"},
                    "n": {"type": "integer", "description": "生成枚数"},
                    "out": {"type": "string", "description": "保存先ディレクトリ"},
                },
                "required": ["prompt"],
            },
        },
        {
            "name": "search_assets",
            "description": "フリー素材（アイコン・イラスト・写真）を検索する。ダウンロードはしない。",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "query": {"type": "string"},
                    "source": {"type": "string", "enum": ["all", *_sources("search_assets")]},
                    "limit": {"type": "integer"},
                },
                "required": ["query"],
            },
        },
        {
            "name": "fetch_assets",
            "description": (
                "フリー素材を検索してダウンロードする。"
                "保存先に CREDITS.md（出典とライセンス）も書き出す。"
            ),
            "inputSchema": {
                "type": "object",
                "properties": {
                    "query": {"type": "string"},
                    "source": {"type": "string", "enum": ["all", *_sources("search_assets")]},
                    "limit": {"type": "integer"},
                    "out": {"type": "string"},
                },
                "required": ["query"],
            },
        },
        {
            "name": "fetch_feed",
            "description": (
                "記事やリリース情報を取得する。"
                "rss はフィードURL、github は owner/name、qiita はキーワードを query に渡す。"
            ),
            "inputSchema": {
                "type": "object",
                "properties": {
                    "query": {"type": "string"},
                    "source": {"type": "string", "enum": _sources("fetch_items")},
                    "limit": {"type": "integer"},
                },
                "required": ["query", "source"],
            },
        },
        {
            "name": "publish_file",
            "description": (
                "ファイルを外部サービスへ送る。既定はドライランで、"
                "confirm を true にしたときだけ実際に送信する。"
            ),
            "inputSchema": {
                "type": "object",
                "properties": {
                    "file": {"type": "string"},
                    "to": {"type": "string", "enum": _sources("publish")},
                    "repo": {"type": "string", "description": "github の場合 owner/name"},
                    "dest": {"type": "string", "description": "送信先でのパス"},
                    "branch": {"type": "string"},
                    "message": {"type": "string"},
                    "confirm": {"type": "boolean", "description": "true で実際に送信する"},
                },
                "required": ["file"],
            },
        },
        {
            "name": "run_recipe",
            "description": "レシピ（YAML）を実行する。publish は confirm を true にするまでドライラン。",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "recipe": {"type": "string", "description": "パス、または recipes/ 内の名前"},
                    "variables": {"type": "object", "description": "{{ vars.X }} の差し替え"},
                    "confirm": {"type": "boolean"},
                },
                "required": ["recipe"],
            },
        },
    ]


# --- 各ツール ---------------------------------------------------------
def _tool_list_connectors(_arguments: dict) -> str:
    lines = []
    for name in registry.names():
        connector = registry.get(name)
        mark = "OK" if connector.is_available() else "要設定"
        detail = connector.unavailable_reason() or connector.summary
        lines.append(f"[{mark}] {name} ({'/'.join(capabilities_of(connector))}): {detail}")
    return "\n".join(lines)


def _tool_generate_image(arguments: dict) -> str:
    provider = imagegen.get_provider(arguments.get("provider", "auto"))
    images = provider.generate(
        _required(arguments, "prompt"),
        size=arguments.get("size", "1024x1024"),
        n=int(arguments.get("n", 1)),
        model=arguments.get("model"),
    )
    destination = arguments.get("out") or output_dir("images")
    saved = [str(image.save(f"{destination}/{image.default_name(i)}")) for i, image in enumerate(images)]
    note = (
        "\n（local は生成AIではなくプロンプトから決まるプレースホルダ画像です）"
        if provider.name == "local"
        else ""
    )
    return f"{provider.name}/{images[0].model} で生成しました:\n" + "\n".join(saved) + note


def _tool_search_assets(arguments: dict) -> str:
    found = assets.search(
        _required(arguments, "query"),
        source=arguments.get("source", "all"),
        limit=int(arguments.get("limit", 5)),
    )
    if not found:
        return "見つかりませんでした"
    return "\n".join(
        f"[{index}] {asset.title} <{asset.source}> ライセンス: {asset.license}\n"
        f"    画像: {asset.image_url}\n    出典: {asset.page_url}"
        for index, asset in enumerate(found, 1)
    )


def _tool_fetch_assets(arguments: dict) -> str:
    limit = int(arguments.get("limit", 3))
    found = assets.search(
        _required(arguments, "query"), source=arguments.get("source", "all"), limit=limit
    )[:limit]
    if not found:
        return "見つかりませんでした"
    destination = arguments.get("out") or output_dir("illust")
    saved = assets.download_all(found, destination)
    lines = [f"{path}\n    出典: {asset.attribution}" for asset, path in saved]
    return "保存しました:\n" + "\n".join(lines) + f"\nクレジット: {destination}/CREDITS.md"


def _tool_fetch_feed(arguments: dict) -> str:
    connector = registry.get(_required(arguments, "source"))
    items = connector.fetch_items(_required(arguments, "query"), limit=int(arguments.get("limit", 5)))
    if not items:
        return "見つかりませんでした"
    return "\n".join(
        f"[{index}] {item.describe()}\n    {item.url}" for index, item in enumerate(items, 1)
    )


def _tool_publish_file(arguments: dict) -> str:
    connector = registry.get(arguments.get("to", "github"))
    options = {
        key: arguments[key]
        for key in ("repo", "dest", "branch", "message")
        if arguments.get(key) is not None
    }
    result = connector.publish(
        _required(arguments, "file"), dry_run=not bool(arguments.get("confirm")), **options
    )
    tail = "\n実際に送るには confirm を true にしてください。" if result.dry_run else ""
    return result.describe() + tail


def _tool_run_recipe(arguments: dict) -> str:
    recipe = recipes.load_recipe(_required(arguments, "recipe"))
    result = recipes.run(
        recipe,
        dry_run=not bool(arguments.get("confirm")),
        variables=arguments.get("variables") or {},
    )
    lines = [f"{step.verb} ({step.id}): {step.summary}" for step in result.steps]
    files = result.files()
    if files:
        lines.append("作られたファイル: " + ", ".join(files))
    return f"レシピ「{result.name}」を実行しました:\n" + "\n".join(lines)


TOOLS: dict[str, Callable[[dict], str]] = {
    "list_connectors": _tool_list_connectors,
    "generate_image": _tool_generate_image,
    "search_assets": _tool_search_assets,
    "fetch_assets": _tool_fetch_assets,
    "fetch_feed": _tool_fetch_feed,
    "publish_file": _tool_publish_file,
    "run_recipe": _tool_run_recipe,
}


def _required(arguments: dict, key: str) -> str:
    value = arguments.get(key)
    if value is None or (isinstance(value, str) and not value.strip()):
        raise AilabError(f"{key} を指定してください")
    return value


def call_tool(name: str, arguments: dict) -> dict:
    """ツールを呼び、MCP の結果オブジェクトを返す。"""
    handler = TOOLS.get(name)
    if handler is None:
        return _content(f"未知のツールです: {name}", is_error=True)
    try:
        return _content(handler(arguments or {}))
    except AilabError as exc:
        return _content(f"エラー: {exc}", is_error=True)
    except (ValueError, OSError) as exc:
        return _content(f"エラー: {exc}", is_error=True)


def _content(text: str, *, is_error: bool = False) -> dict:
    return {"content": [{"type": "text", "text": text}], "isError": is_error}


# --- JSON-RPC ---------------------------------------------------------
def handle(message: dict) -> dict | None:
    """1メッセージを処理する。通知（id なし）には応答しない。"""
    method = message.get("method", "")
    message_id = message.get("id")
    params = message.get("params") or {}

    if message_id is None:  # notifications/initialized など
        return None

    if method == "initialize":
        requested = params.get("protocolVersion")
        return _result(
            message_id,
            {
                "protocolVersion": requested if isinstance(requested, str) else PROTOCOL_VERSION,
                "capabilities": {"tools": {"listChanged": False}},
                "serverInfo": SERVER_INFO,
            },
        )
    if method == "ping":
        return _result(message_id, {})
    if method == "tools/list":
        return _result(message_id, {"tools": tool_definitions()})
    if method == "tools/call":
        name = params.get("name")
        if not name:
            return _error(message_id, INVALID_PARAMS, "ツール名がありません")
        return _result(message_id, call_tool(name, params.get("arguments") or {}))

    return _error(message_id, METHOD_NOT_FOUND, f"未対応のメソッドです: {method}")


def _result(message_id: Any, result: dict) -> dict:
    return {"jsonrpc": "2.0", "id": message_id, "result": result}


def _error(message_id: Any, code: int, message: str) -> dict:
    return {"jsonrpc": "2.0", "id": message_id, "error": {"code": code, "message": message}}


def serve(stdin=None, stdout=None) -> int:
    """stdio で待ち受ける。1行1メッセージ（MCP の stdio トランスポート）。"""
    load_dotenv()
    stdin = stdin or sys.stdin
    stdout = stdout or sys.stdout

    for line in stdin:
        line = line.strip()
        if not line:
            continue
        try:
            message = json.loads(line)
        except json.JSONDecodeError as exc:
            _write(stdout, _error(None, PARSE_ERROR, f"JSON を解釈できません: {exc}"))
            continue

        response = handle(message)
        if response is not None:
            _write(stdout, response)
    return 0


def _write(stdout, payload: dict) -> None:
    stdout.write(json.dumps(payload, ensure_ascii=False) + "\n")
    stdout.flush()

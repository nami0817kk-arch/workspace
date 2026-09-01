"""imagegen を MCP サーバとして公開する（stdio / JSON-RPC 2.0）。

Claude から `imagegen` の連携先を直接呼べるようにするためのもの。
標準出力は JSON-RPC 専用なので、ログや進捗は標準エラーへ出す。
"""

from __future__ import annotations

import json
import sys
from collections.abc import Callable
from pathlib import Path
from typing import Any

from . import __version__, assets, compose, generation, recipes, speech
from .config import load_dotenv, output_dir, project_root
from .core import registry
from .core.connector import capabilities_of
from .core.errors import ImagegenError
from .utils import ensure_utf8_streams

PROTOCOL_VERSION = "2025-06-18"
SERVER_INFO = {"name": "imagegen", "version": __version__}

# JSON-RPC のエラーコード
METHOD_NOT_FOUND = -32601
INVALID_PARAMS = -32602
PARSE_ERROR = -32700


def _sources(capability: str) -> list[str]:
    return [connector.name for connector in registry.by_capability(capability)]


def _styles() -> list[str]:
    from . import styles

    return styles.names()


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
                    "style": {
                        "type": "string",
                        "enum": _styles(),
                        "description": "絵柄のプリセット（flat / banner / icon など）",
                    },
                    "size": {"type": "string", "description": "例: 1024x1024"},
                    "n": {"type": "integer", "description": "生成枚数"},
                    "out": {"type": "string", "description": "保存先ディレクトリ"},
                },
                "required": ["prompt"],
            },
        },
        {
            "name": "compose_image",
            "description": (
                "画像に見出しを載せた1枚（サムネイル・OGP・共有画像）を作って保存する。"
                "背景を省くとベタ塗りになる。生成AIは使わないので待たされず、"
                "同じ指定からは常に同じ画像が出る。"
            ),
            "inputSchema": {
                "type": "object",
                "properties": {
                    "title": {"type": "string", "description": "大きく載せる見出し"},
                    "subtitle": {"type": "string", "description": "小さく載せる補足"},
                    "background": {"type": "string", "description": "背景に敷く画像のパス"},
                    "color": {"type": "string", "description": "背景色（例: #101828）"},
                    "preset": {"type": "string", "enum": sorted(compose.PRESETS)},
                    "size": {"type": "string", "description": "例: 1280x720（preset より優先）"},
                    "position": {"type": "string", "enum": list(compose.POSITIONS)},
                    "align": {"type": "string", "enum": list(compose.ALIGNS)},
                    "band": {"type": "boolean", "description": "文字の背後に帯を敷く"},
                    "stroke": {"type": "integer", "description": "袋文字の太さ（px）"},
                    "dim": {"type": "number", "description": "背景を暗くする 0〜1"},
                    "blur": {"type": "number", "description": "背景をぼかす"},
                    "out": {"type": "string", "description": "保存先ディレクトリ"},
                },
                "required": ["title"],
            },
        },
        {
            "name": "synthesize_speech",
            "description": (
                "文章を読み上げた音声を作ってファイルに保存し、保存先パスを返す。"
                "長文は自動で分割して合成し、WAV なら1本につなぎ直す。"
                "APIキーが無く VOICEVOX も起動していない場合は beep"
                "（尺だけ合わせたプレースホルダ音声）が使われる。"
            ),
            "inputSchema": {
                "type": "object",
                "properties": {
                    "text": {"type": "string", "description": "読み上げる文章"},
                    "provider": {
                        "type": "string",
                        "enum": ["auto", *_sources("synthesize")],
                        "description": "既定は auto（使えるものを優先順に選ぶ）",
                    },
                    "voice": {"type": "string", "description": "声の指定（list_voices で確認）"},
                    "model": {"type": "string"},
                    "speed": {"type": "number", "description": "読み上げ速度（既定 1.0）"},
                    "format": {"type": "string", "enum": ["wav", "mp3", "opus", "aac", "flac"]},
                    "out": {"type": "string", "description": "保存先ディレクトリ"},
                },
                "required": ["text"],
            },
        },
        {
            "name": "list_voices",
            "description": "音声合成で使える声の一覧を返す。",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "provider": {"type": "string", "enum": ["auto", *_sources("synthesize")]}
                },
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
            "name": "grab_image",
            "description": (
                "画像のURLを直接指定して取り込む。自分で見つけた画像を出典つきで"
                "手元に置くときに使う。ページのURLではなく画像そのもののURLを渡す。"
            ),
            "inputSchema": {
                "type": "object",
                "properties": {
                    "url": {"type": "string", "description": "画像そのもののURL"},
                    "page_url": {"type": "string", "description": "出典ページのURL"},
                    "license": {"type": "string", "description": "ライセンス表記"},
                    "creator": {"type": "string"},
                    "title": {"type": "string"},
                    "out": {"type": "string"},
                },
                "required": ["url"],
            },
        },
        {
            "name": "fetch_feed",
            "description": (
                "記事やリリース情報を取得する。"
                "rss はフィードURL、github は owner/name、qiita と estat はキーワード、"
                "edinet は日付(2026-09-01)か証券コード(7203)を query に渡す。"
                "edinet（金融庁の提出書類）と estat（政府統計）は官公庁の一次情報。"
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
    provider = generation.get_provider(arguments.get("provider", "auto"))
    images = generation.generate(
        _required(arguments, "prompt"),
        provider=provider.name,
        size=arguments.get("size", "1024x1024"),
        n=int(arguments.get("n", 1)),
        model=arguments.get("model"),
        style=arguments.get("style"),
    )
    destination = arguments.get("out") or output_dir("images")
    saved = [str(image.save(f"{destination}/{image.default_name(i)}")) for i, image in enumerate(images)]
    note = (
        "\n（local は生成AIではなくプロンプトから決まるプレースホルダ画像です）"
        if provider.name == "local"
        else ""
    )
    return f"{provider.name}/{images[0].model} で生成しました:\n" + "\n".join(saved) + note


def _tool_compose_image(arguments: dict) -> str:
    image = compose.compose(
        title=_required(arguments, "title"),
        subtitle=arguments.get("subtitle", ""),
        background=arguments.get("background"),
        color=arguments.get("color", "#101828"),
        size=arguments.get("size"),
        preset=arguments.get("preset", "youtube"),
        position=arguments.get("position", "bottom"),
        align=arguments.get("align", "center"),
        band=bool(arguments.get("band")),
        stroke=int(arguments.get("stroke", 0)),
        dim=float(arguments.get("dim", 0.0)),
        blur=float(arguments.get("blur", 0.0)),
    )
    destination = arguments.get("out") or output_dir("compose")
    path = image.save(f"{destination}/{image.default_name()}")
    return f"合成しました（{image.meta['size']}）:\n{path}"


def _tool_synthesize_speech(arguments: dict) -> str:
    provider = speech.get_provider(arguments.get("provider", "auto"))
    clips = speech.synthesize(
        _required(arguments, "text"),
        provider=provider.name,
        voice=arguments.get("voice"),
        model=arguments.get("model"),
        speed=float(arguments.get("speed", 1.0)),
        fmt=arguments.get("format"),
    )
    destination = arguments.get("out") or output_dir("speech")
    saved = speech.save_all(clips, destination)
    speech.write_credits(clips, destination)

    lines = []
    for path, clip in zip(saved, clips, strict=True):
        seconds = clip.seconds
        lines.append(f"{path}" + (f"（{seconds:.1f}秒）" if seconds is not None else ""))
    credits = sorted({clip.credit for clip in clips if clip.credit})
    tail = "\n表示が必要なクレジット: " + "、".join(credits) if credits else ""
    note = (
        "\n（beep は読み上げではなく、尺だけ合わせたプレースホルダ音声です）"
        if provider.name == "beep"
        else ""
    )
    return f"{provider.name}/{clips[0].model} で合成しました:\n" + "\n".join(lines) + tail + note


def _tool_list_voices(arguments: dict) -> str:
    connector = speech.get_provider(arguments.get("provider", "auto"))
    if not connector.is_available():
        return f"{connector.name}: {connector.unavailable_reason()}"
    found = connector.list_voices()
    if not found:
        return "使える声が見つかりませんでした"
    return f"{connector.name} で使える声:\n" + "\n".join(f"  {voice.describe()}" for voice in found)


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


def _tool_grab_image(arguments: dict) -> str:
    destination = arguments.get("out") or output_dir("illust")
    asset, path = assets.grab(
        _required(arguments, "url"),
        destination,
        page_url=arguments.get("page_url", ""),
        license=arguments.get("license", "unknown"),
        creator=arguments.get("creator", ""),
        title=arguments.get("title", ""),
    )
    warning = (
        "\nライセンスが未指定です。利用前に出典元の条件を確認してください。"
        if asset.license == "unknown"
        else ""
    )
    return f"保存しました: {path}\n出典: {asset.attribution}{warning}"


def _tool_fetch_feed(arguments: dict) -> str:
    connector = registry.get(_required(arguments, "source"))
    items = connector.fetch_items(_required(arguments, "query"), limit=int(arguments.get("limit", 5)))
    if not items:
        return "見つかりませんでした"
    return "\n".join(
        f"[{index}] {item.describe()}\n    {item.url}" for index, item in enumerate(items, 1)
    )


def _check_inside_project(file_path: str) -> str:
    """プロジェクト配下のファイルだけ送れるようにする。

    MCP のツールは会話の流れで呼ばれるので、取り込んだ文章に誘導されて
    無関係なファイルを外部へ送ってしまう余地を残さない。
    """
    resolved = Path(file_path).expanduser().resolve()
    allowed = [project_root().resolve(), Path(output_dir()).resolve(), Path.cwd().resolve()]
    if not any(resolved == root or root in resolved.parents for root in allowed):
        raise ImagegenError(
            f"プロジェクトの外にあるファイルは送れません: {resolved}"
            f"（{project_root()} 配下に置いてから実行してください）"
        )
    return str(resolved)


def _tool_publish_file(arguments: dict) -> str:
    connector = registry.get(arguments.get("to", "github"))
    options = {
        key: arguments[key]
        for key in ("repo", "dest", "branch", "message")
        if arguments.get(key) is not None
    }
    result = connector.publish(
        _check_inside_project(_required(arguments, "file")),
        dry_run=not bool(arguments.get("confirm")),
        **options,
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
    "compose_image": _tool_compose_image,
    "synthesize_speech": _tool_synthesize_speech,
    "list_voices": _tool_list_voices,
    "search_assets": _tool_search_assets,
    "fetch_assets": _tool_fetch_assets,
    "grab_image": _tool_grab_image,
    "fetch_feed": _tool_fetch_feed,
    "publish_file": _tool_publish_file,
    "run_recipe": _tool_run_recipe,
}


def _required(arguments: dict, key: str) -> str:
    value = arguments.get(key)
    if value is None or (isinstance(value, str) and not value.strip()):
        raise ImagegenError(f"{key} を指定してください")
    return value


def call_tool(name: str, arguments: dict) -> dict:
    """ツールを呼び、MCP の結果オブジェクトを返す。"""
    handler = TOOLS.get(name)
    if handler is None:
        return _content(f"未知のツールです: {name}", is_error=True)
    try:
        return _content(handler(arguments or {}))
    except ImagegenError as exc:
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
    # JSON-RPC は UTF-8。Windows の既定エンコーディングのままだと日本語で落ちる
    ensure_utf8_streams()
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

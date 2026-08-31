"""ailab コマンドラインインターフェース。

    ailab gen "プロンプト"        画像を生成する
    ailab search "キーワード"     フリー素材を検索する
    ailab fetch "キーワード"      フリー素材を検索してダウンロードする
    ailab grab URL                画像のURLを直接指定して取り込む
    ailab publish FILE --to ...   生成物を外部サービスへ送る
    ailab feed "対象" --source ...  記事・リリース情報を取得する
    ailab run レシピ              集める→作る→送る を1コマンドで実行する
    ailab usage                   画像生成の利用量と概算コストを見る
    ailab mcp                     MCPサーバとして起動する（Claude から直接使う）
    ailab connectors              連携先の一覧と設定状況を表示する
    ailab doctor [名前]           連携先へ実際に接続して確認する
"""

from __future__ import annotations

import argparse
import json
import os
import sys

import requests

from . import __version__, assets, imagegen, recipes, styles, usage
from .config import load_dotenv, output_dir
from .core import registry
from .core.connector import CAPABILITY_LABELS, capabilities_of
from .core.errors import AilabError, ConfigError
from .utils import ensure_utf8_streams


def _capability_names(capability: str) -> list[str]:
    return [c.name for c in registry.by_capability(capability)]


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="ailab",
        description="画像生成・フリー素材取得・外部サービス連携のツール",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    parser.add_argument("--version", action="version", version=f"ailab {__version__}")
    parser.add_argument(
        "--no-cache", action="store_true", help="検索結果のキャッシュを使わない"
    )
    sub = parser.add_subparsers(dest="command", required=True)

    gen = sub.add_parser("gen", help="プロンプトから画像を生成する")
    gen.add_argument("prompt", help="生成したい画像の説明")
    gen.add_argument(
        "--provider",
        default="auto",
        choices=["auto", *_capability_names("generate")],
        help="使う生成コネクタ (既定: auto = 使えるものを優先順に選ぶ)",
    )
    gen.add_argument("--model", default=None, help="モデル名（既定値を上書き）")
    gen.add_argument(
        "--style", default=None, choices=styles.names(),
        help="絵柄のプリセット（ailab styles で一覧）",
    )
    gen.add_argument("--size", default="1024x1024", help="画像サイズ 例: 1024x1024")
    gen.add_argument("-n", "--count", type=int, default=1, help="生成枚数")
    gen.add_argument("-o", "--out", default=None, help="出力先ディレクトリ (既定: output/images)")
    gen.add_argument("--no-caption", action="store_true", help="local で文字を描き込まない")
    gen.add_argument(
        "--format", dest="fmt", default=None, choices=["png", "jpg", "webp"],
        help="保存形式を変換する（webp は軽い）",
    )
    gen.add_argument(
        "--max-width", type=int, default=None, help="この幅を超えていたら縮小する（縦横比は維持）"
    )

    search = sub.add_parser("search", help="フリー素材を検索する")
    search.add_argument("query", help="検索キーワード")
    search.add_argument(
        "--source", default="all", choices=["all", *_capability_names("search_assets")],
        help="検索先 (既定: all)",
    )
    search.add_argument("-l", "--limit", type=int, default=10, help="1サイトあたりの取得件数")
    search.add_argument("--json", action="store_true", help="JSON で出力する")

    fetch = sub.add_parser("fetch", help="フリー素材を検索してダウンロードする")
    fetch.add_argument("query", help="検索キーワード")
    fetch.add_argument(
        "--source", default="all", choices=["all", *_capability_names("search_assets")],
        help="検索先 (既定: all)",
    )
    fetch.add_argument("-l", "--limit", type=int, default=3, help="ダウンロードする件数")
    fetch.add_argument("-o", "--out", default=None, help="出力先ディレクトリ (既定: output/illust)")

    grab = sub.add_parser("grab", help="画像のURLを直接指定して取り込む")
    grab.add_argument("url", help="画像そのもののURL（ページのURLではない）")
    grab.add_argument("-o", "--out", default=None, help="出力先ディレクトリ (既定: output/illust)")
    grab.add_argument("--from", dest="page_url", default="", help="出典ページのURL")
    grab.add_argument("--license", default="unknown", help="ライセンス表記（例: CC BY 4.0）")
    grab.add_argument("--by", dest="creator", default="", help="作者名")
    grab.add_argument("--title", default="", help="素材の名前（既定はファイル名）")

    publish = sub.add_parser("publish", help="ファイルを外部サービスへ送る")
    publish.add_argument("file", help="送るファイル")
    publish.add_argument(
        "--to", default="github", choices=_capability_names("publish"), help="送信先"
    )
    publish.add_argument("--repo", default=None, help="github: owner/name (既定: AILAB_GITHUB_REPO)")
    publish.add_argument("--path", dest="dest", default=None, help="リポジトリ内の保存先パス")
    publish.add_argument("--branch", default=None, help="ブランチ (既定: リポジトリの既定ブランチ)")
    publish.add_argument("-m", "--message", default=None, help="コミットメッセージ")
    publish.add_argument(
        "--yes", action="store_true", help="実際に送信する（既定はドライラン）"
    )

    feed = sub.add_parser("feed", help="記事・リリース情報を取得する")
    feed.add_argument(
        "query",
        help="rss はフィードURL、github は owner/name、qiita と wikipedia はキーワード",
    )
    feed.add_argument(
        "--source", required=True, choices=_capability_names("fetch_items"),
        help="取得元（対象の指定方法が違うので必ず選ぶ）",
    )
    feed.add_argument("-l", "--limit", type=int, default=10, help="取得件数")
    feed.add_argument("--json", action="store_true", help="JSON で出力する")

    run = sub.add_parser("run", help="レシピ（YAML）を実行する")
    run.add_argument("recipe", help="レシピのパス、または recipes/ 内の名前")
    run.add_argument(
        "--set", dest="variables", action="append", default=[], metavar="KEY=VALUE",
        help="レシピ内の {{ vars.KEY }} を差し替える（複数指定可）",
    )
    run.add_argument("--yes", action="store_true", help="publish を実際に実行する（既定はドライラン）")
    run.add_argument("--json", action="store_true", help="結果を JSON で出力する")

    connectors = sub.add_parser("connectors", help="連携先の一覧と設定状況")
    connectors.add_argument("--json", action="store_true", help="JSON で出力する")
    sub.add_parser("status", help="connectors と同じ（旧名）").add_argument(
        "--json", action="store_true", help="JSON で出力する"
    )

    sub.add_parser("styles", help="絵柄のプリセット一覧")

    usage_parser = sub.add_parser("usage", help="画像生成の利用量と概算コスト")
    usage_parser.add_argument("-d", "--days", type=int, default=None, help="直近N日に絞る")
    usage_parser.add_argument("--json", action="store_true", help="JSON で出力する")

    sub.add_parser("mcp", help="MCPサーバとして起動する（stdio）")

    doctor = sub.add_parser("doctor", help="連携先へ実際に接続して確認する")
    doctor.add_argument("name", nargs="?", default=None, help="確認する連携先（省略で全部）")
    doctor.add_argument("--json", action="store_true", help="JSON で出力する")

    return parser


# --- 各コマンド -------------------------------------------------------
def _cmd_connectors(args: argparse.Namespace) -> int:
    if getattr(args, "json", False):
        print(
            json.dumps(
                [
                    {
                        "name": c.name,
                        "category": c.category,
                        "capabilities": capabilities_of(c),
                        "summary": c.summary,
                        "available": c.is_available(),
                        "reason": c.unavailable_reason(),
                        "env": list(c.auth.env),
                        "terms_url": c.terms_url,
                    }
                    for c in (registry.get(name) for name in registry.names())
                ],
                ensure_ascii=False,
                indent=2,
            )
        )
        return 0

    for capability, label in CAPABILITY_LABELS.items():
        group = registry.by_capability(capability)
        if not group:
            continue
        print(f"{label}:")
        for connector in group:
            mark = "OK " if connector.is_available() else "NG "
            detail = connector.unavailable_reason() or connector.summary
            print(f"  {mark} {connector.name:<12} {detail}")
        print()
    print("接続まで確認するには: ailab doctor")
    return 0


def _cmd_doctor(args: argparse.Namespace) -> int:
    targets = [registry.get(args.name)] if args.name else [registry.get(n) for n in registry.names()]
    results = []
    for connector in targets:
        try:
            result = connector.check()
            results.append(
                {
                    "name": connector.name,
                    "ok": result.ok,
                    "skipped": result.skipped,
                    "detail": result.detail,
                }
            )
        except AilabError as exc:
            results.append(
                {"name": connector.name, "ok": False, "skipped": False, "detail": str(exc)}
            )

    failed = [row for row in results if not row["ok"] and not row["skipped"]]

    if args.json:
        print(
            json.dumps(
                {"results": results, "failed": len(failed), "checked": len(results)},
                ensure_ascii=False,
                indent=2,
            )
        )
        return 1 if failed else 0

    for row in results:
        mark = "-- " if row["skipped"] else ("OK " if row["ok"] else "NG ")
        print(f"  {mark} {row['name']:<12} {row['detail']}")
    print("\n-- はキー未設定のため未確認。ailab connectors で必要な環境変数を確認できます。")
    return 1 if failed else 0


def _cmd_gen(args: argparse.Namespace) -> int:
    provider = imagegen.get_provider(args.provider)
    kwargs = {}
    if provider.name == "local":
        kwargs["caption"] = not args.no_caption

    images = imagegen.generate(
        args.prompt,
        provider=provider.name,
        size=args.size,
        n=args.count,
        model=args.model,
        style=args.style,
        fmt=args.fmt,
        max_width=args.max_width,
        **kwargs,
    )
    destination = args.out or output_dir("images")
    for index, image in enumerate(images):
        path = image.save(f"{destination}/{image.default_name(index)}")
        print(f"保存しました: {path}  ({image.provider}/{image.model})")
    return 0


def _print_assets(items) -> None:
    for index, asset in enumerate(items, 1):
        size = f"{asset.width}x{asset.height}" if asset.width else "サイズ不明"
        print(f"[{index}] {asset.title or '(無題)'}  <{asset.source}>  {size}")
        print(f"    ライセンス: {asset.license}")
        if asset.creator:
            print(f"    作者      : {asset.creator}")
        print(f"    画像URL   : {asset.image_url}")
        if asset.page_url:
            print(f"    ページ    : {asset.page_url}")


def _cmd_search(args: argparse.Namespace) -> int:
    items = assets.search(args.query, source=args.source, limit=args.limit, **_cache_kwargs(args))
    if args.json:
        print(json.dumps([asset.to_dict() for asset in items], ensure_ascii=False, indent=2))
    elif not items:
        print("見つかりませんでした")
    else:
        _print_assets(items)
    return 0


def _cmd_fetch(args: argparse.Namespace) -> int:
    items = assets.search(args.query, source=args.source, limit=args.limit, **_cache_kwargs(args))
    items = items[: args.limit]
    if not items:
        print("見つかりませんでした")
        return 1
    destination = args.out or output_dir("illust")
    saved = assets.download_all(items, destination)
    for asset, path in saved:
        print(f"保存しました: {path}")
        print(f"    出典: {asset.attribution}")
    print(f"\nクレジットは {destination}/CREDITS.md にまとめました。")
    return 0


def _cmd_grab(args: argparse.Namespace) -> int:
    destination = args.out or output_dir("illust")
    asset, path = assets.grab(
        args.url,
        destination,
        page_url=args.page_url,
        license=args.license,
        creator=args.creator,
        title=args.title,
    )
    print(f"保存しました: {path}")
    print(f"    出典: {asset.attribution}")
    if asset.license == "unknown":
        print("    ライセンスが未指定です。--license と --from で出典を残してください。")
    print(f"\nクレジットは {destination}/CREDITS.md にまとめました。")
    return 0


def _cmd_publish(args: argparse.Namespace) -> int:
    connector = registry.get(args.to)
    options = {
        key: value
        for key, value in (
            ("repo", args.repo),
            ("dest", args.dest),
            ("branch", args.branch),
            ("message", args.message),
        )
        if value is not None
    }
    result = connector.publish(args.file, dry_run=not args.yes, **options)
    print(result.describe())
    if result.dry_run:
        print("実際に送信するには --yes を付けてください。")
    return 0


def _cmd_feed(args: argparse.Namespace) -> int:
    connector = registry.get(args.source, **_cache_kwargs(args))
    items = connector.fetch_items(args.query, limit=args.limit)
    if args.json:
        print(json.dumps([item.to_dict() for item in items], ensure_ascii=False, indent=2))
        return 0
    if not items:
        print("見つかりませんでした")
        return 0
    for index, item in enumerate(items, 1):
        print(f"[{index}] {item.describe()}")
        if item.author:
            print(f"    作者: {item.author}")
        if item.url:
            print(f"    URL : {item.url}")
        if item.summary:
            print(f"    概要: {item.summary.splitlines()[0][:100]}")
    return 0


def _cmd_styles(_args: argparse.Namespace) -> int:
    for name, (description, prompt) in sorted(styles.all_styles().items()):
        print(f"{name:<12}{description}")
        print(f"            + {prompt}")
    print(f"\n{styles.custom_path()} を置けば追加・上書きできます。")
    return 0


def _cmd_usage(args: argparse.Namespace) -> int:
    summary = usage.summarize(days=args.days)
    if args.json:
        print(json.dumps(summary, ensure_ascii=False, indent=2))
        return 0

    if not summary["entries"]:
        print("まだ記録がありません（画像を生成すると記録されます）")
        return 0

    span = f"直近{args.days}日" if args.days else "全期間"
    print(f"{span}: {summary['images']}枚 / 概算 ${summary['cost_usd']:.2f}\n")
    print(f"  {'コネクタ':<14}{'モデル':<34}{'枚数':>6}{'概算$':>9}")
    for row in summary["breakdown"]:
        print(f"  {row['provider']:<14}{row['model']:<34}{row['images']:>6}{row['cost_usd']:>9.3f}")
    print("\n金額は概算です。正確な請求額は各社のダッシュボードで確認してください。")
    print(f"単価を変えるには {usage.log_path().parent / usage.COSTS_NAME} を置きます。")
    return 0


def _cmd_mcp() -> int:
    """MCPサーバを起動する。標準出力は JSON-RPC 専用なので何も表示しない。"""
    from .mcp_server import serve

    print("ailab MCP サーバを起動しました（stdio）", file=sys.stderr)
    return serve()


def _parse_variables(pairs: list[str]) -> dict[str, str]:
    """--set KEY=VALUE を辞書にする。"""
    variables = {}
    for pair in pairs:
        key, sep, value = pair.partition("=")
        if not sep or not key.strip():
            raise ConfigError(f"--set は KEY=VALUE の形式です: {pair!r}")
        variables[key.strip()] = value
    return variables


def _cmd_run(args: argparse.Namespace) -> int:
    recipe = recipes.load_recipe(args.recipe)
    variables = _parse_variables(args.variables)

    def report(index: int, total: int, step) -> None:
        print(f"[{index}/{total}] {step.verb} ({step.id}) … {step.summary}")

    result = recipes.run(
        recipe,
        dry_run=not args.yes,
        variables=variables,
        on_step=None if args.json else report,
    )

    if args.json:
        print(json.dumps(result.to_dict(), ensure_ascii=False, indent=2))
        return 0

    files = result.files()
    if files:
        print("\n作られたファイル:")
        for path in files:
            print(f"  {path}")
    if not args.yes and any(step.verb == "publish" for step in result.steps):
        print("\npublish はドライランです。実際に送るには --yes を付けてください。")
    return 0


def _cache_kwargs(args: argparse.Namespace) -> dict:
    return {"cache_ttl": 0} if getattr(args, "no_cache", False) else {}


def main(argv: list[str] | None = None) -> int:
    ensure_utf8_streams()  # Windows のコンソールでも日本語を出せるようにする
    load_dotenv()
    args = build_parser().parse_args(argv)
    handlers = {
        "gen": _cmd_gen,
        "search": _cmd_search,
        "fetch": _cmd_fetch,
        "grab": _cmd_grab,
        "publish": _cmd_publish,
        "feed": _cmd_feed,
        "run": _cmd_run,
        "connectors": _cmd_connectors,
        "status": _cmd_connectors,
        "doctor": _cmd_doctor,
        "styles": _cmd_styles,
        "usage": _cmd_usage,
        "mcp": lambda _args: _cmd_mcp(),
    }
    try:
        return handlers[args.command](args)
    except AilabError as exc:
        print(f"エラー: {exc}", file=sys.stderr)
        return 1
    except ValueError as exc:
        print(f"エラー: {exc}", file=sys.stderr)
        return 1
    except requests.RequestException as exc:  # pragma: no cover - 通常は NetworkError に包まれる
        print(f"ネットワークエラー: {exc}", file=sys.stderr)
        return 1
    except BrokenPipeError:
        # `ailab connectors | head` のように読み手が先に閉じた場合。
        # 終了時の flush でも落ちないよう、標準出力を捨て先に付け替える。
        os.dup2(os.open(os.devnull, os.O_WRONLY), sys.stdout.fileno())
        return 0


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())

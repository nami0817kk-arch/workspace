"""ailab コマンドラインインターフェース。

    ailab gen "プロンプト"        画像を生成する
    ailab search "キーワード"     フリーイラストを検索する
    ailab fetch "キーワード"      フリーイラストを検索してダウンロードする
    ailab status                  利用できるプロバイダ・素材サイトを表示する
"""

from __future__ import annotations

import argparse
import json
import sys

import requests

from . import __version__, illust, imagegen
from .config import load_dotenv, output_dir


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="ailab",
        description="画像生成とフリーイラスト取得のツール",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    parser.add_argument("--version", action="version", version=f"ailab {__version__}")
    sub = parser.add_subparsers(dest="command", required=True)

    gen = sub.add_parser("gen", help="プロンプトから画像を生成する")
    gen.add_argument("prompt", help="生成したい画像の説明")
    gen.add_argument(
        "--provider",
        default="auto",
        choices=["auto", *imagegen.PROVIDERS],
        help="使う生成プロバイダ (既定: auto = APIキーがあるものを優先)",
    )
    gen.add_argument("--model", default=None, help="モデル名（プロバイダ既定値を上書き）")
    gen.add_argument("--size", default="1024x1024", help="画像サイズ 例: 1024x1024")
    gen.add_argument("-n", "--count", type=int, default=1, help="生成枚数")
    gen.add_argument("-o", "--out", default=None, help="出力先ディレクトリ (既定: output/images)")
    gen.add_argument(
        "--no-caption", action="store_true", help="local プロバイダで文字を描き込まない"
    )

    search = sub.add_parser("search", help="フリーイラストを検索する")
    search.add_argument("query", help="検索キーワード")
    search.add_argument(
        "--source", default="all", choices=["all", *illust.SOURCES], help="検索先 (既定: all)"
    )
    search.add_argument("-l", "--limit", type=int, default=10, help="1サイトあたりの取得件数")
    search.add_argument("--json", action="store_true", help="JSON で出力する")

    fetch = sub.add_parser("fetch", help="フリーイラストを検索してダウンロードする")
    fetch.add_argument("query", help="検索キーワード")
    fetch.add_argument(
        "--source", default="all", choices=["all", *illust.SOURCES], help="検索先 (既定: all)"
    )
    fetch.add_argument("-l", "--limit", type=int, default=3, help="ダウンロードする件数")
    fetch.add_argument("-o", "--out", default=None, help="出力先ディレクトリ (既定: output/illust)")

    sub.add_parser("status", help="利用できるプロバイダ・素材サイトを表示する")
    return parser


def _print_status() -> int:
    print("画像生成プロバイダ:")
    for name, ok, reason in imagegen.available_providers():
        print(f"  {'OK ' if ok else 'NG '} {name:<10} {reason}")
    print("\nフリー素材サイト:")
    for name, ok, reason in illust.available_sources():
        print(f"  {'OK ' if ok else 'NG '} {name:<10} {reason}")
    return 0


def _cmd_gen(args: argparse.Namespace) -> int:
    provider = imagegen.get_provider(args.provider)
    kwargs = {}
    if isinstance(provider, imagegen.LocalProvider):
        kwargs["caption"] = not args.no_caption

    images = provider.generate(
        args.prompt, size=args.size, n=args.count, model=args.model, **kwargs
    )
    destination = args.out or output_dir("images")
    for index, image in enumerate(images):
        path = image.save(f"{destination}/{image.default_name(index)}")
        print(f"保存しました: {path}  ({image.provider}/{image.model})")
    return 0


def _print_items(items: list[illust.IllustItem]) -> None:
    for index, item in enumerate(items, 1):
        size = f"{item.width}x{item.height}" if item.width else "サイズ不明"
        print(f"[{index}] {item.title or '(無題)'}  <{item.source}>  {size}")
        print(f"    ライセンス: {item.license}")
        if item.creator:
            print(f"    作者      : {item.creator}")
        print(f"    画像URL   : {item.image_url}")
        if item.page_url:
            print(f"    ページ    : {item.page_url}")


def _cmd_search(args: argparse.Namespace) -> int:
    items = illust.search(args.query, source=args.source, limit=args.limit)
    if args.json:
        print(json.dumps([item.to_dict() for item in items], ensure_ascii=False, indent=2))
    elif not items:
        print("見つかりませんでした")
    else:
        _print_items(items)
    return 0


def _cmd_fetch(args: argparse.Namespace) -> int:
    items = illust.search(args.query, source=args.source, limit=args.limit)[: args.limit]
    if not items:
        print("見つかりませんでした")
        return 1
    destination = args.out or output_dir("illust")
    saved = illust.download_all(items, destination)
    for item, path in saved:
        print(f"保存しました: {path}")
        print(f"    出典: {item.attribution}")
    print(f"\nクレジットは {destination}/CREDITS.md にまとめました。")
    return 0


def main(argv: list[str] | None = None) -> int:
    load_dotenv()
    args = build_parser().parse_args(argv)
    handlers = {
        "gen": _cmd_gen,
        "search": _cmd_search,
        "fetch": _cmd_fetch,
        "status": lambda _args: _print_status(),
    }
    try:
        return handlers[args.command](args)
    except (imagegen.ProviderError, illust.SourceError, ValueError) as exc:
        print(f"エラー: {exc}", file=sys.stderr)
        return 1
    except requests.RequestException as exc:
        print(f"ネットワークエラー: {exc}", file=sys.stderr)
        print("（社内プロキシや接続を確認してください）", file=sys.stderr)
        return 1


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())

"""ailab コマンドラインインターフェース。

    ailab gen "プロンプト"        画像を生成する
    ailab search "キーワード"     フリー素材を検索する
    ailab fetch "キーワード"      フリー素材を検索してダウンロードする
    ailab publish FILE --to ...   生成物を外部サービスへ送る
    ailab connectors              連携先の一覧と設定状況を表示する
    ailab doctor [名前]           連携先へ実際に接続して確認する
"""

from __future__ import annotations

import argparse
import json
import sys

import requests

from . import __version__, assets, imagegen
from .config import load_dotenv, output_dir
from .core import registry
from .core.errors import AilabError

CATEGORY_LABELS = {
    "images": "画像生成",
    "assets": "素材取得",
    "publish": "送信先",
    "feed": "情報収集",
    "misc": "その他",
}


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
    gen.add_argument("--size", default="1024x1024", help="画像サイズ 例: 1024x1024")
    gen.add_argument("-n", "--count", type=int, default=1, help="生成枚数")
    gen.add_argument("-o", "--out", default=None, help="出力先ディレクトリ (既定: output/images)")
    gen.add_argument("--no-caption", action="store_true", help="local で文字を描き込まない")

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

    connectors = sub.add_parser("connectors", help="連携先の一覧と設定状況")
    connectors.add_argument("--json", action="store_true", help="JSON で出力する")
    sub.add_parser("status", help="connectors と同じ（旧名）").add_argument(
        "--json", action="store_true", help="JSON で出力する"
    )

    doctor = sub.add_parser("doctor", help="連携先へ実際に接続して確認する")
    doctor.add_argument("name", nargs="?", default=None, help="確認する連携先（省略で全部）")

    return parser


# --- 各コマンド -------------------------------------------------------
def _cmd_connectors(args: argparse.Namespace) -> int:
    connectors = [registry.get(name) for name in registry.names()]
    if getattr(args, "json", False):
        print(
            json.dumps(
                [
                    {
                        "name": c.name,
                        "category": c.category,
                        "summary": c.summary,
                        "available": c.is_available(),
                        "reason": c.unavailable_reason(),
                        "env": list(c.auth.env),
                        "terms_url": c.terms_url,
                    }
                    for c in connectors
                ],
                ensure_ascii=False,
                indent=2,
            )
        )
        return 0

    for category, label in CATEGORY_LABELS.items():
        group = [c for c in connectors if c.category == category]
        if not group:
            continue
        print(f"{label}:")
        for connector in group:
            mark = "OK " if connector.is_available() else "NG "
            detail = connector.unavailable_reason() or connector.summary
            print(f"  {mark} {connector.name:<10} {detail}")
        print()
    print("接続まで確認するには: ailab doctor")
    return 0


def _cmd_doctor(args: argparse.Namespace) -> int:
    targets = [registry.get(args.name)] if args.name else [registry.get(n) for n in registry.names()]
    failed = 0
    for connector in targets:
        try:
            result = connector.check()
        except AilabError as exc:
            print(f"  NG  {connector.name:<10} {exc}")
            failed += 1
            continue
        mark = "-- " if result.skipped else ("OK " if result.ok else "NG ")
        print(f"  {mark} {connector.name:<10} {result.detail}")
        if not result.ok and not result.skipped:
            failed += 1
    print("\n-- はキー未設定のため未確認。ailab connectors で必要な環境変数を確認できます。")
    return 1 if failed else 0


def _cmd_gen(args: argparse.Namespace) -> int:
    provider = imagegen.get_provider(args.provider)
    kwargs = {}
    if provider.name == "local":
        kwargs["caption"] = not args.no_caption

    images = provider.generate(
        args.prompt, size=args.size, n=args.count, model=args.model, **kwargs
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


def _cache_kwargs(args: argparse.Namespace) -> dict:
    return {"cache_ttl": 0} if getattr(args, "no_cache", False) else {}


def main(argv: list[str] | None = None) -> int:
    load_dotenv()
    args = build_parser().parse_args(argv)
    handlers = {
        "gen": _cmd_gen,
        "search": _cmd_search,
        "fetch": _cmd_fetch,
        "publish": _cmd_publish,
        "connectors": _cmd_connectors,
        "status": _cmd_connectors,
        "doctor": _cmd_doctor,
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


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())

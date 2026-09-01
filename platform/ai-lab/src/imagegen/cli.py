"""imagegen コマンドラインインターフェース。

    imagegen gen "プロンプト"        画像を生成する
    imagegen compose --title "見出し"  画像に見出しを載せた1枚を作る
    imagegen say "読み上げる文章"    文章を読み上げた音声を作る
    imagegen voices                  読み上げに使える声の一覧
    imagegen search "キーワード"     フリー素材を検索する
    imagegen fetch "キーワード"      フリー素材を検索してダウンロードする
    imagegen grab URL                画像のURLを直接指定して取り込む
    imagegen publish FILE --to ...   生成物を外部サービスへ送る
    imagegen feed "対象" --source ...  記事・リリース情報を取得する
    imagegen run レシピ              集める→作る→送る を1コマンドで実行する
    imagegen usage                   画像生成の利用量と概算コストを見る
    imagegen mcp                     MCPサーバとして起動する（Claude から直接使う）
    imagegen connectors              連携先の一覧と設定状況を表示する
    imagegen doctor [名前]           連携先へ実際に接続して確認する
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path

import requests

from . import __version__, assets, compose, generation, recipes, speech, styles, usage
from .config import load_dotenv, output_dir
from .core import registry
from .core.connector import CAPABILITY_LABELS, capabilities_of
from .core.errors import ConfigError, ImagegenError
from .utils import ensure_utf8_streams, slugify


def _capability_names(capability: str) -> list[str]:
    return [c.name for c in registry.by_capability(capability)]


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="imagegen",
        description="画像生成・フリー素材取得・外部サービス連携のツール",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    parser.add_argument("--version", action="version", version=f"imagegen {__version__}")
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
        help="絵柄のプリセット（imagegen styles で一覧）",
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
    gen.add_argument(
        "--seed", type=int, default=None,
        help="乱数の種。同じ種と同じプロンプトなら同じ絵が出る（pollinations のみ）",
    )

    compose_parser = sub.add_parser("compose", help="画像に見出しを載せた1枚を作る")
    compose_parser.add_argument("--title", default="", help="大きく載せる見出し")
    compose_parser.add_argument("--subtitle", default="", help="小さく載せる補足")
    compose_parser.add_argument("--bg", dest="background", default=None, help="背景に敷く画像")
    compose_parser.add_argument("--color", default="#101828", help="背景色（背景画像が無いとき）")
    compose_parser.add_argument(
        "--preset", default="youtube", choices=sorted(compose.PRESETS),
        help=f"仕上がりサイズ ({', '.join(f'{k}={v}' for k, v in compose.PRESETS.items())})",
    )
    compose_parser.add_argument("--size", default=None, help="サイズを直接指定する 例: 1280x720")
    compose_parser.add_argument("--font", default="", help="使うフォントファイル")
    compose_parser.add_argument(
        "--position", default="bottom", choices=compose.POSITIONS, help="文字を置く高さ"
    )
    compose_parser.add_argument(
        "--align", default="center", choices=compose.ALIGNS, help="文字の揃え方"
    )
    compose_parser.add_argument("--band", action="store_true", help="文字の背後に帯を敷く")
    compose_parser.add_argument("--stroke", type=int, default=0, help="袋文字の太さ（px）")
    compose_parser.add_argument("--dim", type=float, default=0.0, help="背景を暗くする 0〜1")
    compose_parser.add_argument("--blur", type=float, default=0.0, help="背景をぼかす")
    compose_parser.add_argument("--logo", default=None, help="隅に重ねる画像")
    compose_parser.add_argument(
        "--format", dest="fmt", default="png", choices=["png", "jpg", "webp"], help="保存形式"
    )
    compose_parser.add_argument("-o", "--out", default=None, help="出力先 (既定: output/compose)")
    compose_parser.add_argument("--name", default=None, help="保存名（既定は日時＋見出し）")

    say = sub.add_parser("say", help="文章を読み上げた音声を作る")
    say.add_argument("text", nargs="?", default=None, help="読み上げる文章（--file を使うなら省略可）")
    say.add_argument("--file", default=None, help="読み上げる文章をファイルから読む")
    say.add_argument(
        "--provider",
        default="auto",
        choices=["auto", *_capability_names("synthesize")],
        help="使う音声合成コネクタ (既定: auto = 使えるものを優先順に選ぶ)",
    )
    say.add_argument("--voice", default=None, help="声の指定（imagegen voices で一覧）")
    say.add_argument("--model", default=None, help="モデル名（既定値を上書き）")
    say.add_argument("--speed", type=float, default=1.0, help="読み上げ速度 (既定: 1.0)")
    say.add_argument(
        "--format", dest="fmt", default=None, choices=["wav", "mp3", "opus", "aac", "flac"],
        help="音声の形式（対応はコネクタによる。voicevox と beep は wav のみ）",
    )
    say.add_argument(
        "--no-join", action="store_true", help="長文を分けて合成したまま、つながずに保存する"
    )
    say.add_argument("-o", "--out", default=None, help="出力先ディレクトリ (既定: output/speech)")
    say.add_argument("--name", default=None, help="保存名（既定は日時＋文章の先頭）")

    voices = sub.add_parser("voices", help="読み上げに使える声の一覧")
    voices.add_argument(
        "--provider", default="auto", choices=["auto", *_capability_names("synthesize")],
        help="対象のコネクタ (既定: auto)",
    )
    voices.add_argument("--json", action="store_true", help="JSON で出力する")

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
    publish.add_argument("--repo", default=None, help="github: owner/name (既定: IMAGEGEN_GITHUB_REPO)")
    publish.add_argument("--path", dest="dest", default=None, help="リポジトリ内の保存先パス")
    publish.add_argument("--branch", default=None, help="ブランチ (既定: リポジトリの既定ブランチ)")
    publish.add_argument("-m", "--message", default=None, help="コミットメッセージ")
    publish.add_argument(
        "--yes", action="store_true", help="実際に送信する（既定はドライラン）"
    )

    feed = sub.add_parser("feed", help="記事・リリース情報を取得する")
    feed.add_argument(
        "query",
        help=(
            "rss はフィードURL、github は owner/name、qiita と wikipedia と estat はキーワード、"
            "edinet は日付(2026-09-01)か証券コード(7203)"
        ),
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
    print("接続まで確認するには: imagegen doctor")
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
        except ImagegenError as exc:
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
    print("\n-- はキー未設定のため未確認。imagegen connectors で必要な環境変数を確認できます。")
    return 1 if failed else 0


def _cmd_gen(args: argparse.Namespace) -> int:
    provider = generation.get_provider(args.provider)
    kwargs = {}
    if provider.name == "local":
        kwargs["caption"] = not args.no_caption
    if provider.name == "pollinations" and args.seed is not None:
        kwargs["seed"] = args.seed

    images = generation.generate(
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


def _cmd_compose(args: argparse.Namespace) -> int:
    if not (args.title or args.subtitle):
        raise ConfigError("--title か --subtitle のどちらかを指定してください")

    image = compose.compose(
        title=args.title,
        subtitle=args.subtitle,
        background=args.background,
        color=args.color,
        size=args.size,
        preset=args.preset,
        font=args.font,
        position=args.position,
        align=args.align,
        band=args.band,
        stroke=args.stroke,
        dim=args.dim,
        blur=args.blur,
        logo=args.logo,
        fmt=args.fmt,
    )
    destination = args.out or output_dir("compose")
    name = f"{slugify(args.name)}{image.ext}" if args.name else image.default_name()
    path = image.save(f"{destination}/{name}")
    print(f"保存しました: {path}  ({image.meta['size']})")
    return 0


def _speech_text(args: argparse.Namespace) -> str:
    if args.file:
        return Path(args.file).read_text(encoding="utf-8")
    if args.text:
        return args.text
    raise ConfigError("読み上げる文章、または --file を指定してください")


def _cmd_say(args: argparse.Namespace) -> int:
    provider = speech.get_provider(args.provider)
    clips = speech.synthesize(
        _speech_text(args),
        provider=provider.name,
        voice=args.voice,
        model=args.model,
        speed=args.speed,
        fmt=args.fmt,
        join=not args.no_join,
    )
    destination = args.out or output_dir("speech")
    saved = speech.save_all(clips, destination, basename=args.name)

    for path, clip in zip(saved, clips, strict=True):
        seconds = clip.seconds
        length = f"{seconds:.1f}秒" if seconds is not None else "長さ不明"
        voice = f"/{clip.voice}" if clip.voice else ""
        print(f"保存しました: {path}  ({clip.provider}/{clip.model}{voice}, {length})")

    credits_path = speech.write_credits(clips, destination)
    if credits_path:
        for credit in sorted({clip.credit for clip in clips if clip.credit}):
            print(f"    表示が必要なクレジット: {credit}")
        print(f"クレジットは {credits_path} にまとめました。")
    if provider.name == "beep":
        print("（beep は読み上げではなく、尺だけ合わせたプレースホルダ音声です）")
    return 0


def _cmd_voices(args: argparse.Namespace) -> int:
    connector = speech.get_provider(args.provider)
    if not connector.is_available():
        print(f"{connector.name}: {connector.unavailable_reason()}", file=sys.stderr)
        return 1
    found = connector.list_voices()
    if args.json:
        print(json.dumps([voice.to_dict() for voice in found], ensure_ascii=False, indent=2))
        return 0
    if not found:
        print("使える声が見つかりませんでした")
        return 0
    print(f"{connector.name} で使える声:")
    for voice in found:
        print(f"  {voice.describe()}")
    print(f"\n使うとき: imagegen say \"こんにちは\" --provider {connector.name} --voice {found[0].id}")
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
    volume = f"{summary['images']}枚"
    if summary.get("clips"):
        volume += f" / 音声{summary['clips']}本（{summary['chars']:,}文字）"
    print(f"{span}: {volume} / 概算 ${summary['cost_usd']:.2f}\n")
    print(f"  {'コネクタ':<14}{'モデル':<30}{'点数':>6}{'文字数':>9}{'概算$':>9}")
    for row in summary["breakdown"]:
        count = row["clips"] if row.get("kind") == "speech" else row["images"]
        chars = f"{row['chars']:,}" if row.get("chars") else "-"
        print(f"  {row['provider']:<14}{row['model']:<30}{count:>6}{chars:>9}{row['cost_usd']:>9.3f}")
    print("\n金額は概算です。正確な請求額は各社のダッシュボードで確認してください。")
    print(f"単価を変えるには {usage.log_path().parent / usage.COSTS_NAME} を置きます。")
    return 0


def _cmd_mcp() -> int:
    """MCPサーバを起動する。標準出力は JSON-RPC 専用なので何も表示しない。"""
    from .mcp_server import serve

    print("imagegen MCP サーバを起動しました（stdio）", file=sys.stderr)
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
        "compose": _cmd_compose,
        "say": _cmd_say,
        "voices": _cmd_voices,
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
    except ImagegenError as exc:
        print(f"エラー: {exc}", file=sys.stderr)
        return 1
    except ValueError as exc:
        print(f"エラー: {exc}", file=sys.stderr)
        return 1
    except requests.RequestException as exc:  # pragma: no cover - 通常は NetworkError に包まれる
        print(f"ネットワークエラー: {exc}", file=sys.stderr)
        return 1
    except BrokenPipeError:
        # `imagegen connectors | head` のように読み手が先に閉じた場合。
        # 終了時の flush でも落ちないよう、標準出力を捨て先に付け替える。
        os.dup2(os.open(os.devnull, os.O_WRONLY), sys.stdout.fileno())
        return 0


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())

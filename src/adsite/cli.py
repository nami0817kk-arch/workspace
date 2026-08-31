"""コマンドラインインターフェース。

    adsite build                     静的サイトを生成
    adsite serve                     ローカルで確認 (http://localhost:8000)
    adsite check                     公開前の品質チェック
    adsite ingest report.csv         AdSenseのCSVを台帳に取り込む
    adsite forecast --target 700     目標収益に必要な月間PVを逆算
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from moneyloop.config import load_config
from moneyloop.storage import Storage

from .analytics import parse_report, pageviews_needed, record_ad_revenue, summarize_rows, top_pages
from .build import build
from .config import load_site_config


def cmd_build(args) -> int:
    site = load_site_config(args.config)
    report = build(site)
    print(json.dumps(report.to_dict(), ensure_ascii=False, indent=2))
    print(f"出力先: {site.output_dir}", file=sys.stderr)
    return 0


def cmd_check(args) -> int:
    site = load_site_config(args.config)
    report = build(site)
    for warning in report.warnings:
        print(f"警告: {warning}")
    print(f"{report.pages}ページ / ツール{report.tools}件 / 広告掲載{report.ad_pages}ページ")
    if not site.ads.enabled:
        print("注意: AdSenseクライアントIDが未設定のため、広告タグは出力されていません")
    return 1 if report.warnings else 0


def cmd_serve(args) -> int:
    import http.server
    import socketserver

    site = load_site_config(args.config)
    build(site)
    root = Path(site.output_dir).resolve()

    class Handler(http.server.SimpleHTTPRequestHandler):
        def __init__(self, *a, **kw):
            super().__init__(*a, directory=str(root), **kw)

    with socketserver.TCPServer(("127.0.0.1", args.port), Handler) as httpd:
        print(f"http://127.0.0.1:{args.port} で配信中 (Ctrl+C で停止)")
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            pass
    return 0


def cmd_ingest(args) -> int:
    rows, errors = parse_report(Path(args.csv).read_text(encoding="utf-8"))
    for err in errors:
        print(f"警告: {err}")
    if not rows:
        print("取り込める行がありませんでした")
        return 1

    stats = summarize_rows(rows)
    config = load_config(args.moneyloop_config)
    with Storage(config.db_path) as storage:
        count, total = record_ad_revenue(storage, rows, network=args.network)

    print(f"取り込み: {len(rows)}行 / 新規計上 {count}日分 / ${total:.2f}")
    print(f"表示 {stats.impressions:,} / クリック {stats.clicks:,} / CTR {stats.ctr * 100:.2f}%")
    print(f"RPM ${stats.rpm_usd:.2f}  (約 {stats.rpm_usd * config.usd_jpy:,.0f} 円/1000PV)")
    pages = top_pages(rows, limit=args.top)
    if pages:
        print("収益上位ページ:")
        for url, amount in pages:
            print(f"  ${amount:8.2f}  {url}")
    return 0


def cmd_forecast(args) -> int:
    config = load_config(args.moneyloop_config)
    needed = pageviews_needed(args.target, args.rpm)
    print(f"目標月間収益  : ${args.target:,.2f}  (約 {args.target * config.usd_jpy:,.0f} 円)")
    print(f"想定RPM       : ${args.rpm:.2f}  (約 {args.rpm * config.usd_jpy:,.0f} 円/1000PV)")
    print(f"必要な月間PV  : {needed:,}")
    print(f"           1日あたり約 {needed // 30:,} PV")
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="adsite", description="広告収益型ツールサイトのビルドと収益管理")
    parser.add_argument("--config", default=None, help="サイト設定JSONのパス")
    parser.add_argument("--moneyloop-config", default=None, help="moneyloop設定JSONのパス（台帳用）")
    sub = parser.add_subparsers(dest="command", required=True)

    p_build = sub.add_parser("build", help="静的サイトを生成")
    p_build.set_defaults(func=cmd_build)

    p_check = sub.add_parser("check", help="公開前の品質チェック（警告があれば終了コード1）")
    p_check.set_defaults(func=cmd_check)

    p_serve = sub.add_parser("serve", help="ローカルで確認")
    p_serve.add_argument("--port", type=int, default=8000)
    p_serve.set_defaults(func=cmd_serve)

    p_ingest = sub.add_parser("ingest", help="AdSenseのCSVを台帳に取り込む")
    p_ingest.add_argument("csv")
    p_ingest.add_argument("--network", default="adsense")
    p_ingest.add_argument("--top", type=int, default=10)
    p_ingest.set_defaults(func=cmd_ingest)

    p_forecast = sub.add_parser("forecast", help="目標収益に必要な月間PVを逆算")
    p_forecast.add_argument("--target", type=float, default=700.0, help="目標月間収益(USD)")
    p_forecast.add_argument("--rpm", type=float, default=4.0, help="想定RPM(USD/1000PV)")
    p_forecast.set_defaults(func=cmd_forecast)

    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())

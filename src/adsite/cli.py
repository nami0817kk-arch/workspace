"""コマンドラインインターフェース。

    adsite build                        静的サイトを生成
    adsite serve                        ローカルで確認 (http://127.0.0.1:8000)
    adsite check                        公開前の品質チェック
    adsite ingest report.csv            AdSenseのCSVを取り込む
    adsite report                       PL・RPM・CTR・損益分岐PV
    adsite forecast --target 700        目標収益に必要な月間PVを逆算
    adsite cost add --category domain --amount 1.2
    adsite ideas --dry-run              次に作るツールの案を出す
"""

from __future__ import annotations

import argparse
import json
import sys
from datetime import date
from pathlib import Path

from .analytics import ingest, parse_report, summarize_rows, top_pages
from .build import build
from .config import SiteConfig, load_site_config
from .content import load_pages
from .ledger import (
    month_range,
    pageviews_needed,
    record_monthly_fixed_cost,
    record_cost,
    summarize,
)
from .storage import Storage


def _site(args) -> SiteConfig:
    return load_site_config(args.config)


def cmd_build(args) -> int:
    site = _site(args)
    report = build(site)
    print(json.dumps(report.to_dict(), ensure_ascii=False, indent=2))
    print(f"出力先: {site.output_dir}", file=sys.stderr)
    return 0


def cmd_check(args) -> int:
    site = _site(args)
    report = build(site)
    for warning in report.warnings:
        print(f"警告: {warning}")
    print(f"{report.pages}ページ / ツール{report.tools}件 / 広告掲載{report.ad_pages}ページ")

    # AdSense審査はコンテンツ量で落ちることが最も多いので、ここで先に知らせる。
    if report.pages < 15:
        print(f"注意: 審査には実質的な内容のあるページが15枚程度必要です（現在{report.pages}枚）")
    if not site.ads.enabled:
        print("注意: AdSenseクライアントIDが未設定のため、広告タグは出力されていません")
    return 1 if report.warnings else 0


def cmd_serve(args) -> int:
    import http.server
    import socketserver

    site = _site(args)
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
    site = _site(args)
    rows, errors = parse_report(Path(args.csv).read_text(encoding="utf-8"))
    for err in errors:
        print(f"警告: {err}")
    if not rows:
        print("取り込める行がありませんでした")
        return 1

    stats = summarize_rows(rows)
    with Storage(site.db_path) as storage:
        days, total = ingest(storage, rows, network=args.network)

    print(f"取り込み: {len(rows)}行 / {days}日分 / ${total:.2f}")
    print(f"表示 {stats.impressions:,} / クリック {stats.clicks:,} / CTR {stats.ctr * 100:.2f}%")
    print(f"RPM ${stats.rpm_usd:.2f}  (約 {stats.rpm_usd * site.usd_jpy:,.0f} 円/1000PV)")
    if stats.ctr > 0.10:
        print("警告: CTRが10%を超えています。誤クリックを誘発する配置になっていないか確認してください")
    pages = top_pages(rows, limit=args.top)
    if pages:
        print("収益上位ページ:")
        for url, amount in pages:
            print(f"  ${amount:8.2f}  {url}")
    return 0


def cmd_report(args) -> int:
    site = _site(args)
    since, until = month_range(date.fromisoformat(args.month + "-01") if args.month else date.today())
    with Storage(site.db_path) as storage:
        econ = summarize(storage, usd_jpy=site.usd_jpy, since=since, until=until)
        rows = storage.ad_daily(since=since, until=until)

    if args.json:
        print(json.dumps(econ.to_dict(), ensure_ascii=False, indent=2))
        return 0

    d = econ.to_dict()
    print(f"期間            : {d['period']}")
    print(f"広告収益        : ${d['revenue_usd']:.2f}  (約 {d['revenue_usd'] * site.usd_jpy:,.0f} 円)")
    print(f"原価            : ${d['cost_usd']:.4f}")
    print(f"利益            : ${d['profit_usd']:.2f}  (約 {d['profit_jpy']:,} 円)")
    print(f"利益率          : {d['margin'] * 100:.1f}%")
    print(f"PV              : {d['pageviews']:,}  / 表示 {d['impressions']:,} / クリック {d['clicks']:,}")
    print(f"RPM             : ${d['rpm_usd']:.2f}  (約 {d['rpm_usd'] * site.usd_jpy:,.0f} 円/1000PV)")
    print(f"CTR             : {d['ctr'] * 100:.2f}%")
    print(f"損益分岐PV      : {d['breakeven_pageviews']:,}")
    top = top_pages(rows, limit=5)
    if top:
        print("収益上位ページ:")
        for url, amount in top:
            print(f"  ${amount:8.2f}  {url}")
    return 0


def cmd_forecast(args) -> int:
    site = _site(args)
    rpm = args.rpm
    if rpm <= 0:
        # 実測があればそれを使う。広告は自分のサイトのRPMでしか計画できない。
        since, until = month_range(date.today())
        with Storage(site.db_path) as storage:
            rpm = summarize(storage, usd_jpy=site.usd_jpy, since=since, until=until).rpm_usd
        if rpm <= 0:
            print("RPMの実測がありません。--rpm で想定値を指定してください（日本語の技術系なら $2〜6 が目安）")
            return 1
        print(f"（実測RPM ${rpm:.2f} を使用）")

    needed = pageviews_needed(args.target, rpm)
    print(f"目標月間収益  : ${args.target:,.2f}  (約 {args.target * site.usd_jpy:,.0f} 円)")
    print(f"想定RPM       : ${rpm:.2f}  (約 {rpm * site.usd_jpy:,.0f} 円/1000PV)")
    print(f"必要な月間PV  : {needed:,}")
    print(f"           1日あたり約 {needed // 30:,} PV")
    return 0


def cmd_cost_add(args) -> int:
    site = _site(args)
    on = date.fromisoformat(args.date) if args.date else date.today()
    with Storage(site.db_path) as storage:
        if args.once:
            added = record_cost(
                storage,
                category=args.category,
                amount_usd=args.amount,
                ref=f"once:{args.category}:{on.isoformat()}",
                note=args.note,
            )
        else:
            added = record_monthly_fixed_cost(
                storage, category=args.category, amount_usd=args.amount, on=on, note=args.note
            )
    print("計上しました" if added else "同じ費目・同じ期間で計上済みのためスキップしました")
    return 0


def cmd_ideas(args) -> int:
    from .ideas import propose, render_markdown
    from .llm import LLMError, build_client

    site = _site(args)
    pages = load_pages(site.content_dir)
    llm = build_client(dry_run=args.dry_run)
    theme = args.theme or site.theme or site.tagline or site.site_name

    try:
        ideas, result = propose(llm, pages, theme=theme, count=args.count)
    except LLMError as exc:
        print(f"提案の生成に失敗しました: {exc}")
        return 1

    today = date.today()
    with Storage(site.db_path) as storage:
        record_cost(
            storage,
            category="llm:ideas",
            amount_usd=result.cost_usd,
            ref=f"llm:ideas:{today.isoformat()}",
            note="ツール案の生成",
        )

    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(render_markdown(ideas, today), encoding="utf-8")
    print(f"{len(ideas)}件の案を {out} に書き出しました (原価 ${result.cost_usd:.4f})")
    print("そのまま実装せず、実際に検索されているか確認してから着手してください。")
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="adsite", description="広告収益型ツールサイトのビルドと収益管理")
    parser.add_argument("--config", default=None, help="サイト設定JSONのパス")
    sub = parser.add_subparsers(dest="command", required=True)

    sub.add_parser("build", help="静的サイトを生成").set_defaults(func=cmd_build)
    sub.add_parser("check", help="公開前チェック（警告があれば終了コード1）").set_defaults(func=cmd_check)

    p_serve = sub.add_parser("serve", help="ローカルで確認")
    p_serve.add_argument("--port", type=int, default=8000)
    p_serve.set_defaults(func=cmd_serve)

    p_ingest = sub.add_parser("ingest", help="AdSenseのCSVを取り込む")
    p_ingest.add_argument("csv")
    p_ingest.add_argument("--network", default="adsense")
    p_ingest.add_argument("--top", type=int, default=10)
    p_ingest.set_defaults(func=cmd_ingest)

    p_report = sub.add_parser("report", help="PL・RPM・CTR・損益分岐PV")
    p_report.add_argument("--month", help="対象月 (YYYY-MM)")
    p_report.add_argument("--json", action="store_true")
    p_report.set_defaults(func=cmd_report)

    p_forecast = sub.add_parser("forecast", help="目標収益に必要な月間PVを逆算")
    p_forecast.add_argument("--target", type=float, default=700.0, help="目標月間収益(USD)")
    p_forecast.add_argument("--rpm", type=float, default=0.0, help="想定RPM(USD/1000PV)。省略時は実測を使う")
    p_forecast.set_defaults(func=cmd_forecast)

    p_cost = sub.add_parser("cost", help="費用の計上").add_subparsers(dest="cost_command", required=True)
    p_cost_add = p_cost.add_parser("add", help="固定費・一時費用を計上")
    p_cost_add.add_argument("--category", required=True, help="例: domain, mail, hosting")
    p_cost_add.add_argument("--amount", type=float, required=True, help="金額(USD)")
    p_cost_add.add_argument("--date", help="計上日 (YYYY-MM-DD)")
    p_cost_add.add_argument("--note", default="")
    p_cost_add.add_argument("--once", action="store_true", help="月次ではなく一時費用として計上")
    p_cost_add.set_defaults(func=cmd_cost_add)

    p_ideas = sub.add_parser("ideas", help="次に作るツールの案を出す（人がレビューして選ぶ）")
    p_ideas.add_argument("--dry-run", action="store_true", help="Claude APIを呼ばずスタブで実行（無課金）")
    p_ideas.add_argument("--count", type=int, default=8)
    p_ideas.add_argument("--theme", default="", help="サイトのテーマ（省略時は設定から）")
    p_ideas.add_argument("--out", default="docs/tool-ideas.md")
    p_ideas.set_defaults(func=cmd_ideas)

    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())

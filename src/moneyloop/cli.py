"""コマンドラインインターフェース。

    moneyloop run --dry-run          パイプラインを課金なしで実行
    moneyloop run                    本番実行（Claude APIを呼ぶ）
    moneyloop sub add a@b.com --plan pro
    moneyloop revenue accrue         当月の購読収益を計上
    moneyloop report                 PLとユニットエコノミクス
    moneyloop plan --target-profit 3000   目標利益に必要な購読者数を逆算
"""

from __future__ import annotations

import argparse
import json
import sys
from datetime import date

from .config import Config, load_config
from .ledger import accrue_subscriptions, month_range, summarize
from .llm import build_client
from .models import Subscriber
from .orchestrator import run_daily
from .storage import Storage


def _open(args) -> tuple[Config, Storage]:
    config = load_config(args.config)
    return config, Storage(config.db_path)


def cmd_run(args) -> int:
    config, storage = _open(args)
    with storage:
        llm = build_client(dry_run=args.dry_run, enable_fallbacks=config.llm.enable_fallbacks)
        reports = run_daily(
            config,
            storage,
            llm,
            run_date=date.fromisoformat(args.date) if args.date else None,
            niches=args.niche or None,
            send=not args.no_send,
        )
        payload = [r.to_dict() for r in reports]
        print(json.dumps(payload, ensure_ascii=False, indent=2))
        return 1 if any(r.errors for r in reports) else 0


def cmd_sub_add(args) -> int:
    config, storage = _open(args)
    with storage:
        config.plan(args.plan)  # 未定義プランならここで落とす
        sub = storage.upsert_subscriber(Subscriber(email=args.email, niche=args.niche, plan=args.plan))
        print(f"登録しました: {sub.email} / {sub.niche} / {sub.plan}")
    return 0


def cmd_sub_cancel(args) -> int:
    _, storage = _open(args)
    with storage:
        ok = storage.cancel_subscriber(args.email, args.niche)
        print("解約しました" if ok else "該当する購読者が見つかりません")
        return 0 if ok else 1


def cmd_sub_list(args) -> int:
    config, storage = _open(args)
    with storage:
        for niche in config.niches:
            subs = storage.subscribers(niche.code, status=args.status or "")
            print(f"[{niche.code}] {len(subs)}件")
            for s in subs:
                print(f"  {s.email:<32} {s.plan:<8} {s.status:<9} since {s.started_at}")
    return 0


def cmd_revenue_accrue(args) -> int:
    config, storage = _open(args)
    with storage:
        on = date.fromisoformat(args.date) if args.date else date.today()
        count, total = accrue_subscriptions(storage, config, on=on)
        print(f"{on.strftime('%Y-%m')} の購読収益を計上: {count}件 / ${total:.2f}")
    return 0


def cmd_report(args) -> int:
    config, storage = _open(args)
    with storage:
        if args.month:
            since, until = month_range(date.fromisoformat(args.month + "-01"))
        else:
            since, until = month_range(date.today())
        econ = summarize(storage, config, since, until)
        if args.json:
            print(json.dumps(econ.to_dict(), ensure_ascii=False, indent=2))
            return 0
        d = econ.to_dict()
        print(f"期間            : {d['period']}")
        print(f"売上            : ${d['revenue_usd']:.2f}")
        print(f"API原価         : ${d['cost_usd']:.4f}")
        print(f"粗利            : ${d['gross_profit_usd']:.2f}  (約 {d['gross_profit_jpy']:,} 円)")
        print(f"粗利率          : {d['gross_margin'] * 100:.1f}%")
        print(f"発行号数        : {d['issues']}  / 1号あたり原価 ${d['cost_per_issue_usd']:.4f}")
        print(f"購読者          : 有料 {d['paying_subscribers']} / 無料 {d['free_subscribers']}"
              f"  (転換率 {d['conversion_rate'] * 100:.1f}%)")
        print(f"ARPU            : ${d['arpu_usd']:.4f}")
        print(f"損益分岐購読者数: {d['breakeven_subscribers']}人")
    return 0


def cmd_plan(args) -> int:
    """目標利益から逆算して必要な購読者数を出す（意思決定用の簡易モデル）。"""
    config, storage = _open(args)
    with storage:
        since, until = month_range(date.today())
        econ = summarize(config=config, storage=storage, since=since, until=until)
        price = econ.paid_plan_price_usd
        price_cents = int(round(price * 100))
        if price_cents <= 0:
            print("有料プランが定義されていません")
            return 1
        monthly_cost = econ.cost_usd if econ.cost_usd > 0 else args.assumed_cost
        target = args.target_profit
        needed = -(-int(round((target + monthly_cost) * 100)) // price_cents)
        conv = args.conversion / 100 if args.conversion else max(econ.conversion_rate, 0.02)
        audience = -(-needed * 100 // max(int(conv * 100), 1))
        print(f"有料単価        : ${price:.2f}/月")
        print(f"想定月間原価    : ${monthly_cost:.2f}")
        print(f"目標月間利益    : ${target:.2f}  (約 {target * config.usd_jpy:,.0f} 円)")
        print(f"必要な有料購読者: {needed}人")
        print(f"想定転換率      : {conv * 100:.1f}%  → 必要な無料読者規模 {audience}人")
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="moneyloop", description="AI自動リサーチ→有料ニュースレター収益化パイプライン")
    parser.add_argument("--config", default=None, help="設定JSONのパス")
    sub = parser.add_subparsers(dest="command", required=True)

    p_run = sub.add_parser("run", help="パイプラインを実行")
    p_run.add_argument("--dry-run", action="store_true", help="Claude APIを呼ばずスタブで実行（無課金）")
    p_run.add_argument("--date", help="実行日 (YYYY-MM-DD)")
    p_run.add_argument("--niche", action="append", help="対象ニッチ（複数指定可）")
    p_run.add_argument("--no-send", action="store_true", help="生成のみ行い配信しない")
    p_run.set_defaults(func=cmd_run)

    p_sub = sub.add_parser("sub", help="購読者管理").add_subparsers(dest="sub_command", required=True)
    p_add = p_sub.add_parser("add", help="購読者を登録/更新")
    p_add.add_argument("email")
    p_add.add_argument("--niche", required=True)
    p_add.add_argument("--plan", default="free")
    p_add.set_defaults(func=cmd_sub_add)
    p_cancel = p_sub.add_parser("cancel", help="購読者を解約")
    p_cancel.add_argument("email")
    p_cancel.add_argument("--niche", required=True)
    p_cancel.set_defaults(func=cmd_sub_cancel)
    p_list = p_sub.add_parser("list", help="購読者一覧")
    p_list.add_argument("--status", default="active", help="active / canceled / 空文字で全件")
    p_list.set_defaults(func=cmd_sub_list)

    p_rev = sub.add_parser("revenue", help="収益計上").add_subparsers(dest="rev_command", required=True)
    p_accrue = p_rev.add_parser("accrue", help="当月分の購読収益を計上（冪等）")
    p_accrue.add_argument("--date")
    p_accrue.set_defaults(func=cmd_revenue_accrue)

    p_report = sub.add_parser("report", help="PLとユニットエコノミクス")
    p_report.add_argument("--month", help="対象月 (YYYY-MM)")
    p_report.add_argument("--json", action="store_true")
    p_report.set_defaults(func=cmd_report)

    p_plan = sub.add_parser("plan", help="目標利益から必要購読者数を逆算")
    p_plan.add_argument("--target-profit", type=float, default=1000.0, help="目標月間利益(USD)")
    p_plan.add_argument("--assumed-cost", type=float, default=30.0, help="実績がない場合の想定月間原価(USD)")
    p_plan.add_argument("--conversion", type=float, default=0.0, help="無料→有料の転換率(%%)")
    p_plan.set_defaults(func=cmd_plan)

    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())

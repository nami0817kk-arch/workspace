#!/usr/bin/env python3
"""毎日1回、楽天から価格を取得して記録する。手元PCのタスクスケジューラから実行する。

楽天は Backend Service 型で許可IPからのリクエストしか受け付けないため、IPを
固定できない GitHub Actions からは実行できない（run-daily.ps1 が呼ぶ）。
Claude の実行コンテナからも楽天へ到達できないので、ここでの動作確認は
--dry-run と単体テストで行う。

保存の前に validate.check_snapshot で「記録に値するデータか」を検査する。
壊れた1日を混ぜると履歴が恒久的に歪み、取り直せないため。
"""
import argparse
import sys
from datetime import datetime, timezone, timedelta
from pathlib import Path

ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT))

from src import rakuten, store, validate  # noqa: E402

JST = timezone(timedelta(hours=9))


def main() -> int:
    ap = argparse.ArgumentParser(description="楽天から価格を取得して記録する")
    ap.add_argument("--dry-run", action="store_true",
                    help="通信せず、設定と保存先だけ確認する")
    ap.add_argument("--day", default=datetime.now(JST).strftime("%Y-%m-%d"))
    ap.add_argument("--no-verify", action="store_true",
                    help="保存前の検査で止めない（原因を承知のうえで記録するとき）")
    args = ap.parse_args()

    site = store.load_json(ROOT / "config.json", {})
    genres = site.get("genres") or []
    data = ROOT / "data"

    if not genres:
        print("config.json の genres が空です。explore.py で対象ジャンルを決めてください。")
        return 1

    if args.dry_run:
        print(f"対象ジャンル {len(genres)}件 / 1ジャンルあたり{site.get('hits_per_genre', 90)}件")
        print(f"想定リクエスト数: 約{len(genres) * (site.get('hits_per_genre', 90) // 30 + 1)}回"
              f"（1秒1回の制限のため所要 約{len(genres) * 4}秒）")
        print(f"保存先: {store.snapshot_path(data, args.day)}")
        return 0

    throttle = rakuten.Throttle()
    items = store.load_json(data / "items.json", {})
    fetched, failed = [], []

    for genre in genres:
        gid = str(genre["genre_id"] if isinstance(genre, dict) else genre)
        try:
            rows = rakuten.search_genre(gid, site.get("hits_per_genre", 90), throttle)
        except Exception as exc:  # 1ジャンル失敗しても他は記録する
            failed.append(f"{gid}: {exc}")
            continue
        print(f"  ジャンル {gid}: {len(rows)}件")
        fetched.extend(rows)
        for row in rows:
            # 価格は履歴側で持つので、マスタには変化しにくい情報だけ残す
            items[row["item_code"]] = {
                "name": row["name"], "shop": row["shop"], "url": row["url"],
                "image": row["image"], "genre_id": row["genre_id"] or gid,
            }

    if not fetched:
        print("1件も取得できませんでした。" + ("; ".join(failed) if failed else ""))
        return 1

    # 同じ商品が複数ジャンルで返ることがあるため、商品コードで一意にする
    unique = {row["item_code"]: row for row in fetched}
    rows = list(unique.values())

    # 保存の前に検査する。壊れた1日を履歴に混ぜると、最安値・値下がりの判定が
    # 恒久的に歪み、取り直しもできない。疑わしいときは記録しない方を選ぶ。
    errors, warnings = validate.check_snapshot(
        rows, expected=len(genres) * site.get("hits_per_genre", 90))
    for w in warnings:
        print(f"  警告: {w}")
    if errors and not args.no_verify:
        for e in errors:
            print(f"  [ERROR] {e}")
        for f in failed:
            print(f"  失敗: {f}")
        print("記録を中止しました。原因を確認してください。"
              "検査を承知のうえで記録するなら --no-verify を付けます。")
        return 1

    store.write_snapshot(data, args.day, rows)
    summary = store.update_summary(
        store.load_json(data / "summary.json", {}), rows, args.day,
        site.get("history_tail_days", 90))
    store.save_json(data / "summary.json", summary)
    store.save_json(data / "items.json", items)

    without_affiliate = sum(1 for r in rows if not r["is_affiliate"])
    print(f"{args.day}: {len(rows)}件を記録（累計 {len(summary)}商品）")
    if without_affiliate:
        print(f"  警告: {without_affiliate}件がアフィリエイトリンクなし。"
              "RAKUTEN_AFFILIATE_ID が未設定だと収益が発生しません。")
    for f in failed:
        print(f"  失敗: {f}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

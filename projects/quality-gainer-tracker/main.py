import argparse
import sys
import io
from datetime import date

from src.analysis.screener import screen_quality_gainers
from src.analysis.pattern_detector import detect_ab, detect_c
from src.analysis.backfill import build_historical_rankings
from src.db.manager import save, update_prices, report, query, get_past_records


def cmd_rank(args):
    # 日付指定なし → kabutan（当日リアルタイム）
    # 日付指定あり → kabudragon（過去日付）
    date_str = getattr(args, "date", None)
    src = "kabudragon" if date_str else "kabutan"

    print(f"\n{'='*60}")
    print(f"  値上がり質ランキング  日本株  （{src}）")
    print(f"{'='*60}\n")

    df = screen_quality_gainers(
        top_n       = args.top,
        min_gain_pct= args.min_gain,
        source      = src,
        date_str    = date_str,
    )

    if df.empty:
        print("  条件に合う銘柄が見つかりませんでした。")
        return

    cols = [c for c in ["ticker", "name", "終値", "値上がり率%", "出来高"] if c in df.columns]
    print(df[cols].to_string(index=False))

    if not args.no_save:
        print()
        rec_date = args.date or (df["記録日"].iloc[0] if "記録日" in df.columns else None)
        inserted, skipped = save(df, rec_date=rec_date)
        if inserted:
            print(f"  {inserted} 件を DB に登録しました（記録日: {rec_date or str(date.today())}）")
        if skipped:
            print(f"  {skipped} 件は追跡中のためスキップしました")
        if not inserted and not skipped:
            print("  保存対象なし")

    print(f"\n{'='*60}")


def cmd_update(_args):
    print(f"\n{'='*60}")
    print(f"  d01〜d14 追跡価格を更新します...")
    print(f"{'='*60}\n")
    update_prices()
    print(f"\n{'='*60}")


def cmd_report(_args):
    print()
    print(report())


def cmd_backfill(args):
    """過去 n 営業日分のランキングを価格履歴から再構築して DB に補填する"""
    print(f"\n{'='*60}")
    print(f"  過去 {args.days} 営業日のランキングを補填  日本株（ウォッチリスト）")
    print(f"{'='*60}\n")

    existing = {r["rec_date"] for r in get_past_records()}
    if existing:
        print(f"  既記録日数: {len(existing)} 日（スキップします）\n")

    daily = build_historical_rankings(
        n_days       = args.days,
        market       = "JP",
        cap_types    = ["small", "mid"],
        top_n        = 20,
        min_gain_pct = args.min_gain,
        skip_dates   = existing,
    )

    if not daily:
        print(f"\n{'='*60}")
        return

    print(f"\n  DB に保存中...")
    total_inserted = 0
    total_skipped  = 0
    for date_str, df in sorted(daily.items()):
        inserted, skipped = save(df, rec_date=date_str)
        total_inserted += inserted
        total_skipped  += skipped
        parts = []
        if inserted:
            parts.append(f"新規 {inserted} 件")
        if skipped:
            parts.append(f"スキップ {skipped} 件（追跡中）")
        print(f"    {date_str}: " + (", ".join(parts) if parts else "変化なし"))

    print(f"\n  d01〜d14 追跡価格を更新中...")
    update_prices()

    print(f"\n{'='*60}")
    print(f"  完了: {len(daily)} 日処理  登録 {total_inserted} 件 / スキップ {total_skipped} 件")
    print(f"{'='*60}")


def cmd_detect(args):
    """A/B/C 手法の候補銘柄を DB 履歴＋ウォッチリストから検出する"""
    print(f"\n{'='*60}")
    print(f"  手法 A/B/C 候補検出  日本株")
    print(f"{'='*60}\n")

    past    = get_past_records()
    past_set = {r["ticker"] for r in past}

    # ── A / B ── DB 内の過去急騰銘柄からチェック
    if past:
        print(f"  DB 内の過去ランキング銘柄数: {len(past_set)} 件")
        print("  価格データ取得中...（しばらくお待ちください）\n")
        df_a, df_b = detect_ab(past)
    else:
        print("  ⚠️  DB にデータがありません。まず rank コマンドを実行してください。")
        df_a, df_b = __import__("pandas").DataFrame(), __import__("pandas").DataFrame()

    # ── C ── ウォッチリスト全体をスキャン
    print("  C手法: 節目価格スキャン中...\n")
    df_c = detect_c(
        market        = "JP",
        cap_types     = ["small", "mid"],
        past_set      = past_set,
        rsi_threshold = args.rsi,
    )

    # ── 表示 ──
    sections = [
        ("A: 全モ手法",
         "元値の水平帯に戻ってきた銘柄（急騰→急落→元値付近）",
         df_a,
         ["ticker","name","元値","現在価格","元値差%","水平CV%","RSI14","MACD","急騰日"]),
        ("B: 手法２改",
         "急騰後にフィボナッチ半値付近で丸ばりしている銘柄",
         df_b,
         ["ticker","name","フィボ半値","現在価格","フィボ差%","丸ばりCV%","高値比%","RSI14","MACD","急騰日"]),
        ("C: 急落1000円節目",
         f"RSI{args.rsi}以下 × 節目価格（500/1000/2000…）の5%以内",
         df_c,
         ["ticker","name","節目価格","現在価格","節目差%","RSI14","MACD","既ランク"]),
    ]

    found_any = False
    for title, desc, df, cols in sections:
        print(f"  ── {title} ──")
        print(f"  {desc}")
        if df.empty:
            print("    候補なし\n")
        else:
            found_any = True
            show_cols = [c for c in cols if c in df.columns]
            print(f"\n{df[show_cols].to_string(index=False)}\n")

    if not found_any:
        print("  本日は A/B/C いずれの候補も見つかりませんでした。")

    print(f"{'='*60}")


def cmd_query(args):
    df = query(args.sql)
    print(df.to_string())


def main():
    parser = argparse.ArgumentParser(
        description="値上がり質ランキング トラッカー",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
コマンド例:
  python main.py rank                    # 当日ランキングを表示・DB保存
  python main.py rank --top 10           # 上位10件
  python main.py rank --no-save          # 表示のみ（DB保存しない）
  python main.py update                  # d01〜d14 追跡価格を更新
  python main.py report                  # 2週間パフォーマンス集計を表示
  python main.py backfill                # 過去14営業日分を DB に補填
  python main.py backfill --days 30      # 過去30営業日分を補填
  python main.py detect                  # A/B/C 手法の買い候補を検出
  python main.py detect --rsi 20         # C手法の RSI 閾値を20に絞る
""",
    )
    sub = parser.add_subparsers(dest="command")

    p_rank = sub.add_parser("rank", help="当日の値上がり質ランキングを表示・DB保存（日本株）")
    p_rank.add_argument("--top",      type=int, default=20,  help="件数 (デフォルト:20)")
    p_rank.add_argument("--min-gain", type=float, default=0.5, dest="min_gain",
                        help="最低値上がり率%% (デフォルト:0.5)")
    p_rank.add_argument("--no-save",  action="store_true", dest="no_save",
                        help="DB に保存しない")
    p_rank.add_argument("--date", type=str, default=None,
                        help="記録日を手動指定 (YYYY-MM-DD)。省略時はページ日付を使用")
    # --source は明示的な上書き用（通常は自動判定）

    sub.add_parser("update", help="過去レコードの d01〜d14 追跡価格を更新")
    sub.add_parser("report", help="2週間パフォーマンス集計を表示")

    p_bf = sub.add_parser("backfill", help="過去 n 営業日分のランキングを DB に補填（日本株）")
    p_bf.add_argument("--days",     type=int, default=14,  help="遡る営業日数（デフォルト:14）")
    p_bf.add_argument("--min-gain", type=float, default=0.5, dest="min_gain",
                      help="最低値上がり率%% (デフォルト:0.5)")

    p_detect = sub.add_parser("detect", help="A/B/C 手法の候補銘柄を DB 履歴から検出")
    p_detect.add_argument("--rsi",  type=float, default=25.0,
                          help="C手法の RSI 上限（デフォルト:25.0）")

    p_query = sub.add_parser("query", help="DB に任意の SQL を実行（デバッグ用）")
    p_query.add_argument("sql", help="SELECT 文")

    args = parser.parse_args()

    if args.command == "rank":
        cmd_rank(args)
    elif args.command == "backfill":
        cmd_backfill(args)
    elif args.command == "update":
        cmd_update(args)
    elif args.command == "report":
        cmd_report(args)
    elif args.command == "detect":
        cmd_detect(args)
    elif args.command == "query":
        cmd_query(args)
    else:
        parser.print_help()


if __name__ == "__main__":
    # Windows のコンソールは既定が CP932 で、日本語がそのまま出ると化ける。
    # 差し替えるのはコンソールから起動したときだけ。import 時や main() の中で
    # 差し替えると pytest の出力捕捉を壊し、main を通るテストが書けなくなる。
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
    main()

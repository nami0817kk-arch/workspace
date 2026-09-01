import argparse
import io
import sys
from datetime import date

from dotenv import load_dotenv
load_dotenv()

from src.data.kabutan_disclosure import fetch_and_extract
from src.analysis.ir_analyzer import analyze_batch
from src.report.excel_exporter import export_to_excel

CATEGORY_CHOICES = ["kessan", "gyoseki", "haitou", "jishakab", "zoshi", "all"]
CATEGORY_LABELS = {
    "kessan":   "決算",
    "gyoseki":  "業績修正",
    "haitou":   "配当",
    "jishakab": "自社株買い",
    "zoshi":    "増資",
    "all":      "全件",
}


def cmd_run(args):
    target_date = args.date or str(date.today())
    category = None if args.category == "all" else args.category
    label = CATEGORY_LABELS.get(args.category, args.category)

    print(f"\n{'='*60}")
    print(f"  PJT004 IR分析  [{target_date}]  カテゴリ: {label}")
    print(f"{'='*60}\n")

    print("  Step1: 株探から開示一覧＋PDFを取得中...")
    items = fetch_and_extract(
        target_date=target_date,
        category=category,
        max_items=args.max,
    )

    if not items:
        print("  開示情報が見つかりませんでした。")
        return

    print(f"\n  Step2: Claude APIで{len(items)}件を分析中...")
    items = analyze_batch(items, verbose=True)

    print("\n  Step3: Excelレポートを出力中...")
    path = export_to_excel(items, output_path=args.output)
    print(f"  → 保存完了: {path}")

    # スイング重要度 high の銘柄をコンソールに表示
    high = [i for i in items if i.get("analysis", {}).get("swing_relevance") == "high"]
    if high:
        print(f"\n  ★ スイング注目銘柄 ({len(high)}件) ★")
        for item in high:
            a = item["analysis"]
            print(f"    [{a.get('impact','').upper()}] {item.get('company','')} — {item.get('title','')[:40]}")
            print(f"    → {a.get('swing_note','')}")
    else:
        print("\n  本日のスイング注目銘柄: なし")

    print(f"\n{'='*60}")


def main():
    parser = argparse.ArgumentParser(
        description="PJT004 — 株探IR分析ツール",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
使用例:
  python main.py run                          # 当日の全開示を分析
  python main.py run --category gyoseki       # 業績修正のみ
  python main.py run --date 2026-06-27        # 日付指定
  python main.py run --max 10                 # 上位10件のみ
  python main.py run --output report.xlsx     # 出力ファイル名を指定
""",
    )
    sub = parser.add_subparsers(dest="command")

    p_run = sub.add_parser("run", help="IR取得・分析・Excel出力を一括実行")
    p_run.add_argument("--date",     type=str, default=None,
                       help="対象日 YYYY-MM-DD（省略時: 当日）")
    p_run.add_argument("--category", type=str, default="all",
                       choices=CATEGORY_CHOICES,
                       help="開示カテゴリ（デフォルト: all）")
    p_run.add_argument("--max",      type=int, default=20,
                       help="最大処理件数（デフォルト: 20）")
    p_run.add_argument("--output",   type=str, default=None,
                       help="Excelの出力パス（省略時: data/reports/ir_report_YYYYMMDD.xlsx）")

    args = parser.parse_args()

    if args.command == "run":
        cmd_run(args)
    else:
        parser.print_help()


if __name__ == "__main__":
    # Windows のコンソールは既定が CP932 で、日本語がそのまま出ると化ける。
    # 差し替えるのはコンソールから起動したときだけ。import 時や main() の中で
    # 差し替えると pytest の出力捕捉を壊し、main を通るテストが書けなくなる。
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
    main()

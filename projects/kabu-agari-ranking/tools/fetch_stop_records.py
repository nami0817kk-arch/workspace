"""既にある日のファイルに、ストップ高／ストップ安の記録だけを後から足す。

**当日分（取得元が「本日の」として出している日）にしか使えない。**
株探のストップ高・ストップ安ランキングは直近営業日ぶんしか出さないので、
翌営業日になると前の日の分は二度と取れない。

使いどころは2つ:

1. 16:10 の自動実行がランキングは取れたのにストップ高／安だけ落とした日の、
   その日のうちの取り直し
2. ストップ高／安の記録を始めた 2026-09-28 の直前の営業日を、
   休日のうちに1日ぶんだけ拾っておく（2026-09-27 に 09-25 分で実施）

**既にキーがある日には触らない**（`--overwrite` を付けたときだけ上書きする）。
記録済みのものを黙って取り直すと、何がいつの取得なのか分からなくなる。

    python tools/fetch_stop_records.py            # 取れた日付を見るだけ
    python tools/fetch_stop_records.py --write     # 書き込む
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "src"))

import build_site
import fetcher

_DATA_DIR = Path(__file__).resolve().parent.parent / "data"


def main() -> None:
    write = "--write" in sys.argv
    overwrite = "--overwrite" in sys.argv

    high = fetcher.fetch_stop_high()
    low = fetcher.fetch_stop_low()
    rows = {
        "stop_high": build_site._stop_rows(high, fetcher.STOP_HIGH_LABEL),
        "stop_low": build_site._stop_rows(low, fetcher.STOP_LOW_LABEL),
    }

    # 相場日は取得したページ自身が名乗るものを使う（実行日ではない）
    rec_dates = {df["rec_date"].iloc[0] for df in (high, low) if not df.empty}
    if len(rec_dates) > 1:
        print(f"  [ERROR] 相場日が一致しません: {sorted(rec_dates)}")
        sys.exit(1)
    if not rec_dates:
        print("  どちらも0件でした。相場日が分からないので何もしません。")
        print("  （0件が正しいなら、その日のランキング取得のほうで記録されます）")
        return

    rec_date = rec_dates.pop()
    path = _DATA_DIR / f"{rec_date}.json"
    if not path.exists():
        print(f"  [ERROR] {path.name} がありません。先にその日のランキングを取得する。")
        sys.exit(1)

    day = json.loads(path.read_text(encoding="utf-8"))
    for key, value in rows.items():
        if value is None:
            print(f"  {key}: 1ページも取得できませんでした（触りません）")
            continue
        if key in day and not overwrite:
            print(f"  {key}: 既に {len(day[key])} 件あります（--overwrite で上書き）")
            continue
        print(f"  {key}: {len(value)} 件")
        if write:
            day[key] = value

    if not write:
        print(f"  {path.name} には書き込んでいません（--write を付ける）。")
        return

    path.write_text(json.dumps(day, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"  {path} を更新しました。")
    latest = _DATA_DIR / "latest.json"
    if latest.exists() and json.loads(latest.read_text(encoding="utf-8")).get("rec_date") == rec_date:
        latest.write_text(json.dumps(day, ensure_ascii=False, indent=2), encoding="utf-8")
        print("  latest.json も同じ内容にしました。")


if __name__ == "__main__":
    main()

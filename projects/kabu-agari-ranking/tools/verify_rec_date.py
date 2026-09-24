"""保存済みデータの「実際の相場日」を、株探の日足と突き合わせて確かめる。

data/ のファイル名（＝ rec_date）が本当にその日の相場なのかは、
ランキングのページからは確かめられない（当日分しか出ないため）。
個別銘柄の日足（時系列データ）には過去の終値と前日比が残っているので、
そこに同じ数字がある日を探せば、実際の相場日が決まる。

2026-09-24 にこの方法で、掲載開始直後の4日分の日付を確定させた:

    2026-08-24.json … 2026-08-24（正しかった）
    2026-08-28.json … 2026-08-28（正しかった）
    2026-08-31.json … 実際は 2026-09-01
    2026-09-01.json … 実際は 2026-09-02

読み替えは render.DATE_CORRECTIONS に入れてある。

HTML の取得と解析は共有パッケージ kabutan-client に置いた
（構造が変わったときに直す場所を1つにするため）。ここにあるのは、
保存済みデータと突き合わせる手順だけ。

使い方（先方に負荷をかけないよう、1銘柄ごとに間を空ける）:

    python tools/verify_rec_date.py 2026-08-31 2026-09-01

引数を省略すると data/ の全ファイルを見る。**日常的に回すものではない**。
日付の疑いが出たときだけ使う。
"""
from __future__ import annotations

import json
import sys
import time
from pathlib import Path

import pandas as pd
from kabutan import fetch_daily_html, parse_daily_prices

_DATA_DIR = Path(__file__).resolve().parent.parent / "data"

# 1銘柄あたりに見る日足のページ数（1ページでおよそ1か月）
_PAGES = 2
# 先方への間隔。ランキング取得と同じ程度に抑える。
_SLEEP = 1.5
# 1ファイルあたり何銘柄で確かめるか。1件だと偶然の一致を否定できない。
_SAMPLES = 3


def daily_prices(code: str) -> pd.DataFrame:
    frames = []
    for page in range(1, _PAGES + 1):
        html = fetch_daily_html(code, page=page)
        if html:
            df = parse_daily_prices(html)
            if not df.empty:
                frames.append(df)
        time.sleep(_SLEEP)
    if not frames:
        return pd.DataFrame()
    return pd.concat(frames, ignore_index=True).drop_duplicates("date")


def verify(rec_date: str) -> list[str]:
    """そのファイルの上位銘柄が、実際にはどの日の値かを返す。"""
    payload = json.loads((_DATA_DIR / f"{rec_date}.json").read_text(encoding="utf-8"))
    rows = payload.get("gainers") or payload.get("rows") or []
    found = []
    for row in rows[:_SAMPLES]:
        pct = float(row.get("change_pct", row.get("gain_pct")))
        close = float(row["close"])
        df = daily_prices(row["code"])
        if df.empty:
            print(f"  {row['code']} {row['name'][:12]:14s} 日足を取得できませんでした")
            continue
        hit = df[(df["close"] == close) & (df["change_pct"].round(2) == round(pct, 2))]
        dates = hit["date"].tolist()
        print(f"  {row['code']} {row['name'][:12]:14s} 終値{close:>9,.0f} {pct:+6.2f}% → "
              f"{dates or '該当なし'}")
        found.extend(dates)
        time.sleep(_SLEEP)
    return found


def main() -> int:
    targets = sys.argv[1:] or sorted(p.stem for p in _DATA_DIR.glob("????-??-??.json"))
    mismatched = 0
    for rec_date in targets:
        print(f"--- {rec_date}.json ---")
        found = verify(rec_date)
        if not found:
            print("  判定できません（日足に該当なし。期間が古すぎる可能性）")
            continue
        actual = max(set(found), key=found.count)
        if actual == rec_date:
            print(f"  → {rec_date} で正しい（{found.count(actual)}/{len(found)}件一致）")
        else:
            mismatched += 1
            print(f"  → **実際は {actual}**（{found.count(actual)}/{len(found)}件一致）")
    return 1 if mismatched else 0


if __name__ == "__main__":
    sys.exit(main())

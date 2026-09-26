"""
データが止まっていないかの監視。

2つの場所から呼ばれる:

1. CI（kabu-daily.yml、平日17:00 JST）— 手元PCの取得タスクが動かなかった、
   PCが起動していなかった、といった「手元では通知すら出ない止まり方」を拾う。
2. 手元の run-daily.ps1 — 取得の直後に `--after-fetch` で呼び、当日分が
   取れていなければデスクトップ通知を出す。exit 0 のまま当日分だけが
   抜ける止まり方（2026-09-08）は、これまで誰も気づけなかった。

**取り逃した営業日は二度と取れない**（kabutan は当日分しか出さない）ので、
気づくのが当日中かどうかで復旧できるかが決まる。

祝日は market_calendar が見る。土日しか見ていなかった頃はシルバーウィークで
3営業日続けて誤検知し、しかもこの判定が Deploy の手前にあったため公開まで
止めていた。
"""
from __future__ import annotations

import argparse
import json
import sys
from datetime import date, datetime, time, timedelta, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from market_calendar import (
    CalendarOutOfRange,
    business_days_between,
    is_business_day,
    previous_business_day,
)

JST = timezone(timedelta(hours=9))

# 手元の取得は16:10開始。終わって push が届くまでを見て、これ以降は
# 「当日分があるはず」と判定する。これより前の push でも鳴らさないための境目。
FETCH_DONE_AT = time(16, 40)

_DATA_DIR = Path(__file__).resolve().parent.parent / "data"


def expected_rec_date(now: datetime, *, after_fetch: bool = False) -> date:
    """この時点で最新であるべき相場日。

    取得前の時間帯（朝の push など）はまだ前営業日が最新で正しい。
    `after_fetch` は取得を回した直後に呼ばれたことを示し、時刻を問わず
    当日分を期待する。
    """
    today = now.date()
    if is_business_day(today) and (after_fetch or now.time() >= FETCH_DONE_AT):
        return today
    return previous_business_day(today)


def check(rec_date: date, now: datetime, *, after_fetch: bool = False) -> tuple[int, str]:
    """(遅れている営業日数, 説明) を返す。0 なら正常。"""
    expected = expected_rec_date(now, after_fetch=after_fetch)
    behind = business_days_between(rec_date, expected)
    return behind, f"latest rec_date={rec_date} / 期待={expected} / 営業日で{behind}日ぶん遅れ"


def main() -> int:
    parser = argparse.ArgumentParser(description="ランキングデータの鮮度を確認する")
    parser.add_argument(
        "--after-fetch",
        action="store_true",
        help="取得の直後に呼ぶ。時刻によらず当日分を期待する",
    )
    args = parser.parse_args()

    latest = _DATA_DIR / "latest.json"
    if not latest.exists():
        print(f"::error::{latest} がありません。")
        return 1

    rec_date = date.fromisoformat(json.loads(latest.read_text(encoding="utf-8"))["rec_date"])
    now = datetime.now(JST)
    try:
        behind, message = check(rec_date, now, after_fetch=args.after_fetch)
    except CalendarOutOfRange as e:
        # 祝日表は2027年までしか無い。切れた瞬間に例外の生ログだけが出ても、
        # 何をすればよいか分からない（しかも「データが古い」と読めてしまう）。
        print(f"::error::休場日の判定ができません: {e}")
        print("::error::src/market_calendar.py の祝日表を、内閣府CSVから追記してください。")
        return 1
    print(message)

    if behind >= 1:
        print(
            f"::error::ランキングデータが{behind}営業日ぶん古いままです（最新 {rec_date}）。"
            "手元PCの取得タスク run-daily.ps1 が動いたか、"
            "同ディレクトリの run-daily.log を確認してください。"
            "当日中に src\\build_site.py を回さないと、その営業日は二度と取れません。"
        )
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())

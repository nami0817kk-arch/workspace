"""
東証の営業日カレンダー。

鮮度監視（データが古いまま止まっていないか）の判定に使う。土日だけを見て
いると祝日で必ず空振りし、2026-09-21〜23 のシルバーウィークでは3日続けて
誤検知した。鳴りっぱなしの警報は読まれなくなるので、休場日は除いて数える。

祝日は内閣府の「国民の祝日」CSV が一次情報。
https://www8.cao.go.jp/chosei/shukujitsu/syukujitsu.csv

**このCSVは年に一度更新される（翌年分が追加される）。** 表の最終年を過ぎると
判定できなくなるので、その場合は黙って通さず例外にしてある。年末に一度、
上記CSVから追記すること。取得を自動化しない理由は、監視そのものが
外部サイトの応答に依存すると、落ちたときに監視が止まるため。
"""
from __future__ import annotations

from datetime import date, timedelta

# 内閣府CSVから転記（2026-09-23 時点）。振替休日・国民の休日も「休日」として含む。
_NATIONAL_HOLIDAYS = frozenset(
    {
        # 2026
        "2026-01-01",  # 元日
        "2026-01-12",  # 成人の日
        "2026-02-11",  # 建国記念の日
        "2026-02-23",  # 天皇誕生日
        "2026-03-20",  # 春分の日
        "2026-04-29",  # 昭和の日
        "2026-05-03",  # 憲法記念日
        "2026-05-04",  # みどりの日
        "2026-05-05",  # こどもの日
        "2026-05-06",  # 休日（振替）
        "2026-07-20",  # 海の日
        "2026-08-11",  # 山の日
        "2026-09-21",  # 敬老の日
        "2026-09-22",  # 休日（国民の休日）
        "2026-09-23",  # 秋分の日
        "2026-10-12",  # スポーツの日
        "2026-11-03",  # 文化の日
        "2026-11-23",  # 勤労感謝の日
        # 2027
        "2027-01-01",  # 元日
        "2027-01-11",  # 成人の日
        "2027-02-11",  # 建国記念の日
        "2027-02-23",  # 天皇誕生日
        "2027-03-21",  # 春分の日
        "2027-03-22",  # 休日（振替）
        "2027-04-29",  # 昭和の日
        "2027-05-03",  # 憲法記念日
        "2027-05-04",  # みどりの日
        "2027-05-05",  # こどもの日
        "2027-07-19",  # 海の日
        "2027-08-11",  # 山の日
        "2027-09-20",  # 敬老の日
        "2027-09-23",  # 秋分の日
        "2027-10-11",  # スポーツの日
        "2027-11-03",  # 文化の日
        "2027-11-23",  # 勤労感謝の日
    }
)

# 表が覆う範囲。これを外れたら判定せず例外にする（黙って平日扱いにしない）。
COVERED_YEARS = range(2026, 2028)


class CalendarOutOfRange(Exception):
    """祝日表が覆っていない年を判定しようとした。"""


def is_business_day(d: date) -> bool:
    """東証が開いている日か。土日・祝日・年末年始（12/31〜1/3）は False。"""
    if d.year not in COVERED_YEARS:
        raise CalendarOutOfRange(
            f"{d} は祝日表の範囲外です。market_calendar.py に内閣府CSVから追記してください。"
        )
    if d.weekday() >= 5:
        return False
    if d.isoformat() in _NATIONAL_HOLIDAYS:
        return False
    # 東証の年末年始休場。1/1 は祝日表にもあるが、1/2・1/3・12/31 は無い。
    if (d.month, d.day) in {(1, 2), (1, 3), (12, 31)}:
        return False
    return True


def previous_business_day(d: date) -> date:
    """d より前で直近の営業日。"""
    cur = d - timedelta(days=1)
    while not is_business_day(cur):
        cur -= timedelta(days=1)
    return cur


def next_business_day(d: date) -> date:
    """d より後で直近の営業日。「次回更新予定」の表示に使う。"""
    cur = d + timedelta(days=1)
    while not is_business_day(cur):
        cur += timedelta(days=1)
    return cur


def business_days_between(start: date, end: date) -> int:
    """start の翌日から end までに何営業日あるか（end を含む）。start >= end なら 0。"""
    count = 0
    cur = start
    while cur < end:
        cur += timedelta(days=1)
        if is_business_day(cur):
            count += 1
    return count

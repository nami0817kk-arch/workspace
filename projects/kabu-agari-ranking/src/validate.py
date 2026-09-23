"""保存する前に、取ってきたデータが妥当かを見る。

data/ は追記しかできない資産で、**上書きしてしまうと元には戻せない**
（kabutan は当日分しか出さないので、取り直しができない）。
2026-09-07 は、月曜のデータに金曜の日付が付いたまま保存され、
金曜のファイルを潰した。あのとき保存前に日付を一言確かめていれば防げた。

ここは「おかしければ保存しない」側に倒す。疑わしいものを弾いて
その日を取り逃すほうが、古い正しいデータを消すよりましなため。
"""
from __future__ import annotations

from datetime import date, datetime, time, timedelta, timezone

from market_calendar import CalendarOutOfRange, is_business_day, previous_business_day

JST = timezone(timedelta(hours=9))

# 東証の大引け（15:30）。これを過ぎれば当日の終値ランキングが出ている。
MARKET_CLOSE = time(15, 30)

# 上位30件を取りにいって、これを下回るのは取得か解析が壊れている疑いが濃い。
MIN_ROWS = 20


class InvalidPayload(Exception):
    """保存を見送るべきデータ。"""


def expected_rec_dates(now: datetime) -> set[str]:
    """この時点で kabutan が出しうる相場日。

    - 大引け後の営業日 → 当日
    - 場中・休場日 → 直近の営業日（前営業日の終値がまだ出ている）
    """
    today = now.date()
    try:
        if is_business_day(today):
            prev = previous_business_day(today)
            if now.time() >= MARKET_CLOSE:
                return {today.isoformat()}
            return {today.isoformat(), prev.isoformat()}
        return {previous_business_day(today).isoformat()}
    except CalendarOutOfRange:
        # 祝日表の範囲外では日付の妥当性を判断しない（空集合＝何もチェックしない）
        return set()


def check(payload: dict, now: datetime) -> None:
    """おかしければ InvalidPayload を投げる。問題なければ黙って戻る。"""
    rec_date = payload.get("rec_date")
    if not rec_date:
        raise InvalidPayload("rec_date がありません")

    try:
        rec = date.fromisoformat(rec_date)
    except ValueError as e:
        raise InvalidPayload(f"rec_date の形式が不正です: {rec_date}") from e

    if rec > now.date():
        raise InvalidPayload(f"rec_date が未来です: {rec_date}")

    expected = expected_rec_dates(now)
    if expected and rec_date not in expected:
        # ここが 2026-09-07 の事故を止める関門。
        raise InvalidPayload(
            f"rec_date {rec_date} は、この時点で出るはずの相場日"
            f"（{ '/'.join(sorted(expected)) }）と一致しません。"
            "ページ上の日付の読み取りが壊れている可能性があります。"
        )

    gainers = payload.get("gainers") or []
    if len(gainers) < MIN_ROWS:
        raise InvalidPayload(f"値上がりの件数が{len(gainers)}件しかありません（{MIN_ROWS}件未満）")

    for row in gainers:
        if not str(row.get("code", "")).strip():
            raise InvalidPayload("銘柄コードが空の行があります")
        if row.get("change_pct") is None:
            raise InvalidPayload(f"騰落率が取れていない行があります: {row.get('code')}")

    if all(row["change_pct"] == 0 for row in gainers):
        raise InvalidPayload("値上がり率が全て0です（解析が壊れている疑い）")

    # 値上がりランキングなのに首位が下落しているなら、並び替えか列の読み違い。
    if gainers[0]["change_pct"] < 0:
        raise InvalidPayload(
            f"値上がりランキングの首位が下落しています（{gainers[0]['change_pct']}%）"
        )
